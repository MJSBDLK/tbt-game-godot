## Thick Skin: foes land one hit per attack on the owner, whatever their
## athleticism lead. Read in DamageCalculator.calculate_attack_count, which the
## combat preview shares.
extends GutTest


func _fake(athleticism: int, passives: Array = []) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	data.base_athleticism = athleticism
	unit.character_data = data
	unit.current_hp = 20
	return unit


func test_a_much_faster_foe_hits_him_once() -> void:
	var fast := _fake(40)
	assert_eq(DamageCalculator.calculate_attack_count(fast, _fake(10)), 4, "precondition: 4x lead")
	assert_eq(DamageCalculator.calculate_attack_count(fast, _fake(10, ["Thick Skin"])), 1)


func test_his_own_bonus_hits_are_untouched() -> void:
	assert_eq(DamageCalculator.calculate_attack_count(_fake(40, ["Thick Skin"]), _fake(10)), 4)


func test_registry_resolves_thick_skin() -> void:
	assert_true(PassiveRegistry.get_handler("Thick Skin") is ThickSkinPassive)
