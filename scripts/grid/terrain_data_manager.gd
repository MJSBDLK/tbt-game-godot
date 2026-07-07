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
# Unknown terrain names we've already warned about — one loud warning per
# unique name instead of spam on every walkability query.
var _warned_unknown_terrains: Dictionary = {}


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
		if terrain_dict.has("defenseMultiplier"):
			definition.defense_multiplier = _parse_terrain_property(terrain_dict["defenseMultiplier"])
		if terrain_dict.has("defenseMultiplierVsMelee"):
			definition.defense_multiplier_vs_melee = _parse_terrain_property(terrain_dict["defenseMultiplierVsMelee"])
		if terrain_dict.has("defenseMultiplierVsRanged"):
			definition.defense_multiplier_vs_ranged = _parse_terrain_property(terrain_dict["defenseMultiplierVsRanged"])
		if terrain_dict.has("avoidMultiplier"):
			definition.avoid_multiplier = _parse_terrain_property(terrain_dict["avoidMultiplier"])
		if terrain_dict.has("terrainStatusImmunity"):
			var immunities: Array = terrain_dict["terrainStatusImmunity"]
			for immunity: Variant in immunities:
				definition.terrain_status_immunity.append(str(immunity))

		_terrains[terrain_name] = definition


func _has_terrain_properties(terrain_dict: Dictionary) -> bool:
	var property_keys := ["walkable", "movePenalty", "attackMultiplier", "defenseMultiplier", "avoidMultiplier"]
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

		# Parse unit-type overrides (any key that isn't "default"). Keys are
		# normalized to UPPERCASE because the game queries with raw
		# ElementalType enum key strings ("COLD", "AIR") while the JSON is
		# authored in Title Case ("Cold", "Air") — without normalization on
		# both sides every per-type override silently never matches.
		for key: String in dict:
			if key == "default":
				continue
			var override_value: Variant = dict[key]
			if override_value is bool:
				property.unit_type_overrides[key.to_upper()] = 1.0 if override_value else 0.0
			else:
				property.unit_type_overrides[key.to_upper()] = float(override_value)

	return property


# =============================================================================
# PUBLIC API
# =============================================================================

func can_unit_walk_on_terrain(terrain_type: String, unit_type: String = "") -> bool:
	if not _is_loaded:
		return true
	if not _terrains.has(terrain_type):
		# Unknown modifier/terrain name = probably a typo in the tile's custom
		# data or a missing terrain_data.json entry. Impassable + one loud
		# warning per unique name so the gap gets caught during development
		# instead of silently producing walkable mystery tiles.
		if not _warned_unknown_terrains.has(terrain_type):
			_warned_unknown_terrains[terrain_type] = true
			push_warning("TerrainDataManager: Unknown terrain type '%s' — treating as IMPASSABLE. Add it to terrain_data.json or fix the tile's terrain_type custom data." % terrain_type)
		return false
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


func get_defense_multiplier(terrain_type: String, unit_type: String = "") -> float:
	if not _is_loaded or not _terrains.has(terrain_type):
		return 0.0
	var terrain: TerrainDefinition = _terrains[terrain_type]
	return terrain.defense_multiplier.get_value(unit_type)


## Style-conditional defense multipliers (Crater et al.) — neutral 1.0 for
## unknown terrain, unlike the base getters' 0.0, because these layer
## multiplicatively on top of defense_multiplier and must be a no-op by default.
func get_defense_multiplier_vs_melee(terrain_type: String, unit_type: String = "") -> float:
	if not _is_loaded or not _terrains.has(terrain_type):
		return 1.0
	var terrain: TerrainDefinition = _terrains[terrain_type]
	return terrain.defense_multiplier_vs_melee.get_value(unit_type)


func get_defense_multiplier_vs_ranged(terrain_type: String, unit_type: String = "") -> float:
	if not _is_loaded or not _terrains.has(terrain_type):
		return 1.0
	var terrain: TerrainDefinition = _terrains[terrain_type]
	return terrain.defense_multiplier_vs_ranged.get_value(unit_type)


func get_avoid_multiplier(terrain_type: String, unit_type: String = "") -> float:
	if not _is_loaded or not _terrains.has(terrain_type):
		return 0.0
	var terrain: TerrainDefinition = _terrains[terrain_type]
	return terrain.avoid_multiplier.get_value(unit_type)


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
		# Overrides are stored uppercase (see _parse_terrain_property);
		# normalize the query so "Cold", "COLD", and "cold" all match.
		if unit_type != "":
			var key := unit_type.to_upper()
			if unit_type_overrides.has(key):
				return unit_type_overrides[key]
		return default_value

	func get_bool_value(unit_type: String = "") -> bool:
		return get_value(unit_type) > 0.0


class TerrainDefinition:
	var terrain_name: String = ""
	var walkable := TerrainProperty.new()
	var move_penalty := TerrainProperty.new()
	var attack_multiplier := TerrainProperty.new()
	var defense_multiplier: TerrainProperty:
		get:
			return defense_multiplier
		set(value):
			defense_multiplier = value
	var avoid_multiplier: TerrainProperty:
		get:
			return avoid_multiplier
		set(value):
			avoid_multiplier = value
	# Style-conditional defense: multiplied ON TOP of defense_multiplier when the
	# incoming move is melee/ranged (Move.is_ranged_style). Neutral 1.0 unless the
	# terrain opts in (e.g. Crater: dug-in vs melee, exposed to ranged).
	var defense_multiplier_vs_melee := TerrainProperty.new()
	var defense_multiplier_vs_ranged := TerrainProperty.new()
	var terrain_status_immunity: Array[String] = []

	func _init() -> void:
		defense_multiplier = TerrainProperty.new()
		defense_multiplier.default_value = 1.0
		avoid_multiplier = TerrainProperty.new()
		avoid_multiplier.default_value = 1.0
		defense_multiplier_vs_melee.default_value = 1.0
		defense_multiplier_vs_ranged.default_value = 1.0
