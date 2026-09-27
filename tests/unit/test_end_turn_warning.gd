## The End Turn warning: End Turn with units that
## can still act asks first — the system menu becomes "N units haven't
## acted." over End Turn / Cancel — and those units flash their outline
## (SilhouetteCallToAction). Every End Turn press lands on
## UIManager.request_end_turn: the E key / hint bar and the menu's button.
##
## TurnManager._battle_ended is latched for each test so a real end of turn
## marks the roster acted and stops there, instead of launching the enemy
## phase on the live autoloads.
extends GutTest


var _battle_ended_before: bool = false
var _warning_before: bool = true


func before_each() -> void:
	_battle_ended_before = TurnManager._battle_ended
	_warning_before = Settings.end_turn_warning
	TurnManager._battle_ended = true
	TurnManager._is_processing_phase = false
	TurnManager.current_phase = Enums.TurnPhase.PLAYER_PHASE
	Settings.end_turn_warning = true
	GameStateManager.clear_state_stack()
	GameStateManager.change_state(Enums.InputState.DEFAULT)


func after_each() -> void:
	UIManager.hide_system_menu()
	TurnManager._player_units = []
	TurnManager._battle_ended = _battle_ended_before
	Settings.end_turn_warning = _warning_before
	GameStateManager.clear_state_stack()
	GameStateManager.change_state(Enums.InputState.DEFAULT)


## A bare unit with a readable sprite, so the outline flash has art to trace.
func _make_unit(acted: bool) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.character_data = CharacterData.new()
	unit.current_hp = 1  # bare units default to 0 HP = defeated
	unit.can_act = not acted
	var art := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	art.fill_rect(Rect2i(1, 1, 2, 2), Color.WHITE)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = ImageTexture.create_from_image(art)
	unit.add_child(sprite)
	return unit


func _roster(units: Array[Unit]) -> void:
	TurnManager._player_units = units


func _menu() -> SystemMenuPanel:
	return UIManager._system_menu_panel


func _buttons() -> Array[InteractiveButton]:
	var buttons: Array[InteractiveButton] = []
	for child: Node in _menu()._content_container.get_children():
		if child is InteractiveButton:
			buttons.append(child)
	return buttons


func _message() -> String:
	for child: Node in _menu()._content_container.get_children():
		if child is Label:
			return (child as Label).text
	return ""


func test_a_waiting_unit_turns_end_turn_into_a_question() -> void:
	var waiting := _make_unit(false)
	_roster([waiting, _make_unit(true)])
	UIManager.request_end_turn()
	assert_true(_menu().visible, "the confirm is up")
	assert_true(_menu()._confirming_end_turn)
	assert_eq(_message(), "1 unit hasn't acted.")
	assert_eq(GameStateManager.current_state, Enums.InputState.PAUSED, "the board is paused under it")
	assert_true(waiting.can_act, "nothing ended yet")
	assert_eq(_buttons().size(), 2, "End Turn and Cancel")
	assert_eq(_menu()._close_button.text, "Cancel", "Cancel is the landing — a mashed A keeps the turn")


func test_the_waiting_units_flash_their_outline() -> void:
	var first := _make_unit(false)
	var second := _make_unit(false)
	var spent := _make_unit(true)
	_roster([first, second, spent])
	UIManager.request_end_turn()
	assert_eq(_message(), "2 units haven't acted.")
	for unit: Unit in [first, second]:
		assert_true(_flashing(unit), "%s is pointed out" % unit)
	assert_false(_flashing(spent), "a unit that acted is not")


## A live flash on the unit — one queued for deletion has been stopped.
func _flashing(unit: Unit) -> bool:
	var flash: Node = unit.get_node("Sprite2D").get_node_or_null(SilhouetteCallToAction.NODE_NAME)
	return flash != null and not flash.is_queued_for_deletion()


# The flashes repeat until the player backs out or commits to ending the
# turn — every way off the question stops them.

func test_confirming_stops_the_flashes() -> void:
	var waiting := _make_unit(false)
	_roster([waiting])
	UIManager.request_end_turn()
	_buttons()[0].pressed.emit()
	assert_false(_flashing(waiting))


func test_backing_out_to_the_board_stops_the_flashes() -> void:
	var waiting := _make_unit(false)
	_roster([waiting])
	UIManager.request_end_turn()
	_menu()._close_button.pressed.emit()
	assert_false(_flashing(waiting))


func test_backing_out_to_the_menu_stops_the_flashes() -> void:
	var waiting := _make_unit(false)
	_roster([waiting])
	GameStateManager.push_state(Enums.InputState.PAUSED)
	UIManager.show_system_menu()
	_menu().end_turn_selected.emit()
	assert_true(_flashing(waiting))
	_menu()._close_button.pressed.emit()  # Cancel, back to the list
	assert_true(_menu().visible, "on the menu list")
	assert_false(_flashing(waiting), "the question is gone, so are the flashes")


func test_the_state_machine_taking_the_menu_down_stops_the_flashes() -> void:
	var waiting := _make_unit(false)
	_roster([waiting])
	UIManager.request_end_turn()
	# A phase start under the menu goes straight to DEFAULT (turn_manager.gd).
	GameStateManager.change_state(Enums.InputState.DEFAULT)
	assert_false(_menu().visible)
	assert_false(_flashing(waiting))


func test_confirming_ends_the_turn() -> void:
	var waiting := _make_unit(false)
	_roster([waiting])
	UIManager.request_end_turn()
	_buttons()[0].pressed.emit()
	assert_false(waiting.can_act, "the turn ended — the roster is spent")
	assert_false(_menu().visible)
	assert_eq(GameStateManager.current_state, Enums.InputState.DEFAULT, "the pause came off")


func test_cancel_from_the_board_goes_back_to_the_board() -> void:
	var waiting := _make_unit(false)
	_roster([waiting])
	UIManager.request_end_turn()  # the E key / hint bar path
	_menu()._close_button.pressed.emit()
	assert_false(_menu().visible)
	assert_eq(GameStateManager.current_state, Enums.InputState.DEFAULT)
	assert_true(waiting.can_act, "the turn goes on")


func test_cancel_from_the_menu_goes_back_to_the_menu() -> void:
	_roster([_make_unit(false)])
	GameStateManager.push_state(Enums.InputState.PAUSED)
	UIManager.show_system_menu()
	_menu().end_turn_selected.emit()  # the menu's END TURN
	assert_true(_menu()._confirming_end_turn)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	_menu()._unhandled_input(cancel)
	assert_true(_menu().visible, "back on the menu list")
	assert_false(_menu()._confirming_end_turn)
	assert_eq(_buttons()[0].text, "END TURN")
	assert_eq(GameStateManager.current_state, Enums.InputState.PAUSED, "still paused on the menu")


func test_no_warning_when_everyone_has_acted() -> void:
	var spent := _make_unit(true)
	_roster([spent])
	UIManager.request_end_turn()
	assert_false(_menu().visible, "nothing to warn about — the turn just ends")


func test_the_setting_turns_the_warning_off() -> void:
	Settings.end_turn_warning = false
	var waiting := _make_unit(false)
	_roster([waiting])
	UIManager.request_end_turn()
	assert_false(_menu().visible)
	assert_false(waiting.can_act, "ended at once")


func test_nothing_happens_outside_the_player_phase() -> void:
	var waiting := _make_unit(false)
	_roster([waiting])
	TurnManager.current_phase = Enums.TurnPhase.ENEMY_PHASE
	UIManager.request_end_turn()
	assert_false(_menu().visible)
	assert_true(waiting.can_act)
