## Whatever the target holds in a status slot moves to the user, stacks and
## all: Shake Down pockets the target's buff. Gathered when move.steal_slots is
## non-empty; runs every hit, like cleanse (a second hit finds the slot empty).
## The stolen status replaces whatever the user had in that slot.
class_name StealEffect
extends CombatEffect


func on_hit(ctx: CombatHitContext) -> void:
	if ctx.attacker == null or ctx.defender == null or ctx.attacker == ctx.defender:
		return
	for slot: String in ctx.move.steal_slots:
		var category: Enums.EffectCategory = CleanseEffect.SLOT_NAMES[slot]
		var taken: Array[StatusEffect] = []
		for effect: StatusEffect in ctx.defender.get("active_status_effects"):
			if effect.category == category:
				taken.append(effect)
		for effect: StatusEffect in taken:
			StatusEffectSystem.remove_status_effect(ctx.defender, effect.effect_type_name)
			StatusEffectSystem.apply_status_effect_by_name(ctx.attacker, ctx.attacker,
					effect.effect_type_name, effect.stacks, true)
			DebugConfig.log_combat("Steal: %s took %s (%d) from %s" % [
				ctx.attacker.unit_name, effect.effect_type_name, effect.stacks, ctx.defender.unit_name])
