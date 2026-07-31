## Which interaction MODEL is driving the UI right now: POINTER (mouse/touch)
## or CURSOR (keyboard/controller navigation). RQD's meeting ask (2026-06-28):
## menus should open with a default selection ONLY under controller — but
## input sources must coexist (no mode switch) and prompts must never flicker.
##
## The anti-flicker doctrine, in two rules (built 2026-07-29):
##   1. The STATE here is "which model drove the UI last" — it changes only on
##      discrete, debounced events: presses always flip it; mouse motion must
##      exceed a real distance and stick motion a real deadzone, so drift and
##      jitter can never flip it back and forth.
##   2. Consumers SAMPLE at boundaries (menu open, focus adoption) — nothing
##      subscribes and live-swaps. A prompt glyph that wants to ride this
##      later must follow the same rule: swap at boundaries, never mid-frame.
##
## Both inputs stay live at all times; there is no mode. A pointer-opened
## menu has no cursor until the first navigation press summons it (see the
## menus' quiet-open adoption in _unhandled_input).
##
## Registered as Autoload "InputSource", early in the list so its _input
## observes events before scene nodes can consume them. Observes only —
## never calls set_input_as_handled.
extends Node


enum Kind { POINTER, CURSOR }

## Stick/trigger motion below this is drift, not intent. Triggers rest at 0
## and sticks near 0; half-travel is a deliberate act on any pad.
const STICK_DEADZONE: float = 0.5
## Mouse motion below this many native px per event is jitter (a nudged desk,
## a cheap sensor), not the player reaching for the mouse.
const MOUSE_MOTION_MIN_PX: float = 4.0

## Boot default: POINTER — menus open quiet. Costs a controller player one
## navigation press in the rare case a menu opens before their first input;
## in practice (Steam Deck included) some button press always precedes the
## first menu and flips this to CURSOR long before it matters.
var last_kind: Kind = Kind.POINTER


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			last_kind = Kind.CURSOR
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= STICK_DEADZONE:
			last_kind = Kind.CURSOR
	elif event is InputEventKey:
		if (event as InputEventKey).pressed:
			last_kind = Kind.CURSOR
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			last_kind = Kind.POINTER
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() >= MOUSE_MOTION_MIN_PX:
			last_kind = Kind.POINTER
	elif event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			last_kind = Kind.POINTER


func is_cursor_driven() -> bool:
	return last_kind == Kind.CURSOR


func is_pointer_driven() -> bool:
	return last_kind == Kind.POINTER


## True for the four directional UI actions — the presses that summon the
## cursor onto a quiet-opened menu (accept/cancel are NOT summons: nothing
## is selected yet, so there is nothing to accept).
func is_navigation_press(event: InputEvent) -> bool:
	return navigation_direction(event) != Vector2i.ZERO


## The grid direction of a navigation press (screen convention: -y is up), or
## ZERO for any other event. Board consumers (the board cursors) use the
## vector; menus only care that it isn't ZERO. NOTE: the game grid is Y-up —
## board consumers flip the vertical before touching grid coordinates.
func navigation_direction(event: InputEvent) -> Vector2i:
	if event.is_action_pressed("ui_up"):
		return Vector2i(0, -1)
	if event.is_action_pressed("ui_down"):
		return Vector2i(0, 1)
	if event.is_action_pressed("ui_left"):
		return Vector2i(-1, 0)
	if event.is_action_pressed("ui_right"):
		return Vector2i(1, 0)
	return Vector2i.ZERO


## Inverse of navigation_direction: the input action whose held state backs a
## direction. Powers hold-to-repeat cursor travel — key echo is keyboard-only,
## so repeat is timer-driven off Input.is_action_pressed and this mapping,
## serving keyboard and d-pad identically. Empty StringName for ZERO/diagonals.
func action_for_direction(direction: Vector2i) -> StringName:
	if direction == Vector2i(0, -1):
		return &"ui_up"
	if direction == Vector2i(0, 1):
		return &"ui_down"
	if direction == Vector2i(-1, 0):
		return &"ui_left"
	if direction == Vector2i(1, 0):
		return &"ui_right"
	return &""
