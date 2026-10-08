## Drives the threat overlay: owns what's shown, recomputes the danger zones via
## ThreatCalculator on relevant battle events, and feeds them to its (swappable)
## ThreatOverlayRenderers. No drawing here — pure control/logic, so the renderer
## can be re-skinned without touching any of this.
##
## Two layers, each on or off by itself, both allowed on screen at once:
##   - PINS: toggle_unit(enemy) pins/unpins one enemy's zone, in red. Pins
##     PERSIST until toggled off — they deliberately do NOT clear when the
##     preview panel closes. Driven by the Range chip on the enemy preview
##     panel, and by the zone button (V / RT) pressed over an enemy.
##   - THE ARMY ZONE: every enemy's reach, in amber. The zone button anywhere
##     else, and touch's bar button, show or hide it; pins stay as they are.
## Where they overlap the pin wins: the army layer leaves pinned cells out, so
## the red is never tinted by amber under it (army_layer).
## UI reflecting pin state (the preview-panel chip) listens on `changed`.
##
## The zone is a player-phase planning tool: it stands down for the enemy phase
## (redrawn under every enemy step it reads as the enemy's own move range) and
## comes back at the next player phase. Both layers survive the gap.
class_name ThreatOverlayController
extends Node

## Emitted whenever the army zone or the pinned set changes — UI chips re-read.
signal changed

## What the next zone-button press will do (zone_press_for).
enum Press { SHOW_ARMY, HIDE_ARMY, PIN, UNPIN }

## Group name for cross-viewport lookup (HUD panels live in HUDViewport and
## can't reach us by path; same SceneTree groups work from anywhere).
const GROUP_NAME: StringName = &"threat_overlay_controller"

var _army_shown: bool = false
var _pinned: Array[Unit] = []
var _army_renderer: ThreatOverlayRenderer = null
## Added after the army's, so the pins draw on top.
var _pinned_renderer: ThreatOverlayRenderer = null
var _enemy_phase: bool = false


func _ready() -> void:
	add_to_group(GROUP_NAME)
	_army_renderer = _add_renderer("ArmyZoneRenderer")
	_pinned_renderer = _add_renderer("PinnedZoneRenderer")
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager != null and turn_manager.has_signal("player_phase_started"):
		turn_manager.player_phase_started.connect(_on_player_phase_started)
		turn_manager.enemy_phase_started.connect(_on_enemy_phase_started)


func _add_renderer(node_name: String) -> ThreatOverlayRenderer:
	var renderer := ThreatOverlayRenderer.new()
	renderer.name = node_name
	add_child(renderer)
	return renderer


func _on_enemy_phase_started() -> void:
	_enemy_phase = true
	refresh()


## Enemies moved and died while the zone was down; recompute from where they
## stand now.
func _on_player_phase_started(_turn_count: int) -> void:
	_enemy_phase = false
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	# Asked first, every event: RT is a trigger, and the press edge must stay
	# tracked through the enemy phase too.
	var pressed := InputSource.is_action_press(event, &"toggle_threat_zones")
	# Not the player's turn: the key would change a zone nobody can see.
	if not pressed or _enemy_phase:
		return
	press_zone_button(InputManager.get_hovered_tile())
	get_viewport().set_input_as_handled()


## What the zone button (V / RT) does on `hovered` right now: over an enemy it
## pins or unpins that enemy's zone; anywhere else it shows or hides the army
## zone. Touch has no cursor to aim, so its bar button is always the army's.
## The press acts on this and the hint bar names it, so the bar can't promise
## a different press.
func zone_press_for(hovered: Tile) -> Press:
	var enemy := enemy_on(hovered)
	if enemy != null and not InputSource.is_touch_driven():
		return Press.UNPIN if is_unit_shown(enemy) else Press.PIN
	return Press.HIDE_ARMY if _army_shown else Press.SHOW_ARMY


func press_zone_button(hovered: Tile) -> void:
	match zone_press_for(hovered):
		Press.PIN, Press.UNPIN:
			toggle_unit(enemy_on(hovered))
		_:
			toggle_army_zone()


## The living enemy standing on `tile`, or null.
static func enemy_on(tile: Tile) -> Unit:
	if tile == null or not is_instance_valid(tile):
		return null
	var unit := tile.current_unit as Unit
	if unit == null or unit.faction != Enums.UnitFaction.ENEMY or unit.is_defeated():
		return null
	return unit


## Connect per-unit signals so the zone tracks board changes while it's shown: a
## unit moving can open or block enemy paths, and a death removes a threatener.
func register_battle_units(player_units: Array[Unit], enemy_units: Array[Unit]) -> void:
	for unit: Unit in player_units:
		_connect_unit(unit)
	for unit: Unit in enemy_units:
		_connect_unit(unit)


func _connect_unit(unit: Unit) -> void:
	if unit == null:
		return
	if unit.has_signal("movement_completed") and not unit.movement_completed.is_connected(_on_board_changed):
		unit.movement_completed.connect(_on_board_changed)
	if unit.has_signal("combat_completed") and not unit.combat_completed.is_connected(_on_combat):
		unit.combat_completed.connect(_on_combat)


## The army zone on or off; pins stay as they are.
func toggle_army_zone() -> void:
	_army_shown = not _army_shown
	refresh()
	changed.emit()


## Pin/unpin one enemy's zone (the preview-panel Range chip, the zone button
## over an enemy). Pins persist until toggled off here — closing the panel
## does NOT clear them — and draw over the army zone, not instead of it.
func toggle_unit(unit: Unit) -> void:
	if unit == null:
		return
	if _pinned.has(unit):
		_pinned.erase(unit)
	else:
		_pinned.append(unit)
	refresh()
	changed.emit()


func is_showing() -> bool:
	return _army_shown or not _pinned.is_empty()


## Is this specific enemy's zone pinned? (Chip state for the preview panel.)
func is_unit_shown(unit: Unit) -> bool:
	return _pinned.has(unit)


## Recompute and redraw both layers.
func refresh() -> void:
	if _army_renderer == null:
		return
	_prune_invalid_pins()
	if _enemy_phase:
		_army_renderer.clear()
		_pinned_renderer.clear()
		return
	var pinned_map := ThreatCalculator.compute_danger_zone(_pinned)
	_pinned_renderer.set_map(pinned_map, ThreatOverlayRenderer.Style.PINNED)
	if _army_shown:
		var army_map := ThreatCalculator.compute_danger_zone(_enemy_units())
		_army_renderer.set_map(army_layer(army_map, pinned_map), ThreatOverlayRenderer.Style.ARMY)
	else:
		_army_renderer.clear()


## The army zone minus the cells a pin paints: where the layers overlap the
## pin's red wins, never tinted by the amber under it.
static func army_layer(army_map: Dictionary, pinned_map: Dictionary) -> Dictionary:
	var layer := army_map.duplicate()
	for cell: Vector2i in pinned_map:
		layer.erase(cell)
	return layer


## Pinned enemies can die (or be freed) while their zone is up; drop them so a
## corpse doesn't keep projecting threat.
func _prune_invalid_pins() -> void:
	var before: int = _pinned.size()
	_pinned.assign(_pinned.filter(
			func(unit: Unit) -> bool: return is_instance_valid(unit) and not unit.is_defeated()))
	if _pinned.size() != before:
		changed.emit()


func _enemy_units() -> Array[Unit]:
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager == null:
		return []
	return turn_manager.get_enemy_units()


func _on_board_changed(_unit: Unit) -> void:
	if is_showing():
		refresh()


func _on_combat(_attacker: Unit, _defender: Unit) -> void:
	if is_showing():
		refresh()
