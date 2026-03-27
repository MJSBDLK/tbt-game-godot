## Centered options menu panel with variable size and fullscreen border.
## Opened from the system menu's Options button.
## Contains game settings like zoom mode.
class_name OptionsMenuPanel
extends PanelContainer


signal closed()

const GLOW_MATERIAL: ShaderMaterial = preload("res://resources/hud_glow.tres")

const OPTION_LABEL_WIDTH: int = 80
const OPTION_HEIGHT: int = 14
const PANEL_MIN_WIDTH: int = 220

var _content_container: VBoxContainer = null
var _border_overlay: PanelBorderOverlay = null

# Current setting values
var _zoom_mode_smooth_button: Button = null
var _zoom_mode_integer_button: Button = null

# Style caches
var _toggle_style_active: StyleBoxFlat = null
var _toggle_style_inactive: StyleBoxFlat = null
var _toggle_style_hovered: StyleBoxFlat = null


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_MIN_WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Transparent panel — we draw our own inset background.
	var panel_style := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", panel_style)

	# Inset background (5px from each edge = midpoint of 10px border)
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

	# Toggle button styles
	_toggle_style_active = _create_toggle_style(GameColors.ACTION_BUTTON_BG_HOVERED, true)
	_toggle_style_inactive = _create_toggle_style(GameColors.ACTION_BUTTON_BG_NORMAL, false)
	_toggle_style_hovered = _create_toggle_style(GameColors.ACTION_BUTTON_BG_HOVERED, false)

	# Margins
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 6)
	margin.add_child(_content_container)

	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_panel()
		get_viewport().set_input_as_handled()


# =============================================================================
# PUBLIC API
# =============================================================================

func show_panel() -> void:
	_populate_options()
	visible = true
	_ensure_border_overlay()


func hide_panel() -> void:
	visible = false
	_clear_items()
	closed.emit()


# =============================================================================
# OPTION POPULATION
# =============================================================================

func _populate_options() -> void:
	_clear_items()

	# Title
	_create_title("OPTIONS")

	# Separator
	_create_separator()

	# Zoom Mode
	_create_zoom_mode_option()

	# Close button at bottom
	_create_separator()
	_create_close_button()


func _create_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	var glow: ShaderMaterial = GLOW_MATERIAL.duplicate()
	glow.set_shader_parameter("glow_color", GameColors.TEXT_SECONDARY_GLOW)
	label.material = glow
	_content_container.add_child(label)


func _create_separator() -> void:
	var sep := HSeparator.new()
	var empty_style := StyleBoxEmpty.new()
	empty_style.content_margin_top = 2
	empty_style.content_margin_bottom = 2
	sep.add_theme_stylebox_override("separator", empty_style)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_container.add_child(sep)


func _create_zoom_mode_option() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	# Label
	var label := Label.new()
	label.text = "Zoom Mode"
	label.custom_minimum_size = Vector2(OPTION_LABEL_WIDTH, 0)
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	var glow: ShaderMaterial = GLOW_MATERIAL.duplicate()
	glow.set_shader_parameter("glow_color", GameColors.TEXT_PRIMARY_GLOW)
	label.material = glow
	row.add_child(label)

	# Toggle buttons
	var button_container := HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 2)

	var camera := _get_camera()
	var current_integer: bool = camera != null and camera.integer_zoom_mode

	_zoom_mode_smooth_button = _create_toggle_button("Smooth", not current_integer)
	_zoom_mode_smooth_button.pressed.connect(_on_zoom_mode_smooth)
	button_container.add_child(_zoom_mode_smooth_button)

	_zoom_mode_integer_button = _create_toggle_button("Integer", current_integer)
	_zoom_mode_integer_button.pressed.connect(_on_zoom_mode_integer)
	button_container.add_child(_zoom_mode_integer_button)

	row.add_child(button_container)
	_content_container.add_child(row)


func _create_close_button() -> void:
	var button := Button.new()
	button.text = "Close"
	button.custom_minimum_size = Vector2(0, OPTION_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_stylebox_override("normal", _toggle_style_inactive)
	button.add_theme_stylebox_override("hover", _toggle_style_hovered)
	button.add_theme_stylebox_override("pressed", _toggle_style_active)
	button.add_theme_stylebox_override("focus", _toggle_style_hovered)
	button.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GameColors.TEXT_SECONDARY)
	var glow: ShaderMaterial = GLOW_MATERIAL.duplicate()
	glow.set_shader_parameter("glow_color", GameColors.TEXT_PRIMARY_GLOW)
	button.material = glow
	button.pressed.connect(func() -> void: hide_panel())
	_content_container.add_child(button)


# =============================================================================
# TOGGLE BUTTONS
# =============================================================================

func _create_toggle_button(text: String, is_active: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(56, OPTION_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.toggle_mode = false
	_apply_toggle_state(button, is_active)
	return button


func _apply_toggle_state(button: Button, is_active: bool) -> void:
	if is_active:
		button.add_theme_stylebox_override("normal", _toggle_style_active)
		button.add_theme_stylebox_override("hover", _toggle_style_active)
		button.add_theme_stylebox_override("pressed", _toggle_style_active)
		button.add_theme_stylebox_override("focus", _toggle_style_active)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
	else:
		button.add_theme_stylebox_override("normal", _toggle_style_inactive)
		button.add_theme_stylebox_override("hover", _toggle_style_hovered)
		button.add_theme_stylebox_override("pressed", _toggle_style_active)
		button.add_theme_stylebox_override("focus", _toggle_style_hovered)
		button.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", GameColors.TEXT_SECONDARY)


func _create_toggle_style(background_color: Color, is_active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = GameColors.ACTION_BUTTON_BORDER if not is_active \
		else GameColors.TEXT_SECONDARY
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style


# =============================================================================
# ZOOM MODE CALLBACKS
# =============================================================================

func _on_zoom_mode_smooth() -> void:
	_set_zoom_mode(false)
	_apply_toggle_state(_zoom_mode_smooth_button, true)
	_apply_toggle_state(_zoom_mode_integer_button, false)


func _on_zoom_mode_integer() -> void:
	_set_zoom_mode(true)
	_apply_toggle_state(_zoom_mode_smooth_button, false)
	_apply_toggle_state(_zoom_mode_integer_button, true)


func _set_zoom_mode(integer: bool) -> void:
	var camera := _get_camera()
	if camera != null:
		camera.integer_zoom_mode = integer


func _get_camera() -> CameraController:
	var viewport := get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_2d() as CameraController


# =============================================================================
# INTERNAL
# =============================================================================

func _clear_items() -> void:
	if _content_container == null:
		return
	for child: Node in _content_container.get_children():
		_content_container.remove_child(child)
		child.queue_free()
	_zoom_mode_smooth_button = null
	_zoom_mode_integer_button = null


func _ensure_border_overlay() -> void:
	if _border_overlay != null:
		return
	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null and ui_manager.has_method("create_fullscreen_border_overlay"):
		_border_overlay = ui_manager.create_fullscreen_border_overlay()
		if _border_overlay != null:
			add_child(_border_overlay)
