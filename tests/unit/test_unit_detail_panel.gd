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
# Center column (RQD 2026-08-11 round 3): moves are REAL MoveChipButtons — the
# chip is the game's clickable move representation everywhere. Passives keep
# the Manage Units sheet-row vocabulary; open move slots are inert muted rows.
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


func test_moves_render_as_chips_with_inert_muted_empties() -> void:
	var panel := _make_panel_with_moves([_make_move("Frost Lance")])
	assert_eq(panel._move_rows.size(), UnitSheet.MOVE_SLOT_COUNT,
			"the sheet's rule survives: every slot shows, four always")
	var chip := panel._move_rows[0] as MoveChipButton
	assert_not_null(chip, "a real move is a real chip — element-colored identity")
	assert_true(chip.prefer_full_name, "detail venue shows full names")
	assert_eq(chip._name_label.text, "Frost Lance")
	assert_false(chip._uses_label.visible,
			"identity-only selectors: the pane beside them shows the numbers")
	assert_false(chip.peek_enabled,
			"no-op venue: the detail pane IS the tooltip's content")
	var open_slot: Button = panel._move_rows[1]
	assert_null(open_slot as MoveChipButton, "open slots are rows, not blank chips")
	assert_eq(_row_label(open_slot).text, "— empty —")
	assert_eq(open_slot.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"nothing to inspect in an open slot — inert, not clickable")


func test_selection_brackets_mark_the_inspected_move() -> void:
	var panel := _make_panel_with_moves([_make_move("Ember"), _make_move("Spark")])
	var before: Array[Button] = panel._move_rows.duplicate()
	panel._select(UnitDetailPanel.SelectionType.MOVE, 1)
	assert_true((panel._move_rows[1] as MoveChipButton).selected,
			"brackets = 'you are inspecting this'")
	assert_false((panel._move_rows[0] as MoveChipButton).selected)
	assert_eq(panel._move_rows, before,
			"chips persist across selection changes — the flag toggles, no rebuild")
	panel._select(UnitDetailPanel.SelectionType.MOVE, 1)
	assert_false((panel._move_rows[1] as MoveChipButton).selected,
			"re-click toggles the inspection off")


func test_depleted_chip_stays_inspectable_via_denied() -> void:
	var panel := _make_panel_with_moves([_make_move("Spark", 0, 4)])
	var spark := panel._move_rows[0] as MoveChipButton
	assert_true(spark.disabled, "depleted wears the dark tier here too")
	spark.denied.emit()
	assert_eq(panel._selection_type, UnitDetailPanel.SelectionType.MOVE,
			"denied routes to select — in this venue the detail pane IS the why")


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


func test_rows_size_the_column_not_the_other_way_around() -> void:
	# Anchored row content contributes nothing to minimum-size math, so each
	# row MEASURES its name and claims a real minimum width — the center
	# column's width is its widest row (RQD 2026-08-11 round 2; the expand
	# approach let the open detail pane squeeze the column to header width).
	var panel := _make_panel_with_moves([_make_move("Compressed Air"), _make_move("Bonk")])
	var long_chip: Button = panel._move_rows[0]
	var short_chip: Button = panel._move_rows[1]
	assert_gt(long_chip.custom_minimum_size.x, short_chip.custom_minimum_size.x,
			"a longer name claims a wider chip")
	var text_width: float = UIManager.font_8px.get_string_size(
			"Compressed Air", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	assert_gt(long_chip.custom_minimum_size.x, text_width,
			"the chip fits its full name plus both icons — nothing clips")


func test_the_hp_denominator_speaks_with_the_hp_keys_voice() -> void:
	# RQD 2026-08-11: the numerator breathes with current HP; "/20" is a
	# frame fact and wears the same color as the "HP" label beside it —
	# read FROM that label, so the pair can't drift.
	var panel := _make_panel() as UnitDetailPanel
	var data := CharacterData.new()
	panel.show_character(data)
	assert_not_null(panel._hp_name_label, "the scene's HP key label was found")
	assert_eq(panel._hp_max_label.get_theme_color("font_color"),
			panel._hp_name_label.get_theme_color("font_color"))
	assert_ne(panel._hp_label.get_theme_color("font_color"),
			panel._hp_max_label.get_theme_color("font_color"),
			"numerator stays on the health ramp — full HP green != the key's voice")
