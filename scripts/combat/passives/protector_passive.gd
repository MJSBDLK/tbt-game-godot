## Protector passive: "Ranged attacks hit this unit instead of units directly
## behind it." The unit body-blocks ranged offensive attacks aimed at an ally
## standing further along the same row/column/diagonal.
##
## All the conditions — axis-aligned line of fire, a cell actually between
## attacker and target (so melee/adjacent shots never qualify, making this
## naturally ranged-only), offensive single-target move, and the bodyguard being
## an ally of the target — are checked once in MoveTargeting.resolve_actual_target.
## So this handler is unconditional: if asked, Protector always intercepts. A
## future bodyguard-style passive could add its own conditions here instead.
class_name ProtectorPassive
extends CombatEffect


func intercepts_attack(_interceptor: Unit, _attacker: Unit, _target: Unit, _move: Move) -> bool:
	return true
