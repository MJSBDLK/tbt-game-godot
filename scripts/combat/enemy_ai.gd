## AI behavior for a single enemy unit. Added as a child node to enemy Unit nodes.
## Finds best target, moves toward it, and attacks if in range — choosing the
## move per target (best expected damage), not swinging whatever sits in the top
## slot. Called by TurnManager during the enemy phase.
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
	_prefer_damaging_counter_move()


## Spawn arms the first usable move, and the armed move is what this unit
## counters with — a support move there means no counter until the AI first
## swings. Arm the first DAMAGING move instead, when there is one.
func _prefer_damaging_counter_move() -> void:
	if _unit == null or (_unit.assigned_move != null
			and _unit.assigned_move.damage_type != Enums.DamageType.SUPPORT):
		return
	for move: Move in _unit.get_usable_moves():
		if move.damage_type != Enums.DamageType.SUPPORT:
			_unit.assigned_move = move
			return


## Execute this enemy's full turn. Async — caller must await.
func execute_turn() -> void:
	if _unit == null or _unit.is_defeated() or not _unit.can_act:
		return

	DebugConfig.log_ai("AI '%s' thinking..." % _unit.unit_name)
	# The camera brings an off-screen enemy into view before it pulses, then
	# trails its walk.
	_camera_follow(true)
	# Quick scale pulse on the sprite so the player can tell which enemy is
	# acting when there are several on screen. Fits inside think_delay so the
	# AI doesn't visibly stall waiting for it to finish.
	_pulse_active_indicator()
	await get_tree().create_timer(think_delay).timeout

	await _act()

	_camera_follow(false)
	_unit.set_acted()
	DebugConfig.log_ai("AI '%s' turn complete" % _unit.unit_name)


## Walk and swing. Every way out returns to execute_turn, which releases the
## camera and marks the unit acted.
func _act() -> void:
	if _unit.get_usable_moves().is_empty():
		DebugConfig.log_ai("AI '%s' has no usable moves, ending turn" % _unit.unit_name)
		return
	if _randomizes_move():
		_roll_capricious_move()

	var target := _find_best_target()
	if target == null:
		DebugConfig.log_ai("AI '%s' found no targets, ending turn" % _unit.unit_name)
		return

	if _pick_attack_move(target) == null:
		await _move_toward_target(target)
		# The walk can fall short of the chosen target yet end beside another
		# player unit: swing at whoever's in reach rather than stand idle. Not
		# when challenged — the challenge names the only legal target.
		if _pick_attack_move(target) == null and _active_challenger() == null:
			var in_reach := _find_best_target(true)
			if in_reach != null:
				target = in_reach

	var move := _pick_attack_move(target)
	if move != null:
		await _execute_attack(target, move)


# =============================================================================
# TARGET EVALUATION
# =============================================================================

## `in_reach_only` narrows the field to units this one can hit from where it
## stands — the fallback after a walk that fell short.
func _find_best_target(in_reach_only: bool = false) -> Unit:
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
		if in_reach_only and _pick_attack_move(player_unit) == null:
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

## The move this unit would swing at `target` from where it stands, or null.
## Capricious swings only what it rolled. Everyone else takes the usable
## damaging move with the best expected damage (damage × hit chance; slot order
## breaks ties), so a support move in the top slot no longer benches the kit.
## can_target folds in effective range + Extendo's reach LoS, so the AI honors
## range passives and never "attacks through" a wall on a bonus tile.
func _pick_attack_move(target: Unit) -> Move:
	if _randomizes_move():
		var rolled: Move = _unit.assigned_move
		if rolled != null and rolled.has_uses_remaining() \
				and MoveTargeting.can_target(_unit, target, rolled):
			return rolled
		return null
	var best_move: Move = null
	var best_expected: float = -1.0
	for move: Move in _unit.get_usable_moves():
		if move.damage_type == Enums.DamageType.SUPPORT \
				or not MoveTargeting.can_target(_unit, target, move):
			continue
		var expected: float = DamageCalculator.calculate_damage(_unit, target, move) \
				* DamageCalculator.hit_chance_pct(_unit, target, move) / 100.0
		if expected > best_expected:
			best_expected = expected
			best_move = move
	return best_move


func _execute_attack(target: Unit, move: Move) -> void:
	assert(MoveTargeting.can_target(_unit, target, move),
			"EnemyAI: '%s' swinging '%s' at a target it can't reach" % [
				_unit.unit_name, move.move_name])
	DebugConfig.log_ai("AI '%s' attacking '%s' with '%s'" % [
		_unit.unit_name, target.unit_name, move.move_name])
	# The swung move stays armed: it's what this unit counters with next phase,
	# and what its preview panel marks.
	_unit.assigned_move = move
	# Record which move we're about to use so Capricious can avoid picking it again next turn.
	var data: CharacterData = _unit.character_data
	if data != null:
		_unit.last_used_move_index = data.equipped_moves.find(move)
	# Frame the exchange the way the player's own attacks are framed.
	_camera_follow(false)
	var camera := _camera()
	if camera != null:
		camera.center_on((_unit.global_position + target.global_position) / 2.0)
	# Float the move name above the attacker BEFORE the swing so the player has
	# a beat to read it. The attack_delay timer is what gives them the time.
	_unit.spawn_text_callout(move.move_name.to_upper(), _move_callout_color())
	await get_tree().create_timer(attack_delay).timeout
	await _unit.execute_combat_sequence(target, move)


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


## Move-randomizer passives (Capricious) re-roll each turn and swing what they
## rolled. Capability is read from the passive handlers, not a name string.
func _randomizes_move() -> bool:
	for handler: CombatEffect in PassiveRegistry.get_handlers_for(_unit.character_data, _unit):
		if handler.randomizes_move():
			return true
	return false


## Capricious: a random usable move, excluding the last one used.
func _roll_capricious_move() -> void:
	var data: CharacterData = _unit.character_data
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


# =============================================================================
# CAMERA
# =============================================================================

## Null outside a battle scene (and in tests) — every caller tolerates that.
func _camera() -> CameraController:
	return SceneRouter.get_world_camera() as CameraController


## Hand the camera this unit to keep on screen, or take it back. Only releases
## a follow this unit holds.
func _camera_follow(enabled: bool) -> void:
	var camera := _camera()
	if camera == null:
		return
	if enabled:
		camera.follow_target = _unit
	elif camera.follow_target == _unit:
		camera.follow_target = null


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
