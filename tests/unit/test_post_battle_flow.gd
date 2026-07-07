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
