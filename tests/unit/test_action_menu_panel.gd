## ActionMenuPanel after the border-vocabulary adoption (Lawrence-accepted
## 2026-07-19, "cramped but organized"). The contract pinned here: move chips
## are real MoveChipButtons, text actions are InteractiveButtons, the §7
## gameplay rules hold (out-of-range HIDDEN, depleted GRAYED with a deny),
## and focus is the menu cursor — brackets follow it.
extends GutTest


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
	assert_true(ember.assigned, "the assigned move carries the bone orbit")
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
