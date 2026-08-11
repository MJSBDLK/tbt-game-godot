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
# Sheet-vocabulary rows (RQD 2026-08-11): moves/passives match Manage Units.
# Supersedes the 2026-07-19 MoveChipButton adoption — the chips are gone.
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


func _row_label(row: Control) -> Label:
	if row is Label:
		return row
	for child: Node in row.get_children():
		if child is Control:
			var found: Label = _row_label(child)
			if found != null:
				return found
	return null


func test_moves_render_as_four_sheet_rows_with_muted_empties() -> void:
	var panel := _make_panel_with_moves([_make_move("Frost Lance")])
	assert_eq(panel._move_rows.size(), UnitSheet.MOVE_SLOT_COUNT,
			"the sheet's rule: every slot shows, four always")
	assert_eq(_row_label(panel._move_rows[0]).text, "Frost Lance",
			"full name, PRIMARY voice")
	assert_eq(_row_label(panel._move_rows[1]).text, "— empty —",
			"open slots read as muted absence, not hidden rows")


func test_the_selected_row_wears_the_sheet_chrome() -> void:
	var panel := _make_panel_with_moves([_make_move("Ember"), _make_move("Spark")])
	panel._select(UnitDetailPanel.SelectionType.MOVE, 1)
	var selected_style: StyleBoxFlat = \
			panel._move_rows[1].get_theme_stylebox("normal") as StyleBoxFlat
	var idle_style: StyleBoxFlat = \
			panel._move_rows[0].get_theme_stylebox("normal") as StyleBoxFlat
	assert_gt(selected_style.border_width_left, 0,
			"selected = azure border + wash, the sheet's vocabulary")
	assert_eq(idle_style.border_width_left, 0)
	panel._select(UnitDetailPanel.SelectionType.MOVE, 1)
	var after_style: StyleBoxFlat = \
			panel._move_rows[1].get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(after_style.border_width_left, 0, "re-click toggles the inspection off")


func test_depleted_moves_go_muted_but_stay_inspectable() -> void:
	var panel := _make_panel_with_moves([_make_move("Spark", 0, 4)])
	var row: Button = panel._move_rows[0]
	assert_false(row.disabled, "a spent move is still a fact you can inspect")
	assert_eq(_row_label(row).text, "Spark")
	row.pressed.emit()
	assert_eq(panel._selection_type, UnitDetailPanel.SelectionType.MOVE,
			"pressing a depleted row opens its detail — the pane IS the why")


func test_passives_render_as_four_sheet_rows() -> void:
	var panel := _make_panel() as UnitDetailPanel
	var data := CharacterData.new()
	data.equipped_passives.append("Glib")
	panel.show_character(data)
	assert_eq(panel._passive_rows.size(), UnitSheet.PASSIVE_SLOT_COUNT)
	assert_eq(_row_label(panel._passive_rows[0]).text, "Glib")
	assert_eq(_row_label(panel._passive_rows[1]).text, "— empty —")


func test_the_class_line_split_off_its_xp_suffix() -> void:
	# "SKULK Lv.11 · 0/100 XP" overflowed and widened the whole left column
	# (RQD 2026-08-11) — XP lives in its own sheet-style row now, and that row
	# only shows for live PLAYER units (roster inspection has no XP context).
	var panel := _make_panel() as UnitDetailPanel
	var data := CharacterData.new()
	data.level = 11
	panel.show_character(data)
	assert_false(panel._class_label.text.contains("XP"),
			"the class line carries class and level only")
	assert_string_contains(panel._class_label.text, "· Lv 11")
	assert_false(panel._xp_row.visible,
			"no live unit = no XP row (enemies and roster inspection)")


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
		# The HP row is covered too (RQD 2026-08-11): it converted to a
		# StatCapBar in health mode, so its scene bars went dark like the rest.
		var bar_container: Node = stat_container.get_node_or_null(
				"HBoxContainer/StatBarContainer")
		if bar_container == null:
			continue
		rows_checked += 1
		var cap_bars: int = 0
		for child: Node in bar_container.get_children():
			if child is StatCapBar:
				cap_bars += 1
				# Anchor-centered, like the scene bars it replaced. Copying a
				# scene position at _ready captured a PRE-layout y and parked
				# every bar at the top of its row (RQD 2026-08-11) — anchors
				# make the layout engine own the centering instead.
				assert_eq((child as Control).anchor_top, 0.5,
						"%s: the cap bar centers by anchor, not a captured position"
						% stat_container.name)
				assert_eq((child as Control).anchor_bottom, 0.5, stat_container.name)
			elif child is ColorRect:
				assert_false((child as ColorRect).visible,
						"%s/%s: legacy scene rect must stay hidden behind the cap bar"
						% [stat_container.name, child.name])
		assert_eq(cap_bars, 1, "%s: exactly one StatCapBar" % stat_container.name)
	assert_gt(rows_checked, 0, "the scene's stat rows were actually found")


func test_selecting_an_empty_slot_never_opens_a_ghost_detail() -> void:
	# Empty rows are clickable (sheet vocabulary) but there's nothing to
	# describe — the pane stays hidden instead of rendering a move called "—".
	var panel := _make_panel_with_moves([_make_move("Ember")])
	panel._select(UnitDetailPanel.SelectionType.MOVE, 2)
	assert_false(panel._move_description.visible,
			"empty slot selected: no detail pane, no crash")
	var with_sentinel := _make_panel() as UnitDetailPanel
	var data := CharacterData.new()
	data.equipped_moves.append(Move.EMPTY)
	with_sentinel.show_character(data)
	with_sentinel._select(UnitDetailPanel.SelectionType.MOVE, 0)
	assert_false(with_sentinel._move_description.visible,
			"the Move.EMPTY sentinel is an empty slot, not a move named em-dash")
