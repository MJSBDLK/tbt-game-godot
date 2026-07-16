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
## Rendering is split across three canvas items so the text glow shader (the
## menus' visual identity) halos ONLY the glyphs: a behind-chrome child draws
## backlight + border, the Button itself draws just its text under the
## orthogonal-glow material, and a front-chrome child draws brackets, rings,
## and the press flash on top.
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

## Text sits 1px below true center on purpose: with few descenders (q/y/p) in
## menu strings, optical center is a pixel lower than geometric center (RQD).
const TEXT_TOP_MARGIN_PIXELS: int = 2
const TEXT_BOTTOM_MARGIN_PIXELS: int = 0

const GLOW_MATERIAL: ShaderMaterial = preload("res://resources/hud_glow.tres")

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
		_redraw_chrome()

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
		_redraw_chrome()

## Background the backlight lifts from. Panels with a different base (e.g. over
## darker ground) can override.
var base_background: Color = GameColors.ACTION_BUTTON_BG_NORMAL

## EXPERIMENT (RQD 2026-07-15): draw the border through orthogonal_glow's
## border_mode so it halos like the text — one consistent glow identity.
## Default off until the in-gallery verdict lands; the gallery has an A/B
## toggle. If this loses, delete this property, _border_glow_rect, and
## _sync_border_glow_rect.
var border_glow: bool = false:
	set(value):
		if border_glow == value:
			return
		border_glow = value
		if _border_glow_rect != null:
			_border_glow_rect.visible = value
		_redraw_chrome()

## 0.0–1.0 quantized backlight progress (readable for tests/tools).
var _backlight_level: float = 0.0
## Where the current fade started from and toward, in level space [0..1].
var _backlight_from: float = 0.0
var _backlight_target: float = 0.0
var _backlight_start_ms: int = 0
var _press_flash_ms: int = -10_000
var _chrome_behind: Control = null
var _chrome_front: Control = null
var _border_glow_rect: ColorRect = null
## True when the current focus was grabbed by a pointer click rather than
## keyboard/controller navigation. Click-focus must NOT hold the backlight
## after the mouse leaves — a selected button would read as focused forever
## and muddy the vocabulary. Controller focus IS the traveling cursor, so it
## keeps the backlight for as long as it stays.
var _focus_from_pointer: bool = false
## Disabled has no change notification, so _process watches it (border tier and
## text glow both depend on it).
var _last_disabled: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	# Chrome is entirely ours: empty styleboxes; the pressed box shifts the text
	# down 1px with the border/bracket shift (integer pixels only).
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = 4
	flat.content_margin_right = 4
	flat.content_margin_top = TEXT_TOP_MARGIN_PIXELS
	flat.content_margin_bottom = TEXT_BOTTOM_MARGIN_PIXELS
	var pressed_box := StyleBoxEmpty.new()
	pressed_box.content_margin_left = 4
	pressed_box.content_margin_right = 4
	pressed_box.content_margin_top = TEXT_TOP_MARGIN_PIXELS + PRESS_SHIFT_PIXELS
	pressed_box.content_margin_bottom = TEXT_BOTTOM_MARGIN_PIXELS
	for state_name: String in ["normal", "hover", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state_name, flat)
	add_theme_stylebox_override("pressed", pressed_box)
	add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	add_theme_color_override("font_hover_color", GameColors.TEXT_PRIMARY)
	add_theme_color_override("font_focus_color", GameColors.TEXT_PRIMARY)
	add_theme_color_override("font_pressed_color", Color.WHITE)
	add_theme_color_override("font_disabled_color", GameColors.INTERACTIVE_TEXT_DISABLED)

	# The glow shader lives on the Button itself, which draws ONLY text (empty
	# styleboxes; borders live on the chrome children) — so the halo is
	# glyph-only, matching GlowLabel everywhere else in the HUD.
	material = GLOW_MATERIAL.duplicate()
	_last_disabled = disabled
	_sync_text_glow()

	_chrome_behind = _Chrome.new(self, true)
	add_child(_chrome_behind)
	# Border-glow experiment surface: sits above the fill, below the glyphs.
	# The shader's border_mode insets the border 1px, so the rect is 2px
	# oversized to land the border exactly on the button edge with 1px of
	# glow on each side.
	_border_glow_rect = ColorRect.new()
	_border_glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border_glow_rect.show_behind_parent = true
	var border_material := GLOW_MATERIAL.duplicate() as ShaderMaterial
	border_material.set_shader_parameter("solid_rect", true)
	border_material.set_shader_parameter("border_mode", true)
	_border_glow_rect.material = border_material
	_border_glow_rect.visible = border_glow
	add_child(_border_glow_rect)
	_chrome_front = _Chrome.new(self, false)
	add_child(_chrome_front)

	mouse_entered.connect(_on_pointer_gained)
	mouse_exited.connect(_on_pointer_lost)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_pointer_lost)
	button_down.connect(_on_button_down)
	button_up.connect(_redraw_chrome)


func _exit_tree() -> void:
	if _call_to_action_owner == self:
		_call_to_action_owner = null


func _process(_delta: float) -> void:
	if disabled != _last_disabled:
		_last_disabled = disabled
		_sync_text_glow()
		_redraw_chrome()
	# Redraw only while something is actually animating; static states cost nothing.
	var fading: bool = not is_equal_approx(_backlight_level, _backlight_target)
	if fading:
		_backlight_level = _current_backlight_level()
	var flashing: bool = Time.get_ticks_msec() - _press_flash_ms < 120
	if fading or flashing or _wants_motion():
		_redraw_chrome()


func _gui_input(event: InputEvent) -> void:
	# Disabled buttons still see input; a press on one is a question, not a click.
	if not disabled:
		return
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		_play_sfx(SFX_DENY)
		denied.emit()
		accept_event()


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
# CHROME DRAWING — called by the two child canvas items (behind: fill + border;
# front: brackets, rings, press flash). Kept here so all state logic is in one
# file; the children are dumb surfaces.
# =============================================================================

func _draw_chrome(canvas: Control, behind: bool) -> void:
	var shift := Vector2(0, PRESS_SHIFT_PIXELS if is_pressed() else 0)
	var rect := Rect2(shift, size)
	if behind:
		var background := base_background
		if _backlight_level > 0.0:
			background = base_background.lerp(
					GameColors.INTERACTIVE_BACKLIGHT_TINT, _backlight_level * BACKLIGHT_MIX)
		canvas.draw_rect(rect, background, true)
		if not border_glow:
			canvas.draw_rect(Rect2(rect.position + Vector2(0.5, 0.5), rect.size - Vector2.ONE),
					_border_color(), false, 1.0)
		return
	if selected and not disabled:
		_draw_brackets(canvas, rect)
	if call_to_action and not disabled and _motion_enabled():
		_draw_cta_rings(canvas, rect)
	if is_pressed() or Time.get_ticks_msec() - _press_flash_ms < 120:
		canvas.draw_rect(rect, Color(1, 1, 1, PRESS_FLASH_ALPHA), true)


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


func _draw_brackets(canvas: Control, rect: Rect2) -> void:
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
		canvas.draw_rect(Rect2(horizontal_origin, Vector2(arm, 1)), color, true)
		canvas.draw_rect(Rect2(vertical_origin, Vector2(1, arm)), color, true)


func _draw_cta_rings(canvas: Control, rect: Rect2) -> void:
	# Two waves half a cycle apart, so a ring is always inbound.
	for stagger: float in [0.0, 0.5]:
		var phase: float = _cta_phase(stagger)
		var inset: int = cta_ring_inset_at(phase)
		var alpha: float = lerpf(0.2, 0.9, phase)
		var color := GameColors.CALL_TO_ACTION_BRIGHT
		color.a = alpha
		var ring := Rect2(rect.position - Vector2(inset, inset),
				rect.size + Vector2(inset * 2, inset * 2))
		canvas.draw_rect(Rect2(ring.position + Vector2(0.5, 0.5), ring.size - Vector2.ONE),
				color, false, 1.0)


# =============================================================================
# INTERNALS
# =============================================================================

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


## Text glow follows the font color's tier, GlowLabel-style: azure identity
## glow normally, a dim gray whisper when disabled.
func _sync_text_glow() -> void:
	var shader := material as ShaderMaterial
	if shader == null:
		return
	var glow_color: Color = GameColorPalette.get_color("Gray", 3) if disabled \
			else GameColors.TEXT_PRIMARY_GLOW
	shader.set_shader_parameter("glow_color", glow_color)


func _redraw_chrome() -> void:
	if _chrome_behind != null:
		_chrome_behind.queue_redraw()
	if _chrome_front != null:
		_chrome_front.queue_redraw()
	if _border_glow_rect != null and border_glow:
		_sync_border_glow_rect()


## The experiment border tracks state like the drawn one: color per tier
## (including the CTA catch-flash), 1px press shift, size on resize.
func _sync_border_glow_rect() -> void:
	var press_shift: float = PRESS_SHIFT_PIXELS if is_pressed() else 0.0
	_border_glow_rect.position = Vector2(-1.0, press_shift - 1.0)
	_border_glow_rect.size = size + Vector2(2.0, 2.0)
	var border := _border_color()
	_border_glow_rect.color = border
	# The azure border already matches text PRIMARY, so glowing azure-on-azure
	# read as redundant (RQD) — its halo borrows the SECONDARY text color
	# instead, echoing the primary/secondary typography pairing. CTA and
	# disabled keep self-colored halos (amber stays unmistakably amber).
	var glow_color: Color = border
	if not disabled and not call_to_action:
		glow_color = GameColors.TEXT_SECONDARY
	var shader := _border_glow_rect.material as ShaderMaterial
	shader.set_shader_parameter("glow_color", glow_color)
	shader.set_shader_parameter("rect_size", size + Vector2(2.0, 2.0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_redraw_chrome()


func _on_pointer_gained() -> void:
	if disabled:
		return
	_start_backlight_fade(1.0)


func _on_focus_entered() -> void:
	# A mouse button being down while focus arrives means the click grabbed it.
	_focus_from_pointer = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	# The tick plays ONLY for keyboard/controller focus steps — discrete,
	# one per input, console-menu feel. Mouse hover is continuous and would
	# cacophony across a menu (RQD 2026-07-15); the backlight is its feedback.
	if not _focus_from_pointer and not disabled:
		_play_sfx(SFX_HOVER)
	_on_pointer_gained()


func _on_pointer_lost() -> void:
	# Keep the backlight only while another acquisition channel legitimately
	# holds us: the mouse still inside, or focus that arrived via keyboard/
	# controller (the traveling cursor). Click-grabbed focus doesn't count.
	if get_global_rect().has_point(get_global_mouse_position()):
		return
	if has_focus() and not _focus_from_pointer:
		return
	_start_backlight_fade(0.0)


func _on_button_down() -> void:
	_press_flash_ms = Time.get_ticks_msec()
	_play_sfx(SFX_PRESS)
	_redraw_chrome()


func _start_backlight_fade(target: float) -> void:
	if is_equal_approx(_backlight_target, target):
		return
	_backlight_from = _backlight_level
	_backlight_target = target
	_backlight_start_ms = Time.get_ticks_msec()
	_redraw_chrome()


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


## Dumb drawing surface: fills the button rect and delegates to the button's
## chrome painter. `behind` draws under the glyphs (show_behind_parent), the
## other instance draws on top — keeping the glow shader glyph-only.
class _Chrome extends Control:
	var _button: InteractiveButton
	var _behind: bool

	func _init(button: InteractiveButton, behind: bool) -> void:
		_button = button
		_behind = behind
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = behind

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		_button._draw_chrome(self, _behind)
