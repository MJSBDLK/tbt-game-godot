## Visualizes the planned movement path for a unit.
## Draws rotated arrow sprites along the path between waypoints.
## Set as top_level in unit.tscn so positions are in world space.
class_name PathVisualizer
extends Node2D


const ARROW_ALPHA: float = 0.8
const WAYPOINT_ALPHA: float = 0.9

var _arrow_texture: Texture2D = preload("res://art/sprites/tiles/placeholder_arrow.png")

## Each entry: { tile: Tile, rotation: float }
var _path_entries: Array[Dictionary] = []
var _waypoint_entries: Array[Dictionary] = []


func _ready() -> void:
	# Render above floor tiles but below units
	z_index = ZIndexCalculator.calculate_sorting_order(
		0, 100, ZIndexCalculator.ZIndexLayer.PATH_INDICATORS)


func update_path(unit: Node2D) -> void:
	_path_entries.clear()
	_waypoint_entries.clear()

	var current_tile: Tile = unit.get("current_tile")
	var planned_waypoints: Array = unit.get("planned_waypoints")

	if current_tile == null or planned_waypoints.is_empty():
		queue_redraw()
		return

	# Build ordered list of all tiles along the full path
	var full_path: Array[Tile] = []
	var start: Tile = current_tile
	for waypoint: Variant in planned_waypoints:
		var segment := GridManager.find_path(start, waypoint.tile, unit)
		for tile: Tile in segment:
			if not full_path.has(tile):
				full_path.append(tile)
		start = waypoint.tile

	# Collect waypoint tiles for distinct rendering
	var waypoint_tile_set: Array[Tile] = []
	for waypoint: Variant in planned_waypoints:
		waypoint_tile_set.append(waypoint.tile)

	# Build entries with rotation based on direction to next tile
	for index: int in range(full_path.size()):
		var tile: Tile = full_path[index]
		var rotation_angle: float = 0.0

		if index < full_path.size() - 1:
			# Point toward next tile
			var next_tile: Tile = full_path[index + 1]
			rotation_angle = _get_rotation_toward(tile, next_tile)
		elif index > 0:
			# Last tile: same direction as previous arrow
			var previous_tile: Tile = full_path[index - 1]
			rotation_angle = _get_rotation_toward(previous_tile, tile)

		var entry := { "tile": tile, "rotation": rotation_angle }

		if waypoint_tile_set.has(tile):
			_waypoint_entries.append(entry)
		else:
			_path_entries.append(entry)

	queue_redraw()


func clear_arrows() -> void:
	_path_entries.clear()
	_waypoint_entries.clear()
	queue_redraw()


func _draw() -> void:
	var path_color := Color(GameColors.PATH_ARROW, ARROW_ALPHA)
	for entry: Dictionary in _path_entries:
		var tile: Tile = entry["tile"]
		_draw_arrow(tile.global_position, entry["rotation"], path_color)

	var waypoint_color := Color(GameColors.WAYPOINT_INDICATOR, WAYPOINT_ALPHA)
	for entry: Dictionary in _waypoint_entries:
		var tile: Tile = entry["tile"]
		_draw_arrow(tile.global_position, entry["rotation"], waypoint_color)


func _draw_arrow(world_position: Vector2, rotation_angle: float, color: Color) -> void:
	draw_set_transform(world_position, rotation_angle, Vector2.ONE)
	var texture_size := _arrow_texture.get_size()
	var offset := -texture_size / 2.0
	draw_texture(_arrow_texture, offset, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Returns rotation in radians from one tile toward another.
## Arrow sprite points UP by default, so: up=0, right=PI/2, down=PI, left=-PI/2.
func _get_rotation_toward(from_tile: Tile, to_tile: Tile) -> float:
	var direction_x: int = to_tile.grid_x - from_tile.grid_x
	var direction_y: int = to_tile.grid_y - from_tile.grid_y

	if direction_x == 1:
		return PI / 2.0
	elif direction_x == -1:
		return -PI / 2.0
	elif direction_y == 1:
		return PI
	else:
		return 0.0
