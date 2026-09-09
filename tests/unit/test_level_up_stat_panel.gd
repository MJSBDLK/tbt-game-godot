## LevelUpStatPanel — the mid-battle level-up celebration (RQD 2026-08-11),
## and since 2026-09-09 the ONLY level-up screen (the post-battle report was
## removed). Pins the snapshot/diff statics (pure) and the built panel's
## contract: rows from the shared vocabulary, "+1" only on grown stats,
## reduced motion shows everything at once, a skip never hides a gain — and
## MANUAL ADVANCE: the panel holds for a press (skip while revealing,
## dismiss once armed) and never leaves on its own.
extends GutTest


var _saved_motion: bool = true


func before_each() -> void:
	_saved_motion = Settings.ui_motion_enabled


func after_each() -> void:
	Settings.ui_motion_enabled = _saved_motion
	# The UIManager host tests push a state; leave the machine as they found it.
	GameStateManager.clear_state_stack()
	GameStateManager.change_state(Enums.InputState.DEFAULT)
	InputManager.enable_input()


func _unit() -> CharacterData:
	var data := CharacterData.new()
	data.character_name = "Bench Test"
	data.level = 4
	data.base_max_hp = 20
	data.base_strength = 8
	return data


# =============================================================================
# PURE STATICS — snapshot / diff
# =============================================================================

func test_the_snapshot_captures_level_pool_and_all_eight_stats() -> void:
	var unit := _unit()
	unit.available_stat_ups = 2
	var snapshot: Dictionary = LevelUpStatPanel.stat_snapshot(unit)
	assert_eq(int(snapshot["level"]), 4)
	assert_eq(int(snapshot["stat_ups"]), 2)
	assert_eq((snapshot["stats"] as Dictionary).size(), UnitSheet.STAT_ROWS.size(),
			"one entry per sheet stat row — the same list every venue renders")
	assert_eq(int(snapshot["stats"]["strength"]), 8)


func test_grown_stats_diff_in_display_order() -> void:
	var unit := _unit()
	var before: Dictionary = LevelUpStatPanel.stat_snapshot(unit)
	unit.growth_gains_resistance += 1
	unit.growth_gains_strength += 1
	assert_eq(LevelUpStatPanel.grown_stats(before, unit),
			["strength", "resistance"] as Array[String],
			"display order (STAT_ROWS), not roll order")
	assert_eq(LevelUpStatPanel.grown_stats(
			LevelUpStatPanel.stat_snapshot(unit), unit).size(), 0,
			"fresh snapshot = nothing grew")


func test_stat_ups_gained_counts_only_new_points() -> void:
	var unit := _unit()
	unit.available_stat_ups = 1
	var before: Dictionary = LevelUpStatPanel.stat_snapshot(unit)
	unit.available_stat_ups = 3
	assert_eq(LevelUpStatPanel.stat_ups_gained(before, unit), 2)
	unit.available_stat_ups = 0
	assert_eq(LevelUpStatPanel.stat_ups_gained(before, unit), 0,
			"spending points elsewhere never reads as negative gain")


# =============================================================================
# THE BUILT PANEL
# =============================================================================

func _present(unit: CharacterData, before: Dictionary) -> LevelUpStatPanel:
	var panel := LevelUpStatPanel.new()
	add_child_autofree(panel)
	panel.present(unit, before)
	return panel


## A unit that leveled with two growths and a fresh stat-up point.
func _leveled_unit_and_snapshot() -> Array:
	var unit := _unit()
	var before: Dictionary = LevelUpStatPanel.stat_snapshot(unit)
	unit.level = 5
	unit.growth_gains_strength += 1
	unit.growth_gains_agility += 1
	unit.available_stat_ups += 1
	return [unit, before]


func _action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func test_the_panel_fills_its_host_so_centering_and_click_anywhere_work() -> void:
	# set_anchors_preset on an already-parented Control keeps its 0×0 rect
	# (the HintBar-shipped-invisible gotcha) — this panel sat top-left with
	# no click target until a headless shot caught it (2026-09-09). Manual
	# advance made that fatal for a mouse-only player.
	Settings.ui_motion_enabled = false
	var pair := _leveled_unit_and_snapshot()
	var panel := _present(pair[0], pair[1])
	assert_eq(panel.size, panel.get_viewport_rect().size, "the root spans its host")
	assert_gt(panel.size.x, 0.0, "…and that is a real rect, not the 0×0 the preset alone leaves")
	var center: Control = panel.get_child(0)
	assert_eq(center.size, panel.size, "the centering container spans the root")


func test_reduced_motion_shows_every_gain_immediately_and_arms_at_once() -> void:
	Settings.ui_motion_enabled = false
	var pair := _leveled_unit_and_snapshot()
	var panel := _present(pair[0], pair[1])
	assert_eq(panel._plus_labels.size(), 2, "one +1 seat per grown stat")
	for plus: GlowLabel in panel._plus_labels:
		assert_true(plus.visible, "no motion = no reveal choreography, all shown")
	assert_true(panel._badge.visible, "the stat-up badge is up at once")
	assert_eq(panel.phase, LevelUpStatPanel.Phase.ARMED, "nothing to play — armed immediately")
	assert_true(panel._prompt.visible, "CONTINUE shows immediately")
	assert_almost_eq(panel._prompt.modulate.a, 1.0, 0.001, "reduce-motion parks the blink")


func test_motion_mode_holds_the_reveals_the_badge_and_the_prompt() -> void:
	Settings.ui_motion_enabled = true
	var pair := _leveled_unit_and_snapshot()
	var panel := _present(pair[0], pair[1])
	assert_false(panel._plus_labels[0].visible, "with motion on, the +1 waits for its beat")
	assert_false(panel._badge.visible, "the badge lands on its own beat after the last +1")
	assert_false(panel._prompt.visible, "no prompt until the reveal has played")
	assert_eq(panel.phase, LevelUpStatPanel.Phase.REVEALING)


func test_the_panel_waits_for_a_press_after_the_reveal() -> void:
	# RQD 2026-09-09: "I like needing to manually advance after viewing a
	# level-up" — the auto-dismiss linger is gone.
	Settings.ui_motion_enabled = false
	var pair := _leveled_unit_and_snapshot()
	var panel := _present(pair[0], pair[1])
	watch_signals(panel)
	await wait_seconds(0.3)
	assert_signal_not_emitted(panel, "finished", "manual advance — the panel never leaves on its own")
	panel._on_press()
	assert_signal_emitted(panel, "finished", "the press dismisses")
	assert_eq(panel.phase, LevelUpStatPanel.Phase.DONE)


func test_a_press_mid_reveal_skips_to_the_end_and_a_second_press_dismisses() -> void:
	# Dialogue-box semantics: first press completes the text, second advances.
	Settings.ui_motion_enabled = true
	var pair := _leveled_unit_and_snapshot()
	var panel := _present(pair[0], pair[1])
	watch_signals(panel)
	panel._on_press()
	for plus: GlowLabel in panel._plus_labels:
		assert_true(plus.visible, "skipping mid-reveal shows the remaining gains")
	assert_true(panel._badge.visible, "…and the badge")
	assert_eq(panel.phase, LevelUpStatPanel.Phase.ARMED)
	assert_true(panel._prompt.visible, "…then arms the prompt")
	assert_signal_not_emitted(panel, "finished", "a skip is not a dismiss")
	panel._on_press()
	assert_signal_emit_count(panel, "finished", 1)


func test_the_reveal_arms_on_its_own_after_the_breath() -> void:
	Settings.ui_motion_enabled = true
	var unit := _unit()
	var before: Dictionary = LevelUpStatPanel.stat_snapshot(unit)
	unit.growth_gains_strength += 1
	var panel := _present(unit, before)
	watch_signals(panel)
	await wait_seconds(LevelUpStatBlock.REVEAL_STAGGER_SECONDS
			+ LevelUpStatPanel.BREATH_SECONDS + 0.3)
	assert_eq(panel.phase, LevelUpStatPanel.Phase.ARMED, "the choreography ends armed…")
	assert_true(panel._prompt.visible)
	assert_signal_not_emitted(panel, "finished", "…never dismissed")


func test_accept_and_cancel_both_advance_from_keyboard_and_pad() -> void:
	Settings.ui_motion_enabled = false
	for action: String in ["ui_accept", "ui_cancel"]:
		var pair := _leveled_unit_and_snapshot()
		var panel := _present(pair[0], pair[1])
		watch_signals(panel)
		panel._unhandled_input(_action(action))
		assert_signal_emitted(panel, "finished", "%s dismisses the armed panel" % action)


func test_a_skip_never_hides_a_gain_and_finished_fires_once() -> void:
	Settings.ui_motion_enabled = true
	var unit := _unit()
	var before: Dictionary = LevelUpStatPanel.stat_snapshot(unit)
	unit.growth_gains_strength += 1
	var panel := _present(unit, before)
	watch_signals(panel)
	panel._finish()
	assert_true(panel._plus_labels[0].visible,
			"a forced close mid-reveal shows the remaining gains before closing")
	panel._finish()
	assert_signal_emit_count(panel, "finished", 1, "idempotent — one close, one emit")


# =============================================================================
# THE UIMANAGER HOST — the state push around the reveal
# =============================================================================

func test_the_celebration_pushes_its_state_and_quiets_the_board() -> void:
	Settings.ui_motion_enabled = false
	GameStateManager.clear_state_stack()
	GameStateManager.change_state(Enums.InputState.DEFAULT)
	InputManager.enable_input()
	var pair := _leveled_unit_and_snapshot()
	UIManager.show_level_up_celebration(pair[0], pair[1])  # runs to its await
	assert_eq(GameStateManager.current_state, Enums.InputState.LEVEL_UP_CELEBRATION,
			"the reveal holds its own InputState (info panels down, HintBar says Continue)")
	assert_false(InputManager.input_enabled,
			"the board must not react to the Continue press")
	assert_not_null(UIManager._level_up_celebration, "the host exposes the live panel")
	UIManager._level_up_celebration._on_press()
	await get_tree().process_frame
	assert_eq(GameStateManager.current_state, Enums.InputState.DEFAULT, "popped back")
	assert_true(InputManager.input_enabled, "player phase: the board comes back")
	assert_null(UIManager._level_up_celebration, "…and the host forgets the panel")


func test_the_celebration_keeps_input_off_when_the_phase_had_it_off() -> void:
	# The enemy's hit leveled our defender: TurnManager had input off for the
	# AI phase, and popping back to DEFAULT must not switch it on.
	Settings.ui_motion_enabled = false
	GameStateManager.clear_state_stack()
	GameStateManager.change_state(Enums.InputState.DEFAULT)
	InputManager.disable_input()
	var pair := _leveled_unit_and_snapshot()
	UIManager.show_level_up_celebration(pair[0], pair[1])
	assert_eq(GameStateManager.current_state, Enums.InputState.LEVEL_UP_CELEBRATION)
	UIManager._level_up_celebration._on_press()
	await get_tree().process_frame
	assert_eq(GameStateManager.current_state, Enums.InputState.DEFAULT)
	assert_false(InputManager.input_enabled,
			"enemy phase: input stays off after the reveal (the AI still owns the turn)")
