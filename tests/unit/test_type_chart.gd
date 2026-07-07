## Pins the live data/type_chart.json against the design-table intent.
## Full-coverage matchup pins live here for the NEW types (Monster, Beast);
## legacy types get spot checks so a bad reformat of the JSON can't slip
## through silently. Multipliers derive from TypeChart.TYPE_COEFFICIENT, so
## these assertions survive coefficient retuning.
extends GutTest

const _CHART_PATH: String = "res://data/type_chart.json"

var _chart: TypeChart


func before_each() -> void:
	_chart = TypeChart.new()
	assert_true(_chart.load_from_json(_CHART_PATH), "type_chart.json loads")


func _effectiveness(attacking: Enums.ElementalType, defending: Enums.ElementalType) -> float:
	return _chart.get_effectiveness(attacking, defending)


func test_monster_beast_types_resolve_from_strings() -> void:
	assert_eq(Enums.string_to_elemental_type("Monster"), Enums.ElementalType.MONSTER)
	assert_eq(Enums.string_to_elemental_type("Beast"), Enums.ElementalType.BEAST)


func test_monster_defensive_matchups() -> void:
	var ouch := TypeChart.TYPE_COEFFICIENT
	var resist := 1.0 / TypeChart.TYPE_COEFFICIENT
	assert_almost_eq(_effectiveness(Enums.ElementalType.PLANT, Enums.ElementalType.MONSTER), ouch, 0.001, "Monster is weak to Plant")
	assert_almost_eq(_effectiveness(Enums.ElementalType.HERALDIC, Enums.ElementalType.MONSTER), ouch, 0.001, "Monster is weak to Heraldic")
	assert_almost_eq(_effectiveness(Enums.ElementalType.VOID, Enums.ElementalType.MONSTER), resist, 0.001, "Monster resists Void")
	assert_almost_eq(_effectiveness(Enums.ElementalType.FIRE, Enums.ElementalType.MONSTER), 1.0, 0.001, "Unlisted attacker vs Monster is neutral")


func test_monster_offensive_matchups() -> void:
	var ouch := TypeChart.TYPE_COEFFICIENT
	var resist := 1.0 / TypeChart.TYPE_COEFFICIENT
	assert_almost_eq(_effectiveness(Enums.ElementalType.MONSTER, Enums.ElementalType.SIMPLE), ouch, 0.001, "Monster is strong vs Simple")
	assert_almost_eq(_effectiveness(Enums.ElementalType.MONSTER, Enums.ElementalType.CHIVALRIC), resist, 0.001, "Monster is weak vs Chivalric")
	assert_almost_eq(_effectiveness(Enums.ElementalType.MONSTER, Enums.ElementalType.GENTRY), resist, 0.001, "Monster is weak vs Gentry")
	assert_almost_eq(_effectiveness(Enums.ElementalType.MONSTER, Enums.ElementalType.HERALDIC), resist, 0.001, "Monster is weak vs Heraldic")


func test_beast_matchups() -> void:
	var ouch := TypeChart.TYPE_COEFFICIENT
	assert_almost_eq(_effectiveness(Enums.ElementalType.MONSTER, Enums.ElementalType.BEAST), ouch, 0.001, "Beast is weak to Monster")
	assert_almost_eq(_effectiveness(Enums.ElementalType.BEAST, Enums.ElementalType.SIMPLE), ouch, 0.001, "Beast is strong vs Simple")
	assert_almost_eq(_effectiveness(Enums.ElementalType.BEAST, Enums.ElementalType.MONSTER), 1.0, 0.001, "Beast vs Monster attack is neutral")
	assert_almost_eq(_effectiveness(Enums.ElementalType.SIMPLE, Enums.ElementalType.BEAST), 1.0, 0.001, "Beast has no resistances")


func test_legacy_spot_checks() -> void:
	var ouch := TypeChart.TYPE_COEFFICIENT
	assert_almost_eq(_effectiveness(Enums.ElementalType.FIRE, Enums.ElementalType.PLANT), ouch, 0.001, "Fire vs Plant still ouch")
	assert_almost_eq(_effectiveness(Enums.ElementalType.ELECTRIC, Enums.ElementalType.VOID), 0.0, 0.001, "Electric vs Void still immune")
	assert_almost_eq(_effectiveness(Enums.ElementalType.SIMPLE, Enums.ElementalType.GENTRY), 1.0, 0.001, "Unlisted pair still neutral")
