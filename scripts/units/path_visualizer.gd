## Visualizes the planned movement path for a unit.
## Uses draw calls to render colored markers at path tile positions.
## Set as top_level in unit.tscn so positions are in world space.
class_name PathVisualizer
extends Node2D


const MARKER_SIZE: Vector2 = Vector2(6, 6)
const WAYPOINT_SIZE: Vector2 = Vector2(8, 8)

var _path_tiles: Array[Tile] = []
var _waypoint_tiles: Array[Tile] = []


func _ready() -> void:
	# Render above floor tiles but below units
	z_index = ZIndexCalculator.calculate_sorting_order(
		0, 100, ZIndexCalculator.ZIndexLayer.PATH_INDICATORS)


func update_path(unit: Node2D) -> void:
	_path_tiles.clear()
	_waypoint_tiles.clear()

	var current_tile: Tile = unit.get("current_tile")
	var planned_waypoints: Array = unit.get("planned_waypoints")

	if current_tile == null or planned_waypoints.is_empty():
		queue_redraw()
		return

	var start: Tile = current_tile
	for waypoint: Variant in planned_waypoints:
		var segment := GridManager.find_path(start, waypoint.tile, unit)
		for tile: Tile in segment:
			if not _path_tiles.has(tile) and not _waypoint_tiles.has(tile):
				_path_tiles.append(tile)
		_waypoint_tiles.append(waypoint.tile)
		_path_tiles.erase(waypoint.tile)
		start = waypoint.tile

	queue_redraw()


func clear_arrows() -> void:
	_path_tiles.clear()
	_waypoint_tiles.clear()
	queue_redraw()


func _draw() -> void:
	var half_marker := MARKER_SIZE / 2.0
	for tile: Tile in _path_tiles:
		var rect := Rect2(tile.global_position - half_marker, MARKER_SIZE)
		draw_rect(rect, GameColors.PATH_ARROW)

	var half_waypoint := WAYPOINT_SIZE / 2.0
	for tile: Tile in _waypoint_tiles:
		var rect := Rect2(tile.global_position - half_waypoint, WAYPOINT_SIZE)
		draw_rect(rect, GameColors.WAYPOINT_INDICATOR)
