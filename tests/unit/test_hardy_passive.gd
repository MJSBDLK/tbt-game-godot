## Hardy: debuffs land one stack lighter, never below one. Buffs are untouched.
## The cut happens in StatusEffectSystem.apply_status_effect_by_name.
extends GutTest


func _unit(passives: Array = []) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	unit.current_hp = 20
	return unit


func test_a_debuff_lands_a_stack_lighter() -> void:
	var hardy := _unit(["Hardy"])
	StatusEffectSystem.apply_status_effect_by_name(null, hardy, "BUGLE", 3)
	assert_eq(StatusEffectSystem.get_effect_stacks(hardy, "BUGLE"), 2)


func test_without_hardy_the_debuff_lands_whole() -> void:
	var plain := _unit()
	StatusEffectSystem.apply_status_effect_by_name(null, plain, "BUGLE", 3)
	assert_eq(StatusEffectSystem.get_effect_stacks(plain, "BUGLE"), 3)


func test_a_one_stack_debuff_still_lands() -> void:
	var hardy := _unit(["Hardy"])
	StatusEffectSystem.apply_status_effect_by_name(null, hardy, "ROOTED", 1)
	assert_eq(StatusEffectSystem.get_effect_stacks(hardy, "ROOTED"), 1, "shorter, never immune")


func test_a_restack_is_lighter_too() -> void:
	var hardy := _unit(["Hardy"])
	StatusEffectSystem.apply_status_effect_by_name(null, hardy, "BURN", 1)
	StatusEffectSystem.apply_status_effect_by_name(null, hardy, "BURN", 2)
	assert_eq(StatusEffectSystem.get_effect_stacks(hardy, "BURN"), 2, "1, then 2 - 1 more")


func test_buffs_are_untouched() -> void:
	var hardy := _unit(["Hardy"])
	StatusEffectSystem.apply_status_effect_by_name(null, hardy, "FORTIFIED", 4)
	assert_eq(StatusEffectSystem.get_effect_stacks(hardy, "FORTIFIED"), 4)


func test_registry_resolves_hardy() -> void:
	assert_true(PassiveRegistry.get_handler("Hardy") is HardyPassive)
