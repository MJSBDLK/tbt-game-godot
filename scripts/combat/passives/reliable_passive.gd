## Reliable passive: a large flat accuracy bonus on the attacker's hits —
## "effectively guaranteeing hits". Attacker-side; gates on ctx.attacker carrying
## the passive. Migrated from DamageCalculator._attacker_accuracy_bonus.
class_name ReliablePassive
extends CombatEffect


func modify_accuracy(ctx: CombatHitContext) -> void:
	var attacker: Node2D = ctx.attacker
	if attacker == null:
		return
	var data: Variant = attacker.get("character_data")
	if data != null and data.has_equipped_passive("Reliable"):
		ctx.accuracy += DamageCalculator.RELIABLE_ACCURACY_BONUS
