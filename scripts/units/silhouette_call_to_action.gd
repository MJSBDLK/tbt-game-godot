## SilhouetteCallToAction — the §14 call-to-action rings, cut to a unit's
## outline. The button version is amber rings converging onto a border; this
## one spawns InteractiveButton.CTA_SPAWN_INSET_PIXELS outside the sprite's
## silhouette, steps in a pixel at a time on the button's own stepping
## (cta_ring_inset_at) and lands ON the art's edge pixels, which catch the
## light. Plays in bursts — UNIT_CALL_TO_ACTION_PASSES passes of
## UNIT_CALL_TO_ACTION_SECONDS, each starting UNIT_CALL_TO_ACTION_STAGGER of
## a pass after the one before (so 2–3 rings can be in flight at once), then
## UNIT_CALL_TO_ACTION_REST_SECONDS of nothing (all ArtVariables) — and
## repeats until whoever started it frees it.
## Reduce-motion parks it on the edge, bright and steady.
##
## The End Turn warning (SystemMenuPanel.show_end_turn_confirm) plays it on
## every unit that can still act and frees it when the question goes away.
## That bends §14's one-CTA-on-screen rule on purpose: it's one invitation,
## and the board is paused under a modal question while it runs.
##
## The outline is the sprite's frame when it starts. Map idles are one still
## frame today; an animated idle has to hold its frame while this runs, or the
## rings trace a pose the sprite has already left.
class_name SilhouetteCallToAction
extends Node2D


const NODE_NAME: String = "SilhouetteCallToAction"
## Art pixels at or above this alpha are the silhouette.
const OPAQUE_ALPHA: float = 0.5

## Frame key → rings (see rings_for). A unit's idle frame never changes, so
## every warning after the first is free.
static var _ring_cache: Dictionary = {}

var _rings: Array[PackedVector2Array] = []
## The frame's top-left in the sprite's local space (Sprite2D.get_rect).
var _origin: Vector2 = Vector2.ZERO
var _started_ms: int = 0


## Starts the bursts on `sprite`, replacing any already running there. The
## caller frees the returned node to stop them. Returns null (and draws
## nothing) when the frame's pixels can't be read.
static func play_on(sprite: Sprite2D) -> SilhouetteCallToAction:
	if sprite == null or sprite.texture == null:
		return null
	var running: Node = sprite.get_node_or_null(NODE_NAME)
	if running != null:
		running.free()
	var rings: Array[PackedVector2Array] = _rings_for_sprite(sprite)
	if rings.is_empty():
		return null
	var effect := SilhouetteCallToAction.new()
	effect.name = NODE_NAME
	effect._rings = rings
	effect._origin = sprite.get_rect().position
	effect._started_ms = Time.get_ticks_msec()
	sprite.add_child(effect)
	return effect


## Pixel rings around a silhouette, in frame space. rings[0] is the art's own
## edge (opaque pixels with a clear neighbour); rings[d] for d ≥ 1 is every
## clear pixel at Chebyshev distance d from the art, so each ring is the
## outline grown by d — the button ring's rect inset, for any shape. Rings
## reach past the frame, so coordinates can be negative.
static func rings_for(frame: Image, max_inset: int) -> Array[PackedVector2Array]:
	assert(max_inset >= 1, "SilhouetteCallToAction: rings need at least one step out")
	var width: int = frame.get_width()
	var height: int = frame.get_height()
	var grid_width: int = width + 2 * max_inset
	var grid_height: int = height + 2 * max_inset
	var distance := PackedInt32Array()
	distance.resize(grid_width * grid_height)
	distance.fill(-1)
	var queue := PackedInt32Array()
	for y: int in height:
		for x: int in width:
			if frame.get_pixel(x, y).a >= OPAQUE_ALPHA:
				var index: int = (y + max_inset) * grid_width + x + max_inset
				distance[index] = 0
				queue.append(index)
	var rings: Array[PackedVector2Array] = []
	for inset: int in max_inset + 1:
		rings.append(PackedVector2Array())
	# Breadth-first from every art pixel at once over 8 neighbours: the step
	# count IS the Chebyshev distance, and it stops max_inset out.
	var head: int = 0
	while head < queue.size():
		var index: int = queue[head]
		head += 1
		var reach: int = distance[index]
		if reach >= max_inset:
			continue
		@warning_ignore("integer_division")
		var grid_y: int = index / grid_width
		var grid_x: int = index % grid_width
		for dy: int in [-1, 0, 1]:
			for dx: int in [-1, 0, 1]:
				var neighbour: int = (grid_y + dy) * grid_width + grid_x + dx
				if (dx == 0 and dy == 0) or distance[neighbour] != -1:
					continue
				distance[neighbour] = reach + 1
				queue.append(neighbour)
				rings[reach + 1].append(Vector2(grid_x + dx - max_inset, grid_y + dy - max_inset))
	# The edge: art pixels touching the first ring. The padding keeps every
	# art pixel's neighbours inside the grid.
	for y: int in height:
		for x: int in width:
			var index: int = (y + max_inset) * grid_width + x + max_inset
			if distance[index] != 0:
				continue
			var touches_clear: bool = false
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					if distance[index + dy * grid_width + dx] == 1:
						touches_clear = true
			if touches_clear:
				rings[0].append(Vector2(x, y))
	return rings


static func _rings_for_sprite(sprite: Sprite2D) -> Array[PackedVector2Array]:
	var sheet: Image = UnitShadow.readable_sheet(sprite.texture)
	if sheet == null:
		return []
	var source := Rect2i(sprite.region_rect) if sprite.region_enabled \
			else Rect2i(Vector2i.ZERO, sheet.get_size())
	@warning_ignore("integer_division")
	var frame_size: Vector2i = source.size / Vector2i(sprite.hframes, sprite.vframes)
	source = Rect2i(source.position + frame_size * sprite.frame_coords, frame_size)
	# Instance id, not RID: every AtlasTexture cut from one sheet shares the
	# sheet's RID.
	var key := "%s|%s|%s|%s" % [sprite.texture.get_instance_id(), source,
			sprite.flip_h, sprite.flip_v]
	if not _ring_cache.has(key):
		var frame: Image = sheet.get_region(source)
		if sprite.flip_h:
			frame.flip_x()
		if sprite.flip_v:
			frame.flip_y()
		_ring_cache[key] = rings_for(frame, InteractiveButton.CTA_SPAWN_INSET_PIXELS)
	return _ring_cache[key]


## Every pass in flight `elapsed` seconds in, as its 0 → 1 phase. Pass k of a
## burst starts `stagger` passes after pass k-1 (1.0 = when it ends, 0.5 =
## halfway through, so rings overlap); the rest counts from the end of the
## last pass. Empty while resting, and when the dials leave no pass.
static func pass_phases_at(elapsed: float, pass_seconds: float, passes: int,
		stagger: float, rest_seconds: float) -> PackedFloat32Array:
	var phases := PackedFloat32Array()
	if pass_seconds <= 0.0 or passes <= 0:
		return phases
	var spacing: float = pass_seconds * maxf(stagger, 0.0)
	var burst: float = spacing * (passes - 1) + pass_seconds
	var into_cycle: float = fmod(elapsed, burst + maxf(rest_seconds, 0.0))
	for index: int in passes:
		var into_pass: float = into_cycle - spacing * index
		if into_pass >= 0.0 and into_pass < pass_seconds:
			phases.append(into_pass / pass_seconds)
	return phases


## The knobs are read every frame, so the dev console turns them live.
func current_phases() -> PackedFloat32Array:
	return pass_phases_at(float(Time.get_ticks_msec() - _started_ms) / 1000.0,
			ArtVariables.UNIT_CALL_TO_ACTION_SECONDS, ArtVariables.UNIT_CALL_TO_ACTION_PASSES,
			ArtVariables.UNIT_CALL_TO_ACTION_STAGGER, ArtVariables.UNIT_CALL_TO_ACTION_REST_SECONDS)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not Settings.ui_motion_enabled:
		_draw_ring(0, GameColors.CALL_TO_ACTION_BRIGHT)
		return
	for phase: float in current_phases():
		var color: Color = GameColors.CALL_TO_ACTION_BRIGHT
		color.a = lerpf(0.2, 0.9, phase)
		_draw_ring(InteractiveButton.cta_ring_inset_at(phase), color)


func _draw_ring(inset: int, color: Color) -> void:
	for pixel: Vector2 in _rings[inset]:
		draw_rect(Rect2(_origin + pixel, Vector2.ONE), color)
