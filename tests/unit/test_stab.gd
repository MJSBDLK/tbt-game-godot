## STAB (same-type attack bonus): a move whose element matches the attacker's
## typing deals STAB_MULTIPLIER damage. Applied inside calculate_damage so the
## combat preview inherits it for free. Damage assertions are RELATIVE between
## two attackers that differ only in typing, so terrain/type multipliers cancel
## and the comparisons isolate the STAB contribution.
extends GutTest


func _unit(primary := Enums.ElementalType.NONE, secondary := Enums.ElementalType.NONE) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.base_strength = 20
	data.base_special = 20
	data.base_defense = 10
	data.base_resistance = 10
	data.primary_type = primary
	data.secondary_type = secondary
	unit.character_data = data
	return unit


func _move(element := Enums.ElementalType.FIRE) -> Move:
	var move := Move.new()
	move.base_power = 10
	move.accuracy = 90
	move.damage_type = Enums.DamageType.PHYSICAL
	move.element_type = element
	move.attack_range = 1
	return move


# =============================================================================
# get_stab_multiplier — pure lookup
# =============================================================================

func test_stab_on_primary_type_match() -> void:
	var attacker := _unit(Enums.ElementalType.FIRE)
	assert_almost_eq(DamageCalculator.get_stab_multiplier(attacker, _move(Enums.ElementalType.FIRE)),
			DamageCalculator.STAB_MULTIPLIER, 0.0001, "Primary-type move gets STAB")


func test_stab_on_secondary_type_match() -> void:
	var attacker := _unit(Enums.ElementalType.PLANT, Enums.ElementalType.FIRE)
	assert_almost_eq(DamageCalculator.get_stab_multiplier(attacker, _move(Enums.ElementalType.FIRE)),
			DamageCalculator.STAB_MULTIPLIER, 0.0001, "Secondary-type move gets STAB")


func test_no_stab_on_off_type_move() -> void:
	var attacker := _unit(Enums.ElementalType.PLANT)
	assert_almost_eq(DamageCalculator.get_stab_multiplier(attacker, _move(Enums.ElementalType.FIRE)),
			1.0, 0.0001, "Off-type move gets no STAB")


func test_no_stab_for_none_element() -> void:
	# NONE-element move on a NONE-typed unit must NOT match ("no type" isn't a type).
	var attacker := _unit(Enums.ElementalType.NONE)
	assert_almost_eq(DamageCalculator.get_stab_multiplier(attacker, _move(Enums.ElementalType.NONE)),
			1.0, 0.0001, "NONE element never gets STAB")


func test_stab_null_guards() -> void:
	assert_almost_eq(DamageCalculator.get_stab_multiplier(null, _move()), 1.0, 0.0001,
			"Null attacker is neutral")
	assert_almost_eq(DamageCalculator.get_stab_multiplier(_unit(), null), 1.0, 0.0001,
			"Null move is neutral")


# =============================================================================
# calculate_damage integration — STAB visibly scales the final number
# =============================================================================

func test_stab_scales_calculated_damage() -> void:
	var defender := _unit(Enums.ElementalType.NONE)
	var move := _move(Enums.ElementalType.FIRE)
	# Same stats, same move; only the attacker's typing differs.
	var off_type_damage := DamageCalculator.calculate_damage(_unit(Enums.ElementalType.PLANT), defender, move)
	var stab_damage := DamageCalculator.calculate_damage(_unit(Enums.ElementalType.FIRE), defender, move)
	# (20 str + 10 power - 10 def) = 20 base -> 20 vs round(20 * 1.2) = 24.
	assert_eq(off_type_damage, 20, "Baseline: no STAB, neutral type, no terrain")
	assert_eq(stab_damage, roundi(20 * DamageCalculator.STAB_MULTIPLIER),
			"STAB multiplies the final damage")


func test_crystallization_removed_type_loses_stab() -> void:
	# effective_primary_type() drops types removed by a Crystallization injury;
	# STAB must follow the effective typing, not the base typing.
	var attacker := _unit(Enums.ElementalType.FIRE)
	var data: InjuryData = InjuryDatabase.get_injury_by_id("crystallization")
	assert_not_null(data, "crystallization is a defined injury")
	var injury: Injury = InjurySystem.build_injury(data, Enums.InjurySeverity.MINOR)
	attacker.character_data.current_injuries.append(injury)
	assert_almost_eq(DamageCalculator.get_stab_multiplier(attacker, _move(Enums.ElementalType.FIRE)),
			1.0, 0.0001, "Crystallized-away type grants no STAB")
