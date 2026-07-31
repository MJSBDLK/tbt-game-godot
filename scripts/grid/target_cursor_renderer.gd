## The board-side "you are here": four corner ticks around one tile, worn by
## BOTH keyboard/controller board cursors — the free map cursor that roams the
## whole grid during the map-view states, and the constrained attack-target
## cursor (RQD 2026-07-31 — "still not seeing the brackets when picking which
## unit to attack"). One instance, one wearer at a time; InputManager hands the
## vocabulary over on state transitions. Speaks the §14 bracket vocabulary
## EXACTLY: same arm length, same 2-position snap at the same 1.25 Hz
## (constants and phase borrowed from InteractiveButton, so the board cursor
## and a menu cursor blink in lockstep), same hot-white ink. Reduce-motion
## parks the ticks in the inner position.
##
## Pointer users never see this — mouse hover already tints the hovered tile
## and the OS cursor is its own "you are here"; brackets follow the CURSOR
## model only, exactly like menus (brackets = focus, never hover).
class_name TargetCursorRenderer
extends Node2D


## Above the range tints (threat/preview decals sit at 1), below units (z 6+).
@export var cursor_z_index: int = 2

var _tile: Tile = null


func _ready() -> void:
	z_index = cursor_z_index


func set_tile(tile: Tile) -> void:
	_tile = tile
	queue_redraw()


func clear() -> void:
	_tile = null
	queue_redraw()


func target_tile() -> Tile:
	return _tile


func _process(_delta: float) -> void:
	# Redraw only while worn — the snap is wall-clock, not tween-driven.
	if _tile != null:
		queue_redraw()


func _draw() -> void:
	if _tile == null or not is_instance_valid(_tile):
		return
	var size: float = float(GridManager.tile_size)
	var half := Vector2(size, size) * 0.5
	var rect := Rect2(to_local(_tile.global_position) - half, Vector2(size, size))

	var motion: bool = Settings == null or Settings.ui_motion_enabled
	var out: bool = motion and InteractiveButton.brackets_out_at(
			Time.get_ticks_msec() / 1000.0)
	var inset: float = InteractiveButton.BRACKET_INSET_PIXELS + (1 if out else 0)
	var arm: float = InteractiveButton.BRACKET_ARM_PIXELS
	var color: Color = GameColors.INTERACTIVE_BRACKET

	# Four corner ticks, each an L of two 1px arms pointing inward.
	var tl := rect.position + Vector2(-inset, -inset)
	var tr := Vector2(rect.end.x + inset, rect.position.y - inset)
	var bl := Vector2(rect.position.x - inset, rect.end.y + inset)
	var br := rect.end + Vector2(inset, inset)
	_tick(tl, Vector2.RIGHT, Vector2.DOWN, arm, color)
	_tick(tr, Vector2.LEFT, Vector2.DOWN, arm, color)
	_tick(bl, Vector2.RIGHT, Vector2.UP, arm, color)
	_tick(br, Vector2.LEFT, Vector2.UP, arm, color)


func _tick(corner: Vector2, horizontal: Vector2, vertical: Vector2, arm: float, color: Color) -> void:
	# 1px-thick rects, not draw_line — lines land on half-pixels and blur.
	var h_origin := corner + (Vector2(-arm + 1, 0) if horizontal == Vector2.LEFT else Vector2.ZERO)
	draw_rect(Rect2(h_origin, Vector2(arm, 1)), color, true)
	var v_origin := corner + (Vector2(0, -arm + 1) if vertical == Vector2.UP else Vector2.ZERO)
	draw_rect(Rect2(v_origin, Vector2(1, arm)), color, true)
