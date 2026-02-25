## Orchestrates the battle turn loop: Player Phase → Enemy Phase → repeat.
## Handles phase transitions, status effect processing, victory/defeat detection.
## Registered as Autoload "TurnManager".
extends Node


signal player_phase_started(turn_count: int)
signal enemy_phase_started()
signal battle_ended(is_victory: bool)

var current_phase: Enums.TurnPhase = Enums.TurnPhase.PLAYER_PHASE
var turn_count: int = 0

var _player_units: Array[Unit] = []
var _enemy_units: Array[Unit] = []
var _is_processing_phase: bool = false
var _battle_ended: bool = false


# =============================================================================
# PUBLIC API
# =============================================================================

func initialize_battle(player_units: Array[Unit], enemy_units: Array[Unit]) -> void:
	_player_units = player_units
	_enemy_units = enemy_units
	_battle_ended = false
	turn_count = 0
	DebugConfig.log_turn("TurnManager: Battle initialized — %d players, %d enemies" % [
		_player_units.size(), _enemy_units.size()])

	# Connect defeat signals
	for unit: Unit in _player_units:
		if not unit.unit_defeated.is_connected(_on_unit_defeated):
			unit.unit_defeated.connect(_on_unit_defeated)
	for unit: Unit in _enemy_units:
		if not unit.unit_defeated.is_connected(_on_unit_defeated):
			unit.unit_defeated.connect(_on_unit_defeated)

	start_player_phase()


func is_player_phase() -> bool:
	return current_phase == Enums.TurnPhase.PLAYER_PHASE and not _is_processing_phase


func is_battle_ended() -> bool:
	return _battle_ended


func get_player_units() -> Array[Unit]:
	return _player_units


func get_enemy_units() -> Array[Unit]:
	return _enemy_units


func check_end_player_turn() -> void:
	if current_phase != Enums.TurnPhase.PLAYER_PHASE or _is_processing_phase:
		return

	var all_acted := true
	for unit: Unit in _player_units:
		if not unit.is_defeated() and unit.can_act:
			all_acted = false
			break

	if all_acted:
		DebugConfig.log_turn("TurnManager: All player units acted, starting enemy phase")
		start_enemy_phase()


func force_end_player_turn() -> void:
	if current_phase != Enums.TurnPhase.PLAYER_PHASE or _is_processing_phase:
		return

	# Set all remaining units as acted
	for unit: Unit in _player_units:
		if not unit.is_defeated() and unit.can_act:
			unit.set_acted()

	DebugConfig.log_turn("TurnManager: Player force-ended turn")

	var input_manager: Node = get_node_or_null("/root/InputManager")
	if input_manager != null:
		input_manager.deselect_unit()

	start_enemy_phase()


# =============================================================================
# PHASE TRANSITIONS
# =============================================================================

func start_player_phase() -> void:
	if _battle_ended:
		return
	current_phase = Enums.TurnPhase.PLAYER_PHASE
	_is_processing_phase = true
	turn_count += 1

	var input_manager: Node = get_node_or_null("/root/InputManager")
	if input_manager != null:
		input_manager.disable_input()

	DebugConfig.log_turn("TurnManager: === PLAYER PHASE (Turn %d) ===" % turn_count)

	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null:
		await ui_manager.show_phase_transition("PLAYER PHASE - Turn %d" % turn_count, GameColors.PLAYER_UNIT)

	_process_status_effects(_player_units)
	_refresh_units(_player_units)

	if input_manager != null:
		input_manager.enable_input()
		input_manager.deselect_unit()

	var state_manager: Node = get_node_or_null("/root/GameStateManager")
	if state_manager != null:
		state_manager.change_state(Enums.InputState.DEFAULT)

	_is_processing_phase = false
	player_phase_started.emit(turn_count)
	_check_victory_conditions()


func start_enemy_phase() -> void:
	if _battle_ended:
		return
	current_phase = Enums.TurnPhase.ENEMY_PHASE
	_is_processing_phase = true

	var input_manager: Node = get_node_or_null("/root/InputManager")
	if input_manager != null:
		input_manager.disable_input()
		input_manager.deselect_unit()

	GridManager.clear_movement_range()
	GridManager.clear_attack_range()
	GridManager.clear_selected_tile()

	await get_tree().create_timer(0.25).timeout

	DebugConfig.log_turn("TurnManager: === ENEMY PHASE ===")

	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null:
		await ui_manager.show_phase_transition("ENEMY PHASE", GameColors.ENEMY_UNIT)

	_process_status_effects(_enemy_units)
	_refresh_units(_enemy_units)

	enemy_phase_started.emit()
	await _process_enemy_phase()

	if not _battle_ended:
		await get_tree().create_timer(1.0).timeout
		start_player_phase()


# =============================================================================
# ENEMY AI EXECUTION
# =============================================================================

func _process_enemy_phase() -> void:
	for unit: Unit in _enemy_units:
		if unit.is_defeated() or not unit.can_act:
			continue

		var enemy_ai_node: Node = unit.get_node_or_null("EnemyAI")
		if enemy_ai_node != null and enemy_ai_node.has_method("execute_turn"):
			await enemy_ai_node.execute_turn()
		else:
			unit.set_acted()

		await get_tree().create_timer(0.5).timeout
		_check_victory_conditions()
		if _battle_ended:
			return

	_is_processing_phase = false


# =============================================================================
# VICTORY / DEFEAT
# =============================================================================

func _check_victory_conditions() -> void:
	if _battle_ended:
		return

	var all_enemies_defeated := true
	for unit: Unit in _enemy_units:
		if not unit.is_defeated():
			all_enemies_defeated = false
			break

	var all_players_defeated := true
	for unit: Unit in _player_units:
		if not unit.is_defeated():
			all_players_defeated = false
			break

	if all_enemies_defeated:
		_end_battle(true)
	elif all_players_defeated:
		_end_battle(false)


func _end_battle(is_victory: bool) -> void:
	_battle_ended = true
	current_phase = Enums.TurnPhase.BATTLE_END
	_is_processing_phase = false

	var input_manager: Node = get_node_or_null("/root/InputManager")
	if input_manager != null:
		input_manager.disable_input()

	var result_text := "VICTORY!" if is_victory else "DEFEAT!"
	DebugConfig.log_turn("TurnManager: Battle ended — %s (Turn %d)" % [result_text, turn_count])

	# Calculate battle stats
	var player_units_lost: int = 0
	for unit: Unit in _player_units:
		if unit.is_defeated():
			player_units_lost += 1

	var enemies_defeated: int = 0
	for unit: Unit in _enemy_units:
		if unit.is_defeated():
			enemies_defeated += 1

	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null:
		ui_manager.show_battle_result(is_victory, turn_count, player_units_lost,
			enemies_defeated, _player_units.size(), _enemy_units.size())

	battle_ended.emit(is_victory)


func _on_unit_defeated(unit: Unit) -> void:
	_check_victory_conditions()


# =============================================================================
# UNIT MANAGEMENT
# =============================================================================

func _refresh_units(units: Array[Unit]) -> void:
	for unit: Unit in units:
		if not unit.is_defeated():
			unit.refresh_unit()


func _process_status_effects(units: Array[Unit]) -> void:
	var status_system: Node = get_node_or_null("/root/StatusEffectSystem")
	if status_system == null:
		return
	for unit: Unit in units:
		if not unit.is_defeated():
			status_system.process_turn_start_effects(unit)
