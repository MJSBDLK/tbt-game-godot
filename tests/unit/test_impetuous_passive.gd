## Phase 2: Impetuous — +20% damage on the first move use of the turn, -10% each
## use after (+20/+10/0/-10...). A modify_damage handler reading attacks_this_turn.
extends GutTest


func _attacker(attacks_this_turn: int, passives: Array = ["Impetuous"]) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	unit.attacks_this_turn = attacks_this_turn
	return unit


func _ctx(attacker: TestFakeUnit, damage: int) -> CombatHitContext:
	var ctx := CombatHitContext.new()
	ctx.attacker = attacker
	ctx.move = Move.new()
	ctx.damage = damage
	return ctx


func test_first_use_plus_20() -> void:
	var ctx := _ctx(_attacker(1), 10)
	ImpetuousPassive.new().modify_damage(ctx)
	assert_eq(ctx.damage, 12)


func test_second_use_plus_10() -> void:
	var ctx := _ctx(_attacker(2), 10)
	ImpetuousPassive.new().modify_damage(ctx)
	assert_eq(ctx.damage, 11)


func test_third_use_neutral() -> void:
	var ctx := _ctx(_attacker(3), 10)
	ImpetuousPassive.new().modify_damage(ctx)
	assert_eq(ctx.damage, 10, "third use is +0%")


func test_fourth_use_penalty() -> void:
	var ctx := _ctx(_attacker(4), 10)
	ImpetuousPassive.new().modify_damage(ctx)
	assert_eq(ctx.damage, 9, "fourth use is -10%")


func test_noop_without_passive() -> void:
	var ctx := _ctx(_attacker(1, []), 10)
	ImpetuousPassive.new().modify_damage(ctx)
	assert_eq(ctx.damage, 10)


func test_registry_resolves_impetuous() -> void:
	assert_true(PassiveRegistry.get_handler("Impetuous") is ImpetuousPassive)
