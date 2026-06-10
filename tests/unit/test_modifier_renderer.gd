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


func test_shadow_path_convention() -> void:
	assert_eq(ModifierRenderer._shadow_path_for("res://art/x/castle_a.png"),
			"res://art/x/castle_a_shadow.png")
	assert_eq(ModifierRenderer._shadow_path_for("res://art/x/castle_a.tres"), "",
			"Non-PNG paths produce no shadow pairing")
