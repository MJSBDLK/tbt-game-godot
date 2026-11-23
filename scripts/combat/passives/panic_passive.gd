## Panic passive: hurt, the left head panics. Below half HP the owner moves
## EXTRA_TILES farther, but can't use support moves: the panicking head drops
## the rocks. Wound him without finishing him and he's harder to escape.
##
## Two query hooks, both read live so they follow HP mid-turn:
## Unit.max_movement_range asks extra_move_tiles, and Unit.is_move_index_locked
## asks locks_move (the menu greys a locked move with the lock scrim).
class_name PanicPassive
extends CombatEffect


const EXTRA_TILES: int = 1


static func is_panicking(unit: Unit) -> bool:
	if unit == null or unit.character_data == null or unit.is_defeated():
		return false
	return unit.current_hp * 2 < unit.character_data.max_hp


func extra_move_tiles(unit: Unit) -> int:
	return EXTRA_TILES if is_panicking(unit) else 0


func locks_move(unit: Unit, move: Move) -> bool:
	return move != null and move.damage_type == Enums.DamageType.SUPPORT and is_panicking(unit)
