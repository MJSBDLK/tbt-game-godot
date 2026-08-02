## Minimal start screen: pick a campaign start level and click Begin.
## MVP scope — unstyled, programmatic UI build. Lawrence will redesign once the
## campaign loop works end-to-end.
class_name StartScreen
extends Control


const CAMPAIGN_MISSIONS: Array[String] = [
	"res://scenes/battle/maps/test_map_01.tscn",
	"res://scenes/battle/maps/test_map_02.tscn",
	"res://scenes/battle/maps/test_map_03.tscn",
]
# Pool of pre-established characters who can join mid-campaign. One is picked
# at random per mission boundary so replays vary. As the roster grows past the
# campaign length, this naturally avoids duplicates within a run (we filter
# already-rostered chars in _build_recruit_list).
const RECRUIT_POOL: Array[String] = [
	"res://data/characters/grasker.json",
	"res://data/characters/gravity_captain.json",
	"res://data/characters/ogre_squire.json",
	# elf_pirate is now in SquadManager.DEFAULT_ROSTER_PATHS (starting squad),
	# so it's deliberately omitted here — the recruit picker doesn't filter
	# against the bootstrapped roster, and re-offering an already-owned unit
	# would burn a recruit slot.
	"res://data/characters/desert_sniper.json",
	"res://data/characters/healer_goblin.json",
	"res://data/characters/healer_plant.json",
	"res://data/characters/plant_cultist.json",
	"res://data/characters/robot.json",
]
const START_LEVEL_OPTIONS: Array[int] = [5, 20, 40, 60]


var _selected_level: int = 5
var _level_buttons: Array[Button] = []
var _begin_button: Button = null
var _save_browser: SaveBrowserPanel = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_content()


func _build_content() -> void:
	var ui_manager: Node = UIManager

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.08, 0.08, 0.12, 1.0)
	add_child(background)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.anchor_left = 0.2
	center.anchor_right = 0.8
	center.anchor_top = 0.25
	center.anchor_bottom = 0.75
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 10)
	add_child(center)

	var title := Label.new()
	title.text = "TBT GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null:
		title.add_theme_font_override("font", ui_manager.font_11px)
		title.add_theme_font_size_override("font_size", 11)
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Start level (disabled — using fixed character levels)"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null:
		subtitle.add_theme_font_override("font", ui_manager.font_8px)
		subtitle.add_theme_font_size_override("font_size", 8)
	center.add_child(subtitle)

	var level_row := HBoxContainer.new()
	level_row.alignment = BoxContainer.ALIGNMENT_CENTER
	level_row.add_theme_constant_override("separation", 4)
	center.add_child(level_row)

	# Buttons are disabled until the move/passive pools are deep enough to
	# support varied start levels. For now CampaignManager uses per-character
	# fixed levels (CHARACTER_START_LEVELS). Flip `button.disabled = false`
	# below to re-enable; the press handler is still connected.
	for level: int in START_LEVEL_OPTIONS:
		var button := Button.new()
		button.text = str(level)
		button.custom_minimum_size = Vector2(32, 18)
		button.toggle_mode = true
		button.disabled = true
		button.pressed.connect(_on_level_button_pressed.bind(level, button))
		level_row.add_child(button)
		_level_buttons.append(button)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	center.add_child(spacer)

	_begin_button = Button.new()
	_begin_button.text = "Begin Campaign"
	_begin_button.custom_minimum_size = Vector2(120, 22)
	_begin_button.pressed.connect(_on_begin_pressed)
	var begin_wrap := HBoxContainer.new()
	begin_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	begin_wrap.add_child(_begin_button)
	center.add_child(begin_wrap)

	_build_continue_button(center, ui_manager)


## "Continue" resumes the NEWEST save across all rings; "Load Game" beside it
## opens the full save browser (every slot, yellow/blue/manual identity).
## Continue's text carries the save's label and slot color. Both hidden when
## no saves exist — dead buttons on a fresh install are noise.
func _build_continue_button(center: VBoxContainer, ui_manager: Node) -> void:
	var saves: Array[Dictionary] = SaveManager.list_saves()
	if saves.is_empty():
		return
	var newest: Dictionary = saves[0]

	var continue_button := Button.new()
	continue_button.text = "Continue — %s" % str(newest.get("label", "saved game"))
	continue_button.custom_minimum_size = Vector2(120, 22)
	if ui_manager != null:
		continue_button.add_theme_font_override("font", ui_manager.font_8px)
		continue_button.add_theme_font_size_override("font_size", 8)
	var kind_color: Color = GameColors.SAVE_AUTO_BATTLE \
			if str(newest.get("kind", "")) == SaveManager.KIND_AUTO_BATTLE \
			else GameColors.SAVE_AUTO_TURN
	continue_button.add_theme_color_override("font_color", kind_color)
	continue_button.add_theme_color_override("font_hover_color", kind_color)
	continue_button.pressed.connect(_on_continue_pressed.bind(str(newest.get("path", ""))))

	var load_button := Button.new()
	load_button.text = "Load Game"
	load_button.custom_minimum_size = Vector2(0, 22)
	if ui_manager != null:
		load_button.add_theme_font_override("font", ui_manager.font_8px)
		load_button.add_theme_font_size_override("font_size", 8)
	load_button.pressed.connect(_on_load_pressed)

	var continue_wrap := HBoxContainer.new()
	continue_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	continue_wrap.add_theme_constant_override("separation", 6)
	continue_wrap.add_child(continue_button)
	continue_wrap.add_child(load_button)
	center.add_child(continue_wrap)


func _on_continue_pressed(save_path: String) -> void:
	if not SaveManager.load_save_and_continue(save_path):
		push_warning("StartScreen: failed to load '%s'" % save_path)


## The browser is lazily built — most sessions never open it here.
func _on_load_pressed() -> void:
	if _save_browser == null:
		_save_browser = SaveBrowserPanel.new()
		_save_browser.set_anchors_preset(Control.PRESET_CENTER)
		_save_browser.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_save_browser.grow_vertical = Control.GROW_DIRECTION_BOTH
		add_child(_save_browser)
		_save_browser.save_chosen.connect(_on_browser_save_chosen)
	_save_browser.show_panel()


func _on_browser_save_chosen(path: String) -> void:
	_save_browser.visible = false
	if not SaveManager.load_save_and_continue(path):
		push_warning("StartScreen: failed to load '%s'" % path)
		_save_browser.show_panel()


func _on_level_button_pressed(level: int, source_button: Button) -> void:
	_select_level(level, source_button)


func _select_level(level: int, source_button: Button) -> void:
	_selected_level = level
	for button: Button in _level_buttons:
		button.button_pressed = (button == source_button)


func _on_begin_pressed() -> void:
	var campaign_manager: Node = get_node_or_null("/root/CampaignManager")
	if campaign_manager == null:
		push_error("StartScreen: CampaignManager autoload missing")
		return
	campaign_manager.start_campaign(_selected_level, CAMPAIGN_MISSIONS, RECRUIT_POOL)
