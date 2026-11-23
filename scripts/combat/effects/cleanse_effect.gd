## Removes the move's `onHit.cleanse` effects from the target. Gathered when
## move.cleanse_effects is non-empty. Runs every hit (not gated by apply_status).
## "BUFF" / "DEBUFF" clear whatever sits
## in that slot (one of each per unit), so Pry needn't list every buff by name.
class_name CleanseEffect
extends CombatEffect


const SLOT_NAMES: Dictionary = {
	"BUFF": Enums.EffectCategory.BUFF,
	"DEBUFF": Enums.EffectCategory.DEBUFF,
}


func on_hit(ctx: CombatHitContext) -> void:
	for effect_name: String in ctx.move.cleanse_effects:
		if SLOT_NAMES.has(effect_name):
			_clear_slot(ctx.defender, SLOT_NAMES[effect_name])
		else:
			StatusEffectSystem.remove_status_effect(ctx.defender, effect_name)
		DebugConfig.log_combat("Cleanse: %s removed %s from %s" % [
			ctx.attacker.unit_name, effect_name, ctx.defender.unit_name])


func _clear_slot(unit: Node2D, category: Enums.EffectCategory) -> void:
	var names: Array[String] = []
	for effect: StatusEffect in unit.get("active_status_effects"):
		if effect.category == category:
			names.append(effect.effect_type_name)
	for effect_name: String in names:
		StatusEffectSystem.remove_status_effect(unit, effect_name)
