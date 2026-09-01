## Visualizes the planned movement path for a unit using animated beacons.
## Each tile along the path gets a non-rotated beacon sprite. Beacons play a
## 5-step pulse (idle -> mid -> dipped -> mid -> idle) staggered along the path
## so the wave appears to travel from the unit toward the destination. After
## the last tile resolves to idle, the cycle holds for CYCLE_PAUSE_MS, then
## loops. Beacon color follows unit faction: blue for player, red for enemy.
## Set as top_level in unit.tscn so positions are in world space.
##
## Destination ghost (RQD 2026-08-21, todo #4; ride upgrade RQD 2026-08-31):
## while a PLAYER unit has a plan, a projection silhouette of the unit
## (UnitGhost — the same material as the displacement preview's "where the
## shove puts them" ghosts) RIDES the planned path — origin to destination,
## the displacement-style arrow drawing behind it, a hold at the landing,
## then loop; every plan edit restarts the ride. The beacons stay the path;
## the ghost rehearses the walk. Player-only: the AI's walk is already
## animated and its beacons already show the route. Reduce-motion parks the
## ride at its landing state (ghost on the destination, arrow drawn full) and
## the shader freezes its static/tracking flicker. The STAGED ghost
## (show_staged_ghost, ACT_THEN_WALK) never rides — a committed plan just
## marks where the unit will stand. Above the whole board (an informational
## overlay — same z rule as DisplacementPreviewRenderer.OVERLAY_Z_INDEX).
class_name PathVisualizer
extends Node2D


const FRAME_SIZE: Vector2i = Vector2i(9, 9)

# Animation timings (milliseconds). Tune at playtest.
const FRAME_DURATION_MS: float = 125
const TILE_DELAY_MS: float = 200.0
const CYCLE_PAUSE_MS: float = 400.0

# Strip layout: 3 frames laid out horizontally, 9px each. Index 2 (last) is the
# idle/rest pose; index 0 is the deepest part of the dip. Sequence opens and
# closes on idle so wave-start/end blend invisibly into the rest state.
const WAVE_SEQUENCE: Array[int] = [2, 1, 0, 1, 2]
const IDLE_STRIP_INDEX: int = 2

const _BEACON_BLUE: Texture2D = preload("res://art/sprites/ui/move_preview/path_beacon/blue.png")
const _BEACON_RED: Texture2D = preload("res://art/sprites/ui/move_preview/path_beacon/red.png")

# Ghost ride (RQD 2026-08-31): under motion the destination ghost doesn't just
# park — it RIDES the plan, walking the path from the origin with the
# displacement-style arrow drawing behind it, holding at the destination, then
# looping. Every plan edit restarts the ride. Reduce-motion parks at the
# landing state: ghost on the destination, arrow drawn full. The staged ghost
# (ACT_THEN_WALK, show_staged_ghost) never rides — rehearsal is planning-time;
# a committed plan just marks where the unit will stand. Tune at playtest.
# WORLD px/s — tiles are 16 world px apart, so 133 ≈ 0.12 s/tile (RQD bump
# from 88). Window resolution, integer scale, and camera zoom rescale the
# LOOK only (Camera2D.zoom = screen px per world px); delta-timed, so frame
# rate doesn't touch it either.
const GHOST_SPEED_PX_PER_SECOND: float = 133.0
const GHOST_HOLD_AT_DESTINATION_SECONDS: float = 0.7


var _path_tiles: Array[Tile] = []
var _faction: Enums.UnitFaction = Enums.UnitFaction.PLAYER
var _beacon_sprites: Array[Sprite2D] = []
var _animation_time_ms: float = 0.0
# Destination ghost — one per plan, rebuilt on every update, freed on clear.
var _ghost: Sprite2D = null
var _ghost_material: ShaderMaterial = null
# Ghost-ride state. _walk_floor_points is the tile-center polyline (origin
# included, self-crossing duplicates preserved); the ghost floats above it at
# _ghost_anchor. Arrow nodes wear the displacement recipe verbatim.
var _walk_floor_points: PackedVector2Array = PackedVector2Array()
var _walk_total_px: float = 0.0
var _walk_elapsed_seconds: float = 0.0
var _ghost_anchor: Vector2 = Vector2.ZERO
var _arrow_line: Line2D = null
var _arrow_head: Polygon2D = null
var _walking: bool = false


func _ready() -> void:
	z_index = ZIndexCalculator.calculate_sorting_order(
		0, 100, ZIndexCalculator.ZIndexLayer.PATH_INDICATORS)
	_ghost_material = UnitGhost.make_material()
	if Settings != null:
		Settings.changed.connect(_on_settings_changed)


func _on_settings_changed() -> void:
	UnitGhost.set_animated(_ghost_material, Settings.ui_motion_enabled)
	# Motion flipping OFF mid-plan parks the ride at its landing state; flipping
	# ON revives it on the next plan edit (no unit ref is kept to rebuild from).
	if not Settings.ui_motion_enabled and _walking:
		_walking = false
		if _walk_total_px > 0.0:
			_apply_walk_progress(_walk_total_px)


func update_path(unit: Node2D) -> void:
	_faction = unit.get("faction")

	var current_tile: Tile = unit.get("current_tile")
	var planned_waypoints: Array = unit.get("planned_waypoints")

	var full_path: Array[Tile] = []
	if current_tile != null and not planned_waypoints.is_empty():
		var start: Tile = current_tile
		for waypoint: Variant in planned_waypoints:
			var segment := GridManager.find_path(start, waypoint.tile, unit)
			# Preserve duplicates: when a path crosses itself, the cross-tile
			# spawns a stacked beacon whose phase = its index in full_path, so
			# the pulse wave visits it again in walked order. find_path excludes
			# the start tile, so segments don't introduce seam dupes — every
			# repeat here reflects a real revisit the player drew.
			full_path.append_array(segment)
			start = waypoint.tile

	_path_tiles = full_path
	_animation_time_ms = 0.0
	_rebuild_beacon_nodes()
	_rebuild_destination_ghost(unit)


func clear_arrows() -> void:
	_path_tiles.clear()
	_rebuild_beacon_nodes()
	_clear_ghost()
	_clear_walk()


func has_destination_ghost() -> bool:
	return _ghost != null and is_instance_valid(_ghost)


## ACT_THEN_WALK (todo 4A): the plan is confirmed but the walk is deferred.
## Beacons clear — the path is spent — while the ghost alone holds the
## destination until the action commits (play_deferred_walk clears it) or the
## plan cancels. Call BEFORE the unit's logic claims the destination:
## UnitGhost.anchor_offset measures the sprite against current_tile, so both
## must still agree on the origin.
func show_staged_ghost(unit: Node2D, tile: Tile) -> void:
	_path_tiles.clear()
	_rebuild_beacon_nodes()
	_clear_ghost()
	_clear_walk()
	if tile == null or unit.get("faction") != Enums.UnitFaction.PLAYER:
		return
	_park_ghost(unit, tile)


## Park a projection of the unit on the plan's last tile. Sprite-space anchor
## (UnitGhost.anchor_offset) so a mid-body-anchored cast lands where the real
## sprite would. Absolute z above the board: a "where will I stand" you can't
## see through the unit in front of it isn't a preview.
func _rebuild_destination_ghost(unit: Node2D) -> void:
	_clear_ghost()
	_clear_walk()
	if _path_tiles.is_empty() or _faction != Enums.UnitFaction.PLAYER:
		return
	_park_ghost(unit, _path_tiles.back())
	if _ghost != null:
		_build_ghost_ride(unit)


func _park_ghost(unit: Node2D, tile: Tile) -> void:
	var ghost := UnitGhost.build(unit, _ghost_material)
	if ghost == null:
		return
	ghost.z_as_relative = false
	ghost.z_index = DisplacementPreviewRenderer.OVERLAY_Z_INDEX
	add_child(ghost)
	ghost.global_position = tile.global_position + UnitGhost.anchor_offset(unit)
	_ghost = ghost


func _clear_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


# =============================================================================
# GHOST RIDE — the plan rehearses itself (RQD 2026-08-31)
# =============================================================================

## Set up the ride: the tile-center polyline (origin first — anchor_offset is
## measured against current_tile, which still IS the origin during planning),
## the arrow nodes, and the starting pose. Under motion the ghost opens at the
## origin and _process drives it; reduce-motion applies the landing state once
## — ghost on the destination, arrow drawn full.
func _build_ghost_ride(unit: Node2D) -> void:
	var points := PackedVector2Array()
	var origin: Tile = unit.get("current_tile") as Tile
	if origin != null:
		points.append(origin.global_position)
	for tile: Tile in _path_tiles:
		points.append(tile.global_position)
	_walk_floor_points = points
	_walk_total_px = path_length(points)
	_ghost_anchor = UnitGhost.anchor_offset(unit)
	_walk_elapsed_seconds = 0.0
	if _walk_total_px <= 0.0:
		return
	_spawn_ride_arrow()
	if Settings == null or Settings.ui_motion_enabled:
		_walking = true
		_apply_walk_progress(0.0)
	else:
		_walking = false
		_apply_walk_progress(_walk_total_px)


## The displacement arrow recipe — same width, same shared static material,
## and the neutral-intent AZURE family (a move plan damages nothing; red =
## damaging, green = healing). Azure 5, not the displacement arrows' 7: the
## ghost shader's tint sits right at the 7 neighborhood, and the trail must
## read as a separate object from the phantom riding it (RQD 2026-08-31).
## Azure 4 is the next notch down if 5 still hugs it. Drawn after the ghost
## like the displacement renderer draws its arrows, so the tip rides visibly
## over the silhouette.
func _spawn_ride_arrow() -> void:
	var color: Color = GameColorPalette.get_color("Azure", 5)
	var line := Line2D.new()
	line.width = DisplacementPreviewRenderer.ARROW_WIDTH
	line.default_color = color
	line.material = DisplacementPreviewRenderer.OVERLAY_MATERIAL
	line.z_as_relative = false
	line.z_index = DisplacementPreviewRenderer.OVERLAY_Z_INDEX
	add_child(line)
	# Pin the line's frame to the world so its points can be world coords even
	# if the visualizer ever moves off the origin.
	line.global_position = Vector2.ZERO
	_arrow_line = line

	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(-3.0, 2.0), Vector2(-3.0, -2.0)])
	head.color = color
	head.material = DisplacementPreviewRenderer.OVERLAY_MATERIAL
	head.z_as_relative = false
	head.z_index = DisplacementPreviewRenderer.OVERLAY_Z_INDEX
	head.visible = false
	add_child(head)
	_arrow_head = head


func _clear_walk() -> void:
	_walking = false
	_walk_floor_points = PackedVector2Array()
	_walk_total_px = 0.0
	_walk_elapsed_seconds = 0.0
	for node: Node in [_arrow_line, _arrow_head]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_arrow_line = null
	_arrow_head = null


## One ride frame: advance, wrap after the destination hold, pose everything.
func _step_ghost_walk(delta: float) -> void:
	if not _walking or _ghost == null or not is_instance_valid(_ghost) \
			or _walk_total_px <= 0.0:
		return
	_walk_elapsed_seconds += delta
	var travel_seconds: float = _walk_total_px / GHOST_SPEED_PX_PER_SECOND
	var loop_seconds: float = travel_seconds + GHOST_HOLD_AT_DESTINATION_SECONDS
	if _walk_elapsed_seconds >= loop_seconds:
		_walk_elapsed_seconds = fmod(_walk_elapsed_seconds, loop_seconds)
	var progress_px: float = minf(
			_walk_elapsed_seconds * GHOST_SPEED_PX_PER_SECOND, _walk_total_px)
	_apply_walk_progress(progress_px)


## Pose the ghost, trail and head for a given arc-length along the ride.
func _apply_walk_progress(progress_px: float) -> void:
	if _ghost == null or not is_instance_valid(_ghost) or _walk_floor_points.is_empty():
		return
	var sample := walk_sample(_walk_floor_points, progress_px)
	var floor_position: Vector2 = sample.position
	_ghost.global_position = floor_position + _ghost_anchor
	if _arrow_line != null and is_instance_valid(_arrow_line):
		_arrow_line.points = trail_points(_walk_floor_points, progress_px)
	if _arrow_head != null and is_instance_valid(_arrow_head):
		var segment: int = sample.segment
		var direction: Vector2 = Vector2.RIGHT
		if _walk_floor_points.size() > segment + 1:
			direction = _walk_floor_points[segment + 1] - _walk_floor_points[segment]
		# The head needs a few px of trail behind it before it reads as an
		# arrow rather than a floating wedge.
		_arrow_head.visible = progress_px > 2.0
		_arrow_head.global_position = floor_position
		if direction.length_squared() > 0.0:
			_arrow_head.rotation = direction.angle()


## Pure ride math, pinned by tests: where `distance` px along `points` lands,
## and which segment carries it. Clamps to both ends.
static func walk_sample(points: PackedVector2Array, distance: float) -> Dictionary:
	if points.is_empty():
		return {position = Vector2.ZERO, segment = 0}
	if points.size() == 1 or distance <= 0.0:
		return {position = points[0], segment = 0}
	var remaining := distance
	for i: int in range(points.size() - 1):
		var segment_vector := points[i + 1] - points[i]
		var segment_length := segment_vector.length()
		if remaining <= segment_length:
			var t := 0.0 if segment_length == 0.0 else remaining / segment_length
			return {position = points[i] + segment_vector * t, segment = i}
		remaining -= segment_length
	return {position = points[-1], segment = points.size() - 2}


## The polyline from the start up to `distance` px in — the arrow's trail.
static func trail_points(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	var sample := walk_sample(points, distance)
	var out := PackedVector2Array()
	for i: int in range(mini(int(sample.segment) + 1, points.size())):
		out.append(points[i])
	out.append(sample.position)
	return out


static func path_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i: int in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total


func _process(delta: float) -> void:
	_step_ghost_walk(delta)
	if _beacon_sprites.is_empty():
		return
	_animation_time_ms += delta * 1000.0

	var wave_duration_ms: float = WAVE_SEQUENCE.size() * FRAME_DURATION_MS
	var last_start_ms: float = (_beacon_sprites.size() - 1) * TILE_DELAY_MS
	var cycle_total_ms: float = last_start_ms + wave_duration_ms + CYCLE_PAUSE_MS
	var t_in_cycle: float = fmod(_animation_time_ms, cycle_total_ms)

	for index: int in range(_beacon_sprites.size()):
		var sprite: Sprite2D = _beacon_sprites[index]
		var atlas: AtlasTexture = sprite.texture as AtlasTexture
		if atlas == null:
			continue

		var local_t: float = t_in_cycle - index * TILE_DELAY_MS
		var frame_index: int = IDLE_STRIP_INDEX
		if local_t >= 0.0 and local_t < wave_duration_ms:
			var seq_index: int = int(local_t / FRAME_DURATION_MS)
			seq_index = clamp(seq_index, 0, WAVE_SEQUENCE.size() - 1)
			frame_index = WAVE_SEQUENCE[seq_index]

		atlas.region = Rect2(frame_index * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)


func _rebuild_beacon_nodes() -> void:
	for sprite: Sprite2D in _beacon_sprites:
		sprite.queue_free()
	_beacon_sprites.clear()

	if _path_tiles.is_empty():
		return

	var strip: Texture2D = _BEACON_RED if _faction == Enums.UnitFaction.ENEMY else _BEACON_BLUE

	for tile: Tile in _path_tiles:
		var sprite := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = strip
		atlas.region = Rect2(IDLE_STRIP_INDEX * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		sprite.texture = atlas
		sprite.global_position = tile.global_position
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		_beacon_sprites.append(sprite)
