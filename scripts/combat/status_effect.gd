## Runtime instance of an active status effect on a unit.
## Created by StatusEffectSystem when an effect is applied.
class_name StatusEffect
extends RefCounted


var effect_type_name: String = ""
var affected_stat: String = ""
var modifier: int = 0
var remaining_turns: int = 0
var caster_level: int = 1
var locked_move_index: int = -1  # For VOID: which move slot is locked
