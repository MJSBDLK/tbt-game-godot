## Code-built action menu displayed after unit movement.
## Shows available attack moves, Assign Move, Wait, and Cancel options.
## Dev-quality UI — will be replaced by the full UI system in Phase 5.
## Registered as Autoload "ActionMenuManager".
extends Node


signal action_menu_opened(unit: Unit)
signal action_menu_closed()

const MENU_WIDTH: int = 130
const BUTTON_HEIGHT: int = 16
const BUTTON_FONT_SIZE: int = 7
const MENU_MARGIN: int = 4

var _active_unit: Unit = null
var _selected_move_for_attack: Move = null
var _menu_layer: CanvasLayer = null
var _menu_panel: PanelContainer = null
var _button_container: VBoxContainer = null
var _is_visible: bool = false
var _is_assign_submenu: bool = false


func _ready() -> void:
	_build_menu_ui()


# =============================================================================
# PUBLIC API
# =============================================================================

func show_action_menu(unit: Unit) -> void:
	if unit == null:
		return
	_active_unit = unit
	_is_assign_submenu = false

	var input_manager: Node = get_node_or_null("/root/InputManager")
	if input_manager != null:
		input_manager.disable_input()

	var state_manager: Node = get_node("/root/GameStateManager")
	state_manager.change_state(Enums.InputState.ACTION_MENU_OPEN, unit)

	_populate_main_menu(unit)
	_menu_panel.visible = true
	_is_visible = true
	action_menu_opened.emit(unit)
	DebugConfig.log_action_menu("ActionMenu: Opened for '%s'" % unit.unit_name)


func hide_action_menu() -> void:
	_menu_panel.visible = false
	_is_visible = false
	_clear_buttons()
	action_menu_closed.emit()


func get_selected_move_for_attack() -> Move:
	return _selected_move_for_attack


func clear_selected_move() -> void:
	_selected_move_for_attack = null


# =============================================================================
# INPUT HANDLING (menu handles its own input while open)
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not _is_visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()


# =============================================================================
# MENU POPULATION
# =============================================================================

func _populate_main_menu(unit: Unit) -> void:
	_clear_buttons()

	# Attack moves with valid targets
	var usable_moves := unit.get_usable_moves()
	for move: Move in usable_moves:
		var valid_targets := _get_valid_targets_for_move(unit, move)
		if valid_targets.size() > 0:
			var is_assigned := (unit.assigned_move == move)
			var prefix := "> " if is_assigned else ""
			var button_text := "%s%s (%d/%d)" % [prefix, move.move_name, move.current_uses, move.max_uses]
			var captured_move := move
			_create_button(button_text, func() -> void: _on_move_selected(captured_move))

	# Assign move
	_create_button("Assign Move", _on_assign_move)

	# Wait
	_create_button("Wait", _on_wait)

	# Cancel (snap back)
	_create_button("Cancel", _on_cancel)

	_resize_panel()


func _populate_assign_submenu(unit: Unit) -> void:
	_clear_buttons()
	_is_assign_submenu = true

	var usable_moves := unit.get_usable_moves()
	for move: Move in usable_moves:
		var is_assigned := (unit.assigned_move == move)
		var prefix := "> " if is_assigned else ""
		var button_text := "%s%s (%d/%d)" % [prefix, move.move_name, move.current_uses, move.max_uses]
		var captured_move := move
		_create_button(button_text, func() -> void: _on_assign_move_selected(captured_move))

	_create_button("Back", func() -> void: _populate_main_menu(unit))
	_resize_panel()


# =============================================================================
# BUTTON CALLBACKS
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


func _on_assign_move() -> void:
	if _active_unit == null:
		return
	_populate_assign_submenu(_active_unit)


func _on_assign_move_selected(move: Move) -> void:
	if _active_unit == null:
		return
	_active_unit.assign_move(move)
	DebugConfig.log_action_menu("ActionMenu: Assigned '%s' to '%s'" % [move.move_name, _active_unit.unit_name])

	# Refresh the HUD to show the new assignment
	var battle_hud: Node = _get_battle_hud()
	if battle_hud != null:
		battle_hud.update_move_list(_active_unit)
		battle_hud.refresh()

	_populate_main_menu(_active_unit)


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

	var battle_hud: Node = _get_battle_hud()
	if battle_hud != null:
		battle_hud.hide_unit_info()

	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager != null:
		turn_manager.check_end_player_turn()

	DebugConfig.log_action_menu("ActionMenu: '%s' chose Wait" % unit.unit_name)


func _on_cancel() -> void:
	if _active_unit == null:
		return
	var unit := _active_unit
	hide_action_menu()

	# If in assign submenu, go back to main menu
	if _is_assign_submenu:
		_is_assign_submenu = false
		show_action_menu(unit)
		return

	# Snap back to pre-movement position
	unit.cancel_movement()

	var input_manager: Node = get_node("/root/InputManager")
	input_manager.enable_input()
	input_manager.select_unit(unit)

	DebugConfig.log_action_menu("ActionMenu: '%s' cancelled, snapping back" % unit.unit_name)


# =============================================================================
# UI BUILDING
# =============================================================================

func _build_menu_ui() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 10
	add_child(_menu_layer)

	_menu_panel = PanelContainer.new()
	_menu_panel.position = Vector2(640 - MENU_WIDTH - 4, 4)
	_menu_panel.size = Vector2(MENU_WIDTH, 100)
	_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.MENU_BACKGROUND
	style.border_color = GameColors.MENU_BORDER
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.content_margin_left = MENU_MARGIN
	style.content_margin_right = MENU_MARGIN
	style.content_margin_top = MENU_MARGIN
	style.content_margin_bottom = MENU_MARGIN
	_menu_panel.add_theme_stylebox_override("panel", style)
	_menu_layer.add_child(_menu_panel)

	_button_container = VBoxContainer.new()
	_button_container.add_theme_constant_override("separation", 2)
	_menu_panel.add_child(_button_container)

	_menu_panel.visible = false


func _create_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(MENU_WIDTH - MENU_MARGIN * 2, BUTTON_HEIGHT)
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(callback)
	_button_container.add_child(button)
	return button


func _clear_buttons() -> void:
	if _button_container == null:
		return
	for child: Node in _button_container.get_children():
		child.queue_free()


func _resize_panel() -> void:
	var button_count := _button_container.get_child_count()
	var total_height := button_count * (BUTTON_HEIGHT + 2) + MENU_MARGIN * 2
	_menu_panel.size = Vector2(MENU_WIDTH, total_height)


# =============================================================================
# HELPERS
# =============================================================================

func _get_valid_targets_for_move(unit: Unit, move: Move) -> Array[Tile]:
	var tiles: Array[Tile] = []
	if unit == null or move == null or unit.current_tile == null:
		return tiles
	var all_tiles := GridManager.get_tiles_within_range(unit.current_tile, move.attack_range)
	for tile: Tile in all_tiles:
		if tile.current_unit != null and tile.current_unit is Unit:
			var target := tile.current_unit as Unit
			if target.faction != unit.faction and not target.is_defeated():
				tiles.append(tile)
	return tiles


func _get_battle_hud() -> Node:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("get_battle_hud"):
		return scene.call("get_battle_hud")
	return null
