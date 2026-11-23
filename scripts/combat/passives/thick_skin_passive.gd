## Thick Skin passive: foes land one hit on the owner per attack, however far
## their athleticism outruns its own. Its own bonus hits are untouched.
##
## A query hook: DamageCalculator.calculate_attack_count asks the defender's
## passives, so the combat preview shows the single hit too.
class_name ThickSkinPassive
extends CombatEffect


func prevents_bonus_hits() -> bool:
	return true
