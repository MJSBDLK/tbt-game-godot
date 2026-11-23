## Outburst passive: surrounded, the angry head swings once more. With
## FOES_TO_SET_OFF foes standing next to the owner, its multi-hit moves land
## one more hit. Crowding him feeds him; come one at a time, or from range.
##
## A query hook: DamageCalculator.volley_hits asks the attacker's passives,
## so the forecast, the AI and the swing agree. Counted when the swing starts.
class_name OutburstPassive
extends CombatEffect


const FOES_TO_SET_OFF: int = 2


func extra_volley_hits(attacker: Node2D, move: Move) -> int:
	assert(move.hits > 1, "Outburst is only asked about multi-hit moves")
	var tile: Variant = attacker.get("current_tile")
	if tile == null:
		return 0
	var foes := 0
	for neighbor: Tile in GridManager.get_neighbors(tile):
		var occupant: Variant = neighbor.current_unit
		if occupant is Unit and not occupant.is_defeated() \
				and occupant.faction != attacker.get("faction"):
			foes += 1
	return 1 if foes >= FOES_TO_SET_OFF else 0
