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


func after_each() -> void:
	_set_roster([])


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
	assert_eq(buttons.size(), 6, "End Turn + Options/Save/Load/Quit/Close")
	var end_turn := buttons[0]
	assert_eq(end_turn.text, "END TURN")
	assert_false(end_turn.call_to_action,
			"empty roster guard: no battle, no invitation")


func test_focus_cursor_opens_on_end_turn() -> void:
	var panel := _make_panel()
	await wait_process_frames(2)
	var first := panel._content_container.get_child(0) as InteractiveButton
	assert_true(first.selected, "the cursor opens on the first item")


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
