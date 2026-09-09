## Camera controller with keyboard panning, mouse scroll zoom, and middle-mouse drag.
## Attached to the Camera2D node in the battle scene.
## Player-driven panning: exponential decay lerp (responsive).
## Programmatic center_on(): Tween with EASE_IN_OUT (cinematic).
##
## Under the dual-pipeline rendering architecture (see `.claude/zoom-arch.md`),
## the camera renders directly to the root viewport at native window resolution.
## `Camera2D.zoom` therefore represents **screen pixels per world pixel**:
##   zoom = 1 → 1 sp per wp (maximum clean zoom-out — visible area equals the
##              full window in world units)
##   zoom = window_integer_scale → "reference view" (visible area = 640×360
##              world units, matching the design canvas)
##   zoom = N → zoomed in N×, sprite pixels rendered at N screen pixels each
##
## All zoom values render with NEAREST filter and stay pixel-perfect when they
## land on integer screen-pixel-per-world-pixel ratios. Smooth mode (float zoom)
## allows fractional values with mild shimmer; Integer mode snaps cleanly.
class_name CameraController
extends Camera2D


@export_group("Pan")
## Keyboard / edge pan, in SCREEN px/s (the pan divides by zoom, so the
## on-screen speed is the same at every zoom level). 120 read as far too slow
## on F5 — RQD 2026-09-09: "speed up 3-5x"; 4x is the mid-point of the ask.
@export var pan_speed: float = 480.0
@export var pan_smooth_time: float = 0.1
@export var pan_tween_duration: float = 0.35
@export var enable_edge_panning: bool = false
@export var edge_pan_border: float = 20.0

@export_group("Zoom")
## Smooth-mode zoom: each scroll notch scales zoom by (1 + zoom_step), so a
## notch changes the view by the same PROPORTION at any depth. Additive 0.25
## steps felt dead when zoomed in and made smooth mode ~4x less sensitive than
## integer mode's whole-level steps — jarring when switching modes.
@export var zoom_step: float = 0.25
## Minimum camera zoom = screen pixels per world pixel. 1.0 means 1 world pixel
## = 1 screen pixel = pixel-perfect maximum zoom-out. Going lower would render
## world pixels at sub-screen-pixel size (shimmer/wagon-wheel).
@export var min_zoom: float = 1.0
## Maximum zoom-in. At zoom = 8 on a 1080p monitor, the visible area is
## 240×135 world units (~7×4 tiles) — close inspection zoom.
@export var max_zoom: float = 8.0
@export var zoom_smooth_time: float = 0.1
## When true, zoom snaps to integer levels (1x, 2x, 3x, 4x) instead of smooth 0.25 steps.
var integer_zoom_mode: bool = false:
	set(value):
		integer_zoom_mode = value
		if value:
			_target_zoom = roundf(clampf(_target_zoom, min_zoom, max_zoom))

@export_group("Bounds")
@export var constrain_to_bounds: bool = true
## Extra pixels the viewport is allowed to show past each map edge (1 tile = 32px).
@export var bounds_buffer_left: float = 32.0
@export var bounds_buffer_right: float = 32.0
@export var bounds_buffer_top: float = 64.0  # Extra space above map so tall unit HP bars + status icons on top row are pannable into view
@export var bounds_buffer_bottom: float = 0.0

var _target_position: Vector2 = Vector2.ZERO
var _target_zoom: float = 1.0  # Overwritten in _ready() with the window's integer scale.
var _is_dragging: bool = false
var is_panning: bool = false
var _drag_start_position: Vector2 = Vector2.ZERO
var _min_bounds: Vector2 = Vector2.ZERO
var _max_bounds: Vector2 = Vector2(640, 360)
var _pan_tween: Tween = null

# Screenshake state
var _shake_intensity: float = 0.0
var _shake_decay: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO

## The world position the camera is heading toward (set before tween starts).
## Use this instead of global_position when the camera may still be mid-pan.
var target_position: Vector2:
	get: return _target_position

# Map pixel-space rect — set once from grid, used to recompute bounds on zoom change.
var _map_pixel_origin: Vector2 = Vector2.ZERO
var _map_pixel_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	_target_position = global_position
	# Default zoom = window's integer scale. At this zoom the visible world area
	# equals the 640×360 reference resolution — what the design canvas assumes.
	_target_zoom = _default_zoom_for_window()
	zoom = Vector2(_target_zoom, _target_zoom)
	# Honor the player's persisted Zoom Mode preference (Options menu). The
	# setter snaps _target_zoom to an integer when enabled — the default zoom is
	# already integer, so this is a no-op there, but it keeps the invariant.
	integer_zoom_mode = Settings.integer_zoom_mode
	if GridManager.is_grid_ready():
		_set_bounds_from_grid()
	else:
		GridManager.grid_ready.connect(_set_bounds_from_grid)


func _default_zoom_for_window() -> float:
	var w: Vector2i = DisplayServer.window_get_size()
	return float(maxi(1, mini(w.x / 640, w.y / 360)))


func _process(delta: float) -> void:
	if not _is_input_blocked():
		_handle_keyboard_pan(delta)
		if enable_edge_panning:
			_handle_edge_pan(delta)

	_apply_smooth_movement(delta)
	_apply_screenshake(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _is_input_blocked():
		return

	# Zoom
	if event.is_action_pressed("zoom_in"):
		_step_zoom(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("zoom_out"):
		_step_zoom(-1)
		get_viewport().set_input_as_handled()

	# Middle-mouse drag
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse_event.pressed:
				_is_dragging = true
				_drag_start_position = get_global_mouse_position()
				_cancel_tween()
			else:
				_is_dragging = false
	elif event is InputEventMouseMotion and _is_dragging:
		var current_mouse := get_global_mouse_position()
		_target_position -= (current_mouse - _drag_start_position)
		_drag_start_position = get_global_mouse_position()


## One scroll notch of zoom in `direction` (+1 in, -1 out). Integer mode steps
## whole pixel-scale levels (1x → 2x → 3x). Smooth mode is MULTIPLICATIVE —
## zoom scales by (1 + zoom_step) per notch — so the per-notch visual change is
## proportional everywhere and lands close to integer mode's step size around
## the default zoom (3x on 1080p), keeping the two modes' scroll sensitivity
## comparable when the player flips Zoom Mode.
func _step_zoom(direction: int) -> void:
	if integer_zoom_mode:
		_target_zoom = roundf(clampf(_target_zoom + float(direction), min_zoom, max_zoom))
		return
	var factor: float = (1.0 + zoom_step) if direction > 0 else 1.0 / (1.0 + zoom_step)
	_target_zoom = clampf(_target_zoom * factor, min_zoom, max_zoom)


func _handle_keyboard_pan(delta: float) -> void:
	var pan_input := Vector2.ZERO
	if Input.is_action_pressed("camera_pan_left"):
		pan_input.x -= 1.0
	if Input.is_action_pressed("camera_pan_right"):
		pan_input.x += 1.0
	if Input.is_action_pressed("camera_pan_up"):
		pan_input.y -= 1.0
	if Input.is_action_pressed("camera_pan_down"):
		pan_input.y += 1.0
	is_panning = pan_input.length() > 0 or _is_dragging

	if pan_input.length() > 0:
		pan_input = pan_input.normalized()
		_cancel_tween()
		_target_position += pan_input * pan_speed * delta / zoom.x


func _handle_edge_pan(delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	var mouse_position := get_viewport().get_mouse_position()
	var pan_input := Vector2.ZERO

	if mouse_position.x < edge_pan_border:
		pan_input.x -= 1.0
	elif mouse_position.x > viewport_size.x - edge_pan_border:
		pan_input.x += 1.0
	if mouse_position.y < edge_pan_border:
		pan_input.y -= 1.0
	elif mouse_position.y > viewport_size.y - edge_pan_border:
		pan_input.y += 1.0

	if pan_input.length() > 0:
		_cancel_tween()
		_target_position += pan_input.normalized() * pan_speed * delta / zoom.x


func _apply_smooth_movement(delta: float) -> void:
	# Zoom always updates
	var zoom_factor := 1.0 - exp(-10.0 * delta / maxf(zoom_smooth_time, 0.001))
	var new_zoom := lerpf(zoom.x, _target_zoom, zoom_factor)
	zoom = Vector2(new_zoom, new_zoom)

	# Recompute bounds for the updated zoom level
	if _map_pixel_size != Vector2.ZERO:
		_update_bounds_for_zoom()

	# Position: tween owns it while running; lerp handles player-driven pan otherwise
	if _pan_tween != null and _pan_tween.is_running():
		return

	if constrain_to_bounds:
		_target_position.x = clampf(_target_position.x, _min_bounds.x, _max_bounds.x)
		_target_position.y = clampf(_target_position.y, _min_bounds.y, _max_bounds.y)

	var smooth_factor := 1.0 - exp(-10.0 * delta / maxf(pan_smooth_time, 0.001))
	global_position = global_position.lerp(_target_position, smooth_factor)


func _set_bounds_from_grid() -> void:
	var grid_tile_size := GridManager.tile_size
	# origin_x: left pixel edge of the grid (grid_offset_x = min tilemap X)
	var origin_x := GridManager.grid_offset_x * grid_tile_size
	# origin_y: top pixel edge of the grid.
	# grid_offset_y stores -max_tilemap_y (game-grid Y of the bottom row, Y-up).
	# min_tilemap_y = -grid_offset_y - grid_height + 1
	var min_tilemap_y := -GridManager.grid_offset_y - GridManager.grid_height + 1
	var origin_y := min_tilemap_y * grid_tile_size
	_map_pixel_origin = Vector2(origin_x, origin_y)
	_map_pixel_size = Vector2(
		GridManager.grid_width * grid_tile_size,
		GridManager.grid_height * grid_tile_size)
	_update_bounds_for_zoom()
	_target_position = (_min_bounds + _max_bounds) / 2.0
	global_position = _target_position


## Recomputes _min_bounds/_max_bounds so the viewport edge never exceeds the map
## boundary by more than the configured buffer. Called on grid ready and on zoom change.
func _update_bounds_for_zoom() -> void:
	var viewport_size := get_viewport_rect().size
	var half_view := viewport_size / (2.0 * zoom.x)
	var map_center := _map_pixel_origin + _map_pixel_size / 2.0

	# Camera must be far enough from the map edge that the viewport edge stays within
	# the map (plus the optional per-edge buffer).
	var min_x := _map_pixel_origin.x + half_view.x - bounds_buffer_left
	var max_x := _map_pixel_origin.x + _map_pixel_size.x - half_view.x + bounds_buffer_right
	var min_y := _map_pixel_origin.y + half_view.y - bounds_buffer_top
	var max_y := _map_pixel_origin.y + _map_pixel_size.y - half_view.y + bounds_buffer_bottom

	# If the map is narrower than the viewport on an axis, lock to map center.
	if min_x > max_x:
		min_x = map_center.x
		max_x = map_center.x
	if min_y > max_y:
		min_y = map_center.y
		max_y = map_center.y

	_min_bounds = Vector2(min_x, min_y)
	_max_bounds = Vector2(max_x, max_y)


func _is_input_blocked() -> bool:
	var state_manager: Node = get_node_or_null("/root/GameStateManager")
	if state_manager == null:
		return false
	var state: Enums.InputState = state_manager.current_state
	return state == Enums.InputState.ACTION_MENU_OPEN or \
		state == Enums.InputState.UNIT_DETAIL or \
		state == Enums.InputState.DIALOGUE or \
		state == Enums.InputState.PAUSED or \
		state == Enums.InputState.LEVEL_UP_CELEBRATION


func _cancel_tween() -> void:
	if _pan_tween != null and _pan_tween.is_running():
		_pan_tween.kill()
		_target_position = global_position


func center_on(world_position: Vector2, smooth: bool = true) -> void:
	var clamped := world_position
	if constrain_to_bounds:
		clamped.x = clampf(clamped.x, _min_bounds.x, _max_bounds.x)
		clamped.y = clampf(clamped.y, _min_bounds.y, _max_bounds.y)
	_target_position = clamped
	if not smooth:
		_cancel_tween()
		global_position = clamped
		return
	if _pan_tween != null and _pan_tween.is_running():
		_pan_tween.kill()
	_pan_tween = create_tween()
	_pan_tween.set_trans(Tween.TRANS_SINE)
	_pan_tween.set_ease(Tween.EASE_IN_OUT)
	_pan_tween.tween_property(self, "global_position", clamped, pan_tween_duration)


func set_zoom_level(new_zoom: float, smooth: bool = true) -> void:
	_target_zoom = clampf(new_zoom, min_zoom, max_zoom)
	if not smooth:
		zoom = Vector2(_target_zoom, _target_zoom)


## Minimal-pan "keep the point on screen": if world_point sits within `margin`
## world px of the view edge (or beyond it), shift the camera target just far
## enough to bring it back inside — the exponential smoothing in
## _apply_smooth_movement turns that into a short glide, and the usual bounds
## clamp still applies. The board cursor calls this every step; it's a no-op
## while the point is comfortably visible, so a mid-screen cursor never drags
## the camera around.
func ensure_point_visible(world_point: Vector2, margin: float) -> void:
	var half_extent := get_viewport_rect().size / (2.0 * zoom.x)
	var shift := point_visibility_shift(_target_position, half_extent, world_point, margin)
	if shift == Vector2.ZERO:
		return
	_cancel_tween()
	_target_position += shift


## Pure math for ensure_point_visible (static for GUT): the minimal translation
## of a view centered at `center` with half-size `half_extent` so `point` ends
## at least `margin` inside every edge. Margin is capped at half the
## half-extent per axis so a deep zoom-in can't demand contradictory shifts.
static func point_visibility_shift(center: Vector2, half_extent: Vector2,
		point: Vector2, margin: float) -> Vector2:
	var inset := Vector2(
			minf(margin, half_extent.x * 0.5),
			minf(margin, half_extent.y * 0.5))
	var low := center - half_extent + inset
	var high := center + half_extent - inset
	var shift := Vector2.ZERO
	if point.x < low.x:
		shift.x = point.x - low.x
	elif point.x > high.x:
		shift.x = point.x - high.x
	if point.y < low.y:
		shift.y = point.y - low.y
	elif point.y > high.y:
		shift.y = point.y - high.y
	return shift


# =============================================================================
# SCREENSHAKE
# =============================================================================

const SHAKE_MAX_INTENSITY: float = 4.0  # Max pixel offset at impact_weight=1.0
const SHAKE_DECAY_RATE: float = 12.0  # How fast shake dies out (higher = faster)

## Trigger screenshake scaled by impact weight (0.0–1.0).
func screenshake(impact_weight: float) -> void:
	var intensity := impact_weight * SHAKE_MAX_INTENSITY
	# Don't weaken an ongoing stronger shake
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_decay = _shake_intensity


func _apply_screenshake(delta: float) -> void:
	if _shake_intensity <= 0.01:
		_shake_intensity = 0.0
		if _shake_offset != Vector2.ZERO:
			offset -= _shake_offset
			_shake_offset = Vector2.ZERO
		return

	_shake_intensity = lerpf(_shake_intensity, 0.0, SHAKE_DECAY_RATE * delta)

	# Remove previous offset, apply new random one
	offset -= _shake_offset
	_shake_offset = Vector2(
		randf_range(-_shake_intensity, _shake_intensity),
		randf_range(-_shake_intensity, _shake_intensity))
	offset += _shake_offset
