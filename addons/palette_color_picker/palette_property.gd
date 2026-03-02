@tool
extends EditorProperty
## Custom color property editor that shows a palette-only swatch grid
## instead of the standard color picker. Colors come from GameColorPalette.

var no_alpha: bool = false

var _button: Button
var _color_preview: ColorRect
var _active_popup: PopupPanel


func _init():
	_button = Button.new()
	_button.custom_minimum_size = Vector2(40, 20)
	_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button.flat = true
	_button.pressed.connect(_toggle_palette)

	_color_preview = ColorRect.new()
	_color_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(_color_preview)

	add_child(_button)
	add_focusable(_button)


func _update_property():
	var value = get_edited_object()[get_edited_property()]
	if value is Color:
		_color_preview.color = value


func _toggle_palette():
	if _active_popup and is_instance_valid(_active_popup):
		_active_popup.hide()
		return
	_open_palette()


func _open_palette():
	var popup = PopupPanel.new()
	_active_popup = popup
	popup.popup_hide.connect(func():
		_active_popup = null
		popup.queue_free()
	)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	# Palette grid
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(11 * 17 + 8, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var grid = GridContainer.new()
	grid.columns = 11
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)

	# Ensure palette is loaded
	if not GameColorPalette._loaded:
		GameColorPalette.load_palette()

	for ramp_index in GameColorPalette.RAMP_NAMES.size():
		var ramp_name: String = GameColorPalette.RAMP_NAMES[ramp_index]
		for shade in range(11):
			var color = GameColorPalette.get_color(ramp_name, shade)
			var swatch = _make_swatch(color, "%s %d" % [ramp_name, shade], popup)
			grid.add_child(swatch)

	scroll.add_child(grid)
	vbox.add_child(scroll)

	# Alpha slider
	if not no_alpha:
		var alpha_row = HBoxContainer.new()
		alpha_row.add_theme_constant_override("separation", 4)

		var alpha_label = Label.new()
		alpha_label.text = "A:"
		alpha_row.add_child(alpha_label)

		var alpha_slider = HSlider.new()
		alpha_slider.min_value = 0.0
		alpha_slider.max_value = 1.0
		alpha_slider.step = 0.05
		alpha_slider.custom_minimum_size = Vector2(100, 0)
		alpha_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var current_color = get_edited_object()[get_edited_property()]
		if current_color is Color:
			alpha_slider.value = current_color.a

		alpha_slider.value_changed.connect(func(val: float):
			var color_now = get_edited_object()[get_edited_property()]
			if color_now is Color:
				emit_changed(get_edited_property(), Color(color_now.r, color_now.g, color_now.b, val))
				update_property()
		)

		alpha_row.add_child(alpha_slider)
		vbox.add_child(alpha_row)

	margin.add_child(vbox)
	popup.add_child(margin)
	add_child(popup)

	# Position below button
	var screen_pos = _button.get_screen_position()
	popup.position = Vector2i(int(screen_pos.x), int(screen_pos.y + _button.size.y))
	popup.popup()


func _make_swatch(color: Color, tooltip: String, popup: PopupPanel) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(16, 16)
	panel.tooltip_text = tooltip
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Background shows the color
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(1)
	style.border_color = Color(0.1, 0.1, 0.1, 0.4)
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)

	# Hover/press feedback via a border overlay
	var border_overlay = ReferenceRect.new()
	border_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	border_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border_overlay.border_color = Color.TRANSPARENT
	border_overlay.border_width = 2.0
	border_overlay.editor_only = false
	panel.add_child(border_overlay)

	panel.mouse_entered.connect(func():
		border_overlay.border_color = Color.WHITE
	)
	panel.mouse_exited.connect(func():
		border_overlay.border_color = Color.TRANSPARENT
	)
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var alpha := 1.0
			if not no_alpha:
				var current = get_edited_object()[get_edited_property()]
				if current is Color:
					alpha = current.a
			emit_changed(get_edited_property(), Color(color.r, color.g, color.b, alpha))
			update_property()
			popup.hide()
	)

	return panel
