## Ghost passive: the unit can move THROUGH enemy-occupied tiles (it still can't
## END its turn on one — that's the universal endpoint rule). Migrated from the
## inline has_equipped_passive("Ghost") check in GridManager._tile_blocks_passage.
class_name GhostPassive
extends CombatEffect


func passes_through_units() -> bool:
	return true
