## Post-battle flow wiring. The chain is banner → BattleResultPanel → conclude
## (UIManager._on_post_mission_report_ready). show_battle_result's jobs are
## the state push, map-panel teardown, and recording the outcome + stats for
## the banner and the result panel — it SHOWS nothing (a legacy stats overlay
## used to be shown from here and came back as an undismissable zombie under
## the chain, 2026-07-07; deleted 2026-09-09).
##
## Trimmed 2026-09-09 (RQD: "Post-battle: remove a lot of these screens"):
## the LevelUpReportPanel and BonusXpPanel steps that used to follow the
## result panel are gone — level-ups celebrate mid-battle the moment they
## happen (LevelUpStatPanel, test_level_up_stat_panel.gd) and bEXP is spent
## in the intermission (BexpSpendPanel). The first tests pin that they stay
## gone.
extends GutTest


func after_each() -> void:
	# Unwind the BATTLE_RESULT state pushed by show_battle_result.
	UIManager.hide_battle_result()


# =============================================================================
# The chain is one screen long
# =============================================================================

func test_the_retired_post_battle_screens_stay_deleted() -> void:
	# If a scene comes back, so does the double celebration this trimmed.
	for path: String in ["res://scenes/ui/panels/bonus_xp_panel.tscn",
			"res://scenes/ui/panels/level_up_report_panel.tscn",
			"res://scenes/ui/overlays/battle_result_overlay.tscn"]:
		assert_false(ResourceLoader.exists(path),
				"%s was removed with the post-battle cleanup" % path)
	assert_false("_bonus_xp_panel" in UIManager, "UIManager no longer hosts a bEXP screen")
	assert_false("_level_up_report_panel" in UIManager,
			"UIManager no longer hosts a level-up report")
	assert_false("_battle_result_overlay" in UIManager,
			"UIManager no longer instantiates the dormant stats overlay")


func test_closing_the_result_panel_concludes_the_mission_directly() -> void:
	assert_not_null(UIManager._battle_result_panel, "the one post-battle screen is instantiated")
	assert_true(UIManager._battle_result_panel.closed.is_connected(
			UIManager._on_battle_result_panel_closed),
			"Continue on the result panel hands straight to the finisher")
	assert_false(UIManager.has_method("_show_level_up_report"),
			"no level-up report step between the result panel and conclude")
	assert_false(UIManager.has_method("_show_bonus_xp_panel"),
			"no bEXP step between the result panel and conclude")


# =============================================================================
# show_battle_result — records, never shows
# =============================================================================

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
# BattleResultPanel rendering (the one post-battle screen, added 2026-08-03)
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
	# Level-ups celebrated mid-battle as they happened (LevelUpStatPanel);
	# repeating them here as text would deflate that reveal.
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
	assert_false(text.contains("Lv 3"), "level deltas belong to the mid-battle celebration")


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
	assert_signal_emitted(panel, "closed", "UIManager concludes the mission off this")
	assert_false(panel.visible)
