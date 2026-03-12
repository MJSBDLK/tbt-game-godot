## Camera controller with keyboard panning, mouse scroll zoom, and middle-mouse drag.
## Attached to the Camera2D node in the battle scene.
## Player-driven panning: exponential decay lerp (responsive).
## Programmatic center_on(): Tween with EASE_IN_OUT (cinematic).
class_name CameraController
extends Camera2D


@export_group("Pan")
@export var pan_speed: float = 120.0
@export var pan_smooth_time: float = 0.1
@export var pan_tween_duration: float = 0.35
@export var enable_edge_panning: bool = false
@export var edge_pan_border: float = 20.0

@export_group("Zoom")
@export var zoom_step: float = 0.25
@export var min_zoom: float = 1.0
@export var max_zoom: float = 4.0
@export var zoom_smooth_time: float = 0.1

@export_group("Bounds")
@export var constrain_to_bounds: bool = true
@export var bounds_buffer_left: float = 32.0
@export var bounds_buffer_right: float = 32.0
@export var bounds_buffer_top: float = 32.0
@export var bounds_buffer_bottom: float = 0.0

var _target_position: Vector2 = Vector2.ZERO
var _target_zoom: float = 2.0
var _is_dragging: bool = false
var _drag_start_position: Vector2 = Vector2.ZERO
var _min_bounds: Vector2 = Vector2.ZERO
var _max_bounds: Vector2 = Vector2(640, 360)
var _pan_tween: Tween = null


func _ready() -> void:
	_target_position = global_position
	_target_zoom = zoom.x
	if GridManager.is_grid_ready():
		_set_bounds_from_grid()
	else:
		GridManager.grid_ready.connect(_set_bounds_from_grid)


func _process(delta: float) -> void:
	if not _is_input_blocked():
		_handle_keyboard_pan(delta)
		if enable_edge_panning:
			_handle_edge_pan(delta)

	_apply_smooth_movement(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _is_input_blocked():
		return

	# Zoom
	if event.is_action_pressed("zoom_in"):
		_target_zoom = clampf(_target_zoom + zoom_step, min_zoom, max_zoom)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("zoom_out"):
		_target_zoom = clampf(_target_zoom - zoom_step, min_zoom, max_zoom)
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
	var origin_x := GridManager.grid_offset_x * grid_tile_size
	var origin_y := GridManager.grid_offset_y * grid_tile_size
	_min_bounds = Vector2(origin_x - bounds_buffer_left, origin_y - bounds_buffer_top)
	_max_bounds = Vector2(
		origin_x + GridManager.grid_width * grid_tile_size + bounds_buffer_right,
		origin_y + GridManager.grid_height * grid_tile_size + bounds_buffer_bottom)
	_target_position = (_min_bounds + _max_bounds) / 2.0
	global_position = _target_position


func _is_input_blocked() -> bool:
	var state_manager: Node = get_node_or_null("/root/GameStateManager")
	if state_manager == null:
		return false
	var state: Enums.InputState = state_manager.current_state
	return state == Enums.InputState.ACTION_MENU_OPEN or \
		state == Enums.InputState.DIALOGUE or \
		state == Enums.InputState.PAUSED


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
