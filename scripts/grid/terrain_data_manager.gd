## Loads and provides access to JSON-based terrain data.
## Supports conditional properties based on unit elemental types.
## Registered as Autoload "TerrainDataManager".
##
## Usage:
##   TerrainDataManager.get_movement_cost("Forest", "Plant")  # Returns 1.0
##   TerrainDataManager.can_unit_walk_on_terrain("Water", "Air")  # Returns true
extends Node


# Parsed terrain definitions keyed by terrain name
var _terrains: Dictionary = {}
var _is_loaded: bool = false


func _ready() -> void:
	_load_terrain_data()


# =============================================================================
# DATA LOADING
# =============================================================================

func _load_terrain_data() -> void:
	var json_path := "res://data/terrain_data.json"
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		DebugConfig.log_error("TerrainDataManager: terrain_data.json not found at %s" % json_path)
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		DebugConfig.log_error("TerrainDataManager: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return

	var data: Dictionary = json.data
	_parse_terrain_database(data)
	_is_loaded = true
	DebugConfig.log_tilemap("TerrainDataManager: Loaded %d terrain types" % _terrains.size())


func _parse_terrain_database(data: Dictionary) -> void:
	for terrain_name: String in data:
		# Skip doc entries
		if terrain_name.begins_with("_"):
			continue

		var terrain_data: Variant = data[terrain_name]
		if terrain_data is not Dictionary:
			continue

		var terrain_dict: Dictionary = terrain_data
		# Skip stubs that only have _doc and no actual properties
		if not _has_terrain_properties(terrain_dict):
			continue

		var definition := TerrainDefinition.new()
		definition.terrain_name = terrain_name

		if terrain_dict.has("walkable"):
			definition.walkable = _parse_terrain_property(terrain_dict["walkable"])
		if terrain_dict.has("movePenalty"):
			definition.move_penalty = _parse_terrain_property(terrain_dict["movePenalty"])
		if terrain_dict.has("attackMultiplier"):
			definition.attack_multiplier = _parse_terrain_property(terrain_dict["attackMultiplier"])
		if terrain_dict.has("defenseModifier"):
			definition.defense_modifier = _parse_terrain_property(terrain_dict["defenseModifier"])
		if terrain_dict.has("avoidModifier"):
			definition.avoid_modifier = _parse_terrain_property(terrain_dict["avoidModifier"])
		if terrain_dict.has("terrainStatusImmunity"):
			var immunities: Array = terrain_dict["terrainStatusImmunity"]
			for immunity: Variant in immunities:
				definition.terrain_status_immunity.append(str(immunity))

		_terrains[terrain_name] = definition


func _has_terrain_properties(terrain_dict: Dictionary) -> bool:
	var property_keys := ["walkable", "movePenalty", "attackMultiplier", "defenseModifier", "avoidModifier"]
	for key: String in property_keys:
		if terrain_dict.has(key):
			return true
	return false


func _parse_terrain_property(property_data: Variant) -> TerrainProperty:
	var property := TerrainProperty.new()

	if property_data is Dictionary:
		var dict: Dictionary = property_data
		if dict.has("default"):
			var default_value: Variant = dict["default"]
			if default_value is bool:
				property.default_value = 1.0 if default_value else 0.0
			else:
				property.default_value = float(default_value)

		# Parse unit-type overrides (any key that isn't "default")
		for key: String in dict:
			if key == "default":
				continue
			var override_value: Variant = dict[key]
			if override_value is bool:
				property.unit_type_overrides[key] = 1.0 if override_value else 0.0
			else:
				property.unit_type_overrides[key] = float(override_value)

	return property


# =============================================================================
# PUBLIC API
# =============================================================================

func can_unit_walk_on_terrain(terrain_type: String, unit_type: String = "") -> bool:
	if not _is_loaded:
		return true
	if not _terrains.has(terrain_type):
		DebugConfig.warn_grid("Unknown terrain type: %s. Assuming walkable." % terrain_type)
		return true
	var terrain: TerrainDefinition = _terrains[terrain_type]
	return terrain.walkable.get_value(unit_type) > 0.0


func get_movement_cost(terrain_type: String, unit_type: String = "") -> float:
	if not _is_loaded or not _terrains.has(terrain_type):
		return 1.0
	var terrain: TerrainDefinition = _terrains[terrain_type]
	return terrain.move_penalty.get_value(unit_type)


func get_attack_multiplier(terrain_type: String, unit_type: String = "") -> float:
	if not _is_loaded or not _terrains.has(terrain_type):
		return 1.0
	var terrain: TerrainDefinition = _terrains[terrain_type]
	return terrain.attack_multiplier.get_value(unit_type)


func get_defense_modifier(terrain_type: String, unit_type: String = "") -> float:
	if not _is_loaded or not _terrains.has(terrain_type):
		return 0.0
	var terrain: TerrainDefinition = _terrains[terrain_type]
	return terrain.defense_modifier.get_value(unit_type)


func get_avoid_modifier(terrain_type: String, unit_type: String = "") -> float:
	if not _is_loaded or not _terrains.has(terrain_type):
		return 0.0
	var terrain: TerrainDefinition = _terrains[terrain_type]
	return terrain.avoid_modifier.get_value(unit_type)


func get_all_terrain_types() -> Array[String]:
	var types: Array[String] = []
	for key: String in _terrains:
		types.append(key)
	return types


func get_terrain_definition(terrain_type: String) -> TerrainDefinition:
	if not _is_loaded or not _terrains.has(terrain_type):
		return null
	return _terrains[terrain_type]


func is_terrain_immune_to_status(terrain_type: String, status_effect: String) -> bool:
	if not _is_loaded or not _terrains.has(terrain_type):
		return false
	var terrain: TerrainDefinition = _terrains[terrain_type]
	return terrain.terrain_status_immunity.has(status_effect)


# =============================================================================
# DATA CLASSES
# =============================================================================

class TerrainProperty:
	var default_value: float = 1.0
	var unit_type_overrides: Dictionary = {}

	func get_value(unit_type: String = "") -> float:
		if unit_type != "" and unit_type_overrides.has(unit_type):
			return unit_type_overrides[unit_type]
		return default_value

	func get_bool_value(unit_type: String = "") -> bool:
		return get_value(unit_type) > 0.0


class TerrainDefinition:
	var terrain_name: String = ""
	var walkable := TerrainProperty.new()
	var move_penalty := TerrainProperty.new()
	var attack_multiplier := TerrainProperty.new()
	var defense_modifier: TerrainProperty:
		get:
			return defense_modifier
		set(value):
			defense_modifier = value
	var avoid_modifier: TerrainProperty:
		get:
			return avoid_modifier
		set(value):
			avoid_modifier = value
	var terrain_status_immunity: Array[String] = []

	func _init() -> void:
		defense_modifier = TerrainProperty.new()
		defense_modifier.default_value = 0.0
		avoid_modifier = TerrainProperty.new()
		avoid_modifier.default_value = 0.0
