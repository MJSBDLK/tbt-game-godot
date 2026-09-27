## Autotile sheets on the modifier layer: one source holding 47 tiles, whose
## shadows are authored in blocks under the body instead of generated. The
## contract under test — a painted cell draws its OWN atlas region (not the
## whole sheet), its shadow lands on its own cell, and its spill lands one cell
## east, both in the shadow slot.
##
## See art/sprites/tilesets/modifier_autotiles/README.md for the sheet layout
## and tools/register_autotile_modifier.gd for the registration.
extends GutTest


const TILESET_PATH := "res://resources/battle_tileset.tres"
const MOUNTAIN_SOURCE_ID := 8
const TILE := 32
const SPRITE_SOURCE_ID_BASE := 100

# An east-open variant (terrain continues north and south) and a closed one
# (terrain to the east), from the Webtyler layout's peering table.
const EAST_OPEN_COORDS := Vector2i(0, 1)
const EAST_CLOSED_COORDS := Vector2i(1, 0)


# A TileSetAtlasSource does NOT keep its TileSet alive, and a TileData whose
# tileset has been freed reports terrain -1 and null custom data. Hold the
# TileSet for the length of the test.
var _tileset_held: TileSet = null


func before_each() -> void:
	_tileset_held = load(TILESET_PATH)
	assert_not_null(_tileset_held, "tileset loads")


func _tileset() -> TileSet:
	return _tileset_held


func _mountain_source() -> TileSetAtlasSource:
	var source := _tileset().get_source(MOUNTAIN_SOURCE_ID) as TileSetAtlasSource
	assert_not_null(source, "the mountain sheet is registered as source %d" % MOUNTAIN_SOURCE_ID)
	return source


## Parent > [ModifierTileLayer, renderer] with one painted cell, added to the
## tree so _ready → refresh runs.
func _spawn_layer_with(cell: Vector2i, atlas_coords: Vector2i) -> TerrainSpriteRenderer:
	var parent := Node2D.new()
	var layer := TileMapLayer.new()
	layer.name = "ModifierTileLayer"
	layer.tile_set = _tileset()
	layer.set_cell(cell, MOUNTAIN_SOURCE_ID, atlas_coords)
	parent.add_child(layer)
	var renderer := TerrainSpriteRenderer.new()
	renderer.layer_path = NodePath("../ModifierTileLayer")
	parent.add_child(renderer)
	add_child_autofree(parent)
	return renderer


func _regions_of(sprites: Array[Sprite2D]) -> Array:
	var regions: Array = []
	for sprite in sprites:
		regions.append(sprite.region_rect)
	return regions


# =============================================================================
# Registration — the source shape every painted cell depends on
# =============================================================================

func test_the_mountain_sheet_is_one_source_of_47_tiles() -> void:
	var source := _mountain_source()
	assert_eq(source.resource_name, "mountain",
			"resource_name is the sprite name modifier_terrain.json resolves")
	assert_eq(source.get_tiles_count(), 47, "the Webtyler 12x4 body block, minus its one hole")
	assert_false(source.has_tile(Vector2i(10, 1)), "the layout's empty cell stays empty")
	assert_eq(source.texture_region_size, Vector2i(TILE, TILE))
	assert_lt(MOUNTAIN_SOURCE_ID, SPRITE_SOURCE_ID_BASE,
			"autotile sheets live below the single-sprite band so its invariants hold")


func test_body_tiles_carry_terrain_and_the_modifier_flag() -> void:
	var source := _mountain_source()
	var tile_data: TileData = source.get_tile_data(EAST_OPEN_COORDS, 0)
	assert_not_null(tile_data)
	assert_eq(tile_data.terrain_set, 0, "terrain set 0 is the one the brush paints from")
	assert_gte(tile_data.terrain, 0, "the sheet has its own terrain in that set")
	assert_true(tile_data.get_custom_data("is_modifier"),
			"painted on ModifierTileLayer it replaces the floor's properties")


func test_the_east_open_variant_peers_north_and_south_but_not_east() -> void:
	var source := _mountain_source()
	var tile_data: TileData = source.get_tile_data(EAST_OPEN_COORDS, 0)
	var terrain: int = tile_data.terrain
	assert_eq(tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE), terrain)
	assert_eq(tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE), terrain)
	assert_eq(tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE), -1,
			"open to the east — this is the variant that spills")
	var closed: TileData = source.get_tile_data(EAST_CLOSED_COORDS, 0)
	assert_eq(closed.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE), closed.terrain,
			"terrain continues east — nothing to spill into")


func test_the_sheet_stands_three_blocks_tall() -> void:
	var source := _mountain_source()
	assert_eq(source.texture.get_height(), 12 * TILE, "body + shadow + spill, 4 rows each")
	assert_true(TerrainSpriteRenderer.has_shadow_blocks(source.texture, Vector2i(TILE, TILE)))


# =============================================================================
# Block geometry — pure
# =============================================================================

func test_block_region_steps_down_whole_blocks() -> void:
	var body := Rect2i(64, 32, 32, 32)
	assert_eq(TerrainSpriteRenderer.block_region(body, 4, Vector2i(TILE, TILE)),
			Rect2i(64, 160, 32, 32), "the shadow block is 4 rows down, same column")
	assert_eq(TerrainSpriteRenderer.block_region(body, 8, Vector2i(TILE, TILE)),
			Rect2i(64, 288, 32, 32), "the spill block is 8 rows down")


func test_a_body_only_sheet_has_no_shadow_blocks() -> void:
	var image := Image.create(12 * TILE, 4 * TILE, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	assert_false(TerrainSpriteRenderer.has_shadow_blocks(texture, Vector2i(TILE, TILE)),
			"a plain 12x4 sheet carries no shadow — the generated cast still applies")


func test_region_ink_finds_only_painted_regions() -> void:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.set_pixel(40, 40, Color(0, 0, 0, 0.18))
	var texture := ImageTexture.create_from_image(image)
	assert_true(TerrainSpriteRenderer.region_has_ink(texture, Rect2i(32, 32, 32, 32)),
			"a translucent shadow pixel counts as ink")
	assert_false(TerrainSpriteRenderer.region_has_ink(texture, Rect2i(0, 0, 32, 32)),
			"an empty region spawns no sprite")


# =============================================================================
# Rendering — against the real sheet
# =============================================================================

func test_an_east_open_cell_draws_body_shadow_and_spill() -> void:
	var cell := Vector2i(3, -5)
	var renderer := _spawn_layer_with(cell, EAST_OPEN_COORDS)
	var sprites := renderer.get_spawned_sprites()
	assert_eq(sprites.size(), 3, "body, its own shadow, and the spill east of it")

	var layer := renderer.get_node("../ModifierTileLayer") as TileMapLayer
	var center: Vector2 = layer.map_to_local(cell)
	var row: int = TerrainSpriteRenderer.front_row_index(cell.y, 1, GridManager.grid_offset_y)
	var body_region := Rect2(EAST_OPEN_COORDS.x * TILE, EAST_OPEN_COORDS.y * TILE, TILE, TILE)

	var body := sprites[0]
	assert_eq(body.region_rect, body_region, "the cell draws its own atlas region, not the sheet")
	assert_eq(body.position, center)
	assert_eq(body.z_index, TerrainSpriteRenderer.body_z(row))
	assert_eq(body.modulate, Color.WHITE, "the art draws as painted")

	var shadow := sprites[1]
	assert_eq(shadow.region_rect, Rect2(body_region.position + Vector2(0, 4 * TILE), body_region.size))
	assert_eq(shadow.position, center, "its own shadow stays on its own cell")
	assert_eq(shadow.z_index, TerrainSpriteRenderer.shadow_z(row),
			"shadow slot, so it falls on whatever is painted there")

	var spill := sprites[2]
	assert_eq(spill.region_rect, Rect2(body_region.position + Vector2(0, 8 * TILE), body_region.size))
	assert_eq(spill.position, center + Vector2(TILE, 0), "the spill lands one cell east")
	assert_eq(spill.z_index, TerrainSpriteRenderer.shadow_z(row))


func test_shadow_blocks_are_masks_drawn_at_the_board_shadow_ink() -> void:
	# The sheet carries the shape; the opacity is the one value every shadow on
	# the board shares, so moving it moves units and terrain together.
	var renderer := _spawn_layer_with(Vector2i(3, -5), EAST_OPEN_COORDS)
	var sprites := renderer.get_spawned_sprites()
	for i in range(1, sprites.size()):
		assert_eq(sprites[i].modulate, GameColors.CAST_SHADOW_INK,
				"shadow and spill wear the shared cast-shadow ink")


func test_a_closed_east_edge_spills_nothing() -> void:
	var renderer := _spawn_layer_with(Vector2i(3, -5), EAST_CLOSED_COORDS)
	var spill_top := float(EAST_CLOSED_COORDS.y * TILE + 8 * TILE)
	for sprite in renderer.get_spawned_sprites():
		assert_ne(sprite.region_rect.position.y, spill_top,
				"terrain continues east — the spill block is empty for this variant")


func test_every_sprite_is_nearest_filtered_absolute_z() -> void:
	var renderer := _spawn_layer_with(Vector2i(3, -5), EAST_OPEN_COORDS)
	for sprite in renderer.get_spawned_sprites():
		assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_false(sprite.z_as_relative, "absolute board z")
		assert_true(sprite.region_enabled, "autotile cells always draw a region")


func test_the_tilemap_layer_hides_so_it_never_double_draws() -> void:
	var renderer := _spawn_layer_with(Vector2i(3, -5), EAST_OPEN_COORDS)
	var layer := renderer.get_node("../ModifierTileLayer") as TileMapLayer
	assert_false(layer.visible, "the overlay owns the drawing")
