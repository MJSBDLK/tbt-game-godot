## The INTERMISSION HUB — screen 2a of the redesign arc
## ([.claude/intermission.md] §2). Second screen ported from the mockup, after
## StartScreen; it deliberately reuses that screen's two components rather than
## growing its own chrome.
##
## SAME STAGE, TWO ROLES (locked RQD 2026-08-03). The main menu and this screen
## are separate screens wearing the same MenuStageBackdrop. The menu is
## out-of-fiction (New / Continue / Options / Quit); the hub is crew management
## between missions.
##
## VENUE RULE (§2). The hub is the MENUS venue — bare glowing text, corner
## ticks, one lit-border default action, no panel plate. The workspaces it opens
## (Manage Units, Briefing) are the HUD venue — glass panels and the full button
## vocabulary. Bare text needs a quiet ground to read against; dense data needs a
## plate to sit on.
##
## WHY A NEARLY-EMPTY SCREEN EXISTS AT ALL (RQD 2026-08-04). It was nearly cut
## for redundancy — every entry here could live inside Manage Units. It stays
## because the emptiness is doing PACING work: a quiet beat between the battle
## and the spreadsheet. Role compression into Manage Units is still the goal,
## but it compresses within the workspace, never by eating the hub.
##
## SUB-LINES ARE LIVE, NOT DECORATION. Deploy someone, spend a StatUp, buy a
## level, and they follow. Deployment always reads `deployed/cap`, never a bare
## count — the cap is half the information. The resource is a "StatUp", never
## "unspent stat-up points" (RQD round 11); `★N` survives only as the compact
## roster-card glyph where the word doesn't fit.
##
## UNFINISHED BUSINESS IS ADVERTISED, NEVER ENFORCED. Begin Mission is never
## blocked or confirmed because StatUps are unspent — the badge is the nudge.
## A "are you sure? you have points left" dialog is exactly the nag this
## project doesn't ship (squad_manager.md §6, no-confirmations rule).
class_name IntermissionHub
extends Control


const COLUMN_LEFT_MARGIN: int = 28
const EYEBROW_GAP: int = 10
const ENTRY_GAP: int = 4
## Visual separation between the task entries and the system tail.
const TAIL_GAP: int = 12

## Manage Units is the destination for both the direct entry and the bEXP
## deep-link. Still the pre-redesign prep screen — slice 3 of the port replaces
## it with the three-column workspace, and this constant is the only thing that
## has to move when it does.
const MANAGE_UNITS_PATH: String = "res://scenes/ui/prep_screen.tscn"
const START_SCREEN_PATH: String = "res://scenes/ui/start_screen.tscn"


var _menu_entries: Array[MainMenuEntry] = []
var _default_entry: MainMenuEntry = null
var _manage_entry: MainMenuEntry = null
var _bexp_entry: MainMenuEntry = null
var _save_entry: MainMenuEntry = null

## Save Game arrives ARMED. Verified 2026-08-04 and still true: autosaves are
## battle-only — SaveManager writes on `player_phase_started` and early-returns
## when capture_battle_snapshot() is empty, and CampaignManager never saves at
## all. A base-autosave ring is decided but unbuilt (§2c), so arriving at the
## hub genuinely means there is unsaved progress.
var _dirty: bool = true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_content()
	# The pool moves from inside Manage Units, so the hub can't assume its
	# sub-lines are still true when it regains focus.
	SquadManager.bonus_xp_changed.connect(_on_squad_state_changed)


# =============================================================================
# SUB-LINE TEXT — pure, so the copy rules are testable without a viewport
# =============================================================================

## `4/5 deployed` alone, or `4/5 deployed · 3 StatUp` when something is unspent.
## The StatUp clause is omitted rather than shown as zero: a badge that is
## always present stops being a nudge.
static func deploy_sub_line(deployed: int, cap: int, unspent_statups: int) -> String:
	var line: String = "%d/%d deployed" % [deployed, cap]
	if unspent_statups > 0:
		line += " · %d StatUp" % unspent_statups
	return line


## The bare number — the parent label already carries the noun (RQD round 11).
static func bexp_sub_line(pool: int) -> String:
	return str(pool) if pool > 0 else "nothing banked yet"


static func briefing_sub_line(objective_count: int) -> String:
	if objective_count <= 0:
		return "no objectives listed"
	return "%d objective%s" % [objective_count, "" if objective_count == 1 else "s"]


## `Mission 2 of 3`. Index is 0-based coming in; players count from one.
static func eyebrow_text(mission_index: int, mission_count: int) -> String:
	if mission_count <= 0:
		return "Between missions"
	return "Mission %d of %d" % [mission_index + 1, mission_count]


# =============================================================================
# LIVE STATE READS
# =============================================================================

## Squad cap is MAP-DERIVED — the number of player spawn tiles on the mission
## about to be played, not a config value. Two maps can want different squad
## sizes and neither needs a setting.
func _squad_cap() -> int:
	if not CampaignManager.is_active():
		return 0
	return TilemapGridBuilder.count_player_spawns(CampaignManager.get_current_mission_path())


## Deployment lives in CampaignManager, but nothing writes it until the player
## visits Manage Units — so on first arrival at a mission it is empty and the
## honest reading is "everyone the cap allows is coming".
func _deployed_count() -> int:
	var chosen: int = CampaignManager.get_deployment().size()
	if chosen > 0:
		return chosen
	return mini(SquadManager.get_active_roster().size(), _squad_cap())


func _unspent_statups() -> int:
	var total: int = 0
	for character: CharacterData in SquadManager.get_active_roster():
		total += maxi(0, character.available_stat_ups - character.allocated_total())
	return total


func _objective_count() -> int:
	if not CampaignManager.is_active():
		return 0
	var entry: Dictionary = MissionCatalog.entry_for(CampaignManager.get_current_mission_path())
	return (entry.get("objectives", []) as Array).size()


# =============================================================================
# BUILD
# =============================================================================

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

	# Eyebrow, in the INFO voice — where you are in the campaign. Takes the
	# slot the main menu gives its title: this screen has no logo, because it
	# is inside the fiction.
	var eyebrow := GlowLabel.new()
	eyebrow.text = eyebrow_text(CampaignManager.get_current_mission_index(),
			CampaignManager.get_mission_count())
	eyebrow.material = MainMenuEntry.GLOW_MATERIAL.duplicate()
	eyebrow.glow_color = GameColors.TEXT_INFO_GLOW
	if UIManager.font_8px != null:
		eyebrow.add_theme_font_override("font", UIManager.font_8px)
	eyebrow.add_theme_font_size_override("font_size", 8)
	eyebrow.add_theme_color_override("font_color", GameColors.TEXT_INFO)
	column.add_child(eyebrow)
	column.add_child(_spacer(EYEBROW_GAP))

	# Task order, top to bottom — then the system tail behind a gap.
	_manage_entry = _add_entry(column, "Manage Units", "", _on_manage_pressed)
	_bexp_entry = _add_entry(column, "Allocate Bonus EXP", "", _on_bexp_pressed)
	_add_entry(column, "Mission Briefing", briefing_sub_line(_objective_count()),
			_on_briefing_pressed)
	_default_entry = _add_entry(column, "Begin Mission", "", _on_begin_pressed)
	_default_entry.is_default_action = true

	column.add_child(_spacer(TAIL_GAP))
	_save_entry = _add_entry(column, "Save Game", "", _on_save_pressed)
	_add_entry(column, "Options", "", UIManager.show_options_menu)
	_add_entry(column, "Quit to Menu", "", _on_quit_to_menu_pressed)

	_refresh_entries()
	_wire_focus_chain()

	if InputSource.is_cursor_driven():
		_default_entry.grab_focus.call_deferred()


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


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
	var focusable: Array[MainMenuEntry] = []
	for entry: MainMenuEntry in _menu_entries:
		if not entry.inert:
			focusable.append(entry)
	for i: int in focusable.size():
		var entry := focusable[i]
		var up := focusable[(i - 1 + focusable.size()) % focusable.size()]
		var down := focusable[(i + 1) % focusable.size()]
		entry.focus_neighbor_top = entry.get_path_to(up)
		entry.focus_neighbor_bottom = entry.get_path_to(down)
		entry.focus_next = entry.get_path_to(down)
		entry.focus_previous = entry.get_path_to(up)


# =============================================================================
# REFRESH
# =============================================================================

## Rebuilds every live sub-line. Cheap enough to just call on any state change
## rather than tracking which entry each mutation touches.
func _refresh_entries() -> void:
	if _manage_entry != null:
		_set_sub_text(_manage_entry, deploy_sub_line(
				_deployed_count(), _squad_cap(), _unspent_statups()))
	if _bexp_entry != null:
		var pool: int = SquadManager.bonus_xp_pool
		_set_sub_text(_bexp_entry, bexp_sub_line(pool))
		# Inert at zero — there is nothing to allocate, and §14 says an entry
		# whose press would do nothing shouldn't look pressable.
		_bexp_entry.inert = pool <= 0
		_bexp_entry.focus_mode = Control.FOCUS_NONE if _bexp_entry.inert else Control.FOCUS_ALL
	_refresh_save_entry()


## §2b: after a save the entry reads "Game saved!" in the success voice with an
## unlit border, until something changes. Two locked vocabularies composing
## instead of a toast — success colour says *it worked*, unlit border says
## *nothing to press*.
func _refresh_save_entry() -> void:
	if _save_entry == null:
		return
	_set_main_text(_save_entry, "Save Game" if _dirty else "Game saved!")
	_save_entry.inert = not _dirty
	_save_entry.focus_mode = Control.FOCUS_NONE if _save_entry.inert else Control.FOCUS_ALL
	if _save_entry._main_label != null:
		_save_entry._main_label.add_theme_color_override("font_color",
				GameColors.TEXT_PRIMARY if _dirty else GameColors.TEXT_SUCCESS)
		_save_entry._main_label.glow_color = \
				GameColors.TEXT_PRIMARY_GLOW if _dirty else GameColors.TEXT_SUCCESS_GLOW


func _set_sub_text(entry: MainMenuEntry, value: String) -> void:
	entry.sub_text = value
	if entry._sub_label != null:
		entry._sub_label.text = value


func _set_main_text(entry: MainMenuEntry, value: String) -> void:
	entry.text = value
	if entry._main_label != null:
		entry._main_label.text = value


func _on_squad_state_changed(_new_pool: int) -> void:
	_dirty = true
	_refresh_entries()


# =============================================================================
# HANDLERS
# =============================================================================

func _on_manage_pressed() -> void:
	SceneRouter.change_scene_to(MANAGE_UNITS_PATH)


## A DEEP LINK, not a second screen (§3g): it opens Manage Units already
## focused on the bEXP task. The preselection itself lands in slice 3, when
## Manage Units gains a level row to preselect.
func _on_bexp_pressed() -> void:
	SceneRouter.change_scene_to(MANAGE_UNITS_PATH)


func _on_briefing_pressed() -> void:
	# §5 Mission Briefing is not built yet. Manage Units is the honest
	# destination in the meantime — better than a dead entry.
	SceneRouter.change_scene_to(MANAGE_UNITS_PATH)


## Only latches on an actual write. write_manual_save() returns "" when there
## is no active campaign or the disk write fails — latching regardless would
## put "Game saved!" on screen for a save that doesn't exist, which is the one
## lie a save button must never tell.
func _on_save_pressed() -> void:
	if not _dirty:
		return
	if SaveManager.write_manual_save() != "":
		_dirty = false
	_refresh_save_entry()


## Deployment is written by Manage Units, but the player can press Begin
## without ever opening it. Seeding from the roster keeps that path working —
## the same set the sub-line has been advertising all along. Slice 2 moves
## deploy state into the roster rail and this bridge goes away.
func _on_begin_pressed() -> void:
	if not CampaignManager.is_active():
		push_warning("IntermissionHub: no active campaign — returning to start screen")
		SceneRouter.change_scene_to(START_SCREEN_PATH)
		return
	if CampaignManager.get_deployment().is_empty():
		CampaignManager.set_deployment(default_deployment(
				SquadManager.get_active_roster(), _squad_cap()))
	CampaignManager.deploy_to_current_mission()


## First `cap` characters of the roster, in roster order. Pure so the fallback
## can be tested without a campaign.
static func default_deployment(roster: Array[CharacterData], cap: int) -> Array[String]:
	var ids: Array[String] = []
	for character: CharacterData in roster:
		if ids.size() >= cap:
			break
		ids.append(character.character_id)
	return ids


func _on_quit_to_menu_pressed() -> void:
	SceneRouter.change_scene_to(START_SCREEN_PATH)


## First nav press with nothing focused SUMMONS the cursor — at the hovered
## entry if the pointer was resting on one, else at the default action.
## Copied deliberately from StartScreen: this is InputSource doctrine, and the
## two screens must not disagree about it.
func _unhandled_input(event: InputEvent) -> void:
	if not InputSource.is_navigation_press(event):
		return
	for entry: MainMenuEntry in _menu_entries:
		if entry.has_focus():
			return
	var summon_target: MainMenuEntry = _default_entry
	for entry: MainMenuEntry in _menu_entries:
		if entry._hovered and not entry.inert:
			summon_target = entry
			break
	summon_target.grab_focus()
	get_viewport().set_input_as_handled()
