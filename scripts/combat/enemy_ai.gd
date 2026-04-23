## AI behavior for a single enemy unit. Added as a child node to enemy Unit nodes.
## Finds best target, moves toward it, and attacks if in range.
## Called by TurnManager during the enemy phase.
class_name EnemyAI
extends Node


@export var behavior_type: Enums.AIBehaviorType = Enums.AIBehaviorType.AGGRESSIVE
@export var think_delay: float = 0.3
@export var move_delay: float = 0.5
@export var attack_delay: float = 0.5

var _unit: Unit = null


func _ready() -> void:
	_unit = get_parent() as Unit


## Execute this enemy's full turn. Async — caller must await.
func execute_turn() -> void:
	if _unit == null or _unit.is_defeated() or not _unit.can_act:
		return

	DebugConfig.log_ai("AI '%s' thinking..." % _unit.unit_name)
	await get_tree().create_timer(think_delay).timeout

	# Pick a move. Capricious passive → random among usable moves excluding the last used one.
	_assign_move_for_turn()
	if _unit.assigned_move == null:
		DebugConfig.log_ai("AI '%s' has no usable moves, ending turn" % _unit.unit_name)
		_unit.set_acted()
		return

	var target := _find_best_target()
	if target == null:
		DebugConfig.log_ai("AI '%s' found no targets, ending turn" % _unit.unit_name)
		_unit.set_acted()
		return

	# If already in attack range, attack directly
	if _can_attack_target(target):
		await _execute_attack(target)
		_unit.set_acted()
		return

	# Move toward target
	await _move_toward_target(target)

	# Try to attack after moving
	if _can_attack_target(target):
		await _execute_attack(target)

	_unit.set_acted()
	DebugConfig.log_ai("AI '%s' turn complete" % _unit.unit_name)


# =============================================================================
# TARGET EVALUATION
# =============================================================================

func _find_best_target() -> Unit:
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager == null:
		return null

	var player_units: Array[Unit] = turn_manager.get_player_units()
	var best_target: Unit = null
	var best_score: float = -INF

	for player_unit: Unit in player_units:
		if player_unit.is_defeated():
			continue
		var score := _evaluate_target(player_unit)
		if score > best_score:
			best_score = score
			best_target = player_unit

	return best_target


func _evaluate_target(target: Unit) -> float:
	var score: float = 0.0
	var distance := DamageCalculator.get_manhattan_distance(_unit, target)

	# Distance factor — closer is better
	score += 100.0 / float(distance + 1)

	# Health factor — lower health is higher priority
	var health_percent := float(target.current_hp) / float(target.character_data.max_hp)
	score += (1.0 - health_percent) * 50.0

	# Behavior modifiers
	match behavior_type:
		Enums.AIBehaviorType.AGGRESSIVE:
			score += 50.0 / float(distance + 1)
		Enums.AIBehaviorType.TACTICAL:
			score += (1.0 - health_percent) * 75.0
		Enums.AIBehaviorType.DEFENSIVE:
			score += 25.0 / float(distance + 1)

	return score


# =============================================================================
# COMBAT
# =============================================================================

func _can_attack_target(target: Unit) -> bool:
	if _unit.assigned_move == null:
		return false
	if not _unit.assigned_move.has_uses_remaining():
		return false
	var distance := DamageCalculator.get_manhattan_distance(_unit, target)
	return distance <= _unit.assigned_move.attack_range


func _execute_attack(target: Unit) -> void:
	DebugConfig.log_ai("AI '%s' attacking '%s' with '%s'" % [
		_unit.unit_name, target.unit_name, _unit.assigned_move.move_name])
	# Record which move we're about to use so Capricious can avoid picking it again next turn.
	var data: CharacterData = _unit.character_data
	if data != null:
		_unit.last_used_move_index = data.equipped_moves.find(_unit.assigned_move)
	await get_tree().create_timer(attack_delay).timeout
	await _unit.execute_combat_sequence(target, _unit.assigned_move)


func _assign_move_for_turn() -> void:
	var data: CharacterData = _unit.character_data
	if data == null:
		_unit.auto_assign_first_usable_move()
		return

	# Non-Capricious enemies: preserve existing behavior (keep assigned_move if set).
	if not data.has_equipped_passive("Capricious"):
		if _unit.assigned_move == null:
			_unit.auto_assign_first_usable_move()
		return

	# Capricious: pick randomly from usable moves, excluding last_used_move_index.
	var usable_indices: Array[int] = []
	for index: int in range(data.equipped_moves.size()):
		var move: Move = data.equipped_moves[index]
		if move.has_uses_remaining() and not _unit.is_move_index_locked(index):
			usable_indices.append(index)

	if usable_indices.is_empty():
		_unit.assigned_move = null
		return

	var filtered: Array[int] = []
	for idx: int in usable_indices:
		if idx != _unit.last_used_move_index:
			filtered.append(idx)
	var pool: Array[int] = filtered if not filtered.is_empty() else usable_indices
	var chosen: int = pool[randi() % pool.size()]
	_unit.assigned_move = data.equipped_moves[chosen]


# =============================================================================
# MOVEMENT
# =============================================================================

func _move_toward_target(target: Unit) -> void:
	var best_tile := _find_best_move_tile(target)
	if best_tile == null or best_tile == _unit.current_tile:
		DebugConfig.log_ai("AI '%s' cannot move closer to target" % _unit.unit_name)
		return

	_unit.clear_waypoints()
	var success := _unit.add_waypoint(best_tile)
	if not success:
		DebugConfig.log_ai("AI '%s' failed to add waypoint" % _unit.unit_name)
		return

	DebugConfig.log_ai("AI '%s' moving toward '%s'" % [_unit.unit_name, target.unit_name])
	await get_tree().create_timer(move_delay).timeout
	await _unit.execute_planned_movement()


func _find_best_move_tile(target: Unit) -> Tile:
	var movement_tiles := GridManager.get_movement_range(_unit)
	if movement_tiles.is_empty():
		return null

	var target_tile := target.current_tile
	if target_tile == null:
		return null

	var best_tile: Tile = null
	var best_distance: int = 999999

	for tile: Tile in movement_tiles:
		if tile.current_unit != null:
			continue
		var distance := absi(tile.grid_x - target_tile.grid_x) + absi(tile.grid_y - target_tile.grid_y)
		if distance < best_distance:
			best_distance = distance
			best_tile = tile

	return best_tile
