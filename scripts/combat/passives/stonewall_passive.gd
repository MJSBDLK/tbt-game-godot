## Stonewall passive: a foe that steps next to the owner stops there. A foe that
## starts its turn there may walk away, but nothing walks past. It stops
## movement and deals nothing.
##
## A query hook: GridManager's movement range and pathfinding ask it, so the
## player's range, the threat zones and the AI all agree.
class_name StonewallPassive
extends CombatEffect


func exerts_zone_of_control() -> bool:
	return true
