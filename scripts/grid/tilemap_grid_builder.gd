## Reads TileMapLayer nodes at runtime and creates Tile nodes in the scene tree.
## Replaces Unity's TilemapToGameObjectSync (1253 lines of reflection hacks)
## with a clean Godot-native approach.
##
## Setup:
## 1. Create a TileSet with custom data layers:
##    - "terrain_type" (String) — matches terrain_data.json keys
##    - "is_modifier" (bool) — if true, this is a Tier 2 modifier tile
## 2. Add two TileMapLayer children to this node:
##    - "FloorLayer" — Tier 1 base terrain
##    - "ModifierLayer" — Tier 2 modifiers (COMPLETELY REPLACE floor properties)
## 3. Paint tiles in the editor. Run the scene. Grid is built automatically.
##
## Three-tier rule: If a modifier exists at (x,y), its terrain_type COMPLETELY
## replaces the floor terrain_type. Never additive.
class_name TilemapGridBuilder
extends Node2D


@export var floor_layer_path: NodePath = ^"FloorLayer"
@export var modifier_layer_path: NodePath = ^"ModifierLayer"
@export var tile_scene: PackedScene = null

var _floor_layer: TileMapLayer = null
var _modifier_layer: TileMapLayer = null
var _tile_container: Node2D = null


func _ready() -> void:
	_floor_layer = get_node_or_null(floor_layer_path) as TileMapLayer
	_modifier_layer = get_node_or_null(modifier_layer_path) as TileMapLayer

	if _floor_layer == null:
		DebugConfig.log_error("TilemapGridBuilder: FloorLayer not found at '%s'" % str(floor_layer_path))
		return

	if tile_scene == null:
		tile_scene = preload("res://scenes/battle/tile.tscn")

	_tile_container = Node2D.new()
	_tile_container.name = "Tiles"
	add_child(_tile_container)

	_build_grid()


func _build_grid() -> void:
	var floor_cells := _floor_layer.get_used_cells()
	if floor_cells.is_empty():
		DebugConfig.log_error("TilemapGridBuilder: FloorLayer has no painted cells")
		return

	# Calculate grid bounds from painted cells
	var min_x := 999999
	var max_x := -999999
	var min_y := 999999
	var max_y := -999999

	for cell: Vector2i in floor_cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)

	var grid_width := max_x - min_x + 1
	var grid_height := max_y - min_y + 1

	DebugConfig.log_tilemap("TilemapGridBuilder: Building grid from %d floor cells, bounds [%d,%d]->[%d,%d]" % [
		floor_cells.size(), min_x, min_y, max_x, max_y])

	# Get modifier cells for three-tier lookup
	var modifier_cells: Dictionary = {}  # Vector2i -> terrain_type
	if _modifier_layer != null:
		for cell: Vector2i in _modifier_layer.get_used_cells():
			var terrain_type := _get_terrain_type_from_layer(_modifier_layer, cell)
			if terrain_type != "":
				modifier_cells[cell] = terrain_type

	# Build tiles
	var tile_count := 0
	for cell: Vector2i in floor_cells:
		var terrain_type: String

		# Three-tier rule: modifier COMPLETELY REPLACES floor
		if modifier_cells.has(cell):
			terrain_type = modifier_cells[cell]
		else:
			terrain_type = _get_terrain_type_from_layer(_floor_layer, cell)
			if terrain_type == "":
				terrain_type = "Plains"

		var tile: Tile = tile_scene.instantiate() as Tile
		_tile_container.add_child(tile)

		# Godot TileMapLayer uses cell coordinates directly
		# In our isometric-free setup, cell coords = world integer coords
		# Note: TileMapLayer Y axis may be inverted compared to our grid.
		# Godot's TileMapLayer Y increases downward, but our game grid Y increases upward.
		# We negate the Y coordinate to match our convention.
		var grid_x := cell.x
		var grid_y := -cell.y  # Flip Y: Godot tilemap Y-down -> game grid Y-up

		tile.position = Vector2(grid_x, grid_y)
		tile.terrain_type_name = terrain_type
		tile.initialize(grid_x, grid_y)

		# Z-index setup
		var z_handler := GridZIndexHandler.new()
		z_handler.layer = ZIndexCalculator.ZIndexLayer.FLOOR_TILES
		z_handler.row_override = (min_y * -1 + grid_height - 1) - grid_y  # Convert to row index
		tile.add_child(z_handler)

		# Register with GridManager
		GridManager.register_tile(tile)
		tile_count += 1

	# Hide the TileMapLayers — the Tile nodes are the visual representation now
	_floor_layer.visible = false
	if _modifier_layer != null:
		_modifier_layer.visible = false

	# Finalize grid
	GridManager.set_grid_bounds(grid_width, grid_height, min_x, -max_y)

	DebugConfig.log_tilemap("TilemapGridBuilder: Created %d tile nodes" % tile_count)


func _get_terrain_type_from_layer(layer: TileMapLayer, cell: Vector2i) -> String:
	var tile_data := layer.get_cell_tile_data(cell)
	if tile_data == null:
		return ""

	var terrain_type: Variant = tile_data.get_custom_data("terrain_type")
	if terrain_type is String and terrain_type != "":
		return terrain_type

	return ""
