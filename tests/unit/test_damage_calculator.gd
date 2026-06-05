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
