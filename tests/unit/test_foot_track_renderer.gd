## Integration tests for FootTrackRenderer: drive lay_path() directly and check
## sprite spawning, terrain skipping, and the depth cap. Uses the real loaded
## library (the shipped `regolith` variant).
extends GutTest

var _renderer: FootTrackRenderer


func before_each() -> void:
	_renderer = FootTrackRenderer.new()
	add_child_autofree(_renderer)


func _make_tile(grid_x: int, grid_y: int, terrain := "Regolith") -> Tile:
	var tile := Tile.new()
	tile.grid_x = grid_x
	tile.grid_y = grid_y
	tile.terrain_type_name = terrain
	tile.position = Vector2(grid_x * 32, -grid_y * 32)
	autofree(tile)
	return tile


func _count_track_sprites() -> int:
	var count := 0
	for child in _renderer.get_children():
		if child is Sprite2D:
			count += 1
	return count


func test_one_track_per_traversed_tile_on_matching_terrain() -> void:
	# Straight W->E walk across 3 regolith tiles: start, pass-through, end.
	_renderer.lay_path([_make_tile(0, 0), _make_tile(1, 0), _make_tile(2, 0)])
	assert_eq(_count_track_sprites(), 3, "one track sprite per traversed tile")


func test_no_tracks_on_terrain_without_variant() -> void:
	_renderer.lay_path([_make_tile(0, 0, "Rock"), _make_tile(1, 0, "Rock")])
	assert_eq(_count_track_sprites(), 0, "Rock has no variant -> no tracks")


func test_single_tile_path_lays_nothing() -> void:
	_renderer.lay_path([_make_tile(0, 0)])
	assert_eq(_count_track_sprites(), 0, "a one-tile path is not a walk")


func test_depth_cap_caps_repeated_crossings() -> void:
	_renderer.max_depth = 4
	var start := _make_tile(0, 0)
	var crossed := _make_tile(1, 0)
	# Six separate little walks that each end on cell (1,0).
	for n in range(6):
		_renderer.lay_path([start, crossed])
	var stack: Array = _renderer._cell_stacks.get(Vector2i(1, 0), [])
	assert_eq(stack.size(), 4, "cell (1,0) is capped at max_depth=4 after 6 crossings")


func test_ingests_seed_layer_as_depth_one_track() -> void:
	# Build a synthetic stamp layer painting one regolith "E" cell (atlas 0,0).
	var texture: Texture2D = load("res://art/sprites/decorations/foot_tracks/regolith.png")
	assert_not_null(texture, "regolith atlas should be importable")
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(32, 32)
	source.create_tile(Vector2i(0, 0))  # the "E" cell
	var source_id := tile_set.add_source(source)
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	add_child_autofree(layer)
	layer.set_cell(Vector2i(2, -3), source_id, Vector2i(0, 0))

	_renderer.ingest_seed_layer(layer)
	assert_eq(_count_track_sprites(), 1, "one seed track per painted cell")
