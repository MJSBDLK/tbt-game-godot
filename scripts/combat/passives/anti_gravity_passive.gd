## Anti-Gravity passive: nothing weighs them down — each active debuff has a 50%
## chance to shake off at the start of the unit's turn. Buffs are never touched.
##
## A turn-start handler (dispatched from TurnManager._process_passive_turn_start,
## which runs AFTER status processing, so a debuff ticks this turn before it gets
## its 50% roll to clear). Each debuff rolls independently. Also a member of Glib's
## HUMOR_PASSIVES in-group (breezy, irreverent).
class_name AntiGravityPassive
extends CombatEffect


const CLEAR_CHANCE: float = 0.5


func on_turn_start(unit: Unit, _allies: Array[Unit]) -> void:
	# Collect debuff names first — don't mutate active_status_effects while iterating.
	var debuff_names: Array[String] = []
	for effect: StatusEffect in unit.active_status_effects:
		if effect.category == Enums.EffectCategory.DEBUFF:
			debuff_names.append(effect.effect_type_name)

	for effect_name: String in debuff_names:
		if GameRng.randf() < CLEAR_CHANCE:
			StatusEffectSystem.remove_status_effect(unit, effect_name)
