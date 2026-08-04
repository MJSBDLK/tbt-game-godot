## The shared intermission STAGE — locked identity (RQD 2026-08-03): the main
## menu and the between-mission screens are separate screens wearing the same
## backdrop + glass chrome, and the backdrop is SAVE-AWARE ("Black Mesa
## mode"). Resolution order (RQD 2026-08-03, round 8):
##   1. newest save's screenshot (captured by SaveManager at save time)
##   2. Lawrence's reference-res fullscreen art at SHIP_INTERIOR_PATH
##      (not painted yet — drops in with zero code changes)
##   3. flat glass — the dark-eggshell HUD panel color. No programmer-art
##      placeholder: an honest flat beats a crude scene.
## Dim + hint-strength vignette ride on top so free-floating menu text stays
## legible over any backdrop.
class_name MenuStageBackdrop
extends Control


const SHIP_INTERIOR_PATH: String = "res://art/backgrounds/ship_interior.png"

const DIM_COLOR: Color = Color(0.016, 0.02, 0.031, 0.35)
const VIGNETTE_STRENGTH: float = 0.58

var _backdrop: TextureRect = null
var _base: ColorRect = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# The absolute last fallback: opaque dark eggshell (the glass color the
	# whole HUD is built from). Visible only when no screenshot and no art.
	_base = ColorRect.new()
	_base.set_anchors_preset(Control.PRESET_FULL_RECT)
	_base.color = GameColors.with_alpha(GameColors.HUD_PANEL_BACKGROUND, 1.0)
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_base)

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


## Re-resolves what the stage shows per the resolution order in the header.
func refresh() -> void:
	var screenshot := _newest_save_screenshot()
	if screenshot != null:
		_backdrop.texture = screenshot
		return
	if ResourceLoader.exists(SHIP_INTERIOR_PATH):
		_backdrop.texture = load(SHIP_INTERIOR_PATH) as Texture2D
		return
	_backdrop.texture = null  # flat eggshell base shows through


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


