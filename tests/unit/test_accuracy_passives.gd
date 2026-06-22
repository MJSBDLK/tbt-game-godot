## Phase 2 slice 2: Reliable + Low Profile migrated to modify_accuracy passive
## handlers, dispatched from DamageCalculator.hit_chance_pct.
##
## Integration tests use fresh CharacterData (base_skill = base_agility = 5), so
## the skill/agility contribution is 0 and hit% == move.accuracy ± passives.
extends GutTest


func _make_unit(passives: Array = []) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	return unit


func _move(attack_range: int, accuracy: int) -> Move:
	var move := Move.new()
	move.attack_range = attack_range
	move.accuracy = accuracy
	return move


func _ctx(attacker: TestFakeUnit, defender: TestFakeUnit, move: Move, base_acc: float) -> CombatHitContext:
	var ctx := CombatHitContext.new()
	ctx.attacker = attacker
	ctx.defender = defender
	ctx.move = move
	ctx.accuracy = base_acc
	return ctx


# =============================================================================
# ReliablePassive.modify_accuracy
# =============================================================================

func test_reliable_adds_accuracy() -> void:
	var ctx := _ctx(_make_unit(["Reliable"]), _make_unit(), _move(1, 90), 50.0)
	ReliablePassive.new().modify_accuracy(ctx)
	assert_almost_eq(ctx.accuracy, 50.0 + DamageCalculator.RELIABLE_ACCURACY_BONUS, 0.001)


func test_reliable_noop_without_passive() -> void:
	var ctx := _ctx(_make_unit(), _make_unit(), _move(1, 90), 50.0)
	ReliablePassive.new().modify_accuracy(ctx)
	assert_almost_eq(ctx.accuracy, 50.0, 0.001, "no Reliable → unchanged")


# =============================================================================
# LowProfilePassive.modify_accuracy (ranged only)
# =============================================================================

func test_low_profile_reduces_ranged_accuracy() -> void:
	var ctx := _ctx(_make_unit(), _make_unit(["Low Profile"]), _move(2, 80), 80.0)
	LowProfilePassive.new().modify_accuracy(ctx)
	assert_almost_eq(ctx.accuracy, 80.0 - DamageCalculator.LOW_PROFILE_AVOID_BONUS, 0.001)


func test_low_profile_ignores_melee() -> void:
	var ctx := _ctx(_make_unit(), _make_unit(["Low Profile"]), _move(1, 80), 80.0)
	LowProfilePassive.new().modify_accuracy(ctx)
	assert_almost_eq(ctx.accuracy, 80.0, 0.001, "melee (range 1) bypasses Low Profile")


func test_low_profile_noop_without_passive() -> void:
	var ctx := _ctx(_make_unit(), _make_unit(), _move(2, 80), 80.0)
	LowProfilePassive.new().modify_accuracy(ctx)
	assert_almost_eq(ctx.accuracy, 80.0, 0.001)


# =============================================================================
# Registry
# =============================================================================

func test_registry_resolves_accuracy_passives() -> void:
	assert_true(PassiveRegistry.get_handler("Reliable") is ReliablePassive)
	assert_true(PassiveRegistry.get_handler("Low Profile") is LowProfilePassive)


# =============================================================================
# hit_chance_pct integration (skill/agility contribution = 0 at defaults)
# =============================================================================

func test_hit_chance_baseline_is_move_accuracy() -> void:
	var pct := DamageCalculator.hit_chance_pct(_make_unit(), _make_unit(), _move(1, 90))
	assert_eq(pct, 90, "no passives, equal stats → hit% == move.accuracy")


func test_hit_chance_reliable_guarantees_hit() -> void:
	var pct := DamageCalculator.hit_chance_pct(_make_unit(["Reliable"]), _make_unit(), _move(1, 90))
	assert_eq(pct, 100, "90 + 50 Reliable, clamped to 100")


func test_hit_chance_low_profile_reduces_ranged() -> void:
	var pct := DamageCalculator.hit_chance_pct(_make_unit(), _make_unit(["Low Profile"]), _move(2, 80))
	assert_eq(pct, 55, "80 - 25 avoid on a ranged move")


func test_hit_chance_low_profile_does_not_reduce_melee() -> void:
	var pct := DamageCalculator.hit_chance_pct(_make_unit(), _make_unit(["Low Profile"]), _move(1, 80))
	assert_eq(pct, 80, "Low Profile doesn't help vs melee")
