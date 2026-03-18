## Orchestrates the action menu: state transitions, move selection, cancel/wait.
## Delegates visual rendering to ActionMenuPanel via UIManager.
## Registered as Autoload "ActionMenuManager".
extends Node


signal action_menu_opened(unit: Unit)
signal action_menu_closed()

var _active_unit: Unit = null
var _selected_move_for_attack: Move = null
var _is_visible: bool = false
var _panel_connected: bool = false


# =============================================================================
# PUBLIC API
# =============================================================================

func show_action_menu(unit: Unit) -> void:
	if unit == null:
		return
	_active_unit = unit

	var input_manager: Node = get_node_or_null("/root/InputManager")
	if input_manager != null:
		input_manager.disable_input()

	var state_manager: Node = get_node("/root/GameStateManager")
	state_manager.change_state(Enums.InputState.ACTION_MENU_OPEN, unit)

	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null:
		_connect_panel_signals(ui_manager)
		ui_manager.show_action_menu(unit)

	_is_visible = true
	action_menu_opened.emit(unit)
	DebugConfig.log_action_menu("ActionMenu: Opened for '%s'" % unit.unit_name)


func hide_action_menu() -> void:
	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null:
		ui_manager.hide_action_menu()

	_is_visible = false
	action_menu_closed.emit()


func get_selected_move_for_attack() -> Move:
	return _selected_move_for_attack


func clear_selected_move() -> void:
	_selected_move_for_attack = null


# =============================================================================
# INPUT HANDLING (escape while menu is open)
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not _is_visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("unit_info"):
		_on_unit_info_requested()
		get_viewport().set_input_as_handled()


# =============================================================================
# PANEL SIGNAL CONNECTIONS
# =============================================================================

func _connect_panel_signals(ui_manager: Node) -> void:
	if _panel_connected:
		return
	var panel: Node = ui_manager.get_action_menu_panel()
	if panel == null:
		return

	panel.move_selected.connect(_on_move_selected)
	panel.wait_selected.connect(_on_wait)
	panel.cancel_selected.connect(_on_cancel)
	panel.assign_submenu_requested.connect(_on_assign_submenu)
	panel.assign_move_selected.connect(_on_assign_move_selected)
	panel.unit_info_requested.connect(_on_unit_info_requested)
	_panel_connected = true


# =============================================================================
# CALLBACKS
# =============================================================================

func _on_move_selected(move: Move) -> void:
	if _active_unit == null:
		return
	_selected_move_for_attack = move
	_active_unit.assign_move(move)
	hide_action_menu()

	var input_manager: Node = get_node("/root/InputManager")
	input_manager.enable_input()
	input_manager.start_attack_targeting(_active_unit, move)

	DebugConfig.log_action_menu("ActionMenu: Move '%s' selected for attack" % move.move_name)


func _on_assign_submenu() -> void:
	if _active_unit == null:
		return
	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null:
		var panel: Node = ui_manager.get_action_menu_panel()
		if panel != null and panel.has_method("show_assign_submenu"):
			panel.show_assign_submenu()


func _on_assign_move_selected(move: Move) -> void:
	if _active_unit == null:
		return
	_active_unit.assign_move(move)
	DebugConfig.log_action_menu("ActionMenu: Assigned '%s' to '%s'" % [move.move_name, _active_unit.unit_name])

	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null:
		ui_manager.refresh()
		var panel: Node = ui_manager.get_action_menu_panel()
		if panel != null and panel.has_method("show_main_menu"):
			panel.show_main_menu()


func _on_unit_info_requested() -> void:
	if _active_unit == null:
		return
	hide_action_menu()
	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null:
		ui_manager.show_unit_detail(_active_unit)
	DebugConfig.log_action_menu("ActionMenu: Unit Info requested for '%s'" % _active_unit.unit_name)


func _on_wait() -> void:
	if _active_unit == null:
		return
	var unit := _active_unit
	hide_action_menu()

	unit.set_acted()
	unit.set_selected(false)
	GridManager.clear_movement_range()
	GridManager.clear_selected_tile()

	var input_manager: Node = get_node("/root/InputManager")
	input_manager.enable_input()
	input_manager.deselect_unit()

	var state_manager: Node = get_node("/root/GameStateManager")
	state_manager.change_state(Enums.InputState.DEFAULT)

	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null:
		ui_manager.hide_unit_info()

	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager != null:
		turn_manager.check_end_player_turn()

	DebugConfig.log_action_menu("ActionMenu: '%s' chose Wait" % unit.unit_name)


func _on_cancel() -> void:
	if _active_unit == null:
		return
	var unit := _active_unit

	# If in assign submenu, go back to main menu
	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null:
		var panel: Node = ui_manager.get_action_menu_panel()
		if panel != null and panel.has_method("is_assign_submenu") and panel.is_assign_submenu():
			panel.show_main_menu()
			return

	hide_action_menu()

	# Snap back to pre-movement position
	unit.cancel_movement()

	var input_manager: Node = get_node("/root/InputManager")
	input_manager.enable_input()
	input_manager.select_unit(unit)

	DebugConfig.log_action_menu("ActionMenu: '%s' cancelled, snapping back" % unit.unit_name)
