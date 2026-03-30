## Scene-based action menu panel for the right side.
## Dynamically creates move chips for attack moves, plus text buttons for
## Unit Info, Assign Move, Wait, Cancel.
## Signals back to ActionMenuManager for business logic.
class_name ActionMenuPanel
extends PanelContainer


signal move_selected(move: Move)
signal wait_selected()
signal cancel_selected()
signal assign_submenu_requested()
signal assign_move_selected(move: Move)
signal unit_info_requested()

const GLOW_MATERIAL: ShaderMaterial = preload("res://resources/hud_glow.tres")
const MOVE_CHIP_MATERIAL: ShaderMaterial = preload("res://resources/move_chip_fill.tres")

const BUTTON_HEIGHT: int = 14
const BUTTON_WIDTH: int = 120
const CHIP_HEIGHT: int = 14

var _content_container: VBoxContainer = null
var _is_assign_submenu: bool = false
var _active_unit: Unit = null
var _border_overlay: PanelBorderOverlay = null
var _button_style_normal: StyleBoxFlat = null
var _button_style_hovered: StyleBoxFlat = null
var _button_style_pressed: StyleBoxFlat = null
var _button_style_focus: StyleBoxFlat = null


func _ready() -> void:
	custom_minimum_size = Vector2(140, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Panel background — dark HUD style, no content margins so border overlay
	# draws at the panel edge (content is inset via MarginContainer instead).
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = GameColors.HUD_PANEL_BACKGROUND
	add_theme_stylebox_override("panel", panel_style)

	# Pre-build button styles — 1px gray border, corner_radius 2.
	_button_style_normal = _create_button_style(GameColors.ACTION_BUTTON_BG_NORMAL)
	_button_style_hovered = _create_button_style(GameColors.ACTION_BUTTON_BG_HOVERED)
	_button_style_pressed = _create_button_style(GameColors.ACTION_BUTTON_BG_PRESSED)
	_button_style_focus = _create_button_style(GameColors.ACTION_BUTTON_BG_HOVERED)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 31)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 2)
	margin.add_child(_content_container)

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
	_ensure_border_overlay()


func hide_menu() -> void:
	visible = false
	_clear_items()
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
	_clear_items()

	# Attack moves with valid targets — displayed as move chips.
	var usable_moves := unit.get_usable_moves()
	for move: Move in usable_moves:
		var valid_targets := _get_valid_targets_for_move(unit, move)
		if valid_targets.size() > 0:
			var is_assigned := (unit.assigned_move == move)
			var captured_move := move
			_create_move_chip(captured_move, is_assigned, func() -> void: move_selected.emit(captured_move))

	# Text buttons for non-move actions.
	_create_button("Unit Info", func() -> void: unit_info_requested.emit())
	_create_button("Assign Move", func() -> void: assign_submenu_requested.emit())
	_create_button("Wait", func() -> void: wait_selected.emit())
	_create_button("Cancel", func() -> void: cancel_selected.emit())

	_resize_panel()


func _populate_assign_submenu(unit: Unit) -> void:
	_clear_items()
	_is_assign_submenu = true

	var usable_moves := unit.get_usable_moves()
	for move: Move in usable_moves:
		var is_assigned := (unit.assigned_move == move)
		var captured_move := move
		_create_move_chip(captured_move, is_assigned, func() -> void: assign_move_selected.emit(captured_move))

	_create_button("Back", func() -> void:
		_is_assign_submenu = false
		_populate_main_menu(unit))

	_resize_panel()


# =============================================================================
# MOVE CHIP BUILDING
# =============================================================================

func _create_move_chip(move: Move, is_assigned: bool, callback: Callable) -> Control:
	# Clickable wrapper — Button with transparent style, containing the chip visuals.
	var button := Button.new()
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, CHIP_HEIGHT)
	button.clip_contents = true
	# Fully transparent button chrome — the MoveChip ColorRect is the visual.
	var transparent_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", transparent_style)
	button.add_theme_stylebox_override("hover", transparent_style)
	button.add_theme_stylebox_override("pressed", transparent_style)
	button.add_theme_stylebox_override("focus", transparent_style)
	button.pressed.connect(callback)

	# MoveChip background (the colored fill bar).
	var chip := MoveChip.new()
	chip.material = MOVE_CHIP_MATERIAL.duplicate()
	chip.set_anchors_preset(Control.PRESET_FULL_RECT)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fill: float = float(move.current_uses) / float(move.max_uses) if move.max_uses > 0 else 0.0
	var bright_color: Color = GameColors.get_move_chip_foreground(move.element_type)
	var dark_color: Color = GameColors.get_move_chip_background(move.element_type)

	chip.fill_color = bright_color
	chip.empty_color = dark_color
	chip.border_color = GameColorPalette.get_color("Gray", 7)
	chip.fill_percent = fill
	chip.radius_px = 2.0

	# Grey out depleted moves.
	if move.current_uses <= 0:
		chip.fill_color = Color(0.15, 0.15, 0.15, 1.0)
		chip.empty_color = Color(0.08, 0.08, 0.08, 1.0)

	button.add_child(chip)

	# Content row — move name + type icon, laid over the chip.
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 4
	hbox.offset_top = 2
	hbox.offset_right = -3
	hbox.offset_bottom = -2
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Move name label with glow.
	var label := Label.new()
	var display_name: String = move.abbrev_name if move.abbrev_name != "" else move.move_name
	if is_assigned:
		display_name = "> " + display_name
	label.text = display_name
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	var glow: ShaderMaterial = GLOW_MATERIAL.duplicate()
	glow.set_shader_parameter("glow_color", GameColors.TEXT_PRIMARY_GLOW)
	label.material = glow
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(label)

	# Spacer.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(spacer)

	# Type icon.
	var icon_texture: Texture2D = _get_elemental_icon(move.element_type)
	if icon_texture != null:
		var icon := TextureRect.new()
		icon.texture = icon_texture
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)

	button.add_child(hbox)
	_content_container.add_child(button)
	return button


# =============================================================================
# BUTTON BUILDING
# =============================================================================

func _create_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_stylebox_override("normal", _button_style_normal)
	button.add_theme_stylebox_override("hover", _button_style_hovered)
	button.add_theme_stylebox_override("pressed", _button_style_pressed)
	button.add_theme_stylebox_override("focus", _button_style_focus)
	button.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GameColors.TEXT_SECONDARY)
	# Apply glow shader to button text.
	var glow: ShaderMaterial = GLOW_MATERIAL.duplicate()
	glow.set_shader_parameter("glow_color", GameColors.TEXT_PRIMARY_GLOW)
	button.material = glow
	button.pressed.connect(callback)
	_content_container.add_child(button)
	return button


func _create_button_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = GameColors.ACTION_BUTTON_BORDER
	style.set_border_width_all(1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style


func _clear_items() -> void:
	if _content_container == null:
		return
	for child: Node in _content_container.get_children():
		_content_container.remove_child(child)
		child.queue_free()


func _resize_panel() -> void:
	# Reset minimum so the panel can shrink when content is smaller.
	custom_minimum_size.y = 0
	await get_tree().process_frame
	var item_count := _content_container.get_child_count()
	var total_height := item_count * (CHIP_HEIGHT + 2) + 24  # margins (12 top + 12 bottom)
	custom_minimum_size.y = total_height


func _ensure_border_overlay() -> void:
	if _border_overlay != null:
		return
	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager == null:
		return
	_border_overlay = ui_manager.create_fullscreen_border_overlay()
	if _border_overlay != null:
		add_child(_border_overlay)


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


func _get_elemental_icon(element_type: Enums.ElementalType) -> Texture2D:
	if element_type == Enums.ElementalType.NONE:
		return null
	var type_name: String = Enums.elemental_type_to_string(element_type).to_lower()
	var path: String = "res://art/sprites/ui/elemental_type_icons_10x10/%s.png" % type_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
