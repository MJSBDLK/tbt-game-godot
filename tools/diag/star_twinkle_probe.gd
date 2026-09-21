## Frame dump for shaders/star_twinkle.gdshader. Needs a real display (the
## headless renderer draws nothing). From the project root:
##   DISPLAY=:1 godot-4 --path . --resolution 1280x720 -s tools/diag/star_twinkle_probe.gd
## Freezes the shader clock (time_scale 0), pins the cadence range to 8 s / 2 s
## with no jitter, and steps time_offset through 8 s at 12 ticks/s, so the 96
## frames loop for every star the demo paints. Renders on a TRANSPARENT
## viewport once per star KIND so a preview can layer them independently.
## Writes to res://_twinkle_out/:
##   frames_x.png / _plus.png / _alt.png / _blink.png
##                     12×8 grids of 1:1 frames (320×180 each, row-major),
##                     only that kind's stars
##   anatomy.png       flipbook of the full map: one row per anatomy-strip
##                     star, one column per frame, the 7×7 footprint at 6×
extends SceneTree

const SCALE := 4
const FRAME_RATE := 12.0
const CAPTURE_SECONDS := 8.0
const FRAME_COUNT := int(CAPTURE_SECONDS * FRAME_RATE)
const GRID_COLUMNS := 12
## Star kinds by which of R/G are painted: [has_red, has_green, file token].
const KINDS: Array = [[true, false, "x"], [false, true, "plus"], [true, true, "alt"], [false, false, "blink"]]
const OUT_DIR := "res://_twinkle_out"
const FOOT := 7
const FLIP_SCALE := 6

var _sky: TextureRect = null
var _material: ShaderMaterial = null


func _initialize() -> void:
	_run()


func _run() -> void:
	var demo_script: GDScript = load("res://scenes/debug/star_twinkle_demo.gd")
	var map_size: Vector2i = demo_script.MAP_SIZE
	var root := get_root()
	root.transparent_bg = true

	_material = demo_script.make_material()
	_material.set_shader_parameter("time_scale", 0.0)
	_material.set_shader_parameter("frame_rate", FRAME_RATE)
	_material.set_shader_parameter("period_slow_seconds", CAPTURE_SECONDS)
	_material.set_shader_parameter("period_fast_seconds", CAPTURE_SECONDS / 4.0)
	_material.set_shader_parameter("period_jitter", 0.0)
	_sky = TextureRect.new()
	_sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sky.material = _material
	_sky.scale = Vector2(SCALE, SCALE)
	root.add_child(_sky)

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var full_map: Image = demo_script.make_star_map(1)
	var all_frames: Array[Image] = await _capture(full_map, map_size)
	_save_anatomy(all_frames, demo_script.anatomy_positions())
	for kind in KINDS:
		var frames: Array[Image] = await _capture(_only_kind(full_map, kind[0], kind[1]), map_size)
		_save_grid(frames, map_size, "frames_%s.png" % kind[2])
	print("wrote %d frames × %d kinds to %s" % [FRAME_COUNT, KINDS.size(), OUT_DIR])
	quit()


func _capture(star_map: Image, map_size: Vector2i) -> Array[Image]:
	_sky.texture = ImageTexture.create_from_image(star_map)
	var frames: Array[Image] = []
	for k in FRAME_COUNT:
		_material.set_shader_parameter("time_offset", float(k) / FRAME_RATE)
		await process_frame
		await process_frame
		var shot: Image = get_root().get_texture().get_image()
		shot = shot.get_region(Rect2i(Vector2i.ZERO, map_size * SCALE))
		shot.convert(Image.FORMAT_RGBA8)
		shot.resize(map_size.x, map_size.y, Image.INTERPOLATE_NEAREST)
		frames.append(shot)
	return frames


## The map keeping only stars whose painted R/G presence matches.
func _only_kind(star_map: Image, has_red: bool, has_green: bool) -> Image:
	var out := Image.create(star_map.get_width(), star_map.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for y in star_map.get_height():
		for x in star_map.get_width():
			var color := star_map.get_pixel(x, y)
			if color.a > 0.5 and (color.r > 0.0) == has_red and (color.g > 0.0) == has_green:
				out.set_pixel(x, y, color)
	return out


func _save_grid(frames: Array[Image], map_size: Vector2i, file_name: String) -> void:
	var columns := GRID_COLUMNS
	var rows := ceili(float(frames.size()) / columns)
	var grid := Image.create(map_size.x * columns, map_size.y * rows, false, Image.FORMAT_RGBA8)
	for k in frames.size():
		var at := Vector2i((k % columns) * map_size.x, (k / columns) * map_size.y)
		grid.blit_rect(frames[k], Rect2i(Vector2i.ZERO, map_size), at)
	grid.save_png("%s/%s" % [OUT_DIR, file_name])


func _save_anatomy(frames: Array[Image], stars: Array[Vector2i]) -> void:
	var cell := FOOT + 1
	var sheet := Image.create(frames.size() * cell, stars.size() * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(40, 40, 48))
	for row in stars.size():
		var origin := stars[row] - Vector2i(FOOT / 2, FOOT / 2)
		for k in frames.size():
			sheet.blend_rect(frames[k], Rect2i(origin, Vector2i(FOOT, FOOT)), Vector2i(k * cell, row * cell))
	sheet.resize(sheet.get_width() * FLIP_SCALE, sheet.get_height() * FLIP_SCALE, Image.INTERPOLATE_NEAREST)
	sheet.save_png("%s/anatomy.png" % OUT_DIR)
