## Phase 2: Reckless + terrain combat integration. Terrain attack/defense/avoid
## multipliers (data/terrain_data.json) are applied in DamageCalculator —
## attacker's tile scales outgoing damage, the defender's tile scales its defense
## stat and its dodge. Reckless ("Increased terrain bonuses and penalties")
## doubles the deviation-from-neutral of the multipliers tied to its OWN tile.
##
## reckless_adjust is covered as pure math; the rest are integration tests using
## real Tiles + the TerrainDataManager autoload, so the terrain values are
## authoritative rather than hand-mocked. Both units and tiles live IN the scene
## tree so the autoload lookups (TerrainDataManager, TypeChartManager) resolve
## cleanly. Every damage assertion is RELATIVE between two same-typed units that
## differ only in terrain, so the type-effectiveness multiplier cancels and the
## comparisons isolate the terrain contribution.
extends GutTest


func _tile(terrain: String) -> Tile:
	var tile := Tile.new()
	# Tile._ready() resolves $Sprite2D; give it one so the lookup doesn't error
	# (the live terrain getters need the tile in the tree to reach the autoload).
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	add_child_autofree(tile)
	tile.terrain_type_name = terrain
	return tile


func _unit(primary := Enums.ElementalType.NONE, secondary := Enums.ElementalType.NONE,
		passives: Array = [], terrain := "Plains") -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.base_strength = 20
	data.base_special = 20
	data.base_defense = 10
	data.base_resistance = 10
	data.primary_type = primary
	data.secondary_type = secondary
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	unit.current_tile = _tile(terrain)
	return unit


func _move(power := 10, accuracy := 90) -> Move:
	var move := Move.new()
	move.base_power = power
	move.accuracy = accuracy
	move.damage_type = Enums.DamageType.PHYSICAL
	move.element_type = Enums.ElementalType.SIMPLE
	move.attack_range = 1
	return move


# =============================================================================
# reckless_adjust — pure math
# =============================================================================

func test_reckless_adjust_amplifies_bonus() -> void:
	assert_almost_eq(DamageCalculator.reckless_adjust(1.3, true), 1.6, 0.0001,
			"+30% terrain bonus becomes +60% under Reckless")


func test_reckless_adjust_amplifies_penalty() -> void:
	assert_almost_eq(DamageCalculator.reckless_adjust(0.9, true), 0.8, 0.0001,
			"-10% terrain penalty becomes -20% under Reckless")


func test_reckless_adjust_identity_without_passive() -> void:
	assert_almost_eq(DamageCalculator.reckless_adjust(1.3, false), 1.3, 0.0001,
			"no Reckless → multiplier passes through untouched")


func test_reckless_is_not_a_pipeline_handler() -> void:
	assert_null(PassiveRegistry.get_handler("Reckless"),
			"Reckless is a calculator rule (must show in preview), not a CombatEffect handler")


# =============================================================================
# Defensive terrain (defender's tile scales its defense stat)
# =============================================================================

func test_defensive_terrain_reduces_incoming_damage() -> void:
	var attacker := _unit()
	var on_plains := _unit(Enums.ElementalType.NONE, Enums.ElementalType.NONE, [], "Plains")
	var on_castle := _unit(Enums.ElementalType.NONE, Enums.ElementalType.NONE, [], "Castle")
	assert_lt(
			DamageCalculator.calculate_damage(attacker, on_castle, _move()),
			DamageCalculator.calculate_damage(attacker, on_plains, _move()),
			"Castle's 1.3 defense multiplier cuts incoming damage")


func test_reckless_defender_takes_even_less_on_good_terrain() -> void:
	var attacker := _unit()
	var castle := _unit(Enums.ElementalType.NONE, Enums.ElementalType.NONE, [], "Castle")
	var reckless_castle := _unit(Enums.ElementalType.NONE, Enums.ElementalType.NONE, ["Reckless"], "Castle")
	assert_lt(
			DamageCalculator.calculate_damage(attacker, reckless_castle, _move()),
			DamageCalculator.calculate_damage(attacker, castle, _move()),
			"Reckless doubles Castle's defensive bonus → even less damage taken")


func test_reckless_defender_suffers_more_on_bad_terrain() -> void:
	# Water's default defenseMultiplier is 0.9 (a defensive penalty). Walkability
	# is irrelevant to the damage math, so any unit can stand there for the test.
	var attacker := _unit()
	var water := _unit(Enums.ElementalType.NONE, Enums.ElementalType.NONE, [], "Water")
	var reckless_water := _unit(Enums.ElementalType.NONE, Enums.ElementalType.NONE, ["Reckless"], "Water")
	assert_gt(
			DamageCalculator.calculate_damage(attacker, reckless_water, _move()),
			DamageCalculator.calculate_damage(attacker, water, _move()),
			"Reckless doubles Water's defensive penalty → more damage taken")


# =============================================================================
# Attack terrain (attacker's tile scales outgoing damage, type-specific)
# =============================================================================

func test_chivalric_attacks_harder_from_castle() -> void:
	var defender := _unit()
	var plains_knight := _unit(Enums.ElementalType.CHIVALRIC, Enums.ElementalType.NONE, [], "Plains")
	var castle_knight := _unit(Enums.ElementalType.CHIVALRIC, Enums.ElementalType.NONE, [], "Castle")
	assert_gt(
			DamageCalculator.calculate_damage(castle_knight, defender, _move()),
			DamageCalculator.calculate_damage(plains_knight, defender, _move()),
			"Castle gives Chivalric units a 1.4 attack multiplier")


func test_non_chivalric_gets_no_castle_attack_bonus() -> void:
	var defender := _unit()
	var plains_fire := _unit(Enums.ElementalType.FIRE, Enums.ElementalType.NONE, [], "Plains")
	var castle_fire := _unit(Enums.ElementalType.FIRE, Enums.ElementalType.NONE, [], "Castle")
	assert_eq(
			DamageCalculator.calculate_damage(castle_fire, defender, _move()),
			DamageCalculator.calculate_damage(plains_fire, defender, _move()),
			"Castle's attack bonus is Chivalric/Heraldic-only; Fire gets nothing")


func test_reckless_amplifies_attack_terrain() -> void:
	var defender := _unit()
	var knight := _unit(Enums.ElementalType.CHIVALRIC, Enums.ElementalType.NONE, [], "Castle")
	var reckless_knight := _unit(Enums.ElementalType.CHIVALRIC, Enums.ElementalType.NONE, ["Reckless"], "Castle")
	assert_gt(
			DamageCalculator.calculate_damage(reckless_knight, defender, _move()),
			DamageCalculator.calculate_damage(knight, defender, _move()),
			"Reckless doubles the Castle attack bonus")


# =============================================================================
# Dual typing — strongest terrain interaction wins
# =============================================================================

func test_dual_type_claims_the_stronger_terrain_interaction() -> void:
	var defender := _unit()
	var pure_knight := _unit(Enums.ElementalType.CHIVALRIC, Enums.ElementalType.NONE, [], "Castle")
	var knight_fire := _unit(Enums.ElementalType.CHIVALRIC, Enums.ElementalType.FIRE, [], "Castle")
	assert_eq(
			DamageCalculator.calculate_damage(knight_fire, defender, _move()),
			DamageCalculator.calculate_damage(pure_knight, defender, _move()),
			"A Chivalric/Fire unit still claims the full Chivalric castle attack bonus")


# =============================================================================
# Avoid terrain (defender's tile lowers attacker's hit chance)
# =============================================================================

func test_avoid_terrain_lowers_hit_chance() -> void:
	var attacker := _unit()
	var on_plains := _unit(Enums.ElementalType.NONE, Enums.ElementalType.NONE, [], "Plains")
	var on_castle := _unit(Enums.ElementalType.NONE, Enums.ElementalType.NONE, [], "Castle")
	assert_eq(DamageCalculator.hit_chance_pct(attacker, on_plains, _move()), 90,
			"Plains is neutral: hit% equals move accuracy")
	assert_eq(DamageCalculator.hit_chance_pct(attacker, on_castle, _move()), 72,
			"Castle's 1.2 avoid → 90 * (2 - 1.2) = 72")


func test_reckless_defender_dodges_more() -> void:
	var attacker := _unit()
	var reckless_castle := _unit(Enums.ElementalType.NONE, Enums.ElementalType.NONE, ["Reckless"], "Castle")
	assert_eq(DamageCalculator.hit_chance_pct(attacker, reckless_castle, _move()), 54,
			"Reckless: avoid 1.2 → 1.4, hit 90 * (2 - 1.4) = 54")


# =============================================================================
# Behavior preservation — neutral terrain is a no-op vs the off-grid baseline
# =============================================================================

func test_plains_matches_off_grid_baseline() -> void:
	var attacker := _unit()
	var defender := _unit()
	var tileless_attacker := _unit()
	tileless_attacker.current_tile = null
	var tileless_defender := _unit()
	tileless_defender.current_tile = null
	assert_eq(
			DamageCalculator.calculate_damage(attacker, defender, _move()),
			DamageCalculator.calculate_damage(tileless_attacker, tileless_defender, _move()),
			"Plains (all multipliers 1.0) equals the off-grid baseline damage")
	assert_eq(
			DamageCalculator.hit_chance_pct(attacker, defender, _move()),
			DamageCalculator.hit_chance_pct(tileless_attacker, tileless_defender, _move()),
			"Plains equals the off-grid baseline hit chance")


# =============================================================================
# Crater — style-conditional defense (defenseMultiplierVsMelee / VsRanged,
# keyed on Move.is_ranged_style; layered onto the base defenseMultiplier)
# =============================================================================

func _ranged_move(power := 10) -> Move:
	var move := _move(power)
	move.attack_range = 2
	return move


func test_crater_blunts_melee_attacks() -> void:
	var attacker := _unit()
	var dug_in := _unit(Enums.ElementalType.NONE, Enums.ElementalType.NONE, [], "Crater")
	var in_the_open := _unit()
	assert_lt(
			DamageCalculator.calculate_damage(attacker, dug_in, _move()),
			DamageCalculator.calculate_damage(attacker, in_the_open, _move()),
			"a dug-in defender takes less from melee than one on Plains")


func test_crater_exposes_defender_to_ranged_fire() -> void:
	var attacker := _unit()
	var dug_in := _unit(Enums.ElementalType.NONE, Enums.ElementalType.NONE, [], "Crater")
	var in_the_open := _unit()
	assert_gt(
			DamageCalculator.calculate_damage(attacker, dug_in, _ranged_move()),
			DamageCalculator.calculate_damage(attacker, in_the_open, _ranged_move()),
			"a defender in a crater takes more from ranged fire than one on Plains")


func test_style_override_decides_the_crater_split() -> void:
	# A range-1 move explicitly tagged ranged (animationStyle) counts as ranged
	# for the split — the classification is the move's, not the firing distance.
	var attacker := _unit()
	var dug_in := _unit(Enums.ElementalType.NONE, Enums.ElementalType.NONE, [], "Crater")
	var point_blank_shot := _move()
	point_blank_shot.animation_style = "ranged"
	assert_gt(
			DamageCalculator.calculate_damage(attacker, dug_in, point_blank_shot),
			DamageCalculator.calculate_damage(attacker, dug_in, _move()),
			"a tagged-ranged move punishes the crater dweller where a melee move is blunted")


func test_fliers_hover_above_the_crater_split() -> void:
	# Air override is 1.0 on both style multipliers — a flier is above the pit,
	# so it gets neither the melee cover nor the ranged exposure.
	var attacker := _unit()
	var flier_in_crater := _unit(Enums.ElementalType.AIR, Enums.ElementalType.NONE, [], "Crater")
	var flier_in_open := _unit(Enums.ElementalType.AIR, Enums.ElementalType.NONE, [], "Plains")
	assert_eq(
			DamageCalculator.calculate_damage(attacker, flier_in_crater, _move()),
			DamageCalculator.calculate_damage(attacker, flier_in_open, _move()),
			"flier takes normal melee damage in a crater")
	assert_eq(
			DamageCalculator.calculate_damage(attacker, flier_in_crater, _ranged_move()),
			DamageCalculator.calculate_damage(attacker, flier_in_open, _ranged_move()),
			"flier takes normal ranged damage in a crater")
