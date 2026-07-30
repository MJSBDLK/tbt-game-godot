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
	assert_false(settings.unit_type_icons_enabled,
			"On-map type icons default OFF (playtest verdict: too noisy)")
	assert_true(settings.ui_motion_enabled,
			"UI motion defaults on — the border vocabulary's animations are the intended look")
	assert_true(settings.auto_end_turn,
			"Auto end turn defaults ON — matches the long-standing hand-off behavior")


func test_persists_and_reloads_across_instances() -> void:
	var writer := _make_settings()
	writer.set_portrait_effects_enabled(false)
	writer.set_integer_zoom_mode(true)
	writer.set_click_to_attack_enabled(true)
	writer.set_unit_type_icons_enabled(true)
	writer.set_ui_motion_enabled(false)
	writer.set_auto_end_turn(false)
	# A fresh instance reading the same file sees the saved values — this is the
	# "survives restart" guarantee.
	var reader := _make_settings()
	reader.load_settings()
	assert_false(reader.portrait_effects_enabled, "portrait_effects_enabled persisted to disk")
	assert_true(reader.integer_zoom_mode, "integer_zoom_mode persisted to disk")
	assert_true(reader.click_to_attack_enabled, "click_to_attack_enabled persisted to disk")
	assert_true(reader.unit_type_icons_enabled, "unit_type_icons_enabled persisted to disk")
	assert_false(reader.ui_motion_enabled, "ui_motion_enabled persisted to disk")
	assert_false(reader.auto_end_turn, "auto_end_turn persisted to disk")


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
	# for future settings written by other systems or newer builds).
	var seed_config := ConfigFile.new()
	seed_config.set_value("mods", "example_flag", 0.5)
	assert_eq(seed_config.save(_TEST_PATH), OK, "seed write succeeds")

	var settings := _make_settings()
	settings.set_integer_zoom_mode(true)  # triggers a _save()

	var reread := ConfigFile.new()
	assert_eq(reread.load(_TEST_PATH), OK, "file still loads after Settings saved over it")
	assert_almost_eq(float(reread.get_value("mods", "example_flag", -1.0)), 0.5, 0.001,
			"Saving known settings preserves unrelated keys")
	assert_true(bool(reread.get_value("display", "integer_zoom_mode", false)),
			"…and still writes its own keys")


# =============================================================================
# Audio volumes + framerate cap (engine-level prefs)
# =============================================================================

func test_audio_and_fps_defaults() -> void:
	var settings := _make_settings()
	assert_almost_eq(settings.master_volume, 0.8, 0.001, "master volume defaults to 0.8")
	assert_almost_eq(settings.sfx_volume, 0.8, 0.001, "sfx volume defaults to 0.8")
	assert_almost_eq(settings.music_volume, 0.8, 0.001, "music volume defaults to 0.8")
	assert_eq(settings.max_fps, 0, "framerate cap defaults to 0 (uncapped)")


func test_audio_and_fps_persist_across_instances() -> void:
	var writer := _make_settings()
	writer.set_master_volume(0.5)
	writer.set_sfx_volume(0.25)
	writer.set_music_volume(0.0)
	writer.set_max_fps(144)
	var reader := _make_settings()
	reader.load_settings()
	assert_almost_eq(reader.master_volume, 0.5, 0.001, "master volume persisted")
	assert_almost_eq(reader.sfx_volume, 0.25, 0.001, "sfx volume persisted")
	assert_almost_eq(reader.music_volume, 0.0, 0.001, "music volume persisted")
	assert_eq(reader.max_fps, 144, "framerate cap persisted")


func test_volume_setter_clamps() -> void:
	var settings := _make_settings()
	settings.set_master_volume(1.5)
	assert_almost_eq(settings.master_volume, 1.0, 0.001, "volume clamps to 1.0")
	settings.set_master_volume(-0.5)
	assert_almost_eq(settings.master_volume, 0.0, 0.001, "volume clamps to 0.0")


func test_max_fps_setter_clamps() -> void:
	var settings := _make_settings()
	settings.set_max_fps(9999)
	assert_eq(settings.max_fps, 1000, "cap clamps to the 1000 Hz ceiling")
	settings.set_max_fps(10)
	assert_eq(settings.max_fps, 30, "sub-30 positive values clamp up to 30")
	settings.set_max_fps(0)
	assert_eq(settings.max_fps, 0, "0 = uncapped is always allowed")


func test_volume_setter_noop_when_unchanged() -> void:
	var settings := _make_settings()
	watch_signals(settings)
	settings.set_sfx_volume(0.8)  # already the default
	assert_signal_emit_count(settings, "changed", 0,
			"setting a volume to its current value doesn't emit changed")


func test_load_mints_audio_buses_and_applies_engine_prefs() -> void:
	var settings := _make_settings()
	settings.set_max_fps(120)  # runs _apply_engine_settings
	assert_true(AudioServer.get_bus_index("SFX") != -1, "SFX bus minted")
	assert_true(AudioServer.get_bus_index("Music") != -1, "Music bus minted")
	assert_eq(Engine.max_fps, 120, "Engine.max_fps mirrors the setting")
	settings.set_max_fps(0)  # restore uncapped so the test leaves no residue
	assert_eq(Engine.max_fps, 0, "0 restores uncapped")


func test_tooltip_hold_defaults_snaps_and_clamps() -> void:
	var settings := _make_settings()
	assert_eq(settings.tooltip_hold_ms, 200, "default 200ms — the fastest allowed peek")
	settings.set_tooltip_hold_ms(437)
	assert_eq(settings.tooltip_hold_ms, 450, "values snap to the 50ms slider grid")
	settings.set_tooltip_hold_ms(100)
	assert_eq(settings.tooltip_hold_ms, 200,
			"the 200ms floor is a softlock guard — below it, ordinary taps"
			+ " start reading as long-presses and pressing becomes impossible")
	settings.set_tooltip_hold_ms(4000)
	assert_eq(settings.tooltip_hold_ms, 1000, "1s ceiling")


func test_tooltip_hold_persists_across_instances() -> void:
	var writer := _make_settings()
	writer.set_tooltip_hold_ms(550)
	var reader := _make_settings()
	reader.load_settings()
	assert_eq(reader.tooltip_hold_ms, 550, "hold delay persisted")


func test_zero_volume_mutes_the_bus() -> void:
	var settings := _make_settings()
	settings.set_music_volume(0.0)
	var music_index: int = AudioServer.get_bus_index("Music")
	assert_true(AudioServer.is_bus_mute(music_index),
			"a 0% slider is true silence (mute), not just very quiet")
	settings.set_music_volume(0.8)
	assert_false(AudioServer.is_bus_mute(music_index), "raising the volume unmutes")
