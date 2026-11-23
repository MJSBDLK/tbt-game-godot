## Press On: dropping a foe leaves the killer FORTIFIED for a turn.
extends GutTest


func _unit(passives: Array = []) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	unit.current_hp = 20
	return unit


func _kill_by(killer: TestFakeUnit) -> CombatHitContext:
	var ctx := CombatHitContext.new()
	ctx.attacker = killer
	ctx.defender = _unit()
	ctx.move = MoveData.get_move("Pick")
	return ctx


func test_a_kill_braces_him() -> void:
	var traveller := _unit(["Press On"])
	PressOnPassive.new().on_kill(_kill_by(traveller))
	assert_eq(StatusEffectSystem.get_effect_stacks(traveller, "FORTIFIED"), PressOnPassive.FORTIFIED_STACKS)


func test_without_the_passive_nothing_happens() -> void:
	var traveller := _unit()
	PressOnPassive.new().on_kill(_kill_by(traveller))
	assert_eq(StatusEffectSystem.get_effect_stacks(traveller, "FORTIFIED"), 0)


func test_registry_resolves_press_on() -> void:
	assert_true(PassiveRegistry.get_handler("Press On") is PressOnPassive)
