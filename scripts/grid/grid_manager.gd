## Core grid system managing tile storage, neighbor lookups, BFS movement range,
## A* pathfinding, and visual range display.
## Registered as Autoload "GridManager".
##
## All coordinates are INTEGER only. No 0.5 offsets.
## MOVEMENT_SCALE = 2 — internal half-tile precision for movement costs.
extends Node

const MOVEMENT_SCALE: int = 2

signal grid_ready

# Grid storage
var _grid: Dictionary = {}  # Dictionary<Vector2i, Tile>
var _grid_width: int = 0
var _grid_height: int = 0
var _grid_offset_x: int = 0
var _grid_offset_y: int = 0
var _tile_size: int = 16

# Visual state
var _hovered_tile: Tile = null
var _selected_tile: Tile = null
var _current_movement_range_tiles: Array[Tile] = []
var _current_attack_range_tiles: Array[Tile] = []

# Public read-only accessors
var grid_width: int:
	get: return _grid_width
var grid_height: int:
	get: return _grid_height
var grid_offset_x: int:
	get: return _grid_offset_x
var grid_offset_y: int:
	get: return _grid_offset_y
var tile_size: int:
	get: return _tile_size


# =============================================================================
# GRID SETUP (called by TilemapGridBuilder)
# =============================================================================

## Register a tile in the grid at the given integer coordinates.
func register_tile(tile: Tile) -> void:
	var key := Vector2i(tile.grid_x, tile.grid_y)
	_grid[key] = tile


## Finalize grid dimensions after all tiles are registered.
func set_grid_bounds(width: int, height: int, offset_x: int = 0, offset_y: int = 0, p_tile_size: int = 16) -> void:
	_grid_width = width
	_grid_height = height
	_grid_offset_x = offset_x
	_grid_offset_y = offset_y
	_tile_size = p_tile_size
	DebugConfig.log_grid("GridManager: Grid ready — %dx%d, offset (%d,%d), tile_size=%d, %d tiles" % [
		width, height, offset_x, offset_y, p_tile_size, _grid.size()])
	grid_ready.emit()


func is_grid_ready() -> bool:
	return _grid.size() > 0


## Clear the entire grid (used when loading a new map).
func clear_grid() -> void:
	_grid.clear()
	_grid_width = 0
	_grid_height = 0
	_grid_offset_x = 0
	_grid_offset_y = 0
	_hovered_tile = null
	_selected_tile = null
	_current_movement_range_tiles.clear()
	_current_attack_range_tiles.clear()


# =============================================================================
# TILE LOOKUP
# =============================================================================

## Get the tile at integer grid coordinates. Returns null if out of bounds.
func get_tile(x: int, y: int) -> Tile:
	var key := Vector2i(x, y)
	return _grid.get(key, null) as Tile


## Get the tile at a world position (converts pixel coords to grid coords).
func get_tile_at_position(world_position: Vector2) -> Tile:
	var tile_x := roundi(world_position.x / float(_tile_size))
	var tile_y := roundi(world_position.y / float(_tile_size))
	return get_tile(tile_x, tile_y)


## Get the 4-directional neighbors of a tile (up, right, down, left).
func get_neighbors(tile: Tile) -> Array[Tile]:
	var neighbors: Array[Tile] = []
	var directions := [
		Vector2i(0, 1),   # up
		Vector2i(1, 0),   # right
		Vector2i(0, -1),  # down
		Vector2i(-1, 0),  # left
	]
	for direction: Vector2i in directions:
		var neighbor := get_tile(tile.grid_x + direction.x, tile.grid_y + direction.y)
		if neighbor != null:
			neighbors.append(neighbor)
	return neighbors


# =============================================================================
# MOVEMENT RANGE — BFS FLOOD FILL
# =============================================================================

## Calculate all tiles reachable by a unit within its movement range.
## Units can path through friendlies but cannot end on them.
## Enemy units block pathing entirely.
func get_movement_range(unit: Node2D) -> Array[Tile]:
	var valid_tiles: Array[Tile] = []
	if unit == null:
		return valid_tiles

	var current_tile: Tile = unit.get("current_tile")
	var max_movement: int = unit.get("max_movement_range")
	var unit_type: String = _get_unit_type(unit)
	var unit_faction: Variant = unit.get("faction")

	if current_tile == null:
		DebugConfig.log_error("GridManager: Unit has no current_tile for movement range")
		return valid_tiles

	var tile_costs: Dictionary = {}  # Dictionary<Tile, int>
	var tiles_to_check: Array[Tile] = []

	tile_costs[current_tile] = 0
	tiles_to_check.append(current_tile)

	while tiles_to_check.size() > 0:
		var check_tile: Tile = tiles_to_check.pop_front()
		var current_cost: int = tile_costs[check_tile]
		var neighbors := get_neighbors(check_tile)

		for neighbor: Tile in neighbors:
			if not neighbor.can_unit_move_to(unit_type):
				continue

			var move_cost := ceili(neighbor.get_movement_cost_for_unit(unit_type))
			var cost_to_neighbor := current_cost + move_cost

			if cost_to_neighbor > max_movement:
				continue

			# Enemy units block pathfinding
			if neighbor.current_unit != null and neighbor != current_tile:
				var occupant_faction: Variant = neighbor.current_unit.get("faction")
				if occupant_faction != unit_faction:
					continue

			# Update if cheaper path found
			if not tile_costs.has(neighbor) or cost_to_neighbor < tile_costs[neighbor]:
				tile_costs[neighbor] = cost_to_neighbor
				tiles_to_check.append(neighbor)

				# Can only end on unoccupied tiles
				var is_occupied := neighbor.current_unit != null and neighbor != current_tile
				if not is_occupied and not valid_tiles.has(neighbor):
					valid_tiles.append(neighbor)

	return valid_tiles


## Calculate remaining movement range from last waypoint position.
func get_remaining_movement_range(unit: Node2D) -> Array[Tile]:
	var valid_tiles: Array[Tile] = []
	if unit == null:
		return valid_tiles

	var max_movement: int = unit.get("max_movement_range")
	var planned_waypoints: Array = unit.get("planned_waypoints")
	var unit_type: String = _get_unit_type(unit)

	var used_movement: int = unit.call("get_total_planned_movement_cost")
	var remaining_movement := max_movement - used_movement
	if remaining_movement <= 0:
		return valid_tiles

	var start_tile: Tile
	if planned_waypoints.size() > 0:
		start_tile = planned_waypoints[-1].get("tile")
	else:
		start_tile = unit.get("current_tile")

	if start_tile == null:
		return valid_tiles

	var tile_costs: Dictionary = {}
	var tiles_to_check: Array[Tile] = []

	tile_costs[start_tile] = 0
	tiles_to_check.append(start_tile)

	while tiles_to_check.size() > 0:
		var check_tile: Tile = tiles_to_check.pop_front()
		var current_cost: int = tile_costs[check_tile]
		var neighbors := get_neighbors(check_tile)

		for neighbor: Tile in neighbors:
			if not neighbor.can_unit_move_to(unit_type):
				continue

			var cost_to_neighbor := current_cost + ceili(neighbor.get_movement_cost_for_unit(unit_type))
			if cost_to_neighbor > remaining_movement:
				continue
			if neighbor.current_unit != null and neighbor != start_tile:
				continue

			if not tile_costs.has(neighbor) or cost_to_neighbor < tile_costs[neighbor]:
				tile_costs[neighbor] = cost_to_neighbor
				tiles_to_check.append(neighbor)
				if not valid_tiles.has(neighbor) and neighbor != start_tile:
					valid_tiles.append(neighbor)

	return valid_tiles


# =============================================================================
# VISUAL RANGE DISPLAY
# =============================================================================

func display_movement_range(unit: Node2D) -> void:
	if unit == null:
		return
	clear_movement_range()

	var planned_waypoints: Array = unit.get("planned_waypoints")
	var movement_tiles: Array[Tile]
	if planned_waypoints.size() > 0:
		movement_tiles = get_remaining_movement_range(unit)
	else:
		movement_tiles = get_movement_range(unit)

	for tile: Tile in movement_tiles:
		tile.set_color(GameColors.MOVEMENT_RANGE)
		_current_movement_range_tiles.append(tile)


func clear_movement_range() -> void:
	for tile: Tile in _current_movement_range_tiles:
		if tile != _selected_tile:
			tile.set_color(GameColors.TILE_DEFAULT)
	_current_movement_range_tiles.clear()


func is_in_current_movement_range(tile: Tile) -> bool:
	return _current_movement_range_tiles.has(tile)


func display_attack_range(attack_tiles: Array[Tile]) -> void:
	clear_attack_range()
	for tile: Tile in attack_tiles:
		tile.set_color(GameColors.ATTACK_RANGE)
		_current_attack_range_tiles.append(tile)


func clear_attack_range() -> void:
	for tile: Tile in _current_attack_range_tiles:
		if tile != _selected_tile:
			tile.set_color(GameColors.TILE_DEFAULT)
	_current_attack_range_tiles.clear()


## Get all tiles within Manhattan distance of a center tile.
func get_tiles_within_range(center_tile: Tile, attack_range: int) -> Array[Tile]:
	var tiles_in_range: Array[Tile] = []
	if center_tile == null:
		return tiles_in_range

	# Search within bounding box
	for x: int in range(center_tile.grid_x - attack_range, center_tile.grid_x + attack_range + 1):
		for y: int in range(center_tile.grid_y - attack_range, center_tile.grid_y + attack_range + 1):
			var check_tile := get_tile(x, y)
			if check_tile == null:
				continue
			var distance := absi(check_tile.grid_x - center_tile.grid_x) + absi(check_tile.grid_y - center_tile.grid_y)
			if distance <= attack_range and distance > 0:
				tiles_in_range.append(check_tile)

	return tiles_in_range


# =============================================================================
# HOVER / SELECTION
# =============================================================================

func set_hovered_tile(tile: Tile) -> void:
	# Restore previous hovered tile color
	if _hovered_tile != null and _hovered_tile != _selected_tile:
		if _current_movement_range_tiles.has(_hovered_tile):
			_hovered_tile.set_color(GameColors.MOVEMENT_RANGE)
		elif _current_attack_range_tiles.has(_hovered_tile):
			_hovered_tile.set_color(GameColors.ATTACK_RANGE)
		else:
			_hovered_tile.set_color(GameColors.TILE_DEFAULT)

	_hovered_tile = tile

	if _hovered_tile != null and _hovered_tile != _selected_tile:
		if _current_movement_range_tiles.has(_hovered_tile):
			_hovered_tile.set_color(GameColors.MOVEMENT_RANGE_HOVERED)
		elif _current_attack_range_tiles.has(_hovered_tile):
			_hovered_tile.set_color(GameColors.ATTACK_RANGE_HOVERED)
		else:
			_hovered_tile.set_color(GameColors.TILE_HOVERED)


func set_selected_tile(tile: Tile) -> void:
	if _selected_tile != null:
		_selected_tile.set_color(GameColors.TILE_DEFAULT)
	_selected_tile = tile
	if _selected_tile != null:
		_selected_tile.set_color(GameColors.TILE_SELECTED)


func clear_selected_tile() -> void:
	if _selected_tile != null:
		_selected_tile.set_color(GameColors.TILE_DEFAULT)
		_selected_tile = null


# =============================================================================
# A* PATHFINDING
# =============================================================================

## Find shortest path from start_tile to target_tile for the given unit.
## Returns an array of tiles (excluding start, including target).
func find_path(start_tile: Tile, target_tile: Tile, unit: Node2D) -> Array[Tile]:
	var empty_path: Array[Tile] = []
	if start_tile == null or target_tile == null or unit == null:
		return empty_path

	var unit_type: String = _get_unit_type(unit)
	if not target_tile.can_unit_move_to(unit_type):
		return empty_path
	if target_tile.current_unit != null and target_tile != start_tile:
		return empty_path

	var open_list: Array[PathNode] = []
	var closed_set: Dictionary = {}  # Dictionary<Tile, bool>
	var node_map: Dictionary = {}    # Dictionary<Tile, PathNode>

	var start_node := PathNode.new(start_tile)
	start_node.cost_from_start = 0
	start_node.estimated_cost_to_goal = _manhattan_distance(start_tile, target_tile)
	open_list.append(start_node)
	node_map[start_tile] = start_node

	while open_list.size() > 0:
		# Find node with lowest total score
		var current_node: PathNode = open_list[0]
		for i: int in range(1, open_list.size()):
			var candidate: PathNode = open_list[i]
			if candidate.total_path_score < current_node.total_path_score or \
				(candidate.total_path_score == current_node.total_path_score and \
				 candidate.estimated_cost_to_goal < current_node.estimated_cost_to_goal):
				current_node = candidate

		open_list.erase(current_node)
		closed_set[current_node.tile] = true

		# Found target
		if current_node.tile == target_tile:
			return _retrace_path(start_node, current_node)

		var neighbors := get_neighbors(current_node.tile)
		for neighbor: Tile in neighbors:
			if not neighbor.can_unit_move_to(unit_type) or closed_set.has(neighbor):
				continue

			# Can't move through enemies
			if neighbor.current_unit != null and neighbor != target_tile:
				var unit_faction: Variant = unit.get("faction")
				var occupant_faction: Variant = neighbor.current_unit.get("faction")
				if occupant_faction != unit_faction:
					continue

			var new_cost := current_node.cost_from_start + ceili(neighbor.get_movement_cost_for_unit(unit_type))

			var neighbor_node: PathNode
			if not node_map.has(neighbor):
				neighbor_node = PathNode.new(neighbor)
				neighbor_node.estimated_cost_to_goal = _manhattan_distance(neighbor, target_tile)
				neighbor_node.cost_from_start = 999999
				node_map[neighbor] = neighbor_node
				open_list.append(neighbor_node)
			else:
				neighbor_node = node_map[neighbor]

			if new_cost < neighbor_node.cost_from_start:
				neighbor_node.cost_from_start = new_cost
				neighbor_node.parent = current_node
				if not open_list.has(neighbor_node):
					open_list.append(neighbor_node)

	# No path found
	DebugConfig.log_grid("No path from %s to %s" % [start_tile.get_coordinates(), target_tile.get_coordinates()])
	return empty_path


## Calculate the total movement cost of a path for a given unit.
func calculate_path_cost(path: Array[Tile], unit: Node2D = null) -> int:
	if path.is_empty():
		return 0
	var total_cost := 0
	var unit_type: String = _get_unit_type(unit)
	for tile: Tile in path:
		total_cost += ceili(tile.get_movement_cost_for_unit(unit_type))
	return total_cost


# =============================================================================
# PRIVATE HELPERS
# =============================================================================

func _manhattan_distance(tile_a: Tile, tile_b: Tile) -> int:
	return absi(tile_a.grid_x - tile_b.grid_x) + absi(tile_a.grid_y - tile_b.grid_y)


func _retrace_path(start_node: PathNode, end_node: PathNode) -> Array[Tile]:
	var path: Array[Tile] = []
	if start_node.tile == end_node.tile:
		return path

	var current_node := end_node
	var safety := 0
	while current_node != start_node and safety < 200:
		safety += 1
		if current_node == null:
			DebugConfig.log_error("GridManager: null node during path retrace")
			break
		path.append(current_node.tile)
		if current_node.parent == null and current_node != start_node:
			DebugConfig.log_error("GridManager: broken parent chain at %s" % current_node.tile.get_coordinates())
			break
		current_node = current_node.parent

	if safety >= 200:
		DebugConfig.log_error("GridManager: path retrace hit safety limit")

	path.reverse()
	return path


func _get_unit_type(unit: Node2D) -> String:
	if unit == null:
		return ""
	var character_data: Variant = unit.get("character_data")
	if character_data == null:
		return ""
	var primary_type: Variant = character_data.get("primary_type")
	if primary_type == null:
		return ""
	return Enums.elemental_type_to_string(primary_type)
