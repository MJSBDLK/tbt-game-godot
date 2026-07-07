## User-facing, persisted game settings. Saved to `user://settings.cfg` via
## ConfigFile and reloaded on launch — the home for player preferences.
##
## Distinct from DebugConfig: that holds dev-only, non-persisted flags (logging,
## cheats, the portrait-effects *bypass*). This holds settings a player sets in
## the Options menu and expects to stick across sessions.
##
## Registered as Autoload "Settings". Has no dependency on other autoloads, so
## its position in the autoload order doesn't matter — it just loads its own
## config file on _ready.
extends Node


## Emitted after any setting changes AND has been persisted, so live consumers
## (e.g. HDPortraitSlot) can re-read and re-apply. One generic signal keeps
## listeners simple; re-applying an unrelated setting is an idempotent no-op.
signal changed


const DEFAULT_SETTINGS_PATH: String = "user://settings.cfg"

## When false, the HD line-art portrait distortion/glass shaders are skipped and
## portraits render as clean line art. Accessibility setting (motion / flicker /
## migraine sensitivity). Default on — the effect is the intended look.
var portrait_effects_enabled: bool = true

## When true, camera zoom snaps to integer levels (1x, 2x, 3x…) instead of
## smooth 0.25 steps. Applied by CameraController on spawn; mirrors the Options
## menu's Zoom Mode toggle.
var integer_zoom_mode: bool = false

## When true, clicking an enemy while your unit is selected immediately attacks
## with the assigned move (power-user shortcut). Default OFF: new players kept
## triggering attacks while trying to inspect enemies. Disabled, that click
## shows the enemy's info panel instead; attacks go through the action menu.
var click_to_attack_enabled: bool = false

## The file settings load from / save to. Overridable so tests can point at a
## throwaway path instead of clobbering the player's real settings file.
var settings_path: String = DEFAULT_SETTINGS_PATH


func _ready() -> void:
	load_settings()


## Reads every persisted setting from disk into memory. A missing file or a
## missing key falls back to the in-code default, so a fresh install or a
## newly-added setting just uses its default until the player changes it.
func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return  # No saved settings yet — keep the defaults.
	portrait_effects_enabled = bool(config.get_value(
			"visuals", "portrait_effects_enabled", portrait_effects_enabled))
	integer_zoom_mode = bool(config.get_value(
			"display", "integer_zoom_mode", integer_zoom_mode))
	click_to_attack_enabled = bool(config.get_value(
			"controls", "click_to_attack_enabled", click_to_attack_enabled))


## Persists + notifies. No-ops when the value is unchanged so we don't thrash
## the disk or emit redundant `changed` signals.
func set_portrait_effects_enabled(value: bool) -> void:
	if value == portrait_effects_enabled:
		return
	portrait_effects_enabled = value
	_save()
	changed.emit()


## Persists + notifies. No-ops when unchanged (see set_portrait_effects_enabled).
func set_integer_zoom_mode(value: bool) -> void:
	if value == integer_zoom_mode:
		return
	integer_zoom_mode = value
	_save()
	changed.emit()


## Persists + notifies. No-ops when unchanged (see set_portrait_effects_enabled).
func set_click_to_attack_enabled(value: bool) -> void:
	if value == click_to_attack_enabled:
		return
	click_to_attack_enabled = value
	_save()
	changed.emit()


## Writes the full settings set to disk. Loads the existing file first so any
## keys other systems may have written survive the round-trip (forward-
## compatible — we never blow away sections we don't know about).
func _save() -> void:
	var config := ConfigFile.new()
	config.load(settings_path)  # ignore error — a fresh file is fine
	config.set_value("visuals", "portrait_effects_enabled", portrait_effects_enabled)
	config.set_value("display", "integer_zoom_mode", integer_zoom_mode)
	config.set_value("controls", "click_to_attack_enabled", click_to_attack_enabled)
	var err: int = config.save(settings_path)
	if err != OK:
		push_warning("Settings: failed to save %s (error %d)" % [settings_path, err])
