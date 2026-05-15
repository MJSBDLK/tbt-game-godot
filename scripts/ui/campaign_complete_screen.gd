## Shown when the player finishes the final mission of a campaign. Sits
## between the last PostMissionReport and the StartScreen so the run ends with
## a beat rather than dumping the player back to the menu.
##
## MVP scope — programmatic, unstyled. Lawrence will redesign once the loop
## is locked.
class_name CampaignCompleteScreen
extends Control


const START_SCREEN_PATH: String = "res://scenes/ui/start_screen.tscn"

var _continue_button: Button = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_content()


func _build_content() -> void:
	var ui_manager: Node = UIManager

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.06, 0.10, 0.06, 1.0)
	add_child(background)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.anchor_left = 0.15
	center.anchor_right = 0.85
	center.anchor_top = 0.15
	center.anchor_bottom = 0.85
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 8)
	add_child(center)

	var title := Label.new()
	title.text = "CAMPAIGN COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null:
		title.add_theme_font_override("font", ui_manager.font_11px)
		title.add_theme_font_size_override("font_size", 11)
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Your squad lived to fight another day."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null:
		subtitle.add_theme_font_override("font", ui_manager.font_8px)
		subtitle.add_theme_font_size_override("font_size", 8)
	center.add_child(subtitle)

	var roster_header := Label.new()
	roster_header.text = "Survivors"
	roster_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null:
		roster_header.add_theme_font_override("font", ui_manager.font_8px)
		roster_header.add_theme_font_size_override("font_size", 8)
	center.add_child(roster_header)

	for line: String in _build_roster_lines():
		var entry := Label.new()
		entry.text = line
		entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if ui_manager != null:
			entry.add_theme_font_override("font", ui_manager.font_8px)
			entry.add_theme_font_size_override("font_size", 8)
		center.add_child(entry)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	center.add_child(spacer)

	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size = Vector2(120, 22)
	_continue_button.pressed.connect(_on_continue_pressed)
	var wrap := HBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(_continue_button)
	center.add_child(wrap)


func _build_roster_lines() -> Array[String]:
	var lines: Array[String] = []
	var squad: Node = get_node_or_null("/root/SquadManager")
	if squad == null or not squad.has_method("get_active_roster"):
		return lines
	for character: CharacterData in squad.get_active_roster():
		if character == null:
			continue
		lines.append("%s — Lv %d" % [character.character_name, character.level])
	return lines


func _on_continue_pressed() -> void:
	SceneRouter.change_scene_to(START_SCREEN_PATH)
