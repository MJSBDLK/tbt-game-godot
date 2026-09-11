## SaveBrowserPanel's two modes. LOAD lists every ring newest-first and emits
## save_chosen; OVERWRITE lists the four MANUAL slots in slot order (empty
## ones included) and emits slot_chosen. The overwrite picker is the only
## place a manual save can destroy another one, so its rows must be exactly
## the manual ring and nothing else.
extends GutTest


const TEST_SAVE_ROOT: String = "user://test_saves_browser"

var _pristine_campaign: Dictionary = {}


func before_all() -> void:
	_pristine_campaign = CampaignManager.capture_save_state()
	SaveManager.save_root = TEST_SAVE_ROOT


func before_each() -> void:
	InputSource.last_kind = InputSource.Kind.POINTER
	TurnManager._player_units = ([] as Array[Unit])
	TurnManager._enemy_units = ([] as Array[Unit])
	TurnManager._battle_ended = false
	TurnManager.turn_count = 0
	CampaignManager.restore_save_state({
		"mission_paths": ["res://scenes/maps/map_a.tscn"],
		"recruit_pool": [], "recruited_paths": [],
		"current_mission_index": 0, "start_level": 5, "deployment_selection": [],
	})


func after_each() -> void:
	_wipe_test_saves()


func after_all() -> void:
	CampaignManager.restore_save_state(_pristine_campaign)
	SaveManager.save_root = SaveManager.DEFAULT_SAVE_ROOT
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists(TEST_SAVE_ROOT):
		for kind: String in SaveManager.ALL_KINDS:
			dir.remove(TEST_SAVE_ROOT + "/" + kind)
		dir.remove(TEST_SAVE_ROOT)


func _wipe_test_saves() -> void:
	for kind: String in SaveManager.ALL_KINDS:
		var dir := DirAccess.open("%s/%s" % [TEST_SAVE_ROOT, kind])
		if dir == null:
			continue
		for file_name: String in dir.get_files():
			dir.remove(file_name)


func _stub(created_unix: int, kind: String) -> Dictionary:
	return {
		"save_version": SaveManager.SAVE_VERSION,
		"kind": kind,
		"created_unix": created_unix,
		"label": "stub %d" % created_unix,
	}


func _panel() -> SaveBrowserPanel:
	var panel := SaveBrowserPanel.new()
	add_child_autofree(panel)
	return panel


func _row_texts(panel: SaveBrowserPanel) -> Array[String]:
	var out: Array[String] = []
	for button: Button in panel._row_buttons:
		out.append(button.text)
	return out


func test_load_mode_lists_every_ring_newest_first_and_emits_save_chosen() -> void:
	SaveManager.write_autosave(SaveManager.KIND_AUTO_TURN, _stub(200, SaveManager.KIND_AUTO_TURN))
	SaveManager.write_autosave(SaveManager.KIND_AUTO_BASE, _stub(300, SaveManager.KIND_AUTO_BASE))
	SaveManager.write_autosave(SaveManager.KIND_AUTO_BATTLE, _stub(100, SaveManager.KIND_AUTO_BATTLE))
	var panel := _panel()
	watch_signals(panel)
	panel.show_panel()

	assert_eq(panel.mode, SaveBrowserPanel.Mode.LOAD)
	var texts: Array[String] = _row_texts(panel)
	assert_eq(texts.size(), 4, "three saves + Close")
	assert_string_starts_with(texts[0], "stub 300", "newest first — the base autosave leads")
	assert_string_starts_with(texts[2], "stub 100")
	assert_eq(texts[3], "Close")

	panel._row_buttons[0].pressed.emit()
	assert_signal_emitted_with_parameters(panel, "save_chosen",
			["%s/%s/slot_0.json" % [TEST_SAVE_ROOT, SaveManager.KIND_AUTO_BASE]])
	assert_signal_not_emitted(panel, "slot_chosen", "LOAD never speaks the picker's signal")


func test_overwrite_mode_lists_exactly_the_four_manual_slots_in_order() -> void:
	# Autosaves are NOT offered — evicting one of those isn't the player's
	# decision to make, and offering it would let a manual save land in the
	# wrong ring.
	SaveManager.write_autosave(SaveManager.KIND_AUTO_TURN, _stub(999, SaveManager.KIND_AUTO_TURN))
	var slot_1: String = "%s/%s/slot_1.json" % [TEST_SAVE_ROOT, SaveManager.KIND_MANUAL]
	SaveManager.write_manual_save_to(slot_1)
	var panel := _panel()
	watch_signals(panel)
	panel.show_overwrite_picker()

	assert_eq(panel.mode, SaveBrowserPanel.Mode.OVERWRITE)
	var texts: Array[String] = _row_texts(panel)
	assert_eq(texts.size(), SaveManager.SLOT_COUNT + 1, "four slots + Cancel, never the autosaves")
	assert_eq(texts[0], "Slot 1   (empty)", "empty slots are offered — and numbered from one")
	assert_string_starts_with(texts[1], "Mission 1", "an occupied slot shows its label")
	assert_eq(texts[2], "Slot 3   (empty)")
	assert_eq(texts[4], "Cancel")

	panel._row_buttons[1].pressed.emit()
	assert_signal_emitted_with_parameters(panel, "slot_chosen", [slot_1])
	assert_signal_not_emitted(panel, "save_chosen", "the picker never triggers a load")


func test_overwrite_mode_offers_a_corrupt_slot_as_reclaimable() -> void:
	var slot_2: String = "%s/%s/slot_2.json" % [TEST_SAVE_ROOT, SaveManager.KIND_MANUAL]
	DirAccess.make_dir_recursive_absolute(slot_2.get_base_dir())
	var vandal := FileAccess.open(slot_2, FileAccess.WRITE)
	vandal.store_string("{{{ not json")
	vandal.close()
	var panel := _panel()
	panel.show_overwrite_picker()
	assert_eq(_row_texts(panel)[2], "Slot 3   (unreadable)",
			"the player sees the damaged slot and can choose to reuse it")


func test_cancel_hides_and_emits_closed_without_choosing() -> void:
	var panel := _panel()
	watch_signals(panel)
	panel.show_overwrite_picker()
	panel._row_buttons[SaveManager.SLOT_COUNT].pressed.emit()  # the Cancel row
	assert_false(panel.visible)
	assert_signal_emitted(panel, "closed")
	assert_signal_not_emitted(panel, "slot_chosen", "a cancel names no slot")


func test_reopening_in_the_other_mode_rebuilds_the_rows() -> void:
	# One panel, two modes — stale rows from the other mode would let a Load
	# click land in the picker's handler or vice versa.
	SaveManager.write_autosave(SaveManager.KIND_AUTO_TURN, _stub(200, SaveManager.KIND_AUTO_TURN))
	var panel := _panel()
	panel.show_overwrite_picker()
	assert_eq(_row_texts(panel).size(), SaveManager.SLOT_COUNT + 1)
	panel.hide_panel()
	panel.show_panel()
	assert_eq(_row_texts(panel).size(), 2, "one autosave + Close")
	assert_eq(panel.mode, SaveBrowserPanel.Mode.LOAD)


func test_cursor_driven_open_lands_the_cursor_on_the_first_row() -> void:
	# Plain Buttons have no other entry point for a pad; a pointer open stays
	# quiet (InputSource doctrine).
	SaveManager.write_autosave(SaveManager.KIND_AUTO_TURN, _stub(200, SaveManager.KIND_AUTO_TURN))
	var panel := _panel()
	panel.show_panel()
	await wait_frames(1)
	assert_false(panel._row_buttons[0].has_focus(), "pointer open: no phantom cursor")

	InputSource.last_kind = InputSource.Kind.CURSOR
	panel.hide_panel()
	panel.show_panel()
	await wait_frames(1)
	assert_true(panel._row_buttons[0].has_focus(), "cursor open: the first row takes focus")
