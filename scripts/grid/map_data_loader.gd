## Loads map definitions from JSON files.
## Usage: var map_data := MapDataLoader.load_map_data("res://data/maps/test_map_01.json")
class_name MapDataLoader
extends RefCounted


static func load_map_data(json_path: String) -> MapData:
	var file_content := FileAccess.get_file_as_string(json_path)
	if file_content.is_empty():
		push_error("MapDataLoader: Failed to read '%s'" % json_path)
		return null

	var json_result: Variant = JSON.parse_string(file_content)
	if json_result == null or not json_result is Dictionary:
		push_error("MapDataLoader: Failed to parse '%s'" % json_path)
		return null

	return _parse_map_json(json_result as Dictionary)


static func _parse_map_json(data: Dictionary) -> MapData:
	var map_data := MapData.new()

	map_data.map_name = data.get("map_name", "Unknown Map")
	map_data.map_id = data.get("map_id", "")
	map_data.description = data.get("description", "")
	map_data.scene_path = data.get("scene_path", "")
	map_data.recommended_level = int(data.get("recommended_level", 5))

	var grid_size: Dictionary = data.get("grid_size", {})
	map_data.grid_width = int(grid_size.get("width", 10))
	map_data.grid_height = int(grid_size.get("height", 10))

	var player_spawns: Array = data.get("player_spawns", [])
	for spawn_data: Variant in player_spawns:
		if spawn_data is Dictionary:
			var spawn := _parse_spawn(spawn_data as Dictionary, Enums.UnitFaction.PLAYER)
			map_data.player_spawns.append(spawn)

	var enemy_spawns: Array = data.get("enemy_spawns", [])
	for spawn_data: Variant in enemy_spawns:
		if spawn_data is Dictionary:
			var spawn := _parse_spawn(spawn_data as Dictionary, Enums.UnitFaction.ENEMY)
			map_data.enemy_spawns.append(spawn)

	return map_data


static func _parse_spawn(data: Dictionary, faction: Enums.UnitFaction) -> SpawnData:
	var spawn := SpawnData.new()
	spawn.grid_x = int(data.get("grid_x", 0))
	spawn.grid_y = int(data.get("grid_y", 0))
	spawn.character_json_path = data.get("character_json_path", "")
	spawn.faction = faction
	spawn.required = data.get("required", true)

	var ai_behavior_string: String = data.get("ai_behavior", "Aggressive")
	spawn.ai_behavior = _parse_ai_behavior(ai_behavior_string)

	var level_override: Variant = data.get("level_override", null)
	if level_override != null and level_override is float:
		spawn.level_override = int(level_override)

	return spawn


static func _parse_ai_behavior(behavior_string: String) -> Enums.AIBehaviorType:
	var upper := behavior_string.to_upper()
	for key: String in Enums.AIBehaviorType.keys():
		if key == upper:
			return Enums.AIBehaviorType[key]
	return Enums.AIBehaviorType.AGGRESSIVE


# =============================================================================
# DATA CLASSES
# =============================================================================

class MapData:
	var map_name: String = ""
	var map_id: String = ""
	var description: String = ""
	var scene_path: String = ""
	var grid_width: int = 10
	var grid_height: int = 10
	var recommended_level: int = 5
	var player_spawns: Array = []  # Array of SpawnData
	var enemy_spawns: Array = []   # Array of SpawnData


class SpawnData:
	var grid_x: int = 0
	var grid_y: int = 0
	var character_json_path: String = ""
	var faction: Enums.UnitFaction = Enums.UnitFaction.PLAYER
	var ai_behavior: Enums.AIBehaviorType = Enums.AIBehaviorType.AGGRESSIVE
	var level_override: int = -1  # -1 means use recommended_level
	var required: bool = true
