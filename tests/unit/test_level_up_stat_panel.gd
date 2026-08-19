## LevelUpStatPanel — the mid-battle level-up celebration (RQD 2026-08-11).
## Pins the snapshot/diff statics (pure) and the built panel's contract:
## rows from the shared vocabulary, "+1" only on grown stats, reduced motion
## shows everything at once, a skip-click never hides a gain.
extends GutTest


var _saved_motion: bool = true


func before_each() -> void:
	_saved_motion = Settings.ui_motion_enabled


func after_each() -> void:
	Settings.ui_motion_enabled = _saved_motion


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


func test_reduced_motion_shows_every_gain_immediately() -> void:
	Settings.ui_motion_enabled = false
	var unit := _unit()
	var before: Dictionary = LevelUpStatPanel.stat_snapshot(unit)
	unit.level = 5
	unit.growth_gains_strength += 1
	unit.growth_gains_agility += 1
	var panel := _present(unit, before)
	assert_eq(panel._plus_labels.size(), 2, "one +1 seat per grown stat")
	for plus: GlowLabel in panel._plus_labels:
		assert_true(plus.visible, "no motion = no reveal choreography, all shown")


func test_motion_mode_holds_the_reveals_for_the_stagger() -> void:
	Settings.ui_motion_enabled = true
	var unit := _unit()
	var before: Dictionary = LevelUpStatPanel.stat_snapshot(unit)
	unit.growth_gains_strength += 1
	var panel := _present(unit, before)
	assert_false(panel._plus_labels[0].visible,
			"with motion on, the +1 waits for its beat")


func test_a_skip_never_hides_a_gain_and_finished_fires_once() -> void:
	Settings.ui_motion_enabled = true
	var unit := _unit()
	var before: Dictionary = LevelUpStatPanel.stat_snapshot(unit)
	unit.growth_gains_strength += 1
	var panel := _present(unit, before)
	watch_signals(panel)
	panel._finish()
	assert_true(panel._plus_labels[0].visible,
			"skipping mid-reveal shows the remaining gains before closing")
	panel._finish()
	assert_signal_emit_count(panel, "finished", 1, "idempotent — one close, one emit")
