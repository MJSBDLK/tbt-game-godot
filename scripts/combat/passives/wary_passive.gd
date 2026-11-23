## Wary passive: robbed on the road before, so nothing catches this unit off
## guard. Hits on it never crit. A banked crit (Focus, Uppercut) isn't spent on
## it; the attacker keeps it for a target that can be crit.
##
## A query hook: CritEffect.modify_damage asks the defender's passives.
class_name WaryPassive
extends CombatEffect


func prevents_crits() -> bool:
	return true
