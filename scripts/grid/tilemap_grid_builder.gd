## Reads TileMapLayer nodes at runtime and creates Tile nodes in the scene tree.
## Replaces Unity's TilemapToGameObjectSync (1253 lines of reflection hacks)
## with a clean Godot-native approach.
##
## Setup:
## 1. Create a TileSet with custom data layers:
##    - "terrain_type" (String) — matches terrain_data.json keys
##    - "is_modifier" (bool) — if true, this is a Tier 2 modifier tile
## 2. Add these TileMapLayer children to this node:
##    - "TerrainTileLayer" — Tier 1 base terrain
##    - "ModifierTileLayer" — Tier 2 modifiers (COMPLETELY REPLACE floor properties)
##    - "DecorationTileLayer" (optional) — Tier 3 visual-only. Same sprite
##      library as the modifier layer; painting here is the "no gameplay"
##      choice. Rendered by the same TerrainSpriteRenderer overlay (full
##      visual with overhang + shadows), so the layer itself is hidden at
##      runtime just like the modifier layer.
## 3. Paint tiles in the editor. Run the scene. Grid is built automatically.
##
## Three-tier rule: If a modifier exists at (x,y), its terrain_type COMPLETELY
## replaces the floor terrain_type. Never additive.
@tool
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
	# A scene saved while this script was mid-reload (the editor had a map
	# open during a script edit, or a dependency failed to compile for a
	# moment) can write the exported paths as null — test_map_02 caught it
	# on 2026-09-07. An empty path means "the default", never "no layer".
	floor_layer_path = _path_or_default(floor_layer_path, ^"TerrainTileLayer", "floor_layer_path")
	modifier_layer_path = _path_or_default(modifier_layer_path, ^"ModifierTileLayer", "modifier_layer_path")
	decoration_layer_path = _path_or_default(decoration_layer_path, ^"DecorationTileLayer", "decoration_layer_path")
	spawn_layer_path = _path_or_default(spawn_layer_path, ^"SpawnTileLayer", "spawn_layer_path")
	_floor_layer = get_node_or_null(floor_layer_path) as TileMapLayer
	_modifier_layer = get_node_or_null(modifier_layer_path) as TileMapLayer
	_decoration_layer = get_node_or_null(decoration_layer_path) as TileMapLayer
	_spawn_layer = get_node_or_null(spawn_layer_path) as TileMapLayer

	# EDITOR: no grid, no autoloads — just the paint-and-see previews.
	# TerrainSpriteRenderer is @tool; unowned children never reach the .tscn,
	# so the runtime path below starts clean every time.
	if Engine.is_editor_hint():
		_spawn_editor_previews()
		return

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
	# (e.g. a 2x2 castle) expand east and south from the anchor. Per-cell
	# terrain is resolved from data/modifier_terrain.json by SPRITE NAME (the
	# atlas source's resource_name) via ModifierTerrainMap, so a castle's top
	# row can be Wall and its bottom row Castle. Godot's TileMapLayer stores
	# only the anchor cell; footprint occupancy is our convention.
	#
	# Note the asymmetry with the floor path below: floor autotiles carry
	# terrain_type in baked tileset custom_data, while modifiers resolve from
	# the JSON map. Different mechanisms for different shapes — see
	# data/design/terrain_modifiers_and_decorations.md, "Architecture: terrain
	# across three systems".
	var modifier_cells: Dictionary = {}  # Vector2i -> terrain_type
	if _modifier_layer != null:
		for cell: Vector2i in _modifier_layer.get_used_cells():
			var sprite_name := _get_sprite_name_from_layer(_modifier_layer, cell)
			if sprite_name == "":
				continue
			var footprint := _get_footprint_from_layer(_modifier_layer, cell)
			for dx in range(footprint.x):
				for dy in range(footprint.y):
					var cell_terrain := ModifierTerrainMap.resolve(sprite_name, Vector2i(dx, dy))
					if cell_terrain != "":
						modifier_cells[cell + Vector2i(dx, dy)] = cell_terrain

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

	# The floor TileMapLayer stays visible — it displays the actual tileset
	# art. Tile nodes are invisible gameplay objects (selection, occupancy,
	# terrain queries). The modifier + decoration layers get a flat band base
	# here as a fallback; the per-cell TerrainSpriteRenderer overlays spawned
	# below do the real per-row sorting and hide the layers. Enum ref (not a
	# magic number) so it tracks the band across renumbers (e.g. FOOT_TRACKS).
	if _modifier_layer != null:
		_modifier_layer.z_index = int(ZIndexCalculator.ZIndexLayer.TERRAIN_MODIFIERS)
	if _decoration_layer != null:
		_decoration_layer.z_index = int(ZIndexCalculator.ZIndexLayer.TERRAIN_MODIFIERS)
	if _spawn_layer != null:
		_spawn_layer.visible = false

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

	# Spawn the sprite overlays AFTER set_grid_bounds — TerrainSpriteRenderer
	# reads GridManager.grid_offset_y in its _ready to compute front-row z
	# indices, so the bounds must be final first. Each renderer draws its
	# layer's full PNGs (including overhang above/around the gameplay tile)
	# as Sprite2D overlays with occlusion-correct z, and hides its tilemap
	# layer to avoid double-rendering. ORDER MATTERS: modifier first,
	# decoration second — equal-z ties resolve by tree order, so a decoration
	# painted on a modifier's cell draws on top of it.
	if _modifier_layer != null:
		_spawn_sprite_renderer(modifier_layer_path, "ModifierRenderer")
	if _decoration_layer != null:
		_spawn_sprite_renderer(decoration_layer_path, "DecorationRenderer")

	DebugConfig.log_tilemap("TilemapGridBuilder: Created %d tile nodes" % tile_count)


## Null/empty exported path → the conventional default (see _ready). `path`
## is untyped on purpose: a `.tscn` saved with `floor_layer_path = null`
## really does load a null Variant into the typed var, and a NodePath-typed
## parameter would reject it before we could fall back. Warns once per scene
## build so the nulled .tscn gets noticed and cleaned up.
static func _path_or_default(path: Variant, default: NodePath, property_name: String) -> NodePath:
	if path is NodePath and not (path as NodePath).is_empty():
		return path
	push_warning("TilemapGridBuilder: %s is empty in the scene (saved as null?) — using %s. Reset the property in the inspector to clear this." % [
		property_name, default])
	return default


## One TerrainSpriteRenderer per paint layer, as a sibling of the layer.
func _spawn_sprite_renderer(layer_path: NodePath, node_name: String) -> TerrainSpriteRenderer:
	var renderer := TerrainSpriteRenderer.new()
	renderer.name = node_name
	renderer.layer_path = NodePath("../" + str(layer_path).get_file())
	renderer.floor_layer_path = NodePath("../" + str(floor_layer_path).get_file())
	add_child(renderer)
	if not Engine.is_editor_hint():
		assert(renderer.get_spawned_sprites().size() > 0 \
				or (get_node(layer_path) as TileMapLayer).get_used_cells().is_empty(),
				"TilemapGridBuilder: %s painted cells produced no overlay sprites" % node_name)
	return renderer


## Editor-only previews of both paint layers (see TerrainSpriteRenderer's
## header). Same spawn order as the runtime — modifier first, decoration
## second — so tree-order ties resolve the way the game will. Left unowned
## on purpose: the scene tree dock doesn't show them and saving the scene
## doesn't write them.
func _spawn_editor_previews() -> void:
	if _modifier_layer != null:
		_spawn_sprite_renderer(modifier_layer_path, "ModifierPreview")
	if _decoration_layer != null:
		_spawn_sprite_renderer(decoration_layer_path, "DecorationPreview")


func _get_terrain_type_from_layer(layer: TileMapLayer, cell: Vector2i) -> String:
	var tile_data := layer.get_cell_tile_data(cell)
	if tile_data == null:
		return ""

	var terrain_type: Variant = tile_data.get_custom_data("terrain_type")
	if terrain_type is String and terrain_type != "":
		return terrain_type

	return ""


## Reads the painted modifier's sprite name — the atlas source's
## resource_name, set by the registration tool to the sprite basename
## (e.g. "castle_a"). Used to look up per-cell terrain in ModifierTerrainMap.
## Returns "" if the cell isn't an atlas tile.
func _get_sprite_name_from_layer(layer: TileMapLayer, cell: Vector2i) -> String:
	var source_id := layer.get_cell_source_id(cell)
	if source_id < 0 or layer.tile_set == null:
		return ""
	var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null:
		return ""
	return source.resource_name


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
