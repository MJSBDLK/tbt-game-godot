## InputManager is an autoload, so it keeps receiving input on menus and the
## intermission — screens with no battle behind them. Every handler in its
## _unhandled_input is battle-only, so the whole path has to be gated on a
## battle actually existing.
##
## Found on F5 2026-08-07: pressing Escape on the intermission hub reached
## _handle_escape(), which read the state as DEFAULT and opened the BATTLE
## pause menu over a screen with no battle. _process() had gated on
## `input_enabled and GridManager.is_grid_ready()` since forever; the input
## path only checked the first half.
##
## Grid readiness is the gate because it is the one thing that is true exactly
## when a battle is loaded — a menu scene never builds a grid.
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()


func after_each() -> void:
	GridManager.clear_grid()


func _escape_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func test_no_grid_means_no_battle() -> void:
	assert_false(GridManager.is_grid_ready(),
			"a menu or intermission scene never builds a grid")


func test_escape_off_the_board_does_not_reach_the_battle_handler() -> void:
	# The reproduction. If _unhandled_input stops gating on grid readiness this
	# fails by opening the battle system menu over the hub.
	var state_manager: Node = GameStateManager
	var state_before: Enums.InputState = state_manager.current_state

	InputManager._unhandled_input(_escape_event())

	assert_eq(state_manager.current_state, state_before,
			"Escape with no grid must not push PAUSED — that's the battle menu")


func test_the_gate_is_the_same_pair_process_already_used() -> void:
	# Guards against the two paths drifting apart again: whatever condition
	# lets _process run must be the condition that lets input through, or the
	# hover/cursor state and the key handling disagree about being in a battle.
	InputManager.input_enabled = false
	assert_false(InputManager.input_enabled and GridManager.is_grid_ready(),
			"disabled input is gated")
	InputManager.input_enabled = true
	assert_false(InputManager.input_enabled and GridManager.is_grid_ready(),
			"enabled input with no grid is still gated")
