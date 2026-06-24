## Phase 2: Maximum — status debuffs can't lower stats below base. Implemented as
## a clamp in StatusEffectSystem._recalculate_stat_modifiers (negative status
## modifiers floored at 0) gated on CharacterData.has_maximum_protection. Not a
## handler — it's a stat-calc rule.
extends GutTest


func _effect(name: String, affected_stat: String, stacks: int) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_type_name = name
	effect.affected_stat = affected_stat
	effect.stacks = stacks
	return effect


func _unit(passives: Array, effects: Array) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.current_hp = 100
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	unit.active_status_effects = effects
	return unit


func test_maximum_nullifies_a_stat_debuff() -> void:
	var unit := _unit(["Maximum"], [_effect("BURN", "strength", 4)])
	StatusEffectSystem.recalculate_stat_modifiers(unit)
	assert_eq(unit.character_data.status_modifier_strength, 0, "debuff floored at 0")


func test_without_maximum_a_debuff_reduces_the_stat() -> void:
	var unit := _unit([], [_effect("BURN", "strength", 4)])
	StatusEffectSystem.recalculate_stat_modifiers(unit)
	assert_lt(unit.character_data.status_modifier_strength, 0, "debuff reduces strength")


func test_maximum_does_not_block_buffs() -> void:
	var unit := _unit(["Maximum"], [_effect("RALLIED", "strength", 4)])
	StatusEffectSystem.recalculate_stat_modifiers(unit)
	assert_gt(unit.character_data.status_modifier_strength, 0, "buffs still apply under Maximum")


func test_has_maximum_protection_reflects_passive() -> void:
	var data := CharacterData.new()
	assert_false(data.has_maximum_protection(), "no passive, no aura → unprotected")
	data.equipped_passives = ["Maximum"]
	assert_true(data.has_maximum_protection(), "Maximum passive → protected")
	data.equipped_passives = []
	data.maximum_from_aura = true
	assert_true(data.has_maximum_protection(), "Stellar aura flag → protected")
