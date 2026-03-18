## Central state machine tracking the current InputState and active unit.
## All systems query this to determine what input/behavior is appropriate.
## Supports a lightweight state stack for overlay-style transitions (push/pop).
## Registered as Autoload "GameStateManager".
extends Node


signal state_changed(old_state: Enums.InputState, new_state: Enums.InputState)

var current_state: Enums.InputState = Enums.InputState.DEFAULT
var active_unit: Unit = null

var _on_state_exit_callback: Callable = Callable()
var _state_stack: Array = []  # Array of {state: InputState, unit: Unit}

const _MAX_STACK_DEPTH: int = 4


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


## Pushes the current state onto the stack, then transitions to the new state.
## Use for overlay-style panels (e.g. unit detail) where "back" returns here.
func push_state(new_state: Enums.InputState, context_unit: Unit = null) -> void:
	assert(_state_stack.size() < _MAX_STACK_DEPTH, "State stack overflow — likely a push without pop")
	_state_stack.push_back({state = current_state, unit = active_unit})
	DebugConfig.log_state("GameState: pushed %s onto stack (depth=%d)" % [
		Enums.InputState.keys()[current_state], _state_stack.size()])
	change_state(new_state, context_unit)


## Pops the previous state from the stack and transitions back to it.
## Falls back to DEFAULT if the stack is empty.
func pop_state() -> void:
	if _state_stack.is_empty():
		DebugConfig.log_state("GameState: pop_state with empty stack, falling back to DEFAULT")
		change_state(Enums.InputState.DEFAULT)
		return
	var entry: Dictionary = _state_stack.pop_back()
	DebugConfig.log_state("GameState: popping to %s (depth=%d)" % [
		Enums.InputState.keys()[entry.state], _state_stack.size()])
	change_state(entry.state, entry.unit)


## Clears the state stack. Call on terminal transitions (Wait, finish combat)
## where the back path is no longer valid.
func clear_state_stack() -> void:
	if not _state_stack.is_empty():
		DebugConfig.log_state("GameState: clearing stack (depth=%d)" % _state_stack.size())
		_state_stack.clear()


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
		Enums.InputState.ACTION_MENU_OPEN, Enums.InputState.UNIT_DETAIL:
			input_manager.disable_input()
		Enums.InputState.DEFAULT, Enums.InputState.UNIT_SELECTED, \
		Enums.InputState.MOVEMENT_PLANNING, Enums.InputState.ATTACK_TARGETING:
			input_manager.enable_input()
