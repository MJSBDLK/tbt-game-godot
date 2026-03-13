@tool
extends EditorProperty
## Custom color property editor that shows a palette-only swatch grid
## instead of the standard color picker. Colors come from GameColorPalette,
## with collapsible sections for semantic GameColors constants.

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

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 4)

	# Scrollable area containing all collapsible sections
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(11 * 17 + 8, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 2)
	inner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# --- Raw Palette section (expanded by default) ---
	if not GameColorPalette._loaded:
		GameColorPalette.load_palette()

	var raw_grid = GridContainer.new()
	raw_grid.columns = 11
	raw_grid.add_theme_constant_override("h_separation", 1)
	raw_grid.add_theme_constant_override("v_separation", 1)
	for ramp_name: String in GameColorPalette.RAMP_NAMES:
		for shade in range(11):
			var color = GameColorPalette.get_color(ramp_name, shade)
			raw_grid.add_child(_make_swatch(color, "%s %d" % [ramp_name, shade], popup))
	inner_vbox.add_child(_make_section("Raw Palette", raw_grid, true))

	# --- GameColors semantic sections (collapsed by default) ---
	var gc_script = load("res://scripts/core/game_colors.gd")
	var sections: Array = _parse_game_colors_sections()
	for section: Dictionary in sections:
		var section_grid = GridContainer.new()
		section_grid.columns = 11
		section_grid.add_theme_constant_override("h_separation", 1)
		section_grid.add_theme_constant_override("v_separation", 1)
		for var_name: String in section["vars"]:
			var color = gc_script.get(var_name)
			if color is Color:
				section_grid.add_child(_make_swatch(color, var_name, popup))
		if section_grid.get_child_count() > 0:
			inner_vbox.add_child(_make_section(section["name"], section_grid, false))

	scroll.add_child(inner_vbox)
	outer_vbox.add_child(scroll)

	# --- Alpha row (always visible, outside the scroll area) ---
	if not no_alpha:
		outer_vbox.add_child(HSeparator.new())

		var alpha_row = HBoxContainer.new()
		alpha_row.add_theme_constant_override("separation", 4)

		var alpha_label = Label.new()
		alpha_label.text = "A:"
		alpha_row.add_child(alpha_label)

		var alpha_slider = HSlider.new()
		alpha_slider.min_value = 0.0
		alpha_slider.max_value = 1.0
		alpha_slider.step = 0.01
		alpha_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var alpha_spinbox = SpinBox.new()
		alpha_spinbox.min_value = 0
		alpha_spinbox.max_value = 100
		alpha_spinbox.step = 1
		alpha_spinbox.suffix = "%"
		alpha_spinbox.custom_minimum_size = Vector2(68, 0)

		var current_color = get_edited_object()[get_edited_property()]
		if current_color is Color:
			alpha_slider.value = current_color.a
			alpha_spinbox.value = roundi(current_color.a * 100)

		alpha_slider.value_changed.connect(func(val: float):
			alpha_spinbox.set_value_no_signal(roundi(val * 100))
			var color_now = get_edited_object()[get_edited_property()]
			if color_now is Color:
				emit_changed(get_edited_property(), Color(color_now.r, color_now.g, color_now.b, val))
				update_property()
		)

		alpha_spinbox.value_changed.connect(func(val: float):
			alpha_slider.set_value_no_signal(val / 100.0)
			var color_now = get_edited_object()[get_edited_property()]
			if color_now is Color:
				emit_changed(get_edited_property(), Color(color_now.r, color_now.g, color_now.b, val / 100.0))
				update_property()
		)

		alpha_row.add_child(alpha_slider)
		alpha_row.add_child(alpha_spinbox)
		outer_vbox.add_child(alpha_row)

	margin.add_child(outer_vbox)
	popup.add_child(margin)
	add_child(popup)

	var screen_pos = _button.get_screen_position()
	popup.position = Vector2i(int(screen_pos.x), int(screen_pos.y + _button.size.y))
	popup.popup()


func _make_section(title: String, content: Control, expanded: bool) -> Control:
	var section_box = VBoxContainer.new()
	section_box.add_theme_constant_override("separation", 2)
	section_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header = Button.new()
	header.text = ("▼  " if expanded else "▶  ") + title
	header.flat = false
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	content.visible = expanded
	header.pressed.connect(func():
		content.visible = not content.visible
		header.text = ("▼  " if content.visible else "▶  ") + title
	)

	section_box.add_child(header)
	section_box.add_child(content)
	return section_box


func _parse_game_colors_sections() -> Array:
	## Parse game_colors.gd to extract sections and their static Color var names.
	## Section format is a three-line block:
	##   # ===...===
	##   # SECTION NAME
	##   # ===...===
	## Returns: [{"name": "Section Name", "vars": ["VAR_A", "VAR_B"]}, ...]
	var result: Array = []
	var current: Dictionary = {}
	var next_is_section_name: bool = false

	var file = FileAccess.open("res://scripts/core/game_colors.gd", FileAccess.READ)
	if file == null:
		return result

	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()

		# Decorative separator: # ===...
		if line.begins_with("# ==="):
			next_is_section_name = true
			continue

		# Section name: the comment line immediately after a separator
		if next_is_section_name and line.begins_with("# "):
			next_is_section_name = false
			if not current.is_empty() and not current["vars"].is_empty():
				result.append(current)
			var raw_name: String = line.trim_prefix("# ").strip_edges()
			current = {"name": raw_name.capitalize(), "vars": []}
			continue

		next_is_section_name = false

		# Static Color var declaration
		if not current.is_empty() and line.begins_with("static var ") and ": Color" in line:
			var var_name: String = line.trim_prefix("static var ").split(":")[0].strip_edges()
			current["vars"].append(var_name)

	if not current.is_empty() and not current["vars"].is_empty():
		result.append(current)

	file.close()
	return result


func _make_swatch(color: Color, tooltip: String, popup: PopupPanel) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(16, 16)
	panel.tooltip_text = tooltip
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(1)
	style.border_color = Color(0.1, 0.1, 0.1, 0.4)
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)

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
