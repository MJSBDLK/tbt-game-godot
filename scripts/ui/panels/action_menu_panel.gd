## Scene-based action menu panel for the right side.
## Dynamically creates buttons for attack moves, Assign Move, Wait, Cancel.
## Signals back to ActionMenuManager for business logic.
class_name ActionMenuPanel
extends PanelContainer


signal move_selected(move: Move)
signal wait_selected()
signal cancel_selected()
signal assign_submenu_requested()
signal assign_move_selected(move: Move)
signal unit_info_requested()

const BUTTON_HEIGHT: int = 20
const BUTTON_WIDTH: int = 120

var _button_container: VBoxContainer = null
var _is_assign_submenu: bool = false
var _active_unit: Unit = null


func _ready() -> void:
	custom_minimum_size = Vector2(140, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null:
		var border: Variant = ui_manager.create_action_menu_border()
		if border != null:
			add_theme_stylebox_override("panel", border)
		else:
			add_theme_stylebox_override("panel", ui_manager.create_menu_style())

	_button_container = VBoxContainer.new()
	_button_container.add_theme_constant_override("separation", 2)
	add_child(_button_container)

	visible = false


# =============================================================================
# PUBLIC API
# =============================================================================

func show_menu(unit: Unit) -> void:
	if unit == null:
		return
	_active_unit = unit
	_is_assign_submenu = false
	_populate_main_menu(unit)
	visible = true


func hide_menu() -> void:
	visible = false
	_clear_buttons()
	_active_unit = null


func get_active_unit() -> Unit:
	return _active_unit


func is_assign_submenu() -> bool:
	return _is_assign_submenu


func show_assign_submenu() -> void:
	if _active_unit != null:
		_populate_assign_submenu(_active_unit)


func show_main_menu() -> void:
	if _active_unit != null:
		_is_assign_submenu = false
		_populate_main_menu(_active_unit)


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
			_create_button(button_text, func() -> void: move_selected.emit(captured_move))

	# Unit info
	_create_button("Unit Info", func() -> void: unit_info_requested.emit())

	# Assign move
	_create_button("Assign Move", func() -> void: assign_submenu_requested.emit())

	# Wait
	_create_button("Wait", func() -> void: wait_selected.emit())

	# Cancel (snap back)
	_create_button("Cancel", func() -> void: cancel_selected.emit())

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
		_create_button(button_text, func() -> void: assign_move_selected.emit(captured_move))

	_create_button("Back", func() -> void:
		_is_assign_submenu = false
		_populate_main_menu(unit))

	_resize_panel()


# =============================================================================
# BUTTON BUILDING
# =============================================================================

func _create_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
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
	# Let the VBoxContainer auto-size; just ensure minimum
	await get_tree().process_frame
	var button_count := _button_container.get_child_count()
	var total_height := button_count * (BUTTON_HEIGHT + 2) + 8  # margins
	custom_minimum_size.y = total_height


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
