## Low Profile passive: harder to hit at range — adds avoid against RANGED moves
## (attack_range > 1) only. Defender-side; gates on ctx.defender carrying the
## passive. Migrated from DamageCalculator._defender_avoid_bonus.
class_name LowProfilePassive
extends CombatEffect


func modify_accuracy(ctx: CombatHitContext) -> void:
	if ctx.move == null or ctx.move.attack_range <= 1:
		return
	var defender: Node2D = ctx.defender
	if defender == null:
		return
	var data: Variant = defender.get("character_data")
	if data != null and data.has_equipped_passive("Low Profile"):
		ctx.accuracy -= DamageCalculator.LOW_PROFILE_AVOID_BONUS
