## Phase 2 scaffolding: GridGeometry — pure integer-grid queries shared by Extendo
## (forgiving reach-around) and Protector (axis-aligned line of fire). All cases
## are pure math; the blocking predicate is a simple set membership.
extends GutTest


## Build a func(cell: Vector2i) -> bool that reports the given cells as blocked.
func _blocked(cells: Array) -> Callable:
	var blocked := {}
	for c: Vector2i in cells:
		blocked[c] = true
	return func(cell: Vector2i) -> bool: return blocked.has(cell)


# =============================================================================
# is_axis_aligned
# =============================================================================

func test_orthogonal_is_aligned() -> void:
	assert_true(GridGeometry.is_axis_aligned(Vector2i(0, 0), Vector2i(3, 0)), "same row")
	assert_true(GridGeometry.is_axis_aligned(Vector2i(0, 0), Vector2i(0, -4)), "same column")


func test_true_diagonal_is_aligned() -> void:
	assert_true(GridGeometry.is_axis_aligned(Vector2i(0, 0), Vector2i(2, 2)), "+45")
	assert_true(GridGeometry.is_axis_aligned(Vector2i(0, 0), Vector2i(-3, 3)), "-45")


func test_knights_move_is_not_aligned() -> void:
	assert_false(GridGeometry.is_axis_aligned(Vector2i(0, 0), Vector2i(2, 1)),
			"an off-axis offset has no well-defined 'behind'")


func test_same_cell_is_not_aligned() -> void:
	assert_false(GridGeometry.is_axis_aligned(Vector2i(1, 1), Vector2i(1, 1)))


# =============================================================================
# cells_between_on_axis
# =============================================================================

func test_orthogonal_between_in_order() -> void:
	assert_eq(GridGeometry.cells_between_on_axis(Vector2i(0, 0), Vector2i(3, 0)),
			[Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i],
			"ordered from the cell next to `from`")


func test_diagonal_between() -> void:
	assert_eq(GridGeometry.cells_between_on_axis(Vector2i(0, 0), Vector2i(3, 3)),
			[Vector2i(1, 1), Vector2i(2, 2)] as Array[Vector2i])


func test_adjacent_has_nothing_between() -> void:
	assert_eq(GridGeometry.cells_between_on_axis(Vector2i(0, 0), Vector2i(1, 0)).size(), 0,
			"adjacent cells have no cell between them")


func test_non_axis_returns_empty() -> void:
	assert_eq(GridGeometry.cells_between_on_axis(Vector2i(0, 0), Vector2i(2, 1)).size(), 0,
			"off-axis pairs yield no line of fire")


# =============================================================================
# reach_is_clear — straight lines
# =============================================================================

func test_straight_clear() -> void:
	assert_true(GridGeometry.reach_is_clear(Vector2i(0, 0), Vector2i(2, 0), _blocked([])),
			"open straight reach succeeds")


func test_straight_blocked_by_middle() -> void:
	assert_false(GridGeometry.reach_is_clear(Vector2i(0, 0), Vector2i(2, 0), _blocked([Vector2i(1, 0)])),
			"a wall on the only intervening cell blocks a straight poke")


func test_adjacent_always_reaches() -> void:
	# No intervening cell exists, so adjacency reaches regardless of the predicate.
	assert_true(GridGeometry.reach_is_clear(Vector2i(0, 0), Vector2i(1, 0), _blocked([Vector2i(5, 5)])))


func test_endpoints_are_never_treated_as_blocked() -> void:
	# The target tile is "blocked" (occupied/impassable) but still reachable: the
	# endpoint is never tested, only the path to it.
	assert_true(GridGeometry.reach_is_clear(Vector2i(0, 0), Vector2i(2, 0), _blocked([Vector2i(2, 0)])),
			"the target cell itself is not a path obstacle")


# =============================================================================
# reach_is_clear — diagonals (the forgiving reach-around rule)
# =============================================================================

func test_diagonal_open_reaches() -> void:
	assert_true(GridGeometry.reach_is_clear(Vector2i(0, 0), Vector2i(1, 1), _blocked([])))


func test_diagonal_one_corner_blocked_still_reaches() -> void:
	# (1,0) walled, (0,1) open -> poke around the open corner.
	assert_true(GridGeometry.reach_is_clear(Vector2i(0, 0), Vector2i(1, 1), _blocked([Vector2i(1, 0)])),
			"one open corner is enough (forgiving reach-around)")
	assert_true(GridGeometry.reach_is_clear(Vector2i(0, 0), Vector2i(1, 1), _blocked([Vector2i(0, 1)])),
			"either corner works")


func test_diagonal_both_corners_blocked_is_blocked() -> void:
	assert_false(GridGeometry.reach_is_clear(Vector2i(0, 0), Vector2i(1, 1),
			_blocked([Vector2i(1, 0), Vector2i(0, 1)])),
			"a fully-walled corner stops the diagonal")


func test_negative_direction_diagonal() -> void:
	# Reach down-left; only the down corner is open. Confirms sign handling.
	assert_true(GridGeometry.reach_is_clear(Vector2i(5, 5), Vector2i(4, 4),
			_blocked([Vector2i(4, 5)])),
			"works in negative x/y directions too")


func test_longer_l_path_reaches_around_a_block() -> void:
	# (0,0) -> (2,2). Wall the whole x-first edge; the staircase routes up first.
	assert_true(GridGeometry.reach_is_clear(Vector2i(0, 0), Vector2i(2, 2),
			_blocked([Vector2i(1, 0), Vector2i(2, 0)])),
			"a monotone open staircase still exists via the y-first route")


func test_longer_path_fully_walled_is_blocked() -> void:
	# Block both cells adjacent to `from`; no staircase can start.
	assert_false(GridGeometry.reach_is_clear(Vector2i(0, 0), Vector2i(2, 2),
			_blocked([Vector2i(1, 0), Vector2i(0, 1)])),
			"no open first step -> no reach")
