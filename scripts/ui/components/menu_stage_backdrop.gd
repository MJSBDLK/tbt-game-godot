## The shared intermission STAGE — locked identity (RQD 2026-08-03): the main
## menu and the between-mission screens are separate screens wearing the same
## backdrop + glass chrome, and the backdrop is SAVE-AWARE ("Black Mesa
## mode"): with save data, it shows the newest save's screenshot (captured by
## SaveManager at save time); on a fresh install it falls back to the ship
## interior. Dim + hint-strength vignette ride on top so free-floating menu
## text stays legible over any scene.
##
## Lawrence is painting the real 640×360 ship interior (more scenes per plot
## later) — drop it at SHIP_INTERIOR_PATH and the code-generated placeholder
## retires itself. Never block on the art: everything here degrades to flat
## dark.
class_name MenuStageBackdrop
extends Control


const SHIP_INTERIOR_PATH: String = "res://art/backgrounds/ship_interior.png"

const DIM_COLOR: Color = Color(0.016, 0.02, 0.031, 0.35)
const VIGNETTE_STRENGTH: float = 0.58

var _backdrop: TextureRect = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var base := ColorRect.new()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.color = Color(0.039, 0.043, 0.063)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = DIM_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var vignette := TextureRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.texture = _make_vignette_texture()
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	refresh()


## Re-resolves what the stage shows: newest save's screenshot if one exists
## on disk, else the ship interior (Lawrence's file, or the generated
## placeholder until it lands).
func refresh() -> void:
	var screenshot := _newest_save_screenshot()
	if screenshot != null:
		_backdrop.texture = screenshot
		return
	if ResourceLoader.exists(SHIP_INTERIOR_PATH):
		_backdrop.texture = load(SHIP_INTERIOR_PATH) as Texture2D
		return
	_backdrop.texture = _generate_placeholder_interior()


func _newest_save_screenshot() -> Texture2D:
	var saves: Array[Dictionary] = SaveManager.list_saves()
	if saves.is_empty():
		return null
	var shot_path: String = SaveManager.screenshot_path_for(str(saves[0].get("path", "")))
	if not FileAccess.file_exists(shot_path):
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(shot_path)
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)


## Hint-strength radial vignette — transparent center, dark edges. A texture
## because Godot has no radial-gradient ColorRect; 128px is plenty smooth
## once bilinear-stretched.
func _make_vignette_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.set_color(1, Color(0, 0, 0, VIGNETTE_STRENGTH))
	gradient.add_point(0.55, Color(0, 0, 0, 0.05))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.45)
	texture.fill_to = Vector2(0.5, 1.15)
	texture.width = 128
	texture.height = 128
	return texture


## Crude programmer-art ship interior (320×180, NEAREST-upscaled): back wall
## with seams, floor, a starfield viewport, two consoles. Deliberately
## blocky — it exists so the glass-over-scene layering can be judged before
## the real art lands, exactly like the HTML mockup's canvas stand-in.
func _generate_placeholder_interior() -> Texture2D:
	var image := Image.create(320, 180, false, Image.FORMAT_RGB8)
	image.fill(Color8(20, 23, 33))                                     # back wall
	for x: int in range(16, 320, 38):                                  # wall seams
		image.fill_rect(Rect2i(x, 0, 2, 128), Color8(15, 17, 24))
	image.fill_rect(Rect2i(0, 128, 320, 52), Color8(25, 28, 38))       # floor
	for y: int in range(134, 180, 9):
		image.fill_rect(Rect2i(0, y, 320, 1), Color8(18, 20, 28))
	image.fill_rect(Rect2i(0, 124, 320, 4), Color8(35, 39, 51))        # skirting

	image.fill_rect(Rect2i(84, 20, 158, 78), Color8(42, 47, 61))       # window frame
	image.fill_rect(Rect2i(88, 24, 150, 70), Color8(5, 6, 12))         # space
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234                                                    # stars don't reshuffle
	for _i: int in 60:
		var star_x: int = 88 + rng.randi_range(0, 149)
		var star_y: int = 24 + rng.randi_range(0, 69)
		var brightness: float = rng.randf_range(0.35, 1.0)
		image.set_pixel(star_x, star_y, Color(0.86, 0.95, 1.0) * brightness)
	image.fill_rect(Rect2i(160, 24, 3, 70), Color8(42, 47, 61))        # mullion

	for base_x: Array in [[10], [258]]:                                # consoles
		var bx: int = base_x[0]
		image.fill_rect(Rect2i(bx, 96, 52, 32), Color8(29, 32, 41))
		image.fill_rect(Rect2i(bx, 92, 52, 5), Color8(37, 42, 54))
		image.fill_rect(Rect2i(bx + 6, 102, 3, 2), Color8(76, 140, 187))
		image.fill_rect(Rect2i(bx + 14, 102, 3, 2), Color8(192, 68, 46))
		image.fill_rect(Rect2i(bx + 22, 102, 2, 2), Color8(231, 193, 75))
		image.fill_rect(Rect2i(bx + 4, 110, 44, 12), Color8(16, 18, 26))
	return ImageTexture.create_from_image(image)
