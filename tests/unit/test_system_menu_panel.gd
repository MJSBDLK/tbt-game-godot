## SystemMenuPanel after the border-vocabulary adoption (2026-07-19): every
## action is an InteractiveButton, End Turn dropped its magenta accent
## (magenta = SPECIAL damage now), and its CTA stays deliberately unwired —
## TurnManager auto-ends the phase when all units have acted, so that
## condition can never light the button.
extends GutTest


func _make_panel() -> SystemMenuPanel:
	var panel := SystemMenuPanel.new()
	add_child_autofree(panel)
	panel.show_menu()
	return panel


func test_every_action_is_a_vocabulary_button() -> void:
	var panel := _make_panel()
	var buttons: Array[InteractiveButton] = []
	for child: Node in panel._content_container.get_children():
		if child is InteractiveButton:
			buttons.append(child)
	assert_eq(buttons.size(), 6, "End Turn + Options/Save/Load/Quit/Close")
	var end_turn := buttons[0]
	assert_eq(end_turn.text, "END TURN")
	assert_false(end_turn.call_to_action,
			"CTA unwired on purpose: auto-end means 'all acted' never occurs")


func test_focus_cursor_opens_on_end_turn() -> void:
	var panel := _make_panel()
	await wait_process_frames(2)
	var first := panel._content_container.get_child(0) as InteractiveButton
	assert_true(first.selected, "the cursor opens on the first item")


func test_end_turn_still_signals_the_manager() -> void:
	var panel := _make_panel()
	watch_signals(panel)
	(panel._content_container.get_child(0) as BaseButton).pressed.emit()
	assert_signal_emitted(panel, "end_turn_selected")
