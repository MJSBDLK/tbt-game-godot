## The Metastable main menu port (intermission redesign, screen 1) + the
## semantic color lock. Pins: the four-voice color set and its halo-
## temperature doctrine, the CTA-follows-default ordering, the two-line
## Continue, the CTA yield rule, and the screenshot-path derivation for the
## save-aware backdrop.
extends GutTest


var _pristine_campaign: Dictionary = {}


func before_all() -> void:
	# Same isolation as test_battle_save: scratch save dir, campaign forced
	# inactive so nothing routes scenes or writes real rings. Wipe on entry
	# too — a crashed or interrupted earlier run leaves files on real disk,
	# and the fresh-install test's whole premise is an empty root.
	_pristine_campaign = CampaignManager.capture_save_state()
	CampaignManager.restore_save_state({})
	SaveManager.save_root = "user://test_saves_menu"
	_wipe_scratch_saves()


func after_all() -> void:
	CampaignManager.restore_save_state(_pristine_campaign)
	SaveManager.save_root = SaveManager.DEFAULT_SAVE_ROOT


func after_each() -> void:
	_wipe_scratch_saves()
	InputSource.last_kind = InputSource.Kind.POINTER


func _wipe_scratch_saves() -> void:
	# Saves nest one level per ring kind (save_root/auto_turn/slot_0.json) —
	# a flat get_files() wipe silently misses everything (the bug that let a
	# solo run's fake save pollute the next full-suite run).
	var root := DirAccess.open(SaveManager.save_root)
	if root == null:
		return
	for file_name: String in root.get_files():
		root.remove(file_name)
	for dir_name: String in root.get_directories():
		var kind_dir := DirAccess.open("%s/%s" % [SaveManager.save_root, dir_name])
		if kind_dir == null:
			continue
		for file_name: String in kind_dir.get_files():
			kind_dir.remove(file_name)


func _write_fake_save(label: String) -> void:
	SaveManager.write_save_file(SaveManager._slot_path(SaveManager.KIND_AUTO_TURN, 0), {
		"save_version": SaveManager.SAVE_VERSION,
		"kind": SaveManager.KIND_AUTO_TURN,
		"created_unix": 1000,
		"label": label,
	})


func _spawn_menu() -> StartScreen:
	var screen: StartScreen = (load("res://scenes/ui/start_screen.tscn")
			as PackedScene).instantiate() as StartScreen
	add_child_autofree(screen)
	return screen


func _entry_texts(screen: StartScreen) -> Array:
	var texts: Array = []
	for entry: MainMenuEntry in screen._menu_entries:
		texts.append(entry.text)
	return texts


# =============================================================================
# SEMANTIC COLORS — the four-voice lock (ui-style-guide §2)
# =============================================================================

func test_semantic_color_set_is_locked_to_the_palette() -> void:
	assert_eq(GameColors.TEXT_INFO, GameColorPalette.get_color("YellowOrange", 7),
			"info = banana gold — deliberately yellow, azure+gold is the house harmony")
	assert_eq(GameColors.TEXT_INFO_GLOW, GameColorPalette.get_color("YellowOrange", 4),
			"info's halo stays in its own ramp — the quiet gold")
	assert_eq(GameColors.TEXT_WARNING, GameColorPalette.get_color("YellowOrange", 6),
			"warning fill sits one ramp step below info")
	assert_eq(GameColors.TEXT_WARNING_GLOW, GameColorPalette.get_color("Red", 4),
			"warning's halo is HOT — inherits the status-text pairing; the glow is the differentiator")


# =============================================================================
# MENU ORDER + CTA-FOLLOWS-DEFAULT
# =============================================================================

func test_fresh_install_menu_has_no_continue_and_new_campaign_takes_the_cta() -> void:
	var screen := _spawn_menu()
	assert_eq(_entry_texts(screen), ["New Campaign", "Options", "Quit"],
			"no saves: Continue/Load hidden entirely — dead buttons are noise")
	assert_eq(screen._cta_entry, screen._new_campaign_entry,
			"the default action inherits the rings on a fresh install")
	assert_true(screen._new_campaign_entry.call_to_action)


func test_saves_put_continue_on_top_wearing_the_cta_and_its_label() -> void:
	_write_fake_save("Mission 1, Turn 2")
	var screen := _spawn_menu()
	assert_eq(_entry_texts(screen),
			["Continue", "New Campaign", "Load Game", "Options", "Quit"],
			"returning player: Continue first, Load available")
	assert_eq(screen._cta_entry, screen._continue_entry,
			"Continue is the default action when a save exists")
	assert_eq(screen._continue_entry.sub_text, "Mission 1, Turn 2",
			"the save label rides line 2 in the INFO voice")


# =============================================================================
# CTA YIELD — rings mark the default, not the player's position
# =============================================================================

func test_cta_yields_while_focus_rests_elsewhere_and_returns_home() -> void:
	_write_fake_save("Mission 1, Turn 2")
	var screen := _spawn_menu()
	InputSource.last_kind = InputSource.Kind.CURSOR

	screen._new_campaign_entry.grab_focus()
	screen._update_cta_yield()
	assert_true(screen._continue_entry.cta_suppressed,
			"aim on another entry: the rings vanish")

	screen._continue_entry.grab_focus()
	screen._update_cta_yield()
	assert_false(screen._continue_entry.cta_suppressed,
			"aim back on the default: the rings return")


func test_one_aim_one_model_hover_only_counts_under_the_pointer_model() -> void:
	_write_fake_save("Mission 1, Turn 2")
	var screen := _spawn_menu()
	screen._new_campaign_entry._hovered = true

	InputSource.last_kind = InputSource.Kind.POINTER
	assert_true(screen._new_campaign_entry.is_aimed(),
			"pointer model: hover owns the mark")

	InputSource.last_kind = InputSource.Kind.CURSOR
	assert_false(screen._new_campaign_entry.is_aimed(),
			"cursor model: the same hover is IGNORED — no two-cursors bug")
	screen._continue_entry.grab_focus()
	assert_true(screen._continue_entry.is_aimed(),
			"cursor model: focus owns the mark instead")


# =============================================================================
# SAVE-AWARE BACKDROP PLUMBING
# =============================================================================

func test_screenshot_path_is_the_save_sibling() -> void:
	assert_eq(SaveManager.screenshot_path_for("user://saves/auto_turn_1.json"),
			"user://saves/auto_turn_1.png",
			"ring-slot reuse overwrites the sibling too — stale shots self-heal")


func test_backdrop_final_fallback_is_flat_glass() -> void:
	# Resolution order: save screenshot → Lawrence's art file → flat glass.
	# With no saves, the stage shows the art if it has landed, else the bare
	# eggshell base — either way, never a programmer-art placeholder.
	var backdrop := MenuStageBackdrop.new()
	add_child_autofree(backdrop)
	if ResourceLoader.exists(MenuStageBackdrop.SHIP_INTERIOR_PATH):
		assert_not_null(backdrop._backdrop.texture, "Lawrence's art landed — stage wears it")
	else:
		assert_null(backdrop._backdrop.texture,
				"no screenshot, no art file: no texture at all")
	assert_eq(backdrop._base.color,
			GameColors.with_alpha(GameColors.HUD_PANEL_BACKGROUND, 1.0),
			"the stage floor is always the glass color — dark eggshell, opaque")
