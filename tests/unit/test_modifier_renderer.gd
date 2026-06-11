## Tests for ModifierRenderer's z-ordering math. The renderer itself needs a
## scene tree + tileset to run, but the row-index conversion — the part that
## decides occlusion — is a pure static function.
extends GutTest


# The project's z convention (see Unit._update_z_index and
# GridZIndexHandler usage in tilemap_grid_builder):
#   row_index = grid_y - grid_offset_y, where grid_y = -cell_y
#   row 0 = southernmost = highest z (front)
# A multi-cell modifier sorts by its SOUTHERN footprint row.


func test_front_row_matches_unit_convention_for_1x1() -> void:
	# Map with cells y 0..8 → grid_y -8..0 → grid_offset_y = -8.
	# A 1x1 modifier at cell y=8 (southernmost): row = -8 - (-8) = 0 (front).
	assert_eq(ModifierRenderer.front_row_index(8, 1, -8), 0,
			"Southernmost 1x1 modifier is front row (0)")
	# Same map, modifier at cell y=0 (northernmost): row = 0 - (-8) = 8.
	assert_eq(ModifierRenderer.front_row_index(0, 1, -8), 8,
			"Northernmost 1x1 modifier has the highest row index")


func test_front_row_uses_southern_edge_for_multi_cell() -> void:
	# 2x2 castle anchored at cell y=3 covers rows 3 and 4. It must sort by
	# row 4 (its southern edge), like a unit standing at cell y=4 would.
	var castle_row: int = ModifierRenderer.front_row_index(3, 2, -8)
	var unit_at_south_row: int = ModifierRenderer.front_row_index(4, 1, -8)
	assert_eq(castle_row, unit_at_south_row,
			"2x2 anchored at y=3 sorts like a 1x1 at y=4 (southern edge)")


func test_front_row_occlusion_ordering() -> void:
	var offset_y: int = -8
	# Unit NORTH of a 2x2 castle (cell y=2; castle anchored y=3 spans 3-4):
	# unit row > castle row → unit z < castle z → castle occludes the unit.
	var unit_north_row: int = ModifierRenderer.front_row_index(2, 1, offset_y)
	var castle_row: int = ModifierRenderer.front_row_index(3, 2, offset_y)
	var unit_z_north: int = ZIndexCalculator.calculate_sorting_order(
			unit_north_row, 100, ZIndexCalculator.ZIndexLayer.UNITS)
	var castle_z: int = ZIndexCalculator.calculate_sorting_order(
			castle_row, 100, ZIndexCalculator.ZIndexLayer.TERRAIN_MODIFIERS)
	assert_true(castle_z > unit_z_north,
			"Castle renders above a unit standing behind (north of) it")

	# Unit SOUTH of the castle (cell y=5): unit row < castle row → unit
	# renders above the castle's overhang.
	var unit_south_row: int = ModifierRenderer.front_row_index(5, 1, offset_y)
	var unit_z_south: int = ZIndexCalculator.calculate_sorting_order(
			unit_south_row, 100, ZIndexCalculator.ZIndexLayer.UNITS)
	assert_true(unit_z_south > castle_z,
			"Unit in front (south) renders above the castle")

	# Unit on the castle's OWN southern row: same row, UNITS layer (5) beats
	# TERRAIN_MODIFIERS layer (2).
	var unit_same_row: int = ModifierRenderer.front_row_index(4, 1, offset_y)
	var unit_z_same: int = ZIndexCalculator.calculate_sorting_order(
			unit_same_row, 100, ZIndexCalculator.ZIndexLayer.UNITS)
	assert_true(unit_z_same > castle_z,
			"Same-row unit renders above the modifier via layer offset")


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
	var strips := ModifierRenderer.compute_row_strips(_TEX, _FOOTPRINT, _TILE, _ANCHOR_Y, _OFFSET_Y)
	assert_eq(strips.size(), _FOOTPRINT.y, "One strip per footprint row")


func test_strips_tile_the_texture_contiguously() -> void:
	var strips := ModifierRenderer.compute_row_strips(_TEX, _FOOTPRINT, _TILE, _ANCHOR_Y, _OFFSET_Y)
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
	var strips := ModifierRenderer.compute_row_strips(_TEX, _FOOTPRINT, _TILE, _ANCHOR_Y, _OFFSET_Y)
	for strip: Dictionary in strips:
		var region: Rect2 = strip["region_rect"]
		var offset: Vector2 = strip["offset"]
		# centered full sprite maps texture-y `v` to local y (-tex_h/2 + v).
		var expected_local_top: float = -float(_TEX.y) / 2.0 + region.position.y
		assert_eq(offset.y, expected_local_top, "Strip offset keeps pixels aligned")
		assert_eq(offset.x, -float(_TEX.x) / 2.0, "Strips left-align to the texture")


func test_strips_sort_front_to_back() -> void:
	var strips := ModifierRenderer.compute_row_strips(_TEX, _FOOTPRINT, _TILE, _ANCHOR_Y, _OFFSET_Y)
	# Row 0 is north (back, higher row_index); the last row is south (front).
	assert_gt(int(strips[0]["row_index"]), int(strips[strips.size() - 1]["row_index"]),
			"North strip is further back (higher row index) than the south strip")


func test_overhang_strip_occludes_units_behind_the_modifier() -> void:
	# THE invariant: the north strip (which carries all overhang) must out-sort
	# any unit standing north of the footprint, so towers still occlude units
	# behind the castle — including "two rows above the bottom row".
	var strips := ModifierRenderer.compute_row_strips(_TEX, _FOOTPRINT, _TILE, _ANCHOR_Y, _OFFSET_Y)
	var north_strip_z: int = ZIndexCalculator.calculate_sorting_order(
			int(strips[0]["row_index"]), 100, ZIndexCalculator.ZIndexLayer.TERRAIN_MODIFIERS)

	# Footprint spans cells y=3 (top) and y=4 (bottom). "Two rows above the
	# bottom row" = cell y=2; one further = y=1. Both must be occluded.
	for behind_cell_y: int in [2, 1]:
		var unit_row: int = ModifierRenderer.front_row_index(behind_cell_y, 1, _OFFSET_Y)
		var unit_z: int = ZIndexCalculator.calculate_sorting_order(
				unit_row, 100, ZIndexCalculator.ZIndexLayer.UNITS)
		assert_gt(north_strip_z, unit_z,
				"Overhang strip occludes a unit standing at cell y=%d (behind the castle)" % behind_cell_y)


func test_shadow_path_convention() -> void:
	assert_eq(ModifierRenderer._shadow_path_for("res://art/x/castle_a.png"),
			"res://art/x/castle_a_shadow.png")
	assert_eq(ModifierRenderer._shadow_path_for("res://art/x/castle_a.tres"), "",
			"Non-PNG paths produce no shadow pairing")
