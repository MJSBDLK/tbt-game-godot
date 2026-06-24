## Phase 2: Cavalier — the unit's attacking stats (strength, special) can't be
## buffed OR debuffed by moves. A stat-calc rule (like Maximum): the status
## modifier for those stats is forced to 0 in _recalculate_stat_modifiers. Other
## stats are unaffected.
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


func test_blocks_a_buff_on_strength() -> void:
	var unit := _unit(["Cavalier"], [_effect("RALLIED", "strength", 4)])
	StatusEffectSystem.recalculate_stat_modifiers(unit)
	assert_eq(unit.character_data.status_modifier_strength, 0, "buff on attacking stat blocked")


func test_blocks_a_debuff_on_strength() -> void:
	var unit := _unit(["Cavalier"], [_effect("BURN", "strength", 4)])
	StatusEffectSystem.recalculate_stat_modifiers(unit)
	assert_eq(unit.character_data.status_modifier_strength, 0, "debuff on attacking stat blocked")


func test_blocks_special_too() -> void:
	# special is the other attacking stat (no live move targets it yet, so reuse a
	# config with a nonzero pct and point it at special).
	var unit := _unit(["Cavalier"], [_effect("RALLIED", "special", 4)])
	StatusEffectSystem.recalculate_stat_modifiers(unit)
	assert_eq(unit.character_data.status_modifier_special, 0, "special is protected")


func test_does_not_block_non_attacking_stats() -> void:
	var unit := _unit(["Cavalier"], [_effect("FORTIFIED", "defense", 4)])
	StatusEffectSystem.recalculate_stat_modifiers(unit)
	assert_ne(unit.character_data.status_modifier_defense, 0, "defense buff still applies")


func test_without_cavalier_strength_buff_applies() -> void:
	var unit := _unit([], [_effect("RALLIED", "strength", 4)])
	StatusEffectSystem.recalculate_stat_modifiers(unit)
	assert_gt(unit.character_data.status_modifier_strength, 0, "no Cavalier → buff applies")
