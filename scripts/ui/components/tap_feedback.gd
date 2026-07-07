## One-shot input-receipt feedback: a small expanding ring pulse at every press
## position (mouse click / touch tap), firing whether or not the input hit
## anything interactible — kills the "dead input" feeling (FE Heroes-style).
##
## Lives on its own CanvasLayer at the ROOT viewport (native pixel space),
## above both the pixel HUD (layer 50) and HDLayer (layer 100), so the pulse
## draws over everything. Spawned by InputRouter — the single choke point every
## input event passes through BEFORE any Control can consume it — so clicks the
## HUD swallows still pulse.
##
## THIS IS THE PLACEHOLDER VISUAL Lawrence can restyle: every visual knob is
## @export'd, and the ring itself is one _draw call. Radii/width scale with the
## HUD integer scale so the pulse reads the same size on every monitor.
##
## Controller support is deferred: a controller press has no pointer position
## until the controller focus-navigation mode (todo) gives it a cursor.
class_name TapFeedbackLayer
extends CanvasLayer


@export var ring_color: Color = Color(0.55, 0.95, 1.0, 0.9)
## Radii/width in HUD design pixels — multiplied by the HUD integer scale.
@export var start_radius: float = 2.0
@export var end_radius: float = 8.0
@export var line_width: float = 1.5
@export var duration_seconds: float = 0.22


func _ready() -> void:
	layer = 110


## Spawn one ring pulse at a root-viewport (native pixel) position.
func pulse_at(screen_position: Vector2) -> void:
	var ring := TapFeedbackRing.new()
	var scale_factor := maxf(1.0, float(SceneRouter.get_hud_scale()))
	ring.position = screen_position
	ring.color = ring_color
	ring.start_radius = start_radius * scale_factor
	ring.end_radius = end_radius * scale_factor
	ring.line_width = line_width * scale_factor
	ring.duration_seconds = duration_seconds
	add_child(ring)


## The pulse itself: expanding, fading circle outline that frees itself when
## the animation ends. Pure _process + _draw — no tweens, no textures.
class TapFeedbackRing:
	extends Node2D

	var color: Color = Color.WHITE
	var start_radius: float = 2.0
	var end_radius: float = 8.0
	var line_width: float = 1.5
	var duration_seconds: float = 0.22
	var _elapsed: float = 0.0

	func _process(delta: float) -> void:
		_elapsed += delta
		if _elapsed >= duration_seconds:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var progress := clampf(_elapsed / duration_seconds, 0.0, 1.0)
		var eased := 1.0 - (1.0 - progress) * (1.0 - progress)  # ease-out
		var radius := lerpf(start_radius, end_radius, eased)
		var faded := color
		faded.a = color.a * (1.0 - progress)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, faded, line_width)
