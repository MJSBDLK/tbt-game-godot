## Post-battle flow wiring (2026-07-07 regression). The legacy battle-result
## overlay is dead UI — the post-mission chain suppresses it in the same frame
## and nothing listens to its Continue button — so show_battle_result must
## never show it. (The banner-first change briefly did, 3 seconds late: it
## popped up as an undismissable zombie underneath the bEXP screen and
## persisted into the intermission.) show_battle_result's remaining jobs are
## the state push, map-panel teardown, and recording the outcome for the
## banner played at the top of _on_post_mission_report_ready.
extends GutTest


func after_each() -> void:
	# Unwind the BATTLE_RESULT state pushed by show_battle_result.
	UIManager.hide_battle_result()


func test_show_battle_result_does_not_resurrect_the_legacy_overlay() -> void:
	assert_not_null(UIManager._battle_result_overlay, "overlay instantiated (dormant)")
	UIManager.show_battle_result(true, 5, 0, 3, 4, 3)
	assert_false(UIManager._battle_result_overlay.visible,
			"legacy overlay stays hidden — its Continue button has no listeners")


func test_outcome_is_recorded_for_the_banner() -> void:
	UIManager.show_battle_result(false, 5, 4, 1, 4, 3)
	assert_false(UIManager._pending_result_is_victory, "defeat recorded for the DEFEAT banner")
	UIManager.hide_battle_result()
	UIManager.show_battle_result(true, 5, 0, 3, 4, 3)
	assert_true(UIManager._pending_result_is_victory, "victory recorded for the VICTORY banner")


func test_full_stats_payload_is_stashed_for_the_result_panel() -> void:
	UIManager.show_battle_result(true, 7, 1, 8, 4, 8)
	assert_eq(int(UIManager._pending_battle_stats.get("turn_count", -1)), 7,
			"turns survive from _end_battle to the result panel")
	assert_eq(int(UIManager._pending_battle_stats.get("enemies_defeated", -1)), 8)
	assert_eq(int(UIManager._pending_battle_stats.get("player_units_lost", -1)), 1)
	assert_eq(int(UIManager._pending_battle_stats.get("total_players", -1)), 4)


# =============================================================================
# BattleResultPanel rendering (chain step 1, added 2026-08-03)
# =============================================================================

func _fresh_result_panel() -> BattleResultPanel:
	var panel: BattleResultPanel = (load("res://scenes/ui/panels/battle_result_panel.tscn")
			as PackedScene).instantiate() as BattleResultPanel
	add_child_autofree(panel)
	return panel


func _stats(is_victory: bool, turns: int) -> Dictionary:
	return {"is_victory": is_victory, "turn_count": turns, "player_units_lost": 0,
			"enemies_defeated": 3, "total_players": 4, "total_enemies": 3}


func test_result_panel_renders_itemized_income_with_total() -> void:
	var panel := _fresh_result_panel()
	panel.show_result(_stats(true, 5),
			[{"label": "No dawdling", "amount": 75}, {"label": "Above par", "amount": 150}], [])
	var text: String = panel._result_label.get_parsed_text()
	assert_string_contains(text, "VICTORY")
	assert_string_contains(text, "No dawdling")
	assert_string_contains(text, "+150")
	assert_string_contains(text, "Total  +225", "income lines sum on screen")
	assert_string_contains(text, "par", "par is a DISPLAYED fact — never wiki knowledge")


func test_result_panel_shows_injuries_but_never_level_ups() -> void:
	# Level-ups celebrate on the NEXT screen; repeating them here as text
	# would deflate that reveal (the whole reason LevelUpReportPanel exists).
	var injury := Injury.new()
	injury.injury_id = "burn_scar"
	injury.severity = Enums.InjurySeverity.MINOR
	var report: Array = [{
		"character_name": "Ernesto", "new_injuries": [injury],
		"recovered_injuries": [], "permadead": false,
		"level_before": 3, "level_after": 5,
	}]
	var panel := _fresh_result_panel()
	panel.show_result(_stats(true, 5), [], report)
	var text: String = panel._result_label.get_parsed_text()
	assert_string_contains(text, "Ernesto")
	assert_string_contains(text, "injured")
	assert_false(text.contains("Lv 3"), "level deltas reserved for the celebration screen")


func test_result_panel_reports_empty_income_honestly() -> void:
	var slow_win := _fresh_result_panel()
	slow_win.show_result(_stats(true, 40), [], [])
	assert_string_contains(slow_win._result_label.get_parsed_text(), "dawdle",
			"a slow win says WHY there's no income")

	var loss := _fresh_result_panel()
	loss.show_result(_stats(false, 3), [], [])
	assert_string_contains(loss._result_label.get_parsed_text(), "pays nothing",
			"a defeat says the mission replays with no income")


func test_result_panel_continue_emits_closed_and_hides() -> void:
	var panel := _fresh_result_panel()
	watch_signals(panel)
	panel.show_result(_stats(true, 5), [], [])
	assert_true(panel.visible, "panel visible while showing")
	panel._on_continue_pressed()
	assert_signal_emitted(panel, "closed", "UIManager chains the level-up report off this")
	assert_false(panel.visible)
