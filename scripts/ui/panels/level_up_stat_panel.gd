## Mid-battle level-up celebration (RQD 2026-08-11) — THE level-up screen.
## When a player unit levels during battle, this pops a stats-exclusive cut
## of the detail panel: ident line, then the shared LevelUpStatBlock revealing
## the stats that grew one beat at a time (each with its ding), the stat-up
## badge punching in on the beat after, then a CONTINUE prompt.
##
## Since 2026-09-09 this is the ONLY level-up screen: the post-battle
## LevelUpReportPanel (and the bEXP screen behind it) were removed, and what
## made that screen the better dopamine factory moved in here — the ding
## staircase (now LevelUpStatBlock.play_ding), the badge landing on its own
## beat, the breath before the prompt, and MANUAL ADVANCE: the panel never
## leaves on its own; the player presses to move on (RQD: "I like needing to
## manually advance after viewing a level-up"). The small form factor and the
## sheet chrome stay — RQD kept those on purpose.
##
## THIN MODAL HOST: the rows, the snapshot/diff math, the reveal choreography
## and the dings all live in LevelUpStatBlock — the same component the
## intermission bEXP spend panel embeds — so the two celebrations can't
## drift. This class owns only the battle framing: header, stat-up badge,
## prompt, input, and the awaited [signal finished].
##
## INPUT — two-stage, dialogue-box semantics (see [member phase]):
##   REVEALING: a press SKIPS to the end — every gain shown, badge up, prompt
##              armed. A skip never hides a roll (LevelUpStatBlock.abort_reveal).
##   ARMED:     a press DISMISSES (finished).
## "Press" = left click / tap anywhere (the root is MOUSE_FILTER_STOP), or
## ui_accept / ui_cancel (keyboard + pad, and HintBar's touch "Continue",
## which replays ui_accept through Input) via _unhandled_input. Handled events
## stop at HUDViewport, so the board never sees them (InputRouter). While the
## panel is up, UIManager holds InputState.LEVEL_UP_CELEBRATION — InputManager
## quiet, HintBar says "Continue" — see UIManager.show_level_up_celebration.
##
## FLOW: Unit._flush_xp_feedback awaits UIManager.show_level_up_celebration,
## which awaits [signal finished] — so the battle holds its breath (FE-style),
## on the enemy's turn too. Reduced motion (Settings.ui_motion_enabled = false)
## shows everything at once and arms the prompt immediately.
##
## The block renders MODIFIER-STRIPPED here (raw grown values, no bonus
## segments): the celebration tells the growth story, and there is no
## at-rest state to restore to — the panel leaves when the beat ends.
class_name LevelUpStatPanel
extends Control


signal finished


enum Phase { REVEALING, ARMED, DONE }

## Breath between the last beat (final "+1", or the badge) and the prompt —
## forces a small pause so the moment lands; without it the player blasts
## through. (The retired report panel's POST_ANIMATION_PAUSE, kept.)
const BREATH_SECONDS: float = 0.35
## The badge's punch — it lands AFTER the last growth ding so it doesn't
## fight for attention, on the next step of the staircase.
const BADGE_PUNCH_SECONDS: float = 0.27
## The armed prompt's blink period — the RPG "waiting for you" idiom. Parked
## at full alpha under reduced motion.
const PROMPT_BLINK_SECONDS: float = 1.0
const PROMPT_BLINK_LOW_ALPHA: float = 0.35


## Where the beat is. REVEALING until the choreography (or a skip) has shown
## everything; ARMED while waiting for the dismissing press; DONE after
## [signal finished].
var phase: Phase = Phase.REVEALING

var _character: CharacterData = null
var _before: Dictionary = {}
var _block: LevelUpStatBlock = null
var _badge: GlowLabel = null
var _prompt: GlowLabel = null
var _prompt_tween: Tween = null
var _finished: bool = false

## Test/back-compat seam: the reveal seats live on the block now.
var _plus_labels: Array[GlowLabel]:
	get: return _block._plus_labels if _block != null else ([] as Array[GlowLabel])


## Delegates — the math moved to LevelUpStatBlock with the extraction
## (RQD 2026-08-11); these keep the battle-side call sites and the shipped
## test surface stable.
static func stat_snapshot(character: CharacterData) -> Dictionary:
	return LevelUpStatBlock.stat_snapshot(character)


static func grown_stats(before: Dictionary, character: CharacterData) -> Array[String]:
	return LevelUpStatBlock.grown_stats(before, character)


static func stat_ups_gained(before: Dictionary, character: CharacterData) -> int:
	return LevelUpStatBlock.stat_ups_gained(before, character)


func present(character: CharacterData, before: Dictionary) -> void:
	_character = character
	_before = before
	# ANCHORS + OFFSETS, not the anchors preset alone: on an already-parented
	# Control set_anchors_preset keeps the current (0×0) rect, which left this
	# panel parked top-left with a click target of nothing (found by a
	# headless shot 2026-09-09 — the same gotcha that shipped HintBar
	# invisible). Centering AND click-anywhere both need the root to fill
	# its host.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	assert(not is_inside_tree() or size == get_parent_area_size(),
			"LevelUpStatPanel: the root must fill its host — centering and click-anywhere depend on it")
	_run_reveal()


func _gui_input(event: InputEvent) -> void:
	# Click / tap anywhere: skip while revealing, dismiss once armed.
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_on_press()


func _unhandled_input(event: InputEvent) -> void:
	# Keyboard + pad + the HintBar's touch button. Marked handled in
	# HUDViewport so InputRouter blocks it at the root viewport — the board
	# never sees the press.
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_press()


## The one press handler — dialogue-box semantics (see the header).
func _on_press() -> void:
	if _finished:
		return
	match phase:
		Phase.REVEALING:
			_skip_to_armed()
		Phase.ARMED:
			_finish()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# The sheet's panel chrome (UnitSheet._ready's recipe), so the celebration
	# reads as the same surface family as the screen it's a cut of.
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.HUD_PANEL_BACKGROUND
	style.border_color = GameColorPalette.get_color("Straw2", 3)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	column.add_child(header)
	header.add_child(UnitSheet.dim_label(_character.character_name.to_upper()))
	var level_label := GlowLabel.styled(
			"Lv %d → %d" % [int(_before.get("level", _character.level)), _character.level],
			UIManager.font_8px, 8, GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW)
	header.add_child(level_label)

	_block = LevelUpStatBlock.new()
	_block.build(_character, _before, not Settings.ui_motion_enabled, false)
	column.add_child(_block)

	var new_stat_ups: int = LevelUpStatBlock.stat_ups_gained(_before, _character)
	if new_stat_ups > 0:
		_badge = GlowLabel.styled("+%d STAT UP%s" % [new_stat_ups,
				"" if new_stat_ups == 1 else "S"],
				UIManager.font_8px, 8, GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW)
		_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# With motion, the badge lands on its own beat after the last "+1".
		_badge.visible = not Settings.ui_motion_enabled
		column.add_child(_badge)

	# The prompt wears INFO like the level line — it points at the next
	# thing. Not SUCCESS (growth's color; the prompt isn't a gain), not a §14
	# lit border (the whole panel is the press target, like a dialogue box).
	_prompt = GlowLabel.styled("CONTINUE", UIManager.font_8px, 8,
			GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	column.add_child(_prompt)


func _run_reveal() -> void:
	if Settings.ui_motion_enabled:
		await _block.play_reveal()
		if phase != Phase.REVEALING:
			return  # skipped mid-reveal — _skip_to_armed owns the rest
		if _badge != null:
			await _punch_badge()
			if phase != Phase.REVEALING:
				return
		await get_tree().create_timer(BREATH_SECONDS).timeout
		if phase != Phase.REVEALING:
			return
	_arm()


## The badge lands after the last "+1", one more step up the staircase.
func _punch_badge() -> void:
	_badge.visible = true
	_block.play_ding()
	_badge.pivot_offset = _badge.size / 2.0
	_badge.scale = Vector2(0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(_badge, "scale", Vector2(1.15, 1.15), BADGE_PUNCH_SECONDS * 0.55) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_badge, "scale", Vector2.ONE, BADGE_PUNCH_SECONDS * 0.45)
	await tween.finished


## Skip: everything the reveal was going to show becomes visible now, then
## the prompt arms — a skip never hides a gain, and never dismisses.
func _skip_to_armed() -> void:
	_show_everything()
	_arm()


func _show_everything() -> void:
	if _block != null:
		_block.abort_reveal()
	if _badge != null:
		_badge.visible = true
		_badge.scale = Vector2.ONE


func _arm() -> void:
	if _finished or phase == Phase.ARMED:
		return
	phase = Phase.ARMED
	assert(_prompt != null, "LevelUpStatPanel: armed before _build seated the prompt")
	_prompt.visible = true
	_prompt.modulate.a = 1.0
	if Settings.ui_motion_enabled:
		_prompt_tween = create_tween().set_loops()
		_prompt_tween.tween_property(_prompt, "modulate:a", PROMPT_BLINK_LOW_ALPHA,
				PROMPT_BLINK_SECONDS / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_prompt_tween.tween_property(_prompt, "modulate:a", 1.0,
				PROMPT_BLINK_SECONDS / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Terminal. Idempotent — one close, one emit. Callable from any phase (a
## host tearing down mid-reveal); shows every remaining gain first so a
## forced close never hides a roll either.
func _finish() -> void:
	if _finished:
		return
	_finished = true
	phase = Phase.DONE
	if _prompt_tween != null:
		_prompt_tween.kill()
	_show_everything()
	finished.emit()
