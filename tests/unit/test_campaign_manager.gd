## Tests for CampaignManager's defeat-handling policy.
##
## A loss replays the current mission instead of advancing to the next one
## (RESTART_MISSION_ON_LOSS) — the player's persistent roster (levels + injuries)
## carries over either way because SquadManager owns that state. We exercise the
## pure decision helper `_should_advance_after` rather than driving the full
## conclude_mission(), which would trigger SceneRouter scene routing.
extends GutTest

var _CampaignManager = preload("res://scripts/managers/campaign_manager.gd")


func test_victory_advances_with_restart_on() -> void:
	assert_true(_CampaignManager._should_advance_after(true, true),
			"A victory always advances to the next mission")


func test_defeat_replays_with_restart_on() -> void:
	assert_false(_CampaignManager._should_advance_after(false, true),
			"A defeat replays the current mission when restart-on-loss is enabled")


func test_defeat_advances_with_restart_off() -> void:
	assert_true(_CampaignManager._should_advance_after(false, false),
			"With the toggle off, a defeat advances like a victory (old behavior)")


func test_victory_advances_with_restart_off() -> void:
	assert_true(_CampaignManager._should_advance_after(true, false),
			"A victory advances regardless of the restart-on-loss toggle")


func test_restart_on_loss_is_enabled_by_default() -> void:
	# The shipped default for the balancing-playtest phase. If this flips, the
	# loss path reverts to the old "advance regardless of outcome" placeholder.
	assert_true(_CampaignManager.RESTART_MISSION_ON_LOSS,
			"Restart-on-loss is the current testing-phase default")
