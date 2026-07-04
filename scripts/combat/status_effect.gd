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
# Slots locked by VOID — one entry per stack, in acquisition order so the most
# recently locked slot pops first when a stack expires. Each entry is a
# Dictionary { "kind": SLOT_MOVE | SLOT_PASSIVE, "index": int } addressing a slot
# in the target's equipped_moves / equipped_passives. VOID draws from a single
# combined move+passive pool (see StatusEffectSystem._assign_void_locks), so one
# stack may lock a move and the next a passive.
const SLOT_MOVE := "move"
const SLOT_PASSIVE := "passive"
var locked_slots: Array[Dictionary] = []
# Element/damage_type of the move that applied this effect. Used for injury
# attribution when a DoT tick deals the killing blow.
var source_element: Enums.ElementalType = Enums.ElementalType.NONE
var source_damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL


## True if the given equipped_moves slot index is locked by this effect.
func is_move_slot_locked(index: int) -> bool:
	return _has_locked_slot(SLOT_MOVE, index)


## True if the given equipped_passives slot index is locked by this effect.
func is_passive_slot_locked(index: int) -> bool:
	return _has_locked_slot(SLOT_PASSIVE, index)


func _has_locked_slot(kind: String, index: int) -> bool:
	for slot: Dictionary in locked_slots:
		if slot.get("kind") == kind and slot.get("index") == index:
			return true
	return false
