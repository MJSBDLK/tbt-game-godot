## Central state machine tracking the current InputState and active unit.
## All systems query this to determine what input/behavior is appropriate.
## Registered as Autoload "GameStateManager".
extends Node


signal state_changed(old_state: Enums.InputState, new_state: Enums.InputState)

var current_state: Enums.InputState = Enums.InputState.DEFAULT
var active_unit: Unit = null

var _on_state_exit_callback: Callable = Callable()


func change_state(new_state: Enums.InputState, context_unit: Unit = null) -> void:
	var old_state := current_state
	_exit_state(old_state)
	current_state = new_state
	active_unit = context_unit
	_enter_state(new_state)
	DebugConfig.log_state("GameState: %s → %s (unit=%s)" % [
		Enums.InputState.keys()[old_state],
		Enums.InputState.keys()[new_state],
		context_unit.unit_name if context_unit != null else "none"])
	state_changed.emit(old_state, new_state)


func is_state(state: Enums.InputState) -> bool:
	return current_state == state


func set_on_exit_callback(callback: Callable) -> void:
	_on_state_exit_callback = callback


func _exit_state(state: Enums.InputState) -> void:
	if _on_state_exit_callback.is_valid():
		_on_state_exit_callback.call()
		_on_state_exit_callback = Callable()

	match state:
		Enums.InputState.ATTACK_TARGETING:
			GridManager.clear_attack_range()


func _enter_state(state: Enums.InputState) -> void:
	var input_manager: Node = get_node_or_null("/root/InputManager")
	if input_manager == null:
		return

	match state:
		Enums.InputState.ACTION_MENU_OPEN:
			input_manager.disable_input()
		Enums.InputState.DEFAULT, Enums.InputState.ATTACK_TARGETING:
			input_manager.enable_input()
