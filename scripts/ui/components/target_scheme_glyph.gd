## The 10x10 target-scheme glyph for move chips — the "scheme + digits" pick
## (RQD 2026-07-19, over the reach-strip runner-up kept in the mockup).
## Shape says WHAT it hits: crosshair = single target, plus-cluster = blast.
## Color says WHO: bone = hostile (the quiet default — most moves), teal =
## friendly (ally/self — the loud exception). The chip owns the color choice,
## including the disabled grey-down; this node only draws.
##
## Drawn at runtime on the pixel grid — no sprite exists for it yet. When
## Lawrence authors real scheme art, swap this for a TextureRect and keep the
## same slot in the chip row.
class_name TargetSchemeGlyph
extends Control


const GLYPH_SIZE: int = 10

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


const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const SHADOW_OFFSET: Vector2 = Vector2(1, 1)


func _draw() -> void:
	var cells: Array[Rect2] = []
	if blast:
		# Center cell + four orthogonal cells: the classic AoE footprint.
		for cell: Vector2 in [Vector2(4, 4), Vector2(4, 1), Vector2(4, 7),
				Vector2(1, 4), Vector2(7, 4)]:
			cells.append(Rect2(cell, Vector2(2, 2)))
	else:
		# Crosshair: center pip + four edge ticks.
		cells.append(Rect2(4, 4, 2, 2))
		cells.append(Rect2(4, 1, 2, 1))
		cells.append(Rect2(4, 8, 2, 1))
		cells.append(Rect2(1, 4, 1, 2))
		cells.append(Rect2(8, 4, 1, 2))
	# 1px drop shadow first: bone cells vanish on light bodies (Robo grey —
	# RQD 2026-07-19). Mockup parity — the SVG glyphs carry a drop-shadow.
	for cell: Rect2 in cells:
		draw_rect(Rect2(cell.position + SHADOW_OFFSET, cell.size), SHADOW_COLOR)
	for cell: Rect2 in cells:
		draw_rect(cell, glyph_color)
