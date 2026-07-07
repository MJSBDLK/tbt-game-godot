## Routes input events between the root viewport (world) and HUDViewport (HUD).
##
## The split-viewport architecture means events arrive at the root viewport and
## must be explicitly forwarded to HUDViewport for HUD Controls to receive them.
## The world (Camera2D + Node2D content under WorldRoot) lives in the root
## viewport directly, so world-targeted events need no forwarding — they're
## already where the world's input handlers live.
##
## Rules:
##   - All events are forwarded into HUDViewport with mouse coords remapped
##     from native window pixels to the HUDViewport's 640×360 space.
##   - If HUDViewport reports the event as handled (`is_input_handled()`),
##     this router consumes it at the root viewport so the world never sees it.
##   - Otherwise the event continues through the root viewport's normal input
##     cycle (Controls at root, then `_unhandled_input` for autoloads like
##     InputManager).
##
## See `.claude/zoom-arch.md` for the architecture rationale.
class_name InputRouter
extends Node


@onready var _hud_viewport: SubViewport = $"../HUDViewport"
@onready var _hud_display: TextureRect = $"../HUDLayer/HUDDisplay"
@onready var _tap_feedback: TapFeedbackLayer = $"../TapFeedbackLayer"


func _input(event: InputEvent) -> void:
	# Input-receipt pulse fires FIRST, before anything can consume the event —
	# it must appear whether or not the press hit something interactible.
	_pulse_tap_feedback(event)
	_forward_to_hud(event)
	# Mouse motion is broadcast (HUD wants hover state, world wants tile preview);
	# never consume at root for motion.
	if event is InputEventMouseMotion:
		return
	if _hud_viewport.is_input_handled():
		get_viewport().set_input_as_handled()


## The "your tap registered" ring (TapFeedbackLayer). Presses only — releases,
## motion, and the scroll wheel don't pulse. Touch taps also deliver an
## EMULATED mouse press (device == DEVICE_ID_EMULATION); the touch branch owns
## those, so the mouse branch skips them to avoid a double pulse.
func _pulse_tap_feedback(event: InputEvent) -> void:
	if _tap_feedback == null:
		return
	if event is InputEventMouseButton and event.pressed and not event.is_echo() \
			and event.device != InputEvent.DEVICE_ID_EMULATION \
			and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		_tap_feedback.pulse_at(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_tap_feedback.pulse_at(event.position)


func _forward_to_hud(event: InputEvent) -> void:
	var remapped: InputEvent = event
	if event is InputEventMouse:
		# Remap from root-viewport pixel coords into HUDViewport's design space.
		# HUDDisplay fills the window; HUDViewport renders at window/scale, so
		# `scale_factor = hud_display.size / hud_viewport.size`. Reading both at
		# event-time means resize is picked up without extra signal plumbing.
		var hud_event: InputEventMouse = event.duplicate()
		var scale_factor: float = _hud_display_scale()
		var local_pos: Vector2 = (event.position - _hud_display.position) / scale_factor
		hud_event.position = local_pos
		hud_event.global_position = local_pos
		if hud_event is InputEventMouseMotion:
			hud_event.relative = event.relative / scale_factor
		remapped = hud_event
	_hud_viewport.push_input(remapped, true)


func _hud_display_scale() -> float:
	var design_w: float = _hud_viewport.size.x
	if design_w <= 0.0:
		return 1.0
	return _hud_display.size.x / design_w
