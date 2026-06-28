## Drives the threat overlay: owns the on/off + mode state, recomputes the danger
## zone via ThreatCalculator on relevant battle events, and feeds the result to
## its (swappable) ThreatOverlayRenderer. No drawing here — pure control/logic, so
## the renderer can be re-skinned without touching any of this.
##
## V1 wires the ALL-ENEMIES toggle ("toggle_threat_zones" input action). The
## INDIVIDUAL mode (show one/several specific enemies' zones, styled distinctly so
## the player can tell what they're looking at) is the next slice; the mode +
## _shown plumbing is already here for it.
class_name ThreatOverlayController
extends Node

enum Mode { OFF, ALL_ENEMIES, INDIVIDUAL }

var _mode: int = Mode.OFF
var _shown: Array[Unit] = []  # INDIVIDUAL mode: the specific enemies being shown
var _renderer: ThreatOverlayRenderer = null


func _ready() -> void:
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


## Flip the whole-army danger zone on/off.
func toggle_all_enemies() -> void:
	_mode = Mode.OFF if _mode == Mode.ALL_ENEMIES else Mode.ALL_ENEMIES
	refresh()


func is_showing() -> bool:
	return _mode != Mode.OFF


## Recompute and redraw for the current mode.
func refresh() -> void:
	if _renderer == null:
		return
	if _mode == Mode.OFF:
		_renderer.clear()
		return
	_renderer.set_map(ThreatCalculator.compute_danger_zone(_threateners()))


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
