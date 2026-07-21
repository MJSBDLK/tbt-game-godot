## The hold-to-peek move detail card (ui-style-guide.md §14 "Detail tooltips" —
## CORE input decision, RQD 2026-07-19). One gesture verb on every input:
## HOLD to inspect, release to dismiss. Long press (touch, delay =
## Settings.tooltip_hold_ms) = hold right click (M&K) = hold Back/R3 on the
## focused chip (controller). The card is the detail panel's move pane in
## tooltip form — full name in the element's chip text scheme, PWR/ACC/RNG/
## USES, the targeting scheme in words, secondary effect, description — so a
## chip's compressed glyphs are always one hold away from their explanation.
##
## One card on screen at a time; opening one dismisses any DenyTooltip (and
## vice versa) so the two never stack over a chip. Same family as DenyTooltip:
## game_theme TooltipPanel + GlowLabels.
##
## The card is added to the source's VIEWPORT, not the source: chips clip
## their contents, and canvas clipping applies to child canvas items even when
## they're top_level — a chip-parented card would render 14px tall. Lifetime
## is tied back to the source explicitly (tree_exiting), and the venues close
## their own peeks on hide.
class_name MoveTooltip
extends RefCounted


const GAME_THEME: Theme = preload("res://resources/game_theme.tres")
const FONT_8PX: FontFile = preload("res://fonts/UndeadPixelLight8.ttf")
const GLOW_MATERIAL: ShaderMaterial = preload("res://resources/hud_glow.tres")

## Description wrap width — sized to the 140px side columns the chips live in.
const CARD_WIDTH: float = 132.0
## Breathing room between the card and the source / the canvas edges.
const MARGIN_PIXELS: float = 2.0

static var _active: PanelContainer = null
static var _active_source: Control = null


## Open the card for `move` just above `source` (below if there's no room).
## Replaces any open card; the caller owns closing it (release / focus loss).
static func show_for(source: Control, move: Move) -> void:
	if source == null or move == null or not source.is_inside_tree():
		return
	dismiss()
	DenyTooltip.dismiss()

	var card := _build_card(move)
	source.get_viewport().add_child(card)
	_active = card
	_active_source = source
	if not source.tree_exiting.is_connected(dismiss_for):
		source.tree_exiting.connect(dismiss_for.bind(source))

	# Size lands a frame later; then seat the card beside its chip.
	await source.get_tree().process_frame
	if not is_instance_valid(card) or not is_instance_valid(source):
		return
	_place_beside(card, source)


static func dismiss() -> void:
	if _active != null and is_instance_valid(_active):
		_active.queue_free()
	_active = null
	_active_source = null


## Dismiss only if `source` owns the open card — a chip closing its own peek
## must never tear down a newer card another chip just opened.
static func dismiss_for(source: Control) -> void:
	if _active_source == source:
		dismiss()


static func is_open_for(source: Control) -> bool:
	return _active != null and is_instance_valid(_active) and _active_source == source


## Genuine-touch test for the long-press trigger. In this pipeline touch
## reaches the HUD as the EMULATED mouse press (InputRouter remaps only mouse
## events into HUD coords), so the emulation device id IS the touch signal.
## A real mouse must never long-press-peek: desktop clicks have no tap/hold
## ambiguity, and a slow click must stay a click (right click peeks instead).
static func is_touch_pointer(event: InputEvent) -> bool:
	return event.device == InputEvent.DEVICE_ID_EMULATION


# =============================================================================
# CARD CONSTRUCTION
# =============================================================================

static func _build_card(move: Move) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme = GAME_THEME
	card.theme_type_variation = "TooltipPanel"
	# The card must never eat the hold's own release (or anything else).
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	# Header: element + damage-type icons, then the FULL name in the element's
	# chip text scheme — the card answers what the truncated chip couldn't.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	var element_icon := TextureRect.new()
	element_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	element_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	element_icon.texture = MoveChipButton.elemental_icon(move.element_type)
	header.add_child(element_icon)
	var damage_icon := TextureRect.new()
	damage_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	damage_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_icon.texture = MoveChipButton.damage_type_icon(move.damage_type)
	header.add_child(damage_icon)
	header.add_child(_make_label(move.move_name.to_upper(),
			GameColors.get_move_chip_font_color(move.element_type),
			GameColors.get_move_chip_glow_color(move.element_type)))

	# Stat grid: PWR/ACC/RNG/USES — same values, same formats as the detail
	# panel's move pane (this card IS that pane in tooltip form). Labels in
	# the mini 5px font, values in 8px — the chip's own size split.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 0)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(grid)
	_add_stat(grid, "PWR", "%d" % move.base_power if move.base_power > 0 else "--")
	_add_stat(grid, "ACC", "%d%%" % move.accuracy)
	var range_band: String = MoveChipButton.range_text(move)
	_add_stat(grid, "RNG", range_band if range_band != "" else "--")
	_add_stat(grid, "USES", "%d/%d" % [move.current_uses, move.max_uses])

	# The targeting scheme, in words — the glyph spelled out (Lawrence review
	# 2026-07-19: basic schemes carry new-player value; the card is the lesson).
	column.add_child(_make_label(_targeting_text(move),
			GameColors.TEXT_SECONDARY, GameColors.TEXT_SECONDARY_GLOW))

	# Secondary effect ("30% BURN"), only when the move has one.
	if move.status_effect_type != Enums.StatusEffectType.NONE:
		var effect_name: String = Enums.StatusEffectType.keys()[move.status_effect_type]
		column.add_child(_make_label(
				"%d%% %s" % [roundi(move.status_effect_chance * 100.0), effect_name],
				GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW))

	if not move.description.is_empty():
		var description := _make_label(move.description,
				GameColors.TEXT_SECONDARY, GameColors.TEXT_SECONDARY_GLOW)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size = Vector2(CARD_WIDTH, 0)
		column.add_child(description)

	return card


## Above the source, clamped inside the canvas; below when the top is tight.
## Integer position — the card rides the pixel grid like everything else.
static func _place_beside(card: PanelContainer, source: Control) -> void:
	var bounds: Rect2 = source.get_viewport().get_visible_rect()
	var rect := source.get_global_rect()
	var x: float = clampf(rect.position.x + (rect.size.x - card.size.x) / 2.0,
			bounds.position.x + MARGIN_PIXELS,
			bounds.end.x - card.size.x - MARGIN_PIXELS)
	var y: float = rect.position.y - card.size.y - MARGIN_PIXELS
	if y < bounds.position.y + MARGIN_PIXELS:
		y = rect.end.y + MARGIN_PIXELS
	card.position = Vector2(x, y).floor()


static func _add_stat(grid: GridContainer, stat_name: String, value: String) -> void:
	var name_label := _make_label(stat_name,
			GameColors.TEXT_SECONDARY, GameColors.TEXT_SECONDARY_GLOW)
	if UIManager.font_5px != null:
		name_label.add_theme_font_override("font", UIManager.font_5px)
		name_label.add_theme_font_size_override("font_size", 5)
	# Small line shares the big values' bottom edge (same rule as chip range).
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	grid.add_child(name_label)
	grid.add_child(_make_label(value,
			GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW))


static func _targeting_text(move: Move) -> String:
	var who: String
	match move.target_type:
		Enums.TargetType.SELF:
			who = "SELF"
		Enums.TargetType.ALLY:
			who = "ALLIES"
		Enums.TargetType.ALLY_NOT_SELF:
			who = "OTHER ALLIES"
		_:
			who = "ENEMIES"
	var blast: bool = move.target_type == Enums.TargetType.AOE \
			or move.area_of_effect > 0
	var shape: String = "BLAST" if blast else "SINGLE TARGET"
	return "%s - %s" % [shape, who]


static func _make_label(label_text: String, font_color: Color, glow: Color) -> GlowLabel:
	var label := GlowLabel.new()
	label.text = label_text
	label.theme_type_variation = "TooltipLabel"
	label.add_theme_color_override("font_color", font_color)
	label.material = GLOW_MATERIAL.duplicate()
	label.glow_color = glow
	label.add_theme_font_override("font", FONT_8PX)
	label.add_theme_font_size_override("font_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
