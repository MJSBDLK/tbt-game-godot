## Bare-text menu entry — the "menus venue" of the border vocabulary
## (ui-style-guide §14, RQD 2026-08-03). Full-screen menus drop the
## lit-border box for free-floating glow text, because everything on such a
## screen is pressable; the two marks that still matter both render here:
##
##  - CORNER TICKS ("you are here") — the same bracket geometry as
##    InteractiveButton and the board cursor (bracket_tick_rects is the one
##    source). One aim, one model: ticks follow HOVER only under the pointer
##    model and FOCUS only under the cursor model (InputSource.last_kind),
##    so the two inputs can never mark different entries at once — the
##    two-cursors bug Black Mesa has shipped since 2020.
##  - THE LIT BORDER ("the default action") — `is_default_action` dresses
##    this one entry as a bordered primary button among bare-text entries.
##    Static on purpose: the converging CTA rings were tried here first and
##    RETIRED (RQD round 9) — the yield rule made them flicker on every
##    mouse pass through the dead space between entries. The border is
##    §14's own "pressable" mark doing double duty as "most pressable."
##
## Optional `sub_text` renders in the semantic INFO voice (banana gold) —
## Continue wears "Mission N, Turn N" there. `inert` styles the entry as
## unlit glass: dim, unfocusable, tickless (the locked start-level row).
class_name MainMenuEntry
extends MarginContainer


signal pressed


const GLOW_MATERIAL: ShaderMaterial = preload("res://resources/hud_glow.tres")

const PRESS_FLASH_MS: int = 120
const TICK_INSET_PIXELS: float = 2.0
const TICK_ARM_PIXELS: float = 4.0

var text: String = ""
var sub_text: String = ""

## Unlit glass: dim, unfocusable, tickless. SETTABLE AT ANY TIME — the setter
## keeps focus_mode and the dim styling in sync, because entries that go inert
## after construction are the common case (the bEXP row empties, Save Game
## latches). Flipping the flag alone used to leave the entry fully lit and
## still reachable by cursor navigation; _ready() applied both once and never
## again.
var inert: bool = false:
	set(value):
		inert = value
		focus_mode = Control.FOCUS_NONE if value else Control.FOCUS_ALL
		_apply_inert_style()
		queue_redraw()

## The one primary action on the screen: wears the lit-border box. Aiming at
## it brightens the border (same idle→focus step as InteractiveButton).
var is_default_action: bool = false:
	set(value):
		is_default_action = value
		queue_redraw()

var _hovered: bool = false
var _press_flash_started_ms: int = -PRESS_FLASH_MS
var _main_label: GlowLabel = null
var _sub_label: GlowLabel = null


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE if inert else Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_constant_override("margin_left", 6)
	add_theme_constant_override("margin_right", 6)
	add_theme_constant_override("margin_top", 3)
	add_theme_constant_override("margin_bottom", 3)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_main_label = _make_glow_label(text, UIManager.font_11px, 11,
			GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW)
	column.add_child(_main_label)
	if sub_text != "":
		_sub_label = _make_glow_label(sub_text, UIManager.font_8px, 8,
				GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW)
		column.add_child(_sub_label)
	_apply_inert_style()

	mouse_entered.connect(func() -> void: _hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hovered = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _process(_delta: float) -> void:
	# Cheap per-frame redraw while the aim mark is live — it must follow
	# InputSource model flips, which have no signal; sampling in _draw each
	# frame is the no-flicker way.
	if is_aimed() or is_default_action:
		queue_redraw()


## No-ops before _ready() builds the labels; _ready() calls this itself once
## they exist, so setting `inert` at any point in the lifecycle lands.
func _apply_inert_style() -> void:
	if _main_label == null:
		return
	if inert:
		_main_label.add_theme_color_override("font_color", GameColors.INTERACTIVE_TEXT_DISABLED)
		_main_label.glow_color = Color.TRANSPARENT
	else:
		_main_label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
		_main_label.glow_color = GameColors.TEXT_PRIMARY_GLOW


## The one-aim-one-model verdict: does the mark belong on THIS entry now?
func is_aimed() -> bool:
	if inert:
		return false
	if InputSource.is_pointer_driven():
		return _hovered
	return has_focus()


func _gui_input(event: InputEvent) -> void:
	if inert:
		return
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
		accept_event()
		_press()
	elif event.is_action_pressed("ui_accept") and has_focus():
		accept_event()
		_press()


func _press() -> void:
	_press_flash_started_ms = Time.get_ticks_msec()
	# §14 press response: 1 game px downward dip + flash. The dip rides the
	# top margin so the container layout carries it without a position fight.
	add_theme_constant_override("margin_top", 4)
	add_theme_constant_override("margin_bottom", 2)
	get_tree().create_timer(float(PRESS_FLASH_MS) / 1000.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			add_theme_constant_override("margin_top", 3)
			add_theme_constant_override("margin_bottom", 3)
			queue_redraw())
	queue_redraw()
	pressed.emit()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if is_default_action and not inert:
		draw_rect(rect, GameColors.ACTION_BUTTON_BG_NORMAL, true)
		var border_color := GameColors.INTERACTIVE_BORDER_FOCUS if is_aimed() \
				else GameColors.INTERACTIVE_BORDER_IDLE
		draw_rect(Rect2(rect.position + Vector2(0.5, 0.5), rect.size - Vector2.ONE),
				border_color, false, 1.0)
	if is_aimed():
		for tick: Rect2 in InteractiveButton.bracket_tick_rects(
				rect, TICK_INSET_PIXELS, TICK_ARM_PIXELS):
			draw_rect(tick, GameColors.INTERACTIVE_BRACKET, true)
	if Time.get_ticks_msec() - _press_flash_started_ms < PRESS_FLASH_MS:
		draw_rect(rect, Color(1, 1, 1, 0.12), true)


func _make_glow_label(label_text: String, font: FontFile, font_size: int,
		color: Color, glow: Color) -> GlowLabel:
	var label := GlowLabel.new()
	label.text = label_text
	label.material = GLOW_MATERIAL.duplicate()
	label.glow_color = glow
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
