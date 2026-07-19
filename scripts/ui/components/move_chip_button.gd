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
	_name_label.material = GLOW_MATERIAL.duplicate()
	(_name_label.material as ShaderMaterial).set_shader_parameter(
			"glow_color", GameColors.TEXT_PRIMARY_GLOW)
	# Fixed column: with clip_text on, the text no longer drives the minimum
	# width, so every chip's scheme/range columns line up.
	_name_label.clip_text = true
	_name_label.custom_minimum_size.x = NAME_COLUMN_WIDTH
	row.add_child(_name_label)

	# Scheme + digits — target scheme glyph, then the range band. The spacer
	# after them is a DECISION, not layout convenience: range never sits
	# beside uses (two number pairs side by side misread — Lawrence review).
	_scheme_glyph = TargetSchemeGlyph.new()
	row.add_child(_scheme_glyph)

	# Numbers wear the name's font scheme — same color, same glyph glow — so
	# name, range, and uses read as one family (RQD 2026-07-19, mocked in the
	# HTML first; judged at real scale here).
	_number_glow = GLOW_MATERIAL.duplicate() as ShaderMaterial
	_number_glow.set_shader_parameter("glow_color", GameColors.TEXT_PRIMARY_GLOW)

	_range_label = Label.new()
	_range_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_range_label.material = _number_glow
	row.add_child(_range_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	_uses_label = Label.new()
	_uses_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_uses_label.material = _number_glow
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
		_uses_label.remove_theme_color_override("font_color")
		_range_label.remove_theme_color_override("font_color")


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
