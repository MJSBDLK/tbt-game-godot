## Battle scene root script. Spawns units from map data JSON and kicks off the turn loop.
## Spawn priority: painted SpawnTileLayer tiles > JSON map data > hardcoded fallback.
## Set map_data_path in the inspector to point to your map's JSON file.
extends Node2D


@export var map_data_path: String = ""
@export var default_player_character: String = "res://data/characters/spaceman.json"
@export var default_enemy_character: String = "res://data/characters/grunt.json"

var _unit_scene: PackedScene = preload("res://scenes/battle/unit.tscn")
var _units_container: Node2D = null


func _ready() -> void:
	_units_container = Node2D.new()
	_units_container.name = "Units"
	add_child(_units_container)

	if GridManager.is_grid_ready():
		_on_grid_ready()
	else:
		GridManager.grid_ready.connect(_on_grid_ready)


func _on_grid_ready() -> void:
	var player_units: Array[Unit] = []
	var enemy_units: Array[Unit] = []

	# Priority 1: Tile-based spawns from SpawnTileLayer
	var spawn_points := _get_tile_spawn_points()
	var has_tile_spawns := spawn_points["Player"].size() > 0 or spawn_points["Enemy"].size() > 0

	if has_tile_spawns:
		player_units = _spawn_units_from_tiles(spawn_points["Player"], Enums.UnitFaction.PLAYER, default_player_character)
		enemy_units = _spawn_units_from_tiles(spawn_points["Enemy"], Enums.UnitFaction.ENEMY, default_enemy_character)
		DebugConfig.log_unit_init("BattleScene: Spawned %d players + %d enemies from tile spawns" % [
			player_units.size(), enemy_units.size()])
	elif map_data_path != "":
		# Priority 2: JSON map data
		var map_data := MapDataLoader.load_map_data(map_data_path)
		if map_data != null:
			player_units = _spawn_units_from_data(map_data.player_spawns)
			enemy_units = _spawn_units_from_data(map_data.enemy_spawns)
			DebugConfig.log_unit_init("BattleScene: Spawned %d players + %d enemies from '%s'" % [
				player_units.size(), enemy_units.size(), map_data.map_name])
		else:
			push_warning("BattleScene: Failed to load '%s', using fallback spawns" % map_data_path)
			player_units = _spawn_fallback_players()
			enemy_units = _spawn_fallback_enemies()
	else:
		# Priority 3: Hardcoded fallback
		player_units = _spawn_fallback_players()
		enemy_units = _spawn_fallback_enemies()

	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager != null:
		turn_manager.initialize_battle(player_units, enemy_units)
	else:
		push_warning("BattleScene: TurnManager not found — running without turn loop")


# =============================================================================
# TILE-BASED SPAWNING (SpawnTileLayer)
# =============================================================================

func _get_tile_spawn_points() -> Dictionary:
	var grid_builder := _find_grid_builder()
	if grid_builder == null:
		return {"Player": [], "Enemy": []}
	return grid_builder.get_spawn_points()


func _find_grid_builder() -> TilemapGridBuilder:
	# The TilemapGridBuilder is a sibling or child in the scene tree
	for child: Node in get_children():
		if child is TilemapGridBuilder:
			return child as TilemapGridBuilder
	# Also check parent's children (siblings)
	if get_parent() != null:
		for child: Node in get_parent().get_children():
			if child is TilemapGridBuilder:
				return child as TilemapGridBuilder
	return null


func _spawn_units_from_tiles(positions: Array, faction: Enums.UnitFaction, character_path: String) -> Array[Unit]:
	var units: Array[Unit] = []
	for position: Variant in positions:
		var grid_pos := position as Vector2i
		var tile := GridManager.get_tile(grid_pos.x, grid_pos.y)
		if tile == null:
			push_warning("BattleScene: No tile at (%d, %d) for tile spawn" % [grid_pos.x, grid_pos.y])
			continue
		var unit := _create_unit(character_path, faction, tile)
		if unit != null:
			units.append(unit)
	return units


# =============================================================================
# MAP-DRIVEN SPAWNING
# =============================================================================

func _spawn_units_from_data(spawns: Array) -> Array[Unit]:
	var units: Array[Unit] = []
	for spawn_entry: Variant in spawns:
		var spawn := spawn_entry as MapDataLoader.SpawnData
		if spawn == null:
			continue

		var tile := GridManager.get_tile(spawn.grid_x, spawn.grid_y)
		if tile == null:
			push_warning("BattleScene: No tile at (%d, %d) for spawn" % [spawn.grid_x, spawn.grid_y])
			continue

		var unit := _create_unit(spawn.character_json_path, spawn.faction, tile, spawn.ai_behavior)
		if unit != null:
			units.append(unit)

	return units


# =============================================================================
# FALLBACK SPAWNING (no map data)
# =============================================================================

func _spawn_fallback_players() -> Array[Unit]:
	var units: Array[Unit] = []
	var offset_x := GridManager.grid_offset_x
	var offset_y := GridManager.grid_offset_y

	var tile_1 := GridManager.get_tile(offset_x + 1, offset_y + 1)
	if tile_1 != null:
		units.append(_create_unit("res://data/characters/spaceman.json",
			Enums.UnitFaction.PLAYER, tile_1))

	var tile_2 := GridManager.get_tile(offset_x + 1, offset_y + 3)
	if tile_2 != null:
		units.append(_create_unit("res://data/characters/spaceman.json",
			Enums.UnitFaction.PLAYER, tile_2))

	return units


func _spawn_fallback_enemies() -> Array[Unit]:
	var units: Array[Unit] = []
	var offset_x := GridManager.grid_offset_x
	var offset_y := GridManager.grid_offset_y

	var tile_1 := GridManager.get_tile(offset_x + 3, offset_y + 1)
	if tile_1 != null:
		units.append(_create_unit("res://data/characters/grunt.json",
			Enums.UnitFaction.ENEMY, tile_1))

	var tile_2 := GridManager.get_tile(offset_x + 5, offset_y + 3)
	if tile_2 != null:
		units.append(_create_unit("res://data/characters/grunt.json",
			Enums.UnitFaction.ENEMY, tile_2))

	return units


# =============================================================================
# UNIT CREATION
# =============================================================================

func _create_unit(json_path: String, faction: Enums.UnitFaction, tile: Tile,
		ai_behavior: Enums.AIBehaviorType = Enums.AIBehaviorType.AGGRESSIVE) -> Unit:
	var unit: Unit = _unit_scene.instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	_units_container.add_child(unit)
	unit.initialize(tile)
	unit.auto_assign_first_usable_move()

	# Add EnemyAI to enemy units
	if faction == Enums.UnitFaction.ENEMY:
		var enemy_ai := EnemyAI.new()
		enemy_ai.name = "EnemyAI"
		enemy_ai.behavior_type = ai_behavior
		unit.add_child(enemy_ai)

	return unit
