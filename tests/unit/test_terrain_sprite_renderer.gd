## Tests for TerrainSpriteRenderer — the overlay that draws modifier AND
## decoration cells as full-PNG sprites with occlusion-correct z. The
## z math is pure/static; the spawn behavior is exercised against a real
## TileMapLayer painted from battle_tileset.tres.
extends GutTest


# The project's z convention (see Unit._update_z_index and
# GridZIndexHandler usage in tilemap_grid_builder):
#   row_index = grid_y - grid_offset_y, where grid_y = -cell_y
#   row 0 = southernmost = highest z (front)
# A multi-cell sprite sorts by its SOUTHERN footprint row.


func test_front_row_matches_unit_convention_for_1x1() -> void:
	# Map with cells y 0..8 → grid_y -8..0 → grid_offset_y = -8.
	# A 1x1 sprite at cell y=8 (southernmost): row = -8 - (-8) = 0 (front).
	assert_eq(TerrainSpriteRenderer.front_row_index(8, 1, -8), 0,
			"Southernmost 1x1 sprite is front row (0)")
	# Same map, sprite at cell y=0 (northernmost): row = 0 - (-8) = 8.
	assert_eq(TerrainSpriteRenderer.front_row_index(0, 1, -8), 8,
			"Northernmost 1x1 sprite has the highest row index")


func test_front_row_uses_southern_edge_for_multi_cell() -> void:
	# 2x2 castle anchored at cell y=3 covers rows 3 and 4. It must sort by
	# row 4 (its southern edge), like a unit standing at cell y=4 would.
	var castle_row: int = TerrainSpriteRenderer.front_row_index(3, 2, -8)
	var unit_at_south_row: int = TerrainSpriteRenderer.front_row_index(4, 1, -8)
	assert_eq(castle_row, unit_at_south_row,
			"2x2 anchored at y=3 sorts like a 1x1 at y=4 (southern edge)")


func test_front_row_occlusion_ordering() -> void:
	var offset_y: int = -8
	# Unit NORTH of a 2x2 castle (cell y=2; castle anchored y=3 spans 3-4):
	# unit row > castle row → unit z < castle z → castle occludes the unit.
	var unit_north_row: int = TerrainSpriteRenderer.front_row_index(2, 1, offset_y)
	var castle_row: int = TerrainSpriteRenderer.front_row_index(3, 2, offset_y)
	var unit_z_north: int = ZIndexCalculator.calculate_sorting_order(
			unit_north_row, 100, ZIndexCalculator.ZIndexLayer.UNITS)
	var castle_z: int = TerrainSpriteRenderer.body_z(castle_row)
	assert_true(castle_z > unit_z_north,
			"Castle renders above a unit standing behind (north of) it")

	# Unit SOUTH of the castle (cell y=5): unit row < castle row → unit
	# renders above the castle's overhang.
	var unit_south_row: int = TerrainSpriteRenderer.front_row_index(5, 1, offset_y)
	var unit_z_south: int = ZIndexCalculator.calculate_sorting_order(
			unit_south_row, 100, ZIndexCalculator.ZIndexLayer.UNITS)
	assert_true(unit_z_south > castle_z,
			"Unit in front (south) renders above the castle")

	# Unit on the castle's OWN southern row: same row, UNITS slot beats
	# TERRAIN_MODIFIERS slot.
	var unit_same_row: int = TerrainSpriteRenderer.front_row_index(4, 1, offset_y)
	var unit_z_same: int = ZIndexCalculator.calculate_sorting_order(
			unit_same_row, 100, ZIndexCalculator.ZIndexLayer.UNITS)
	assert_true(unit_z_same > castle_z,
			"Same-row unit renders above the sprite via layer offset")


# =============================================================================
# Shadow z — the "shadows fall on the east neighbor" experiment
# =============================================================================

func test_shadow_sits_one_slot_above_its_own_row_body() -> void:
	var row: int = 5
	assert_eq(TerrainSpriteRenderer.shadow_z(row), TerrainSpriteRenderer.body_z(row) + 1,
			"Shadow is exactly the next slot up (TERRAIN_SHADOWS) so it spills onto same-row east neighbors")


func test_shadow_stays_below_same_row_unit_and_below_south_row_body() -> void:
	var row: int = 5
	var shadow: int = TerrainSpriteRenderer.shadow_z(row)
	var unit_same_row: int = ZIndexCalculator.calculate_sorting_order(
			row, 100, ZIndexCalculator.ZIndexLayer.UNITS)
	assert_lt(shadow, unit_same_row, "A unit on the shadow's row walks over the shadow")
	var body_one_row_south: int = TerrainSpriteRenderer.body_z(row - 1)
	assert_lt(shadow, body_one_row_south, "A sprite one row south covers the shadow")


# =============================================================================
# Per-row strips ("interleave" mode) — multi-row sprites split into one
# horizontal strip per footprint row so a unit on a back row interleaves.
# =============================================================================
# Setup mirrors the 2x2 castle: 64x96 texture (16px tower overhang on top of a
# 2-row, 64px footprint), anchored at cell y=3, map grid_offset_y = -8.

const _TEX := Vector2i(64, 96)
const _FOOTPRINT := Vector2i(2, 2)
const _TILE := Vector2i(32, 32)
const _ANCHOR_Y := 3
const _OFFSET_Y := -8


func test_strips_one_per_footprint_row() -> void:
	var strips := TerrainSpriteRenderer.compute_row_strips(_TEX, _FOOTPRINT, _TILE, _ANCHOR_Y, _OFFSET_Y)
	assert_eq(strips.size(), _FOOTPRINT.y, "One strip per footprint row")


func test_strips_tile_the_texture_contiguously() -> void:
	var strips := TerrainSpriteRenderer.compute_row_strips(_TEX, _FOOTPRINT, _TILE, _ANCHOR_Y, _OFFSET_Y)
	# North strip owns the top overhang (starts at texture y=0); south strip
	# runs to the bottom edge; bands are gapless and cover the full height.
	var top: Rect2 = strips[0]["region_rect"]
	var bottom: Rect2 = strips[strips.size() - 1]["region_rect"]
	assert_eq(top.position.y, 0.0, "North strip starts at the texture top (owns overhang)")
	assert_eq(bottom.end.y, float(_TEX.y), "South strip reaches the texture bottom")
	var covered: float = 0.0
	var cursor: float = 0.0
	for strip: Dictionary in strips:
		var r: Rect2 = strip["region_rect"]
		assert_eq(r.position.y, cursor, "Strips are contiguous with no gap/overlap")
		assert_eq(r.size.x, float(_TEX.x), "Strips span the full texture width")
		cursor = r.end.y
		covered += r.size.y
	assert_eq(covered, float(_TEX.y), "Strips cover the whole texture height")


func test_strips_offset_reconstructs_original_position() -> void:
	# Each strip's offset must place its top pixel where the centered full
	# sprite would have drawn it, so the split image is pixel-identical.
	var strips := TerrainSpriteRenderer.compute_row_strips(_TEX, _FOOTPRINT, _TILE, _ANCHOR_Y, _OFFSET_Y)
	for strip: Dictionary in strips:
		var region: Rect2 = strip["region_rect"]
		var offset: Vector2 = strip["offset"]
		# centered full sprite maps texture-y `v` to local y (-tex_h/2 + v).
		var expected_local_top: float = -float(_TEX.y) / 2.0 + region.position.y
		assert_eq(offset.y, expected_local_top, "Strip offset keeps pixels aligned")
		assert_eq(offset.x, -float(_TEX.x) / 2.0, "Strips left-align to the texture")


func test_strips_sort_front_to_back() -> void:
	var strips := TerrainSpriteRenderer.compute_row_strips(_TEX, _FOOTPRINT, _TILE, _ANCHOR_Y, _OFFSET_Y)
	# Row 0 is north (back, higher row_index); the last row is south (front).
	assert_gt(int(strips[0]["row_index"]), int(strips[strips.size() - 1]["row_index"]),
			"North strip is further back (higher row index) than the south strip")


func test_overhang_strip_occludes_units_behind_the_sprite() -> void:
	# THE invariant: the north strip (which carries all overhang) must out-sort
	# any unit standing north of the footprint, so towers still occlude units
	# behind the castle — including "two rows above the bottom row".
	var strips := TerrainSpriteRenderer.compute_row_strips(_TEX, _FOOTPRINT, _TILE, _ANCHOR_Y, _OFFSET_Y)
	var north_strip_z: int = TerrainSpriteRenderer.body_z(int(strips[0]["row_index"]))

	# Footprint spans cells y=3 (top) and y=4 (bottom). "Two rows above the
	# bottom row" = cell y=2; one further = y=1. Both must be occluded.
	for behind_cell_y: int in [2, 1]:
		var unit_row: int = TerrainSpriteRenderer.front_row_index(behind_cell_y, 1, _OFFSET_Y)
		var unit_z: int = ZIndexCalculator.calculate_sorting_order(
				unit_row, 100, ZIndexCalculator.ZIndexLayer.UNITS)
		assert_gt(north_strip_z, unit_z,
				"Overhang strip occludes a unit standing at cell y=%d (behind the castle)" % behind_cell_y)


func test_shadow_path_convention() -> void:
	assert_eq(TerrainSpriteRenderer._shadow_path_for("res://art/x/castle_a.png"),
			"res://art/x/castle_a_shadow.png")
	assert_eq(TerrainSpriteRenderer._shadow_path_for("res://art/x/castle_a.tres"), "",
			"Non-PNG paths produce no shadow pairing")


# =============================================================================
# Spawn behavior against the real tileset — the same code path serves both
# paint layers, so a tree painted on DecorationTileLayer gets its canopy and
# its shadow exactly like one on ModifierTileLayer (the bug this replaced:
# the decoration layer drew a cropped 32x32 chunk at a flat z, no shadow).
# =============================================================================

const _TILESET_PATH := "res://resources/battle_tileset.tres"


func _source_named(tileset: TileSet, sprite_name: String) -> Dictionary:
	for i in range(tileset.get_source_count()):
		var id: int = tileset.get_source_id(i)
		var source := tileset.get_source(id) as TileSetAtlasSource
		if source != null and source.resource_name == sprite_name:
			return {"id": id, "atlas": source.get_tile_id(0), "source": source}
	return {}


## Builds Parent > [<layer_name> TileMapLayer, renderer] with `paints` as
## {cell: sprite_name}, adds it to the tree (so _ready → refresh runs) and
## returns the renderer.
func _spawn_layer_with(layer_name: String, paints: Dictionary) -> TerrainSpriteRenderer:
	var tileset: TileSet = load(_TILESET_PATH)
	assert_not_null(tileset, "tileset loads")
	var parent := Node2D.new()
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tileset
	for cell: Vector2i in paints:
		var entry := _source_named(tileset, paints[cell])
		assert_false(entry.is_empty(), "'%s' is registered" % paints[cell])
		layer.set_cell(cell, entry["id"], entry["atlas"])
	parent.add_child(layer)
	var renderer := TerrainSpriteRenderer.new()
	renderer.layer_path = NodePath("../" + layer_name)
	parent.add_child(renderer)
	add_child_autofree(parent)
	return renderer


func _textures_of(sprites: Array[Sprite2D]) -> Array[String]:
	var names: Array[String] = []
	for s in sprites:
		names.append(s.texture.resource_path.get_file())
	names.sort()
	return names


func test_decoration_layer_gets_full_visual_and_authored_shadow() -> void:
	# darkforest_a: 96x96 PNG, 1x1 footprint, ships a _shadow.png.
	var renderer := _spawn_layer_with("DecorationTileLayer", {Vector2i(2, -3): "darkforest_a"})
	var sprites := renderer.get_spawned_sprites()
	assert_eq(_textures_of(sprites), ["darkforest_a.png", "darkforest_a_shadow.png"],
			"body + authored shadow, both from the full PNGs (not the atlas chunk)")
	var layer := renderer.get_node("../DecorationTileLayer") as TileMapLayer
	assert_false(layer.visible, "the tilemap layer is hidden so the cropped chunk doesn't double-draw")
	for s in sprites:
		assert_eq(s.position, layer.map_to_local(Vector2i(2, -3)), "1x1 sprites center on the painted cell")
		assert_false(s.z_as_relative, "absolute board z")
		assert_eq(s.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)


func test_modifier_layer_renders_identically_to_decoration_layer() -> void:
	var as_modifier := _spawn_layer_with("ModifierTileLayer", {Vector2i(2, -3): "darkforest_a"})
	var as_decoration := _spawn_layer_with("DecorationTileLayer", {Vector2i(2, -3): "darkforest_a"})
	var mod_sprites := as_modifier.get_spawned_sprites()
	var dec_sprites := as_decoration.get_spawned_sprites()
	assert_eq(_textures_of(mod_sprites), _textures_of(dec_sprites), "same textures")
	assert_eq(mod_sprites.size(), dec_sprites.size())
	for i in range(mod_sprites.size()):
		assert_eq(dec_sprites[i].z_index, mod_sprites[i].z_index,
				"same z on either layer — the layer decides gameplay, never looks")
		assert_eq(dec_sprites[i].position, mod_sprites[i].position)


func test_sprite_without_authored_shadow_spawns_body_only() -> void:
	# crater_a ships no _shadow.png (a hole in the ground casts nothing).
	var renderer := _spawn_layer_with("DecorationTileLayer", {Vector2i(0, 0): "crater_a"})
	assert_eq(_textures_of(renderer.get_spawned_sprites()), ["crater_a.png"])


func test_multi_row_sprite_interleaves_per_row_with_one_shadow() -> void:
	# castle_a: 128x128, 2x2 footprint, default "interleave" → 2 strips.
	# Tilemap y is negative in real maps (game grid is Y-up; GridManager has
	# no bounds in this test so grid_offset_y is 0 and rows must be >= 0 to
	# avoid the row clamp).
	var renderer := _spawn_layer_with("DecorationTileLayer", {Vector2i(1, -4): "castle_a"})
	var sprites := renderer.get_spawned_sprites()
	assert_eq(_textures_of(sprites), ["castle_a.png", "castle_a.png", "castle_a_shadow.png"],
			"one strip per footprint row + one shadow")
	var strip_z: Array[int] = []
	for s in sprites:
		if s.region_enabled:
			strip_z.append(s.z_index)
	assert_eq(strip_z.size(), 2)
	assert_ne(strip_z[0], strip_z[1], "each row strip sorts at its own depth")


func test_body_and_shadow_z_follow_the_static_helpers() -> void:
	var cell := Vector2i(4, -6)
	var renderer := _spawn_layer_with("DecorationTileLayer", {cell: "darkforest_a"})
	var row: int = TerrainSpriteRenderer.front_row_index(cell.y, 1, GridManager.grid_offset_y)
	for s in renderer.get_spawned_sprites():
		if s.texture.resource_path.ends_with("_shadow.png"):
			assert_eq(s.z_index, TerrainSpriteRenderer.shadow_z(row), "shadow z")
		else:
			assert_eq(s.z_index, TerrainSpriteRenderer.body_z(row), "body z")


func test_refresh_rebuilds_from_the_layer() -> void:
	var renderer := _spawn_layer_with("DecorationTileLayer", {Vector2i(0, 0): "crater_a"})
	var layer := renderer.get_node("../DecorationTileLayer") as TileMapLayer
	var tileset: TileSet = layer.tile_set
	var tree := _source_named(tileset, "darkforest_a")
	layer.set_cell(Vector2i(1, 0), tree["id"], tree["atlas"])
	renderer.refresh()
	assert_eq(_textures_of(renderer.get_spawned_sprites()),
			["crater_a.png", "darkforest_a.png", "darkforest_a_shadow.png"],
			"refresh picks up the newly painted cell")


# =============================================================================
# Generated cast shadow — the fallback for sprites with no authored
# _shadow.png. Same tip-over as UnitShadow; self-masked like the exporter.
# =============================================================================

## 32x64 canvas holding an 8-wide opaque "trunk" (x 12..19) from y=8 down to
## y=55, so the feet line is row 56 and the trunk stands 48px tall.
func _trunk_image(width: int = 32, height: int = 64, top: int = 8, bottom: int = 56,
		left: int = 12, right: int = 20) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(top, bottom):
		for x in range(left, right):
			img.set_pixel(x, y, Color.WHITE)
	return img


func test_generated_shadow_lies_to_the_right_of_the_feet_and_squats() -> void:
	# Dials pinned (1.0 / 0.25 / no shear / no nudge) so this doesn't drift
	# with the live sun.
	var cast := TerrainSpriteRenderer.generate_cast_shadow(_trunk_image(), 1.0, 0.25, 0.0, 0.0)
	assert_false(cast.is_empty(), "an opaque sprite casts")
	var image: Image = cast["image"]
	var anchor: Vector2 = cast["anchor"]
	# The trunk stands 48px above its feet → the rigid tip-over lays 48px of
	# smear to the RIGHT, starting at the feet x (canvas center 16 → local 0).
	assert_eq(image.get_width(), 48, "smear length = height above the feet × smoosh_x")
	assert_eq(anchor.x, 0.0, "smear starts at the caster's center line and reaches right")
	# 8px of trunk width × 0.25 squash → a 2px-tall smear straddling the feet
	# line (canvas row 56 → local 56 - 32 = 24; rows 23..24).
	assert_eq(image.get_height(), 2, "squat: trunk width × smoosh_y")
	assert_eq(anchor.y, 23.0, "smear sits on the feet line (local y = feet - h/2 - 1)")


func test_generated_shadow_is_ink_and_never_tints_its_own_caster() -> void:
	var sprite := _trunk_image()
	var cast := TerrainSpriteRenderer.generate_cast_shadow(sprite, 1.0, 0.25, 0.0, 0.0)
	var image: Image = cast["image"]
	var anchor: Vector2 = cast["anchor"]
	var origin := anchor + Vector2(sprite.get_width() / 2.0, sprite.get_height() / 2.0)
	var ink_pixels: int = 0
	for py in range(image.get_height()):
		for px in range(image.get_width()):
			var c := image.get_pixel(px, py)
			if c.a <= 0.0:
				continue
			ink_pixels += 1
			assert_almost_eq(c.a, GameColors.CAST_SHADOW_INK.a, 0.01, "40% ink, baked")
			assert_eq(Vector3(c.r, c.g, c.b), Vector3.ZERO, "black ink")
			# Map back to the sprite: no ink may sit under an opaque trunk pixel.
			var sx: int = int(origin.x) + px
			var sy: int = int(origin.y) + py
			if sx >= 0 and sx < sprite.get_width() and sy >= 0 and sy < sprite.get_height():
				assert_false(sprite.get_pixel(sx, sy).a > 0.5,
						"smear pixel (%d,%d) is under the caster at (%d,%d) — should be masked" % [px, py, sx, sy])
	assert_gt(ink_pixels, 0, "something survived the self-mask")
	# The row that overlaps the trunk's bottom row (canvas y=55) is cleared
	# where the trunk is (x 16..19) and inked just past it (x=20).
	var trunk_row: int = 55 - int(origin.y)
	assert_eq(image.get_pixel(16 - int(origin.x), trunk_row).a, 0.0, "under the trunk: erased")
	assert_almost_eq(image.get_pixel(20 - int(origin.x), trunk_row).a, 0.4, 0.01, "just past the trunk: ink")


func test_generated_shadow_is_empty_for_transparent_art() -> void:
	var blank := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	blank.fill(Color(0.0, 0.0, 0.0, 0.0))
	assert_true(TerrainSpriteRenderer.generate_cast_shadow(blank, 1.0, 0.25, 0.0, 0.0).is_empty())
	assert_true(TerrainSpriteRenderer.generate_cast_shadow(null, 1.0, 0.25, 0.0, 0.0).is_empty())


## An in-memory tileset with one synthetic 96x96 tree (1x1 footprint at
## atlas (1,1)) that ships no _shadow.png — the generated-fallback case the
## real export set can't exercise (everything there is either authored or
## opted out).
func _spawn_synthetic_tree(sprite_name: String = "synthetic_tree") -> TerrainSpriteRenderer:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(_trunk_image(96, 96, 16, 80, 44, 52))
	source.texture_region_size = Vector2i(32, 32)
	source.resource_name = sprite_name
	source.create_tile(Vector2i(1, 1), Vector2i(1, 1))
	tileset.add_source(source, 500)
	var parent := Node2D.new()
	var layer := TileMapLayer.new()
	layer.name = "DecorationTileLayer"
	layer.tile_set = tileset
	layer.set_cell(Vector2i(3, -5), 500, Vector2i(1, 1))
	parent.add_child(layer)
	var renderer := TerrainSpriteRenderer.new()
	renderer.layer_path = ^"../DecorationTileLayer"
	parent.add_child(renderer)
	add_child_autofree(parent)
	return renderer


func test_sprite_without_authored_shadow_gets_a_generated_one() -> void:
	var renderer := _spawn_synthetic_tree()
	var sprites := renderer.get_spawned_sprites()
	assert_eq(sprites.size(), 2, "body + generated shadow")
	var body: Sprite2D = null
	var shadow: Sprite2D = null
	for s in sprites:
		if s.centered:
			body = s
		else:
			shadow = s
	assert_not_null(body, "the body is the centered full-PNG sprite")
	assert_not_null(shadow, "the generated shadow is a top-left anchored sprite")
	if body == null or shadow == null:
		return
	var row: int = TerrainSpriteRenderer.front_row_index(-5, 1, GridManager.grid_offset_y)
	assert_eq(shadow.z_index, TerrainSpriteRenderer.shadow_z(row), "generated shadow uses the shadow slot")
	assert_eq(body.z_index, TerrainSpriteRenderer.body_z(row))
	assert_true(shadow.position.x >= body.position.x, "the cast reaches right from the trunk")
	assert_eq(shadow.position, shadow.position.round(), "integer world position — pixel grid")
	var pixel: Color = shadow.texture.get_image().get_pixel(shadow.texture.get_width() - 1, 0)
	assert_almost_eq(pixel.a, GameColors.CAST_SHADOW_INK.a, 0.01, "far tip of the smear is ink")


func test_generated_shadow_respects_the_debug_kill_switch() -> void:
	var was: bool = DebugConfig.terrain_generated_shadows
	DebugConfig.terrain_generated_shadows = false
	var renderer := _spawn_synthetic_tree()
	assert_eq(renderer.get_spawned_sprites().size(), 1, "body only")
	DebugConfig.terrain_generated_shadows = was


func test_generated_shadow_respects_casts_shadow_false() -> void:
	ModifierTerrainMap.load_from_dictionary({
		"by_prefix": {},
		"by_sprite": {"flat_thing": {"casts_shadow": false}},
	})
	var renderer := _spawn_synthetic_tree("flat_thing")
	assert_eq(renderer.get_spawned_sprites().size(), 1, "opted out: body only")
	ModifierTerrainMap.reload()


# =============================================================================
# Editor preview — front row derivation (the runtime asks GridManager; the
# editor has no GridManager and derives the same number from the floor).
# =============================================================================

func test_editor_grid_offset_makes_the_southernmost_cell_row_zero() -> void:
	var cells: Array[Vector2i] = [Vector2i(0, -8), Vector2i(3, 0), Vector2i(-2, -3)]
	var offset: int = TerrainSpriteRenderer.editor_grid_offset_y(cells)
	assert_eq(offset, 0, "max tilemap y is 0 → offset 0")
	assert_eq(TerrainSpriteRenderer.front_row_index(0, 1, offset), 0, "southernmost cell is the front row")
	assert_eq(TerrainSpriteRenderer.front_row_index(-8, 1, offset), 8, "northernmost cell is 8 rows back")


func test_editor_grid_offset_matches_the_builder_convention_for_negative_maps() -> void:
	# A map painted entirely at negative tilemap y (max y = -2): the builder
	# passes -max_y to set_grid_bounds, so offset must be 2.
	var cells: Array[Vector2i] = [Vector2i(0, -9), Vector2i(4, -2)]
	assert_eq(TerrainSpriteRenderer.editor_grid_offset_y(cells), 2)
	assert_eq(TerrainSpriteRenderer.front_row_index(-2, 1, 2), 0)


func test_editor_grid_offset_is_zero_for_an_empty_layer() -> void:
	var none: Array[Vector2i] = []
	assert_eq(TerrainSpriteRenderer.editor_grid_offset_y(none), 0)


func test_runtime_renderer_does_not_poll() -> void:
	# set_process is the editor-only poll; at runtime the builder refreshes
	# explicitly and the layer never changes underneath us.
	var renderer := _spawn_layer_with("DecorationTileLayer", {Vector2i(0, 0): "crater_a"})
	assert_false(renderer.is_processing(), "no per-frame work at runtime")


# =============================================================================
# casts_shadow: false means NO shadow — the authored one included. The
# system for floor elements Lawrence drew a shadow for anyway.
# =============================================================================

func test_casts_shadow_false_suppresses_an_authored_shadow() -> void:
	ModifierTerrainMap.load_from_dictionary({
		"by_prefix": {},
		"by_sprite": {"darkforest_a": {"casts_shadow": false}},
	})
	var renderer := _spawn_layer_with("DecorationTileLayer", {Vector2i(2, -3): "darkforest_a"})
	assert_eq(_textures_of(renderer.get_spawned_sprites()), ["darkforest_a.png"],
			"darkforest_a ships a _shadow.png, and it must NOT be drawn")
	ModifierTerrainMap.reload()


func test_wildcard_casts_shadow_false_covers_the_family_on_the_board() -> void:
	ModifierTerrainMap.load_from_dictionary({
		"by_prefix": {},
		"by_sprite": {"volcano_*": {"casts_shadow": false}},
	})
	var renderer := _spawn_layer_with("DecorationTileLayer",
			{Vector2i(0, -2): "volcano_c", Vector2i(1, -2): "darkforest_a"})
	assert_eq(_textures_of(renderer.get_spawned_sprites()),
			["darkforest_a.png", "darkforest_a_shadow.png", "volcano_c.png"],
			"the volcano loses its shadow, the neighbor keeps its own")
	ModifierTerrainMap.reload()
