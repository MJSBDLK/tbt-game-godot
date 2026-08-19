## StatAllocation — the between-mission stat-up point spend.
##
## First test coverage for this file; it predated the tests policy and the
## 2026-08-05 flip from FLAT to PERCENTAGE is what finally earned it a pin.
## Doctrine: [data/design/class-and-promotion.md] §7.
##
## Deliberately asserts SHAPE over dial values. PCT_PER_POINT is explicitly
## playtest-provisional, so tests derive expectations from the constants
## instead of hardcoding "+10%" — a balance pass should never become a
## test-fixing pass. The one exception is the mode itself, which IS the
## decision and should fail loudly if someone flips it back.
extends GutTest


# =============================================================================
# THE MODE DECISION
# =============================================================================

func test_percentage_is_the_shipping_mode() -> void:
	assert_eq(StatAllocation.MODE, StatAllocation.Mode.PERCENTAGE,
			"FLAT exists only as a comparison mode — shipping FLAT would flatten archetypes")


func test_four_pips_is_the_advertised_total_bonus() -> void:
	# The player-facing promise is "+40% at 4 pips". That's PCT_PER_POINT and
	# PER_STAT_CAP agreeing with each other, which is easy to break by tuning
	# one and forgetting the other.
	var advertised: float = StatAllocation.PCT_PER_POINT * float(StatAllocation.PER_STAT_CAP)
	var base: int = 100  # round numbers so rounding can't muddy the check
	assert_eq(StatAllocation.compute_delta("defense", base, StatAllocation.PER_STAT_CAP),
			int(round(float(base) * advertised)),
			"a maxed stat gains exactly PCT_PER_POINT x PER_STAT_CAP of its level_stat")


# =============================================================================
# THE ARCHETYPE ARGUMENT (why percentage beat flat)
# =============================================================================

func test_a_pip_is_worth_more_to_the_unit_already_invested_in_the_stat() -> void:
	# The whole reason percentage won. Under FLAT a glass cannon could buy its
	# way out of being fragile for the same price the tank pays to stay tanky,
	# and every unit converged on the middle.
	var glass_cannon: int = StatAllocation.compute_delta("defense", 3, 4)
	var tank: int = StatAllocation.compute_delta("defense", 20, 4)
	assert_gt(tank, glass_cannon * 3,
			"maxing DEF moves the tank far more than the mage — the spread survives")


func test_allocation_cannot_close_a_gap_between_archetypes() -> void:
	var glass_cannon_final: int = 3 + StatAllocation.compute_delta("defense", 3, 4)
	var tank_unspent: int = 20
	assert_lt(glass_cannon_final, tank_unspent,
			"a mage dumping everything into DEF still ends below a tank who spent nothing")


func test_hp_is_not_carved_out_of_percentage_mode() -> void:
	# HP used to route through the flat scalar in both modes. That carve-out
	# reintroduced the exact flattening percentage exists to avoid, so it was
	# removed — HP scales like everything else now.
	var small: int = StatAllocation.compute_delta("max_hp", 20, 4)
	var large: int = StatAllocation.compute_delta("max_hp", 50, 4)
	assert_gt(large, small,
			"a 50-HP unit gains more from 4 HP pips than a 20-HP unit does")


# =============================================================================
# ROUNDING (once on the total, never per point)
# =============================================================================

func test_rounding_happens_once_on_the_total() -> void:
	# level_stat 7 is the canonical trap: round(7 * 0.40) = 3, but summing
	# four separate round(7 * 0.10) gives 4. Per-point rounding would inflate
	# every low stat, which is backwards from the intent.
	var single_point: int = StatAllocation.compute_delta("defense", 7, 1)
	var four_points: int = StatAllocation.compute_delta("defense", 7, 4)
	assert_lt(four_points, single_point * 4,
			"the total is rounded once, so it lands under four rounded-up singles")


func test_the_curve_never_goes_backwards() -> void:
	# Monotonicity is the property rounding could plausibly break. Spending a
	# point must never reduce a stat, at any level_stat, at any point count.
	for level_stat: int in [1, 3, 7, 12, 20, 45, 99]:
		var previous: int = 0
		for points: int in range(1, StatAllocation.PER_STAT_CAP + 1):
			var delta: int = StatAllocation.compute_delta("defense", level_stat, points)
			assert_gte(delta, previous,
					"level_stat %d: point %d must not lower the stat" % [level_stat, points])
			previous = delta


func test_a_tiny_stat_still_gains_something_at_max_investment() -> void:
	# 4 pips on a level_stat of 1 is round(1 * 1.40) - 1 = 0. Pinned as KNOWN
	# and accepted, not overlooked: a stat that low is one the unit has no
	# business investing in, and a special case to force +1 would hand the
	# worst stat the best deal. Revisit only if real level_stats get that low.
	assert_eq(StatAllocation.compute_delta("defense", 1, 4), 0,
			"a level_stat of 1 rounds to no gain — accepted, see comment")
	assert_gt(StatAllocation.compute_delta("defense", 4, 4), 0,
			"anything with a realistic floor gains")


# =============================================================================
# GUARDS
# =============================================================================

func test_zero_and_negative_points_are_inert() -> void:
	assert_eq(StatAllocation.compute_delta("defense", 20, 0), 0, "unspent stats are unchanged")
	assert_eq(StatAllocation.compute_delta("defense", 20, -3), 0, "negative points can't drain a stat")


func test_the_pool_lands_exactly_on_the_advertised_size_at_max_level() -> void:
	# "A Lv 60 character will have 10 stat ups" is a design promise; the award
	# cadence has to actually produce it.
	var total: int = 0
	for level: int in range(1, 61):
		total += StatAllocation.points_awarded_at_level(level)
	assert_eq(total, StatAllocation.POOL_AT_MAX_LEVEL,
			"levels 1-60 award exactly POOL_AT_MAX_LEVEL points")


func test_the_pool_cannot_max_every_stat() -> void:
	# The scarcity that makes allocation a decision. 10 points against 8 stats
	# at 4 each means the player can max two stats and change, never all of
	# them — if this ever inverts, allocation stops being a build choice.
	var eight_stats_maxed: int = 8 * StatAllocation.PER_STAT_CAP
	assert_lt(StatAllocation.POOL_AT_MAX_LEVEL, eight_stats_maxed,
			"the pool is deliberately too small to max the board")
