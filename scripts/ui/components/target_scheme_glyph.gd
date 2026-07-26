## The 10x10 target-scheme glyph for move chips — the "scheme + digits" pick
## (RQD 2026-07-19, over the reach-strip runner-up kept in the mockup).
## Shape says WHAT it hits: crosshair = single target, plus-cluster = blast.
## Color says WHO: bone = hostile (the quiet default — most moves), teal =
## friendly (ally/self — the loud exception). The chip owns the color choice,
## including the disabled grey-down; this node only draws.
##
## Inside a chip, NEITHER the shadow NOR the ink is drawn here — both live in
## the chip's fill shader (shadow: Lawrence 2026-07-20, the occluded body
## pushed down its ramp to ~30% luminance; ink: RQD 2026-07-26, the light or
## dark cut of the faction family per SIDE of the usage boundary, because
## light bone died on light fills like Robo's Gray 8). Both split per pixel
## across the boundary, and only the chip shader knows where that boundary
## is. This node then only provides layout and the shared shape texture
## (`ink_in_chip_shader = true`); standalone it draws the tinted shape
## itself. The dark orthogonal-glow outline was tried 2026-07-19 and
## replaced by this ("restore the box shadow").
##
## When Lawrence authors real scheme art, swap the generated texture for
## sprites — the mask plumbing keeps working as long as the sprite has
## transparent padding.
class_name TargetSchemeGlyph
extends Control


const GLYPH_SIZE: int = 10
## Transparent padding around the cells in the shape texture — gives the
## shadow mask room for its 1px offset.
const PAD: int = 1
## Where the shadow falls relative to the shape (classic down-right).
const SHADOW_OFFSET: Vector2 = Vector2(1, 1)

## Shape textures are shared across every chip — white cells, tinted at
## draw time by glyph_color.
static var _shape_textures: Dictionary = {}

var glyph_color: Color = Color.WHITE:
	set(value):
		if glyph_color == value:
			return
		glyph_color = value
		queue_redraw()

## Plus-cluster footprint instead of the single-target crosshair.
var blast: bool = false:
	set(value):
		if blast == value:
			return
		blast = value
		queue_redraw()

## When the chip shader renders the ink (per-side contrast cuts), this node
## must not paint its single-color shape on top. Layout + mask only.
var ink_in_chip_shader: bool = false:
	set(value):
		if ink_in_chip_shader == value:
			return
		ink_in_chip_shader = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(GLYPH_SIZE, GLYPH_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if ink_in_chip_shader:
		return
	var texture := shape_texture(blast)
	# The quad extends PAD px past the control on every side — that's where
	# the outline paints. Siblings don't clip against this control.
	draw_texture_rect(texture, Rect2(Vector2(-PAD, -PAD), texture.get_size()),
			false, glyph_color)


## Public: MoveChipButton feeds this same texture to the chip shader as the
## shadow mask, so shape and shadow can never disagree.
static func shape_texture(blast_shape: bool) -> ImageTexture:
	if _shape_textures.has(blast_shape):
		return _shape_textures[blast_shape]
	var side: int = GLYPH_SIZE + PAD * 2
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for cell: Rect2i in _cells(blast_shape):
		image.fill_rect(Rect2i(cell.position + Vector2i(PAD, PAD), cell.size),
				Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	_shape_textures[blast_shape] = texture
	return texture


static func _cells(blast_shape: bool) -> Array[Rect2i]:
	var cells: Array[Rect2i] = []
	if blast_shape:
		# Center cell + four orthogonal cells: the classic AoE footprint.
		for cell: Vector2i in [Vector2i(4, 4), Vector2i(4, 1), Vector2i(4, 7),
				Vector2i(1, 4), Vector2i(7, 4)]:
			cells.append(Rect2i(cell, Vector2i(2, 2)))
	else:
		# Crosshair: center pip + four edge ticks.
		cells.append(Rect2i(4, 4, 2, 2))
		cells.append(Rect2i(4, 1, 2, 1))
		cells.append(Rect2i(4, 8, 2, 1))
		cells.append(Rect2i(1, 4, 1, 2))
		cells.append(Rect2i(8, 4, 1, 2))
	return cells
