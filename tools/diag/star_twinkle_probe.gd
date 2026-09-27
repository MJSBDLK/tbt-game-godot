## Frame dump for shaders/star_twinkle.gdshader. Needs a real display (the
## headless renderer draws nothing). From the project root:
##   DISPLAY=:1 godot-4 --path . --resolution 1280x720 -s tools/diag/star_twinkle_probe.gd
## Freezes the shader clock (time_scale 0), pins the cadence range to 8 s / 2 s
## with no jitter, and steps time_offset through 8 s at 12 captures/s, so the 96
## captures loop for every star the demo paints. Each animation frame is pinned
## to 0.25 s, exactly 3 captures. Writes to res://_twinkle_out/:
##   frames.png    12×8 grid of 1:1 frames (320×180 each, row-major)
##   anatomy.png   flipbook: one row per anatomy-strip star, one column per
##                 frame, the 7×7 footprint at 6×
## Also asserts the tail rule on the #FF0000 anatomy star (exit 1 on FAIL):
## the tip pixel arrives dim, inner pixels are never dimmer than outer ones,
## and the innermost reaches full only at full extension. And asserts even
## frames on the same star: 1, 2, 3, 2, 1, every one exactly 3 captures long —
## then recaptures with both holds at one frame and expects 6, 3, 6, 3, 6.
## Captures are opaque over the demo's sky color on purpose: a transparent
## viewport comes back premultiplied, and blit_rect/blend_rect read that as
## straight alpha, which squares every tail's apparent brightness.
extends SceneTree

const SCALE := 4
const CAPTURE_RATE := 12.0
const STEP_SECONDS := 0.25
const CAPTURE_SECONDS := 8.0
const FRAME_COUNT := int(CAPTURE_SECONDS * CAPTURE_RATE)
const GRID_COLUMNS := 12
const OUT_DIR := "res://_twinkle_out"
const FOOT := 7
const FLIP_SCALE := 6


func _initialize() -> void:
	_run()


func _run() -> void:
	var demo_script: GDScript = load("res://scenes/debug/star_twinkle_demo.gd")
	var map_size: Vector2i = demo_script.MAP_SIZE
	var root := get_root()
	var bg := ColorRect.new()
	bg.color = demo_script.BACKGROUND
	bg.size = Vector2(map_size * SCALE)
	root.add_child(bg)

	# Loaded at runtime: naming StarSky here would compile it before the autoloads exist.
	var material: ShaderMaterial = load("res://scripts/ui/components/star_sky.gd").build_material()
	material.set_shader_parameter("time_scale", 0.0)
	material.set_shader_parameter("step_seconds", STEP_SECONDS)
	material.set_shader_parameter("hold_seconds", 0.0)
	material.set_shader_parameter("dim_hold_seconds", 0.0)
	material.set_shader_parameter("period_slow_seconds", CAPTURE_SECONDS)
	material.set_shader_parameter("period_fast_seconds", CAPTURE_SECONDS / 4.0)
	material.set_shader_parameter("period_jitter", 0.0)
	var sky := TextureRect.new()
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sky.texture = ImageTexture.create_from_image(demo_script.make_star_map(1))
	material.set_shader_parameter("star_map", sky.texture)
	sky.material = material
	sky.scale = Vector2(SCALE, SCALE)
	root.add_child(sky)

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var frames := await _capture(material, map_size)

	_save_grid(frames, map_size)
	_save_anatomy(frames, demo_script.anatomy_positions())
	print("wrote %d frames to %s" % [FRAME_COUNT, OUT_DIR])
	var anatomy_star: Vector2i = demo_script.anatomy_positions()[0]
	var rule_ok := _tail_rule_holds(frames, anatomy_star, demo_script.BACKGROUND.r)
	print("tail rule: %s" % ("PASS" if rule_ok else "FAIL"))
	var expected := roundi(STEP_SECONDS * CAPTURE_RATE)
	var even_ok := _frame_lengths_are(frames, anatomy_star, demo_script.BACKGROUND.r,
			[expected, expected, expected, expected, expected])
	print("even frames: %s" % ("PASS" if even_ok else "FAIL"))

	material.set_shader_parameter("hold_seconds", STEP_SECONDS)
	material.set_shader_parameter("dim_hold_seconds", STEP_SECONDS)
	var held := await _capture(material, map_size)
	var holds_ok := _frame_lengths_are(held, anatomy_star, demo_script.BACKGROUND.r,
			[2 * expected, expected, 2 * expected, expected, 2 * expected])
	print("holds: %s" % ("PASS" if holds_ok else "FAIL"))
	quit(0 if rule_ok and even_ok and holds_ok else 1)


## One capture per 1/CAPTURE_RATE s of shader time, across CAPTURE_SECONDS.
func _capture(material: ShaderMaterial, map_size: Vector2i) -> Array[Image]:
	var frames: Array[Image] = []
	for k in FRAME_COUNT:
		material.set_shader_parameter("time_offset", float(k) / CAPTURE_RATE)
		await process_frame
		await process_frame
		var shot: Image = get_root().get_texture().get_image()
		shot = shot.get_region(Rect2i(Vector2i.ZERO, map_size * SCALE))
		shot.convert(Image.FORMAT_RGBA8)
		shot.resize(map_size.x, map_size.y, Image.INTERPOLATE_NEAREST)
		frames.append(shot)
	return frames


## The X tail of `star` (painted #FF0000) read along one diagonal, frame by
## frame. Red channel stands in for alpha: the star color is one flat tone.
func _tail_rule_holds(frames: Array[Image], star: Vector2i, ground: float) -> bool:
	var lit_floor := ground + 0.05
	var seen_tip_first := false
	var seen_full := false
	var previous_lit := false
	for frame in frames:
		var core := frame.get_pixelv(star).r
		var k1 := frame.get_pixelv(star + Vector2i(1, 1)).r
		var k2 := frame.get_pixelv(star + Vector2i(2, 2)).r
		var k3 := frame.get_pixelv(star + Vector2i(3, 3)).r
		if k1 < k2 - 0.01 or k2 < k3 - 0.01:
			push_error("inner tail pixel dimmer than outer: %s" % [[k1, k2, k3]])
			return false
		var lit := k1 > lit_floor
		if lit and not previous_lit:
			seen_tip_first = k1 < core - 0.2
			if not seen_tip_first:
				push_error("first tail pixel arrived at %.2f of core %.2f, not dim" % [k1, core])
				return false
		if k3 > lit_floor and absf(k1 - core) < 0.05:
			seen_full = true
		previous_lit = lit
	if not seen_tip_first or not seen_full:
		push_error("never saw a full flash (tip-first %s, full %s)" % [seen_tip_first, seen_full])
	return seen_tip_first and seen_full


## The #FF0000 star's X reach per capture, read as a loop (the capture spans
## exactly one period), must run 1, 2, 3, 2, 1 with each frame lasting exactly
## `expected` captures — no frame lingering longer than its knobs say.
func _frame_lengths_are(frames: Array[Image], star: Vector2i, ground: float,
		expected: Array) -> bool:
	var lit_floor := ground + 0.05
	var reaches: Array[int] = []
	for frame in frames:
		var reach := 0
		while reach < 3 and frame.get_pixelv(star + Vector2i(reach + 1, reach + 1)).r > lit_floor:
			reach += 1
		reaches.append(reach)
	var start := reaches.find(0)
	if start < 0:
		push_error("the star never rested")
		return false
	var runs: Array[Vector2i] = []  # (reach, captures)
	for i in reaches.size():
		var reach: int = reaches[(start + i) % reaches.size()]
		if not runs.is_empty() and runs[-1].x == reach:
			runs[-1].y += 1
		else:
			runs.append(Vector2i(reach, 1))
	var tails := runs.filter(func(run: Vector2i) -> bool: return run.x > 0)
	var shape := tails.map(func(run: Vector2i) -> int: return run.x)
	var lengths := tails.map(func(run: Vector2i) -> int: return run.y)
	print("frames: reach %s, captures %s" % [shape, lengths])
	if shape != [1, 2, 3, 2, 1]:
		push_error("expected one flash of 1, 2, 3, 2, 1")
		return false
	if lengths != expected:
		push_error("frames lasted %s captures, not %s" % [lengths, expected])
		return false
	return true


func _save_grid(frames: Array[Image], map_size: Vector2i) -> void:
	var rows := ceili(float(frames.size()) / GRID_COLUMNS)
	var grid := Image.create(map_size.x * GRID_COLUMNS, map_size.y * rows, false, Image.FORMAT_RGBA8)
	for k in frames.size():
		var at := Vector2i((k % GRID_COLUMNS) * map_size.x, (k / GRID_COLUMNS) * map_size.y)
		grid.blit_rect(frames[k], Rect2i(Vector2i.ZERO, map_size), at)
	grid.save_png("%s/frames.png" % OUT_DIR)


func _save_anatomy(frames: Array[Image], stars: Array[Vector2i]) -> void:
	var cell := FOOT + 1
	var sheet := Image.create(frames.size() * cell, stars.size() * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(40, 40, 48))
	for row in stars.size():
		var origin := stars[row] - Vector2i(FOOT / 2, FOOT / 2)
		for k in frames.size():
			sheet.blit_rect(frames[k], Rect2i(origin, Vector2i(FOOT, FOOT)), Vector2i(k * cell, row * cell))
	sheet.resize(sheet.get_width() * FLIP_SCALE, sheet.get_height() * FLIP_SCALE, Image.INTERPOLATE_NEAREST)
	sheet.save_png("%s/anatomy.png" % OUT_DIR)
