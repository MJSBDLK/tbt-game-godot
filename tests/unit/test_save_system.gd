## Save system stage 2: campaign-layer serialization + SaveManager disk I/O.
##
## The two load-bearing properties:
##   1. Facts round-trip THROUGH JSON TEXT — every capture is stringified and
##      re-parsed before restoring, because JSON turns ints into floats and a
##      restore that only works on the in-memory dict is a lie.
##   2. Restore = reconstruct-then-layer: characters reload fresh from their
##      authored JSON and saved deltas apply on top (injury modifiers are
##      recomputed, never trusted from the file).
##
## SquadManager is a live autoload with a bootstrapped roster — every test
## that touches it restores the pristine capture in after_each, using the
## save system itself as its own cleanup tool.
extends GutTest


const TEST_SAVE_ROOT: String = "user://test_saves"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"

var _pristine_squad: Dictionary = {}
var _pristine_campaign: Dictionary = {}


func before_all() -> void:
	_pristine_squad = SquadManager.capture_save_state()
	_pristine_campaign = CampaignManager.capture_save_state()
	SaveManager.save_root = TEST_SAVE_ROOT


func after_each() -> void:
	SquadManager.restore_save_state(_json_round_trip(_pristine_squad))
	CampaignManager.restore_save_state(_pristine_campaign)
	Settings.seeded_reload = true
	_wipe_test_saves()


func after_all() -> void:
	SaveManager.save_root = SaveManager.DEFAULT_SAVE_ROOT
	_wipe_test_saves()
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists(TEST_SAVE_ROOT):
		for kind: String in [SaveManager.KIND_AUTO_BATTLE, SaveManager.KIND_AUTO_TURN, SaveManager.KIND_MANUAL]:
			dir.remove(TEST_SAVE_ROOT + "/" + kind)
		dir.remove(TEST_SAVE_ROOT)


## Every capture crosses JSON TEXT before restoring — the honest round trip.
func _json_round_trip(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data)) as Dictionary


func _wipe_test_saves() -> void:
	for kind: String in [SaveManager.KIND_AUTO_BATTLE, SaveManager.KIND_AUTO_TURN, SaveManager.KIND_MANUAL]:
		var dir_path: String = "%s/%s" % [TEST_SAVE_ROOT, kind]
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file_name: String in dir.get_files():
			dir.remove(file_name)


func _make_injury(id: String, severity: Enums.InjurySeverity, battles: int) -> Injury:
	var injury := Injury.new()
	injury.injury_id = id
	injury.severity = severity
	injury.battles_remaining = battles
	return injury


# =============================================================================
# CHARACTER DATA ROUND TRIP
# =============================================================================

func test_character_deltas_round_trip_through_json() -> void:
	var original: CharacterData = CharacterDataLoader.load_character(SPACEMAN_PATH)
	original.simulate_levels_up_to(5)
	original.experience = 42
	original.allocated_strength = 2
	original.available_stat_ups = 3
	original.current_injuries.append(_make_injury("burn_scar", Enums.InjurySeverity.MINOR, 2))
	original.pending_injuries.append(_make_injury("wound_chivalric", Enums.InjurySeverity.MAJOR, 8))
	InjurySystem.recalculate_injury_modifiers(original)
	if not original.equipped_moves.is_empty():
		original.equipped_moves[0].current_uses = 1

	var restored: CharacterData = CharacterDataLoader.load_character(SPACEMAN_PATH)
	restored.apply_save_dict(_json_round_trip(original.to_save_dict()))

	assert_eq(restored.level, 5, "level restores")
	assert_eq(restored.experience, 42, "experience restores")
	assert_eq(restored.allocated_strength, 2, "stat allocation restores")
	assert_eq(restored.available_stat_ups, 3, "unspent pool restores")
	for stat: String in ["hp", "strength", "defense", "agility"]:
		var field: String = "growth_gains_%s" % stat
		assert_eq(int(restored.get(field)), int(original.get(field)),
			"%s (rolled growths) restores exactly" % field)

	assert_eq(restored.current_injuries.size(), 1, "committed injury restores")
	assert_eq(restored.current_injuries[0].injury_id, "burn_scar")
	assert_eq(restored.current_injuries[0].battles_remaining, 2)
	assert_eq(restored.pending_injuries.size(), 1, "pending injury restores")
	assert_eq(restored.pending_injuries[0].severity, Enums.InjurySeverity.MAJOR)
	assert_eq(restored.injury_modifier_strength, original.injury_modifier_strength,
		"injury modifiers are RECOMPUTED from restored injuries, matching the original")
	assert_eq(restored.strength, original.strength,
		"effective strength (base + growth + alloc − injury) matches")

	assert_eq(restored.equipped_moves.size(), original.equipped_moves.size(), "move count restores")
	if not original.equipped_moves.is_empty():
		assert_eq(restored.equipped_moves[0].move_name, original.equipped_moves[0].move_name)
		assert_eq(restored.equipped_moves[0].current_uses, 1, "depleted PP restores")
	assert_eq(restored.equipped_passives, original.equipped_passives, "passives restore")


func test_unknown_saved_move_is_dropped_not_fatal() -> void:
	var character: CharacterData = CharacterDataLoader.load_character(SPACEMAN_PATH)
	var save: Dictionary = character.to_save_dict()
	save["equipped_moves"] = [{"name": "Move That Got Deleted In A Rebalance", "current_uses": 3}]
	character.apply_save_dict(_json_round_trip(save))
	assert_eq(character.equipped_moves.size(), 0,
		"a move no longer in the bank drops with a warning instead of crashing the load")


# =============================================================================
# SQUAD / CAMPAIGN ROUND TRIPS
# =============================================================================

func test_squad_state_round_trips_through_json() -> void:
	var spaceman: CharacterData = SquadManager.get_character_by_id("spaceman")
	assert_not_null(spaceman, "bootstrapped roster has spaceman")
	spaceman.simulate_levels_up_to(3)
	SquadManager.bonus_xp_pool = 77
	var ernesto: CharacterData = SquadManager.get_character_by_id("ernesto")
	SquadManager.mark_permadead(ernesto)

	var snapshot: Dictionary = _json_round_trip(SquadManager.capture_save_state())

	# Trash everything, then restore from the snapshot.
	SquadManager.restore_save_state({})
	assert_eq(SquadManager.get_active_roster().size(), 0, "wipe emptied the roster")
	SquadManager.restore_save_state(snapshot)

	var restored_spaceman: CharacterData = SquadManager.get_character_by_id("spaceman")
	assert_not_null(restored_spaceman, "spaceman survives the round trip")
	assert_eq(restored_spaceman.level, 3, "spaceman's level survives")
	assert_eq(SquadManager.bonus_xp_pool, 77, "bEXP pool survives")
	assert_true(SquadManager.is_permadead("ernesto"), "permadeath survives")
	assert_null(SquadManager.get_character_by_id("ernesto"), "the dead stay out of the roster")
	assert_not_null(SquadManager.get_character_by_id("maam"), "the living all come back")


func test_campaign_state_round_trips_through_json() -> void:
	var state: Dictionary = {
		"mission_paths": ["res://scenes/maps/map_a.tscn", "res://scenes/maps/map_b.tscn"],
		"recruit_pool": ["res://data/characters/robot.json"],
		"recruited_paths": ["res://data/characters/robot.json"],
		"current_mission_index": 1,
		"start_level": 11,
		"deployment_selection": ["spaceman", "maam"],
	}
	CampaignManager.restore_save_state(_json_round_trip(state))
	var captured: Dictionary = CampaignManager.capture_save_state()

	assert_eq(captured["current_mission_index"], 1)
	assert_eq(captured["start_level"], 11)
	assert_eq(captured["mission_paths"], state["mission_paths"])
	assert_eq(captured["recruited_paths"], state["recruited_paths"])
	assert_eq(captured["deployment_selection"], state["deployment_selection"])
	assert_true(bool(captured["deployment_chosen"]),
			"a non-empty selection is chosen — the flag rides along")
	assert_true(CampaignManager.is_active(), "index 1 of 2 missions = active campaign")


func test_a_benched_everyone_deployment_survives_the_round_trip() -> void:
	# RQD 2026-08-16: 0/N is a real state. Without the flag an empty list
	# would reload as "unset" and the hub would re-seed the first cap.
	CampaignManager.restore_save_state(_json_round_trip({
		"mission_paths": ["res://scenes/maps/map_a.tscn"],
		"recruit_pool": [], "recruited_paths": [],
		"current_mission_index": 0, "start_level": 5,
		"deployment_selection": [], "deployment_chosen": true,
	}))
	assert_true(CampaignManager.has_deployment(), "chosen…")
	assert_eq(CampaignManager.get_deployment().size(), 0, "…and empty: nobody deploys")
	assert_true(bool(CampaignManager.capture_save_state()["deployment_chosen"]))


func test_a_legacy_save_without_the_flag_reads_empty_as_unset() -> void:
	# Saves from before the split carry no deployment_chosen; their empty
	# list WAS the everyone-sentinel, so it must stay "unset" — not become
	# an unlaunchable 0/N on load.
	CampaignManager.restore_save_state(_json_round_trip({
		"mission_paths": ["res://scenes/maps/map_a.tscn"],
		"recruit_pool": [], "recruited_paths": [],
		"current_mission_index": 0, "start_level": 5,
		"deployment_selection": [],
	}))
	assert_false(CampaignManager.has_deployment(), "legacy empty = unset = everyone")
	CampaignManager.restore_save_state(_json_round_trip({
		"mission_paths": ["res://scenes/maps/map_a.tscn"],
		"recruit_pool": [], "recruited_paths": [],
		"current_mission_index": 0, "start_level": 5,
		"deployment_selection": ["spaceman"],
	}))
	assert_true(CampaignManager.has_deployment(), "legacy non-empty = a real choice")


func test_set_and_clear_deployment_flip_the_flag() -> void:
	CampaignManager.set_deployment([])
	assert_true(CampaignManager.has_deployment(), "an explicit empty write is still a write")
	CampaignManager.clear_deployment()
	assert_false(CampaignManager.has_deployment())
	assert_eq(CampaignManager.get_deployment().size(), 0)


# =============================================================================
# SAVE MANAGER — RINGS, DURABILITY, GATES
# =============================================================================

func _stub_save(created_unix: int, battle: bool = false,
		kind: String = SaveManager.KIND_AUTO_TURN) -> Dictionary:
	var snapshot: Dictionary = {
		"save_version": SaveManager.SAVE_VERSION,
		"kind": kind,
		"created_unix": created_unix,
		"label": "stub %d" % created_unix,
	}
	if battle:
		snapshot["battle"] = {"stub": true}
	return snapshot


func test_ring_fills_empty_slots_then_overwrites_oldest() -> void:
	for created: int in [100, 200, 300, 400]:
		assert_ne(SaveManager.write_autosave(SaveManager.KIND_AUTO_TURN, _stub_save(created)), "",
			"write %d lands" % created)
	# Empty slots fill in order, so the oldest (100) sits in slot_0.
	var slot_0: String = "%s/%s/slot_0.json" % [TEST_SAVE_ROOT, SaveManager.KIND_AUTO_TURN]
	assert_eq(int(SaveManager.read_save_file(slot_0).get("created_unix", -1)), 100)

	SaveManager.write_autosave(SaveManager.KIND_AUTO_TURN, _stub_save(500))
	assert_eq(int(SaveManager.read_save_file(slot_0).get("created_unix", -1)), 500,
		"5th write overwrites the OLDEST slot, not the newest")
	assert_eq(SaveManager.list_saves().size(), 4, "ring never exceeds 4 slots")


func test_corrupt_slot_is_reclaimed_before_healthy_ones() -> void:
	for created: int in [100, 200, 300, 400]:
		SaveManager.write_autosave(SaveManager.KIND_AUTO_TURN, _stub_save(created))
	var slot_2: String = "%s/%s/slot_2.json" % [TEST_SAVE_ROOT, SaveManager.KIND_AUTO_TURN]
	var vandal := FileAccess.open(slot_2, FileAccess.WRITE)
	vandal.store_string("this is not JSON {{{")
	vandal.close()

	SaveManager.write_autosave(SaveManager.KIND_AUTO_TURN, _stub_save(500))
	assert_eq(int(SaveManager.read_save_file(slot_2).get("created_unix", -1)), 500,
		"the corrupt slot is sacrificed first")
	var slot_0: String = "%s/%s/slot_0.json" % [TEST_SAVE_ROOT, SaveManager.KIND_AUTO_TURN]
	assert_eq(int(SaveManager.read_save_file(slot_0).get("created_unix", -1)), 100,
		"the oldest HEALTHY save is untouched")


func test_overwrite_rotates_previous_save_to_bak() -> void:
	var path: String = "%s/%s/slot_0.json" % [TEST_SAVE_ROOT, SaveManager.KIND_AUTO_TURN]
	assert_true(SaveManager.write_save_file(path, _stub_save(100)))
	assert_true(SaveManager.write_save_file(path, _stub_save(200)))
	assert_eq(int(SaveManager.read_save_file(path).get("created_unix", -1)), 200)
	assert_eq(int(SaveManager.read_save_file(path + ".bak").get("created_unix", -1)), 100,
		"the previous good save survives as .bak")
	assert_false(FileAccess.file_exists(path + ".tmp"), "no tmp litter after a clean write")


func test_version_gate_refuses_newer_and_garbage() -> void:
	var newer: Dictionary = _stub_save(100)
	newer["save_version"] = SaveManager.SAVE_VERSION + 99
	var path: String = "%s/%s/slot_0.json" % [TEST_SAVE_ROOT, SaveManager.KIND_AUTO_TURN]
	SaveManager.write_save_file(path, newer)
	assert_eq(SaveManager.read_save_file(path), {},
		"a save from a newer build is refused, never guessed at")
	assert_eq(SaveManager.read_save_file("%s/nowhere.json" % TEST_SAVE_ROOT), {},
		"a missing file reads as empty")


func test_list_saves_newest_first_with_battle_flag() -> void:
	SaveManager.write_autosave(SaveManager.KIND_AUTO_BATTLE,
		_stub_save(100, true, SaveManager.KIND_AUTO_BATTLE))
	SaveManager.write_autosave(SaveManager.KIND_AUTO_TURN, _stub_save(200))
	var rows: Array[Dictionary] = SaveManager.list_saves()
	assert_eq(rows.size(), 2)
	assert_eq(int(rows[0]["created_unix"]), 200, "newest first")
	assert_eq(rows[1]["kind"], SaveManager.KIND_AUTO_BATTLE)
	assert_true(rows[1]["has_battle"], "battle-bearing saves are flagged for the UI")
	assert_false(rows[0]["has_battle"])


# =============================================================================
# MANUAL SAVES (system menu Save button)
# =============================================================================

## TurnManager is a live autoload other suites also touch — pin it to a known
## empty state so a stray battle from an earlier suite can't leak a "battle"
## section into these snapshots.
func _reset_turn_manager() -> void:
	TurnManager._player_units = ([] as Array[Unit])
	TurnManager._enemy_units = ([] as Array[Unit])
	TurnManager._battle_ended = false
	TurnManager.turn_count = 0


func test_manual_save_requires_active_campaign() -> void:
	_reset_turn_manager()
	CampaignManager.restore_save_state({})
	assert_eq(SaveManager.write_manual_save(), "",
		"nothing to record without a campaign — refused with a warning, not a junk file")


func test_manual_save_writes_into_manual_ring() -> void:
	_reset_turn_manager()
	CampaignManager.restore_save_state({
		"mission_paths": ["res://scenes/maps/map_a.tscn"],
		"recruit_pool": [], "recruited_paths": [],
		"current_mission_index": 0, "start_level": 5, "deployment_selection": [],
	})
	var path: String = SaveManager.write_manual_save()
	assert_ne(path, "", "manual save lands")
	assert_string_contains(path, "/%s/" % SaveManager.KIND_MANUAL)
	var snapshot: Dictionary = SaveManager.read_save_file(path)
	assert_eq(str(snapshot["kind"]), SaveManager.KIND_MANUAL)
	assert_eq(str(snapshot["label"]), "Mission 1", "no live battle → campaign-only label")
	assert_false(snapshot.has("battle"), "no live board → no battle section")


# =============================================================================
# FULL LOAD FLOW
# =============================================================================

func test_load_and_restore_brings_back_squad_campaign_and_dice() -> void:
	var spaceman: CharacterData = SquadManager.get_character_by_id("spaceman")
	spaceman.simulate_levels_up_to(4)
	SquadManager.bonus_xp_pool = 55
	CampaignManager.restore_save_state({
		"mission_paths": ["res://scenes/maps/map_a.tscn", "res://scenes/maps/map_b.tscn"],
		"recruit_pool": [], "recruited_paths": [],
		"current_mission_index": 1, "start_level": 5, "deployment_selection": [],
	})

	var snapshot: Dictionary = SaveManager.build_snapshot(SaveManager.KIND_AUTO_TURN, "integration test")
	var expected_roll: int = GameRng.randi()  # the draw the dice owe after a seeded reload
	var path: String = SaveManager.write_autosave(SaveManager.KIND_AUTO_TURN, snapshot)
	assert_ne(path, "", "autosave landed")

	# Scorch the earth: empty squad, dead campaign, scrambled dice.
	SquadManager.restore_save_state({})
	CampaignManager.restore_save_state({})
	GameRng.reseed()
	assert_false(CampaignManager.is_active())

	assert_true(SaveManager.load_and_restore(path), "load succeeds")
	assert_eq(SquadManager.get_character_by_id("spaceman").level, 4, "squad restored")
	assert_eq(SquadManager.bonus_xp_pool, 55, "bEXP restored")
	assert_eq(CampaignManager.get_current_mission_index(), 1, "campaign restored")
	assert_true(CampaignManager.is_active())
	assert_eq(GameRng.randi(), expected_roll,
		"seeded_reload restores the dice mid-stream — same next roll as before the save")


func test_unseeded_reload_rerolls_fate() -> void:
	var snapshot: Dictionary = SaveManager.build_snapshot(SaveManager.KIND_AUTO_TURN, "scummer test")
	var path: String = SaveManager.write_autosave(SaveManager.KIND_AUTO_TURN, snapshot)

	Settings.seeded_reload = false
	assert_true(SaveManager.load_and_restore(path))
	var dice_after: Dictionary = GameRng.capture_state()
	assert_ne(dice_after.get("seed"), snapshot["rng"].get("seed"),
		"with seeded_reload off, a load reseeds instead of restoring the recorded dice")
