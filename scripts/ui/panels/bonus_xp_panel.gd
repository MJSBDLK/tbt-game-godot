## Between-mission bonus-XP allocation screen.
##
## SCOPE — functional scaffolding only. Per [[feedback-ui-scope-order]] this
## lands functionality-first so the user can mock up the stylized version on
## top, with Lawrence doing final polish. Anything cosmetic (colors, layout
## proportions, animation curves, sound stubs) is a placeholder.
##
## Why this screen exists ([[mission_objectives.md]]):
##   bEXP rewards objectives, not kills — so the meta-incentive ("finish the
##   objective fast") doesn't fight the in-moment incentive ("grind kills for
##   XP"). This screen is where the player spends the accumulated pool to top
##   up under-leveled units between fights.
##
## DATA CONTRACT — receives the same Array as BattleResultPanel via
## show_report() so it can render alongside the survivors. The screen
## doesn't NEED the report (the active roster is the source of truth), but
## taking it as input keeps the UIManager chain consistent — every step in
## the post-mission flow accepts the same payload.
##
## EMITS `closed` when the user clicks Continue — UIManager then finishes the
## post-mission flow (state pop + campaign conclude). If the pool is zero at
## entry time, the screen self-skips (emits closed immediately).
class_name BonusXpPanel
extends Control


signal closed


## SPEND MODEL (flattened 2026-08-05): a level costs a flat 100 bEXP for
## everyone, forever — SquadManager.BEXP_LEVEL_COST. There is no price tag to
## read and no scaling to reverse-engineer; the pool total IS the readout, and
## "pool / 100" is how many levels you can hand out.
##
## The previous level-scaled price was removed on purpose. Catch-up lives
## entirely in the combat award now, so a second rubber band here would be a
## rule the player can't see. See SquadManager's BEXP_LEVEL_COST comment.

## Stats displayed in the capped-stat strip on each row. Order matches the
## character sheet (HP first, defensive stats last) so the visual layout
## maps to player expectations.
const _STAT_STRIP: Array = [
	["HP",  "max_hp"],
	["STR", "strength"],
	["SPC", "special"],
	["SKL", "skill"],
	["AGL", "agility"],
	["ATH", "athleticism"],
	["DEF", "defense"],
	["RES", "resistance"],
]


# Per-row UI handles cached so we can refresh them when the pool or
# experience changes without rebuilding the entire screen.
# Keyed by character_id → Dictionary { level: Label, xp: Label, bar: ColorRect,
# bar_bg: ColorRect, buy_button: Button }.
var _rows: Dictionary = {}

var _pool_label: Label = null
var _income_label: Label = null
var _continue_button: Button = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_chrome()
	if SquadManager.bonus_xp_changed.is_connected(_on_pool_changed):
		return
	SquadManager.bonus_xp_changed.connect(_on_pool_changed)


# =============================================================================
# PUBLIC API
# =============================================================================

## Builds rows for every surviving (non-permadead) roster member and shows
## the screen. If the bonus pool is zero at entry time, skips immediately —
## there's nothing to spend, so no reason to interrupt the flow.
func show_report(report: Array) -> void:
	if SquadManager.bonus_xp_pool <= 0:
		closed.emit()
		return

	_rebuild_rows(report)
	_refresh_pool_label()
	_refresh_income_label()
	visible = true


# =============================================================================
# BUILD
# =============================================================================

func _build_chrome() -> void:
	var ui_manager: Node = UIManager

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.05, 0.06, 0.10, 0.92)
	add_child(background)

	# Outer card — sized similarly to LevelUpReportPanel for visual continuity
	# in the post-mission chain.
	var card := VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.anchor_left = 0.10
	card.anchor_right = 0.90
	card.anchor_top = 0.10
	card.anchor_bottom = 0.90
	card.add_theme_constant_override("separation", 6)
	add_child(card)

	# Title.
	var banner := Label.new()
	banner.text = "BONUS XP"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null:
		banner.add_theme_font_override("font", ui_manager.font_11px)
		banner.add_theme_font_size_override("font_size", 11)
	banner.modulate = GameColorPalette.get_color("Yellow", 7)
	card.add_child(banner)

	# Pool readout — total bEXP remaining.
	_pool_label = Label.new()
	_pool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null:
		_pool_label.add_theme_font_override("font", ui_manager.font_8px)
		_pool_label.add_theme_font_size_override("font_size", 8)
	card.add_child(_pool_label)

	# Itemized income from the mission just finished (mirrors the result
	# screen's bEXP section, compacted to one line). Empty when nothing was
	# earned — the pool alone tells the carry-forward story then.
	_income_label = Label.new()
	_income_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null:
		_income_label.add_theme_font_override("font", ui_manager.font_5px)
		_income_label.add_theme_font_size_override("font_size", 5)
	_income_label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	card.add_child(_income_label)

	# Rule explainers — surface the two mechanics players would otherwise
	# learn from a wiki: the fixed-growth bEXP level, and the catch-up pricing.
	var rule_label := Label.new()
	rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_label.text = "Each level grants exactly %d stat growths (capped stats excluded)" % \
			CharacterData.BEXP_GROWTHS_PER_LEVEL
	if ui_manager != null:
		rule_label.add_theme_font_override("font", ui_manager.font_5px)
		rule_label.add_theme_font_size_override("font_size", 5)
	rule_label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	card.add_child(rule_label)

	var pricing_label := Label.new()
	pricing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pricing_label.text = "Prices scale with level — catching up is cheap"
	if ui_manager != null:
		pricing_label.add_theme_font_override("font", ui_manager.font_5px)
		pricing_label.add_theme_font_size_override("font_size", 5)
	pricing_label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	card.add_child(pricing_label)

	# Scrollable rows — handles rosters bigger than the card height.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)

	var rows_box := VBoxContainer.new()
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 4)
	rows_box.name = "RowsBox"
	scroll.add_child(rows_box)

	# Footer Continue button. Doesn't enforce "spend everything" — leftover
	# bEXP carries to the next mission via SquadManager.bonus_xp_pool, which
	# is the FE-style design.
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	card.add_child(footer)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size = Vector2(80, 18)
	if ui_manager != null:
		_continue_button.add_theme_font_override("font", ui_manager.font_8px)
		_continue_button.add_theme_font_size_override("font_size", 8)
	_continue_button.pressed.connect(_on_continue_pressed)
	footer.add_child(_continue_button)


## Tears down any existing rows and rebuilds one per surviving roster member.
## Permadead characters are filtered out by `report.get("permadead")` rather
## than by querying the active roster — the report is the post-commit truth.
func _rebuild_rows(report: Array) -> void:
	var rows_box: VBoxContainer = find_child("RowsBox", true, false) as VBoxContainer
	if rows_box == null:
		return
	for child: Node in rows_box.get_children():
		child.queue_free()
	_rows.clear()

	for entry: Dictionary in report:
		if entry.get("permadead", false):
			continue
		var character_name: String = entry.get("character_name", "")
		var character_id: String = _resolve_character_id(character_name)
		var character: CharacterData = SquadManager.get_character_by_id(character_id) if character_id != "" else null
		if character == null:
			continue
		var row_handles: Dictionary = _build_row(rows_box, character)
		_rows[character.character_id] = row_handles


## Single row: portrait | name + level | XP bar + value | "+" button.
## Returns a dictionary of handles the refresh path uses to update text and
## bar widths without rebuilding the row.
func _build_row(parent: VBoxContainer, character: CharacterData) -> Dictionary:
	var ui_manager: Node = UIManager

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	# Portrait — same crop logic as the roster rail's cards.
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(32, 32)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.texture = CharacterPortrait.get_sprite_crop_for(character)
	row.add_child(portrait)

	# Info column: name on top, XP bar + numbers below.
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	info.add_child(name_row)

	var name_label := Label.new()
	name_label.text = character.character_name
	if ui_manager != null:
		name_label.add_theme_font_override("font", ui_manager.font_8px)
		name_label.add_theme_font_size_override("font_size", 8)
	name_row.add_child(name_label)

	var level_label := Label.new()
	if ui_manager != null:
		level_label.add_theme_font_override("font", ui_manager.font_5px)
		level_label.add_theme_font_size_override("font_size", 5)
	level_label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	name_row.add_child(level_label)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 4)
	bar_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(bar_row)

	var bar_holder := Control.new()
	bar_holder.custom_minimum_size = Vector2(140, 6)
	bar_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(bar_holder)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.10, 0.10, 0.15, 1.0)
	bar_bg.size = Vector2(140, 6)
	bar_bg.position = Vector2.ZERO
	bar_holder.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.color = GameColorPalette.get_color("Yellow", 6)
	bar_fill.size = Vector2(0, 6)
	bar_fill.position = Vector2.ZERO
	bar_holder.add_child(bar_fill)

	var xp_label := Label.new()
	if ui_manager != null:
		xp_label.add_theme_font_override("font", ui_manager.font_5px)
		xp_label.add_theme_font_size_override("font_size", 5)
	xp_label.modulate = Color(1.0, 1.0, 1.0, 0.85)
	bar_row.add_child(xp_label)

	# Capped-stat strip — one tiny label per stat. Capped stats render in
	# yellow to call the player's attention to the "feel smart" optimization:
	# putting bEXP into a unit with capped stats concentrates the 3 growths
	# on the remaining ones. Indicators are stat_label nodes parallel to
	# _STAT_STRIP so _refresh_row can recolor them when caps change.
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 2)
	info.add_child(strip)

	var stat_labels: Array[Label] = []
	for spec: Array in _STAT_STRIP:
		var stat_label := Label.new()
		stat_label.text = spec[0]
		if ui_manager != null:
			stat_label.add_theme_font_override("font", ui_manager.font_5px)
			stat_label.add_theme_font_size_override("font_size", 5)
		stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(stat_label)
		stat_labels.append(stat_label)

	# Price-tag button — text is set per-refresh since the price can move
	# mid-screen (buying levels on the squad's top unit re-anchors everyone).
	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(64, 18)
	if ui_manager != null:
		buy_button.add_theme_font_override("font", ui_manager.font_8px)
		buy_button.add_theme_font_size_override("font_size", 8)
	buy_button.pressed.connect(_on_buy_pressed.bind(character.character_id))
	row.add_child(buy_button)

	var handles: Dictionary = {
		"character": character,
		"level": level_label,
		"xp": xp_label,
		"bar": bar_fill,
		"bar_bg": bar_bg,
		"buy_button": buy_button,
		"stat_labels": stat_labels,
	}
	_refresh_row(handles)
	return handles


# =============================================================================
# REFRESH
# =============================================================================

func _refresh_row(handles: Dictionary) -> void:
	var character: CharacterData = handles.get("character") as CharacterData
	if character == null:
		return
	# Flat 100 XP/level matches CharacterData.grant_xp's cascade and RD's
	# threshold convention. The action-side XP awards (CombatXpCalculator)
	# scale with level diff, not the threshold.
	var threshold: int = 100
	var ratio: float = clampf(float(character.experience) / float(threshold), 0.0, 1.0)
	(handles["level"] as Label).text = "Lv %d" % character.level
	(handles["xp"] as Label).text = "%d / %d" % [character.experience, threshold]
	var bar_bg: ColorRect = handles["bar_bg"] as ColorRect
	var bar: ColorRect = handles["bar"] as ColorRect
	bar.size.x = bar_bg.size.x * ratio
	# Flat cost for every unit, so affordability is a property of the pool, not
	# of the row — every button on screen enables and disables together.
	var cost: int = SquadManager.BEXP_LEVEL_COST
	var buy_button: Button = handles["buy_button"] as Button
	buy_button.text = "LV UP %d" % cost
	buy_button.disabled = SquadManager.bonus_xp_pool < cost
	buy_button.tooltip_text = "Buy one level for %d bEXP — the same for every unit" % cost
	# Refresh the capped-stat strip — caps can change between refreshes
	# when an allocation pushes a stat over the cap mid-screen.
	var stat_labels: Array = handles.get("stat_labels", [])
	for i: int in range(stat_labels.size()):
		var stat_label: Label = stat_labels[i] as Label
		var stat_name: String = _STAT_STRIP[i][1]
		if character.is_at_stat_cap(stat_name):
			stat_label.modulate = GameColorPalette.get_color("Yellow", 5)
			stat_label.tooltip_text = "%s is capped — bEXP growths will skip it" % _STAT_STRIP[i][0]
		else:
			stat_label.modulate = Color(1.0, 1.0, 1.0, 0.35)
			stat_label.tooltip_text = ""


func _refresh_pool_label() -> void:
	if _pool_label == null:
		return
	_pool_label.text = "Pool: %d bEXP" % SquadManager.bonus_xp_pool


## One-line mirror of the result screen's income section, so the player
## still sees where the money came from while deciding how to spend it.
func _refresh_income_label() -> void:
	if _income_label == null:
		return
	var lines: Array[Dictionary] = SquadManager.last_mission_award_lines
	if lines.is_empty():
		_income_label.text = ""
		_income_label.visible = false
		return
	var parts: Array[String] = []
	for award: Dictionary in lines:
		parts.append("%s +%d" % [str(award.get("label", "?")), int(award.get("amount", 0))])
	_income_label.text = "Earned this mission:  %s" % "  ·  ".join(parts)
	_income_label.visible = true


func _on_pool_changed(_new_pool: int) -> void:
	_refresh_pool_label()
	for handles: Dictionary in _rows.values():
		_refresh_row(handles)


# =============================================================================
# INTERACTION
# =============================================================================

func _on_buy_pressed(character_id: String) -> void:
	var character: CharacterData = SquadManager.get_character_by_id(character_id)
	if character == null:
		return
	# buy_bexp_level emits bonus_xp_changed, which triggers _on_pool_changed
	# above and refreshes every row's price tags and buttons — including
	# re-anchored prices if this purchase raised the squad's max level.
	SquadManager.buy_bexp_level(character)


func _on_continue_pressed() -> void:
	visible = false
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_on_continue_pressed()
		get_viewport().set_input_as_handled()


# =============================================================================
# UTILITIES
# =============================================================================

## Reverse-lookup mirrors LevelUpReportPanel's. The report ships display
## names; SquadManager keys by id. Walking active roster is fine — squads
## are tiny.
func _resolve_character_id(character_name: String) -> String:
	for character: CharacterData in SquadManager.get_active_roster():
		if character.character_name == character_name:
			return character.character_id
	return ""
