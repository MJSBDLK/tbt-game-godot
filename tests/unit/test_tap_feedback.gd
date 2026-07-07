## Tap/click input-receipt feedback: TapFeedbackLayer's ring spawning and
## InputRouter's press filtering. The ring's look is eyeball territory; what's
## pinned here is the contract — every real press pulses exactly once at the
## press position, and non-press events never pulse.
extends GutTest


func _layer() -> TapFeedbackLayer:
	var layer := TapFeedbackLayer.new()
	add_child_autofree(layer)
	return layer


func _router_with(layer: TapFeedbackLayer) -> InputRouter:
	var router := InputRouter.new()
	autofree(router)
	# Bypass the @onready sibling lookup — only the feedback hook is under test.
	router._tap_feedback = layer
	return router


func _mouse_press(button: MouseButton = MOUSE_BUTTON_LEFT, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(100, 50)
	return event


func test_pulse_at_spawns_a_ring_at_the_press_position() -> void:
	var layer := _layer()
	layer.pulse_at(Vector2(123, 45))
	assert_eq(layer.get_child_count(), 1, "one pulse per call")
	var ring: Node2D = layer.get_child(0)
	assert_eq(ring.position, Vector2(123, 45), "ring spawns at the press position")


func test_ring_frees_itself_when_the_animation_ends() -> void:
	var layer := _layer()
	layer.pulse_at(Vector2.ZERO)
	var ring: Node = layer.get_child(0)
	ring._process(1.0)  # far past duration_seconds
	assert_true(ring.is_queued_for_deletion(), "ring cleans itself up — no pooling, no leaks")


func test_left_and_right_presses_pulse() -> void:
	var layer := _layer()
	var router := _router_with(layer)
	router._pulse_tap_feedback(_mouse_press(MOUSE_BUTTON_LEFT))
	router._pulse_tap_feedback(_mouse_press(MOUSE_BUTTON_RIGHT))
	assert_eq(layer.get_child_count(), 2, "left and right presses each pulse")


func test_releases_motion_and_wheel_do_not_pulse() -> void:
	var layer := _layer()
	var router := _router_with(layer)
	router._pulse_tap_feedback(_mouse_press(MOUSE_BUTTON_LEFT, false))  # release
	router._pulse_tap_feedback(_mouse_press(MOUSE_BUTTON_WHEEL_UP))
	router._pulse_tap_feedback(InputEventMouseMotion.new())
	assert_eq(layer.get_child_count(), 0, "only presses pulse")


func test_touch_press_pulses_but_its_mouse_echo_does_not() -> void:
	var layer := _layer()
	var router := _router_with(layer)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(10, 10)
	router._pulse_tap_feedback(touch)
	# Godot synthesizes a mouse press from the touch with DEVICE_ID_EMULATION —
	# it must NOT double-pulse.
	var emulated := _mouse_press(MOUSE_BUTTON_LEFT)
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	router._pulse_tap_feedback(emulated)
	assert_eq(layer.get_child_count(), 1, "a touch tap pulses exactly once")
