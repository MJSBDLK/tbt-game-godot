## The 10x10 target-scheme glyph for move chips — the "scheme + digits" pick
## (RQD 2026-07-19, over the reach-strip runner-up kept in the mockup).
## Shape says WHAT it hits: crosshair = single target, plus-cluster = blast.
## Color says WHO: bone = hostile (the quiet default — most moves), teal =
## friendly (ally/self — the loud exception). The chip owns the color choice,
## including the disabled grey-down; this node only draws.
##
## The outline is the game's own orthogonal_glow shader with a dark glow
## ("why not just use the orthogonal glow?" — RQD 2026-07-19): the shader
## paints around transparent texture edges, so the glyph renders from a
## generated texture with 1px of transparent padding rather than raw
## draw_rect primitives (quads with no transparent texels can't halo).
##
## When Lawrence authors real scheme art, swap the generated texture for
## sprites and keep the same slot + material.
class_name TargetSchemeGlyph
extends Control


const GLYPH_SIZE: int = 10
## Transparent padding around the cells — where the outline lives.
const PAD: int = 1
## Dark "glow" = the pixel-art outline. Alpha is shaped by the shader's
## global glow_alpha, same as every text halo.
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)
const GLOW_MATERIAL: ShaderMaterial = preload("res://resources/hud_glow.tres")

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


func _ready() -> void:
	custom_minimum_size = Vector2(GLYPH_SIZE, GLYPH_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = GLOW_MATERIAL.duplicate()
	(material as ShaderMaterial).set_shader_parameter("glow_color", OUTLINE_COLOR)


func _draw() -> void:
	var texture := _shape_texture(blast)
	# The quad extends PAD px past the control on every side — that's where
	# the outline paints. Siblings don't clip against this control.
	draw_texture_rect(texture, Rect2(Vector2(-PAD, -PAD), texture.get_size()),
			false, glyph_color)


static func _shape_texture(blast_shape: bool) -> ImageTexture:
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
