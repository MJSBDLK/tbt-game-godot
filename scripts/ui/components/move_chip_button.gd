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

## Why pressing is currently refused — surfaced by deny UI (styled tooltip).
var disabled_reason: String = ""

## This move is the unit's assigned move: parked brackets, persistent.
var assigned: bool = false:
	set(value):
		if assigned == value:
			return
		assigned = value
		_redraw_chrome()

var _chip: MoveChip = null
var _name_label: Label = null
var _uses_label: Label = null
var _element: Enums.ElementalType = Enums.ElementalType.NONE
var _base_fill: Color = Color.WHITE
var _base_empty: Color = Color.BLACK


func _ready() -> void:
	super()
	# The chip body replaces both the flat background and the azure border.
	base_background = Color.TRANSPARENT
	text = ""

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
	add_child(row)

	_name_label = Label.new()
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.material = GLOW_MATERIAL.duplicate()
	(_name_label.material as ShaderMaterial).set_shader_parameter(
			"glow_color", GameColors.TEXT_PRIMARY_GLOW)
	row.add_child(_name_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	_uses_label = Label.new()
	_uses_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_uses_label)

	# Brackets/rings/press-flash draw above the chip body and its labels.
	move_child(_chrome_front, get_child_count() - 1)


## Configure from a Move. `locked` = sealed by Void Lock (uses stay visible —
## the lock took the move, not the PP); depletion is read off the Move itself.
func setup(move: Move, is_assigned: bool = false, locked: bool = false) -> void:
	_element = move.element_type
	_base_fill = GameColors.get_move_chip_foreground(move.element_type)
	_base_empty = GameColors.get_move_chip_background(move.element_type)
	_chip.border_color = GameColorPalette.get_color("Gray", 7)
	_chip.fill_percent = float(move.current_uses) / float(move.max_uses) \
			if move.max_uses > 0 else 0.0
	_name_label.text = move.abbrev_name if move.abbrev_name != "" else move.move_name
	_uses_label.text = "%d/%d" % [move.current_uses, move.max_uses]
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
	if locked:
		# Subdued (bubbles only) — the tight menu can't spill the smoke/crackle.
		VoidLockOverlay.set_locked(_chip, true, true)

	_chip.fill_color = _base_fill
	_chip.empty_color = _base_empty
	_uses_label.add_theme_color_override("font_color",
			GameColors.INTERACTIVE_TEXT_DISABLED if disabled else GameColors.TEXT_PRIMARY_GLOW)


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
