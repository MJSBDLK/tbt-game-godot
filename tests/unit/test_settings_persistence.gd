## The suite must never write the player's user://settings.cfg. The GUT
## pre-run hook (tests/gut_pre_run.gd) forces battle_animations = MAP for
## speed; before Settings.persistence_enabled existed, one persisting setter
## call in any test (test_move_commit_mode's clamp test) wrote that — and
## every other suite-time value — into the real file. RQD's build then
## loaded MAP and the combat scene "never triggered" (2026-09-07).
extends GutTest

const PROBE_PATH: String = "user://_settings_persistence_probe.cfg"

var _path_before: String
var _persist_before: bool
var _motion_before: bool


func before_each() -> void:
	_path_before = Settings.settings_path
	_persist_before = Settings.persistence_enabled
	_motion_before = Settings.ui_motion_enabled
	Settings.settings_path = PROBE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_PATH))


func after_each() -> void:
	Settings.settings_path = _path_before
	Settings.persistence_enabled = _persist_before
	Settings.ui_motion_enabled = _motion_before
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_PATH))


func test_the_hook_keeps_the_suite_off_disk() -> void:
	assert_false(_persist_before, "tests/gut_pre_run.gd must disable persistence for the whole run")


func test_setters_apply_in_memory_but_do_not_write_while_disabled() -> void:
	Settings.persistence_enabled = false
	Settings.set_ui_motion_enabled(not _motion_before)
	assert_eq(Settings.ui_motion_enabled, not _motion_before, "the value still changes")
	assert_false(FileAccess.file_exists(PROBE_PATH), "nothing reached disk")


func test_setters_write_the_whole_block_when_enabled() -> void:
	Settings.persistence_enabled = true
	Settings.set_ui_motion_enabled(not _motion_before)  # a real change — same-value calls short-circuit
	assert_true(FileAccess.file_exists(PROBE_PATH), "a persisting setter writes the file")
	var config := ConfigFile.new()
	assert_eq(config.load(PROBE_PATH), OK)
	assert_eq(int(config.get_value("visuals", "battle_animations", -1)), int(Settings.battle_animations),
			"every setting is written on any save — which is why the suite must stay disabled")
