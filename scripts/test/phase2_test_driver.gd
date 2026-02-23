## Temporary test driver for Phase 2 unit system.
## Left-click: select player unit or add waypoint to movement range tile.
## Right-click: execute planned movement (or deselect if no waypoints).
## Replaced by InputManager in Phase 4.
extends Node2D


var _unit_scene: PackedScene = preload("res://scenes/battle/unit.tscn")
var _selected_unit: Unit = null
var _units_container: Node2D = null


func _ready() -> void:
	_units_container = Node2D.new()
	_units_container.name = "Units"
	add_child(_units_container)

	if GridManager.is_grid_ready():
		_spawn_test_units()
	else:
		GridManager.grid_ready.connect(_spawn_test_units)


func _spawn_test_units() -> void:
	var offset_x: int = GridManager.grid_offset_x
	var offset_y: int = GridManager.grid_offset_y

	# Player unit near bottom-left
	var player_tile := GridManager.get_tile(offset_x + 1, offset_y + 1)
	if player_tile != null:
		_create_unit("res://data/characters/spaceman.json", Enums.UnitFaction.PLAYER, player_tile)
		print("Phase2Test: Spawned player unit at %s" % player_tile.get_coordinates())

	# Enemy unit near top-right
	var enemy_tile := GridManager.get_tile(offset_x + 6, offset_y + 6)
	if enemy_tile != null:
		_create_unit("res://data/characters/spaceman.json", Enums.UnitFaction.ENEMY, enemy_tile)
		print("Phase2Test: Spawned enemy unit at %s" % enemy_tile.get_coordinates())


func _create_unit(json_path: String, faction: Enums.UnitFaction, tile: Tile) -> Unit:
	var unit: Unit = _unit_scene.instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	_units_container.add_child(unit)
	unit.initialize(tile)
	return unit


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return

	var mouse_event := event as InputEventMouseButton
	var world_position := get_global_mouse_position()
	var clicked_tile := GridManager.get_tile_at_position(world_position)

	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(clicked_tile)
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click()


func _handle_left_click(clicked_tile: Tile) -> void:
	if clicked_tile == null:
		return

	# Clicking a player unit — select it
	if clicked_tile.current_unit != null and clicked_tile.current_unit is Unit:
		var clicked_unit := clicked_tile.current_unit as Unit
		if clicked_unit.faction == Enums.UnitFaction.PLAYER and clicked_unit.can_act:
			_select_unit(clicked_unit)
			return

	# Clicking a movement range tile — add waypoint
	if _selected_unit != null and _selected_unit.can_act:
		if GridManager.is_in_current_movement_range(clicked_tile):
			var success := _selected_unit.add_waypoint(clicked_tile)
			if success:
				GridManager.display_movement_range(_selected_unit)
				print("Phase2Test: Waypoint added at %s" % clicked_tile.get_coordinates())


func _handle_right_click() -> void:
	if _selected_unit == null:
		return

	if not _selected_unit.planned_waypoints.is_empty():
		# Execute movement
		_selected_unit.movement_completed.connect(
			_on_movement_completed.bind(_selected_unit), CONNECT_ONE_SHOT)
		_selected_unit.execute_planned_movement()
		GridManager.clear_movement_range()
		print("Phase2Test: Executing movement")
	else:
		# Deselect
		_deselect_unit()


func _select_unit(unit: Unit) -> void:
	if _selected_unit != null:
		_deselect_unit()
	_selected_unit = unit
	_selected_unit.set_selected(true)
	GridManager.display_movement_range(_selected_unit)
	print("Phase2Test: Selected '%s'" % unit.unit_name)


func _deselect_unit() -> void:
	if _selected_unit == null:
		return
	_selected_unit.set_selected(false)
	_selected_unit.clear_waypoints()
	GridManager.clear_movement_range()
	_selected_unit = null
	print("Phase2Test: Deselected")


func _on_movement_completed(unit: Unit) -> void:
	unit.set_acted()
	_selected_unit = null
	print("Phase2Test: Movement complete, unit acted")
