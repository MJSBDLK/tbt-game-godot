## The METASTABLE main menu — first screen of the intermission redesign
## (RQD 2026-08-03 mockup arc; see the design record in ui-style-guide §2
## "Semantic colors" + §14 "Menus venue").
##
## Locked decisions this screen embodies:
##  - "Same stage, two roles": this menu and the between-mission screens are
##    separate screens sharing MenuStageBackdrop (save-aware "Black Mesa"
##    backdrop: newest save's screenshot, ship interior on fresh install).
##  - Bare-text chrome: free-floating MainMenuEntry rows, left-justified
##    column, no panel plate. Corner ticks = you are here; converging rings
##    = the default action, WITH the yield rule (_update_cta_yield).
##  - The CTA follows the default action: Continue on top when saves exist,
##    New Campaign otherwise (Continue/Load hidden entirely with no saves).
##  - Continue is two-line: "Continue" + the save label in the INFO voice.
##  - No subtitle, ever. The title text is the slot the eventual logo art
##    drops into. "Metastable" is a WORKING title — repo stays tbt-game.
##  - Start-level select AXED from the menu (RQD 2026-08-03 round 8) — the
##    feature itself is still undecided, but it has no UI presence; if it
##    returns it comes back as a designed row, not a locked stub.
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
const GAME_TITLE: String = "METASTABLE"
const COLUMN_LEFT_MARGIN: int = 28
const TITLE_GAP: int = 18
const ENTRY_GAP: int = 4

var _selected_level: int = 5
var _save_browser: SaveBrowserPanel = null

var _menu_entries: Array[MainMenuEntry] = []
var _cta_entry: MainMenuEntry = null
var _continue_entry: MainMenuEntry = null
var _new_campaign_entry: MainMenuEntry = null
var _load_entry: MainMenuEntry = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_window().title = "Metastable"
	_build_content()


func _process(_delta: float) -> void:
	_update_cta_yield()


func _build_content() -> void:
	add_child(MenuStageBackdrop.new())

	var column_margin := MarginContainer.new()
	column_margin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	column_margin.add_theme_constant_override("margin_left", COLUMN_LEFT_MARGIN)
	add_child(column_margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", ENTRY_GAP)
	column_margin.add_child(column)

	# The lockup: logo alone, air below (no-subtitle doctrine). 22px = the
	# 11px pixel font at a crisp 2× integer.
	var title := GlowLabel.new()
	title.text = GAME_TITLE
	title.material = MainMenuEntry.GLOW_MATERIAL.duplicate()
	title.glow_color = GameColors.TEXT_PRIMARY_GLOW
	if UIManager.font_11px != null:
		title.add_theme_font_override("font", UIManager.font_11px)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	column.add_child(title)
	var title_gap := Control.new()
	title_gap.custom_minimum_size = Vector2(0, TITLE_GAP)
	column.add_child(title_gap)

	# Menu entries — CTA follows the default action: Continue when saves
	# exist (on top), New Campaign on a fresh install. Continue/Load hidden
	# entirely with no saves: dead buttons on a fresh install are noise.
	var saves: Array[Dictionary] = SaveManager.list_saves()
	if not saves.is_empty():
		var newest: Dictionary = saves[0]
		_continue_entry = _add_entry(column, "Continue",
				str(newest.get("label", "saved game")),
				_on_continue_pressed.bind(str(newest.get("path", ""))))
	_new_campaign_entry = _add_entry(column, "New Campaign", "", _on_begin_pressed)
	if not saves.is_empty():
		_load_entry = _add_entry(column, "Load Game", "", _on_load_pressed)
	_add_entry(column, "Options", "", UIManager.show_options_menu)
	_add_entry(column, "Quit", "", _on_quit_pressed)

	_cta_entry = _continue_entry if _continue_entry != null else _new_campaign_entry
	_cta_entry.call_to_action = true
	_wire_focus_chain()

	# Cursor-driven arrivals get the cursor on the default action; pointer
	# arrivals open quiet (InputSource doctrine — first nav press summons).
	if InputSource.is_cursor_driven():
		_cta_entry.grab_focus.call_deferred()


func _add_entry(column: VBoxContainer, entry_text: String, entry_sub: String,
		handler: Callable) -> MainMenuEntry:
	var entry := MainMenuEntry.new()
	entry.text = entry_text
	entry.sub_text = entry_sub
	entry.pressed.connect(handler)
	entry.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(entry)
	_menu_entries.append(entry)
	return entry


func _wire_focus_chain() -> void:
	for i: int in _menu_entries.size():
		var entry := _menu_entries[i]
		var up := _menu_entries[(i - 1 + _menu_entries.size()) % _menu_entries.size()]
		var down := _menu_entries[(i + 1) % _menu_entries.size()]
		entry.focus_neighbor_top = entry.get_path_to(up)
		entry.focus_neighbor_bottom = entry.get_path_to(down)
		entry.focus_next = entry.get_path_to(down)
		entry.focus_previous = entry.get_path_to(up)


## CTA YIELD (§14): the rings mark the DEFAULT action, not the player's
## position — they vanish while aim (hover under the pointer model, focus
## under the cursor model) rests on any OTHER entry, and return when aim
## comes home or goes idle. Sampled per frame: model flips have no signal,
## and sampling at draw time is the no-flicker way.
func _update_cta_yield() -> void:
	if _cta_entry == null:
		return
	var aimed: MainMenuEntry = null
	for entry: MainMenuEntry in _menu_entries:
		if entry.is_aimed():
			aimed = entry
			break
	_cta_entry.cta_suppressed = aimed != null and aimed != _cta_entry


## First nav press with nothing focused SUMMONS the cursor — at the hovered
## entry if the pointer was resting on one, else at the default action.
## (InputSource has already flipped to cursor model by the time this runs,
## so we read the raw hover flag, not is_aimed.)
func _unhandled_input(event: InputEvent) -> void:
	if not InputSource.is_navigation_press(event):
		return
	for entry: MainMenuEntry in _menu_entries:
		if entry.has_focus():
			return
	var summon_target: MainMenuEntry = _cta_entry
	for entry: MainMenuEntry in _menu_entries:
		if entry._hovered:
			summon_target = entry
			break
	summon_target.grab_focus()
	get_viewport().set_input_as_handled()


# =============================================================================
# HANDLERS (campaign wiring unchanged from the pre-redesign screen)
# =============================================================================

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


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_begin_pressed() -> void:
	var campaign_manager: Node = get_node_or_null("/root/CampaignManager")
	if campaign_manager == null:
		push_error("StartScreen: CampaignManager autoload missing")
		return
	campaign_manager.start_campaign(_selected_level, CAMPAIGN_MISSIONS, RECRUIT_POOL)
