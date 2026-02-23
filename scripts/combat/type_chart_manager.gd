## Autoload singleton providing type effectiveness lookups.
## Registered as "TypeChartManager" in project.godot.
extends Node


const TYPE_CHART_PATH: String = "res://data/type_chart.json"

var _type_chart: TypeChart = null


func _ready() -> void:
	_type_chart = TypeChart.new()
	if not _type_chart.load_from_json(TYPE_CHART_PATH):
		DebugConfig.log_error("TypeChartManager: Failed to load type chart")


## Get effectiveness of attacking type vs a single defending type.
func get_type_effectiveness(attacking_type: Enums.ElementalType, defending_type: Enums.ElementalType) -> float:
	if _type_chart == null:
		return TypeChart.DEFAULT_EFFECTIVENESS
	return _type_chart.get_effectiveness(attacking_type, defending_type)


## Get combined effectiveness against a dual-type defender.
## Multiplies primary and secondary matchups (e.g., 2x * 0.5x = 1x).
func get_combined_effectiveness(move_element: Enums.ElementalType, primary_defense: Enums.ElementalType, secondary_defense: Enums.ElementalType) -> float:
	var primary_mult := get_type_effectiveness(move_element, primary_defense)

	if secondary_defense == Enums.ElementalType.NONE or secondary_defense == primary_defense:
		return primary_mult

	var secondary_mult := get_type_effectiveness(move_element, secondary_defense)
	return primary_mult * secondary_mult


## Get the display text for a given multiplier.
func get_effectiveness_text(multiplier: float) -> String:
	return TypeChart.get_effectiveness_text(multiplier)
