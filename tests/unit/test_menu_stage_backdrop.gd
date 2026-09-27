## The intermission stage's two roles (MenuStageBackdrop) and the diorama it
## stands in front of in fiction (MissionPreview). RQD 2026-09-22: the hub
## arrived painted with the recruit picker — the base autosave's screenshot
## was the last frame on screen, hint bar and all, and the stage showed the
## newest save first. In fiction the stage now wants the ship art, else the
## mission being prepared for as the battle will first see it: the squad on
## its spawns, no HUD; the save screenshot is the main menu's alone. Pins
## the order, the diorama's shape (a picture, never a board), who stands
## where, and the framing math. What it LOOKS like is eyeball territory.
extends GutTest


const MAP_PATH: String = "res://scenes/battle/maps/test_map_02.tscn"
const MISSING_MAP_PATH: String = "res://scenes/battle/maps/no_such_map.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"

var _pristine_campaign: Dictionary = {}


func before_all() -> void:
	_pristine_campaign = CampaignManager.capture_save_state()
	CampaignManager.restore_save_state({})
	SaveManager.save_root = "user://test_saves_backdrop"
	_wipe_scratch_saves()


func after_all() -> void:
	_wipe_scratch_saves()
	SaveManager.save_root = SaveManager.DEFAULT_SAVE_ROOT
	CampaignManager.restore_save_state(_pristine_campaign)
	GridManager.clear_grid()


func after_each() -> void:
	_wipe_scratch_saves()


func _wipe_scratch_saves() -> void:
	var root := DirAccess.open(SaveManager.save_root)
	if root == null:
		return
	for file_name: String in root.get_files():
		root.remove(file_name)
	for dir_name: String in root.get_directories():
		var kind_dir := DirAccess.open("%s/%s" % [SaveManager.save_root, dir_name])
		if kind_dir == null:
			continue
		for file_name: String in kind_dir.get_files():
			kind_dir.remove(file_name)


## A newest save WITH a sibling screenshot, so Black Mesa mode has a frame.
func _write_save_with_screenshot() -> void:
	var path: String = SaveManager._slot_path(SaveManager.KIND_AUTO_TURN, 0)
	SaveManager.write_save_file(path, {
		"save_version": SaveManager.SAVE_VERSION,
		"kind": SaveManager.KIND_AUTO_TURN,
		"created_unix": 1000,
		"label": "Mission 1 · Turn 3",
	})
	var image := Image.create(8, 8, false, Image.FORMAT_RGB8)
	image.fill(Color.RED)
	image.save_png(SaveManager.screenshot_path_for(path))


func _stage(mission_path: String) -> MenuStageBackdrop:
	var stage := MenuStageBackdrop.new()
	stage.mission_path = mission_path
	add_child_autofree(stage)
	return stage


# =============================================================================
# THE TWO ORDERS
# =============================================================================

func test_out_of_fiction_the_newest_save_screenshot_comes_first() -> void:
	_write_save_with_screenshot()
	var stage := _stage("")
	assert_true(stage._backdrop.texture is ImageTexture, "Black Mesa mode: the saved frame")
	assert_false(stage.is_showing_mission_preview())


func test_in_fiction_the_stage_previews_the_mission_not_the_save() -> void:
	# Same save on disk — the hub must not paint it. Its frame was whatever
	# was on screen when the boundary autosave fired (the recruit picker).
	_write_save_with_screenshot()
	if ResourceLoader.exists(MenuStageBackdrop.SHIP_INTERIOR_PATH):
		pass_test("ship interior art is painted — it outranks the preview by design")
		return
	var stage := _stage(MAP_PATH)
	assert_true(stage.is_showing_mission_preview(), "a live map, not the saved frame")
	assert_true(stage._backdrop.texture is ViewportTexture)
	assert_eq(stage._backdrop.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
			"a resize crops instead of stretching pixels")
	assert_gt(_units_in(stage._preview).size(), 0,
			"the lineup stands on the map — the roster, with no campaign to filter it")


func test_a_mission_that_wont_load_falls_to_flat_glass() -> void:
	var stage := _stage(MISSING_MAP_PATH)
	assert_false(stage.is_showing_mission_preview())
	assert_null(stage._backdrop.texture, "flat eggshell shows through — no stale frame")


func test_refreshing_drops_the_previous_preview() -> void:
	var stage := _stage(MAP_PATH)
	var first: SubViewport = stage._preview
	if first == null:
		pass_test("no preview to drop (ship art present)")
		return
	stage.refresh()
	assert_ne(stage._preview, first, "a fresh viewport per resolve")
	assert_true(first.is_queued_for_deletion(), "the old one is freed, not leaked")


# =============================================================================
# THE PREVIEW IS A PICTURE, NEVER A BOARD
# =============================================================================

func test_preview_holds_the_painted_layers_and_no_grid_builder() -> void:
	GridManager.clear_grid()
	var preview: SubViewport = MissionPreview.build(MAP_PATH)
	assert_not_null(preview, "test_map_02 renders")
	if preview == null:
		return
	add_child_autofree(preview)
	var floor_layer: TileMapLayer = preview.find_child("TerrainTileLayer", true, false) as TileMapLayer
	assert_not_null(floor_layer, "the floor autotiles ride along")
	assert_true(floor_layer.visible)
	var spawn_layer: TileMapLayer = preview.find_child("SpawnTileLayer", true, false) as TileMapLayer
	if spawn_layer != null:
		assert_false(spawn_layer.visible, "spawn markers are editor data, not scenery")
	for node: Node in preview.get_children():
		assert_false(node is TilemapGridBuilder, "the builder's script is gone — no _ready, no grid")
	assert_false(GridManager.is_grid_ready(), "GridManager was never touched")
	assert_eq(preview.render_target_update_mode, SubViewport.UPDATE_ALWAYS,
			"a diorama keeps rendering — whatever animates on the board animates here")
	assert_eq(_units_in(preview).size(), 0, "no squad given, nobody seated")


func test_preview_overlays_wear_the_standalone_flag() -> void:
	var preview: SubViewport = MissionPreview.build(MAP_PATH)
	if preview == null:
		fail_test("test_map_02 renders")
		return
	add_child_autofree(preview)
	var renderers: Array[Node] = preview.find_children("*", "TerrainSpriteRenderer", true, false)
	assert_gt(renderers.size(), 0, "modifier/decoration layers draw through the real overlays")
	for renderer: Node in renderers:
		assert_true(renderer.standalone, "no GridManager behind the picture")


func test_preview_camera_frames_the_floor_at_the_cover_zoom() -> void:
	var preview: SubViewport = MissionPreview.build(MAP_PATH)
	if preview == null:
		fail_test("test_map_02 renders")
		return
	add_child_autofree(preview)
	var camera: Camera2D = null
	for node: Node in preview.get_children():
		if node is Camera2D:
			camera = node
	assert_not_null(camera)
	if camera == null:
		return
	var floor_layer: TileMapLayer = preview.find_child("TerrainTileLayer", true, false) as TileMapLayer
	var rect: Rect2 = MissionPreview.floor_rect(floor_layer)
	assert_eq(camera.position, rect.get_center().round(), "centered on the painted floor")
	var zoom: int = MissionPreview.cover_zoom(rect.size, MissionPreview.REFERENCE_SIZE)
	assert_eq(camera.zoom, Vector2(zoom, zoom))
	assert_true(camera.is_current(), "the viewport looks through it")


func _units_in(preview: SubViewport) -> Array[Node]:
	if preview == null:
		return []
	return preview.find_children("*", "Unit", true, false)


func _squad(paths: Array[String]) -> Array[CharacterData]:
	var squad: Array[CharacterData] = []
	for path: String in paths:
		squad.append(CharacterDataLoader.load_character(path))
	return squad


func test_the_squad_stands_on_the_player_spawns_in_battle_order() -> void:
	var spawn_count: int = TilemapGridBuilder.count_player_spawns(MAP_PATH)
	assert_gt(spawn_count, 1, "test_map_02 has room for a pair")
	var squad := _squad([SPACEMAN_PATH, GRUNT_PATH])
	var preview: SubViewport = MissionPreview.build(MAP_PATH, MissionPreview.REFERENCE_SIZE, squad)
	if preview == null:
		fail_test("test_map_02 renders")
		return
	add_child_autofree(preview)
	var units: Array[Node] = _units_in(preview)
	assert_eq(units.size(), 2, "one unit per roster member with a spawn to stand on")
	if units.size() < 2:
		return
	var spawn_layer: TileMapLayer = preview.find_child("SpawnTileLayer", true, false) as TileMapLayer
	var floor_layer: TileMapLayer = preview.find_child("TerrainTileLayer", true, false) as TileMapLayer
	var cells: Array[Vector2i] = MissionPreview.player_spawn_cells(spawn_layer)
	var offset_y: int = TerrainSpriteRenderer.editor_grid_offset_y(floor_layer.get_used_cells())
	for i: int in range(2):
		var unit := units[i] as Unit
		assert_eq(unit.character_data.character_name, squad[i].character_name,
				"spawn %d seats roster member %d — the battle's own order" % [i, i])
		assert_ne(unit.character_data, squad[i], "a copy of the roster's data, never the roster's")
		assert_eq(unit.faction, Enums.UnitFaction.PLAYER)
		var seat: Vector2 = floor_layer.transform * floor_layer.map_to_local(cells[i])
		assert_lt(unit.global_position.distance_to(preview.get_child(0).to_global(seat)), 0.5,
				"standing on its spawn cell")
		assert_false(unit._health_bar.visible, "no HUD — a picture of the unit, not a combatant")
		assert_eq(unit.z_index, ZIndexCalculator.calculate_sorting_order(
				unit.current_tile.grid_y - offset_y, 100, ZIndexCalculator.ZIndexLayer.UNITS),
				"sorted against the terrain with the overlays' own front row")


func test_a_squad_bigger_than_the_spawns_is_trimmed_to_the_spawns() -> void:
	var spawn_count: int = TilemapGridBuilder.count_player_spawns(MAP_PATH)
	var paths: Array[String] = []
	for i: int in range(spawn_count + 2):
		paths.append(SPACEMAN_PATH)
	var preview: SubViewport = MissionPreview.build(MAP_PATH, MissionPreview.REFERENCE_SIZE, _squad(paths))
	if preview == null:
		fail_test("test_map_02 renders")
		return
	add_child_autofree(preview)
	assert_eq(_units_in(preview).size(), spawn_count, "the bench stays home")


func test_missing_or_hollow_scenes_build_nothing() -> void:
	assert_null(MissionPreview.build(""))
	assert_null(MissionPreview.build(MISSING_MAP_PATH))


# =============================================================================
# FRAMING MATH (pure)
# =============================================================================

func test_cover_zoom_is_the_smallest_integer_that_fills_the_canvas() -> void:
	var canvas := Vector2i(640, 360)
	assert_eq(MissionPreview.cover_zoom(Vector2(320, 192), canvas), 2, "20×12 tiles: ×2 covers both axes")
	assert_eq(MissionPreview.cover_zoom(Vector2(160, 128), canvas), 4, "a small map zooms until it covers")
	assert_eq(MissionPreview.cover_zoom(Vector2(640, 360), canvas), 1, "exact fit")
	assert_eq(MissionPreview.cover_zoom(Vector2(1280, 720), canvas), 1, "never below 1 — crop, don't shrink")
	assert_eq(MissionPreview.cover_zoom(Vector2(700, 100), canvas), 4, "the tighter axis decides")
	assert_eq(MissionPreview.cover_zoom(Vector2.ZERO, canvas), 1, "degenerate input stays sane")


func test_floor_rect_spans_the_painted_cells_in_pixels() -> void:
	var layer := TileMapLayer.new()
	autofree(layer)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(32, 32, false, Image.FORMAT_RGBA8))
	source.create_tile(Vector2i.ZERO)
	var source_id: int = tile_set.add_source(source)
	layer.tile_set = tile_set
	layer.set_cell(Vector2i(2, -3), source_id, Vector2i.ZERO)
	layer.set_cell(Vector2i(5, -1), source_id, Vector2i.ZERO)
	var rect: Rect2 = MissionPreview.floor_rect(layer)
	assert_eq(rect.position, Vector2(64, -96), "north-west corner of the first painted cell")
	assert_eq(rect.size, Vector2(4 * 32, 3 * 32), "4 cells wide, 3 tall")
