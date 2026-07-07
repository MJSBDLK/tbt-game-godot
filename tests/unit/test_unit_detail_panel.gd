## UnitDetailPanel scene-level checks. Instantiates the real
## unit_info_panel.tscn so _ready-time node caching (including the runtime-
## cloned Range mini-panel) is exercised headlessly instead of only in-game.
extends GutTest

const _PANEL_SCENE: PackedScene = preload("res://scenes/ui/panels/unit_detail_panel/unit_info_panel.tscn")


func _make_panel() -> Node:
	var panel: Node = _PANEL_SCENE.instantiate()
	add_child_autofree(panel)
	return panel


func test_range_mini_panel_is_cloned_into_the_stat_row() -> void:
	var panel := _make_panel()
	var row: HBoxContainer = panel.get_node(
			"MainRow/RightColumnMargin/MovePassiveStatusParent/MoveDescription/PowerAccUsgContainer")
	var range_panel: Node = row.get_node_or_null("RangePanelContainer")
	assert_not_null(range_panel, "Range mini-panel cloned at _ready")
	assert_eq(range_panel.get_index(), row.get_node("PowerPanelContainer").get_index() + 1,
			"Range sits between Power and Accuracy")
	assert_not_null(panel._move_detail_range_label, "Range value label cached")


func test_move_detail_populates_range_value() -> void:
	var panel := _make_panel()
	var move := Move.new()
	move.move_name = "Testshot"
	move.attack_range = 3
	move.base_power = 5
	move.accuracy = 80
	move.max_uses = 10
	move.current_uses = 10
	var data := CharacterData.new()
	data.equipped_moves.append(move)
	panel._character_data = data
	panel._show_move_detail(0)
	assert_eq(panel._move_detail_range_label.text, "3",
			"Move detail shows the move's base range")
