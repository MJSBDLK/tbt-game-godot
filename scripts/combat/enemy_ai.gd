## AI behavior for a single enemy unit. Added as a child node to enemy Unit nodes.
## Finds best target, moves toward it, and attacks if in range.
## Called by TurnManager during the enemy phase.
class_name EnemyAI
extends Node


## Sentinel route cost for "no terrain path to the target from this tile."
const UNREACHABLE: int = 0x7FFFFFFF

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
	# Quick scale pulse on the sprite so the player can tell which enemy is
	# acting when there are several on screen. Fits inside think_delay so the
	# AI doesn't visibly stall waiting for it to finish.
	_pulse_active_indicator()
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
	# CHALLENGED (Phase 4): a challenged unit answers the challenge. While the
	# status holds and the challenger lives, targeting locks onto them — no
	# scoring, no second-guessing. The compulsion ends when the status expires
	# or the challenger falls.
	var challenger := _active_challenger()
	if challenger != null:
		DebugConfig.log_ai("AI '%s' is CHALLENGED — locked onto '%s'" % [
			_unit.unit_name, challenger.unit_name])
		return challenger

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


## The live challenger compelling this unit, or null. Reads the CHALLENGED
## status' source_unit (stamped by StatusEffectSystem at apply time; re-pointed
## on restack so the newest roar wins; restored from saves via grid cell).
func _active_challenger() -> Unit:
	for effect: StatusEffect in _unit.active_status_effects:
		if effect.effect_type_name != "CHALLENGED" or effect.stacks <= 0:
			continue
		var source := effect.source_unit as Unit
		if source != null and is_instance_valid(source) and not source.is_defeated():
			return source
	return null


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
	# can_target folds in effective range + Extendo's reach LoS, so the AI honors
	# range passives and never "attacks through" a wall on a bonus tile.
	return MoveTargeting.can_target(_unit, target, _unit.assigned_move)


func _execute_attack(target: Unit) -> void:
	DebugConfig.log_ai("AI '%s' attacking '%s' with '%s'" % [
		_unit.unit_name, target.unit_name, _unit.assigned_move.move_name])
	# Record which move we're about to use so Capricious can avoid picking it again next turn.
	var data: CharacterData = _unit.character_data
	if data != null:
		_unit.last_used_move_index = data.equipped_moves.find(_unit.assigned_move)
	# Float the move name above the attacker BEFORE the swing so the player has
	# a beat to read it. The attack_delay timer is what gives them the time.
	_unit.spawn_text_callout(_unit.assigned_move.move_name.to_upper(), _move_callout_color())
	await get_tree().create_timer(attack_delay).timeout
	await _unit.execute_combat_sequence(target, _unit.assigned_move)


## Color for the move-name callout. Uses the move's elemental-type foreground
## color so the player also gets a hint about matchup before the hit lands.
## Falls back to the enemy-faction red for typeless moves.
func _move_callout_color() -> Color:
	if _unit.assigned_move != null and _unit.assigned_move.element_type != Enums.ElementalType.NONE:
		return GameColors.get_move_chip_foreground(_unit.assigned_move.element_type)
	return GameColors.ENEMY_UNIT


## One-shot scale pulse on the sprite — 1.0 → 1.15 → 1.0 over ~0.3s. Tells the
## player "this enemy is up next." Uses sprite scale (not modulate) so it
## doesn't fight with hit-flash or the acted/active modulate state.
func _pulse_active_indicator() -> void:
	if _unit == null:
		return
	var sprite: Sprite2D = _unit.get_node_or_null("Sprite2D")
	if sprite == null:
		return
	var tween := _unit.create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN)


func _assign_move_for_turn() -> void:
	var data: CharacterData = _unit.character_data
	if data == null:
		_unit.auto_assign_first_usable_move()
		return

	# Move-randomizer passives (Capricious) re-pick each turn; others keep their
	# assignment. Capability is read from the passive handlers, not a name string.
	var should_randomize: bool = false
	for handler: CombatEffect in PassiveRegistry.get_handlers_for(data, _unit):
		if handler.randomizes_move():
			should_randomize = true
			break
	if not should_randomize:
		if _unit.assigned_move == null:
			_unit.auto_assign_first_usable_move()
		return

	# Randomize: pick from usable moves, excluding last_used_move_index.
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
	var chosen: int = pool[GameRng.randi() % pool.size()]
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

	# Score candidates by REAL route distance — a terrain-aware cost field
	# flooded outward from the target — not straight-line Manhattan. Crow-flies
	# scoring walked the AI into the dead end nearest the target and parked it
	# against obstacle walls instead of routing around them.
	var route_costs: Dictionary = GridManager.get_approach_cost_field(target_tile, _unit)

	var best_tile: Tile = null
	var best_route_cost: int = UNREACHABLE
	var best_manhattan: int = UNREACHABLE

	for tile: Tile in movement_tiles:
		if tile.current_unit != null:
			continue
		var route_cost: int = route_costs.get(tile, UNREACHABLE)
		# Manhattan breaks route ties, and carries the whole decision when no
		# terrain route exists (e.g. target on an island) so the enemy still
		# closes the gap instead of standing frozen.
		var manhattan := absi(tile.grid_x - target_tile.grid_x) + absi(tile.grid_y - target_tile.grid_y)
		if route_cost < best_route_cost \
				or (route_cost == best_route_cost and manhattan < best_manhattan):
			best_route_cost = route_cost
			best_manhattan = manhattan
			best_tile = tile

	return best_tile
