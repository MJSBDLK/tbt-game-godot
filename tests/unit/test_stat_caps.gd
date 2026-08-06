## Class stat ceilings and the shared cap bar that draws them.
##
## Caps went class-based 2026-08-06 (they were a flat HP 100 / others 50 table
## before). Design: [data/design/class-and-promotion.md].
##
## The cap NUMBERS are explicitly provisional, so these tests assert structural
## invariants — the tier ladder holds, nobody exceeds global, archetypes stay
## distinguishable — rather than pinning individual values. A balance pass
## should be able to move any single number without turning red.
extends GutTest


func _unit(character_class: Enums.CharacterClass, level: int = 1) -> CharacterData:
	var data := CharacterData.new()
	data.current_class = character_class
	data.level = level
	return data


func _tier_of(character_class: Enums.CharacterClass) -> int:
	return Enums.CLASS_INFO[character_class]["tier"]


# =============================================================================
# THE TABLE ITSELF
# =============================================================================

func test_every_class_in_the_enum_has_caps() -> void:
	# A class with no caps row silently falls back to GLOBAL, which reads as
	# "uncapped" and would quietly break the promotion ladder for that class.
	for character_class: Enums.CharacterClass in Enums.CLASS_INFO:
		assert_true(ClassStatCaps.BY_CLASS.has(character_class),
				"%s has no caps row" % Enums.get_class_display_name(character_class))


func test_every_class_caps_all_eight_stats() -> void:
	for character_class: Enums.CharacterClass in ClassStatCaps.BY_CLASS:
		var caps: Dictionary = ClassStatCaps.BY_CLASS[character_class]
		for stat_name: String in ClassStatCaps.STAT_NAMES:
			assert_true(caps.has(stat_name),
					"%s is missing a %s cap" % [
						Enums.get_class_display_name(character_class), stat_name])


func test_no_class_exceeds_the_global_ceiling() -> void:
	# GLOBAL is what every bar is scaled against. A class above it would draw
	# a track longer than the widget and clamp invisibly.
	for character_class: Enums.CharacterClass in ClassStatCaps.BY_CLASS:
		for stat_name: String in ClassStatCaps.STAT_NAMES:
			assert_lte(ClassStatCaps.for_class(character_class, stat_name),
					ClassStatCaps.global_cap(stat_name),
					"%s %s is above the global ceiling" % [
						Enums.get_class_display_name(character_class), stat_name])


func test_caps_climb_with_tier() -> void:
	# The promotion ladder: every tier-2 class must out-cap every tier-1 class,
	# and tier 3 must out-cap tier 2, on total headroom. If this inverts,
	# promoting could LOWER a ceiling and freeze a stat mid-campaign.
	var totals := {1: [], 2: [], 3: []}
	for character_class: Enums.CharacterClass in ClassStatCaps.BY_CLASS:
		var total: int = 0
		for stat_name: String in ClassStatCaps.STAT_NAMES:
			total += ClassStatCaps.for_class(character_class, stat_name)
		(totals[_tier_of(character_class)] as Array).append(total)
	for tier: int in [1, 2]:
		var best_below: int = (totals[tier] as Array).max()
		var worst_above: int = (totals[tier + 1] as Array).min()
		assert_gt(worst_above, best_below,
				"the weakest tier-%d class must out-cap the strongest tier-%d" % [tier + 1, tier])


func test_no_class_maxes_the_whole_board() -> void:
	# Class identity is which stats are ALLOWED to get tall. A class at global
	# on everything would have no identity and no reason to pick another.
	for character_class: Enums.CharacterClass in ClassStatCaps.BY_CLASS:
		var at_global: int = 0
		for stat_name: String in ClassStatCaps.STAT_NAMES:
			if ClassStatCaps.for_class(character_class, stat_name) >= ClassStatCaps.global_cap(stat_name):
				at_global += 1
		assert_lt(at_global, ClassStatCaps.STAT_NAMES.size(),
				"%s caps out on every stat" % Enums.get_class_display_name(character_class))


func test_archetypes_stay_distinguishable() -> void:
	# Spot-check that the table encodes the class fantasy rather than a flat
	# ramp. These are relative comparisons, so retuning the values is fine —
	# inverting the archetype is not.
	var heavy_defense: int = ClassStatCaps.for_class(Enums.CharacterClass.HEAVY, "defense")
	var mage_defense: int = ClassStatCaps.for_class(Enums.CharacterClass.MAGE, "defense")
	assert_gt(heavy_defense, mage_defense * 2, "a Heavy's DEF ceiling dwarfs a Mage's")

	var mage_special: int = ClassStatCaps.for_class(Enums.CharacterClass.MAGE, "special")
	var heavy_special: int = ClassStatCaps.for_class(Enums.CharacterClass.HEAVY, "special")
	assert_gt(mage_special, heavy_special * 2, "and the reverse holds for SPC")

	assert_gt(ClassStatCaps.for_class(Enums.CharacterClass.SKULK, "agility"),
			ClassStatCaps.for_class(Enums.CharacterClass.HEAVY, "agility"),
			"a Skulk outruns a Heavy")


func test_an_unknown_class_falls_back_to_global_not_zero() -> void:
	# A caps row of zero would make is_at_stat_cap true for every stat and stop
	# every growth roll — a new enum entry must fail open, not closed.
	var bogus: int = -1
	assert_eq(ClassStatCaps.for_class(bogus as Enums.CharacterClass, "strength"),
			ClassStatCaps.global_cap("strength"),
			"a class with no row is uncapped below global, never capped at 0")


# =============================================================================
# CHARACTERDATA READS ITS CLASS
# =============================================================================

func test_two_classes_disagree_about_the_same_stat() -> void:
	# The actual point of the change: the cap now depends on who is asking.
	var heavy := _unit(Enums.CharacterClass.HEAVY)
	var mage := _unit(Enums.CharacterClass.MAGE)
	assert_ne(heavy.get_stat_cap("defense"), mage.get_stat_cap("defense"),
			"get_stat_cap reads current_class, not a flat table")


func test_the_global_cap_does_not_depend_on_class() -> void:
	var heavy := _unit(Enums.CharacterClass.HEAVY)
	var mage := _unit(Enums.CharacterClass.MAGE)
	assert_eq(heavy.get_global_stat_cap("defense"), mage.get_global_stat_cap("defense"),
			"bar scale is class-independent — that's what makes bars comparable")


func test_allocated_points_do_not_count_toward_the_cap() -> void:
	# The rule RQD specified, and the one most likely to be "fixed" by someone
	# who assumes is_at_stat_cap should read the displayed number.
	var mage := _unit(Enums.CharacterClass.MAGE)
	var cap: int = mage.get_stat_cap("defense")
	mage.base_defense = cap
	assert_true(mage.is_at_stat_cap("defense"), "growth reached the ceiling")
	mage.allocated_defense = StatAllocation.PER_STAT_CAP
	assert_true(mage.is_at_stat_cap("defense"),
			"StatUps push the number past the cap without un-capping the stat")


# =============================================================================
# BAR GEOMETRY
# =============================================================================

func test_track_is_the_class_share_of_the_global_ceiling() -> void:
	var heavy := _unit(Enums.CharacterClass.HEAVY)
	var expected: float = float(heavy.get_stat_cap("defense")) / float(heavy.get_global_stat_cap("defense"))
	assert_almost_eq(StatCapBar.track_ratio(heavy, "defense"), expected, 0.001,
			"track length is class_cap / global_cap")


func test_fill_is_proportional_to_the_raw_stat_across_classes() -> void:
	# THE property that makes one bar carry two facts: two units with the same
	# grown stat draw the same fill length even in different classes, so fill
	# compares them while track shows their differing headroom.
	var heavy := _unit(Enums.CharacterClass.HEAVY)
	var mage := _unit(Enums.CharacterClass.MAGE)
	heavy.base_defense = 8
	mage.base_defense = 8
	assert_almost_eq(StatCapBar.fill_ratio(heavy, "defense"),
			StatCapBar.fill_ratio(mage, "defense"), 0.001,
			"same DEF, same fill — regardless of class")
	assert_gt(StatCapBar.track_ratio(heavy, "defense"),
			StatCapBar.track_ratio(mage, "defense"),
			"but the Heavy's track is visibly longer — that's the headroom")


func test_fill_never_draws_past_the_track() -> void:
	# StatUps can push the displayed stat above the class cap. The bar must not
	# follow, or the fill would spill past the end of its own allowance.
	var mage := _unit(Enums.CharacterClass.MAGE)
	mage.base_defense = mage.get_stat_cap("defense")
	mage.allocated_defense = StatAllocation.PER_STAT_CAP
	assert_almost_eq(StatCapBar.fill_ratio(mage, "defense"),
			StatCapBar.track_ratio(mage, "defense"), 0.001,
			"a capped stat fills its track exactly, and no further")


func test_bar_and_label_cannot_disagree_about_being_capped() -> void:
	# is_at_cap is a passthrough so a panel colouring the number beside the bar
	# can't use a different rule than the bar itself.
	var heavy := _unit(Enums.CharacterClass.HEAVY)
	assert_false(StatCapBar.is_at_cap(heavy, "defense"), "a fresh unit isn't capped")
	heavy.base_defense = heavy.get_stat_cap("defense")
	assert_true(StatCapBar.is_at_cap(heavy, "defense"), "and agrees once it is")


# =============================================================================
# THE BONUS SEGMENT (allocation / bond / passive / injury / status)
# =============================================================================

func test_no_bonus_draws_no_segment() -> void:
	var heavy := _unit(Enums.CharacterClass.HEAVY)
	heavy.base_defense = 10
	assert_eq(StatCapBar.bonus_span(heavy, "defense"), Vector2.ZERO,
			"an unmodified stat has nothing to append")


func test_a_positive_bonus_starts_where_the_fill_ends() -> void:
	var heavy := _unit(Enums.CharacterClass.HEAVY)
	heavy.base_defense = 10
	heavy.passive_bonus_defense = 6
	var span: Vector2 = StatCapBar.bonus_span(heavy, "defense")
	assert_almost_eq(span.x, StatCapBar.fill_ratio(heavy, "defense"), 0.001,
			"the segment picks up exactly where the grown fill stops")
	assert_gt(span.y, span.x, "and runs outward")


func test_statups_may_draw_past_the_class_cap() -> void:
	# The rule the bar exists to illustrate. A capped stat that then gets
	# StatUps must show a segment sticking out PAST the end of its own track —
	# clamping it would contradict the thing being demonstrated.
	var mage := _unit(Enums.CharacterClass.MAGE)
	mage.base_defense = mage.get_stat_cap("defense")
	mage.allocated_defense = StatAllocation.PER_STAT_CAP
	var span: Vector2 = StatCapBar.bonus_span(mage, "defense")
	assert_gt(span.y, StatCapBar.track_ratio(mage, "defense"),
			"the StatUp segment extends beyond the class ceiling")


func test_a_penalty_carves_back_out_of_the_fill() -> void:
	# An injured unit's bar has to visibly shrink. Drawn backwards from the
	# fill rather than appended, so the lost portion reads as taken away.
	var heavy := _unit(Enums.CharacterClass.HEAVY)
	heavy.base_defense = 16
	heavy.status_modifier_defense = -6
	var span: Vector2 = StatCapBar.bonus_span(heavy, "defense")
	var fill: float = StatCapBar.fill_ratio(heavy, "defense")
	assert_lt(span.x, fill, "the penalty starts inside the fill")
	assert_almost_eq(span.y, fill, 0.001, "and ends where the fill ends")


func test_a_bonus_cannot_draw_past_the_widget() -> void:
	# Global cap is the widget's right edge; nothing may exceed it or the
	# segment would silently clip and misreport.
	var mage := _unit(Enums.CharacterClass.MAGE)
	mage.base_defense = 40
	mage.passive_bonus_defense = 500
	var span: Vector2 = StatCapBar.bonus_span(mage, "defense")
	assert_lte(span.y, 1.0, "an absurd buff still stops at the widget edge")


func test_a_null_character_draws_nothing_rather_than_crashing() -> void:
	# Panels refresh before a unit is assigned; the bar has to no-op.
	assert_eq(StatCapBar.track_ratio(null, "defense"), 0.0)
	assert_eq(StatCapBar.fill_ratio(null, "defense"), 0.0)
	assert_eq(StatCapBar.bonus_span(null, "defense"), Vector2.ZERO)
	assert_false(StatCapBar.is_at_cap(null, "defense"))
