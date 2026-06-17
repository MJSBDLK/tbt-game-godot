## Regression tests for the InjurySystem queue path.
## Specifically locks in the same-type immunity rule:
##   - MAJOR + same-type → MINOR (standard recovery)
##   - MINOR + same-type → MINOR with shortened recovery (1 battle)
##   - Cross-type kill → severity stands, default recovery
extends GutTest


func _make_character(primary: Enums.ElementalType, max_hp: int = 100) -> CharacterData:
	var data := CharacterData.new()
	data.character_id = "test_subject"
	data.character_name = "Test Subject"
	data.primary_type = primary
	data.secondary_type = Enums.ElementalType.NONE
	data.base_max_hp = max_hp
	return data


func _make_unit(character_data: CharacterData,
		killing_element: Enums.ElementalType,
		killing_damage_type: Enums.DamageType,
		overkill: int) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	unit.character_data = character_data
	unit.last_killing_source = {
		"element": killing_element,
		"damage_type": killing_damage_type,
		"name": "TestMove",
	}
	unit.last_damage_overkill = overkill
	return unit


# =============================================================================
# Same-type immunity: MINOR severity
# =============================================================================

func test_same_type_minor_kill_still_lands_injury() -> void:
	# Ernesto bug regression: a Simple-element unit killed by a Simple-physical
	# move with low overkill used to have its Minor injury dropped entirely.
	# Should now land a MINOR with shortened recovery.
	var data := _make_character(Enums.ElementalType.SIMPLE, 100)
	var unit := _make_unit(data, Enums.ElementalType.SIMPLE, Enums.DamageType.PHYSICAL, 5)

	var injury: Injury = InjurySystem.queue_injury_from_death(unit)

	assert_not_null(injury, "Same-type Minor must still land (was silently dropped before fix)")
	assert_eq(injury.severity, Enums.InjurySeverity.MINOR, "Severity stays MINOR")
	assert_eq(injury.battles_remaining, InjurySystem.SAME_TYPE_MINOR_RECOVERY_BATTLES,
			"Recovery shortened by same-type immunity")
	assert_eq(data.pending_injuries.size(), 1, "Injury appended to pending list")


# =============================================================================
# Same-type immunity: MAJOR severity (severity reduced, recovery normal)
# =============================================================================

func test_same_type_major_kill_drops_to_minor_with_default_recovery() -> void:
	# Same-type immunity should reduce a Major to a Minor (existing behavior),
	# but use the standard minor recovery time — NOT the shortened recovery.
	# Major→Minor reduction is itself the mitigation; don't double-dip.
	var data := _make_character(Enums.ElementalType.SIMPLE, 100)
	var unit := _make_unit(data, Enums.ElementalType.SIMPLE, Enums.DamageType.PHYSICAL, 50)

	var injury: Injury = InjurySystem.queue_injury_from_death(unit)

	assert_not_null(injury, "Major-to-Minor reduction still produces an injury")
	assert_eq(injury.severity, Enums.InjurySeverity.MINOR, "Major reduced one tier")
	var data_for_id: InjuryData = InjuryDatabase.get_injury_by_id(injury.injury_id)
	assert_eq(injury.battles_remaining, data_for_id.minor_recovery_battles,
			"Reduced-Major uses the default minor recovery, not the shortened one")


# =============================================================================
# Cross-type: no immunity reduction
# =============================================================================

func test_cross_type_minor_kill_uses_default_recovery() -> void:
	# Simple-type unit killed by a Fire-physical move. No immunity applies.
	var data := _make_character(Enums.ElementalType.SIMPLE, 100)
	var unit := _make_unit(data, Enums.ElementalType.FIRE, Enums.DamageType.PHYSICAL, 5)

	var injury: Injury = InjurySystem.queue_injury_from_death(unit)

	assert_not_null(injury, "Cross-type kill always lands an injury")
	assert_eq(injury.severity, Enums.InjurySeverity.MINOR)
	var data_for_id: InjuryData = InjuryDatabase.get_injury_by_id(injury.injury_id)
	assert_eq(injury.battles_remaining, data_for_id.minor_recovery_battles,
			"Cross-type recovery is the default for the injury type")


# =============================================================================
# Null guards
# =============================================================================

func test_null_unit_returns_null() -> void:
	assert_null(InjurySystem.queue_injury_from_death(null),
			"Null unit short-circuits without crashing")


func test_empty_killing_source_returns_null() -> void:
	var data := _make_character(Enums.ElementalType.SIMPLE, 100)
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	unit.character_data = data
	unit.last_killing_source = {}

	var injury: Injury = InjurySystem.queue_injury_from_death(unit)
	assert_null(injury, "Empty killing source means we can't classify — skip injury")
	assert_eq(data.pending_injuries.size(), 0, "Nothing queued when classification fails")


# =============================================================================
# build_injury factory — severity-appropriate recovery
# =============================================================================

func test_build_injury_minor_uses_minor_recovery() -> void:
	var data: InjuryData = InjuryDatabase.get_injury_by_id("burn_scar")
	assert_not_null(data, "burn_scar is a defined injury")
	var injury: Injury = InjurySystem.build_injury(data, Enums.InjurySeverity.MINOR)
	assert_eq(injury.injury_id, "burn_scar")
	assert_eq(injury.severity, Enums.InjurySeverity.MINOR)
	assert_eq(injury.battles_remaining, data.minor_recovery_battles,
			"Minor injury stamps the minor recovery duration")


func test_build_injury_major_uses_major_recovery() -> void:
	var data: InjuryData = InjuryDatabase.get_injury_by_id("burn_scar")
	var injury: Injury = InjurySystem.build_injury(data, Enums.InjurySeverity.MAJOR)
	assert_eq(injury.severity, Enums.InjurySeverity.MAJOR)
	assert_eq(injury.battles_remaining, data.major_recovery_battles,
			"Major injury stamps the major recovery duration")


# =============================================================================
# queue_random_injury — Ctrl+K dev cheat backing
# =============================================================================

func test_queue_random_injury_appends_one_to_pending() -> void:
	var data := _make_character(Enums.ElementalType.SIMPLE, 100)
	var injury: Injury = InjurySystem.queue_random_injury(data)
	assert_not_null(injury, "A random injury is produced when definitions exist")
	assert_eq(data.pending_injuries.size(), 1, "Exactly one injury queued")
	assert_true(data.pending_injuries.has(injury), "The returned injury is the one queued")
	assert_not_null(InjuryDatabase.get_injury_by_id(injury.injury_id),
			"Random pick is a real defined injury id")


func test_queue_random_injury_null_character_returns_null() -> void:
	assert_null(InjurySystem.queue_random_injury(null),
			"Null character short-circuits without crashing")
