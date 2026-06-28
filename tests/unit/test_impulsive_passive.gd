## Phase 2: Impulsive — first attack of the turn is +20 accurate; incoming attacks
## against this unit are +20 accurate (the reckless drawback). A modify_accuracy
## handler reusing attacks_this_turn.
extends GutTest


func _unit(passives: Array = [], attacks_this_turn: int = 0) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	unit.attacks_this_turn = attacks_this_turn
	return unit


func _ctx(attacker: TestFakeUnit, defender: TestFakeUnit, base_acc: float = 50.0) -> CombatHitContext:
	var ctx := CombatHitContext.new()
	ctx.attacker = attacker
	ctx.defender = defender
	ctx.move = Move.new()
	ctx.accuracy = base_acc
	return ctx


# =============================================================================
# Attacker side: first-attack accuracy bonus
# =============================================================================

func test_first_attack_bonus_applies_pre_attack() -> void:
	# attacks_this_turn 0 = what the combat preview sees before the swing.
	var ctx := _ctx(_unit(["Impulsive"], 0), _unit())
	ImpulsivePassive.new().modify_accuracy(ctx)
	assert_almost_eq(ctx.accuracy, 70.0, 0.001, "50 + 20 first-attack")


func test_first_attack_bonus_applies_during_attack() -> void:
	# attacks_this_turn 1 = the actual first attack. Same result as preview.
	var ctx := _ctx(_unit(["Impulsive"], 1), _unit())
	ImpulsivePassive.new().modify_accuracy(ctx)
	assert_almost_eq(ctx.accuracy, 70.0, 0.001)


func test_no_first_attack_bonus_after_first() -> void:
	var ctx := _ctx(_unit(["Impulsive"], 2), _unit())
	ImpulsivePassive.new().modify_accuracy(ctx)
	assert_almost_eq(ctx.accuracy, 50.0, 0.001, "second+ attack gets no bonus")


# =============================================================================
# Defender side: incoming attacks are more accurate
# =============================================================================

func test_incoming_accuracy_penalty() -> void:
	var ctx := _ctx(_unit(), _unit(["Impulsive"]))
	ImpulsivePassive.new().modify_accuracy(ctx)
	assert_almost_eq(ctx.accuracy, 70.0, 0.001, "50 + 20 easier to hit")


func test_both_sides_stack() -> void:
	# An Impulsive unit attacking another Impulsive unit on its first attack: +40.
	var ctx := _ctx(_unit(["Impulsive"], 0), _unit(["Impulsive"]))
	ImpulsivePassive.new().modify_accuracy(ctx)
	assert_almost_eq(ctx.accuracy, 90.0, 0.001)


func test_noop_without_passive() -> void:
	var ctx := _ctx(_unit(), _unit())
	ImpulsivePassive.new().modify_accuracy(ctx)
	assert_almost_eq(ctx.accuracy, 50.0, 0.001)


# =============================================================================
# Registry + hit_chance integration (default stats → contribution 0)
# =============================================================================

func test_registry_resolves_impulsive() -> void:
	assert_true(PassiveRegistry.get_handler("Impulsive") is ImpulsivePassive)


func test_hit_chance_first_attack_more_accurate() -> void:
	var attacker := _unit(["Impulsive"], 0)
	var defender := _unit()
	var move := Move.new()
	move.accuracy = 70
	move.attack_range = 1
	assert_eq(DamageCalculator.hit_chance_pct(attacker, defender, move), 90, "70 + 20 first attack")


func test_hit_chance_impulsive_defender_easier_to_hit() -> void:
	var attacker := _unit()
	var defender := _unit(["Impulsive"])
	var move := Move.new()
	move.accuracy = 70
	move.attack_range = 1
	assert_eq(DamageCalculator.hit_chance_pct(attacker, defender, move), 90, "70 + 20 incoming")
