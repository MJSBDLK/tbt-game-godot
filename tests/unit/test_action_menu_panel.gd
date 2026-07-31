## ActionMenuPanel after the border-vocabulary adoption (Lawrence-accepted
## 2026-07-19, "cramped but organized"). The contract pinned here: move chips
## are real MoveChipButtons, text actions are InteractiveButtons, the §7
## gameplay rules hold (out-of-range HIDDEN, depleted GRAYED with a deny),
## and focus is the menu cursor — brackets follow it.
extends GutTest


func before_each() -> void:
	# Cursor-driven by default so the long-standing focus-on-open behavior
	# holds for every test that doesn't probe the quiet-open path.
	InputSource.last_kind = InputSource.Kind.CURSOR


func after_each() -> void:
	InputSource.last_kind = InputSource.Kind.POINTER  # the boot default
	GridManager.clear_move_range_preview()


func _make_move(move_name: String, uses: int = 3, max_uses: int = 5) -> Move:
	var move := Move.new()
	move.move_name = move_name
	move.element_type = Enums.ElementalType.FIRE
	move.current_uses = uses
	move.max_uses = max_uses
	return move


func _make_unit(moves: Array[Move]) -> Unit:
	# Off-tree Unit (autofree, no _ready) — same pattern as test_unit.gd.
	# current_tile stays null, so MoveTargeting finds no targets: main-menu
	# moves are all "out of range" here, which is itself part of the contract.
	var unit := Unit.new()
	autofree(unit)
	var data := CharacterData.new()
	data.equipped_moves = moves
	unit.character_data = data
	return unit


func _make_panel(unit: Unit) -> ActionMenuPanel:
	var panel := ActionMenuPanel.new()
	add_child_autofree(panel)
	panel.show_menu(unit)
	return panel


func _press(button: BaseButton) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	button._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	button._gui_input(release)


func test_background_tint_is_inset_under_the_rounded_border() -> void:
	# The tint must be an inset rounded child, never the stylebox: a full-rect
	# square fill peeked past the border overlay's rounded corners (RQD
	# 2026-07-29; the system/options menus ship the same recipe).
	var panel := _make_panel(_make_unit([_make_move("Ember")]))
	assert_true(panel.get_theme_stylebox("panel") is StyleBoxEmpty,
			"panel stylebox draws nothing — the tint is a child")
	var background := panel.get_child(0) as Panel
	assert_not_null(background, "inset background is the first child (under content)")
	assert_eq(background.offset_left, 5.0, "inset to the 10px border art's midpoint")
	assert_eq(background.offset_right, -5.0)
	var style := background.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(style.bg_color, GameColors.HUD_PANEL_BACKGROUND)
	assert_eq(style.corner_radius_top_left, 5, "rounded so corners stay tucked")


func test_main_menu_text_actions_are_interactive_buttons() -> void:
	var panel := _make_panel(_make_unit([_make_move("Ember")]))
	var items := panel._content_container.get_children()
	# The healthy move has no valid targets (no tile) -> hidden per §7.
	assert_eq(items.size(), 4, "Unit Info / Assign Move / Wait / Cancel")
	for item: Node in items:
		assert_true(item is InteractiveButton and not item is MoveChipButton,
				"text actions speak the vocabulary, not hand-rolled styles")


func test_assign_submenu_builds_real_move_chips() -> void:
	var unit := _make_unit([_make_move("Ember"), _make_move("Spark", 0, 4)])
	unit.assigned_move = unit.character_data.equipped_moves[0]
	var panel := _make_panel(unit)
	panel.show_assign_submenu()
	var items := panel._content_container.get_children()
	assert_eq(items.size(), 3, "two chips + Back")

	var ember := items[0] as MoveChipButton
	assert_not_null(ember, "chips are the real component")
	assert_true(ember.assigned, "the assigned move carries the orbit")
	assert_false(ember.disabled)

	var spark := items[1] as MoveChipButton
	assert_true(spark.disabled, "depleted is GRAYED, not hidden (§7)")
	assert_eq(spark.disabled_reason, "NO USES REMAINING")

	assert_true(items[2] is InteractiveButton and not items[2] is MoveChipButton,
			"Back is a vocabulary text button")


func test_focus_is_the_menu_cursor() -> void:
	var panel := _make_panel(_make_unit([]))
	await wait_process_frames(2)  # _focus_first_item defers its grab
	var items := panel._content_container.get_children()
	assert_true((items[0] as InteractiveButton).selected,
			"the cursor opens on the first item")
	(items[2] as InteractiveButton).grab_focus()
	await wait_process_frames(1)
	assert_true((items[2] as InteractiveButton).selected, "brackets follow focus")
	assert_false((items[0] as InteractiveButton).selected,
			"exactly one cursor position")


func test_pointer_open_is_quiet_until_a_nav_press_summons_the_cursor() -> void:
	# InputSource (RQD 2026-07-29): pointer-driven opens show no phantom
	# cursor; the first directional press adopts focus onto the first item.
	InputSource.last_kind = InputSource.Kind.POINTER
	get_viewport().gui_release_focus()
	var panel := _make_panel(_make_unit([]))
	await wait_process_frames(2)
	var first := panel._content_container.get_child(0) as InteractiveButton
	assert_false(first.selected, "pointer-driven open shows no phantom cursor")
	var nav := InputEventAction.new()
	nav.action = "ui_down"
	nav.pressed = true
	panel._unhandled_input(nav)
	await wait_process_frames(2)
	assert_true(first.selected, "the first nav press summons the cursor onto item one")


func test_focused_chip_live_paints_and_text_focus_clears() -> void:
	# Grid live-paint (RQD 2026-07-30): the chip holding the menu cursor paints
	# its move's reach via GridManager; focus moving onto a text action (which
	# carries no move) lets the paint clear. Units here have no tile, so the
	# footprint is empty — the STATE seam is what's pinned; footprint math
	# lives in test_move_range_preview.gd.
	var unit := _make_unit([_make_move("Ember"), _make_move("Spark")])
	var panel := _make_panel(unit)
	panel.show_assign_submenu()
	await wait_process_frames(2)  # deferred focus grab
	assert_eq(GridManager.move_range_preview_move(), unit.character_data.equipped_moves[0],
			"cursor-driven open: the first chip's move paints immediately")
	(panel._content_container.get_child(2) as InteractiveButton).grab_focus()  # Back
	await wait_process_frames(2)  # deferred re-derive
	assert_null(GridManager.move_range_preview_move(),
			"no chip holds attention — the board clears")


func test_hover_paints_under_the_pointer_model() -> void:
	# Pointer users get the paint from hover — the same attention channel the
	# backlight answers to. Quiet open paints nothing until a chip is hovered.
	InputSource.last_kind = InputSource.Kind.POINTER
	get_viewport().gui_release_focus()
	var unit := _make_unit([_make_move("Ember")])
	var panel := _make_panel(unit)
	panel.show_assign_submenu()
	await wait_process_frames(2)
	assert_null(GridManager.move_range_preview_move(), "quiet open: no phantom paint")
	var chip := panel._content_container.get_child(0) as MoveChipButton
	chip.mouse_entered.emit()
	assert_eq(GridManager.move_range_preview_move(), chip.get_move(),
			"hover paints the chip's move")
	chip.mouse_exited.emit()
	await wait_process_frames(2)  # deferred re-derive
	assert_null(GridManager.move_range_preview_move(),
			"hover left, nothing else attends — the board clears")


func test_hiding_the_menu_clears_the_live_paint() -> void:
	var unit := _make_unit([_make_move("Ember")])
	var panel := _make_panel(unit)
	panel.show_assign_submenu()
	await wait_process_frames(2)
	assert_not_null(GridManager.move_range_preview_move(), "precondition: painted")
	panel.hide_menu()
	assert_null(GridManager.move_range_preview_move(),
			"closing the menu drops the paint synchronously")


func test_pressing_wait_still_signals_the_manager() -> void:
	var panel := _make_panel(_make_unit([]))
	watch_signals(panel)
	# BaseButton's release path is hover-gated, and injected events can't set
	# hover headless — so emit pressed directly: the contract under test is
	# the panel's wiring (pressed -> wait_selected), not engine click physics.
	(panel._content_container.get_child(2) as BaseButton).pressed.emit()
	assert_signal_emitted(panel, "wait_selected",
			"adoption must not break the manager contract")


func test_denied_press_surfaces_the_deny_tooltip() -> void:
	var unit := _make_unit([_make_move("Spark", 0, 4)])
	var panel := _make_panel(unit)
	panel.show_assign_submenu()
	var spark := panel._content_container.get_child(0) as MoveChipButton
	_press(spark)
	await wait_process_frames(2)  # DenyTooltip sizes itself a frame later
	assert_not_null(DenyTooltip._active, "press-for-why: the reason appears")
	assert_true(is_instance_valid(DenyTooltip._active))
