## Pathfinder passive: basic navigation, learned on the road. Rough terrain
## (any tile costing more than 1 to enter) costs 1 less, never below 1. Roads
## and open ground are unchanged.
##
## A query hook: GridManager._scaled_tile_cost asks the mover's passives, so
## the movement range, routing, path costs and the AI all agree.
class_name PathfinderPassive
extends CombatEffect


const RELIEF: float = 1.0


func terrain_cost_relief() -> float:
	return RELIEF
