## Single source of truth for "what tiles/units can this move target?".
## Both the action menu (which moves to surface) and the input manager (which
## tiles to highlight + accept clicks on during targeting mode) call into here.
##
## Drift between these two filters is how the "First Aid hidden from menu" and
## "can't target self with First Aid" bugs both snuck in. New targeting rules
## (range modifiers, line-of-sight, AOE, terrain gates) all land here.
class_name MoveTargeting
extends RefCounted


## Returns true if `target` is a legal recipient of `move` cast by `attacker`,
## ignoring range/grid considerations — pure faction + self filter.
static func is_valid_target(target: Unit, attacker: Unit, move: Move) -> bool:
	if target == null or attacker == null or move == null:
		return false
	if target.is_defeated():
		return false
	if move.targets_allies():
		if target.faction != attacker.faction:
			return false
		if move.target_type == Enums.TargetType.ALLY_NOT_SELF and target == attacker:
			return false
		return true
	return target.faction != attacker.faction


## Returns every tile within `move`'s range whose occupant is a valid target.
## Self-targetable moves (ALLY, SELF) include the attacker's own tile, which
## the grid range helper otherwise excludes.
static func get_valid_target_tiles(attacker: Unit, move: Move) -> Array[Tile]:
	var tiles: Array[Tile] = []
	if attacker == null or move == null or attacker.current_tile == null:
		return tiles

	var candidates := GridManager.get_tiles_within_range(attacker.current_tile, move.attack_range)
	if move.target_type == Enums.TargetType.ALLY or move.target_type == Enums.TargetType.SELF:
		candidates.append(attacker.current_tile)

	for tile: Tile in candidates:
		if tile.current_unit == null or not tile.current_unit is Unit:
			continue
		var target := tile.current_unit as Unit
		if is_valid_target(target, attacker, move):
			tiles.append(tile)
	return tiles
