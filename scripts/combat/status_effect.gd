## Runtime instance of an active status effect on a unit.
## Created by StatusEffectSystem when an effect is applied.
## Effect persists while stacks > 0; ticks down per its config tick_trigger.
class_name StatusEffect
extends RefCounted


static var EMPTY: StatusEffect:
	get:
		var effect := StatusEffect.new()
		effect.effect_type_name = "—"
		return effect


var effect_type_name: String = ""
var category: Enums.EffectCategory = Enums.EffectCategory.DEBUFF
var affected_stat: String = ""
var stacks: int = 0
var caster_level: int = 1
var dot_damage_per_tick: int = 0  # Cached at apply time from caster level + target HP
var hot_heal_per_tick: int = 0    # Cached at apply time from caster level + target HP
var locked_move_indices: Array[int] = []  # For VOID: one entry per stack
