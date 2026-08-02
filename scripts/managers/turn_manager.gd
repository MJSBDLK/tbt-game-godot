## Orchestrates the battle turn loop: Player Phase → Enemy Phase → repeat.
## Handles phase transitions, status effect processing, victory/defeat detection.
## Registered as Autoload "TurnManager".
extends Node


signal player_phase_started(turn_count: int)
signal enemy_phase_started()
signal battle_ended(is_victory: bool)
## Fires once when initialize_battle wires up the unit lists, before
## start_player_phase. Lets SquadManager snapshot pre-battle levels so the
## post-mission level-up report can detect deltas even when level-ups
## happened mid-battle (i.e. via combat XP, not the post-victory roll).
signal battle_started(player_units: Array[Unit])
## Every player unit has acted but Settings.auto_end_turn is OFF: the phase
## is waiting for a manual End Turn. This is the End Turn CTA's trigger —
## with auto-end on, the state ends the phase before anything could fire.
signal player_phase_spent()

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

	battle_started.emit(_player_units)
	start_player_phase()


## Re-enters a battle mid-flight from a save snapshot. Deliberately NOT
## initialize_battle + start_player_phase:
##   - no battle_started — SquadManager's listener refills PP and re-snapshots
##     pre-battle levels, both of which would stomp the restored state (the
##     saved pre-battle snapshot comes back via restore_pre_battle_snapshots).
##   - no phase upkeep — snapshots are captured AFTER upkeep ran (status
##     ticks, refreshes, control locks), so the restored can_act/can_move
##     latches and status stacks already embody it. Re-ticking would
##     double-charge the player a turn of DoT.
## player_phase_started still fires (UI listeners orient on it); SaveManager
## suppresses its own autosave echo for exactly this emission.
func resume_battle(player_units: Array[Unit], enemy_units: Array[Unit],
		saved_turn_count: int) -> void:
	_player_units = player_units
	_enemy_units = enemy_units
	_battle_ended = false
	_is_processing_phase = false
	turn_count = saved_turn_count
	current_phase = Enums.TurnPhase.PLAYER_PHASE

	for unit: Unit in _player_units:
		if not unit.unit_defeated.is_connected(_on_unit_defeated):
			unit.unit_defeated.connect(_on_unit_defeated)
	for unit: Unit in _enemy_units:
		if not unit.unit_defeated.is_connected(_on_unit_defeated):
			unit.unit_defeated.connect(_on_unit_defeated)

	DebugConfig.log_turn("TurnManager: Battle RESUMED at turn %d — %d players, %d enemies" % [
		turn_count, _player_units.size(), _enemy_units.size()])

	var input_manager: Node = get_node_or_null("/root/InputManager")
	if input_manager != null:
		input_manager.enable_input()
		input_manager.deselect_unit()
	var state_manager: Node = get_node_or_null("/root/GameStateManager")
	if state_manager != null:
		state_manager.change_state(Enums.InputState.DEFAULT)

	player_phase_started.emit(turn_count)
	_check_victory_conditions()


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

	if not all_player_units_acted():
		return

	if Settings != null and not Settings.auto_end_turn:
		# Manual mode (Options toggle): the phase waits for End Turn — the
		# system menu's button wears the call-to-action for this state.
		DebugConfig.log_turn(
				"TurnManager: All player units acted — waiting for End Turn (auto-end off)")
		player_phase_spent.emit()
		return

	DebugConfig.log_turn("TurnManager: All player units acted, starting enemy phase")
	start_enemy_phase()


## True when no living player unit can still act — the phase is spent.
func all_player_units_acted() -> bool:
	for unit: Unit in _player_units:
		if not unit.is_defeated() and unit.can_act:
			return false
	return true


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

	var ui_manager: Node = UIManager
	if ui_manager != null:
		await ui_manager.show_phase_transition("PLAYER PHASE - Turn %d" % turn_count, GameColors.PLAYER_UNIT)

	_process_status_effects(_player_units)
	# Scheduled effects tick on the CASTER's faction clock, so this fires
	# strikes queued by PLAYER casts — on victims of EITHER faction (the queue
	# rides on the victim; the clock belongs to the caster's side).
	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.PLAYER, _all_battle_units())
	_refresh_units(_player_units)
	# Control locks (ROOTED/FREEZE) and injury effects both run AFTER refresh so
	# their can_move/can_act=false latches aren't immediately reset. Control locks
	# gate movement for THIS turn, then consume a stack — "1 stack = 1 turn".
	_process_control_locks(_player_units)
	_process_injury_turn_effects(_player_units)
	_process_passive_turn_start(_player_units)

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

	var ui_manager: Node = UIManager
	if ui_manager != null:
		await ui_manager.show_phase_transition("ENEMY PHASE", GameColors.ENEMY_UNIT)

	_process_status_effects(_enemy_units)
	# Enemy-cast scheduled strikes (an enemy Shriek from last turn) land here —
	# the player had exactly one full turn to scatter or cleanse the marks.
	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.ENEMY, _all_battle_units())
	_refresh_units(_enemy_units)
	_process_control_locks(_enemy_units)
	_process_injury_turn_effects(_enemy_units)
	_process_passive_turn_start(_enemy_units)

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

	var ui_manager: Node = UIManager
	if ui_manager != null:
		ui_manager.show_battle_result(is_victory, turn_count, player_units_lost,
			enemies_defeated, _player_units.size(), _enemy_units.size())

	battle_ended.emit(is_victory)


func _on_unit_defeated(_unit: Unit) -> void:
	_check_victory_conditions()


# =============================================================================
# UNIT MANAGEMENT
# =============================================================================

func _refresh_units(units: Array[Unit]) -> void:
	for unit: Unit in units:
		if not unit.is_defeated():
			unit.refresh_unit()
	_audit_tile_occupancy(units, "refresh")


## Diagnostic: verify every alive unit's current_tile registers the unit back.
## Logs a loud warning on mismatch so we can catch occupancy desyncs as they happen.
func _audit_tile_occupancy(units: Array[Unit], phase: String) -> void:
	for unit: Unit in units:
		if unit.is_defeated():
			continue
		if unit.current_tile == null:
			push_warning("OCCUPANCY AUDIT [%s] %s has null current_tile" % [phase, unit.unit_name])
			continue
		if unit.current_tile.current_unit != unit:
			var occupant_name: String = "null"
			if unit.current_tile.current_unit != null:
				occupant_name = unit.current_tile.current_unit.unit_name
			push_warning("OCCUPANCY AUDIT [%s] %s thinks it's on tile [%d,%d] but tile.current_unit=%s" % [
				phase, unit.unit_name, unit.current_tile.grid_x, unit.current_tile.grid_y, occupant_name])


## Every live unit on the board, both factions — scheduled-effect ticks span
## the whole board because a caster's delayed strikes ride on its VICTIMS.
func _all_battle_units() -> Array[Unit]:
	var all: Array[Unit] = []
	for unit: Unit in _player_units:
		if is_instance_valid(unit):
			all.append(unit)
	for unit: Unit in _enemy_units:
		if is_instance_valid(unit):
			all.append(unit)
	return all


func _process_status_effects(units: Array[Unit]) -> void:
	var status_system: Node = get_node_or_null("/root/StatusEffectSystem")
	if status_system == null:
		return
	for unit: Unit in units:
		if not unit.is_defeated():
			status_system.process_turn_start_effects(unit)


func _process_control_locks(units: Array[Unit]) -> void:
	var status_system: Node = get_node_or_null("/root/StatusEffectSystem")
	if status_system == null:
		return
	for unit: Unit in units:
		if not unit.is_defeated():
			status_system.process_control_locks(unit)


## Run each live unit's passive on_turn_start hooks (heals, debuff-clears, ...).
## Runs after status/control/injury so passives react to the settled turn-start
## state. `units` is the faction list, passed through so ally-targeting passives
## (Jury Rig) can find neighbours.
func _process_passive_turn_start(units: Array[Unit]) -> void:
	for unit: Unit in units:
		if unit.is_defeated() or unit.character_data == null:
			continue
		for handler: CombatEffect in PassiveRegistry.get_handlers_for(unit.character_data, unit):
			handler.on_turn_start(unit, units)


func _process_injury_turn_effects(units: Array[Unit]) -> void:
	var injury_system: Node = get_node_or_null("/root/InjurySystem")
	if injury_system == null:
		return
	for unit: Unit in units:
		if not unit.is_defeated():
			injury_system.process_turn_start(unit, turn_count)
