## Type effectiveness chart loaded from JSON.
## Uses string-based type names to prevent enum reordering corruption.
## Unlisted matchups default to 1.0x (normal effectiveness).
class_name TypeChart
extends Resource


const DEFAULT_EFFECTIVENESS: float = 1.0

# Cache: "ATTACKING:DEFENDING" -> multiplier
var _effectiveness_cache: Dictionary = {}


func load_from_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		DebugConfig.log_error("TypeChart: File not found: %s" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		DebugConfig.log_error("TypeChart: Failed to open: %s" % path)
		return false

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()

	if error != OK:
		DebugConfig.log_error("TypeChart: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return false

	var data: Dictionary = json.data
	if not data.has("matchups"):
		DebugConfig.log_error("TypeChart: Missing 'matchups' array")
		return false

	_effectiveness_cache.clear()
	var matchups: Array = data["matchups"]
	for entry: Dictionary in matchups:
		var attacking: String = entry.get("attacking", "")
		var defending: String = entry.get("defending", "")
		var multiplier: float = entry.get("multiplier", 1.0)
		if attacking != "" and defending != "":
			var key := _make_key(attacking, defending)
			_effectiveness_cache[key] = multiplier

	DebugConfig.log_combat("TypeChart: Loaded %d matchups from %s" % [_effectiveness_cache.size(), path])
	return true


## Get effectiveness multiplier for attacking type vs defending type.
func get_effectiveness(attacking_type: Enums.ElementalType, defending_type: Enums.ElementalType) -> float:
	if attacking_type == Enums.ElementalType.NONE or defending_type == Enums.ElementalType.NONE:
		return DEFAULT_EFFECTIVENESS

	var attacking_name := Enums.elemental_type_to_string(attacking_type)
	var defending_name := Enums.elemental_type_to_string(defending_type)
	var key := _make_key(attacking_name, defending_name)
	return _effectiveness_cache.get(key, DEFAULT_EFFECTIVENESS)


## Get display text for an effectiveness multiplier.
static func get_effectiveness_text(multiplier: float) -> String:
	if multiplier >= 4.0:
		return "Devastating"
	elif multiplier >= 2.0:
		return "Super Effective"
	elif multiplier == 1.0:
		return ""
	elif multiplier >= 0.5:
		return "Not Very Effective"
	elif multiplier > 0.0:
		return "Barely Effective"
	else:
		return "No Effect"


func _make_key(attacking_name: String, defending_name: String) -> String:
	# Normalize to title case for consistent lookup
	return attacking_name.to_pascal_case() + ":" + defending_name.to_pascal_case()
