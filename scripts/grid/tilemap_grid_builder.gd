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
##    - "DecorationLayer" (optional) — Tier 3 visual-only (stays visible at runtime)
## 3. Paint tiles in the editor. Run the scene. Grid is built automatically.
##
## Three-tier rule: If a modifier exists at (x,y), its terrain_type COMPLETELY
## replaces the floor terrain_type. Never additive.
class_name TilemapGridBuilder
extends Node2D


@export var floor_layer_path: NodePath = ^"TerrainTileLayer"
@export var modifier_layer_path: NodePath = ^"ModifierTileLayer"
@export var decoration_layer_path: NodePath = ^"DecorationTileLayer"
@export var spawn_layer_path: NodePath = ^"SpawnTileLayer"
@export var tile_scene: PackedScene = null

var _floor_layer: TileMapLayer = null
var _modifier_layer: TileMapLayer = null
var _decoration_layer: TileMapLayer = null
var _spawn_layer: TileMapLayer = null
var _tile_container: Node2D = null


func _ready() -> void:
	_floor_layer = get_node_or_null(floor_layer_path) as TileMapLayer
	_modifier_layer = get_node_or_null(modifier_layer_path) as TileMapLayer
	_decoration_layer = get_node_or_null(decoration_layer_path) as TileMapLayer
	_spawn_layer = get_node_or_null(spawn_layer_path) as TileMapLayer

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
	# Clear any previous grid state (supports scene transitions between maps)
	GridManager.clear_grid()

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

	# Get modifier cells for three-tier lookup. A painted cell is the ANCHOR
	# (top-left / north-west) of its tile's footprint: multi-cell tiles
	# (e.g. a 2x2 castle) expand east and south from the anchor, applying
	# the same terrain_type to every covered cell. Godot's TileMapLayer
	# stores only the anchor cell; footprint occupancy is our convention
	# (see data/design/terrain_modifiers_and_decorations.md).
	var modifier_cells: Dictionary = {}  # Vector2i -> terrain_type
	if _modifier_layer != null:
		for cell: Vector2i in _modifier_layer.get_used_cells():
			var terrain_type := _get_terrain_type_from_layer(_modifier_layer, cell)
			if terrain_type == "":
				continue
			var footprint := _get_footprint_from_layer(_modifier_layer, cell)
			for dx in range(footprint.x):
				for dy in range(footprint.y):
					modifier_cells[cell + Vector2i(dx, dy)] = terrain_type

	# Build tiles
	var tile_size: int = _floor_layer.tile_set.tile_size.x
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

		# Game grid uses Y-up; TileMapLayer uses Y-down.  We keep both:
		# - grid_x/grid_y: game-logic coordinates (Y-up, integer)
		# - tile.position: pixel position matching TileMapLayer cell CENTER
		var grid_x := cell.x
		var grid_y := -cell.y  # Flip Y: Godot tilemap Y-down -> game grid Y-up
		var half_tile := tile_size / 2
		tile.position = Vector2(cell.x * tile_size + half_tile, cell.y * tile_size + half_tile)
		tile.terrain_type_name = terrain_type
		tile.initialize(grid_x, grid_y)

		# Z-index setup
		var z_handler := GridZIndexHandler.new()
		z_handler.layer = ZIndexCalculator.ZIndexLayer.FLOOR_TILES
		z_handler.row_override = max_y + grid_y  # Front row (cell.y=max_y) → index 0 (highest z)
		tile.add_child(z_handler)

		# Register with GridManager
		GridManager.register_tile(tile)
		tile_count += 1

	# Keep TileMapLayers visible — they display the actual tileset art.
	# Tile nodes are invisible gameplay objects (selection, occupancy, terrain queries).
	if _modifier_layer != null:
		_modifier_layer.z_index = 2  # Between floor (0/1) and decoration (3)
	if _spawn_layer != null:
		_spawn_layer.visible = false
	if _decoration_layer != null:
		_decoration_layer.z_index = 3  # Above floor tiles, below units

	# Apply boundary markers if any were placed
	var boundary := get_boundary_rect()
	if boundary.has_area():
		GridManager.trim_to_bounds(boundary.position.x, boundary.position.y,
			boundary.position.x + boundary.size.x - 1,
			boundary.position.y + boundary.size.y - 1)
		GridManager.set_grid_bounds(boundary.size.x, boundary.size.y,
			boundary.position.x, boundary.position.y, tile_size)
		DebugConfig.log_tilemap("TilemapGridBuilder: Boundary markers found — trimmed to %s" % str(boundary))
	else:
		GridManager.set_grid_bounds(grid_width, grid_height, min_x, -max_y, tile_size)

	# Spawn the modifier overlay AFTER set_grid_bounds — ModifierRenderer
	# reads GridManager.grid_offset_y in its _ready to compute front-row z
	# indices, so the bounds must be final first. The renderer draws each
	# modifier's full PNG (including overhang above/around the gameplay
	# tile) as Sprite2D overlays with occlusion-correct z, and hides the
	# modifier tilemap layer to avoid double-rendering.
	if _modifier_layer != null:
		var modifier_renderer := ModifierRenderer.new()
		modifier_renderer.name = "ModifierRenderer"
		modifier_renderer.modifier_layer_path = NodePath("../" + str(modifier_layer_path).get_file())
		add_child(modifier_renderer)

	DebugConfig.log_tilemap("TilemapGridBuilder: Created %d tile nodes" % tile_count)


func _get_terrain_type_from_layer(layer: TileMapLayer, cell: Vector2i) -> String:
	var tile_data := layer.get_cell_tile_data(cell)
	if tile_data == null:
		return ""

	var terrain_type: Variant = tile_data.get_custom_data("terrain_type")
	if terrain_type is String and terrain_type != "":
		return terrain_type

	return ""


## Reads the painted cell's tile footprint (size_in_atlas) from its atlas
## source. (1, 1) for plain tiles, missing cells, or non-atlas sources.
func _get_footprint_from_layer(layer: TileMapLayer, cell: Vector2i) -> Vector2i:
	var source_id := layer.get_cell_source_id(cell)
	if source_id < 0 or layer.tile_set == null:
		return Vector2i.ONE
	var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null:
		return Vector2i.ONE
	var atlas_coords := layer.get_cell_atlas_coords(cell)
	return source.get_tile_size_in_atlas(atlas_coords)


## Loads `scene_path` (a mission .tscn) off-tree and counts the cells on its
## SpawnTileLayer marked with spawn_faction == "Player". Used by the squad
## prep screen to show how many slots the next mission has without booting the
## battle. Returns 0 if the scene can't be loaded or has no spawn layer.
##
## Note: instantiate() builds the node graph but does NOT call _ready, so this
## doesn't trigger GridManager.clear_grid() or any other side effects.
static func count_player_spawns(scene_path: String) -> int:
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return 0
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return 0
	var instance: Node = packed.instantiate()
	if instance == null:
		return 0
	var count: int = 0
	var builder: TilemapGridBuilder = _find_builder_in(instance)
	if builder != null:
		var spawn_layer: TileMapLayer = builder.get_node_or_null(builder.spawn_layer_path) as TileMapLayer
		if spawn_layer != null:
			for cell: Vector2i in spawn_layer.get_used_cells():
				var tile_data := spawn_layer.get_cell_tile_data(cell)
				if tile_data == null:
					continue
				var spawn_faction: Variant = tile_data.get_custom_data("spawn_faction")
				if spawn_faction is String and spawn_faction == "Player":
					count += 1
	instance.queue_free()
	return count


static func _find_builder_in(node: Node) -> TilemapGridBuilder:
	if node is TilemapGridBuilder:
		return node as TilemapGridBuilder
	for child: Node in node.get_children():
		var found := _find_builder_in(child)
		if found != null:
			return found
	return null


## Returns spawn points from the SpawnTileLayer, grouped by faction.
## Player spawns: Array[Vector2i] (game-grid coordinates, Y-up).
## Enemy spawns: Array[Dictionary] of {position: Vector2i, difficulty: EnemyDifficulty}.
## The difficulty comes from the tile's "spawn_difficulty" custom data — empty
## or unrecognized values fall back to EnemyDifficulty.DEFAULT.
func get_spawn_points() -> Dictionary:
	var result: Dictionary = {"Player": [], "Enemy": []}

	if _spawn_layer == null:
		return result

	for cell: Vector2i in _spawn_layer.get_used_cells():
		var tile_data := _spawn_layer.get_cell_tile_data(cell)
		if tile_data == null:
			continue

		var spawn_faction: Variant = tile_data.get_custom_data("spawn_faction")
		if not (spawn_faction is String and spawn_faction != ""):
			continue
		if spawn_faction == "Boundary":
			continue  # Boundary markers are not spawn points

		var grid_x := cell.x
		var grid_y := -cell.y  # Flip Y: Godot tilemap Y-down -> game grid Y-up
		var grid_pos := Vector2i(grid_x, grid_y)

		if spawn_faction == "Player":
			result["Player"].append(grid_pos)
		elif spawn_faction == "Enemy":
			var difficulty := Enums.EnemyDifficulty.DEFAULT
			var diff_name: Variant = tile_data.get_custom_data("spawn_difficulty")
			if diff_name is String and diff_name != "":
				if Enums.SPAWN_DIFFICULTY_BY_NAME.has(diff_name):
					difficulty = Enums.SPAWN_DIFFICULTY_BY_NAME[diff_name]
				else:
					push_warning("TilemapGridBuilder: Unknown spawn_difficulty '%s' at cell %s" % [diff_name, cell])
			result["Enemy"].append({"position": grid_pos, "difficulty": difficulty})
		else:
			push_warning("TilemapGridBuilder: Unknown spawn_faction '%s' at cell %s" % [spawn_faction, cell])

	DebugConfig.log_tilemap("TilemapGridBuilder: Found %d player spawns, %d enemy spawns" % [
		result["Player"].size(), result["Enemy"].size()])

	return result


## Returns the playable boundary as a Rect2i in game-grid coords (Y-up).
## Reads all spawn layer cells whose spawn_faction == "Boundary" and
## computes the bounding rect of those corners.
## Returns an empty Rect2i if no boundary corner tiles are placed.
func get_boundary_rect() -> Rect2i:
	if _spawn_layer == null:
		return Rect2i()

	var boundary_cells: Array[Vector2i] = []
	for cell: Vector2i in _spawn_layer.get_used_cells():
		var tile_data := _spawn_layer.get_cell_tile_data(cell)
		if tile_data == null:
			continue
		var spawn_faction: Variant = tile_data.get_custom_data("spawn_faction")
		if spawn_faction is String and spawn_faction == "Boundary":
			boundary_cells.append(cell)

	if boundary_cells.size() == 0:
		return Rect2i()

	var min_x := boundary_cells[0].x
	var max_x := boundary_cells[0].x
	var min_y := -boundary_cells[0].y   # Y-flip: tilemap Y-down -> game grid Y-up
	var max_y := -boundary_cells[0].y
	for cell: Vector2i in boundary_cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, -cell.y)
		max_y = maxi(max_y, -cell.y)

	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
