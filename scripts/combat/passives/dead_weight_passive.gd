## Dead Weight passive: when the owner falls, every foe next to it is ROOTED
## for a turn, pinned under the body. Any cause of death counts: a hit, a
## collision, a DoT.
##
## An on_defeated handler (PassiveEffectsSystem.notify_fallen, on
## Unit.unit_defeated while the owner still holds its tile). The one-debuff
## slot rule still applies: a foe already carrying a debuff isn't pinned.
class_name DeadWeightPassive
extends CombatEffect


## 1 stack = 1 lost move (ROOTED latches at the foe's next turn start).
const ROOTED_STACKS: int = 1


func on_defeated(unit: Unit) -> void:
	if unit.current_tile == null:
		return
	for neighbor: Tile in GridManager.get_neighbors(unit.current_tile):
		var foe := neighbor.current_unit as Unit
		if foe == null or foe.is_defeated() or foe.faction == unit.faction:
			continue
		StatusEffectSystem.apply_status_effect_by_name(unit, foe, "ROOTED", ROOTED_STACKS)
