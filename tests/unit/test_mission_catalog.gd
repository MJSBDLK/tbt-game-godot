## MissionCatalog: manifest lookup + the bEXP income table (par bands +
## objective lines). Doctrine pins ([.claude/mission_objectives.md] 2026-08-03
## amendment): bands are additive and granted once at mission end; defeat
## earns nothing; unlisted maps get defaults so ad-hoc battles still pay.
extends GutTest


func _entry(par: int, dawdle: int) -> Dictionary:
	return {"par_turns": par, "dawdle_turns": dawdle}


func _labels(lines: Array[Dictionary]) -> Array:
	var out: Array = []
	for line: Dictionary in lines:
		out.append(str(line.get("label", "")))
	return out


# =============================================================================
# MANIFEST LOOKUP
# =============================================================================

func test_manifest_entries_load_for_campaign_maps() -> void:
	var entry: Dictionary = MissionCatalog.entry_for("res://scenes/battle/maps/test_map_01.tscn")
	assert_eq(int(entry["par_turns"]), 6, "test_map_01 par from manifest")
	assert_eq(int(entry["dawdle_turns"]), 12, "test_map_01 dawdle from manifest")
	var map_three: Dictionary = MissionCatalog.entry_for("res://scenes/battle/maps/test_map_03.tscn")
	assert_eq(int(map_three["par_turns"]), 8, "per-map values differ — not one global")


func test_unlisted_map_gets_defaults() -> void:
	var entry: Dictionary = MissionCatalog.entry_for("res://scenes/battle/maps/does_not_exist.tscn")
	assert_eq(int(entry["par_turns"]), MissionCatalog.DEFAULT_PAR_TURNS,
			"unlisted maps fall back to defaults so ad-hoc battles still pay income")
	assert_eq(int(entry["dawdle_turns"]), MissionCatalog.DEFAULT_DAWDLE_TURNS)


# =============================================================================
# PAR BANDS — additive, edge-inclusive, victory-only
# =============================================================================

func test_finishing_at_par_earns_both_bands() -> void:
	var lines: Array[Dictionary] = MissionCatalog.compute_award_lines(_entry(6, 12), 6, true)
	assert_eq(lines.size(), 2, "at par exactly: gimme AND above-par (additive bands)")
	assert_eq(MissionCatalog.total_of(lines),
			MissionCatalog.NO_DAWDLING_BEXP + MissionCatalog.ABOVE_PAR_BEXP,
			"finishing faster never earns less — the bands stack")


func test_finishing_past_par_but_inside_dawdle_earns_the_gimme_only() -> void:
	var lines: Array[Dictionary] = MissionCatalog.compute_award_lines(_entry(6, 12), 7, true)
	assert_eq(_labels(lines), ["No dawdling"], "one turn past par drops only the par bonus")
	var at_dawdle: Array[Dictionary] = MissionCatalog.compute_award_lines(_entry(6, 12), 12, true)
	assert_eq(_labels(at_dawdle), ["No dawdling"], "dawdle threshold is edge-inclusive too")


func test_dawdling_past_the_gimme_earns_nothing() -> void:
	var lines: Array[Dictionary] = MissionCatalog.compute_award_lines(_entry(6, 12), 13, true)
	assert_eq(lines.size(), 0,
			"past dawdle: no income — grinding pays in combat XP, never in bEXP")


func test_defeat_earns_no_income_at_any_speed() -> void:
	var lines: Array[Dictionary] = MissionCatalog.compute_award_lines(_entry(6, 12), 1, false)
	assert_eq(lines.size(), 0, "a lost mission replays; it never pays")


# =============================================================================
# OBJECTIVE LINES — award side ready before runtime tracking exists
# =============================================================================

func test_completed_objective_appends_its_line() -> void:
	var entry: Dictionary = _entry(6, 12)
	entry["objectives"] = [{"id": "save_npc", "label": "Bystander saved", "bexp": 200}]
	var lines: Array[Dictionary] = MissionCatalog.compute_award_lines(entry, 20, true, ["save_npc"])
	assert_eq(_labels(lines), ["Bystander saved"],
			"objective pays even past dawdle — bands and objectives are independent")
	assert_eq(MissionCatalog.total_of(lines), 200)


func test_uncompleted_objective_stays_silent() -> void:
	var entry: Dictionary = _entry(6, 12)
	entry["objectives"] = [{"id": "save_npc", "label": "Bystander saved", "bexp": 200}]
	var lines: Array[Dictionary] = MissionCatalog.compute_award_lines(entry, 6, true)
	assert_false(_labels(lines).has("Bystander saved"),
			"no completion id, no line — ignoring objectives is valid play")
