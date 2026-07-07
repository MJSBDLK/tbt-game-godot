## Drives the threat overlay: owns the on/off + mode state, recomputes the danger
## zone via ThreatCalculator on relevant battle events, and feeds the result to
## its (swappable) ThreatOverlayRenderer. No drawing here — pure control/logic, so
## the renderer can be re-skinned without touching any of this.
##
## Two ways in, per the 2026-07 design pass:
##   - INDIVIDUAL: toggle_unit(enemy) pins/unpins one enemy's zone. Pins PERSIST
##     until toggled off — they deliberately do NOT clear when the preview panel
##     closes. Driven by the Range chip on the enemy preview panel.
##   - ALL_ENEMIES: the "toggle_threat_zones" action (V) and any on-screen
##     equivalent. Semantics are "show all / clear all": if ANYTHING is lit
##     (pins or the army zone), it clears everything; otherwise it shows the
##     whole army. One button, no third state to remember.
## UI reflecting pin state (the preview-panel chip) listens on `changed`.
class_name ThreatOverlayController
extends Node

## Emitted whenever mode or the pinned set changes — UI chips re-read state.
signal changed

enum Mode { OFF, ALL_ENEMIES, INDIVIDUAL }

## Group name for cross-viewport lookup (HUD panels live in HUDViewport and
## can't reach us by path; same SceneTree groups work from anywhere).
const GROUP_NAME: StringName = &"threat_overlay_controller"

var _mode: int = Mode.OFF
var _shown: Array[Unit] = []  # INDIVIDUAL mode: the specific enemies being shown
var _renderer: ThreatOverlayRenderer = null


func _ready() -> void:
	add_to_group(GROUP_NAME)
	_renderer = ThreatOverlayRenderer.new()
	_renderer.name = "ThreatOverlayRenderer"
	add_child(_renderer)
	assert(_renderer != null, "ThreatOverlayController: renderer failed to create")
	# Enemies move/die during their phase; recompute when control returns to the
	# player so the zone reflects their new positions.
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager != null and turn_manager.has_signal("player_phase_started"):
		turn_manager.player_phase_started.connect(func(_turn_count: int) -> void: refresh())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_threat_zones"):
		toggle_all_enemies()
		get_viewport().set_input_as_handled()


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


## The global key/button — "show all / clear all": anything lit clears
## everything; from a clean board it shows the whole army's zone.
func toggle_all_enemies() -> void:
	if _mode != Mode.OFF:
		clear_all()
		return
	_mode = Mode.ALL_ENEMIES
	refresh()
	changed.emit()


## Pin/unpin one enemy's zone (the preview-panel Range chip). Pins persist
## until toggled off here or via clear_all — closing the panel does NOT clear
## them. Pinning while the army-wide zone is up replaces it: mixing the two
## would make the stacked-count map unreadable.
func toggle_unit(unit: Unit) -> void:
	if unit == null:
		return
	if _mode == Mode.ALL_ENEMIES:
		_shown.clear()
	if _shown.has(unit):
		_shown.erase(unit)
	else:
		_shown.append(unit)
	_mode = Mode.INDIVIDUAL if not _shown.is_empty() else Mode.OFF
	refresh()
	changed.emit()


## Everything off — pins and the army zone alike.
func clear_all() -> void:
	_shown.clear()
	_mode = Mode.OFF
	refresh()
	changed.emit()


func is_showing() -> bool:
	return _mode != Mode.OFF


## Is this specific enemy's zone pinned? (Chip state for the preview panel.)
func is_unit_shown(unit: Unit) -> bool:
	return _mode == Mode.INDIVIDUAL and _shown.has(unit)


## Recompute and redraw for the current mode.
func refresh() -> void:
	if _renderer == null:
		return
	_prune_invalid_pins()
	if _mode == Mode.OFF:
		_renderer.clear()
		return
	_renderer.set_map(ThreatCalculator.compute_danger_zone(_threateners()))


## Pinned enemies can die (or be freed) while their zone is up; drop them so a
## corpse doesn't keep projecting threat. Emptying the set turns the mode off.
func _prune_invalid_pins() -> void:
	var before: int = _shown.size()
	_shown.assign(_shown.filter(
			func(unit: Unit) -> bool: return is_instance_valid(unit) and not unit.is_defeated()))
	if _shown.size() == before:
		return
	if _shown.is_empty() and _mode == Mode.INDIVIDUAL:
		_mode = Mode.OFF
	changed.emit()


func _threateners() -> Array[Unit]:
	if _mode == Mode.ALL_ENEMIES:
		var turn_manager: Node = get_node_or_null("/root/TurnManager")
		if turn_manager != null:
			return turn_manager.get_enemy_units()
		return []
	return _shown


func _on_board_changed(_unit: Unit) -> void:
	if _mode != Mode.OFF:
		refresh()


func _on_combat(_attacker: Unit, _defender: Unit) -> void:
	if _mode != Mode.OFF:
		refresh()
