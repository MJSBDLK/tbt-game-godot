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
var _portrait_effects_on_button: Button = null
var _portrait_effects_off_button: Button = null
var _ui_motion_on_button: Button = null
var _ui_motion_off_button: Button = null
var _click_attack_on_button: Button = null
var _click_attack_off_button: Button = null
var _auto_end_on_button: Button = null
var _auto_end_off_button: Button = null
var _seeded_reload_on_button: Button = null
var _seeded_reload_off_button: Button = null
var _type_icons_on_button: Button = null
var _type_icons_off_button: Button = null

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

	# Portrait Effects (HD line-art distortion / glass shaders)
	_create_portrait_effects_option()

	# UI Motion (border-vocabulary animations; accessibility kill switch)
	_create_ui_motion_option()

	# Quick Attack (click enemy = instant attack; power-user shortcut)
	_create_click_attack_option()

	# Auto End Turn (phase hands off when every unit has acted)
	_create_auto_end_option()

	# Seeded Reload (loading a save keeps or re-rolls the dice)
	_create_seeded_reload_option()

	# On-map elemental type icons beside unit health bars
	_create_type_icons_option()

	# Move-tooltip hold delay slider (200–1000ms)
	_create_tooltip_hold_option()

	# Framerate cap slider (Off / 30–1000)
	_create_max_fps_option()

	# Volume sliders (buses are minted by Settings at load)
	_create_volume_options()

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

	# Settings is the source of truth — it's correct even when no camera exists
	# (e.g. Options opened from a menu scene), and the camera mirrors it on spawn.
	var current_integer: bool = Settings.integer_zoom_mode

	_zoom_mode_smooth_button = _create_toggle_button("Smooth", not current_integer)
	_zoom_mode_smooth_button.pressed.connect(_on_zoom_mode_smooth)
	button_container.add_child(_zoom_mode_smooth_button)

	_zoom_mode_integer_button = _create_toggle_button("Integer", current_integer)
	_zoom_mode_integer_button.pressed.connect(_on_zoom_mode_integer)
	button_container.add_child(_zoom_mode_integer_button)

	row.add_child(button_container)
	_content_container.add_child(row)


func _create_close_button() -> void:
	# The one plain action in this panel — a vocabulary InteractiveButton.
	# The toggle pills stay hand-rolled ON PURPOSE: the border vocabulary has
	# no toggle/segmented design yet (the mockup never covered settings
	# widgets) — that's a future §14 extension, not a mechanical swap.
	var button := InteractiveButton.new()
	button.text = "Close"
	button.custom_minimum_size = Vector2(0, OPTION_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	# Persist first (survives restart), then apply live to the current camera.
	Settings.set_integer_zoom_mode(integer)
	var camera := _get_camera()
	if camera != null:
		camera.integer_zoom_mode = integer


# =============================================================================
# PORTRAIT EFFECTS CALLBACKS
# =============================================================================
# Toggles the HD line-art portrait distortion/glass shaders. Accessibility
# setting (motion / flicker sensitivity). Persisted via Settings; every
# HDPortraitSlot re-applies live off the Settings.changed signal.

func _create_portrait_effects_option() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.text = "Portrait FX"
	label.custom_minimum_size = Vector2(OPTION_LABEL_WIDTH, 0)
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	var glow: ShaderMaterial = GLOW_MATERIAL.duplicate()
	glow.set_shader_parameter("glow_color", GameColors.TEXT_PRIMARY_GLOW)
	label.material = glow
	row.add_child(label)

	var button_container := HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 2)

	var enabled: bool = Settings.portrait_effects_enabled

	_portrait_effects_on_button = _create_toggle_button("On", enabled)
	_portrait_effects_on_button.pressed.connect(_on_portrait_effects_on)
	button_container.add_child(_portrait_effects_on_button)

	_portrait_effects_off_button = _create_toggle_button("Off", not enabled)
	_portrait_effects_off_button.pressed.connect(_on_portrait_effects_off)
	button_container.add_child(_portrait_effects_off_button)

	row.add_child(button_container)
	_content_container.add_child(row)


func _on_portrait_effects_on() -> void:
	Settings.set_portrait_effects_enabled(true)
	_apply_toggle_state(_portrait_effects_on_button, true)
	_apply_toggle_state(_portrait_effects_off_button, false)


func _on_portrait_effects_off() -> void:
	Settings.set_portrait_effects_enabled(false)
	_apply_toggle_state(_portrait_effects_on_button, false)
	_apply_toggle_state(_portrait_effects_off_button, true)


# Toggles the interactive-UI border-vocabulary animations (selection brackets,
# call-to-action rings, focus backlight fade). Colors always stay — only motion
# stops. Accessibility setting, persisted via Settings; InteractiveButton reads
# the flag live every frame, so this applies instantly.

func _create_ui_motion_option() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.text = "UI Motion"
	label.tooltip_text = "Animated button borders. Off keeps the colors but stops the movement."
	label.custom_minimum_size = Vector2(OPTION_LABEL_WIDTH, 0)
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	var glow: ShaderMaterial = GLOW_MATERIAL.duplicate()
	glow.set_shader_parameter("glow_color", GameColors.TEXT_PRIMARY_GLOW)
	label.material = glow
	row.add_child(label)

	var button_container := HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 2)

	var enabled: bool = Settings.ui_motion_enabled

	_ui_motion_on_button = _create_toggle_button("On", enabled)
	_ui_motion_on_button.pressed.connect(_on_ui_motion_on)
	button_container.add_child(_ui_motion_on_button)

	_ui_motion_off_button = _create_toggle_button("Off", not enabled)
	_ui_motion_off_button.pressed.connect(_on_ui_motion_off)
	button_container.add_child(_ui_motion_off_button)

	row.add_child(button_container)
	_content_container.add_child(row)


func _on_ui_motion_on() -> void:
	Settings.set_ui_motion_enabled(true)
	_apply_toggle_state(_ui_motion_on_button, true)
	_apply_toggle_state(_ui_motion_off_button, false)


func _on_ui_motion_off() -> void:
	Settings.set_ui_motion_enabled(false)
	_apply_toggle_state(_ui_motion_on_button, false)
	_apply_toggle_state(_ui_motion_off_button, true)


# Click-to-attack shortcut (click an enemy while a unit is selected = instant
# attack with the assigned move). Off by default — new players kept attacking
# enemies they meant to inspect. Persisted via Settings.

func _create_click_attack_option() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.text = "Quick Attack"
	label.tooltip_text = "Clicking an enemy with a unit selected attacks immediately."
	label.custom_minimum_size = Vector2(OPTION_LABEL_WIDTH, 0)
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	var glow: ShaderMaterial = GLOW_MATERIAL.duplicate()
	glow.set_shader_parameter("glow_color", GameColors.TEXT_PRIMARY_GLOW)
	label.material = glow
	row.add_child(label)

	var button_container := HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 2)

	var enabled: bool = Settings.click_to_attack_enabled

	_click_attack_on_button = _create_toggle_button("On", enabled)
	_click_attack_on_button.pressed.connect(_on_click_attack_on)
	button_container.add_child(_click_attack_on_button)

	_click_attack_off_button = _create_toggle_button("Off", not enabled)
	_click_attack_off_button.pressed.connect(_on_click_attack_off)
	button_container.add_child(_click_attack_off_button)

	row.add_child(button_container)
	_content_container.add_child(row)


func _on_click_attack_on() -> void:
	Settings.set_click_to_attack_enabled(true)
	_apply_toggle_state(_click_attack_on_button, true)
	_apply_toggle_state(_click_attack_off_button, false)


func _on_click_attack_off() -> void:
	Settings.set_click_to_attack_enabled(false)
	_apply_toggle_state(_click_attack_on_button, false)
	_apply_toggle_state(_click_attack_off_button, true)


# Auto end turn (meeting ask 2026-06-28): ON = the phase hands off the moment
# every unit has acted (the long-standing behavior). OFF = the phase waits and
# the system menu's End Turn wears the call-to-action. Persisted via Settings.

func _create_auto_end_option() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.text = "Auto End Turn"
	label.tooltip_text = "End your turn automatically once every unit has acted."
	label.custom_minimum_size = Vector2(OPTION_LABEL_WIDTH, 0)
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	var glow: ShaderMaterial = GLOW_MATERIAL.duplicate()
	glow.set_shader_parameter("glow_color", GameColors.TEXT_PRIMARY_GLOW)
	label.material = glow
	row.add_child(label)

	var button_container := HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 2)

	var enabled: bool = Settings.auto_end_turn

	_auto_end_on_button = _create_toggle_button("On", enabled)
	_auto_end_on_button.pressed.connect(_on_auto_end_on)
	button_container.add_child(_auto_end_on_button)

	_auto_end_off_button = _create_toggle_button("Off", not enabled)
	_auto_end_off_button.pressed.connect(_on_auto_end_off)
	button_container.add_child(_auto_end_off_button)

	row.add_child(button_container)
	_content_container.add_child(row)


func _on_auto_end_on() -> void:
	Settings.set_auto_end_turn(true)
	_apply_toggle_state(_auto_end_on_button, true)
	_apply_toggle_state(_auto_end_off_button, false)
	# Flipping auto-end ON with a spent phase pending honors the new rule now:
	# the hand-off the player just asked for happens instead of dangling.
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager != null:
		turn_manager.check_end_player_turn()


func _on_auto_end_off() -> void:
	Settings.set_auto_end_turn(false)
	_apply_toggle_state(_auto_end_on_button, false)
	_apply_toggle_state(_auto_end_off_button, true)


# Seeded Reload: On = loading a save restores the dice exactly (repeating the
# same actions repeats the same outcomes — Fire-Emblem-fair). Off = every load
# re-rolls fate, the save-scummer's option. Saves always record the dice, so
# flipping this never invalidates one.

func _create_seeded_reload_option() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.text = "Seeded Reload"
	label.tooltip_text = "On: loading a save keeps the dice — same choices, same results.\nOff: every load re-rolls fate."
	label.custom_minimum_size = Vector2(OPTION_LABEL_WIDTH, 0)
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	var glow: ShaderMaterial = GLOW_MATERIAL.duplicate()
	glow.set_shader_parameter("glow_color", GameColors.TEXT_PRIMARY_GLOW)
	label.material = glow
	row.add_child(label)

	var button_container := HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 2)

	var enabled: bool = Settings.seeded_reload

	_seeded_reload_on_button = _create_toggle_button("On", enabled)
	_seeded_reload_on_button.pressed.connect(_on_seeded_reload_on)
	button_container.add_child(_seeded_reload_on_button)

	_seeded_reload_off_button = _create_toggle_button("Off", not enabled)
	_seeded_reload_off_button.pressed.connect(_on_seeded_reload_off)
	button_container.add_child(_seeded_reload_off_button)

	row.add_child(button_container)
	_content_container.add_child(row)


func _on_seeded_reload_on() -> void:
	Settings.set_seeded_reload(true)
	_apply_toggle_state(_seeded_reload_on_button, true)
	_apply_toggle_state(_seeded_reload_off_button, false)


func _on_seeded_reload_off() -> void:
	Settings.set_seeded_reload(false)
	_apply_toggle_state(_seeded_reload_on_button, false)
	_apply_toggle_state(_seeded_reload_off_button, true)


# On-map type icons beside unit health bars. Off by default (noisy); units
# re-apply live off Settings.changed.

func _create_type_icons_option() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.text = "Type Icons"
	label.tooltip_text = "Show units' elemental types beside their health bars on the map."
	label.custom_minimum_size = Vector2(OPTION_LABEL_WIDTH, 0)
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	var glow: ShaderMaterial = GLOW_MATERIAL.duplicate()
	glow.set_shader_parameter("glow_color", GameColors.TEXT_PRIMARY_GLOW)
	label.material = glow
	row.add_child(label)

	var button_container := HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 2)

	var enabled: bool = Settings.unit_type_icons_enabled

	_type_icons_on_button = _create_toggle_button("On", enabled)
	_type_icons_on_button.pressed.connect(_on_type_icons_on)
	button_container.add_child(_type_icons_on_button)

	_type_icons_off_button = _create_toggle_button("Off", not enabled)
	_type_icons_off_button.pressed.connect(_on_type_icons_off)
	button_container.add_child(_type_icons_off_button)

	row.add_child(button_container)
	_content_container.add_child(row)


func _on_type_icons_on() -> void:
	Settings.set_unit_type_icons_enabled(true)
	_apply_toggle_state(_type_icons_on_button, true)
	_apply_toggle_state(_type_icons_off_button, false)


func _on_type_icons_off() -> void:
	Settings.set_unit_type_icons_enabled(false)
	_apply_toggle_state(_type_icons_on_button, false)
	_apply_toggle_state(_type_icons_off_button, true)


# =============================================================================
# SLIDER ROWS (framerate cap + volumes)
# =============================================================================

## Generic label + HSlider + live value readout row. `format_value` maps the
## slider value to its display string; `on_changed` receives the raw slider
## value. The row is freed wholesale by _clear_items, and the value label is
## captured by the closure, so no member refs are needed.
func _create_slider_option(label_text: String, tooltip: String, min_value: float,
		max_value: float, step: float, current: float,
		format_value: Callable, on_changed: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.text = label_text
	label.tooltip_text = tooltip
	label.custom_minimum_size = Vector2(OPTION_LABEL_WIDTH, 0)
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	var glow: ShaderMaterial = GLOW_MATERIAL.duplicate()
	glow.set_shader_parameter("glow_color", GameColors.TEXT_PRIMARY_GLOW)
	label.material = glow
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = current
	slider.custom_minimum_size = Vector2(80, OPTION_HEIGHT)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = str(format_value.call(current))
	value_label.custom_minimum_size = Vector2(30, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	row.add_child(value_label)

	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = str(format_value.call(value))
		on_changed.call(value))

	_content_container.add_child(row)


## Hold-to-peek delay for move detail tooltips (long press / hold right click /
## hold Back/R3 — ui-style-guide.md §14). The 200ms floor is a softlock guard:
## a threshold shorter than a player can reliably release would open a tooltip
## on every tap, so the slider simply doesn't go there (RQD 2026-07-19).
func _create_tooltip_hold_option() -> void:
	_create_slider_option("Tooltip Hold",
			"How long to hold a move chip before its detail card opens.",
			float(Settings.TOOLTIP_HOLD_MIN_MS), float(Settings.TOOLTIP_HOLD_MAX_MS),
			float(Settings.TOOLTIP_HOLD_STEP_MS), float(Settings.tooltip_hold_ms),
			func(value: float) -> String: return "%dms" % roundi(value),
			func(value: float) -> void: Settings.set_tooltip_hold_ms(roundi(value)))


## FPS cap: leftmost slider notch (below 30) reads as "Off" → Engine.max_fps 0.
func _create_max_fps_option() -> void:
	var format := func(value: float) -> String:
		return "Off" if value < 30.0 else "%d" % roundi(value)
	var current: float = float(Settings.max_fps) if Settings.max_fps >= 30 else 20.0
	_create_slider_option("FPS Cap", "Cap the framerate. Off = uncapped (VSync still applies).",
			20.0, 1000.0, 10.0, current, format,
			func(value: float) -> void:
				Settings.set_max_fps(0 if value < 30.0 else roundi(value)))


func _create_volume_options() -> void:
	var to_percent := func(value: float) -> String:
		return "%d%%" % roundi(value * 100.0)
	_create_slider_option("Master Vol.", "Overall game volume.",
			0.0, 1.0, 0.05, Settings.master_volume, to_percent,
			func(value: float) -> void: Settings.set_master_volume(value))
	_create_slider_option("SFX Vol.", "Sound effect volume.",
			0.0, 1.0, 0.05, Settings.sfx_volume, to_percent,
			func(value: float) -> void: Settings.set_sfx_volume(value))
	_create_slider_option("Music Vol.", "Music volume.",
			0.0, 1.0, 0.05, Settings.music_volume, to_percent,
			func(value: float) -> void: Settings.set_music_volume(value))


func _get_camera() -> CameraController:
	# The options panel lives in HUDViewport; the world camera is in the root
	# viewport. Route through SceneRouter so we don't end up looking at the
	# wrong viewport.
	return SceneRouter.get_world_camera() as CameraController


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
	_portrait_effects_on_button = null
	_portrait_effects_off_button = null
	_click_attack_on_button = null
	_click_attack_off_button = null
	_type_icons_on_button = null
	_type_icons_off_button = null


func _ensure_border_overlay() -> void:
	if _border_overlay != null:
		return
	var ui_manager: Node = UIManager
	if ui_manager != null and ui_manager.has_method("create_fullscreen_border_overlay"):
		_border_overlay = ui_manager.create_fullscreen_border_overlay()
		if _border_overlay != null:
			add_child(_border_overlay)
