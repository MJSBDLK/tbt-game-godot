## UIManager's overlay panels live in a CanvasLayer that outlives every scene.
## The save browser (Load, or the overwrite picker) opens FROM the system
## menu; when something else ends the pause underneath it — the player phase
## starting, a cancel clearing the stack — the menu is hidden by the state
## handler but the browser was not, and it rode into the intermission hub as
## a picker nobody opened (RQD's screenshot, 2026-09-22).
extends GutTest


func before_each() -> void:
	GameStateManager.clear_state_stack()
	GameStateManager.change_state(Enums.InputState.DEFAULT)


func after_each() -> void:
	UIManager.hide_save_browser()
	UIManager.hide_system_menu()
	GameStateManager.clear_state_stack()
	GameStateManager.change_state(Enums.InputState.DEFAULT)


func _open_browser_from_the_menu(overwrite: bool) -> void:
	GameStateManager.push_state(Enums.InputState.PAUSED)
	UIManager.show_system_menu()
	if overwrite:
		UIManager._save_browser_panel.show_overwrite_picker()
		UIManager._system_menu_panel.visible = false  # what _on_system_menu_save does
	else:
		UIManager._on_system_menu_load()
	assert_true(UIManager._save_browser_panel.visible, "the browser is up")
	assert_false(UIManager._system_menu_panel.visible, "over a hidden menu")


func test_the_player_phase_starting_takes_the_picker_down_with_the_menu() -> void:
	_open_browser_from_the_menu(true)
	# turn_manager.gd's phase start: straight to DEFAULT, no pop.
	GameStateManager.change_state(Enums.InputState.DEFAULT)
	assert_false(UIManager._system_menu_panel.visible)
	assert_false(UIManager._save_browser_panel.visible,
			"an orphaned picker would ride the overlay into the hub")


func test_a_cleared_stack_takes_the_load_browser_down_too() -> void:
	_open_browser_from_the_menu(false)
	GameStateManager.clear_state_stack()
	GameStateManager.change_state(Enums.InputState.DEFAULT)
	assert_false(UIManager._save_browser_panel.visible)


func test_the_browsers_own_close_still_brings_the_menu_back() -> void:
	# The intended path is untouched: cancelling the browser while still
	# PAUSED resurrects the system menu it was opened from.
	_open_browser_from_the_menu(true)
	UIManager._save_browser_panel.hide_panel()
	assert_false(UIManager._save_browser_panel.visible)
	assert_true(UIManager._system_menu_panel.visible, "closed → the menu returns")
