## CombatBackdrop: Lawrence's backdrop on the combat stage, and the floor
## layers the fight's surroundings pick. A layer named after scenery shows
## when that scenery stands within two steps (no diagonals) of a fighter; a
## "_left"/"_right" layer answers to that side's fighter; any other name
## always shows. Scenery comes from the map: TilemapGridBuilder → Tile.scenery.
extends GutTest


const MAP_PATH: String = "res://scenes/battle/maps/lawrence_test_map.tscn"

var _vocabulary: Dictionary = {
	"crater": true, "shelltree": true, "sand": true, "orange_sand": true, "water": true,
}


func after_each() -> void:
	GridManager.clear_grid()


func _tile(x: int, y: int, scenery: Array = []) -> Tile:
	var tile := Tile.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	add_child_autofree(tile)
	tile.grid_x = x
	tile.grid_y = y
	tile.scenery = PackedStringArray(scenery)
	GridManager.register_tile(tile)
	return tile


func _fighter_on(tile: Tile) -> TestFakeUnit:
	var fighter := TestFakeUnit.new()
	add_child_autofree(fighter)
	fighter.current_tile = tile
	return fighter


# =============================================================================
# Which layers show
# =============================================================================

func test_a_layer_named_after_no_scenery_always_shows() -> void:
	for layer: String in ["ground_regolith", "hill_back_left", "atmosphere", "rivers"]:
		assert_true(CombatBackdrop.shows(layer, {}, {}, _vocabulary), layer)


func test_a_scenery_layer_shows_only_when_that_scenery_is_near_a_fighter() -> void:
	assert_true(CombatBackdrop.shows("shelltree", {"shelltree": true}, {}, _vocabulary), "near the left fighter")
	assert_true(CombatBackdrop.shows("shelltree", {}, {"shelltree": true}, _vocabulary), "near the right fighter")
	assert_false(CombatBackdrop.shows("shelltree", {"crater": true}, {}, _vocabulary), "nowhere near")
	assert_true(CombatBackdrop.shows("crater_final", {"crater": true}, {}, _vocabulary),
			"extra words after the scenery name are the painter's")


func test_a_sided_layer_answers_to_its_own_fighter() -> void:
	var crater := {"crater": true}
	assert_true(CombatBackdrop.shows("crater_left", crater, {}, _vocabulary))
	assert_false(CombatBackdrop.shows("crater_left", {}, crater, _vocabulary), "the right fighter's crater isn't the left's")
	assert_true(CombatBackdrop.shows("crater_right", {}, crater, _vocabulary))
	assert_false(CombatBackdrop.shows("crater_right", crater, {}, _vocabulary))
	assert_true(CombatBackdrop.shows("crater_center", {}, crater, _vocabulary), "center answers to either")


func test_the_longest_scenery_name_wins_in_whole_words() -> void:
	var blue_sand := {"sand": true, "blue_sand": true}
	assert_true(CombatBackdrop.shows("orange_sand", {"sand": true, "orange_sand": true}, {}, _vocabulary))
	assert_false(CombatBackdrop.shows("orange_sand", blue_sand, {}, _vocabulary), "blue sand isn't orange")
	assert_true(CombatBackdrop.shows("sand_orange", blue_sand, {}, _vocabulary), "a plain sand_* layer follows any sand")
	assert_true(CombatBackdrop.shows("waterfall", {}, {}, _vocabulary), "'water' has to be a whole word")


func test_the_vocabulary_is_what_maps_can_paint() -> void:
	var names := CombatBackdrop.scenery_names()
	for expected: String in ["crater", "shelltree", "piperoot", "firetopradish", "volcano", "mountain",
			"orange_sand", "blue_sand", "water", "road", "regolith", "sand"]:
		assert_true(names.has(expected), expected)
	assert_false(names.has("ground"), "no map paints Ground, so ground_regolith always shows")
	assert_false(names.has("hill"))


# =============================================================================
# Scenery near a fighter
# =============================================================================

func test_scenery_counts_two_steps_without_diagonals() -> void:
	var center := _tile(0, 0, ["regolith"])
	_tile(2, 0, ["crater"])
	_tile(1, 1, ["shelltree"])  # one across + one up = two steps
	_tile(0, -2, ["water"])
	_tile(2, 1, ["sand"])  # three steps
	_tile(3, 0, ["volcano"])
	var near: Array = CombatBackdrop.scenery_near(center).keys()
	near.sort()
	assert_eq(near, ["crater", "regolith", "shelltree", "water"])
	assert_eq(CombatBackdrop.scenery_near(null), {}, "a fighter off the grid sees nothing")


func test_each_fighter_answers_for_its_own_side() -> void:
	var left_tile := _tile(0, 0)
	var right_tile := _tile(6, 0)
	_tile(-2, 0, ["crater"])  # two steps from the left fighter, eight from the right
	var backdrop := CombatBackdrop.new()
	add_child_autofree(backdrop)
	backdrop.choose_layers(_fighter_on(left_tile), _fighter_on(right_tile))
	var vocabulary := CombatBackdrop.scenery_names()
	var hidden := 0
	for art: TextureRect in backdrop.floor_layers():
		var layer := CombatBackdrop.layer_name(art.name)
		assert_eq(art.visible, CombatBackdrop.shows(layer, {"crater": true}, {}, vocabulary), layer)
		if not art.visible:
			hidden += 1
	assert_gt(hidden, 0, "the regolith has layers no crater calls for")


# =============================================================================
# The art and the map
# =============================================================================

func test_the_stage_stacks_sky_then_stars_then_the_floor_in_export_order() -> void:
	var files := CombatBackdrop.floor_files(CombatBackdrop.DIRECTORY + CombatBackdrop.FLOOR_FOLDER)
	assert_gt(files.size(), 1)
	assert_eq(CombatBackdrop.layer_name("07_crater_left.png"), "crater_left", "the export's order number drops")
	assert_eq(CombatBackdrop.layer_name("sky.png"), "sky")
	var backdrop := CombatBackdrop.new()
	add_child_autofree(backdrop)
	var names: Array[String] = []
	for child: Node in backdrop.get_children():
		names.append(String(child.name))
	assert_eq(names.slice(0, 2), ["sky", "sky_twinkle"], "the stars draw between the sky and the floor")
	assert_eq(names.slice(2), files.map(func(file: String) -> String: return file.get_basename()),
			"the floor in the painter's order")
	var stars: TextureRect = backdrop.get_node("sky_twinkle")
	assert_true(stars is StarSky, "the star map draws through the twinkle shader")
	assert_eq((stars.material as ShaderMaterial).get_shader_parameter("star_map"), stars.texture,
			"the shader reads the map, not just the rect")
	assert_false((stars as StarSky).draws_resting_stars, "the painted sky shows the stars at rest; only flashes draw")
	backdrop.lay_out(Vector2(-111, -21), 3)
	for child: Node in backdrop.get_children():
		var art := child as TextureRect
		assert_eq(art.position, Vector2(-111, -21), "%s on the canvas anchor" % art.name)
		assert_eq(art.size, art.texture.get_size() * 3, "%s at the puppets' scale" % art.name)


func test_the_star_map_keeps_its_painted_colors_through_import() -> void:
	# The map's colors are data (R/G = tail shape and reach, B = cadence): a
	# lossy import would change how every star twinkles.
	var image: Image = (load(CombatBackdrop.DIRECTORY + CombatBackdrop.TWINKLE_FILE) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	assert_eq(image.get_pixel(48, 1).to_rgba32(), Color8(0, 51, 0).to_rgba32(), "a + star")
	assert_eq(image.get_pixel(134, 1).to_rgba32(), Color8(179, 0, 0).to_rgba32(), "an X star")
	assert_eq(image.get_pixel(169, 4).to_rgba32(), Color8(0, 0, 51).to_rgba32(), "a bare blinking core")
	var stars := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var texel: Color = image.get_pixel(x, y)
			if texel.a >= 0.5 and maxf(texel.r, maxf(texel.g, texel.b)) >= 0.02:
				stars += 1
	assert_eq(stars, 94, "Lawrence's 94 stars, no strays from the import")


func test_a_map_gives_every_tile_its_scenery() -> void:
	var map: Node = (load(MAP_PATH) as PackedScene).instantiate()
	var builder: Node = map.find_child("TilemapBuilder", true, false)
	builder.get_parent().remove_child(builder)
	map.free()
	add_child_autofree(builder)  # _ready builds the grid
	var floor_layer: TileMapLayer = builder.get_node("TerrainTileLayer")
	var floors_checked := 0
	var pieces_checked := 0
	for cell: Vector2i in floor_layer.get_used_cells():
		var tile: Tile = GridManager.get_tile(cell.x, -cell.y)
		if tile == null:
			continue  # trimmed: outside the map's boundary markers
		assert_gt(tile.scenery.size(), 0, "%s names its floor" % cell)
		floors_checked += 1
	assert_gt(floors_checked, 0)
	for layer_name: String in ["ModifierTileLayer", "DecorationTileLayer"]:
		var layer := builder.get_node_or_null(layer_name) as TileMapLayer
		if layer == null:
			continue
		for cell: Vector2i in layer.get_used_cells():
			var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			var family := ModifierTerrainMap.family(source.resource_name)
			var footprint: Vector2i = source.get_tile_size_in_atlas(layer.get_cell_atlas_coords(cell))
			for dx: int in footprint.x:
				for dy: int in footprint.y:
					var tile: Tile = GridManager.get_tile(cell.x + dx, -(cell.y + dy))
					if tile != null and family != "":
						assert_true(tile.scenery.has(family), "%s covers %s" % [source.resource_name, cell + Vector2i(dx, dy)])
						pieces_checked += 1
	assert_gt(pieces_checked, 0, "the test map has pieces to check")


func test_a_floor_sheet_names_both_its_materials() -> void:
	var tile_set: TileSet = load(CombatBackdrop.MAP_TILESET)
	var names := TilemapGridBuilder.floor_scenery_names(tile_set)
	for expected: String in ["blue_sand", "orange_sand", "purple_sand", "water", "regolith", "sand", "road"]:
		assert_true(names.has(expected), expected)
	var blue_sand: TileData = null  # any tile of the "Blue Sand / Regolith" sheet
	for source_index: int in tile_set.get_source_count():
		var source := tile_set.get_source(tile_set.get_source_id(source_index)) as TileSetAtlasSource
		for tile_index: int in (source.get_tiles_count() if source != null else 0):
			var data := source.get_tile_data(source.get_tile_id(tile_index), 0)
			if data.terrain_set == 0 and data.terrain == 0 and blue_sand == null:
				blue_sand = data
	assert_not_null(blue_sand)
	assert_eq(tile_set.get_terrain_name(0, 0), "Blue Sand / Regolith", "precondition")
	assert_eq(TilemapGridBuilder.floor_scenery(tile_set, blue_sand, "Sand"),
			PackedStringArray(["sand", "blue_sand", "regolith"]))
