## Grateful: buffs land on him one stack heavier, up to the buff's cap
## (StatusEffectSystem.apply_status_effect_by_name asks deepens_buffs).
## Hardy's mirror: debuffs are untouched.
extends GutTest


func _unit(passives: Array = []) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.current_hp = 20
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	return unit


func test_a_buff_lands_a_stack_heavier() -> void:
	var thumps := _unit(["Grateful"])
	StatusEffectSystem.apply_status_effect_by_name(thumps, thumps, "FORTIFIED", 2)
	assert_eq(StatusEffectSystem.get_effect_stacks(thumps, "FORTIFIED"), 3)


func test_a_restack_lands_heavier_too() -> void:
	var thumps := _unit(["Grateful"])
	StatusEffectSystem.apply_status_effect_by_name(thumps, thumps, "RALLIED", 1)
	StatusEffectSystem.apply_status_effect_by_name(thumps, thumps, "RALLIED", 1)
	assert_eq(StatusEffectSystem.get_effect_stacks(thumps, "RALLIED"), 4)


func test_the_cap_still_holds() -> void:
	var thumps := _unit(["Grateful"])
	var squash := _unit()
	StatusEffectSystem.apply_status_effect_by_name(squash, thumps, "COVERED", 1)
	assert_eq(StatusEffectSystem.get_effect_stacks(thumps, "COVERED"), 1, "Covered holds one stack")
	var braced := _unit(["Grateful"])
	StatusEffectSystem.apply_status_effect_by_name(braced, braced, "FORTIFIED", 4)
	assert_eq(StatusEffectSystem.get_effect_stacks(braced, "FORTIFIED"), 4, "Fortified tops out at 4")


func test_debuffs_land_as_they_are() -> void:
	var thumps := _unit(["Grateful"])
	StatusEffectSystem.apply_status_effect_by_name(thumps, thumps, "GRAVITY", 2)
	assert_eq(StatusEffectSystem.get_effect_stacks(thumps, "GRAVITY"), 2)


func test_without_the_passive_a_buff_lands_as_cast() -> void:
	var other := _unit()
	StatusEffectSystem.apply_status_effect_by_name(other, other, "FORTIFIED", 2)
	assert_eq(StatusEffectSystem.get_effect_stacks(other, "FORTIFIED"), 2)
