## Battle scene root script. Spawns units from SpawnTileLayer and kicks off the turn loop.
## Each map scene must have a TilemapGridBuilder with a painted SpawnTileLayer.
extends Node2D


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
	var spawn_points := _get_tile_spawn_points()
	var player_units := _spawn_units_from_tiles(spawn_points["Player"], Enums.UnitFaction.PLAYER, default_player_character)
	var enemy_units := _spawn_units_from_tiles(spawn_points["Enemy"], Enums.UnitFaction.ENEMY, default_enemy_character)

	if player_units.is_empty() and enemy_units.is_empty():
		push_warning("BattleScene: No spawn tiles found — paint Player/Enemy tiles on SpawnTileLayer")

	DebugConfig.log_unit_init("BattleScene: Spawned %d players + %d enemies from tile spawns" % [
		player_units.size(), enemy_units.size()])

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
	for child: Node in get_children():
		if child is TilemapGridBuilder:
			return child as TilemapGridBuilder
	if get_parent() != null:
		for child: Node in get_parent().get_children():
			if child is TilemapGridBuilder:
				return child as TilemapGridBuilder
	return null


func _spawn_units_from_tiles(positions: Array, faction: Enums.UnitFaction, character_path: String) -> Array[Unit]:
	var units: Array[Unit] = []
	# For player units, walk the SquadManager roster instead of relying on the
	# default character_path (this lets the persistent roster determine who
	# spawns and how many slots are filled). For enemy units we still use the
	# tile spawn count + the per-faction default JSON path.
	if faction == Enums.UnitFaction.PLAYER:
		var roster: Array[CharacterData] = SquadManager.get_active_roster()
		var slot_count: int = mini(positions.size(), roster.size())
		for i: int in range(slot_count):
			var grid_pos := positions[i] as Vector2i
			var tile := GridManager.get_tile(grid_pos.x, grid_pos.y)
			if tile == null:
				push_warning("BattleScene: No tile at (%d, %d) for spawn" % [grid_pos.x, grid_pos.y])
				continue
			var unit := _create_unit_from_data(roster[i], faction, tile)
			if unit != null:
				units.append(unit)
		return units

	# Enemy spawns: load from default JSON path each spawn (no persistence).
	for position: Variant in positions:
		var grid_pos := position as Vector2i
		var tile := GridManager.get_tile(grid_pos.x, grid_pos.y)
		if tile == null:
			push_warning("BattleScene: No tile at (%d, %d) for spawn" % [grid_pos.x, grid_pos.y])
			continue
		var unit := _create_unit(character_path, faction, tile)
		if unit != null:
			units.append(unit)
	return units


# =============================================================================
# UNIT CREATION
# =============================================================================

## Spawn a unit from a JSON path. Used for enemies (and as a fallback for tests).
func _create_unit(json_path: String, faction: Enums.UnitFaction, tile: Tile,
		ai_behavior: Enums.AIBehaviorType = Enums.AIBehaviorType.AGGRESSIVE) -> Unit:
	var unit: Unit = _unit_scene.instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	_units_container.add_child(unit)
	unit.initialize(tile)
	unit.auto_assign_first_usable_move()

	if faction == Enums.UnitFaction.ENEMY:
		var enemy_ai := EnemyAI.new()
		enemy_ai.name = "EnemyAI"
		enemy_ai.behavior_type = ai_behavior
		unit.add_child(enemy_ai)

	return unit


## Spawn a unit from a pre-existing CharacterData (the SquadManager-persistent
## path used for player units). The CharacterData reference is shared with the
## roster so any mid-mission state mutations (XP gain, injury queue) persist.
func _create_unit_from_data(character_data: CharacterData, faction: Enums.UnitFaction, tile: Tile,
		ai_behavior: Enums.AIBehaviorType = Enums.AIBehaviorType.AGGRESSIVE) -> Unit:
	var unit: Unit = _unit_scene.instantiate() as Unit
	unit.character_data = character_data
	unit.faction = faction
	_units_container.add_child(unit)
	unit.initialize(tile)
	unit.auto_assign_first_usable_move()

	if faction == Enums.UnitFaction.ENEMY:
		var enemy_ai := EnemyAI.new()
		enemy_ai.name = "EnemyAI"
		enemy_ai.behavior_type = ai_behavior
		unit.add_child(enemy_ai)

	return unit
