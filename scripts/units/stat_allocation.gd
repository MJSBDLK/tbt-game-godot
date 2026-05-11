## Stat-up allocation rules and math.
##
## A unit collects stat-up points as it levels (~10 by L60). Between missions
## the player distributes them across 8 stats — at most PER_STAT_CAP into any
## one stat. The Mode constant picks how each point is realized:
##
##   FLAT       — +1 per point on every stat (HP scales by HP_FLAT_PER_POINT)
##   PERCENTAGE — +PCT_PER_POINT% per point, computed against the unit's
##                level_stat (base + growth). Rounding happens once on the
##                final total to keep the curve monotonic.
##
## The same point counts feed both modes — flip the constant to compare
## without disturbing player allocation state.
class_name StatAllocation


enum Mode { FLAT, PERCENTAGE }

const MODE: Mode = Mode.FLAT

const POOL_AT_MAX_LEVEL: int = 10
const PER_STAT_CAP: int = 4

# FLAT mode: every point on a non-HP stat = +1; HP gets +2.
const HP_FLAT_PER_POINT: int = 2

# PERCENTAGE mode: every point = +6.25% of level_stat. 4 points = +25%.
const PCT_PER_POINT: float = 0.0625


## Stat-up points granted on reaching `new_level`. Lumped at every 6th level
## so a L60 unit ends up with exactly POOL_AT_MAX_LEVEL points to distribute.
## Tune the cadence here without disturbing already-allocated state — points
## the unit has already spent stay spent.
static func points_awarded_at_level(new_level: int) -> int:
	if new_level <= 0:
		return 0
	if new_level % 6 == 0:
		return 1
	return 0


## Returns the stat delta produced by `points` allocations on a stat whose
## level_stat (base + growth_gains) is `level_stat`. HP routes through the
## flat HP scalar even in PERCENTAGE mode for now — keep HP balance constant
## across modes and tune separately.
static func compute_delta(stat_name: String, level_stat: int, points: int) -> int:
	if points <= 0:
		return 0
	if stat_name == "max_hp":
		return points * HP_FLAT_PER_POINT
	match MODE:
		Mode.FLAT:
			return points
		Mode.PERCENTAGE:
			var multiplier: float = 1.0 + PCT_PER_POINT * float(points)
			return int(roundf(float(level_stat) * multiplier)) - level_stat
	return 0
