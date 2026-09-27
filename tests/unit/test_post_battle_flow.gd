## Post-battle flow: banner → BattleResultPanel → conclude. The chain lives in
## BattleResultPanel (hold_outcome, play_post_mission); these pin its wiring
## and what the one screen says. Level-ups celebrate mid-battle
## (test_level_up_stat_panel.gd) and bEXP is spent in the intermission, so
## neither has a post-battle screen.
extends GutTest


func after_each() -> void:
	UIManager._battle_result_panel.release_outcome_hold()


# =============================================================================
# The chain is one screen long
# =============================================================================

func test_the_retired_post_battle_screens_stay_deleted() -> void:
	# If a scene comes back, so does the double celebration.
	for path: String in ["res://scenes/ui/panels/bonus_xp_panel.tscn",
			"res://scenes/ui/panels/level_up_report_panel.tscn",
			"res://scenes/ui/overlays/battle_result_overlay.tscn"]:
		assert_false(ResourceLoader.exists(path),
				"%s was removed with the post-battle cleanup" % path)
	for field: String in ["_bonus_xp_panel", "_level_up_report_panel", "_battle_result_overlay"]:
		assert_false(field in UIManager, "UIManager hosts no %s" % field)


func test_the_chain_starts_off_the_squad_report() -> void:
	var panel: BattleResultPanel = UIManager._battle_result_panel
	assert_not_null(panel, "the one post-battle screen is instantiated")
	assert_true(SquadManager.post_mission_report_ready.is_connected(panel.play_post_mission),
			"the banner waits for SquadManager's report, not battle_ended")


# =============================================================================
# hold_outcome — holds, never shows
# =============================================================================

func test_the_outcome_is_held_for_the_banner_and_the_screen() -> void:
	var panel: BattleResultPanel = UIManager._battle_result_panel
	UIManager.hold_battle_outcome(_stats(false, 7))
	assert_eq(GameStateManager.current_state, Enums.InputState.BATTLE_RESULT,
			"the map is frozen from the last blow")
	assert_false(panel._outcome.is_victory, "defeat held for the DEFEAT banner")
	assert_eq(int(panel._outcome.turn_count), 7, "turns survive to the result screen")
	assert_false(panel.visible, "the banner comes first; nothing shows yet")


func test_a_second_hold_does_not_stack_the_state() -> void:
	UIManager.hold_battle_outcome(_stats(true, 5))
	UIManager.hold_battle_outcome(_stats(true, 6))
	UIManager._battle_result_panel.release_outcome_hold()
	assert_ne(GameStateManager.current_state, Enums.InputState.BATTLE_RESULT,
			"one release unwinds it")


# =============================================================================
# BattleResultPanel rendering
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
	assert_signal_emitted(panel, "closed", "the chain concludes the mission off this")
	assert_false(panel.visible)
