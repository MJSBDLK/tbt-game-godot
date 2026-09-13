## GUT pre-run hook (see .gutconfig.json). The suite runs every exchange
## through the in-place MapPresenter by default: the combat scene is real
## seconds of wipes and clip frames per exchange, and most tests are about
## logic, not presentation. Tests that WANT the scene set
## Settings.battle_animations themselves (test_scene_presenter.gd) and
## restore it in after_each.
extends GutHookScript


func run() -> void:
	# Never write the player's user://settings.cfg from the suite: the MAP
	# value below (or any test's persisting setter call) would land in the
	# real file. It did, 2026-09-07 — RQD's build loaded MAP and the combat
	# scene "never triggered". test_settings_persistence.gd pins this.
	Settings.persistence_enabled = false
	Settings.battle_animations = Settings.BattleAnimations.MAP
	# Dev flags that would STALL a headless run must be off no matter what the
	# working tree says: with combat_scene_step_pauses flipped on locally (RQD,
	# 2026-09-08, examining the stage) every scene test parked forever waiting
	# for a press and the pre-commit hook hung. The step-pause test flips it on
	# for itself and restores it.
	DebugConfig.combat_scene_step_pauses = false
