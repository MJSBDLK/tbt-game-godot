## Between-mission prep hub (squad manager). Master-detail layout per
## .claude/squad_manager.md §3+§8: vertical roster strip on the left, focused
## unit's editing surface on the right.
##
## Each roster card has two interactive zones:
##   - Card body click → selects the unit, opens equipment_picker on the right
##   - "Bench/Deploy" button → toggles the unit's deployment status without
##     changing focus selection
##
## Dimmed cards (`modulate.a` = BENCHED_MODULATE_ALPHA) are benched.
## Begin Mission disabled when no unit is in the deployed selection.
class_name PrepScreen
extends Control


const BENCHED_MODULATE_ALPHA: float = 0.4

var _header_label: Label = null
var _roster_strip: VBoxContainer = null
var _detail_host: Control = null
var _begin_button: Button = null
var _picker: EquipmentPicker = null
var _empty_prompt: Label = null

# Per-character UI state (parallel arrays indexed alongside the roster).
# _card_buttons doubles as the click target and the modulate target.
var _card_buttons: Array[Button] = []
var _deploy_buttons: Array[Button] = []
var _character_ids: Array[String] = []

var _selected_character_id: String = ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_chrome()
	_populate_roster()


# =============================================================================
# BUILD
# =============================================================================

func _build_chrome() -> void:
	var ui_manager: Node = get_node_or_null("/root/UIManager")

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.08, 0.08, 0.12, 1.0)
	add_child(background)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	root.offset_left = 8
	root.offset_top = 8
	root.offset_right = -8
	root.offset_bottom = -8
	add_child(root)

	# Top bar: header + Begin Mission
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	root.add_child(top_bar)

	_header_label = Label.new()
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ui_manager != null:
		_header_label.add_theme_font_override("font", ui_manager.font_11px)
		_header_label.add_theme_font_size_override("font_size", 11)
	top_bar.add_child(_header_label)

	_begin_button = Button.new()
	_begin_button.text = "Begin Mission"
	_begin_button.custom_minimum_size = Vector2(110, 22)
	_begin_button.pressed.connect(_on_begin_pressed)
	top_bar.add_child(_begin_button)

	# Main split: roster strip on left, detail host on right
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	root.add_child(main)

	# Left: scrolling roster
	var roster_scroll := ScrollContainer.new()
	roster_scroll.custom_minimum_size = Vector2(140, 0)
	roster_scroll.size_flags_horizontal = Control.SIZE_FILL
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(roster_scroll)

	_roster_strip = VBoxContainer.new()
	_roster_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roster_strip.add_theme_constant_override("separation", 4)
	roster_scroll.add_child(_roster_strip)

	# Right: detail host. Plain Control so the picker (added later) can use
	# PRESET_FULL_RECT to fill it — Container-based hosts would override that.
	_detail_host = Control.new()
	_detail_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_host.size_flags_stretch_ratio = 3.0
	_detail_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_host.clip_contents = true
	main.add_child(_detail_host)

	_empty_prompt = Label.new()
	_empty_prompt.text = "Select a unit on the left to manage their equipment."
	_empty_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_prompt.modulate.a = 0.6
	if ui_manager != null:
		_empty_prompt.add_theme_font_override("font", ui_manager.font_8px)
		_empty_prompt.add_theme_font_size_override("font_size", 8)
	_detail_host.add_child(_empty_prompt)


func _populate_roster() -> void:
	var campaign_manager: Node = get_node_or_null("/root/CampaignManager")
	if campaign_manager != null and campaign_manager.is_active():
		var mission_index: int = campaign_manager.get_current_mission_index()
		var mission_count: int = campaign_manager.get_mission_count()
		_header_label.text = "Mission %d of %d" % [mission_index + 1, mission_count]
	else:
		_header_label.text = "Squad Preview"

	var roster: Array[CharacterData] = SquadManager.get_active_roster()
	print("[PrepScreen] _populate_roster: roster.size() = %d" % roster.size())
	for character: CharacterData in roster:
		print("[PrepScreen]   adding card for: id='%s' name='%s'" % [character.character_id, character.character_name])
		_add_roster_card(character)
	print("[PrepScreen] after populate: _roster_strip has %d children" % _roster_strip.get_child_count())
	call_deferred("_log_layout_sizes")
	_refresh_begin_button()


func _log_layout_sizes() -> void:
	# Runs one frame after _ready so the layout pass has completed.
	if _roster_strip == null:
		print("[PrepScreen] _log_layout_sizes: _roster_strip is null")
		return
	print("[PrepScreen] self.size = %s" % size)
	# Walk up from the roster strip to self, logging each ancestor.
	var node: Node = _roster_strip
	var depth: int = 0
	while node != null and node != self.get_parent():
		if node is Control:
			var ctl: Control = node
			print("[PrepScreen]   [%d] %s.size = %s, pos = %s" % [depth, ctl.name, ctl.size, ctl.position])
		node = node.get_parent()
		depth += 1
	print("[PrepScreen] _detail_host.size = %s, pos = %s" % [_detail_host.size, _detail_host.position])
	for i: int in range(_roster_strip.get_child_count()):
		var c: Node = _roster_strip.get_child(i)
		if c is Control:
			var card: Control = c
			print("[PrepScreen]   card[%d] size = %s" % [i, card.size])


func _add_roster_card(character: CharacterData) -> void:
	var ui_manager: Node = get_node_or_null("/root/UIManager")

	# The entire card is one Button so clicking anywhere on it selects the
	# unit. Deploy toggle sits inside as a child Button — its clicks are
	# consumed at that node and don't bubble up to the parent's pressed.
	var card_button := Button.new()
	card_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_button.custom_minimum_size = Vector2(0, 56)
	card_button.toggle_mode = false
	card_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card_button.pressed.connect(_on_card_select_pressed.bind(character.character_id))
	_roster_strip.add_child(card_button)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_button.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)

	# Header row: portrait + name/level/class
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(header_row)

	if not character.portrait_path.is_empty() and ResourceLoader.exists(character.portrait_path):
		var portrait := TextureRect.new()
		portrait.texture = load(character.portrait_path) as Texture2D
		portrait.custom_minimum_size = Vector2(28, 28)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header_row.add_child(portrait)

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(name_box)

	var name_label := Label.new()
	name_label.text = character.character_name
	if ui_manager != null:
		name_label.add_theme_font_override("font", ui_manager.font_8px)
		name_label.add_theme_font_size_override("font_size", 8)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_box.add_child(name_label)

	var class_label := Label.new()
	var class_str: String = Enums.CharacterClass.keys()[character.current_class].capitalize()
	class_label.text = "%s  Lv %d" % [class_str, character.level]
	if ui_manager != null:
		class_label.add_theme_font_override("font", ui_manager.font_5px)
		class_label.add_theme_font_size_override("font_size", 5)
	class_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_box.add_child(class_label)

	# Compact stat row + deploy toggle
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 4)
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(bottom_row)

	var stat_label := Label.new()
	stat_label.text = "HP %d  STR %d  SPC %d" % [
		character.max_hp, character.strength, character.special
	]
	stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ui_manager != null:
		stat_label.add_theme_font_override("font", ui_manager.font_5px)
		stat_label.add_theme_font_size_override("font_size", 5)
	stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_child(stat_label)

	var deploy_button := Button.new()
	deploy_button.text = "Deploy"
	deploy_button.toggle_mode = true
	deploy_button.button_pressed = true
	deploy_button.custom_minimum_size = Vector2(48, 16)
	deploy_button.toggled.connect(_on_card_deploy_toggled.bind(card_button))
	bottom_row.add_child(deploy_button)

	_card_buttons.append(card_button)
	_deploy_buttons.append(deploy_button)
	_character_ids.append(character.character_id)


# =============================================================================
# SELECTION + DEPLOYMENT
# =============================================================================

func _on_card_select_pressed(character_id: String) -> void:
	_selected_character_id = character_id
	var character: CharacterData = SquadManager.get_character_by_id(character_id)
	if character == null:
		return
	_show_picker_for(character)
	_highlight_selected_card()


func _on_card_deploy_toggled(deployed: bool, card_button: Button) -> void:
	# Dim the card when benched. Refresh Begin button state.
	card_button.modulate.a = 1.0 if deployed else BENCHED_MODULATE_ALPHA
	_refresh_begin_button()


func _show_picker_for(character: CharacterData) -> void:
	if _picker == null:
		_picker = EquipmentPicker.new()
		_picker.set_anchors_preset(Control.PRESET_FULL_RECT)
		_detail_host.add_child(_picker)
	_empty_prompt.visible = false
	_picker.visible = true
	_picker.set_character(character)


func _highlight_selected_card() -> void:
	for i: int in range(_character_ids.size()):
		var is_selected: bool = _character_ids[i] == _selected_character_id
		# Keep benched-dim alpha if benched; only swap modulate color tint.
		var deploy_btn: Button = _deploy_buttons[i]
		var benched: bool = not deploy_btn.button_pressed
		var base_alpha: float = BENCHED_MODULATE_ALPHA if benched else 1.0
		_card_buttons[i].modulate = Color(1.2, 1.2, 0.85, base_alpha) if is_selected else Color(1.0, 1.0, 1.0, base_alpha)


func _selected_deployed_ids() -> Array[String]:
	var ids: Array[String] = []
	for i: int in range(_deploy_buttons.size()):
		if _deploy_buttons[i].button_pressed:
			ids.append(_character_ids[i])
	return ids


func _refresh_begin_button() -> void:
	if _begin_button == null:
		return
	_begin_button.disabled = _selected_deployed_ids().is_empty()


# =============================================================================
# BEGIN MISSION
# =============================================================================

func _on_begin_pressed() -> void:
	var campaign_manager: Node = get_node_or_null("/root/CampaignManager")
	if campaign_manager == null or not campaign_manager.is_active():
		push_warning("PrepScreen: no active campaign — returning to start screen")
		get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")
		return
	campaign_manager.set_deployment(_selected_deployed_ids())
	campaign_manager.deploy_to_current_mission()
