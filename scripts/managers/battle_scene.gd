## Battle scene root script. Spawns test units and kicks off the turn loop.
## Replaces the temporary phase3_test_driver.gd.
## Unit spawning is hardcoded for Phase 4 — Phase 6 handles map-driven spawning.
extends Node2D


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
	var player_units := _spawn_player_units()
	var enemy_units := _spawn_enemy_units()

	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager != null:
		turn_manager.initialize_battle(player_units, enemy_units)
	else:
		push_warning("BattleScene: TurnManager not found — running without turn loop")


func _spawn_player_units() -> Array[Unit]:
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


func _spawn_enemy_units() -> Array[Unit]:
	var units: Array[Unit] = []
	var offset_x := GridManager.grid_offset_x
	var offset_y := GridManager.grid_offset_y

	var tile_1 := GridManager.get_tile(offset_x + 3, offset_y + 1)
	if tile_1 != null:
		units.append(_create_unit("res://data/characters/fire_warrior.json",
			Enums.UnitFaction.ENEMY, tile_1))

	var tile_2 := GridManager.get_tile(offset_x + 5, offset_y + 3)
	if tile_2 != null:
		units.append(_create_unit("res://data/characters/fire_warrior.json",
			Enums.UnitFaction.ENEMY, tile_2))

	return units


func _create_unit(json_path: String, faction: Enums.UnitFaction, tile: Tile) -> Unit:
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
		unit.add_child(enemy_ai)

	return unit
