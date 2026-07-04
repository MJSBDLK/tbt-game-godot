## Ambient void-lock effect, played over a target rect (a chip/panel stylebox).
## Three continuously re-randomised emitters reproduce Lawrence's mockup — jagged,
## aliased, "violent chemical reaction" energy — without looking like a canned loop:
##   * smoke   — PROGRAMMATIC pixel streams (not baked sprites, which cut off mid-
##     plume when their animation ended). Jets originate at spaced border points and
##     spit single reference-pixels along random trajectories inside an angular cone;
##     each pixel flies until a randomised despawn distance. When a jet's emit window
##     ends it stops spawning but its live pixels finish their travel (no early
##     dissipation). Reproduces how Lawrence hand-animated the wisps.
##   * bubbles — `void bubble 1–6` drift in at random interior spots at ~mockup rate.
##   * stars   — a sweep of Lawrence's BAKED bursts, not a drawn line. At each stop a
##     jagged `void star lines` burst erupts, then ~3 frames later a `void star`
##     pops there; stops march across the band. Count, spacing, drift, timing,
##     variants and h-flip are re-rolled every sweep, so the chain never repeats.
##
## Usage: add as a child of the target Control, then `play(rect)` with the rect in
## that Control's local space. `stop()` halts emission; active pixels/sprites finish.
class_name VoidLockEffect
extends Node2D

# --- Smoke jet tuning (RQD's spec; degrees measured clockwise from straight up) ---
@export var smoke_left_bound_deg: float = 15.0
@export var smoke_right_bound_deg: float = 45.0
@export var smoke_spawn_rate: float = 12.0      # pixels/sec per jet (lower = sparser)
@export var smoke_despawn_inner: float = 6.0    # nearest a pixel may vanish (px from origin)
@export var smoke_despawn_outer: float = 14.0   # farthest a pixel may travel
@export var smoke_speed_min: float = 14.0       # px/sec
@export var smoke_speed_max: float = 26.0
@export var smoke_jet_duration_min: float = 0.9 # how long a jet keeps emitting (sec)
@export var smoke_jet_duration_max: float = 1.2
@export var smoke_color: Color = Color("d2ce6a")   # Lawrence's exact fizzle pixel color

const SMOKE_JETS := 7                # concurrent emitting jets
const SMOKE_JET_MIN_DIST := 14.0     # spacing between live jet origins

const BUBBLE_INTERVAL := 0.22
# Star sweep: a jagged line-burst erupts at each stop, then STAR_LINE_LEAD later
# (~3 frames) a star pops at the same spot; stops are STAR_STEP apart.
const STAR_STEP := 0.30
const STAR_LINE_LEAD := 0.28
# Idle between star sweeps — this is the void-star spawn cadence. Higher = stars
# appear less often. (min/max so the gap varies and doesn't feel metronomic.)
@export var star_sweep_gap_min: float = 0.45
@export var star_sweep_gap_max: float = 0.95

var _size: Vector2 = Vector2(100, 14)
var _running: bool = false

var _jets: Array[Dictionary] = []        # {origin, emit_left, accum}
var _smoke: Array[Dictionary] = []       # {pos, vel, origin, despawn}

var _bubble_accum: float = 0.0

# Star sweep — a time-scheduled list of baked-sprite spawns.
var _sweep_active: bool = false
var _sweep_gap: float = 0.4
var _sweep_clock: float = 0.0
var _sweep_end: float = 0.0
var _events: Array[Dictionary] = []   # {t, tag, pos, flip, fired}


func play(rect: Rect2) -> void:
	position = rect.position
	_size = rect.size
	_running = true
	set_process(true)


func stop() -> void:
	_running = false


func _process(delta: float) -> void:
	if _running:
		_tick_bubbles(delta)
	_tick_smoke(delta)   # jets/pixels keep going after stop() until they finish
	_tick_stars(delta)   # finish an in-flight sweep even after stop()


# =============================================================================
# SMOKE — programmatic pixel jets from the border
# =============================================================================

func _tick_smoke(delta: float) -> void:
	# Refill jets to the cap (only while running — stopping lets existing ones die).
	while _running and _jets.size() < SMOKE_JETS:
		var origin := _pick_jet_origin()
		if origin.x == INF:
			break
		_jets.append({
			"origin": origin,
			"emit_left": randf_range(smoke_jet_duration_min, smoke_jet_duration_max),
			"accum": 0.0,
		})

	# Emit from live jets; a jet whose window closed is dropped (its pixels live on).
	var live_jets: Array[Dictionary] = []
	for jet: Dictionary in _jets:
		jet["emit_left"] -= delta
		if jet["emit_left"] <= 0.0:
			continue
		var interval := 1.0 / maxf(0.5, smoke_spawn_rate)
		jet["accum"] += delta
		while jet["accum"] >= interval:
			jet["accum"] -= interval
			_emit_smoke_pixel(jet["origin"])
		live_jets.append(jet)
	_jets = live_jets

	# Advance pixels; each vanishes only once it reaches its own despawn distance.
	var live: Array[Dictionary] = []
	for p: Dictionary in _smoke:
		p["pos"] += p["vel"] * delta
		if p["origin"].distance_to(p["pos"]) < p["despawn"]:
			live.append(p)
	_smoke = live

	queue_redraw()


func _emit_smoke_pixel(origin: Vector2) -> void:
	var theta := deg_to_rad(randf_range(smoke_left_bound_deg, smoke_right_bound_deg))
	var dir := Vector2(sin(theta), -cos(theta))   # 0°=up, +→right
	_smoke.append({
		"pos": origin,
		"vel": dir * randf_range(smoke_speed_min, smoke_speed_max),
		"origin": origin,
		"despawn": randf_range(smoke_despawn_inner, smoke_despawn_outer),
	})


func _pick_jet_origin() -> Vector2:
	for _attempt: int in range(12):
		var pt := _random_perimeter_point()
		var ok := true
		for jet: Dictionary in _jets:
			if pt.distance_to(jet["origin"]) < SMOKE_JET_MIN_DIST:
				ok = false
				break
		if ok:
			return pt
	return Vector2(INF, INF)


func _draw() -> void:
	# One reference pixel each, snapped to the pixel it's "most in" (round) so the
	# stream doesn't shimmer between pixels — same idea as the parallax overlay.
	for p: Dictionary in _smoke:
		draw_rect(Rect2((p["pos"] as Vector2).round(), Vector2.ONE), smoke_color)


func _random_perimeter_point() -> Vector2:
	var w := _size.x
	var h := _size.y
	var d := randf() * 2.0 * (w + h)
	if d < w:
		return Vector2(d, 0.0)
	d -= w
	if d < h:
		return Vector2(w, d)
	d -= h
	if d < w:
		return Vector2(w - d, h)
	return Vector2(0.0, h - (d - w))


# =============================================================================
# BUBBLES — random interior, mockup rate
# =============================================================================

func _tick_bubbles(delta: float) -> void:
	_bubble_accum += delta
	if _bubble_accum < BUBBLE_INTERVAL:
		return
	_bubble_accum = 0.0
	var pt := Vector2(randf() * _size.x, randf_range(_size.y * 0.15, _size.y * 0.95))
	_spawn("void bubble %d" % randi_range(1, 6), pt, Vector2(0.5, 0.5))


# =============================================================================
# STARS — a re-rolled sweep of baked jagged bursts
# =============================================================================

func _tick_stars(delta: float) -> void:
	if not _sweep_active:
		if not _running:
			return
		_sweep_gap -= delta
		if _sweep_gap <= 0.0:
			_start_sweep()
		return

	_sweep_clock += delta
	for e: Dictionary in _events:
		if not e["fired"] and _sweep_clock >= e["t"]:
			e["fired"] = true
			var spr := _spawn(e["tag"], e["pos"], Vector2(0.5, 0.5))
			if spr != null:
				spr.flip_h = e["flip"]
	if _sweep_clock >= _sweep_end:
		_sweep_active = false
		_sweep_gap = randf_range(star_sweep_gap_min, star_sweep_gap_max)


func _start_sweep() -> void:
	_sweep_active = true
	_sweep_clock = 0.0
	_events.clear()

	var count := randi_range(3, 6)
	var left_to_right := randf() < 0.65
	var margin: float = clampf(_size.x * 0.08, 2.0, 8.0)
	var start_x := margin if left_to_right else _size.x - margin
	var end_x := _size.x - margin if left_to_right else margin
	var band := _size.y * randf_range(0.4, 0.6)

	var prev := Vector2.ZERO
	for k: int in range(count):
		var frac: float = (k + 0.5) / count
		var pos := Vector2(lerpf(start_x, end_x, frac) + randf_range(-3.0, 3.0),
				band + randf_range(-2.0, 2.0))
		# The jagged line-burst leads from the previous stop toward this one.
		var line_pos: Vector2 = pos if k == 0 else prev.lerp(pos, 0.5)
		var t0: float = k * STAR_STEP
		_events.append({ "t": t0, "tag": "void star lines", "pos": line_pos,
				"flip": randf() < 0.5, "fired": false })
		_events.append({ "t": t0 + STAR_LINE_LEAD, "tag": "void star %d" % randi_range(1, 4),
				"pos": pos, "flip": randf() < 0.5, "fired": false })
		prev = pos
	_sweep_end = (count - 1) * STAR_STEP + STAR_LINE_LEAD + 0.4


# =============================================================================
# SPAWN HELPER
# =============================================================================

## One-shot AnimatedSprite2D for `tag`, aligning the given anchor point of its
## content box (in [0,1]; (0,1)=bottom-left, (0.5,0.5)=centre) to local `pos`.
func _spawn(tag: String, pos: Vector2, anchor: Vector2) -> AnimatedSprite2D:
	var sf := VoidLockFxLibrary.frames(tag)
	if sf == null:
		return null
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bb := VoidLockFxLibrary.content_bbox(tag)
	spr.position = pos - (Vector2(bb.position) + Vector2(bb.size) * anchor)
	add_child(spr)
	spr.play("default")
	spr.animation_finished.connect(spr.queue_free)
	return spr
