## Impulsive passive: leaps in without thinking. Its first attack of the turn is
## more accurate, but its recklessness leaves it exposed — every incoming attack
## is more accurate against it.
##
## A modify_accuracy handler (no wiring). One handler covers both sides:
##   • attacker carries Impulsive + it's their first attack → +accuracy
##   • defender carries Impulsive → incoming attacks get +accuracy (always)
## If an Impulsive unit attacks another, both apply (+40 to that hit).
##
## "First attack" check uses attacks_this_turn <= 1: the counter is 0 before the
## unit has attacked (what the combat preview sees) and 1 during its single attack,
## so <= 1 keeps the previewed hit% and the real roll consistent. (Units act once
## per turn today, so the counter never exceeds 1 in practice.)
class_name ImpulsivePassive
extends CombatEffect


const FIRST_ATTACK_ACCURACY: int = 20
const INCOMING_ACCURACY_PENALTY: int = 20


func modify_accuracy(ctx: CombatHitContext) -> void:
	var attacker: Node2D = ctx.attacker
	if attacker != null:
		var attacker_data: Variant = attacker.get("character_data")
		if attacker_data != null and attacker_data.has_equipped_passive("Impulsive"):
			if int(attacker.get("attacks_this_turn")) <= 1:
				ctx.accuracy += FIRST_ATTACK_ACCURACY

	var defender: Node2D = ctx.defender
	if defender != null:
		var defender_data: Variant = defender.get("character_data")
		if defender_data != null and defender_data.has_equipped_passive("Impulsive"):
			ctx.accuracy += INCOMING_ACCURACY_PENALTY
