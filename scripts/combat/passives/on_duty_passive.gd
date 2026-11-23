## On Duty passive: the flaw with a niche. The owner never ends up more than
## LEASH_TILES from where its turn began. It walks at most that far, and no
## push, pull or throw carries it past the line: it stops there, with no
## collision. Kiteable, but it can't be dragged from a door or knocked off a
## ledge.
##
## A query hook (leash_tiles) that GridManager reads for walking and for
## displacement_allows, which every DisplacementSystem resolver asks.
## on_turn_start pins the line's centre on Unit.turn_start_cell.
class_name OnDutyPassive
extends CombatEffect


## At 3 or more, no single displacement in the game reaches the line and the
## niche is gone.
const LEASH_TILES: int = 1


func leash_tiles() -> int:
	return LEASH_TILES


func on_turn_start(unit: Unit, _allies: Array[Unit]) -> void:
	if unit.current_tile != null:
		unit.turn_start_cell = Vector2i(unit.current_tile.grid_x, unit.current_tile.grid_y)
