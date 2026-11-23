## Wary: hits on the owner never crit, and a banked crit isn't spent on them.
extends GutTest


func _unit(passives: Array = []) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	unit.current_hp = 20
	return unit


func _banked_hit(defender: TestFakeUnit) -> CombatHitContext:
	var attacker := _unit()
	attacker.pending_crit = true
	var ctx := CombatHitContext.new()
	ctx.attacker = attacker
	ctx.defender = defender
	ctx.move = MoveData.get_move("Klunk")
	ctx.damage = 10
	return ctx


func test_a_banked_crit_lands_on_anyone_else() -> void:
	var ctx := _banked_hit(_unit())
	CritEffect.new().modify_damage(ctx)
	assert_true(ctx.is_crit)


func test_a_wary_defender_is_never_crit() -> void:
	var ctx := _banked_hit(_unit(["Wary"]))
	CritEffect.new().modify_damage(ctx)
	assert_false(ctx.is_crit)
	assert_eq(ctx.damage, 10)


func test_the_banked_crit_waits_for_another_target() -> void:
	var ctx := _banked_hit(_unit(["Wary"]))
	CritEffect.new().modify_damage(ctx)
	assert_true(ctx.attacker.pending_crit, "not wasted on someone who saw it coming")


func test_registry_resolves_wary() -> void:
	assert_true(PassiveRegistry.get_handler("Wary") is WaryPassive)
