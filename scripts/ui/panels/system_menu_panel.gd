## Right-side system menu panel (like the action menu but for game-level actions).
## Appears when pressing Escape in DEFAULT state or tapping the menu button.
## Contains: Options, End Turn, Save, Load, Quit.
class_name SystemMenuPanel
extends PanelContainer


signal options_selected()
signal end_turn_selected()
signal save_selected()
signal load_selected()
signal quit_selected()
signal closed()

const GLOW_MATERIAL: ShaderMaterial = preload("res://resources/hud_glow.tres")

const BUTTON_HEIGHT: int = 14
const BUTTON_WIDTH: int = 116

var _content_container: VBoxContainer = null
var _border_overlay: PanelBorderOverlay = null
var _button_style_normal: StyleBoxFlat = null
var _button_style_hovered: StyleBoxFlat = null
var _button_style_pressed: StyleBoxFlat = null
var _button_style_focus: StyleBoxFlat = null


func _ready() -> void:
	custom_minimum_size = Vector2(140, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Transparent panel — we draw our own inset background to avoid
	# the dark bg peeking outside the border's rounded corners.
	var panel_style := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", panel_style)

	# Inset background (5px from each edge = midpoint of 10px border)
	# Uses a Panel with rounded corners so it doesn't peek past the border.
	var background := Panel.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = GameColors.HUD_PANEL_BACKGROUND
	bg_style.set_corner_radius_all(5)
	background.add_theme_stylebox_override("panel", bg_style)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.offset_left = 5
	background.offset_right = -5
	background.offset_top = 5
	background.offset_bottom = -5
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_button_style_normal = _create_button_style(GameColors.ACTION_BUTTON_BG_NORMAL)
	_button_style_hovered = _create_button_style(GameColors.ACTION_BUTTON_BG_HOVERED)
	_button_style_pressed = _create_button_style(GameColors.ACTION_BUTTON_BG_PRESSED)
	_button_style_focus = _create_button_style(GameColors.ACTION_BUTTON_BG_HOVERED)

	# Margins: 12px left/right with 116px buttons = 140px panel
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


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_menu()
		get_viewport().set_input_as_handled()


# =============================================================================
# PUBLIC API
# =============================================================================

func show_menu() -> void:
	_populate_menu()
	visible = true
	_ensure_border_overlay()


func hide_menu() -> void:
	visible = false
	_clear_items()
	closed.emit()


# =============================================================================
# MENU POPULATION
# =============================================================================

func _populate_menu() -> void:
	_clear_items()

	_create_end_turn_button()
	_create_spacer()
	_create_button("Options", func() -> void: options_selected.emit())
	_create_button("Save", func() -> void: save_selected.emit())
	_create_button("Load", func() -> void: load_selected.emit())
	_create_button("Quit", func() -> void: quit_selected.emit())
	_create_button("Close", func() -> void: hide_menu())

	_resize_panel()


const END_TURN_BUTTON_HEIGHT: int = 22


# =============================================================================
# BUTTON BUILDING
# =============================================================================

func _create_end_turn_button() -> Button:
	var button := Button.new()
	button.text = "END TURN"
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, END_TURN_BUTTON_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Pink/red accent — cautionary but not alarming
	var accent_color: Color = GameColorPalette.get_color("Magenta", 4)
	var accent_glow: Color = GameColorPalette.get_color("Magenta", 2)
	var accent_text: Color = GameColorPalette.get_color("Magenta", 9)

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = accent_color
	style_normal.border_color = accent_text
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(2)
	style_normal.content_margin_left = 4
	style_normal.content_margin_right = 4
	style_normal.content_margin_top = 2
	style_normal.content_margin_bottom = 2

	var style_hovered := style_normal.duplicate()
	style_hovered.bg_color = accent_color.lightened(0.2)

	var style_pressed := style_normal.duplicate()
	style_pressed.bg_color = accent_color.darkened(0.2)

	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hovered)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("focus", style_hovered)
	button.add_theme_color_override("font_color", accent_text)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", accent_text.darkened(0.2))

	var glow: ShaderMaterial = GLOW_MATERIAL.duplicate()
	glow.set_shader_parameter("glow_color", accent_glow)
	button.material = glow

	button.pressed.connect(func() -> void: end_turn_selected.emit())
	_content_container.add_child(button)
	return button


func _create_spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_container.add_child(spacer)


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
	custom_minimum_size.y = 0
	await get_tree().process_frame
	var item_count := _content_container.get_child_count()
	var total_height := item_count * (BUTTON_HEIGHT + 2) + 24
	custom_minimum_size.y = total_height


func _ensure_border_overlay() -> void:
	if _border_overlay != null:
		return
	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null and ui_manager.has_method("create_fullscreen_border_overlay"):
		_border_overlay = ui_manager.create_fullscreen_border_overlay()
		if _border_overlay != null:
			add_child(_border_overlay)
