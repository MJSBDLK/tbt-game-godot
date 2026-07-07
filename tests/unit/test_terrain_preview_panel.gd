## TerrainPreviewPanel pure helpers. The panel itself is exercised in-game;
## these pin the movement-cost formatter that used to ceil Road's 0.5 into a
## misleading "1" (todo: "terrain preview still reads 1 instead of ½").
extends GutTest


func test_whole_costs_render_as_integers() -> void:
	assert_eq(TerrainPreviewPanel._format_move_cost(1.0), "1")
	assert_eq(TerrainPreviewPanel._format_move_cost(3.0), "3")


func test_half_costs_render_with_fraction_glyph() -> void:
	assert_eq(TerrainPreviewPanel._format_move_cost(0.5), "½", "Road cost")
	assert_eq(TerrainPreviewPanel._format_move_cost(1.5), "1½")


func test_other_fractions_fall_back_to_decimals() -> void:
	assert_eq(TerrainPreviewPanel._format_move_cost(0.25), "0.25")
