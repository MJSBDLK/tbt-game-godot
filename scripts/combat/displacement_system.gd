## Resolves on-hit instant displacement (knockback, pull, etc.) for moves.
## Stateless static class. Called by Unit._execute_single_hit after damage lands.
##
## Save model: target fails the save when the chosen dc_source on the hit
## strictly exceeds target.<displace_save_stat>. Deterministic (no roll).
##
## Vector resolution: produces a unit Vector2i in grid space, then steps the
## target one tile at a time up to displace_distance. Stops early on blocked
## tiles per displace_on_blocked policy.
class_name DisplacementSystem
extends RefCounted


const PUSH_TWEEN_PER_TILE: float = 0.08


## Resolve any on-hit displacement on `move`. Awaitable — returns when the
## push tween (if any) completes. Skips silently if move has no displacement
## or target is defeated.
static func resolve(caster: Node2D, target: Node2D, move: Move, hit_damage: int) -> void:
	if move == null or target == null or caster == null:
		return
	if move.displace_distance <= 0:
		# Future hook: on_hit_script for non-displacement custom effects.
		if move.on_hit_script != "":
			DebugConfig.log_combat("DisplacementSystem: on_hit_script '%s' set but script execution not yet implemented" % move.on_hit_script)
		return
	if target.has_method("is_defeated") and target.is_defeated():
		return

	if not _save_failed(target, move, hit_damage):
		DebugConfig.log_combat("DisplacementSystem: %s saved against displacement (%s vs dc=%d)" % [
			target.unit_name, move.displace_save_stat, _resolve_dc(move, hit_damage)])
		return

	var direction := _resolve_vector(caster, target, move)
	if direction == Vector2i.ZERO:
		return

	await _push(target, direction, move.displace_distance, move.displace_on_blocked, caster)


# =============================================================================
# SAVE
# =============================================================================

static func _save_failed(target: Node2D, move: Move, hit_damage: int) -> bool:
	if move.displace_save_stat == "":
		return true  # No save defined — always displaces
	var character_data: Variant = target.get("character_data")
	if character_data == null:
		return true
	var save_value: Variant = character_data.get(move.displace_save_stat)
	if save_value == null:
		DebugConfig.log_error("DisplacementSystem: Unknown save stat '%s' on character_data" % move.displace_save_stat)
		return false
	var dc := _resolve_dc(move, hit_damage)
	return dc > int(save_value)


static func _resolve_dc(move: Move, hit_damage: int) -> int:
	match move.displace_save_dc_source:
		"damage":
			return hit_damage
		"base_power":
			return move.base_power
		_:
			return hit_damage  # Default: total damage dealt


# =============================================================================
# VECTOR
# =============================================================================

static func _resolve_vector(caster: Node2D, target: Node2D, move: Move) -> Vector2i:
	match move.displace_vector:
		"away_from_attacker", "":
			return _away_from(caster, target)
		"toward_attacker":
			return -_away_from(caster, target)
		_:
			DebugConfig.log_error("DisplacementSystem: Unknown displace_vector '%s'" % move.displace_vector)
			return Vector2i.ZERO


## Unit vector pointing from caster's tile to target's tile, axis-aligned.
## On diagonals: prefer the dominant axis; tie breaks to X.
static func _away_from(caster: Node2D, target: Node2D) -> Vector2i:
	var caster_tile: Tile = caster.get("current_tile") as Tile
	var target_tile: Tile = target.get("current_tile") as Tile
	if caster_tile == null or target_tile == null:
		return Vector2i.ZERO
	var dx: int = target_tile.grid_x - caster_tile.grid_x
	var dy: int = target_tile.grid_y - caster_tile.grid_y
	if dx == 0 and dy == 0:
		return Vector2i.ZERO
	if absi(dx) >= absi(dy):
		return Vector2i(signi(dx), 0)
	return Vector2i(0, signi(dy))


# =============================================================================
# MOVEMENT
# =============================================================================

static func _push(target: Node2D, direction: Vector2i, distance: int, on_blocked: String, caster: Node2D) -> void:
	var grid_manager: Node = target.get_node_or_null("/root/GridManager")
	if grid_manager == null:
		DebugConfig.log_error("DisplacementSystem: GridManager autoload not found")
		return

	var current: Tile = target.get("current_tile") as Tile
	if current == null:
		return

	var unit_type: String = _get_target_unit_type(target)
	var tiles_to_step: Array[Tile] = []
	var step_x: int = current.grid_x
	var step_y: int = current.grid_y

	for i: int in range(distance):
		step_x += direction.x
		step_y += direction.y
		var next_tile: Tile = grid_manager.get_tile(step_x, step_y) as Tile
		if next_tile == null:
			# Off-grid — handle later (fall_through, edge bounce, etc.)
			break
		if not next_tile.can_unit_move_to(unit_type):
			# Impassable terrain (wall, water for non-aquatic, etc.). Stop short.
			break
		if next_tile.current_unit != null and next_tile.current_unit != target:
			# Blocked by another unit. Default policy: stop before this tile.
			# Future: bonus_damage / swap / fall_through.
			if on_blocked != "stop":
				DebugConfig.log_combat("DisplacementSystem: on_blocked='%s' not yet implemented, treating as stop" % on_blocked)
			break
		tiles_to_step.append(next_tile)

	if tiles_to_step.is_empty():
		DebugConfig.log_combat("DisplacementSystem: %s pushed but blocked immediately" % target.unit_name)
		return

	DebugConfig.log_combat("DisplacementSystem: %s displaced %d tile(s) by %s" % [
		target.unit_name, tiles_to_step.size(), caster.unit_name])

	await _animate_push(target, tiles_to_step)


## Mirrors GridManager._get_unit_type — derives the terrain-passability key from
## the target's primary elemental type.
static func _get_target_unit_type(target: Node2D) -> String:
	var character_data: Variant = target.get("character_data")
	if character_data == null:
		return ""
	var primary_type: Variant = character_data.get("primary_type")
	if primary_type == null:
		return ""
	return Enums.elemental_type_to_string(primary_type)


static func _animate_push(target: Node2D, tiles: Array[Tile]) -> void:
	for tile: Tile in tiles:
		var tween := target.create_tween()
		tween.tween_property(target, "global_position", tile.global_position, PUSH_TWEEN_PER_TILE)
		await tween.finished
		# move_to_tile reconciles occupancy + z-index. Position is already correct from the tween.
		if target.has_method("move_to_tile"):
			target.call("move_to_tile", tile)
