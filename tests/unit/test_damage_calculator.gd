## Unit tests for DamageCalculator pure-math helpers.
## Functions that need Unit/CharacterData fixtures are tested separately —
## these only cover paths that take primitive inputs or null Node2D args.
extends GutTest


# =============================================================================
# calculate_impact_weight — damage feel rating, 0.0..1.0
# =============================================================================

func test_impact_weight_zero_damage() -> void:
	assert_eq(DamageCalculator.calculate_impact_weight(0, 100), 0.0,
			"Zero damage = zero impact")


func test_impact_weight_clamped_at_one() -> void:
	# damage > max_hp AND damage > MAX_REASONABLE_DAMAGE both produce ratios > 1.
	# Should clamp.
	assert_eq(DamageCalculator.calculate_impact_weight(200, 50), 1.0,
			"Damage exceeding both ratios clamps to 1.0")


func test_impact_weight_uses_hp_ratio_for_fragile_targets() -> void:
	# 10 dmg on 20 max_hp = 50% HP gone → 0.5 hp_ratio dominates 0.2 raw_ratio.
	assert_almost_eq(DamageCalculator.calculate_impact_weight(10, 20), 0.5, 0.001,
			"Chunky % damage on a fragile unit registers via hp_ratio")


func test_impact_weight_uses_raw_ratio_for_chip_damage_on_tanks() -> void:
	# 25 dmg on 1000 max_hp: raw_ratio = 25/50 = 0.5, hp_ratio = 0.025.
	# Raw wins — big number on big unit still feels meaningful.
	assert_almost_eq(DamageCalculator.calculate_impact_weight(25, 1000), 0.5, 0.001,
			"Big damage on a tank registers via raw_ratio even at low HP%")


# =============================================================================
# hit_chance_pct — null guards (the safest cases to test without unit fixtures)
# =============================================================================

func test_hit_chance_null_move_returns_one_hundred() -> void:
	assert_eq(DamageCalculator.hit_chance_pct(null, null, null), 100,
			"Null move short-circuits to 100% (caller responsibility)")


func test_hit_chance_falls_back_to_move_accuracy_when_units_missing() -> void:
	var move := Move.new()
	move.accuracy = 73
	assert_eq(DamageCalculator.hit_chance_pct(null, null, move), 73,
			"Missing attacker/defender skips skill/agility math, uses move base")


# =============================================================================
# calculate_attack_count — null guard
# =============================================================================

func test_attack_count_defaults_to_one_with_null_units() -> void:
	assert_eq(DamageCalculator.calculate_attack_count(null, null), 1,
			"No combatants = no multi-hit roll")


# =============================================================================
# bellows_multiplier — one helper for the calculator AND the hit announcement
# =============================================================================
# (RQD 2026-08-21, todo #2A.) Pulled out of calculate_damage so
# Unit._execute_single_hit can announce "BELLOWS xN" with the exact number the
# damage math applies. These need a unit in the tree (the autoload lookup rides
# the attacker node) — TestFakeUnit carries active_status_effects.

func _bellows_unit(special: int = 10, resistance: int = 0) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.base_max_hp = 100
	data.base_special = special
	data.base_resistance = resistance
	unit.character_data = data
	unit.current_hp = 100
	unit.active_status_effects = []
	return unit


func _fire_move(power: int = 10) -> Move:
	var move := Move.new()
	move.move_name = "Test Scorch"
	move.element_type = Enums.ElementalType.FIRE
	move.damage_type = Enums.DamageType.SPECIAL
	move.base_power = power
	return move


func test_bellows_multiplier_is_one_without_stacks() -> void:
	var unit := _bellows_unit()
	assert_almost_eq(DamageCalculator.bellows_multiplier(unit, _fire_move()), 1.0, 0.001)
	assert_almost_eq(DamageCalculator.bellows_multiplier(null, _fire_move()), 1.0, 0.001, "null attacker")
	assert_almost_eq(DamageCalculator.bellows_multiplier(unit, null), 1.0, 0.001, "null move")


func test_bellows_multiplier_scales_per_stack_on_fire_only() -> void:
	var unit := _bellows_unit()
	StatusEffectSystem.apply_status_effect_by_name(null, unit, "BELLOWS", 2)
	assert_almost_eq(DamageCalculator.bellows_multiplier(unit, _fire_move()),
			1.0 + 2 * DamageCalculator.BELLOWS_BONUS_PER_STACK, 0.001, "two stacks of fire")
	var air := _fire_move()
	air.element_type = Enums.ElementalType.AIR
	assert_almost_eq(DamageCalculator.bellows_multiplier(unit, air), 1.0, 0.001,
			"Bellows is a FIRE boost — other elements ignore the stacks")


func test_calculate_damage_applies_the_same_bellows_number() -> void:
	# Spc 10 + power 10 - Res 0 = 20 base; no STAB (typeless attacker), no
	# terrain (no tile) — so the multiplier shows through exactly.
	var attacker := _bellows_unit(10, 0)
	var defender := _bellows_unit(0, 0)
	assert_eq(DamageCalculator.calculate_damage(attacker, defender, _fire_move()), 20,
			"baseline without stacks")
	StatusEffectSystem.apply_status_effect_by_name(null, attacker, "BELLOWS", 2)
	var expected: int = roundi(20 * DamageCalculator.bellows_multiplier(attacker, _fire_move()))
	assert_eq(DamageCalculator.calculate_damage(attacker, defender, _fire_move()), expected,
			"the calculator and the announced multiplier can't disagree (20 x 1.5 = 30)")
