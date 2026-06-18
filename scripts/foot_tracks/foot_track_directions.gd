## Pure direction logic for foot tracks: turns a walked path into directional
## track labels. No rendering, no engine state — fully unit-testable.
##
## Grid convention (see tilemap_grid_builder / GridZIndexHandler): +x = East,
## +y = North (higher grid_y is further north / back). Movement is orthogonal
## only, so every step is one cardinal and every tile connects 1-2 cardinals.
##
## A track label is the set of tile edges the path touches:
##   - endpoint tile (start or stop): one cardinal — "E"/"S"/"W"/"N"
##   - pass-through corner: "SE"/"WS"/"EN"/"NW"
##   - pass-through straight: N-S -> "SN"/"NS", E-W -> "WE"/"EW" (two
##     interchangeable variants, picked by the caller for anti-repeat)
## Labels match the atlas cell names in data/design/foot_tracks.md.
class_name FootTrackDirections


# Canonical cardinal ordering for building an unordered-pair key.
const _RANK := { "N": 0, "S": 1, "E": 2, "W": 3 }


## Cardinal for a one-step grid delta, or "" for a zero delta. Diagonal deltas
## (shouldn't happen — movement is orthogonal) collapse to the dominant axis.
static func cardinal_from_delta(delta: Vector2i) -> String:
	if delta == Vector2i.ZERO:
		return ""
	if absi(delta.x) >= absi(delta.y):
		return "E" if delta.x > 0 else "W"
	return "N" if delta.y > 0 else "S"


## The 1-2 cardinal edges a tile's track connects, given the previous and next
## cells along the walked path. Pass `null` for prev (start tile) or next (final
## tile). Edges point FROM the current cell TOWARD the neighbour.
static func connected_edges(prev_cell: Variant, cur_cell: Vector2i, next_cell: Variant) -> Array:
	var edges: Array[String] = []
	if prev_cell is Vector2i:
		var toward_prev := cardinal_from_delta((prev_cell as Vector2i) - cur_cell)
		if toward_prev != "":
			edges.append(toward_prev)
	if next_cell is Vector2i:
		var toward_next := cardinal_from_delta((next_cell as Vector2i) - cur_cell)
		if toward_next != "" and not edges.has(toward_next):
			edges.append(toward_next)
	return edges


## True when the two edges form a straight pass-through (N-S or E-W) — the only
## case with two interchangeable art variants.
static func is_straight(edges: Array) -> bool:
	if edges.size() != 2:
		return false
	var key := _pair_key(edges[0], edges[1])
	return key == "NS" or key == "EW"


## Track label for a set of connected edges. `straight_pick` selects between the
## two variants of a straight axis (0/1; alternate or randomize upstream); it is
## ignored for cardinals and corners.
static func label_for_edges(edges: Array, straight_pick: int = 0) -> String:
	if edges.is_empty():
		return ""
	if edges.size() == 1:
		return edges[0]
	match _pair_key(edges[0], edges[1]):
		"NS": return "NS" if (straight_pick & 1) == 1 else "SN"
		"EW": return "EW" if (straight_pick & 1) == 1 else "WE"
		"NE": return "EN"
		"NW": return "NW"
		"SE": return "SE"
		"SW": return "WS"
	return ""


## Convenience: resolve a tile's label straight from prev/cur/next cells.
static func label_for_tile(prev_cell: Variant, cur_cell: Vector2i, next_cell: Variant, straight_pick: int = 0) -> String:
	return label_for_edges(connected_edges(prev_cell, cur_cell, next_cell), straight_pick)


## Canonical 2-char key for an unordered cardinal pair (ordered by _RANK).
static func _pair_key(a: String, b: String) -> String:
	if int(_RANK.get(a, 9)) <= int(_RANK.get(b, 9)):
		return a + b
	return b + a
