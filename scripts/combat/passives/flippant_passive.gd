## Flippant passive: dismissive of "advantages" — when an incoming attack is
## super-effective against this unit, it's harder to land (-accuracy) but hits
## harder when it does (+damage). Defender-side; gates on ctx.defender carrying
## Flippant and the move being super-effective (type multiplier > 1).
##
## One handler, two hooks: modify_accuracy (avoid) + modify_damage. Both run with
## no wiring — hit_chance_pct gathers passives for accuracy, and the pipeline
## gathers them for damage. Computes effectiveness via DamageCalculator, so no
## ctx change is needed.
class_name FlippantPassive
extends CombatEffect


const EXTRA_DAMAGE_PCT: float = 25.0
const ACCURACY_PENALTY: int = 25


func modify_accuracy(ctx: CombatHitContext) -> void:
	if _super_effective_vs_flippant(ctx):
		ctx.accuracy -= ACCURACY_PENALTY


func modify_damage(ctx: CombatHitContext) -> void:
	if _super_effective_vs_flippant(ctx):
		ctx.damage = maxi(1, roundi(ctx.damage * (1.0 + EXTRA_DAMAGE_PCT / 100.0)))


func _super_effective_vs_flippant(ctx: CombatHitContext) -> bool:
	if ctx.attacker == null or ctx.defender == null or ctx.move == null:
		return false
	var data: Variant = ctx.defender.get("character_data")
	if data == null or not data.has_equipped_passive("Flippant"):
		return false
	return DamageCalculator.get_type_effectiveness(ctx.attacker, ctx.defender, ctx.move) > 1.0
