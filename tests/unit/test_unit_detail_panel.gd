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


# =============================================================================
# Chip adoption (2026-07-19): MovePanel tablets -> real MoveChipButtons
# =============================================================================

func _make_move(move_name: String, uses: int = 3, max_uses: int = 5) -> Move:
	var move := Move.new()
	move.move_name = move_name
	move.element_type = Enums.ElementalType.FIRE
	move.current_uses = uses
	move.max_uses = max_uses
	return move


func _make_panel_with_moves(moves: Array[Move]) -> UnitDetailPanel:
	var panel := _make_panel() as UnitDetailPanel
	var data := CharacterData.new()
	data.equipped_moves = moves
	panel.show_character(data)
	return panel


func test_tablets_became_vocabulary_chips_with_full_names() -> void:
	var panel := _make_panel_with_moves([_make_move("Frost Lance")])
	assert_gt(panel._move_chips.size(), 1, "scene tablets replaced in place")
	for chip_button: MoveChipButton in panel._move_chips:
		assert_true(chip_button.prefer_full_name, "detail venue shows full names")
	assert_true(panel._move_chips[0].visible)
	assert_eq(panel._move_chips[0]._name_label.text, "Frost Lance",
			"full name, not the menu abbreviation")
	assert_false(panel._move_chips[1].visible, "empty slots hide")
	assert_false(panel._move_chips[0]._uses_label.visible,
			"identity-only selectors: the pane beside them shows the numbers")
	assert_false(panel._move_chips[0]._scheme_glyph.visible)


func test_selection_brackets_mark_the_inspected_move() -> void:
	var panel := _make_panel_with_moves([_make_move("Ember"), _make_move("Spark")])
	panel._select(UnitDetailPanel.SelectionType.MOVE, 1)
	assert_true(panel._move_chips[1].selected, "brackets = 'you are inspecting this'")
	assert_false(panel._move_chips[0].selected)
	panel._select(UnitDetailPanel.SelectionType.MOVE, 1)
	assert_false(panel._move_chips[1].selected,
			"re-click toggles the inspection off")


func test_depleted_chip_stays_inspectable_via_denied() -> void:
	var panel := _make_panel_with_moves([_make_move("Spark", 0, 4)])
	var spark := panel._move_chips[0]
	assert_true(spark.disabled, "depleted wears the dark tier here too")
	spark.denied.emit()
	assert_true(spark.selected,
			"denied routes to select — in this venue the detail pane IS the why")


func test_detail_chips_opt_out_of_hold_to_peek() -> void:
	var panel := _make_panel_with_moves([_make_move("Ember")])
	for chip_button: MoveChipButton in panel._move_chips:
		assert_false(chip_button.peek_enabled,
				"no-op venue (RQD 2026-07-21): the detail pane beside these"
				+ " chips IS the tooltip's content, live and larger")


# =============================================================================
# One track per bar (RQD 2026-08-11): StatCapBar draws the ONLY track
# =============================================================================

func test_the_cap_bar_is_the_only_visible_bar_in_every_stat_row() -> void:
	# The scene ships three legacy ColorRects per row (StatBar, StatBonusBar,
	# StatBarBackground). All three must be hidden — the full-width background
	# outlived the 2026-08-06 adoption and read as a second, longer track once
	# StatCapBar started scaling its track to the class cap.
	var panel := _make_panel()
	var stats: Node = panel.get_node(
			"MainRow/LeftColumnMargin/LeftColumn/StatsContainer")
	var rows_checked: int = 0
	for stat_container: Node in stats.get_children():
		# The HP row is exempt: its scene bars are the LIVE rendering (colored
		# by health ratio), deliberately not a StatCapBar yet — converting it
		# is an open todo item, and this test should start covering it then.
		if stat_container.name == "HPContainer":
			continue
		var bar_container: Node = stat_container.get_node_or_null(
				"HBoxContainer/StatBarContainer")
		if bar_container == null:
			continue
		rows_checked += 1
		var cap_bars: int = 0
		for child: Node in bar_container.get_children():
			if child is StatCapBar:
				cap_bars += 1
			elif child is ColorRect:
				assert_false((child as ColorRect).visible,
						"%s/%s: legacy scene rect must stay hidden behind the cap bar"
						% [stat_container.name, child.name])
		assert_eq(cap_bars, 1, "%s: exactly one StatCapBar" % stat_container.name)
	assert_gt(rows_checked, 0, "the scene's stat rows were actually found")
