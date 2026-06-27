## Computes where a set of units can attack — the spatial "danger zone" the threat
## overlay renders. PURE MODEL: returns plain data (cell -> threat count), no
## visuals and no nodes, so the renderer is fully swappable (Lawrence can replace
## the look without touching this). Mirrors MoveTargeting/DamageCalculator: static
## helpers, no state.
##
## A tile is "threatened" by a unit if the unit could attack it THIS turn: from
## any tile it can move to (plus where it currently stands), within the reach of
## its best damaging move. That's the Fire-Emblem danger zone (move + attack).
##
## compute_danger_zone takes ANY unit list, which is what lets the controller do
## every activation mode off one model: all enemies (pass the roster), one enemy
## (pass [unit]), or several selected enemies (pass the subset).
##
## V1 simplifications (deliberate, documented so they're not mistaken for bugs):
##   - Reach is the MAX effective range over the unit's equipped DAMAGING moves
##     (the worst case the player should fear); support-only units have no zone.
##   - Attack reach is a Manhattan ball (get_tiles_within_range); it does NOT run
##     per-tile line-of-sight (Extendo's bonus-tile LoS, walls between). A
##     telegraph should over-warn slightly rather than under-warn, and exact LoS
##     per reachable tile is far more compute than a warning needs.
##   - Move + attack only. The "passive danger zone" (Zone Control's reaction
##     radius, hazards) is a future source layered onto the same map.
class_name ThreatCalculator
extends RefCounted


## Aggregate danger zone for `threateners`: Dictionary of Vector2i cell -> how many
## of those units can attack it. Cells absent from the dict are unthreatened.
## Skips null and defeated units. Pass any list — the whole roster, one unit, or a
## chosen subset — to drive whichever activation mode the controller is in.
static func compute_danger_zone(threateners: Array[Unit]) -> Dictionary:
	var danger: Dictionary = {}
	for unit: Unit in threateners:
		if unit == null or unit.is_defeated():
			continue
		for cell: Vector2i in threatened_cells(unit):
			danger[cell] = int(danger.get(cell, 0)) + 1
	return danger


## Every cell `unit` could attack this turn (move + attack), as the keys of a
## Dictionary (used as a set). Empty when the unit has no damaging move, no tile,
## or otherwise can't threaten anything.
static func threatened_cells(unit: Unit) -> Dictionary:
	var cells: Dictionary = {}
	if unit == null or unit.current_tile == null:
		return cells
	var reach: int = max_damaging_reach(unit)
	if reach <= 0:
		return cells
	# Where the unit could stand when it attacks: every move-reachable tile plus
	# its current tile (it can attack without moving). get_movement_range excludes
	# the start tile, so add it explicitly.
	var stands: Array[Tile] = GridManager.get_movement_range(unit)
	stands.append(unit.current_tile)
	for stand: Tile in stands:
		for target: Tile in GridManager.get_tiles_within_range(stand, reach):
			cells[Vector2i(target.grid_x, target.grid_y)] = true
	return cells


## The unit's longest reach among its equipped damaging moves (0 if support-only
## or dataless). Honors range passives via MoveTargeting.effective_attack_range,
## so an Extendo enemy's danger zone is correctly one tile larger.
static func max_damaging_reach(unit: Unit) -> int:
	if unit == null or unit.character_data == null:
		return 0
	var best: int = 0
	for move: Move in unit.character_data.equipped_moves:
		if move == null or move.damage_type == Enums.DamageType.SUPPORT:
			continue
		best = maxi(best, MoveTargeting.effective_attack_range(unit, move))
	return best
