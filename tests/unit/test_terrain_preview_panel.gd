## TerrainPreviewPanel: pure formatters plus the melee/ranged defense split.
## The formatter tests pin the movement-cost display that used to ceil Road's
## 0.5 into a misleading "1"; the split tests pin that a style-split terrain
## (Crater) shows BOTH defense numbers instead of a single misleading "—".
extends GutTest

const PANEL_SCENE: String = "res://scenes/ui/panels/terrain_preview_panel/terrain_preview_panel.tscn"

## Grid layout: 5 header icons, then 5 cells per row. Defense is column 3.
const FIRST_ROW_START: int = 5
const DEFENSE_COLUMN_OFFSET: int = 2


func test_whole_costs_render_as_integers() -> void:
	assert_eq(TerrainPreviewPanel._format_move_cost(1.0), "1")
	assert_eq(TerrainPreviewPanel._format_move_cost(3.0), "3")


func test_half_costs_render_with_fraction_glyph() -> void:
	assert_eq(TerrainPreviewPanel._format_move_cost(0.5), "½", "Road cost")
	assert_eq(TerrainPreviewPanel._format_move_cost(1.5), "1½")


func test_other_fractions_fall_back_to_decimals() -> void:
	assert_eq(TerrainPreviewPanel._format_move_cost(0.25), "0.25")


# =============================================================================
# Melee/ranged defense split (Crater)
# =============================================================================

func test_split_defense_lines_carry_style_markers() -> void:
	assert_eq(TerrainPreviewPanel._format_split_defense(1.2, 0.9), ["M1.2", "R0.9"],
			"M/R letter prefixes are the interim markers until Lawrence's glyphs land")


func _panel() -> TerrainPreviewPanel:
	var panel: TerrainPreviewPanel = (load(PANEL_SCENE) as PackedScene).instantiate()
	add_child_autofree(panel)
	return panel


func _tile(terrain: String) -> Tile:
	var tile := Tile.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	add_child_autofree(tile)
	tile.terrain_type_name = terrain
	return tile


func _default_row_defense_cell(panel: TerrainPreviewPanel) -> Node:
	return panel._grid.get_child(FIRST_ROW_START + DEFENSE_COLUMN_OFFSET)


func test_crater_defense_cell_splits_into_melee_and_ranged() -> void:
	var panel := _panel()
	panel.show_tile(_tile("Crater"))
	var cell: Node = _default_row_defense_cell(panel)
	assert_true(cell is VBoxContainer, "split terrain renders a stacked two-line defense cell")
	var expected: Array[String] = TerrainPreviewPanel._format_split_defense(1.2, 0.85)
	var line_texts: Array[String] = []
	for line: Node in cell.get_children():
		if line is TapTooltip:
			continue
		line_texts.append((line.get_node("Label") as Label).text)
	assert_eq(line_texts, expected, "both combined defense values are visible at a glance")


func test_unsplit_terrain_keeps_the_single_defense_cell() -> void:
	var panel := _panel()
	panel.show_tile(_tile("Plains"))
	var cell: Node = _default_row_defense_cell(panel)
	assert_false(cell is VBoxContainer, "no style split → the familiar single cell")
