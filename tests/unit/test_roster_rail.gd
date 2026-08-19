## RosterRail + ManageUnitsScreen — slice 2 of the intermission port
## (2026-08-10). Design: [.claude/intermission.md] §3–§4.
##
## The rail's rules are pure statics so they pin without a viewport. The one
## that matters most is §4d: DEPLOYMENT SERIALIZES IN ROSTER ORDER, whatever
## the rail is sorted by — spawn position must never move because the player
## re-sorted to compare AGL. That is a real behavior change from the old
## prep screen (whose squad-strip order WAS the deployment order) and the
## design doc explicitly demands a test for it.
extends GutTest


func _unit(id: String, unit_name: String, level: int, base: Dictionary = {}) -> CharacterData:
	var data := CharacterData.new()
	data.character_id = id
	data.character_name = unit_name
	data.level = level
	for key: String in base:
		data.set(key, base[key])
	return data


## Ma'am 11 / Ernesto 5 / Max 5 / Elf 3 — levels chosen so a level sort has
## both a clear winner and a tie.
func _squad() -> Array[CharacterData]:
	return [
		_unit("maam", "Ma'am", 11, {"base_strength": 12, "base_skill": 9}),
		_unit("ernesto", "Ernesto", 5, {"base_strength": 8, "base_skill": 11}),
		_unit("max", "Max Stellar", 5, {"base_strength": 10, "base_skill": 7}),
		_unit("elf", "Elf Pirate", 3, {"base_strength": 6, "base_skill": 8}),
	]


# =============================================================================
# SORT — the key is the readout (§4a)
# =============================================================================

func test_default_squad_order_is_the_identity() -> void:
	# Squad order is the one key that carries narrative — the order these
	# people joined. Ascending, it must reproduce the roster exactly.
	assert_eq(RosterRail.sort_order(_squad(), "ord", true), [0, 1, 2, 3])


func test_ties_break_on_squad_order_in_both_directions() -> void:
	# Godot's sort_custom is NOT stable; without the explicit tiebreak the two
	# Lv 5 units could swap places on every re-sort. Ernesto joined before
	# Max, so Ernesto leads the tie whichever way the sort runs.
	var descending: Array[int] = RosterRail.sort_order(_squad(), "lv", false)
	assert_eq(descending, [0, 1, 2, 3], "11, then the 5s in join order, then 3")
	var ascending: Array[int] = RosterRail.sort_order(_squad(), "lv", true)
	assert_eq(ascending, [3, 1, 2, 0], "3, then the 5s STILL in join order, then 11")


func test_name_sort_ignores_case() -> void:
	var roster: Array[CharacterData] = [
		_unit("a", "ernesto", 1), _unit("b", "Adele", 1), _unit("c", "Maam", 1),
	]
	assert_eq(RosterRail.sort_order(roster, "nm", true), [1, 0, 2],
			"Adele before ernesto — lowercase must not sort after every capital")


func test_stat_sort_reads_the_effective_stat() -> void:
	var order: Array[int] = RosterRail.sort_order(_squad(), "skl", false)
	assert_eq(order, [1, 0, 3, 2], "SKL 11, 9, 8, 7")


func test_the_readout_is_the_sort_key() -> void:
	var squad: Array[CharacterData] = _squad()
	assert_eq(RosterRail.card_readout(squad[0], "skl", 0), "9",
			"sort by SKL and every card reads its SKL")
	assert_eq(RosterRail.card_readout(squad[0], "lv", 0), "11")


func test_name_sort_shows_no_readout() -> void:
	# The name is already the card — repeating it in the value slot is noise.
	assert_eq(RosterRail.card_readout(_squad()[0], "nm", 0), "")


func test_squad_order_counts_from_one() -> void:
	# The readout becomes 1, 2, 3… — players don't count from zero.
	assert_eq(RosterRail.card_readout(_squad()[0], "ord", 0), "1")
	assert_eq(RosterRail.card_readout(_squad()[3], "ord", 3), "4")


# =============================================================================
# SEARCH — substring, not fuzzy (§4b)
# =============================================================================

func test_search_matches_name_substring_case_insensitively() -> void:
	var unit: CharacterData = _unit("max", "Max Stellar", 5)
	assert_true(RosterRail.matches_search(unit, "stell"))
	assert_true(RosterRail.matches_search(unit, "MAX"))
	assert_false(RosterRail.matches_search(unit, "ernesto"))


func test_search_reaches_class_and_elemental_type() -> void:
	# §4b: name, class, AND type — "air" should surface the squad's one flier.
	var unit: CharacterData = _unit("elf", "Elf Pirate", 3)
	unit.primary_type = Enums.ElementalType.AIR
	assert_true(RosterRail.matches_search(unit, "air"))
	assert_true(RosterRail.matches_search(unit, "spaceman"),
			"the default class is searchable too")


func test_empty_and_whitespace_queries_match_everyone() -> void:
	assert_true(RosterRail.matches_search(_squad()[0], ""))
	assert_true(RosterRail.matches_search(_squad()[0], "   "))


# =============================================================================
# DEPLOYMENT ORDER — §4d, the behavior change the doc demands a test for
# =============================================================================

func test_deployment_serializes_in_roster_order() -> void:
	# The set was built in click order d → a → c. The wire format must be
	# roster order regardless, because BattleScene spawns in roster order and
	# the save records what BattleScene will do.
	var deployed: Dictionary = {}
	for id: String in ["elf", "maam", "max"]:
		deployed[id] = true
	assert_eq(RosterRail.deployment_in_roster_order(_squad(), deployed),
			["maam", "max", "elf"] as Array[String])


func test_bench_and_redeploy_does_not_move_the_unit_to_the_back() -> void:
	# The old prep screen appended a redeployed card at the END of the squad
	# strip — which silently moved that unit's spawn tile. Benching Ernesto
	# and bringing him back must land him exactly where he was.
	var deployed: Dictionary = {"maam": true, "ernesto": true, "max": true}
	deployed.erase("ernesto")
	deployed["ernesto"] = true
	assert_eq(RosterRail.deployment_in_roster_order(_squad(), deployed),
			["maam", "ernesto", "max"] as Array[String])


# =============================================================================
# RESOLVING A CARRIED SELECTION — prune, clamp, seed
# =============================================================================

func test_a_carried_selection_survives_intact() -> void:
	var selection: Array[String] = ["ernesto", "elf"]
	assert_eq(RosterRail.resolved_deployment(_squad(), selection, 5),
			["ernesto", "elf"] as Array[String])


func test_permadead_ids_are_pruned() -> void:
	# A selection saved before a permadeath can name a ghost; the resolved
	# form must only contain people who can actually stand on a tile.
	var selection: Array[String] = ["maam", "ghost", "max"]
	assert_eq(RosterRail.resolved_deployment(_squad(), selection, 5),
			["maam", "max"] as Array[String])


func test_a_selection_from_a_bigger_map_clamps_to_this_cap() -> void:
	# Mission 1 had 4 spawn tiles, mission 2 has 2 — the first 2 in roster
	# order keep their seats, matching what the spawn loop would do anyway.
	var selection: Array[String] = ["maam", "ernesto", "max", "elf"]
	assert_eq(RosterRail.resolved_deployment(_squad(), selection, 2),
			["maam", "ernesto"] as Array[String])


func test_first_arrival_seeds_the_cap_in_roster_order() -> void:
	# Nothing has written deployment yet — the resolved form is the same set
	# the hub sub-line has been advertising: the first `cap` of the roster.
	var chosen: Array[String] = RosterRail.resolved_deployment(_squad(), [], 3)
	assert_eq(chosen, ["maam", "ernesto", "max"] as Array[String])


func test_a_roster_smaller_than_the_cap_seeds_everyone() -> void:
	var two: Array[CharacterData] = [_unit("a", "A", 1), _unit("b", "B", 1)]
	assert_eq(RosterRail.resolved_deployment(two, [], 5).size(), 2,
			"a 5-spawn map with 2 units deploys 2, not 5 with blanks")


func test_a_zero_cap_seeds_nobody() -> void:
	# count_player_spawns returns 0 for an unloadable mission path; seeding
	# the whole roster onto a map with no spawn tiles would be worse.
	assert_eq(RosterRail.resolved_deployment(_squad(), [], 0).size(), 0)


func test_a_zero_cap_still_keeps_a_carried_selection() -> void:
	# No cap doesn't mean no choice — a preview open must not erase what the
	# player picked on a real map.
	var selection: Array[String] = ["max"]
	assert_eq(RosterRail.resolved_deployment(_squad(), selection, 0),
			["max"] as Array[String])


func test_a_chosen_empty_selection_stays_empty() -> void:
	# RQD 2026-08-16: benching everyone is a real 0/N. Seeding it back to the
	# first `cap` on the next hub arrival would silently undo the choice.
	assert_eq(RosterRail.resolved_deployment(_squad(), [], 3, true).size(), 0,
			"chosen + empty = nobody, not 'seed three'")
	assert_eq(RosterRail.resolved_deployment(_squad(), [], 3, false).size(), 3,
			"unset + empty still seeds — nobody asked for zero there")


func test_a_chosen_selection_pruned_to_nothing_reseeds() -> void:
	# The player picked people; permadeath took them all. They never asked
	# for zero, so the fallback seeds rather than hands them an empty hub.
	var selection: Array[String] = ["ghost", "phantom"]
	assert_eq(RosterRail.resolved_deployment(_squad(), selection, 2, true),
			["maam", "ernesto"] as Array[String])


# =============================================================================
# PIPS — inert, never silent (§4c)
# =============================================================================

func test_the_last_deployed_pip_stays_pressable() -> void:
	# It used to go inert — and disabled pips draw hollow, so the one unit
	# still deployed LOOKED benched (RQD 2026-08-16). Now that an empty
	# selection is a real 0/N (CampaignManager.has_deployment), benching the
	# last unit is free; the hub's Begin Mission is what refuses the launch.
	assert_eq(RosterRail.pip_inert_reason(true, 1, 5), "")


func test_bench_pips_go_inert_at_cap() -> void:
	assert_eq(RosterRail.pip_inert_reason(false, 4, 4), RosterRail.REASON_SQUAD_FULL)


func test_pips_are_pressable_everywhere_else() -> void:
	assert_eq(RosterRail.pip_inert_reason(true, 3, 4), "", "benching under cap is free")
	assert_eq(RosterRail.pip_inert_reason(false, 2, 4), "", "deploying under cap is free")
	assert_eq(RosterRail.pip_inert_reason(false, 9, 0), "",
			"cap 0 = unknown mission = no cap to hit")


# =============================================================================
# IT ACTUALLY BUILDS
# =============================================================================
# The statics can't notice a construction crash — a missing autoload, a font
# that resolves null, a component API that moved. Build the real things.

func _built_rail(roster: Array[CharacterData], deployed: Array[String],
		cap: int) -> RosterRail:
	var rail := RosterRail.new()
	rail.set_state(roster, deployed, cap)
	add_child_autofree(rail)
	return rail


func _card_buttons(rail: RosterRail) -> Array[Button]:
	var cards: Array[Button] = []
	for child: Node in rail._card_list.get_children():
		if child is Button:
			cards.append(child as Button)
	return cards


func test_the_rail_builds_a_card_per_unit() -> void:
	var rail := _built_rail(_squad(), ["maam", "ernesto"], 4)
	assert_eq(_card_buttons(rail).size(), 4,
			"every roster member gets a card — deployed above, benched below")


func test_the_rail_defaults_to_selecting_the_first_card() -> void:
	var rail := _built_rail(_squad(), ["maam", "ernesto"], 4)
	assert_eq(rail.get_selected_id(), "maam")


func test_pip_toggles_emit_roster_order() -> void:
	var rail := _built_rail(_squad(), ["maam", "ernesto"], 4)
	watch_signals(rail)
	rail._on_pip_pressed("elf")
	var parameters: Array = get_signal_parameters(rail, "deployment_changed")
	assert_eq(parameters[0], ["maam", "ernesto", "elf"] as Array[String],
			"elf joins in roster position, not at the end of the click history")


func test_a_full_squad_refuses_one_more() -> void:
	var rail := _built_rail(_squad(), ["maam", "ernesto"], 2)
	watch_signals(rail)
	rail._on_pip_pressed("elf")
	assert_signal_not_emitted(rail, "deployment_changed",
			"at cap the deploy pip is inert, and even a stale press is a no-op")
	assert_eq(rail.deployed_count(), 2)


func test_the_squad_can_reach_zero_and_says_so() -> void:
	var rail := _built_rail(_squad(), ["maam"], 4)
	watch_signals(rail)
	rail._on_pip_pressed("maam")
	assert_signal_emitted_with_parameters(rail, "deployment_changed", [[] as Array[String]])
	assert_eq(rail.deployed_count(), 0, "the last deployed unit can be benched")


func test_the_last_deployed_pip_is_drawn_filled_not_hollow() -> void:
	# The visible half of the bug: at 1/N the deployed unit's pip must still
	# read as deployed (filled, enabled), not wear the disabled hollow look.
	var rail := _built_rail(_squad(), ["maam"], 4)
	var pip: Button = null
	for card: Button in _card_buttons(rail):
		for child: Node in card.find_children("*", "Button", true, false):
			if child != card and (child as Button).tooltip_text == "bench this unit":
				pip = child
	assert_not_null(pip, "the deployed unit's pip is the one that benches")
	assert_false(pip.disabled)
	var style := pip.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(style.bg_color, GameColors.INTERACTIVE_BORDER_IDLE, "filled = deployed")


func test_the_screen_builds_without_a_campaign() -> void:
	# F6 straight onto the scene: no campaign, cap 0. Everyone rides along
	# locally and NOTHING is written to CampaignManager — an editor preview
	# must not invent a deployment for a mission that doesn't exist.
	var before: Array[String] = CampaignManager.get_deployment()
	var screen := ManageUnitsScreen.new()
	add_child_autofree(screen)
	assert_not_null(screen._rail, "the rail is up")
	assert_eq(_card_buttons(screen._rail).size(),
			SquadManager.get_active_roster().size())
	assert_eq(CampaignManager.get_deployment(), before,
			"no campaign, no deployment write")


func test_the_bexp_deep_link_opens_level_ascending() -> void:
	# §3g: with pricing flattened, the level-ascending sort is the ONLY thing
	# pointing at who the catch-up XP exists for — it's load-bearing.
	ManageUnitsScreen.open_sorted_by_level = true
	var screen := ManageUnitsScreen.new()
	add_child_autofree(screen)
	assert_eq(screen._rail._sort_key, "lv")
	assert_true(screen._rail._sort_ascending)
	assert_false(ManageUnitsScreen.open_sorted_by_level,
			"the flag is consumed — a plain open later must not inherit it")


func test_squad_readout_shows_the_cap_only_when_there_is_one() -> void:
	assert_eq(ManageUnitsScreen.squad_readout(4, 6), "4/6")
	assert_eq(ManageUnitsScreen.squad_readout(4, 0), "4",
			"cap 0 = unknown mission — a bare count, same as the old prep screen")


func test_the_bootstrap_order_is_the_story_order() -> void:
	# RQD 2026-08-10: squad order is the order these people joined — Ma'am,
	# Ernesto, Max, Elf Pirate. It's the rail's default readout (1, 2, 3…)
	# and what spawn position derives from, so it is CANON, not an accident
	# of which JSON got listed first.
	var paths: Array[String] = SquadManager.DEFAULT_ROSTER_PATHS
	assert_string_contains(paths[0], "maam")
	assert_string_contains(paths[1], "ernesto")
	assert_string_contains(paths[2], "spaceman")
	assert_string_contains(paths[3], "elf_pirate")


# =============================================================================
# bEXP MODE (slice 4) — the sheet's column converts to the spend view
# =============================================================================

func test_bexp_mode_swaps_the_sheets_column_and_escape_backs_out_one_layer() -> void:
	var screen := ManageUnitsScreen.new()
	add_child_autofree(screen)
	assert_false(screen._bexp_panel.visible, "the sheet owns the column at rest")
	screen._set_bexp_mode(true)
	assert_true(screen._bexp_panel.visible)
	assert_false(screen._sheet.visible, "one column slot, exactly one occupant")
	screen._set_bexp_mode(false)
	assert_true(screen._sheet.visible)
	assert_false(screen._bexp_panel.visible)


func test_the_deep_link_lands_in_the_spend_view() -> void:
	# §3g extended by slice 4: "Allocate Bonus EXP" should not open a screen
	# that is still one click away from allocating bonus EXP.
	ManageUnitsScreen.open_sorted_by_level = true
	var screen := ManageUnitsScreen.new()
	add_child_autofree(screen)
	assert_true(screen._bexp_panel.visible)
	assert_false(screen._sheet.visible)


# =============================================================================
# THE SPAWN FILTER — BattleScene reads the same unset/empty split
# =============================================================================

func _with_campaign(deployment: Array[String], chosen: bool) -> Dictionary:
	var saved: Dictionary = CampaignManager.capture_save_state()
	CampaignManager.restore_save_state({
		"mission_paths": ["res://scenes/maps/map_a.tscn"],
		"recruit_pool": [], "recruited_paths": [],
		"current_mission_index": 0, "start_level": 5,
		"deployment_selection": deployment, "deployment_chosen": chosen,
	})
	return saved


func test_an_unset_deployment_spawns_everyone_a_chosen_one_is_verbatim() -> void:
	var saved := _with_campaign([], false)
	var scene := BattleScene.new()
	add_child_autofree(scene)
	var roster_size: int = SquadManager.get_active_roster().size()
	assert_eq(scene._get_deployed_roster().size(), roster_size,
			"unset = the legacy everyone fallback (F6 on a map)")
	CampaignManager.set_deployment(["spaceman"])
	assert_eq(scene._get_deployed_roster().size(), 1, "chosen: exactly who was picked")
	CampaignManager.set_deployment([])
	assert_eq(scene._get_deployed_roster().size(), 0,
			"chosen + empty = nobody, NOT everyone — the hub gates this before spawn")
	CampaignManager.restore_save_state(saved)
