## Pure integer-grid geometry: reachability and collinearity on the tactical grid.
## No autoloads, no Tile/Unit references — every query takes Vector2i grid cells
## and (where blocking matters) a Callable predicate, so callers plug in their own
## "is this cell blocked" rule. That keeps the geometry reusable: Extendo passes
## "impassable terrain for my unit's type", a future fog-of-war pass would pass
## "blocks sight", and Protector uses the pure axis query with no predicate at all.
##
## CONVENTIONS
##   - Coordinates are integer Vector2i cells (the project's "integer coordinates
##     only" rule). Nothing here uses floats, so there is no center-to-center
##     rounding drift — a deliberate choice over a true geometric ray.
##   - "between" always EXCLUDES both endpoints.
##
## WHO USES WHAT
##   - Extendo (+1 reach, "not through impassable") -> reach_is_clear().
##     Forgiving "reach-around" rule: the attack reaches if SOME minimal
##     orthogonal staircase of open cells connects attacker to target. A diagonal
##     is blocked only when BOTH of its corner cells are blocked; one open corner
##     is enough to poke around. (Chosen via the scratch/ LoS explorer.)
##   - Protector ("ranged attacks hit me instead of the unit directly behind me")
##     -> is_axis_aligned() + cells_between_on_axis(). Interception is limited to
##     the 8 compass directions (same row, same column, or a true 45-degree
##     diagonal). Arbitrary knight's-move offsets have no well-defined "behind"
##     and never intercept — which also keeps the math purely integer.
##
## To change Extendo's diagonal feel later, swap reach_is_clear's body; the two
## alternatives the explorer demonstrates (strict bounding-box, geometric ray)
## are drop-in replacements with the same signature.
class_name GridGeometry
extends RefCounted


## True when `to` lies on one of the 8 compass axes from `from`: same column
## (dx == 0), same row (dy == 0), or a true 45-degree diagonal (|dx| == |dy|).
## A cell is never axis-aligned with itself.
static func is_axis_aligned(from: Vector2i, to: Vector2i) -> bool:
	if from == to:
		return false
	var delta := to - from
	return delta.x == 0 or delta.y == 0 or absi(delta.x) == absi(delta.y)


## The integer cells strictly between `from` and `to` along a compass axis, in
## order starting from the cell adjacent to `from`. Returns an empty array when
## the two cells are NOT axis-aligned (no well-defined line) or are adjacent
## (nothing between them). This is Protector's "line of fire": the units a shot
## from `from` at `to` would pass over.
static func cells_between_on_axis(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not is_axis_aligned(from, to):
		return cells
	var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var cell := from + step
	while cell != to:
		cells.append(cell)
		cell += step
	return cells


## Forgiving "reach-around" clearance from `from` to `to`: true if there is a
## minimal monotone staircase of non-blocked cells connecting them (every step
## moves toward `to`). The endpoints are never tested — the attacker stands on
## `from`, and the target occupies `to`, so neither being "blocked" matters.
##
## `is_blocked` is `func(cell: Vector2i) -> bool`. For Extendo it answers "is this
## tile impassable for the attacker's type" (a null/off-map tile counts as
## blocked there). Pure DP over the bounding lattice — no recursion, no floats.
static func reach_is_clear(from: Vector2i, to: Vector2i, is_blocked: Callable) -> bool:
	var step_x := signi(to.x - from.x)
	var step_y := signi(to.y - from.y)
	var span_x := absi(to.x - from.x)
	var span_y := absi(to.y - from.y)

	# reachable[Vector2i(i, j)] = can we reach the cell i steps toward `to` in x
	# and j steps in y, through open cells, moving only toward `to`?
	var reachable := {}
	for i in range(span_x + 1):
		for j in range(span_y + 1):
			if i == 0 and j == 0:
				reachable[Vector2i(0, 0)] = true
				continue
			var cell := Vector2i(from.x + i * step_x, from.y + j * step_y)
			var is_endpoint := i == span_x and j == span_y
			if not is_endpoint and is_blocked.call(cell):
				reachable[Vector2i(i, j)] = false
				continue
			var reached := false
			if i > 0 and reachable.get(Vector2i(i - 1, j), false):
				reached = true
			elif j > 0 and reachable.get(Vector2i(i, j - 1), false):
				reached = true
			reachable[Vector2i(i, j)] = reached

	return reachable.get(Vector2i(span_x, span_y), false)
