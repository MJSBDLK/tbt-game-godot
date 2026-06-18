## Pure-logic tests for FootTrackDirections — walked path -> track label.
## Grid convention: +x = East, +y = North. Movement is orthogonal only.
extends GutTest


func test_cardinal_from_delta() -> void:
	assert_eq(FootTrackDirections.cardinal_from_delta(Vector2i(1, 0)), "E", "+x is East")
	assert_eq(FootTrackDirections.cardinal_from_delta(Vector2i(-1, 0)), "W", "-x is West")
	assert_eq(FootTrackDirections.cardinal_from_delta(Vector2i(0, 1)), "N", "+y is North")
	assert_eq(FootTrackDirections.cardinal_from_delta(Vector2i(0, -1)), "S", "-y is South")
	assert_eq(FootTrackDirections.cardinal_from_delta(Vector2i.ZERO), "", "zero delta has no cardinal")


func test_start_tile_is_exit_cardinal() -> void:
	# Start tile: no prev; the unit leaves toward the next cell (to the East).
	assert_eq(FootTrackDirections.label_for_tile(null, Vector2i(0, 0), Vector2i(1, 0)), "E",
			"Start tile connects the edge toward the next cell")


func test_end_tile_is_entry_cardinal() -> void:
	# Final tile: no next; entered from the West (prev is West).
	assert_eq(FootTrackDirections.label_for_tile(Vector2i(-1, 0), Vector2i(0, 0), null), "W",
			"Final tile connects the edge toward the previous cell")


func test_straight_pass_through_has_two_variants() -> void:
	# Enter from South, exit North -> straight N-S.
	var ns := FootTrackDirections.connected_edges(Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1))
	assert_true(FootTrackDirections.is_straight(ns), "S->N is a straight")
	assert_eq(FootTrackDirections.label_for_edges(ns, 0), "SN", "straight_pick 0 -> SN")
	assert_eq(FootTrackDirections.label_for_edges(ns, 1), "NS", "straight_pick 1 -> NS (anti-repeat variant)")
	# Enter from West, exit East -> straight E-W.
	var ew := FootTrackDirections.connected_edges(Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0))
	assert_true(FootTrackDirections.is_straight(ew), "W->E is a straight")
	assert_eq(FootTrackDirections.label_for_edges(ew, 0), "WE", "E-W straight_pick 0 -> WE")
	assert_eq(FootTrackDirections.label_for_edges(ew, 1), "EW", "E-W straight_pick 1 -> EW")


func test_corners_cover_all_four_diagonals() -> void:
	assert_eq(FootTrackDirections.label_for_tile(Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0)), "SE", "S->E corner")
	assert_eq(FootTrackDirections.label_for_tile(Vector2i(0, -1), Vector2i(0, 0), Vector2i(-1, 0)), "WS", "S->W corner")
	assert_eq(FootTrackDirections.label_for_tile(Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0)), "EN", "N->E corner")
	assert_eq(FootTrackDirections.label_for_tile(Vector2i(0, 1), Vector2i(0, 0), Vector2i(-1, 0)), "NW", "N->W corner")


func test_corner_is_direction_agnostic() -> void:
	# Enter East / exit South must equal enter South / exit East (same edge set).
	var a := FootTrackDirections.label_for_tile(Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, -1))
	var b := FootTrackDirections.label_for_tile(Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0))
	assert_eq(a, b, "Corner label is independent of travel direction")
	assert_eq(a, "SE", "{E,S} resolves to SE")


func test_corner_is_not_straight() -> void:
	var edges := FootTrackDirections.connected_edges(Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0))
	assert_false(FootTrackDirections.is_straight(edges), "A corner is not a straight")


func test_self_crossing_labels_each_visit_independently() -> void:
	# A revisited cell yields a label per visit (caller stacks them). Visit 1:
	# entered West, left North. Visit 2: entered South, left East.
	assert_eq(FootTrackDirections.label_for_tile(Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1)), "NW", "visit 1: W->N")
	assert_eq(FootTrackDirections.label_for_tile(Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0)), "SE", "visit 2: S->E")


func test_degenerate_uturn_collapses_to_single_cardinal() -> void:
	# prev and next on the same side (a U-turn within one tile) dedupes to one
	# edge rather than emitting an invalid two-edge label.
	assert_eq(FootTrackDirections.label_for_tile(Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, -1)), "S",
			"Same prev/next edge collapses to a single cardinal")
