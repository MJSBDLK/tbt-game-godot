## Between-missions screen: shows N recruit candidates as cards, player clicks
## one. Emits `recruit_chosen(path)` with the chosen JSON path. Built
## programmatically — Lawrence will design the proper card art later.
class_name RecruitPickerPanel
extends Control


signal recruit_chosen(json_path: String)


var _cards_row: HBoxContainer = null
var _candidates: Array[String] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_chrome()


# =============================================================================
# PUBLIC API
# =============================================================================

func show_candidates(candidate_paths: Array[String]) -> void:
	_candidates = candidate_paths.duplicate()
	_clear_cards()
	for path: String in _candidates:
		var character: CharacterData = CharacterDataLoader.load_character(path)
		if character == null:
			push_warning("RecruitPickerPanel: Failed to load %s" % path)
			continue
		_cards_row.add_child(_build_card(character, path))
	visible = true


func hide_panel() -> void:
	visible = false


# =============================================================================
# BUILD
# =============================================================================

func _build_chrome() -> void:
	var ui_manager: Node = get_node_or_null("/root/UIManager")

	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.6)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 220)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.5, 1)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "Choose a recruit"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null:
		header.add_theme_font_override("font", ui_manager.font_11px)
		header.add_theme_font_size_override("font_size", 11)
	vbox.add_child(header)

	_cards_row = HBoxContainer.new()
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_row.add_theme_constant_override("separation", 8)
	vbox.add_child(_cards_row)


func _build_card(character: CharacterData, path: String) -> Control:
	var ui_manager: Node = get_node_or_null("/root/UIManager")

	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 210)
	button.pressed.connect(_on_card_pressed.bind(path))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)

	if not character.portrait_path.is_empty() and ResourceLoader.exists(character.portrait_path):
		var portrait_wrap := CenterContainer.new()
		portrait_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var portrait := TextureRect.new()
		portrait.texture = load(character.portrait_path) as Texture2D
		portrait.custom_minimum_size = Vector2(48, 48)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_wrap.add_child(portrait)
		content.add_child(portrait_wrap)

	var name_label := Label.new()
	name_label.text = character.character_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null:
		name_label.add_theme_font_override("font", ui_manager.font_8px)
		name_label.add_theme_font_size_override("font_size", 8)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)

	var type_class_label := Label.new()
	var type_str: String = Enums.elemental_type_to_string(character.primary_type).capitalize()
	var class_str: String = Enums.CharacterClass.keys()[character.current_class].capitalize()
	type_class_label.text = "%s %s" % [type_str, class_str]
	type_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null:
		type_class_label.add_theme_font_override("font", ui_manager.font_5px)
		type_class_label.add_theme_font_size_override("font_size", 5)
	type_class_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(type_class_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	content.add_child(spacer)

	var stats_label := Label.new()
	stats_label.text = "HP %d  STR %d\nSPC %d  SKL %d\nAGL %d  ATH %d\nDEF %d  RES %d" % [
		character.base_max_hp, character.base_strength,
		character.base_special, character.base_skill,
		character.base_agility, character.base_athleticism,
		character.base_defense, character.base_resistance,
	]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null:
		stats_label.add_theme_font_override("font", ui_manager.font_5px)
		stats_label.add_theme_font_size_override("font_size", 5)
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(stats_label)

	return button


func _clear_cards() -> void:
	for child: Node in _cards_row.get_children():
		child.queue_free()


# =============================================================================
# INPUT
# =============================================================================

func _on_card_pressed(json_path: String) -> void:
	visible = false
	recruit_chosen.emit(json_path)
