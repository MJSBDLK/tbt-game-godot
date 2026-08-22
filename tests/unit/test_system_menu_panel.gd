## SystemMenuPanel after the border-vocabulary adoption (2026-07-19): every
## action is an InteractiveButton, End Turn dropped its magenta accent
## (magenta = SPECIAL damage now), and its CTA is wired (2026-07-29) to the
## one state that can invite it: a SPENT player phase — every unit acted,
## phase waiting. Only reachable with the auto-end-turn Options toggle off.
extends GutTest


func before_each() -> void:
	# Shared live autoload: earlier battle-flow tests can leave
	# _is_processing_phase latched, which makes is_player_phase() false and
	# would mask the CTA. Start from a clean idle player phase.
	TurnManager._is_processing_phase = false
	TurnManager.current_phase = Enums.TurnPhase.PLAYER_PHASE
	# Cursor-driven by default so the long-standing focus-on-open behavior
	# holds for every test that doesn't probe the quiet-open path.
	InputSource.last_kind = InputSource.Kind.CURSOR


func after_each() -> void:
	_set_roster([])
	InputSource.last_kind = InputSource.Kind.POINTER  # the boot default


## Roster poked directly, NOT via initialize_battle — that launches the full
## start_player_phase pipeline, whose deferred _refresh_units un-spends the
## roster on a later frame (see test_turn_manager_auto_end.gd).
func _set_roster(units: Array[Unit]) -> void:
	TurnManager._player_units = units


func _make_panel() -> SystemMenuPanel:
	var panel := SystemMenuPanel.new()
	add_child_autofree(panel)
	panel.show_menu()
	return panel


func _make_unit(acted: bool) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.character_data = CharacterData.new()
	unit.current_hp = 1  # bare units default to 0 HP = defeated
	unit.can_act = not acted
	return unit


func test_every_action_is_a_vocabulary_button() -> void:
	var panel := _make_panel()
	var buttons: Array[InteractiveButton] = []
	for child: Node in panel._content_container.get_children():
		if child is InteractiveButton:
			buttons.append(child)
	assert_eq(buttons.size(), 7, "End Turn + Close/Options/Save/Load/Main Menu/Quit")
	var end_turn := buttons[0]
	assert_eq(end_turn.text, "END TURN")
	assert_false(end_turn.call_to_action,
			"empty roster guard: no battle, no invitation")


func test_close_leads_the_list_right_under_end_turn() -> void:
	# RQD 2026-08-21: Close moved from the bottom to the top — the peek-and-
	# leave case is the common one, and it's the safe landing for the cursor.
	var panel := _make_panel()
	var buttons: Array[InteractiveButton] = []
	for child: Node in panel._content_container.get_children():
		if child is InteractiveButton:
			buttons.append(child)
	assert_eq(buttons[0].text, "END TURN")
	assert_eq(buttons[1].text, "Close", "Close is the first item under End Turn")
	assert_eq(buttons[2].text, "Options", "…and Options follows it")
	assert_eq(buttons[-1].text, "Quit", "Quit stays last")


func test_focus_cursor_opens_on_close_not_end_turn() -> void:
	# A default on End Turn meant controller A-A ended the turn by accident.
	var panel := _make_panel()
	await wait_process_frames(2)
	var end_turn := panel._content_container.get_child(0) as InteractiveButton
	assert_false(end_turn.selected, "cursor-driven open does NOT land on End Turn")
	assert_true(panel._close_button.selected, "cursor-driven open: the cursor starts on Close")
	assert_eq(get_viewport().gui_get_focus_owner(), panel._close_button)


func test_close_button_closes_the_menu() -> void:
	var panel := _make_panel()
	watch_signals(panel)
	panel._close_button.pressed.emit()
	assert_signal_emitted(panel, "closed")
	assert_false(panel.visible)


func test_pointer_open_is_quiet_until_a_nav_press_summons_the_cursor() -> void:
	# InputSource (RQD 2026-07-29): default selection is a cursor-model
	# courtesy — under pointer input the menu opens with no phantom cursor,
	# and the first directional press adopts focus onto the first item.
	InputSource.last_kind = InputSource.Kind.POINTER
	get_viewport().gui_release_focus()
	var panel := _make_panel()
	await wait_process_frames(2)
	var landing := panel._close_button
	assert_false(landing.selected, "pointer-driven open shows no phantom cursor")
	assert_null(get_viewport().gui_get_focus_owner(), "nothing holds focus on quiet open")
	var nav := InputEventAction.new()
	nav.action = "ui_down"
	nav.pressed = true
	panel._unhandled_input(nav)
	await wait_process_frames(2)
	assert_true(landing.selected, "the first nav press summons the cursor onto Close")


func test_pointer_click_on_a_stay_open_item_leaves_no_phantom_cursor() -> void:
	# Regression (RQD 2026-08-01): Godot natively focuses a clicked button, so
	# pressing Save — the first item that KEEPS the menu open — hung the §14
	# brackets on it under mouse control. Pointer presses must clean up the
	# click-focus; cursor presses keep their "you are here."
	InputSource.last_kind = InputSource.Kind.POINTER
	get_viewport().gui_release_focus()
	var panel := _make_panel()
	await wait_process_frames(2)
	var save_button := panel._save_button
	assert_not_null(save_button, "panel exposes its Save row")
	save_button.grab_focus()  # what a mouse click does natively, pre-pressed
	save_button.pressed.emit()
	await wait_process_frames(1)
	assert_false(save_button.selected, "no brackets after a pointer press")
	assert_false(save_button.has_focus(), "click-focus is released under pointer")

	# Same press under the cursor model keeps the cursor parked on the item.
	InputSource.last_kind = InputSource.Kind.CURSOR
	save_button.grab_focus()
	save_button.pressed.emit()
	await wait_process_frames(1)
	assert_true(save_button.selected, "cursor-model press keeps the brackets")
	assert_true(save_button.has_focus(), "cursor-model press keeps focus")


func test_end_turn_wears_the_cta_only_when_the_phase_is_spent() -> void:
	_set_roster([_make_unit(true)])
	var panel := _make_panel()
	var end_turn := panel._content_container.get_child(0) as InteractiveButton
	assert_true(end_turn.call_to_action,
			"spent phase (all units acted, waiting) invites the press")
	panel.hide_menu()

	_set_roster([_make_unit(false)])
	panel.show_menu()
	end_turn = panel._content_container.get_child(0) as InteractiveButton
	assert_false(end_turn.call_to_action,
			"a unit can still act — End Turn stays a plain lit button")


func test_end_turn_still_signals_the_manager() -> void:
	var panel := _make_panel()
	watch_signals(panel)
	(panel._content_container.get_child(0) as BaseButton).pressed.emit()
	assert_signal_emitted(panel, "end_turn_selected")


func test_main_menu_sits_beside_quit_and_signals() -> void:
	# RQD 2026-08-16: a way out of a battle that isn't closing the game.
	var panel := _make_panel()
	var buttons: Array[InteractiveButton] = []
	for child: Node in panel._content_container.get_children():
		if child is InteractiveButton:
			buttons.append(child)
	var main_menu_index: int = -1
	for i: int in buttons.size():
		if buttons[i].text == "Main Menu":
			main_menu_index = i
	assert_ne(main_menu_index, -1, "the entry exists")
	assert_eq(buttons[main_menu_index + 1].text, "Quit", "…right before Quit")
	watch_signals(panel)
	buttons[main_menu_index].pressed.emit()
	assert_signal_emitted(panel, "main_menu_selected")
