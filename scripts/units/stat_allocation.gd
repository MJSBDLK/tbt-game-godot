## Stat-up allocation rules and math.
##
## A unit collects stat-up points as it levels (~10 by L60). Between missions
## the player distributes them across 8 stats — at most PER_STAT_CAP into any
## one stat. The Mode constant picks how each point is realized:
##
##   PERCENTAGE — +PCT_PER_POINT% per point, computed against the unit's
##                level_stat (base + growth). Rounding happens once on the
##                final total to keep the curve monotonic. THE SHIPPING MODE.
##   FLAT       — +1 per point on every stat (HP scales by HP_FLAT_PER_POINT).
##                Kept only as a comparison mode; see below for why it lost.
##
## The same point counts feed both modes — flip the constant to compare
## without disturbing player allocation state. Points are what's stored;
## the stat delta is always derived, so a mode flip re-derives every save
## correctly rather than baking in stale numbers.
##
## WHY PERCENTAGE (RQD, 2026-08-05). The worry was that every unit would dump
## its whole pool into DEF and RES. Percentage doesn't make defence less
## attractive — it makes each point scale with what the unit ALREADY has, which
## preserves archetypes instead of flattening them:
##
##   glass cannon, DEF 3   -> +40% = 4  (+1)   |  flat +4 would give 7  (+4)
##   tank,         DEF 20  -> +40% = 28 (+8)   |  flat +4 would give 24 (+4)
##
## Under FLAT the glass cannon more than doubles its DEF and buys its way out of
## being fragile; every unit converges on the middle. Under PERCENTAGE the tank
## stays tanky and the mage stays paper. A tank maxing DEF is still correct
## play — the point was never to discourage it, only to stop it from erasing
## what makes units different from each other.
##
## PROVISIONAL, awaiting playtest. Watch ATH especially: multi-hit is a RATIO
## cliff at 2x/3x/4x the defender's ATH, so +40% ATH pays nothing at all until
## it tips past a threshold and then doubles your damage. A step that steep may
## quietly beat DEF/RES as the optimal dump once players find it.
class_name StatAllocation


enum Mode { FLAT, PERCENTAGE }

const MODE: Mode = Mode.PERCENTAGE

const POOL_AT_MAX_LEVEL: int = 10
const PER_STAT_CAP: int = 4

# FLAT mode only: every point on a non-HP stat = +1; HP gets +2.
const HP_FLAT_PER_POINT: int = 2

# PERCENTAGE mode: every point = +10% of level_stat. 4 points = +40%.
const PCT_PER_POINT: float = 0.10


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
## level_stat (base + growth_gains) is `level_stat`.
##
## PERCENTAGE treats max_hp like every other stat — a flat HP carve-out would
## reintroduce exactly the archetype-flattening the mode exists to avoid (a
## 20-HP unit and a 50-HP unit buying the same +2 makes them more alike). HP
## keeps the flat scalar in FLAT mode only.
##
## Rounding happens ONCE on the final total, never per point: round(7 * 0.40)
## is 3, but 4 * round(7 * 0.10) is 4. Per-point rounding would silently
## inflate every low stat, which is the opposite of the intent.
static func compute_delta(stat_name: String, level_stat: int, points: int) -> int:
	if points <= 0:
		return 0
	# The cap is enforced UI-side (UnitSheet's stat rows), so nothing in the data
	# model stops a bad caller — or a save written by an older build — from
	# handing us more. Loud in dev, clamped in release rather than paying out.
	assert(points <= PER_STAT_CAP,
			"%s got %d allocated points, over the %d cap" % [stat_name, points, PER_STAT_CAP])
	var effective_points: int = mini(points, PER_STAT_CAP)
	match MODE:
		Mode.FLAT:
			return effective_points * (HP_FLAT_PER_POINT if stat_name == "max_hp" else 1)
		Mode.PERCENTAGE:
			var multiplier: float = 1.0 + PCT_PER_POINT * float(effective_points)
			return int(roundf(float(level_stat) * multiplier)) - level_stat
	return 0
