## MissionPreview — a mission map as a diorama: the board as the battle will
## first see it, with no battle behind it and no HUD on it. The intermission
## stage stands in front of it (MenuStageBackdrop, while Lawrence's ship
## interior is unpainted) and every save's picture is one frame of it
## (SaveManager), so the main menu's Continue shows the mission you're on as
## it began — never a mid-battle frame with the hint bar and the carnage.
##
## What gets rendered: the map's TilemapBuilder subtree — floor autotiles as
## painted, modifier and decoration layers through the same
## TerrainSpriteRenderer overlays the battle uses (full sprites, overhang,
## shadows), spawn markers hidden — and the deployed squad standing on the
## player spawns in the battle's own order (BattleScene.deployed_roster ↔
## the spawn layer's cell order), each unit a sprite and its cast shadow with
## its battle chrome hidden. Enemies aren't rolled until the battle starts,
## so their spawns stay empty. The builder's script is dropped before it
## enters the tree, so no grid is built and GridManager is never touched:
## this is a picture of a map, never a board. Framed by an integer-zoom
## camera that COVERS the canvas (crop, never letterbox — the vignette on
## top hides the edges either way); at the HUD canvas size every map ships
## covers at zoom 1, which is the game's own scale.
class_name MissionPreview
extends RefCounted


const REFERENCE_SIZE: Vector2i = Vector2i(640, 360)
const DEFAULT_FLOOR_LAYER: NodePath = ^"TerrainTileLayer"
const DEFAULT_MODIFIER_LAYER: NodePath = ^"ModifierTileLayer"
const DEFAULT_DECORATION_LAYER: NodePath = ^"DecorationTileLayer"
const DEFAULT_SPAWN_LAYER: NodePath = ^"SpawnTileLayer"
const TILE_SCENE: PackedScene = preload("res://scenes/battle/tile.tscn")
const UNIT_SCENE: PackedScene = preload("res://scenes/battle/unit.tscn")


## A SubViewport showing the map at `scene_path` with `squad` seated on its
## player spawns, sized to `canvas`. Null when the scene is missing, has no
## grid builder, or has no painted floor. The caller parents it; the squad
## is seated and the camera made current the moment it enters the tree
## (units need the tree to place themselves), and it keeps rendering — a
## diorama, so whatever animates on the board animates here.
static func build(scene_path: String, canvas: Vector2i = REFERENCE_SIZE,
		squad: Array[CharacterData] = []) -> SubViewport:
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return null
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return null
	var instance: Node = packed.instantiate()
	if instance == null:
		return null
	var builder: TilemapGridBuilder = TilemapGridBuilder._find_builder_in(instance)
	if builder == null:
		instance.free()
		return null

	var floor_path: NodePath = _layer_path(builder.floor_layer_path, DEFAULT_FLOOR_LAYER)
	var modifier_path: NodePath = _layer_path(builder.modifier_layer_path, DEFAULT_MODIFIER_LAYER)
	var decoration_path: NodePath = _layer_path(builder.decoration_layer_path, DEFAULT_DECORATION_LAYER)
	var spawn_path: NodePath = _layer_path(builder.spawn_layer_path, DEFAULT_SPAWN_LAYER)
	var floor_layer: TileMapLayer = builder.get_node_or_null(floor_path) as TileMapLayer
	if floor_layer == null or floor_layer.tile_set == null or floor_layer.get_used_cells().is_empty():
		instance.free()
		return null

	# Lift the builder out of the never-readied battle scene and free the
	# rest (BattleScene, its camera controller). instantiate() ran no _ready,
	# so nothing has registered anywhere yet. Dropping the script is what
	# keeps it that way once the viewport enters the tree.
	var builder_parent: Node = builder.get_parent()
	if builder_parent != null:
		builder_parent.remove_child(builder)
	if instance != builder:
		instance.free()
	var stage: Node2D = builder
	stage.set_script(null)
	stage.position = Vector2.ZERO
	var spawn_layer: TileMapLayer = stage.get_node_or_null(spawn_path) as TileMapLayer
	var spawn_cells: Array[Vector2i] = player_spawn_cells(spawn_layer)
	if spawn_layer != null:
		spawn_layer.visible = false

	var viewport := SubViewport.new()
	viewport.name = "MissionPreview"
	viewport.size = canvas
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.gui_disable_input = true
	viewport.handle_input_locally = false
	viewport.add_child(stage)

	# Same spawn order as the battle: modifier first, decoration second, so
	# equal-z ties resolve the way the game draws them.
	for layer_path: NodePath in [modifier_path, decoration_path]:
		if stage.get_node_or_null(layer_path) as TileMapLayer == null:
			continue
		var renderer := TerrainSpriteRenderer.new()
		renderer.standalone = true
		renderer.layer_path = NodePath("../" + str(layer_path).get_file())
		renderer.floor_layer_path = NodePath("../" + str(floor_path).get_file())
		stage.add_child(renderer)

	var rect: Rect2 = floor_rect(floor_layer)
	var zoom: int = cover_zoom(rect.size, canvas)
	var camera := Camera2D.new()
	camera.zoom = Vector2(zoom, zoom)
	camera.position = rect.get_center().round()
	camera.position_smoothing_enabled = false
	viewport.add_child(camera)
	# Children are ready before the viewport is, so the stage is in its tree
	# by the time this fires — make_current and Unit.initialize both need it.
	viewport.ready.connect(_on_viewport_ready.bind(viewport, camera, stage, floor_layer,
			spawn_cells, squad))
	return viewport


static func _on_viewport_ready(_viewport: SubViewport, camera: Camera2D, stage: Node2D,
		floor_layer: TileMapLayer, spawn_cells: Array[Vector2i],
		squad: Array[CharacterData]) -> void:
	camera.make_current()
	_seat_squad(stage, floor_layer, spawn_cells, squad)


## The squad on the player spawns, spawn i ↔ roster member i, exactly as
## BattleScene._spawn_units_from_tiles seats them. Each unit stands on a
## Tile of its own (Unit.initialize wants one) that nothing registers, and
## wears the z the standalone overlays use so it sorts against the terrain
## the way it will in play — Unit's own stamp reads GridManager, which
## holds some other board's offset or none.
static func _seat_squad(stage: Node2D, floor_layer: TileMapLayer,
		spawn_cells: Array[Vector2i], squad: Array[CharacterData]) -> void:
	var seats: int = mini(spawn_cells.size(), squad.size())
	if seats <= 0:
		return
	var tiles := Node2D.new()
	tiles.name = "Tiles"
	stage.add_child(tiles)
	var offset_y: int = TerrainSpriteRenderer.editor_grid_offset_y(floor_layer.get_used_cells())
	for i: int in range(seats):
		var cell: Vector2i = spawn_cells[i]
		var tile: Tile = TILE_SCENE.instantiate() as Tile
		tile.position = floor_layer.transform * floor_layer.map_to_local(cell)
		tiles.add_child(tile)
		tile.initialize(cell.x, -cell.y)  # game grid is Y-up
		var unit: Unit = UNIT_SCENE.instantiate() as Unit
		# A copy: the battle shares the roster's data so mid-mission state
		# persists; a picture wants none of that.
		unit.character_data = squad[i].duplicate() as CharacterData
		unit.faction = Enums.UnitFaction.PLAYER
		stage.add_child(unit)
		unit.initialize(tile)
		unit.hide_battle_chrome()
		unit.z_index = ZIndexCalculator.calculate_sorting_order(
				tile.grid_y - offset_y, 100, ZIndexCalculator.ZIndexLayer.UNITS)


## The player spawn cells in the spawn layer's own order — the order the
## battle seats the roster in.
static func player_spawn_cells(spawn_layer: TileMapLayer) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if spawn_layer == null:
		return cells
	for cell: Vector2i in spawn_layer.get_used_cells():
		var tile_data := spawn_layer.get_cell_tile_data(cell)
		if tile_data == null:
			continue
		var spawn_faction: Variant = tile_data.get_custom_data("spawn_faction")
		if spawn_faction is String and spawn_faction == "Player":
			cells.append(cell)
	return cells


## The painted floor's pixel rect in the builder's space (cell centers come
## from map_to_local; the rect starts half a tile before the first center).
static func floor_rect(floor_layer: TileMapLayer) -> Rect2:
	var cells: Rect2i = floor_layer.get_used_rect()
	var tile_size := Vector2(floor_layer.tile_set.tile_size)
	var top_left: Vector2 = floor_layer.map_to_local(cells.position) - tile_size / 2.0
	return Rect2(floor_layer.transform * top_left, Vector2(cells.size) * tile_size)


## The smallest integer zoom at which a map of `map_size` world px covers
## the whole canvas. Never below 1 — a fractional zoom breaks pixels, so a
## map bigger than the canvas is cropped rather than shrunk.
static func cover_zoom(map_size: Vector2, canvas: Vector2i) -> int:
	if map_size.x <= 0.0 or map_size.y <= 0.0:
		return 1
	var needed: float = maxf(float(canvas.x) / map_size.x, float(canvas.y) / map_size.y)
	return maxi(1, ceili(needed - 0.0001))


## A .tscn saved mid-script-reload can carry a null export (the builder's
## own guard). An empty path means the conventional name, never "no layer".
static func _layer_path(path: Variant, default: NodePath) -> NodePath:
	if path is NodePath and not (path as NodePath).is_empty():
		return path
	return default
