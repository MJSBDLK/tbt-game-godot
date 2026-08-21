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

## When false, the interactive-UI border vocabulary keeps its state COLORS but
## drops all motion: selection brackets park, call-to-action rings vanish (the
## border stays bright), the focus backlight snaps instead of fading.
## Accessibility setting, same spirit as portrait_effects_enabled. Default on.
var ui_motion_enabled: bool = true

## When true, clicking an enemy while your unit is selected immediately attacks
## with the assigned move (power-user shortcut). Default OFF: new players kept
## triggering attacks while trying to inspect enemies. Disabled, that click
## shows the enemy's info panel instead; attacks go through the action menu.
var click_to_attack_enabled: bool = false

## When true, units render their elemental type icon(s) beside the in-world
## health bar (primary + secondary, right of the bar). Default OFF — playtest
## verdict was "too noisy"; kept as an opt-in until on-map typing display gets
## a real design pass.
var unit_type_icons_enabled: bool = false

## Audio volumes, linear 0.0–1.0, applied to the AudioServer buses. SFX and
## Music buses are minted at load if missing (the project ships no bus layout
## yet), so future AudioStreamPlayers can route by bus name from day one.
## Defaults per design: 0.8.
var master_volume: float = 0.8
var sfx_volume: float = 0.8
var music_volume: float = 0.8

## Framerate cap, applied to Engine.max_fps. 0 = uncapped (VSync still applies
## on top). The Options slider offers Off / 30–1000.
var max_fps: int = 0

## How long a touch must hold a move chip before its detail card (MoveTooltip)
## opens. CORE input decision (ui-style-guide.md §14): long press = right click
## = Back/R3, all hold-to-peek. The 200ms FLOOR is a softlock guard — a
## threshold shorter than a player can reliably release would turn every tap
## into a tooltip (RQD 2026-07-19). Options slider: 200–1000ms in 50ms steps.
var tooltip_hold_ms: int = 200

## When true (the default = today's behavior), the player phase hands off to
## the enemy the moment every player unit has acted. When false, the phase
## WAITS — the player ends it via End Turn, whose call-to-action finally has
## a reachable trigger (with auto-end on, "all acted" ends the phase before
## anything could invite the press). Meeting ask 2026-06-28; built 2026-07-29.
var auto_end_turn: bool = true

## When true (default), loading a save restores the gameplay dice (GameRng)
## exactly where they were — repeating the same actions after a reload repeats
## the same outcomes (Fire-Emblem-fair). When false, every load re-rolls fate:
## the save-scummer's option. Saves always RECORD the dice state; this only
## branches the load path, so flipping it never invalidates a save.
var seeded_reload: bool = true

## When true (default), the battle HUD shows the hint / command bar: per-state
## [glyph] verb hints under controller/keyboard, real buttons under touch.
## Experienced players can turn it off — but note that under touch the bar is
## the ONLY way to End turn / open the Menu / toggle Threat zones, so the
## Options toggle should warn (or hide) there. Built 2026-08-20.
var show_control_hints: bool = true

## How a planned move is confirmed once a marker is on the board — the
## playtest toggle (RQD 2026-08-21). MARKER: press the marker again (the
## fluent path; the hint bar's step line wears the NOTICE border and stays a
## label). BUTTON: the hint bar's step cluster becomes a pressable "Move here"
## (parked-gold CTA) — clearer the first three times, clunkier the next three
## hundred. AUTO (default): BUTTON under touch (the corner cluster is already
## under the thumb and double-tapping a tile is the error-prone gesture),
## MARKER everywhere else. Marker presses always work in every mode.
enum MoveConfirmMode { AUTO, MARKER, BUTTON }
var move_confirm_mode: int = MoveConfirmMode.AUTO

const TOOLTIP_HOLD_MIN_MS: int = 200
const TOOLTIP_HOLD_MAX_MS: int = 1000
const TOOLTIP_HOLD_STEP_MS: int = 50

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
	if config.load(settings_path) == OK:
		portrait_effects_enabled = bool(config.get_value(
				"visuals", "portrait_effects_enabled", portrait_effects_enabled))
		integer_zoom_mode = bool(config.get_value(
				"display", "integer_zoom_mode", integer_zoom_mode))
		ui_motion_enabled = bool(config.get_value(
				"visuals", "ui_motion_enabled", ui_motion_enabled))
		click_to_attack_enabled = bool(config.get_value(
				"controls", "click_to_attack_enabled", click_to_attack_enabled))
		unit_type_icons_enabled = bool(config.get_value(
				"display", "unit_type_icons_enabled", unit_type_icons_enabled))
		master_volume = clampf(float(config.get_value(
				"audio", "master_volume", master_volume)), 0.0, 1.0)
		sfx_volume = clampf(float(config.get_value(
				"audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
		music_volume = clampf(float(config.get_value(
				"audio", "music_volume", music_volume)), 0.0, 1.0)
		max_fps = clampi(int(config.get_value(
				"display", "max_fps", max_fps)), 0, 1000)
		tooltip_hold_ms = _snap_tooltip_hold(int(config.get_value(
				"controls", "tooltip_hold_ms", tooltip_hold_ms)))
		auto_end_turn = bool(config.get_value(
				"gameplay", "auto_end_turn", auto_end_turn))
		seeded_reload = bool(config.get_value(
				"gameplay", "seeded_reload", seeded_reload))
		show_control_hints = bool(config.get_value(
				"controls", "show_control_hints", show_control_hints))
		move_confirm_mode = clampi(int(config.get_value(
				"controls", "move_confirm_mode", move_confirm_mode)),
				MoveConfirmMode.AUTO, MoveConfirmMode.BUTTON)
	# Engine-level prefs (fps cap, bus volumes) must apply even with no file —
	# a fresh install still needs the buses minted and defaults pushed.
	_apply_engine_settings()


## Persists + notifies. No-ops when the value is unchanged so we don't thrash
## the disk or emit redundant `changed` signals.
func set_portrait_effects_enabled(value: bool) -> void:
	if value == portrait_effects_enabled:
		return
	portrait_effects_enabled = value
	_save()
	changed.emit()


## Persists + notifies. No-ops when unchanged (see set_portrait_effects_enabled).
func set_ui_motion_enabled(value: bool) -> void:
	if value == ui_motion_enabled:
		return
	ui_motion_enabled = value
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


## Persists + notifies. No-ops when unchanged (see set_portrait_effects_enabled).
func set_unit_type_icons_enabled(value: bool) -> void:
	if value == unit_type_icons_enabled:
		return
	unit_type_icons_enabled = value
	_save()
	changed.emit()


## Persists + applies to the Master bus + notifies. Clamped to 0–1.
func set_master_volume(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(value, master_volume):
		return
	master_volume = value
	_apply_engine_settings()
	_save()
	changed.emit()


## Persists + applies to the SFX bus + notifies. Clamped to 0–1.
func set_sfx_volume(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(value, sfx_volume):
		return
	sfx_volume = value
	_apply_engine_settings()
	_save()
	changed.emit()


## Persists + applies to the Music bus + notifies. Clamped to 0–1.
func set_music_volume(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(value, music_volume):
		return
	music_volume = value
	_apply_engine_settings()
	_save()
	changed.emit()


## Persists + applies Engine.max_fps + notifies. 0 = uncapped; else 30–1000.
func set_max_fps(value: int) -> void:
	value = 0 if value <= 0 else clampi(value, 30, 1000)
	if value == max_fps:
		return
	max_fps = value
	_apply_engine_settings()
	_save()
	changed.emit()


## Persists + notifies. Snapped to the 50ms slider grid and clamped 200–1000
## (the 200 floor is the softlock guard — see the var doc).
func set_tooltip_hold_ms(value: int) -> void:
	value = _snap_tooltip_hold(value)
	if value == tooltip_hold_ms:
		return
	tooltip_hold_ms = value
	_save()
	changed.emit()


## Persists + notifies. No-ops when unchanged (see set_portrait_effects_enabled).
func set_show_control_hints(value: bool) -> void:
	if value == show_control_hints:
		return
	show_control_hints = value
	_save()
	changed.emit()


func set_move_confirm_mode(value: int) -> void:
	value = clampi(value, MoveConfirmMode.AUTO, MoveConfirmMode.BUTTON)
	if value == move_confirm_mode:
		return
	move_confirm_mode = value
	_save()
	changed.emit()


func set_auto_end_turn(value: bool) -> void:
	if value == auto_end_turn:
		return
	auto_end_turn = value
	_save()
	changed.emit()


## Persists + notifies. No-ops when unchanged (see set_portrait_effects_enabled).
func set_seeded_reload(value: bool) -> void:
	if value == seeded_reload:
		return
	seeded_reload = value
	_save()
	changed.emit()


func _snap_tooltip_hold(value: int) -> int:
	var snapped_value: int = roundi(float(value) / float(TOOLTIP_HOLD_STEP_MS)) \
			* TOOLTIP_HOLD_STEP_MS
	return clampi(snapped_value, TOOLTIP_HOLD_MIN_MS, TOOLTIP_HOLD_MAX_MS)


## Push engine-level prefs into the engine singletons. Engine and AudioServer
## are core singletons, not autoloads, so the "no autoload dependencies" rule
## in the header still holds.
func _apply_engine_settings() -> void:
	Engine.max_fps = max_fps
	_ensure_audio_buses()
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("SFX", sfx_volume)
	_apply_bus_volume("Music", music_volume)


## The project ships no default_bus_layout.tres yet — mint the SFX/Music buses
## at load so the volume settings have somewhere to land and future
## AudioStreamPlayers can route by bus name from day one.
func _ensure_audio_buses() -> void:
	for bus_name: String in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, &"Master")


func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	# linear_to_db(0) is -inf; mute instead so the slider's bottom is true silence.
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


## Writes the full settings set to disk. Loads the existing file first so any
## keys other systems may have written survive the round-trip (forward-
## compatible — we never blow away sections we don't know about).
func _save() -> void:
	var config := ConfigFile.new()
	config.load(settings_path)  # ignore error — a fresh file is fine
	config.set_value("visuals", "portrait_effects_enabled", portrait_effects_enabled)
	config.set_value("visuals", "ui_motion_enabled", ui_motion_enabled)
	config.set_value("display", "integer_zoom_mode", integer_zoom_mode)
	config.set_value("controls", "click_to_attack_enabled", click_to_attack_enabled)
	config.set_value("display", "unit_type_icons_enabled", unit_type_icons_enabled)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("display", "max_fps", max_fps)
	config.set_value("controls", "tooltip_hold_ms", tooltip_hold_ms)
	config.set_value("gameplay", "auto_end_turn", auto_end_turn)
	config.set_value("gameplay", "seeded_reload", seeded_reload)
	config.set_value("controls", "show_control_hints", show_control_hints)
	config.set_value("controls", "move_confirm_mode", move_confirm_mode)
	var err: int = config.save(settings_path)
	if err != OK:
		push_warning("Settings: failed to save %s (error %d)" % [settings_path, err])
