## Tests for the Settings autoload's persistence + change-notification logic.
## Instances the script directly (not the live `Settings` singleton) pointed at a
## throwaway file, so tests never touch the player's real user://settings.cfg.
## _ready() doesn't fire on a bare .new() (node isn't in the tree), so the
## instance starts from in-code defaults until we call load_settings() ourselves.
extends GutTest

const _TEST_PATH: String = "user://__settings_test.cfg"
const _TEST_FILE: String = "__settings_test.cfg"

var _SettingsScript: GDScript = preload("res://scripts/core/settings.gd")


func before_each() -> void:
	_remove_test_file()


func after_each() -> void:
	_remove_test_file()


func _remove_test_file() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(_TEST_FILE):
		dir.remove(_TEST_FILE)


func _make_settings() -> Object:
	var settings: Object = _SettingsScript.new()
	autofree(settings)
	settings.settings_path = _TEST_PATH
	return settings


func test_defaults() -> void:
	var settings := _make_settings()
	assert_true(settings.portrait_effects_enabled, "Portrait effects default on (intended look)")
	assert_false(settings.integer_zoom_mode, "Zoom mode defaults to smooth")
	assert_false(settings.click_to_attack_enabled,
			"Click-to-attack shortcut defaults OFF (new players kept misfiring attacks)")


func test_persists_and_reloads_across_instances() -> void:
	var writer := _make_settings()
	writer.set_portrait_effects_enabled(false)
	writer.set_integer_zoom_mode(true)
	writer.set_click_to_attack_enabled(true)
	# A fresh instance reading the same file sees the saved values — this is the
	# "survives restart" guarantee.
	var reader := _make_settings()
	reader.load_settings()
	assert_false(reader.portrait_effects_enabled, "portrait_effects_enabled persisted to disk")
	assert_true(reader.integer_zoom_mode, "integer_zoom_mode persisted to disk")
	assert_true(reader.click_to_attack_enabled, "click_to_attack_enabled persisted to disk")


func test_setter_noop_when_value_unchanged() -> void:
	var settings := _make_settings()
	watch_signals(settings)
	settings.set_portrait_effects_enabled(true)  # already the default
	assert_signal_emit_count(settings, "changed", 0,
			"Setting a value to what it already is doesn't emit changed or hit disk")


func test_setter_emits_changed_on_real_change() -> void:
	var settings := _make_settings()
	watch_signals(settings)
	settings.set_portrait_effects_enabled(false)
	assert_signal_emit_count(settings, "changed", 1, "A real change emits changed exactly once")


func test_missing_file_keeps_defaults() -> void:
	# before_each removed the file — loading a nonexistent file is a clean no-op.
	var settings := _make_settings()
	settings.load_settings()
	assert_true(settings.portrait_effects_enabled, "Missing file → in-code default")
	assert_false(settings.integer_zoom_mode, "Missing file → in-code default")


func test_save_preserves_unknown_keys() -> void:
	# Pre-seed the file with a section Settings doesn't manage. Saving a known
	# setting must load-then-write so the unrelated key survives (forward-compat
	# for whenever audio/etc. settings land).
	var seed_config := ConfigFile.new()
	seed_config.set_value("audio", "master_volume", 0.5)
	assert_eq(seed_config.save(_TEST_PATH), OK, "seed write succeeds")

	var settings := _make_settings()
	settings.set_integer_zoom_mode(true)  # triggers a _save()

	var reread := ConfigFile.new()
	assert_eq(reread.load(_TEST_PATH), OK, "file still loads after Settings saved over it")
	assert_almost_eq(float(reread.get_value("audio", "master_volume", -1.0)), 0.5, 0.001,
			"Saving known settings preserves unrelated keys")
	assert_true(bool(reread.get_value("display", "integer_zoom_mode", false)),
			"…and still writes its own keys")
