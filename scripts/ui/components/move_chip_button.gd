## A move chip wearing the border vocabulary (ui-style-guide.md §14, "Move
## chips" section of the mockup). Body and border are SKIN: the MoveChip
## shader draws the element fill/empty pair, the skewed usage boundary, and
## its own gray rounded border — none of which the vocabulary may repaint
## (RQD 2026-07-16). The vocabulary contributes:
##   backlight  — the body lifts one luminance step on hover/focus (fill and
##                empty together, so the usage boundary keeps its contrast)
##   brackets   — snapping = the menu cursor is here (inherited `selected`);
##                PARKED = this is the assigned move. Same shape, same white;
##                motion category carries the difference. Replaces "> ".
##   disabled   — depleted/locked drop the whole chip to the dark tier and
##                pressing emits `denied`; `disabled_reason` says why.
##   press/CTA  — inherited unchanged (1px shift + flash; amber rings).
class_name MoveChipButton
extends InteractiveButton


const CHIP_MATERIAL: ShaderMaterial = preload("res://resources/move_chip_fill.tres")

## Fixed name column ("scheme + digits" layout, RQD 2026-07-19): the name
## clips at this width so the scheme/range columns align down the menu.
## Real data uses abbrev_name; clipping is the fallback, not the plan.
const NAME_COLUMN_WIDTH: float = 38.0

## The GlowLabel prefab's optical seat (ui_text.tscn: MarginContainer with
## margin_top = 2): pixel caps carry their mass high, so true center reads
## high. Chip text rides the same 2px so it sits like every panel label.
const TEXT_TOP_MARGIN: int = 2

## Why pressing is currently refused — surfaced by deny UI (styled tooltip).
var disabled_reason: String = ""

## Venue knobs: wider contexts (unit detail panel) widen the name column and
## show the full move name instead of the menu abbreviation. Set BEFORE the
## chip enters the tree — the column width is applied in _ready.
@export var name_column_width: float = NAME_COLUMN_WIDTH
@export var prefer_full_name: bool = false

## Field sets per venue ("that's smart" — RQD 2026-07-19): the action menu
## shows everything (the battle decision point); the detail panel's pane
## already shows the numbers, so its chips are identity-only selectors; the
## preview readout keeps uses. Set BEFORE the chip enters the tree.
@export var show_scheme_and_range: bool = true
@export var show_uses: bool = true

## Venue knob: hold-to-peek detail card (MoveTooltip; ui-style-guide.md §14).
## On wherever a chip appears without its numbers spelled out nearby; the
## detail panel turns it off — its detail pane IS the card's content, so a
## tooltip there would only stack noise (RQD 2026-07-21, "no-op in the detail
## panel"). The preview panel does NOT use this path either: its chips are
## mouse-transparent (the map hover underneath flips the panel away — the
## M&K/controller answer), so the panel itself watches for touch holds.
@export var peek_enabled: bool = true

## This move is the unit's assigned move: parked brackets, persistent.
var assigned: bool = false:
	set(value):
		if assigned == value:
			return
		assigned = value
		_redraw_chrome()

var _chip: MoveChip = null
## The configured move — kept for the peek card (and venue hit-testing).
var _move: Move = null
## Wall-clock ms when a genuine touch press started arming the hold-to-peek;
## -1 = not armed. Matured in _process against Settings.tooltip_hold_ms.
var _peek_hold_start_ms: int = -1
var _peek_open: bool = false
var _name_label: Label = null
var _uses_label: Label = null
var _icon: TextureRect = null
var _damage_icon: TextureRect = null
var _scheme_glyph: TargetSchemeGlyph = null
var _range_label: Label = null
var _element: Enums.ElementalType = Enums.ElementalType.NONE
var _base_fill: Color = Color.WHITE
var _base_empty: Color = Color.BLACK
# One shared halo for both number labels — same scheme, same color, so one
# material serves both (unlike the name's per-instance duplicate, nothing
# here ever varies per chip).
var _number_glow: ShaderMaterial = null
# The name's glow, held so a healthy re-setup can restore it after the
# disabled tier nulled it.
var _name_glow: ShaderMaterial = null


func _ready() -> void:
	super()
	# The chip body replaces both the flat background and the azure border.
	base_background = Color.TRANSPARENT
	text = ""
	# Overflow must never spill into neighboring panels (RQD bug 2026-07-19:
	# detail-panel chips appended their data over the description pane). What
	# to SHOW at narrow widths is the pending density decision; until then,
	# clip is the contract.
	clip_contents = true

	_chip = MoveChip.new()
	_chip.material = CHIP_MATERIAL.duplicate()
	_chip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.show_behind_parent = true
	_chip.radius_px = 2.0
	add_child(_chip)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_top = 2
	row.offset_right = -3
	row.offset_bottom = -2
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Seven children now — the default 4px separation no longer fits 120px.
	row.add_theme_constant_override("separation", 2)
	add_child(row)

	# Elemental type icon leads the row — same 10x10 set the action menu uses.
	_icon = TextureRect.new()
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)

	# Damage type (phys/spec/support) beside the element — Lawrence trial
	# 2026-07-19, revert clause: "if it's ugly we'll move it back".
	_damage_icon = TextureRect.new()
	_damage_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_damage_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_damage_icon)

	_name_label = Label.new()
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_glow = GLOW_MATERIAL.duplicate() as ShaderMaterial
	_name_glow.set_shader_parameter("glow_color", GameColors.TEXT_PRIMARY_GLOW)
	_name_label.material = _name_glow
	# Trim, NOT clip_text: scissor clipping also cut the glow halo at the
	# label's left/top edge (RQD bug 2026-07-19) — trimming reshapes the
	# text and leaves the halo intact.
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	var name_seat := _seat_label(_name_label)
	if show_scheme_and_range or show_uses:
		# Fixed column so the data columns to the right line up down the menu.
		_name_label.custom_minimum_size.x = name_column_width
	else:
		# Identity-only chips have nothing to align right of the name — a
		# fixed column would only truncate it (RQD 2026-07-19, "Uppercut").
		# The name takes the row; trim fires only on genuine overrun. The
		# EXPAND goes on the SEAT — it, not the label, is the row's child.
		name_seat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_seat)

	# Scheme + digits — target scheme glyph, then the range band. The spacer
	# after them is a DECISION, not layout convenience: range never sits
	# beside uses (two number pairs side by side misread — Lawrence review).
	_scheme_glyph = TargetSchemeGlyph.new()
	# The glyph's ramp shadow renders in the chip shader (it owns the
	# fill/empty boundary) — keep the mask rect synced to wherever layout
	# puts the glyph.
	_scheme_glyph.item_rect_changed.connect(_update_scheme_shadow)
	row.add_child(_scheme_glyph)

	# Numbers wear the name's font scheme — same color, same glyph glow — so
	# name, range, and uses read as one family (RQD 2026-07-19, mocked in the
	# HTML first; judged at real scale here).
	_number_glow = GLOW_MATERIAL.duplicate() as ShaderMaterial
	_number_glow.set_shader_parameter("glow_color", GameColors.TEXT_PRIMARY_GLOW)

	_range_label = Label.new()
	# Range as a 5px annotation, not an 8px stat (LOCKED, RQD 2026-07-19 —
	# "way better than expected"): the size split keeps it from pairing with
	# uses' digits. Bottom-aligned so the small line shares the big labels'
	# bottom edge at integer positions (centering 5 in 8 lands on half-pixels).
	_range_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	if UIManager.font_5px != null:
		_range_label.add_theme_font_override("font", UIManager.font_5px)
		_range_label.add_theme_font_size_override("font_size", 5)
	_range_label.material = _number_glow
	row.add_child(_seat_label(_range_label))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Its only job is pushing uses to the right edge — without uses it would
	# just steal the slack an expanding name needs.
	spacer.visible = show_uses
	row.add_child(spacer)

	_uses_label = Label.new()
	_uses_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_uses_label.material = _number_glow
	row.add_child(_seat_label(_uses_label))

	# Venue field set — hidden nodes drop out of the HBox entirely.
	_scheme_glyph.visible = show_scheme_and_range
	_range_label.visible = show_scheme_and_range
	_uses_label.visible = show_uses

	# Brackets/rings/press-flash draw above the chip body and its labels.
	move_child(_chrome_front, get_child_count() - 1)

	# A finger dragging off the chip abandons both the arming hold and an open
	# peek — release-elsewhere must not leave a card orphaned.
	mouse_exited.connect(_on_peek_pointer_exited)


## Configure from a Move. `locked` = sealed by Void Lock (uses stay visible —
## the lock took the move, not the PP); depletion is read off the Move itself.
## Re-runnable: panels reuse chips across units/refreshes, so the disabled
## tier fully resets before being re-derived from the new move.
func setup(move: Move, is_assigned: bool = false, locked: bool = false) -> void:
	# A re-setup means the data changed — an open card would be showing stale
	# numbers, so it closes rather than lie.
	_close_peek()
	_move = move
	disabled = false
	disabled_reason = ""
	_name_label.material = _name_glow
	_name_label.remove_theme_color_override("font_color")
	VoidLockOverlay.set_locked(_chip, false)

	_element = move.element_type
	_base_fill = GameColors.get_move_chip_foreground(move.element_type)
	_base_empty = GameColors.get_move_chip_background(move.element_type)
	_chip.border_color = GameColorPalette.get_color("Gray", 7)
	_chip.fill_percent = float(move.current_uses) / float(move.max_uses) \
			if move.max_uses > 0 else 0.0
	_update_scheme_shadow()
	if prefer_full_name and move.move_name != "":
		_name_label.text = move.move_name
	else:
		_name_label.text = move.abbrev_name if move.abbrev_name != "" else move.move_name
	# Text wears the ELEMENT's designed pairing (GameColors §3 chip colors) —
	# default white on some bodies was unreadable (RQD 2026-07-19). Numbers
	# follow the name's scheme, so they take the same pair.
	var chip_text_color: Color = GameColors.get_move_chip_font_color(move.element_type)
	var chip_glow_color: Color = GameColors.get_move_chip_glow_color(move.element_type)
	_name_label.add_theme_color_override("font_color", chip_text_color)
	_name_glow.set_shader_parameter("glow_color", chip_glow_color)
	_number_glow.set_shader_parameter("glow_color", chip_glow_color)
	_uses_label.text = "%d/%d" % [move.current_uses, move.max_uses]
	_icon.texture = elemental_icon(move.element_type)
	_icon.material = null
	_damage_icon.texture = damage_type_icon(move.damage_type)
	_damage_icon.material = null
	_scheme_glyph.blast = move.target_type == Enums.TargetType.AOE \
			or move.area_of_effect > 0
	_scheme_glyph.glyph_color = GameColors.SCHEME_FRIENDLY \
			if move.targets_allies() or move.target_type == Enums.TargetType.SELF \
			else GameColors.SCHEME_HOSTILE
	_range_label.text = range_text(move)
	assigned = is_assigned

	var depleted: bool = not move.has_uses_remaining()
	if depleted or locked:
		disabled = true
		disabled_reason = "SEALED BY VOID LOCK" if locked else "NO USES REMAINING"
		_base_fill = Color(0.15, 0.15, 0.15, 1.0)
		_base_empty = Color(0.08, 0.08, 0.08, 1.0)
		_chip.border_color = GameColors.INTERACTIVE_BORDER_DISABLED
		_name_label.material = null
		_name_label.add_theme_color_override(
				"font_color", GameColors.INTERACTIVE_TEXT_DISABLED)
		# Icons follow the tier: greyed whenever the chip is dark.
		_icon.material = VoidLockOverlay.icon_gray_material()
		_damage_icon.material = VoidLockOverlay.icon_gray_material()
		_scheme_glyph.glyph_color = GameColors.INTERACTIVE_TEXT_DISABLED
	if locked:
		# Subdued (bubbles only) — the tight menu can't spill the smoke/crackle.
		VoidLockOverlay.set_locked(_chip, true, true)

	_chip.fill_color = _base_fill
	_chip.empty_color = _base_empty
	# Chrome state (incl. the shader's shadow pair) must land NOW, not on the
	# first hover — the assigned setter only redraws on change.
	_redraw_chrome()
	# Numbers follow the name exactly: default white + halo when healthy,
	# halo killed + tier grey when dark. Both directions, so re-setup works.
	if disabled:
		_uses_label.material = null
		_range_label.material = null
		_uses_label.add_theme_color_override(
				"font_color", GameColors.INTERACTIVE_TEXT_DISABLED)
		_range_label.add_theme_color_override(
				"font_color", GameColors.INTERACTIVE_TEXT_DISABLED)
	else:
		_uses_label.material = _number_glow
		_range_label.material = _number_glow
		_uses_label.add_theme_color_override("font_color",
				GameColors.get_move_chip_font_color(_element))
		_range_label.add_theme_color_override("font_color",
				GameColors.get_move_chip_font_color(_element))


## The shared 10x10 elemental icon set (also used by the action menu).
## Null for NONE or a missing sprite — the row just shows no icon.
static func elemental_icon(element_type: Enums.ElementalType) -> Texture2D:
	if element_type == Enums.ElementalType.NONE:
		return null
	var type_name: String = Enums.elemental_type_to_string(element_type).to_lower()
	var path: String = "res://art/sprites/ui/elemental_type_icons_10x10/%s.png" % type_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## Wraps a text label in the GlowLabel prefab's margin seat (2px top) so chip
## text sits at the same optical height as every panel label.
static func _seat_label(label: Label) -> MarginContainer:
	var seat := MarginContainer.new()
	seat.add_theme_constant_override("margin_top", TEXT_TOP_MARGIN)
	seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seat.add_child(label)
	return seat


## Non-interactive display contexts (unit preview): the chip skin and data
## still communicate, but nothing hovers, focuses, or presses — so the lit
## contract isn't violated by an unpressable chip. MOUSE_FILTER_IGNORE is
## LOAD-BEARING beyond that: mouse events fall through to the map tiles
## underneath, whose hover flips the info panel to the other side — the
## M&K/controller displacement behavior. Touch hold-to-peek in these venues
## is watched by the PANEL (UnitPreviewPanel._input), not by the chip.
func make_display_only() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


## The move this chip was last setup() with — display venues use it to feed
## the panel-level touch peek. Null before the first setup.
func get_move() -> Move:
	return _move


## The digits half of "scheme + digits": targeting is dist <= attack_range
## with an implied minimum of 1, so the band reads "1-N" ("1" at melee).
## The data model has no min range yet — when it grows one, teach it here.
static func range_text(move: Move) -> String:
	if move.attack_range <= 0:
		return ""
	if move.attack_range == 1:
		return "1"
	return "1-%d" % move.attack_range


## The shared 10x10 damage-type icon set (physical / special_d / support) —
## the same sprites the detail panel, equipment picker, and combat preview use.
static func damage_type_icon(damage_type: Enums.DamageType) -> Texture2D:
	var path: String = Enums.get_damage_type_icon(damage_type)
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


# =============================================================================
# Hold-to-peek (MoveTooltip) — one gesture verb on every input: HOLD to
# inspect, release to dismiss (ui-style-guide.md §14 "Detail tooltips").
#   touch      — long press (Settings.tooltip_hold_ms); maturing the hold
#                CANCELS the in-flight button press, so releasing after a peek
#                never casts the move (the not-confuse-the-player rule).
#   M&K        — hold right click. A real mouse left-hold never peeks: desktop
#                clicks have no tap/hold ambiguity, and a slow click must stay
#                a click.
#   controller — hold Back/R3 ("tooltip_peek") while focus is on the chip
#                (focused Controls receive joypad events through gui_input).
# Works on DISABLED chips too — a depleted move's details are exactly what a
# player wants to read. Quick tap on one still denies; the hold peeks.
# =============================================================================

func _gui_input(event: InputEvent) -> void:
	if _handle_peek_input(event):
		accept_event()
		return
	super(event)


## The peek gesture logic, accept_event-free so tests can drive it directly.
## Returns true when the event belonged to the peek (and must be consumed).
func _handle_peek_input(event: InputEvent) -> bool:
	if not peek_enabled or _move == null:
		return false
	if event.is_action_pressed("tooltip_peek"):
		_open_peek()
		return true
	if event.is_action_released("tooltip_peek"):
		_close_peek()
		return true
	var mouse := event as InputEventMouseButton
	if mouse == null:
		return false
	if mouse.button_index == MOUSE_BUTTON_RIGHT:
		if mouse.pressed:
			_open_peek()
		else:
			_close_peek()
		return true
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return false
	if mouse.pressed:
		# Genuine touch only (see MoveTooltip.is_touch_pointer). The press
		# itself still presses — the chip giving press feedback DURING the
		# hold is correct; the cancel happens only if the hold matures.
		if MoveTooltip.is_touch_pointer(mouse):
			_peek_hold_start_ms = Time.get_ticks_msec()
		return false
	# Left release: a matured peek swallows it — peeking must never cast.
	_peek_hold_start_ms = -1
	if _peek_open:
		_close_peek()
		return true
	return false


func _process(delta: float) -> void:
	super(delta)
	if _peek_hold_start_ms >= 0 and \
			Time.get_ticks_msec() - _peek_hold_start_ms >= Settings.tooltip_hold_ms:
		_peek_hold_start_ms = -1
		_cancel_press_attempt()
		_open_peek()


func _exit_tree() -> void:
	super()
	_close_peek()


func _notification(what: int) -> void:
	# A chip hidden mid-peek (menu closing via visible = false) takes its card
	# down — otherwise the card floats over whatever replaced the menu.
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_close_peek()


func _open_peek() -> void:
	if _peek_open or _move == null:
		return
	_peek_open = true
	MoveTooltip.show_for(self, _move)


func _close_peek() -> void:
	_peek_hold_start_ms = -1
	if not _peek_open:
		return
	_peek_open = false
	MoveTooltip.dismiss_for(self)


func _on_peek_pointer_exited() -> void:
	_close_peek()


## Forget the in-flight press so releasing after a peek doesn't cast the move.
## Flipping `disabled` is the one public lever that clears BaseButton's
## internal press_attempt (non-toggle buttons expose no direct reset); the
## flip happens within one call, so InteractiveButton's disabled watcher in
## _process never sees an edge.
func _cancel_press_attempt() -> void:
	if disabled:
		return
	disabled = true
	disabled = false
	# is_pressed() just went false — unshift the body and chrome now.
	_redraw_chrome()


# =============================================================================
# Vocabulary overrides
# =============================================================================

## Behind-chrome draws nothing: the chip shader IS the body and the border.
## Front-chrome (brackets, rings, press flash) inherits.
func _draw_chrome(canvas: Control, behind: bool) -> void:
	if behind:
		return
	super._draw_chrome(canvas, behind)


func _brackets_visible() -> bool:
	return selected or assigned


func _brackets_snapping() -> bool:
	# Parked for the assigned move; the cursor landing here resumes the snap —
	# that IS "you are here".
	return selected


func _redraw_chrome() -> void:
	super()
	if _chip == null:
		return
	# Backlight, element-preserving: the pair climbs ONE step up its OWN
	# palette ramp (PoppyRed 5 → 6), both colors together so the usage
	# boundary keeps its contrast. On-ramp at rest and at full lift — the
	# lerp-toward-white version read as "slightly off" because it left the
	# ramp (RQD 2026-07-16). Disabled chips stay parked on their grey pair.
	if disabled:
		_chip.fill_color = _base_fill
		_chip.empty_color = _base_empty
	else:
		_chip.fill_color = GameColors.get_move_chip_foreground_lifted(_element, _backlight_level)
		_chip.empty_color = GameColors.get_move_chip_background_lifted(_element, _backlight_level)
	# The body rides the press shift with the rest of the chrome.
	var press_offset: float = float(PRESS_SHIFT_PIXELS) if is_pressed() else 0.0
	_chip.position.y = press_offset
	# Shadow pair follows the CURRENT body: down its ramp to ~30% luminance
	# (2 fill steps / 1 empty step — per-element depth in the GameColors ramp
	# table), lift-aware, darkened grey on the disabled tier (Lawrence
	# 2026-07-20; depth matched to the mockup's pop 2026-07-26).
	var chip_material := _chip.material as ShaderMaterial
	if chip_material != null:
		if disabled:
			chip_material.set_shader_parameter(
					"fill_shadow_color", _base_fill.darkened(0.4))
			chip_material.set_shader_parameter(
					"empty_shadow_color", _base_empty.darkened(0.4))
		else:
			chip_material.set_shader_parameter("fill_shadow_color",
					GameColors.get_move_chip_foreground_shadow(_element, _backlight_level))
			chip_material.set_shader_parameter("empty_shadow_color",
					GameColors.get_move_chip_background_shadow(_element, _backlight_level))
		_update_scheme_shadow()


## Syncs the chip shader's shadow mask to the glyph: same shape texture, so
## shape and shadow can never disagree; rect from live layout positions, so
## it tracks the press shift and any reflow.
func _update_scheme_shadow() -> void:
	if _chip == null or _scheme_glyph == null or not is_inside_tree():
		return
	var chip_material := _chip.material as ShaderMaterial
	if chip_material == null:
		return
	var enabled: bool = _scheme_glyph.visible
	chip_material.set_shader_parameter("scheme_shadow_enabled", enabled)
	if not enabled:
		return
	var mask: ImageTexture = TargetSchemeGlyph.shape_texture(_scheme_glyph.blast)
	chip_material.set_shader_parameter("scheme_shadow_mask", mask)
	var pad := Vector2(TargetSchemeGlyph.PAD, TargetSchemeGlyph.PAD)
	var rect_position: Vector2 = _scheme_glyph.global_position \
			- _chip.global_position - pad + TargetSchemeGlyph.SHADOW_OFFSET
	chip_material.set_shader_parameter("scheme_shadow_rect",
			Vector4(rect_position.x, rect_position.y,
					mask.get_width(), mask.get_height()))
