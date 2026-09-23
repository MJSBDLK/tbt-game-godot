## Frame dump for shaders/star_twinkle.gdshader. Needs a real display (the
## headless renderer draws nothing). From the project root:
##   DISPLAY=:1 godot-4 --path . --resolution 1280x720 -s tools/diag/star_twinkle_probe.gd
## Freezes the shader clock (time_scale 0), pins the cadence range to 8 s / 2 s
## with no jitter, and steps time_offset through 8 s at 12 ticks/s, so the 96
## frames loop for every star the demo paints. Writes to res://_twinkle_out/:
##   frames.png    12×8 grid of 1:1 frames (320×180 each, row-major)
##   anatomy.png   flipbook: one row per anatomy-strip star, one column per
##                 frame, the 7×7 footprint at 6×
## Also asserts the tail rule on the #FF0000 anatomy star (exit 1 on FAIL):
## the tip pixel arrives dim, inner pixels are never dimmer than outer ones,
## and the innermost reaches full only at full extension.
## Captures are opaque over the demo's sky color on purpose: a transparent
## viewport comes back premultiplied, and blit_rect/blend_rect read that as
## straight alpha, which squares every tail's apparent brightness.
extends SceneTree

const SCALE := 4
const FRAME_RATE := 12.0
const CAPTURE_SECONDS := 8.0
const FRAME_COUNT := int(CAPTURE_SECONDS * FRAME_RATE)
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
	material.set_shader_parameter("frame_rate", FRAME_RATE)
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
	var frames: Array[Image] = []
	for k in FRAME_COUNT:
		material.set_shader_parameter("time_offset", float(k) / FRAME_RATE)
		await process_frame
		await process_frame
		var shot: Image = root.get_texture().get_image()
		shot = shot.get_region(Rect2i(Vector2i.ZERO, map_size * SCALE))
		shot.convert(Image.FORMAT_RGBA8)
		shot.resize(map_size.x, map_size.y, Image.INTERPOLATE_NEAREST)
		frames.append(shot)

	_save_grid(frames, map_size)
	_save_anatomy(frames, demo_script.anatomy_positions())
	print("wrote %d frames to %s" % [FRAME_COUNT, OUT_DIR])
	var rule_ok := _tail_rule_holds(frames, demo_script.anatomy_positions()[0], demo_script.BACKGROUND.r)
	print("tail rule: %s" % ("PASS" if rule_ok else "FAIL"))
	quit(0 if rule_ok else 1)


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
