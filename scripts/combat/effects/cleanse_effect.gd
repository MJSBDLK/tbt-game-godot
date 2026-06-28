## Removes the move's `onHit.cleanse` effects from the target. Gathered when
## move.cleanse_effects is non-empty. Runs every hit (not gated by apply_status),
## mirroring the old Unit._apply_cleanse.
class_name CleanseEffect
extends CombatEffect


func on_hit(ctx: CombatHitContext) -> void:
	for effect_name: String in ctx.move.cleanse_effects:
		StatusEffectSystem.remove_status_effect(ctx.defender, effect_name)
		DebugConfig.log_combat("Cleanse: %s removed %s from %s" % [
			ctx.attacker.unit_name, effect_name, ctx.defender.unit_name])
