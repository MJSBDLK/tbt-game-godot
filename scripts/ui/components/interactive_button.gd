## The border vocabulary, in code — one button component for all interactive UI.
## Spec: ui-style-guide.md §14; living mockup: data/design/mockups/border-vocabulary.html.
##
## THE CONTRACT: a lit border means "you can press this." On top of that, motion
## carries meaning by CATEGORY, never by parameter:
##   none       = normal interactive button (steady lit border — never pulses)
##   snapping   = SELECTED ("you are here"): white corner ticks, 2 positions, 1.25 Hz
##   converging = CALL TO ACTION ("the game suggests this next"): amber rings
##                shrinking onto the border, which catches the light as they land
## Purple/magenta is RETIRED from selection semantics (2026-07-15) — selection is
## shape, not color. Focus/hover is a BACKLIGHT: the background lifts toward azure
## in 4 discrete shades over 2/15 s (both directions), plus a brighter border.
## Disabled is the darkest tier and pressing it emits `denied` (tap-for-why).
##
## Scarcity rules the vocabulary depends on:
##   - at most ONE call_to_action on screen (enforced: last-wins + warning)
##   - selection is unique by definition (caller's responsibility)
## so at most two things ever animate at once and the screen stays calm.
##
## All motion derives its phase from shared wall-clock time (Time.get_ticks_msec),
## so every button on screen ticks in sync BY CONSTRUCTION — no clock autoload.
## Settings.ui_motion_enabled == false keeps every state's color and parks every
## state's motion. Everything draws on integer pixels; nothing ever scales.
class_name InteractiveButton
extends Button


## Pressed while disabled — the "tell me why not" tap. UI that disables a button
## should connect this to surface the reason (tooltip/toast).
signal denied


# --- Backlight (focus/hover) ---
const BACKLIGHT_DURATION_SECONDS: float = 2.0 / 15.0  # ~8 frames @ 60
const BACKLIGHT_STEPS: int = 4
const BACKLIGHT_MIX: float = 0.22  # how far the bg lifts toward the tint at full

# --- Selected brackets ---
const BRACKET_CYCLE_SECONDS: float = 0.8  # 1.25 Hz (RQD 2026-07-15)
const BRACKET_ARM_PIXELS: int = 5
const BRACKET_INSET_PIXELS: int = 2  # corner sits 2px out from the rect corner

# --- Call to action rings ---
const CTA_WAVE_SECONDS: float = 0.9  # one ring lands every 0.9s (two staggered)
const CTA_SPAWN_INSET_PIXELS: int = 6  # rings spawn this far outside the rect

# --- Press response ---
const PRESS_SHIFT_PIXELS: int = 1
const PRESS_FLASH_ALPHA: float = 0.16

const SFX_HOVER: String = "res://audio/ui/blip_hover.wav"
const SFX_PRESS: String = "res://audio/ui/blip_press.wav"
const SFX_DENY: String = "res://audio/ui/blip_deny.wav"

## The one CTA on screen (scarcity rule). Last-wins with a loud warning rather
## than an assert, so a violation in a shipped build degrades instead of crashing.
static var _call_to_action_owner: InteractiveButton = null


## "You are here." Unique per menu — the caller moves it, we just draw it.
var selected: bool = false:
	set(value):
		if selected == value:
			return
		selected = value
		queue_redraw()

## "The game suggests this next." At most one on screen — see scarcity rules.
var call_to_action: bool = false:
	set(value):
		if call_to_action == value:
			return
		call_to_action = value
		if value:
			_claim_call_to_action()
		elif _call_to_action_owner == self:
			_call_to_action_owner = null
		queue_redraw()

## Background the backlight lifts from. Panels with a different base (e.g. over
## darker ground) can override.
var base_background: Color = GameColors.ACTION_BUTTON_BG_NORMAL

## 0.0–1.0 quantized backlight progress (readable for tests/tools).
var _backlight_level: float = 0.0
## Where the current fade started from and toward, in level space [0..1].
var _backlight_from: float = 0.0
var _backlight_target: float = 0.0
var _backlight_start_ms: int = 0
var _press_flash_ms: int = -10_000


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	# Chrome is entirely ours: empty styleboxes, but keep the press-down text
	# shift by giving the pressed box +1px top content margin (integer pixel).
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = 4
	flat.content_margin_right = 4
	flat.content_margin_top = 1
	flat.content_margin_bottom = 1
	var pressed_box := StyleBoxEmpty.new()
	pressed_box.content_margin_left = 4
	pressed_box.content_margin_right = 4
	pressed_box.content_margin_top = 1 + PRESS_SHIFT_PIXELS
	pressed_box.content_margin_bottom = 1 - PRESS_SHIFT_PIXELS
	for state_name: String in ["normal", "hover", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state_name, flat)
	add_theme_stylebox_override("pressed", pressed_box)
	add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	add_theme_color_override("font_hover_color", GameColors.TEXT_PRIMARY)
	add_theme_color_override("font_focus_color", GameColors.TEXT_PRIMARY)
	add_theme_color_override("font_pressed_color", Color.WHITE)
	add_theme_color_override("font_disabled_color", GameColors.INTERACTIVE_TEXT_DISABLED)

	mouse_entered.connect(_on_pointer_gained)
	mouse_exited.connect(_on_pointer_lost)
	focus_entered.connect(_on_pointer_gained)
	focus_exited.connect(_on_pointer_lost)
	button_down.connect(_on_button_down)


func _exit_tree() -> void:
	if _call_to_action_owner == self:
		_call_to_action_owner = null


func _process(_delta: float) -> void:
	# Redraw only while something is actually animating; static states cost nothing.
	var fading: bool = not is_equal_approx(_backlight_level, _backlight_target)
	if fading:
		_backlight_level = _current_backlight_level()
	var flashing: bool = Time.get_ticks_msec() - _press_flash_ms < 120
	if fading or flashing or _wants_motion():
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# Disabled buttons still see input; a press on one is a question, not a click.
	if not disabled:
		return
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		_play_sfx(SFX_DENY)
		denied.emit()
		accept_event()


func _draw() -> void:
	var shift := Vector2(0, PRESS_SHIFT_PIXELS if is_pressed() else 0)
	var rect := Rect2(shift, size)

	# --- Backlight fill (behind everything) ---
	var background := base_background
	if _backlight_level > 0.0:
		background = base_background.lerp(
				GameColors.INTERACTIVE_BACKLIGHT_TINT, _backlight_level * BACKLIGHT_MIX)
	draw_rect(rect, background, true)

	# --- Border: 1px, color says which tier you're looking at ---
	var border_color := _border_color()
	draw_rect(Rect2(rect.position + Vector2(0.5, 0.5), rect.size - Vector2.ONE),
			border_color, false, 1.0)

	# --- Selected: snapping corner ticks (shape carries selection, not color) ---
	if selected and not disabled:
		_draw_brackets(rect)

	# --- Call to action: converging rings ---
	if call_to_action and not disabled and _motion_enabled():
		_draw_cta_rings(rect)

	# --- Press flash ---
	if is_pressed() or Time.get_ticks_msec() - _press_flash_ms < 120:
		draw_rect(rect, Color(1, 1, 1, PRESS_FLASH_ALPHA), true)


# =============================================================================
# STATE MATH — static + pure where possible so GUT can pin the spec exactly.
# =============================================================================

## Quantized backlight level after `elapsed` seconds of fading from `from`
## toward `target`: exactly BACKLIGHT_STEPS discrete shades, never a glide.
static func backlight_level_at(elapsed: float, from: float, target: float) -> float:
	if elapsed >= BACKLIGHT_DURATION_SECONDS:
		return target
	var raw: float = elapsed / BACKLIGHT_DURATION_SECONDS
	var stepped: float = floorf(raw * BACKLIGHT_STEPS) / BACKLIGHT_STEPS
	return from + (target - from) * stepped


## True when the brackets sit in their "out" position (1px past rest) at the
## given wall-clock phase. Exactly two positions — no easing between.
static func brackets_out_at(seconds: float) -> bool:
	return fmod(seconds, BRACKET_CYCLE_SECONDS) >= BRACKET_CYCLE_SECONDS * 0.5


## Ring inset (pixels outside the rect) for one CTA wave at `phase` [0..1):
## spawns CTA_SPAWN_INSET_PIXELS out, steps inward one integer pixel at a time,
## lands at 0 (on the border).
static func cta_ring_inset_at(phase: float) -> int:
	var steps: int = CTA_SPAWN_INSET_PIXELS
	return steps - int(floorf(clampf(phase, 0.0, 0.999) * (steps + 1)))


# =============================================================================
# INTERNALS
# =============================================================================

func _border_color() -> Color:
	if disabled:
		return GameColors.INTERACTIVE_BORDER_DISABLED
	if call_to_action:
		# The border "catches" each ring as it lands; parked bright without motion.
		if not _motion_enabled() or _cta_phase(0.0) > 0.72:
			return GameColors.CALL_TO_ACTION_BRIGHT
		return GameColors.CALL_TO_ACTION_DIM
	if _backlight_target > 0.5 or _backlight_level > 0.5:
		return GameColors.INTERACTIVE_BORDER_FOCUS
	return GameColors.INTERACTIVE_BORDER_IDLE


func _draw_brackets(rect: Rect2) -> void:
	var out: bool = _motion_enabled() and brackets_out_at(_now_seconds())
	var inset: float = BRACKET_INSET_PIXELS + (1 if out else 0)
	var arm: float = BRACKET_ARM_PIXELS
	var color := GameColors.INTERACTIVE_BRACKET
	var corners: Array[Vector2] = [
		rect.position + Vector2(-inset, -inset),                            # TL
		Vector2(rect.end.x + inset, rect.position.y - inset),               # TR
		Vector2(rect.position.x - inset, rect.end.y + inset),               # BL
		rect.end + Vector2(inset, inset),                                   # BR
	]
	for i: int in corners.size():
		var corner: Vector2 = corners[i]
		var toward_center := Vector2(
				1.0 if corner.x < rect.get_center().x else -1.0,
				1.0 if corner.y < rect.get_center().y else -1.0)
		# Horizontal arm, then vertical arm — each 1px thick, drawn inward.
		var horizontal_origin := corner if toward_center.x > 0 else corner - Vector2(arm, 0)
		var vertical_origin := corner if toward_center.y > 0 else corner - Vector2(0, arm)
		if toward_center.y < 0:
			horizontal_origin.y -= 1.0
		if toward_center.x < 0:
			vertical_origin.x -= 1.0
		draw_rect(Rect2(horizontal_origin, Vector2(arm, 1)), color, true)
		draw_rect(Rect2(vertical_origin, Vector2(1, arm)), color, true)


func _draw_cta_rings(rect: Rect2) -> void:
	# Two waves half a cycle apart, so a ring is always inbound.
	for stagger: float in [0.0, 0.5]:
		var phase: float = _cta_phase(stagger)
		var inset: int = cta_ring_inset_at(phase)
		var alpha: float = lerpf(0.2, 0.9, phase)
		var color := GameColors.CALL_TO_ACTION_BRIGHT
		color.a = alpha
		var ring := Rect2(rect.position - Vector2(inset, inset),
				rect.size + Vector2(inset * 2, inset * 2))
		draw_rect(Rect2(ring.position + Vector2(0.5, 0.5), ring.size - Vector2.ONE),
				color, false, 1.0)


func _cta_phase(stagger: float) -> float:
	return fmod(_now_seconds() / CTA_WAVE_SECONDS + stagger, 1.0)


func _current_backlight_level() -> float:
	if not _motion_enabled():
		return _backlight_target
	var elapsed: float = float(Time.get_ticks_msec() - _backlight_start_ms) / 1000.0
	return backlight_level_at(elapsed, _backlight_from, _backlight_target)


func _wants_motion() -> bool:
	return _motion_enabled() and not disabled and (selected or call_to_action)


func _motion_enabled() -> bool:
	return Settings == null or Settings.ui_motion_enabled


func _on_pointer_gained() -> void:
	if disabled:
		return
	_start_backlight_fade(1.0)
	_play_sfx(SFX_HOVER)


func _on_pointer_lost() -> void:
	# Keep the backlight while the OTHER acquisition channel still holds us
	# (mouse leaving a focused button shouldn't drop the controller focus glow).
	if has_focus() or get_global_rect().has_point(get_global_mouse_position()):
		return
	_start_backlight_fade(0.0)


func _on_button_down() -> void:
	_press_flash_ms = Time.get_ticks_msec()
	_play_sfx(SFX_PRESS)
	queue_redraw()


func _start_backlight_fade(target: float) -> void:
	if is_equal_approx(_backlight_target, target):
		return
	_backlight_from = _backlight_level
	_backlight_target = target
	_backlight_start_ms = Time.get_ticks_msec()
	queue_redraw()


func _claim_call_to_action() -> void:
	if _call_to_action_owner != null and is_instance_valid(_call_to_action_owner) \
			and _call_to_action_owner != self and _call_to_action_owner.call_to_action \
			and _call_to_action_owner.is_visible_in_tree():
		# Scarcity rule: ONE call to action on screen. Last-wins so a shipped
		# build degrades gracefully, but loudly — this is a design bug.
		push_warning("InteractiveButton: second call_to_action on screen ('%s' steals from '%s')"
				% [text, _call_to_action_owner.text])
		_call_to_action_owner.call_to_action = false
	_call_to_action_owner = self


func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _play_sfx(path: String) -> void:
	if not is_inside_tree() or not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path) as AudioStream
	player.bus = &"SFX"
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
