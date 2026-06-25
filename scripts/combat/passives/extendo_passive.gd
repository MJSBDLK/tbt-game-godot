## Extendo passive: +1 attack range for PHYSICAL moves only ("+1 physical range").
## Attacker-side — gathered from the attacker's passives by
## MoveTargeting.effective_attack_range. The "not through impassable" half of the
## description is enforced where the bonus is consumed, not here: any target on a
## tile past the move's base range must have a clear reach
## (GridGeometry.reach_is_clear, forgiving reach-around, terrain-blocked for the
## attacker's type). Special and support moves get nothing.
class_name ExtendoPassive
extends CombatEffect


const RANGE_BONUS: int = 1


func extra_attack_range(move: Move) -> int:
	if move == null or move.damage_type != Enums.DamageType.PHYSICAL:
		return 0
	return RANGE_BONUS
