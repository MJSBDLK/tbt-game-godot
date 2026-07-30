## InputSource — the "which interaction model is driving" autoload (RQD
## 2026-06-28 ask, built 2026-07-29). Pins the anti-flicker debounce: presses
## always flip the model; mouse jitter and stick drift NEVER do. Instances
## the script directly so tests don't disturb the live autoload.
extends GutTest


var _InputSourceScript: GDScript = preload("res://scripts/core/input_source.gd")


func _make_source() -> Node:
	var source: Node = _InputSourceScript.new()
	autofree(source)
	return source


func _joypad_button(pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	return event


func _stick_motion(value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	return event


func _mouse_motion(distance: float) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(distance, 0)
	return event


func test_boot_default_is_pointer_so_menus_open_quiet() -> void:
	assert_true(_make_source().is_pointer_driven())


func test_presses_flip_the_model_both_ways() -> void:
	var source := _make_source()
	source._input(_joypad_button(true))
	assert_true(source.is_cursor_driven(), "a pad press means the cursor model drives")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	source._input(click)
	assert_true(source.is_pointer_driven(), "a click hands the wheel to the pointer")
	var key := InputEventKey.new()
	key.keycode = KEY_DOWN
	key.pressed = true
	source._input(key)
	assert_true(source.is_cursor_driven(), "keyboard is cursor-model input too")


func test_releases_never_flip() -> void:
	var source := _make_source()
	source._input(_joypad_button(true))
	source._input(_joypad_button(false))
	assert_true(source.is_cursor_driven(), "only presses carry intent")


func test_jitter_and_drift_are_debounced_out() -> void:
	# The flicker guard: sub-threshold motion carries no intent, so the model
	# can never oscillate from a nudged desk or a drifting stick.
	var source := _make_source()
	source._input(_joypad_button(true))
	source._input(_mouse_motion(2.0))
	assert_true(source.is_cursor_driven(), "2px mouse jitter doesn't steal the wheel")
	source._input(_mouse_motion(10.0))
	assert_true(source.is_pointer_driven(), "a real mouse reach does")
	source._input(_stick_motion(0.2))
	assert_true(source.is_pointer_driven(), "stick drift under the deadzone is noise")
	source._input(_stick_motion(0.8))
	assert_true(source.is_cursor_driven(), "half-travel is a deliberate act")


func test_touch_is_pointer_model() -> void:
	var source := _make_source()
	source._input(_joypad_button(true))
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	source._input(touch)
	assert_true(source.is_pointer_driven())


func test_navigation_press_is_directional_only() -> void:
	var source := _make_source()
	for action: String in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		var nav := InputEventAction.new()
		nav.action = action
		nav.pressed = true
		assert_true(source.is_navigation_press(nav), action + " summons the cursor")
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	assert_false(source.is_navigation_press(accept),
			"accept is NOT a summons — nothing is selected yet, nothing to accept")
