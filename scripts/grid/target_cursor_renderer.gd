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
	var color: Color = GameColors.INTERACTIVE_BRACKET

	# Tick geometry comes from InteractiveButton.bracket_tick_rects — the ONE
	# source for §14 bracket shapes, so board and menu ink can never drift.
	# (A local reimplementation once painted 1px wide right/bottom — Rect2.end
	# is exclusive.) 1px-thick rects, not draw_line: lines land on half-pixels
	# and blur.
	for tick: Rect2 in InteractiveButton.bracket_tick_rects(
			rect, inset, InteractiveButton.BRACKET_ARM_PIXELS):
		draw_rect(tick, color, true)
