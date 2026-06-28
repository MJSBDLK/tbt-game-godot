## Phase 2: Flippant — super-effective attacks against this unit get -accuracy but
## +damage. Defender-side; one handler, two hooks. Uses a real super-effective
## matchup (Air → Void is "ouch" in the type chart) and a neutral one (Air → Simple).
extends GutTest


func _unit(passives: Array, primary: Enums.ElementalType) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	data.primary_type = primary
	data.secondary_type = Enums.ElementalType.NONE
	unit.character_data = data
	return unit


func _ctx(attacker: TestFakeUnit, defender: TestFakeUnit, element: Enums.ElementalType) -> CombatHitContext:
	var ctx := CombatHitContext.new()
	ctx.attacker = attacker
	ctx.defender = defender
	var move := Move.new()
	move.element_type = element
	ctx.move = move
	ctx.damage = 8
	ctx.accuracy = 90.0
	return ctx


# Super-effective vs a Flippant unit: +25% damage, -25 accuracy.
func test_super_effective_boosts_damage() -> void:
	var ctx := _ctx(_unit([], Enums.ElementalType.AIR), _unit(["Flippant"], Enums.ElementalType.VOID), Enums.ElementalType.AIR)
	FlippantPassive.new().modify_damage(ctx)
	assert_eq(ctx.damage, 10, "8 * 1.25 = 10")


func test_super_effective_reduces_accuracy() -> void:
	var ctx := _ctx(_unit([], Enums.ElementalType.AIR), _unit(["Flippant"], Enums.ElementalType.VOID), Enums.ElementalType.AIR)
	FlippantPassive.new().modify_accuracy(ctx)
	assert_almost_eq(ctx.accuracy, 65.0, 0.001, "90 - 25 avoid")


# Neutral matchup (Air → Simple is unlisted): no effect even with Flippant.
func test_neutral_matchup_no_effect() -> void:
	var ctx := _ctx(_unit([], Enums.ElementalType.AIR), _unit(["Flippant"], Enums.ElementalType.SIMPLE), Enums.ElementalType.AIR)
	FlippantPassive.new().modify_damage(ctx)
	FlippantPassive.new().modify_accuracy(ctx)
	assert_eq(ctx.damage, 8, "neutral → no damage bonus")
	assert_almost_eq(ctx.accuracy, 90.0, 0.001, "neutral → no accuracy penalty")


# Super-effective but the defender lacks Flippant: no effect.
func test_no_passive_no_effect() -> void:
	var ctx := _ctx(_unit([], Enums.ElementalType.AIR), _unit([], Enums.ElementalType.VOID), Enums.ElementalType.AIR)
	FlippantPassive.new().modify_damage(ctx)
	FlippantPassive.new().modify_accuracy(ctx)
	assert_eq(ctx.damage, 8)
	assert_almost_eq(ctx.accuracy, 90.0, 0.001)


func test_registry_resolves_flippant() -> void:
	assert_true(PassiveRegistry.get_handler("Flippant") is FlippantPassive)
