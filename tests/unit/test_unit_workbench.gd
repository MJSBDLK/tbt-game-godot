## UnitSheet + UnitWorkbench — slice 3 of the intermission port (2026-08-10).
## Design: [.claude/intermission.md] §3. These two absorb EquipmentPicker; the
## bank/equip semantics pinned here are the ones that carried over from
## equipment_picker.md §3–§5 (alphabetized bank, pool minus equipped, live
## commit), plus the new one-screen rules: the lane is implied by the slot,
## and StatUp allocation lives on the sheet row.
extends GutTest


## Real move/passive names from the shipped data files, so the bank tests
## exercise MoveData/PassiveData for real:
##   Bonk           Physical / Simple
##   Compressed Air Special  / Air
##   Fortify        Support  / Chivalric
##   Laser          Special  / Robo
func _unit() -> CharacterData:
	var data := CharacterData.new()
	data.character_id = "workbench_test"
	data.character_name = "Bench Test"
	data.level = 5
	data.base_pool_moves.assign(["Laser", "Bonk", "Fortify", "Compressed Air"])
	data.base_pool_passives.assign(["Glib", "Anti-Gravity", "Extendo"])
	return data


func _equip(data: CharacterData, move_name: String) -> void:
	data.equipped_moves.append(MoveData.get_move(move_name))


# =============================================================================
# THE BANK — pool minus equipped, alphabetized, filterable
# =============================================================================

func test_the_bank_is_the_pool_minus_equipped_alphabetized() -> void:
	var unit := _unit()
	_equip(unit, "Bonk")
	assert_eq(UnitWorkbench.move_bank(unit, {}, {}),
			["Compressed Air", "Fortify", "Laser"] as Array[String],
			"equipped moves leave the bank; the rest alphabetize (predictability rule)")


func test_damage_filters_shrink_the_bank() -> void:
	var unit := _unit()
	var special_only: Dictionary = {Enums.DamageType.SPECIAL: true}
	assert_eq(UnitWorkbench.move_bank(unit, special_only, {}),
			["Compressed Air", "Laser"] as Array[String])


func test_element_filters_compose_with_damage_filters() -> void:
	var unit := _unit()
	var special_only: Dictionary = {Enums.DamageType.SPECIAL: true}
	var robo_only: Dictionary = {Enums.ElementalType.ROBO: true}
	assert_eq(UnitWorkbench.move_bank(unit, special_only, robo_only),
			["Laser"] as Array[String], "filters intersect, not union")


func test_an_empty_filter_set_means_no_filter() -> void:
	var unit := _unit()
	assert_eq(UnitWorkbench.move_bank(unit, {}, {}).size(), 4,
			"empty set = everything shows, not nothing")


func test_the_passive_bank_mirrors_the_move_bank() -> void:
	var unit := _unit()
	unit.equipped_passives.append("Glib")
	assert_eq(UnitWorkbench.passive_bank(unit),
			["Anti-Gravity", "Extendo"] as Array[String])


# =============================================================================
# EQUIP — live commit (squad_manager.md §6)
# =============================================================================

func test_equipping_replaces_the_slot_and_frees_the_old_move() -> void:
	var unit := _unit()
	_equip(unit, "Bonk")
	assert_true(UnitWorkbench.equip_move(unit, 0, "Laser"))
	assert_eq(unit.equipped_moves[0].move_name, "Laser")
	assert_has(UnitWorkbench.move_bank(unit, {}, {}), "Bonk",
			"the displaced move falls back into the bank — nothing is ever lost")


func test_equipping_past_the_list_end_pads_with_empty_slots() -> void:
	# A unit with 2 moves equipping into slot 4 must not crash or compact —
	# slot identity is positional.
	var unit := _unit()
	_equip(unit, "Bonk")
	assert_true(UnitWorkbench.equip_move(unit, 2, "Laser"))
	assert_eq(unit.equipped_moves.size(), 3)
	assert_eq(unit.equipped_moves[2].move_name, "Laser")
	assert_true(UnitSheet.is_empty_move(unit.equipped_moves[1]),
			"the gap stays an empty slot (Move.EMPTY, the em-dash sentinel)")


func test_an_unknown_move_never_commits() -> void:
	var unit := _unit()
	_equip(unit, "Bonk")
	assert_false(UnitWorkbench.equip_move(unit, 0, "Spaghettify"))
	assert_eq(unit.equipped_moves[0].move_name, "Bonk", "the slot is untouched")


func test_equipping_a_passive_writes_the_name() -> void:
	var unit := _unit()
	assert_true(UnitWorkbench.equip_passive(unit, 1, "Extendo"))
	assert_eq(str(unit.equipped_passives[1]), "Extendo")
	assert_false(UnitWorkbench.equip_passive(unit, 0, "Not A Passive"))


# =============================================================================
# SHEET COPY RULES + STAT LANE ARITHMETIC
# =============================================================================

func test_ident_sub_line_reads_class_and_level() -> void:
	assert_eq(UnitSheet.ident_sub_line(_unit()), "Spaceman · Lv 5")


func test_stat_labels_use_the_fingerprint_abbreviations() -> void:
	assert_eq(UnitSheet.stat_label("athleticism"), "ATH")
	assert_eq(UnitSheet.stat_label("max_hp"), "HP")


func test_open_stat_count_reads_level_stats_never_allocations() -> void:
	var unit := _unit()
	assert_eq(UnitWorkbench.open_stat_count(unit), 8, "a fresh unit is capped nowhere")
	# Park base STR exactly at the Spaceman cap — one stat closes.
	unit.base_strength = unit.get_stat_cap("strength")
	assert_eq(UnitWorkbench.open_stat_count(unit), 7)
	# Allocated points must NOT close a stat: StatUps sit outside the cap math.
	unit.available_stat_ups = 4
	unit.set_allocated_points("defense", 4)
	assert_eq(UnitWorkbench.open_stat_count(unit), 7,
			"allocation can exceed the cap without 'capping' the stat")


# =============================================================================
# STATUP ALLOCATION ON THE SHEET ROW — §3e
# =============================================================================

func _built_sheet(unit: CharacterData) -> UnitSheet:
	var sheet := UnitSheet.new()
	add_child_autofree(sheet)
	sheet.set_character(unit)
	return sheet


func test_allocation_spends_from_the_pool_and_announces_itself() -> void:
	var unit := _unit()
	unit.available_stat_ups = 3
	var sheet := _built_sheet(unit)
	watch_signals(sheet)
	sheet._on_stat_increment("strength")
	assert_eq(unit.get_allocated_points("strength"), 1)
	assert_signal_emitted(sheet, "changed",
			"the rail badge and the save latch both hang off this")


func test_the_pool_is_a_hard_floor() -> void:
	var unit := _unit()
	unit.available_stat_ups = 1
	var sheet := _built_sheet(unit)
	sheet._on_stat_increment("strength")
	sheet._on_stat_increment("agility")
	assert_eq(unit.allocated_total(), 1, "one point in the pool, one point spent")


func test_the_per_stat_cap_is_a_hard_ceiling() -> void:
	var unit := _unit()
	unit.available_stat_ups = 10
	var sheet := _built_sheet(unit)
	for _i: int in 6:
		sheet._on_stat_increment("strength")
	assert_eq(unit.get_allocated_points("strength"), StatAllocation.PER_STAT_CAP)


func test_refunds_stop_at_zero() -> void:
	var unit := _unit()
	unit.available_stat_ups = 2
	var sheet := _built_sheet(unit)
	sheet._on_stat_increment("strength")
	sheet._on_stat_decrement("strength")
	sheet._on_stat_decrement("strength")
	assert_eq(unit.get_allocated_points("strength"), 0)
	assert_eq(unit.allocated_total(), 0)


# =============================================================================
# SELECTION — the lane is implied by the slot (§3a)
# =============================================================================

func test_clicking_the_open_slot_again_returns_to_the_summary() -> void:
	var sheet := _built_sheet(_unit())
	sheet._pick("move", 0)
	assert_eq(sheet.get_selection_kind(), "move")
	sheet._pick("move", 0)
	assert_eq(sheet.get_selection_kind(), "none",
			"same slot twice = deselect, back to the unit summary")


func test_slot_selection_survives_a_unit_switch_but_injuries_do_not() -> void:
	# §3b: click Move 2 on one unit, click another in the rail — you're on
	# THEIR Move 2. Injuries are personal and reset instead.
	var sheet := _built_sheet(_unit())
	sheet._pick("move", 1)
	sheet.set_character(_unit())
	assert_eq(sheet.get_selection_kind(), "move", "loadout comparison in one click")
	assert_eq(sheet.get_selection_key(), 1)
	sheet._pick("injury", 0)
	sheet.set_character(_unit())
	assert_eq(sheet.get_selection_kind(), "none",
			"an injury selection names a wound the next unit doesn't have")


# =============================================================================
# THE WORKBENCH IS DOWNSTREAM OF THE SLOT
# =============================================================================

func _built_workbench(unit: CharacterData) -> UnitWorkbench:
	var workbench := UnitWorkbench.new()
	add_child_autofree(workbench)
	workbench.set_squad([unit] as Array[CharacterData])
	return workbench


func test_every_slot_kind_opens_its_lane() -> void:
	var unit := _unit()
	_equip(unit, "Bonk")
	var injury := Injury.new()
	injury.injury_id = "burn_scar"
	injury.severity = Enums.InjurySeverity.MINOR
	injury.battles_remaining = 3
	unit.current_injuries.append(injury)

	var workbench := _built_workbench(unit)
	workbench.show_lane(unit, "move", 0)
	assert_eq(workbench._head_label.text, "MOVE SLOT 1", "players count from one")
	workbench.show_lane(unit, "passive", 1)
	assert_eq(workbench._head_label.text, "PASSIVE SLOT 2")
	workbench.show_lane(unit, "stat", "strength")
	assert_eq(workbench._head_label.text, "STAT — STR")
	workbench.show_lane(unit, "injury", 0)
	assert_eq(workbench._head_label.text, "INJURY")
	workbench.show_lane(unit, "none", null)
	assert_eq(workbench._head_label.text, "UNIT SUMMARY")


func test_the_swap_is_a_second_explicit_step() -> void:
	# §3c: picking a bank row only stages a candidate; nothing changes until
	# Equip. Picking the same row again drops the candidate.
	var unit := _unit()
	_equip(unit, "Bonk")
	var workbench := _built_workbench(unit)
	workbench.show_lane(unit, "move", 0)

	workbench._on_bank_row_pressed("Laser")
	assert_eq(unit.equipped_moves[0].move_name, "Bonk",
			"staging a candidate commits nothing")
	workbench._on_bank_row_pressed("Laser")
	assert_eq(workbench._bank_pick, "", "same row again drops the candidate")

	workbench._on_bank_row_pressed("Laser")
	watch_signals(workbench)
	workbench._on_equip_pressed(true)
	assert_eq(unit.equipped_moves[0].move_name, "Laser", "Equip commits live")
	assert_signal_emitted(workbench, "changed")
	assert_eq(workbench._bank_pick, "", "the candidate is consumed")


func test_switching_lanes_drops_a_half_picked_candidate() -> void:
	var unit := _unit()
	_equip(unit, "Bonk")
	var workbench := _built_workbench(unit)
	workbench.show_lane(unit, "move", 0)
	workbench._on_bank_row_pressed("Laser")
	workbench.show_lane(unit, "stat", "strength")
	assert_eq(workbench._bank_pick, "",
			"a candidate belongs to the lane it was picked in")


func test_filters_persist_across_lanes_like_workshop_jigs() -> void:
	var unit := _unit()
	_equip(unit, "Bonk")
	var workbench := _built_workbench(unit)
	workbench.show_lane(unit, "move", 0)
	workbench._on_damage_filter_toggled(Enums.DamageType.SPECIAL)
	workbench.show_lane(unit, "stat", "strength")
	workbench.show_lane(unit, "move", 0)
	assert_true(workbench._damage_filter.has(Enums.DamageType.SPECIAL),
			"the filter survives leaving and returning to the move lane")
	workbench._on_damage_filter_toggled(Enums.DamageType.SPECIAL)
	assert_false(workbench._damage_filter.has(Enums.DamageType.SPECIAL))


func test_muted_is_its_own_voice_not_a_dimmed_secondary() -> void:
	# RQD 2026-08-10: absence text ("(empty)", "no injuries", deselected
	# summaries) gets a real MUTED pair — modulating SECONDARY turned its
	# violet halo muddy. Colors are provisional pending Lawrence; the pair
	# EXISTING and being distinct is the contract.
	assert_ne(GameColors.TEXT_MUTED, GameColors.TEXT_SECONDARY)
	assert_ne(GameColors.TEXT_MUTED_GLOW, GameColors.TEXT_SECONDARY_GLOW)
	assert_ne(GameColors.TEXT_MUTED, GameColors.TEXT_PRIMARY)


# =============================================================================
# ROUND-5 F5 FIXES (RQD 2026-08-11)
# =============================================================================

func test_four_passive_slots_matching_the_engine_cap() -> void:
	# The F5 bug: Ernesto had two passives equipped and three banked, and the
	# sheet's two rendered slots made the bank unequippable. equipped_passives
	# is "Max 4" engine-side; the sheet renders all four.
	assert_eq(UnitSheet.PASSIVE_SLOT_COUNT, 4)
	var unit := _unit()
	assert_true(UnitWorkbench.equip_passive(unit, 3, "Extendo"),
			"slot 4 is reachable")
	assert_eq(str(unit.equipped_passives[3]), "Extendo")


func test_range_reads_one_to_n_because_targeting_is_inclusive() -> void:
	# move_targeting runs get_tiles_within_range (distance 1..attack_range),
	# so "R3" lied by omission — the move also hits adjacent. No minimum-range
	# mechanic exists; if one is ever added, range_text is where the label
	# learns it.
	var melee := Move.new()
	melee.attack_range = 1
	assert_eq(UnitWorkbench.range_text(melee), "1")
	var reach := Move.new()
	reach.attack_range = 3
	assert_eq(UnitWorkbench.range_text(reach), "1-3")


func test_filter_chips_know_when_they_would_find_nothing() -> void:
	# Support exists in the pool (Fortify) but not as Air — the Support chip
	# under an Air element filter grays out; Physical alone stays lit.
	var unit := _unit()
	assert_true(UnitWorkbench.filter_chip_has_entries(unit,
			{Enums.DamageType.PHYSICAL: true}, {}))
	assert_false(UnitWorkbench.filter_chip_has_entries(unit,
			{Enums.DamageType.SUPPORT: true}, {Enums.ElementalType.AIR: true}),
			"no Air-typed Support move exists in this pool")


# =============================================================================
# CREW FILE + STAT META (RQD 2026-08-11, round 6)
# =============================================================================

func test_stat_meta_is_effective_over_cap() -> void:
	# "DEF 7/11", nothing else — prose buried the two numbers that matter.
	var unit := _unit()
	unit.base_defense = 7
	assert_eq(UnitWorkbench.stat_meta_line(unit, "defense"),
			"7/%d" % unit.get_stat_cap("defense"))


func test_statups_may_overflow_the_meta() -> void:
	# The numerator is the EFFECTIVE stat: allocation past the class cap shows
	# as 22/20, a flex rather than an error.
	var unit := _unit()
	unit.base_strength = unit.get_stat_cap("strength")
	unit.available_stat_ups = 4
	unit.set_allocated_points("strength", 4)
	var meta: String = UnitWorkbench.stat_meta_line(unit, "strength")
	var parts: PackedStringArray = meta.split("/")
	assert_gt(int(parts[0]), int(parts[1]), "effective value overflows the cap")


func test_the_starting_squad_has_service_records() -> void:
	# The crew-file lane's lore plumbing, end to end through the real JSON:
	# loader key serviceRecord -> CharacterData.service_record. Content is
	# draft copy (corp-AI voice) — this pins the PLUMBING, not the words.
	for id: String in ["maam", "ernesto", "spaceman", "elfPirate"]:
		var character: CharacterData = SquadManager.get_character_by_id(id)
		if character == null:
			continue
		assert_ne(character.service_record, "",
				"%s ships with a service record" % id)


func test_hd_art_detection_branches_the_crew_file() -> void:
	# A synthetic unit has no line art — the lane falls to static/NO DATA.
	assert_false(CharacterPortrait.has_hd_art(_unit()))
	assert_null(CharacterPortrait.hd_art_for(_unit()))
	# Ma'am ships line art, so she gets the HD treatment.
	var maam: CharacterData = SquadManager.get_character_by_id("maam")
	if maam != null:
		assert_true(CharacterPortrait.has_hd_art(maam))


# =============================================================================
# SERVICE-RECORD GAP MARKUP — [[gap note]] -> [ DATA CORRUPTED ]
# =============================================================================

func test_gap_notes_never_reach_the_screen() -> void:
	var record: String = "Asset X [[real name — undecided]]. Cleared for duty."
	var rendered: String = UnitWorkbench.service_record_bbcode(record, false)
	assert_false(rendered.contains("undecided"),
			"the author's note is for the canon list, not the player")
	assert_string_contains(rendered, "DATA CORRUPTED")
	assert_string_contains(rendered, "Cleared for duty.")


func test_gaps_are_listable_for_the_canon_backlog() -> void:
	var record: String = "A [[first gap]] B [[second gap]] C"
	assert_eq(UnitWorkbench.service_record_gaps(record),
			["first gap", "second gap"] as Array[String])
	assert_eq(UnitWorkbench.service_record_gaps("no gaps here").size(), 0)


func test_prose_brackets_cannot_break_the_markup() -> void:
	# A record containing literal [ ] must render as text, not parse as bbcode.
	var rendered: String = UnitWorkbench.service_record_bbcode("Filed under [misc].", false)
	assert_string_contains(rendered, "[lb]misc[rb]", "brackets escape to bbcode literals")


func test_an_unterminated_marker_renders_verbatim_rather_than_eating_the_tail() -> void:
	var record: String = "Asset Y [[oops no close"
	var rendered: String = UnitWorkbench.service_record_bbcode(record, false)
	assert_string_contains(rendered, "oops no close",
			"a typo'd marker should be visible in playtests, not silently swallowed")


func test_the_shake_effect_is_motion_gated() -> void:
	var record: String = "[[gap]]"
	assert_string_contains(UnitWorkbench.service_record_bbcode(record, true), "[shake")
	assert_false(UnitWorkbench.service_record_bbcode(record, false).contains("[shake"),
			"reduced-motion players get a still corrupted span")


func test_shaking_glyphs_are_not_clipped_by_the_record_block() -> void:
	# Round 9: RichTextLabel overrides clip_contents to true, which sheared
	# the [shake] glyphs at the block's edges. The summary lane's body must
	# let them overflow.
	var unit := _unit()
	unit.service_record = "Asset with a [[gap]] on file."
	var workbench := _built_workbench(unit)
	workbench.show_lane(unit, "none", null)
	var bodies: Array[Node] = workbench.find_children("*", "RichTextLabel", true, false)
	assert_eq(bodies.size(), 1, "the summary lane renders exactly one record body")
	assert_false((bodies[0] as RichTextLabel).clip_contents,
			"shake displacement must overflow the block, not shear at its edge")


# =============================================================================
# [[ NO DATA ]] — untampered absence, distinct from tampering
# =============================================================================

func test_a_bare_no_data_marker_renders_still_and_stays_off_the_backlog() -> void:
	var record: String = "Next of kin: [[ NO DATA ]]."
	var rendered: String = UnitWorkbench.service_record_bbcode(record, true)
	assert_string_contains(rendered, "NO DATA")
	assert_false(rendered.contains("DATA CORRUPTED"),
			"absence is not tampering — the two placeholders never mix")
	assert_false(rendered.contains("[shake"),
			"nobody tampered with nothing: NO DATA holds still even with motion on")
	assert_string_contains(rendered, "no record on file", "its own hover hint")
	assert_eq(UnitWorkbench.service_record_gaps(record).size(), 0,
			"a bare NO DATA is canonical absence, not a canon to-do")


func test_the_marker_is_case_insensitive() -> void:
	assert_string_contains(
			UnitWorkbench.service_record_bbcode("[[no data]]", false), "NO DATA")
	assert_false(UnitWorkbench.service_record_bbcode("[[No Data]]", false)
			.contains("DATA CORRUPTED"))


func test_the_colon_form_carries_an_author_note_onto_the_backlog() -> void:
	var record: String = "Homeworld: [[ NO DATA: which planet — undecided ]]."
	var rendered: String = UnitWorkbench.service_record_bbcode(record, false)
	assert_string_contains(rendered, "NO DATA")
	assert_false(rendered.contains("undecided"), "the note is for us, not the player")
	assert_eq(UnitWorkbench.service_record_gaps(record),
			["which planet — undecided"] as Array[String])


func test_a_note_merely_starting_with_the_words_stays_corrupted() -> void:
	# "No data recovered from the wreck" is an author note that happens to
	# open with the magic words — only the bare marker or the colon form
	# switch kind.
	var record: String = "[[No data recovered from the wreck]]"
	assert_string_contains(
			UnitWorkbench.service_record_bbcode(record, false), "DATA CORRUPTED")
	assert_eq(UnitWorkbench.service_record_gaps(record),
			["No data recovered from the wreck"] as Array[String])


func test_both_marker_kinds_coexist_in_one_record() -> void:
	var record: String = "A [[real name — undecided]] B [[ NO DATA ]] C"
	var rendered: String = UnitWorkbench.service_record_bbcode(record, false)
	assert_string_contains(rendered, "DATA CORRUPTED")
	assert_string_contains(rendered, "NO DATA")
	assert_eq(UnitWorkbench.service_record_gaps(record),
			["real name — undecided"] as Array[String])


# =============================================================================
# FRAME GEOMETRY — the ring hugs the drawn art
# =============================================================================

func test_a_wide_area_bottom_centers_the_art_at_full_height() -> void:
	# Square art in a 100×50 area: height-constrained to 50×50, centered.
	assert_eq(UnitWorkbench.portrait_rect_in_area(Vector2(100, 50), 1.0),
			Rect2(25, 0, 50, 50))


func test_a_tall_area_bottom_aligns_the_art_at_full_width() -> void:
	# Square art in a 50×100 area: width-constrained to 50×50, on the floor.
	assert_eq(UnitWorkbench.portrait_rect_in_area(Vector2(50, 100), 1.0),
			Rect2(0, 50, 50, 50))


func test_the_art_rect_is_pixel_snapped() -> void:
	# 101-wide area centers a 50-wide rect at 25.5 — floored, never fractional
	# (fractional rects shimmer in the pixel viewport).
	var rect: Rect2 = UnitWorkbench.portrait_rect_in_area(Vector2(101, 50), 1.0)
	assert_eq(rect.position.x, 25.0)
	assert_eq(rect.size, Vector2(50, 50))


func test_degenerate_areas_produce_an_empty_rect() -> void:
	assert_eq(UnitWorkbench.portrait_rect_in_area(Vector2(0, 50), 1.0), Rect2())
	assert_eq(UnitWorkbench.portrait_rect_in_area(Vector2(50, 50), 0.0), Rect2())
