## Intermission hub — screen 2a of the redesign port (2026-08-07).
## Design: [.claude/intermission.md] §2.
##
## The sub-line builders are pure statics precisely so the COPY RULES can be
## pinned here without standing up a viewport, a campaign, or a save file.
## Those rules are the fiddly part — they were argued over across several
## mockup rounds and are exactly the kind of thing a later refactor quietly
## reverts.
extends GutTest


# =============================================================================
# COPY RULES (RQD, mockup rounds 11 + 12)
# =============================================================================

func test_deployment_always_shows_the_cap() -> void:
	# "Deployment reads deployed/cap, never a bare count — the cap is half the
	# information." A bare "4" can't tell you whether you have room.
	var line: String = IntermissionHub.deploy_sub_line(4, 5, 0)
	assert_eq(line, "4/5 deployed")
	assert_string_contains(line, "/", "the cap is never dropped")


func test_the_statup_badge_appears_only_when_something_is_unspent() -> void:
	# A badge that is always there stops being a nudge — so zero is omitted
	# entirely rather than rendered as "0 StatUp".
	assert_eq(IntermissionHub.deploy_sub_line(4, 5, 0), "4/5 deployed",
			"nothing unspent, nothing advertised")
	assert_eq(IntermissionHub.deploy_sub_line(4, 5, 3), "4/5 deployed · 3 StatUp",
			"unspent points ride the same sub-line")


func test_the_resource_is_called_a_statup() -> void:
	# RQD round 11: the word is "StatUp", not "unspent stat-up points". ★N
	# survives only as the compact roster-card glyph.
	var line: String = IntermissionHub.deploy_sub_line(1, 5, 2)
	assert_string_contains(line, "StatUp")
	assert_false(line.contains("★"), "the glyph belongs on roster cards, not here")
	assert_false(line.to_lower().contains("point"), "'points' was retired")


func test_the_bexp_sub_line_is_just_the_number() -> void:
	# The parent label already says "Allocate Bonus EXP" — repeating the noun
	# in the sub-line is width spent on nothing.
	assert_eq(IntermissionHub.bexp_sub_line(340), "340")
	assert_false(IntermissionHub.bexp_sub_line(340).to_lower().contains("bexp"))


func test_an_empty_pool_says_so_in_words() -> void:
	# "0" would read as a value; the empty state should read as a state.
	assert_eq(IntermissionHub.bexp_sub_line(0), "nothing banked yet")


func test_the_briefing_line_pluralises() -> void:
	assert_eq(IntermissionHub.briefing_sub_line(1), "1 objective")
	assert_eq(IntermissionHub.briefing_sub_line(2), "2 objectives")
	assert_eq(IntermissionHub.briefing_sub_line(0), "no objectives listed")


# =============================================================================
# THE IMPLICIT OBJECTIVE (F5 findings, 2026-08-07)
# =============================================================================

func test_a_map_with_no_objectives_still_has_one_to_show() -> void:
	# Every shipped map declares `objectives: []`, so the briefing read
	# "no objectives listed" on every mission — which looks like a bug rather
	# than like "nothing special here".
	var shown: Array = MissionCatalog.briefing_objectives(
			"res://scenes/battle/maps/test_map_01.tscn")
	assert_eq(shown.size(), 1, "the victory condition IS the objective")
	assert_eq(str((shown[0] as Dictionary).get("label", "")), "Eliminate the enemy")


func test_an_unknown_map_also_gets_the_implicit_objective() -> void:
	# Ad-hoc battles aren't in the manifest at all; they must not brief empty.
	assert_eq(MissionCatalog.briefing_objectives("res://nope.tscn").size(), 1)


func test_the_implicit_objective_pays_no_bexp() -> void:
	# Routing the enemy is how you WIN, not a bonus for winning. If it ever
	# starts paying, every mission silently gains free income.
	assert_eq(int(MissionCatalog.DEFAULT_OBJECTIVE.get("bexp", -1)), 0)


func test_the_implicit_objective_stays_out_of_the_award_path() -> void:
	# The display default must not leak into compute_award_lines, or the result
	# screen grows a 0-bEXP "Eliminate the enemy" row. entry_for() is the award
	# side and must keep reporting what the manifest actually declared.
	var entry: Dictionary = MissionCatalog.entry_for(
			"res://scenes/battle/maps/test_map_01.tscn")
	assert_eq((entry.get("objectives", []) as Array).size(), 0,
			"the award side still sees an empty list")
	var lines: Array[Dictionary] = MissionCatalog.compute_award_lines(
			entry, 1, true, ["rout"])
	for line: Dictionary in lines:
		assert_ne(str(line.get("label", "")), "Eliminate the enemy",
				"even claiming 'rout' complete adds no line")


func test_the_eyebrow_counts_from_one() -> void:
	# mission_index is 0-based internally; players count from 1.
	assert_eq(IntermissionHub.eyebrow_text(0, 3), "Mission 1 of 3")
	assert_eq(IntermissionHub.eyebrow_text(2, 3), "Mission 3 of 3")


func test_the_eyebrow_survives_having_no_campaign() -> void:
	# The hub scene can be opened directly from the editor with no campaign
	# running; "Mission 1 of 0" would be nonsense on screen.
	assert_eq(IntermissionHub.eyebrow_text(-1, 0), "Between missions")


# The Begin Mission fallback moved: deployment is now materialized at hub
# ARRIVAL (_seed_deployment) from RosterRail.resolved_deployment — prune,
# clamp, seed — so the sub-line and the actual spawn read the same list. The
# seeding rules are pinned in test_roster_rail.gd.


# =============================================================================
# IT ACTUALLY BUILDS
# =============================================================================
# The tests above are pure functions; none of them would notice if _ready()
# crashed. A ported screen's failure mode is almost always in construction —
# a missing autoload, a font that resolves to null, a component API that moved.

func _built_hub() -> IntermissionHub:
	var hub := IntermissionHub.new()
	add_child_autofree(hub)
	return hub


func _entry_texts(hub: IntermissionHub) -> Array[String]:
	var texts: Array[String] = []
	for entry: MainMenuEntry in hub._menu_entries:
		texts.append(entry.text)
	return texts


func test_the_hub_builds_every_entry_in_task_order() -> void:
	var hub := _built_hub()
	var texts: Array[String] = _entry_texts(hub)
	assert_eq(texts, ["Manage Units", "Allocate Bonus EXP", "Mission Briefing",
			"Begin Mission", "Save Game", "Options", "Quit to Menu"],
			"task order top to bottom, then the system tail")


func test_begin_mission_wears_the_lit_border() -> void:
	# §14: exactly one default action per screen, and it's the one you came to
	# press. If a second entry ever claims it the vocabulary breaks.
	var hub := _built_hub()
	var defaults: int = 0
	for entry: MainMenuEntry in hub._menu_entries:
		if entry.is_default_action:
			defaults += 1
	assert_eq(defaults, 1, "exactly one default action")
	assert_eq(hub._default_entry.text, "Begin Mission")


func test_the_bexp_entry_goes_inert_on_an_empty_pool() -> void:
	# §14 again: an entry whose press would do nothing must not look pressable.
	var hub := _built_hub()
	var saved_pool: int = SquadManager.bonus_xp_pool
	SquadManager.bonus_xp_pool = 0
	hub._refresh_entries()
	assert_true(hub._bexp_entry.inert, "nothing banked, nothing to press")
	SquadManager.bonus_xp_pool = 250
	hub._refresh_entries()
	assert_false(hub._bexp_entry.inert, "a funded pool re-arms it")
	assert_eq(hub._bexp_entry.sub_text, "250", "and the sub-line follows the pool")
	SquadManager.bonus_xp_pool = saved_pool


func test_save_game_arrives_armed_and_latches_after_a_save() -> void:
	# §2b. It arrives armed because autosaves are battle-only — nothing has
	# written the campaign layer by the time the player reaches the hub.
	var hub := _built_hub()
	assert_eq(hub._save_entry.text, "Save Game", "arrives armed")
	assert_false(hub._save_entry.inert)

	hub._dirty = false
	hub._refresh_save_entry()
	assert_eq(hub._save_entry.text, "Game saved!", "latches into the success voice")
	assert_true(hub._save_entry.inert, "and unlit — nothing left to press")


func test_spending_bexp_re_arms_the_save_entry() -> void:
	# The latch has to break on any mutation, or the screen claims a save that
	# no longer covers what's on it.
	var hub := _built_hub()
	hub._dirty = false
	hub._refresh_save_entry()
	assert_true(hub._save_entry.inert, "latched")

	SquadManager.bonus_xp_changed.emit(SquadManager.bonus_xp_pool)
	assert_false(hub._save_entry.inert, "a pool change re-arms Save Game")
	assert_eq(hub._save_entry.text, "Save Game")


func test_mission_briefing_is_inert_rather_than_going_somewhere_else() -> void:
	# It used to open Manage Units, which is a worse failure than a dead entry:
	# a label that silently goes elsewhere teaches the player not to trust any
	# of them. Found on F5, 2026-08-07.
	var hub := _built_hub()
	assert_true(hub._briefing_entry.inert, "inert until §5 exists")
	assert_eq(hub._briefing_entry.focus_mode, Control.FOCUS_NONE,
			"and unreachable by cursor navigation")


func test_the_briefing_sub_line_is_never_empty_on_a_live_mission() -> void:
	# The count comes from briefing_objectives(), not the award list, so an
	# undeclared map reports 1 rather than 0.
	var hub := _built_hub()
	assert_ne(hub._briefing_entry.sub_text, "",
			"the row stays informative even while it's unpressable")


func test_inert_entries_stay_out_of_the_focus_chain() -> void:
	# Cursor navigation must not stop on something it can't press.
	var hub := _built_hub()
	var saved_pool: int = SquadManager.bonus_xp_pool
	SquadManager.bonus_xp_pool = 0
	hub._refresh_entries()
	assert_eq(hub._bexp_entry.focus_mode, Control.FOCUS_NONE,
			"an inert entry is unfocusable")
	SquadManager.bonus_xp_pool = saved_pool


# =============================================================================
# ROUTING
# =============================================================================

func test_mission_boundaries_land_on_the_hub() -> void:
	# The whole point of slice 1: the boundary no longer drops the player
	# straight into the squad editor.
	assert_eq(CampaignManager.INTERMISSION_PATH,
			"res://scenes/ui/intermission_hub.tscn",
			"campaign boundaries route to the hub")
	assert_true(ResourceLoader.exists(CampaignManager.INTERMISSION_PATH),
			"and the scene it names actually exists")


func test_manage_units_still_opens_something_real() -> void:
	# The hub's Manage Units entry opens the three-column workspace. If that
	# path rots the hub becomes a dead end.
	assert_true(ResourceLoader.exists(IntermissionHub.MANAGE_UNITS_PATH),
			"Manage Units has a live destination")
	assert_true(ResourceLoader.exists(IntermissionHub.START_SCREEN_PATH),
			"Quit to Menu has a live destination")
