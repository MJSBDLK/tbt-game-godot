## The UNIT SHEET — middle column of Manage Units ([.claude/intermission.md]
## §3b, §3e). The selected unit's STATE, where every editable thing is a slot:
## ident, XP row, the stat block, move slots, passive slots, injury chips.
##
## The sheet never scrolls away and never changes shape. Clicking a slot
## SELECTS it (emitting `slot_selected` so the workbench can open the matching
## lane); clicking the open slot again deselects back to the unit summary.
## Injury selection deliberately does NOT survive switching units — injuries
## are personal; move/passive/stat selection does, so comparing loadouts
## across the squad is one click per unit (§3b).
##
## STAT ROWS (§3e, Radiant Dawn order): LABEL · GAUGE · NUMBER+tally · [−][+].
## The gauge is the shared StatCapBar (class track / global max). The number is
## the EFFECTIVE stat with the allocation tally riding it as `+` suffixes —
## `24++` says both what you have and how much of it you bought, which is what
## lets [−] exist: without the tally there's no telling refundable points from
## growth rolls. The [+]/[−] live HERE, on the row, so allocating never
## requires the workbench (§3d) — the workbench explains, the row changes.
##
## The XP row is display-only until slice 4 wires the bEXP lane into it.
class_name UnitSheet
extends PanelContainer


## A slot was selected (kind: "move" / "passive" / "stat" / "injury", key:
## slot index, stat property name, or injury index) — or deselected
## (kind "none"). The workbench is downstream of this signal.
signal slot_selected(kind: String, key: Variant)
## The sheet mutated the character (StatUp allocation). Rail badges and any
## open workbench lane want a refresh; the hub's save latch wants re-arming.
signal changed


## Display order + labels, the same convention StatFingerprint and the summary
## abbreviations teach. One row each, single column.
const STAT_ROWS: Array = [
	["max_hp", "HP"], ["strength", "STR"], ["special", "SPC"], ["skill", "SKL"],
	["agility", "AGL"], ["athleticism", "ATH"], ["defense", "DEF"], ["resistance", "RES"],
]

const MOVE_SLOT_COUNT: int = 4
## §8: the real count is class-schedule-dependent (1 or 2); rendering assumes
## 2 until that schedule exists.
const PASSIVE_SLOT_COUNT: int = 2
const CAP_BAR_HEIGHT: int = 3
const ICON_SIZE: int = 10
const ELEMENTAL_ICON_DIR: String = "res://art/sprites/ui/elemental_type_icons_10x10/"


var _character: CharacterData = null
var _sel_kind: String = "none"
var _sel_key: Variant = null

var _stack: VBoxContainer = null


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.HUD_PANEL_BACKGROUND
	style.border_color = GameColorPalette.get_color("Straw2", 3)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", 2)
	add_child(_stack)
	refresh()


# =============================================================================
# PURE COPY RULES
# =============================================================================

## `Spaceman · Lv 5` — the ident block's second line.
static func ident_sub_line(character: CharacterData) -> String:
	return "%s · Lv %d" % [
		Enums.get_class_display_name(character.current_class), character.level]


static func stat_label(stat_name: String) -> String:
	for entry: Array in STAT_ROWS:
		if entry[0] == stat_name:
			return entry[1]
	return stat_name


## Move.EMPTY is a real Move instance named "—" with move_id "empty", not a
## null — every slot-emptiness check has to go through here or the em-dash
## sentinel leaks into the UI as a move called "—".
static func is_empty_move(move: Move) -> bool:
	return move == null or move.move_id == "empty" or move.move_name == "" \
			or move.move_name == "—"


# =============================================================================
# PUBLIC API
# =============================================================================

func set_character(character: CharacterData) -> void:
	_character = character
	# Move/passive/stat selection survives a unit switch (compare loadouts in
	# one click per unit); an injury selection doesn't — it names a wound the
	# next unit doesn't have. Silent on purpose: the screen re-shows the
	# workbench lane deterministically after set_character, so an emit here
	# would race it with a half-updated screen.
	if _sel_kind == "injury":
		_sel_kind = "none"
		_sel_key = null
	refresh()


func get_selection_kind() -> String:
	return _sel_kind


func get_selection_key() -> Variant:
	return _sel_key


## Full rebuild. Cold path, small tree — rebuilding beats reconciling.
func refresh() -> void:
	if _stack == null:
		return
	for child: Node in _stack.get_children():
		child.queue_free()
	if _character == null:
		return
	_build_ident()
	_build_xp_row()
	_stack.add_child(_section_header("STATS"))
	for entry: Array in STAT_ROWS:
		_stack.add_child(_make_stat_row(str(entry[0]), str(entry[1])))
	_build_statup_pool_line()
	_stack.add_child(_section_header("MOVES"))
	_build_move_grid()
	_stack.add_child(_section_header("PASSIVES"))
	_build_passive_grid()
	_stack.add_child(_section_header("INJURIES"))
	_build_injury_row()


# =============================================================================
# SELECTION
# =============================================================================

func _pick(kind: String, key: Variant) -> void:
	# Clicking the open slot again closes it back to the unit summary.
	if kind == _sel_kind and key == _sel_key:
		_set_selection("none", null)
	else:
		_set_selection(kind, key)
	refresh()


func _set_selection(kind: String, key: Variant) -> void:
	_sel_kind = kind
	_sel_key = key
	slot_selected.emit(_sel_kind, _sel_key)


func _is_selected(kind: String, key: Variant) -> bool:
	return _sel_kind == kind and _sel_key == key


# =============================================================================
# IDENT + XP
# =============================================================================

func _build_ident() -> void:
	var ident := HBoxContainer.new()
	ident.add_theme_constant_override("separation", 6)
	var margin := _margins(5, 5, 5, 0)
	margin.add_child(ident)
	_stack.add_child(margin)

	var portrait := TextureRect.new()
	portrait.texture = CharacterPortrait.get_sprite_crop_for(_character)
	portrait.custom_minimum_size = Vector2(32, 32)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ident.add_child(portrait)

	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 1)
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	ident.add_child(who)

	var name_label := Label.new()
	name_label.text = _character.character_name
	if UIManager.font_11px != null:
		name_label.add_theme_font_override("font", UIManager.font_11px)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", GameColorPalette.get_color("Azure", 9))
	who.add_child(name_label)

	var sub_label := Label.new()
	sub_label.text = ident_sub_line(_character)
	_style_dim(sub_label)
	who.add_child(sub_label)

	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 2)
	_add_type_icon(type_row, _character.primary_type)
	_add_type_icon(type_row, _character.secondary_type)
	who.add_child(type_row)


## Display-only until slice 4: the current XP toward the next level. The gold
## matches the pool in the top bar — the tell that this number is where bEXP
## will land.
func _build_xp_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var margin := _margins(5, 5, 2, 2)
	margin.add_child(row)
	_stack.add_child(margin)

	var key_label := Label.new()
	key_label.text = "XP"
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_dim(key_label)
	row.add_child(key_label)

	var track := Control.new()
	track.custom_minimum_size = Vector2(0, 4)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track_bg := ColorRect.new()
	track_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	track_bg.color = GameColors.with_alpha(GameColorPalette.get_color("Gray", 0), 0.8)
	track.add_child(track_bg)
	var fill := ColorRect.new()
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = clampf(_character.experience / 100.0, 0.0, 1.0)
	fill.color = GameColors.TEXT_INFO
	track.add_child(fill)
	row.add_child(track)

	var price := Label.new()
	price.text = "%d/100" % _character.experience
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if UIManager.font_8px != null:
		price.add_theme_font_override("font", UIManager.font_8px)
	price.add_theme_font_size_override("font_size", 8)
	price.add_theme_color_override("font_color", GameColors.TEXT_INFO)
	row.add_child(price)


# =============================================================================
# STAT ROWS — §3e
# =============================================================================

func _make_stat_row(stat_name: String, abbrev: String) -> Button:
	var points: int = _character.get_allocated_points(stat_name)
	var level_value: int = _character.get_base_plus_growth(stat_name)
	var capped: bool = level_value >= _character.get_stat_cap(stat_name)
	var remaining: int = _character.available_stat_ups - _character.allocated_total()

	var row := _slot_button(_is_selected("stat", stat_name))
	row.custom_minimum_size = Vector2(0, 13)
	row.pressed.connect(_pick.bind("stat", stat_name))

	var content := HBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 4
	content.offset_right = -4
	content.add_theme_constant_override("separation", 4)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)

	var label := Label.new()
	label.text = abbrev
	label.custom_minimum_size = Vector2(20, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_dim(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)

	# The gauge — class-cap track against the global ceiling, the same
	# component every other stat surface draws. PASS mouse filter: its tooltip
	# works while clicks fall through to the row.
	var cap_bar := StatCapBar.new(stat_name, CAP_BAR_HEIGHT)
	cap_bar.custom_minimum_size = Vector2(40, CAP_BAR_HEIGHT)
	cap_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap_bar.set_character(_character)
	cap_bar.tooltip_text = _cap_tooltip(stat_name, abbrev, level_value, capped)
	content.add_child(cap_bar)

	# `24++` — effective number, allocation tally as suffix. Green at the
	# class ceiling (the shiny-capped-stat convention). The tally is capped at
	# PER_STAT_CAP = 4 so the suffix can never blow the row width.
	var value := RichTextLabel.new()
	value.bbcode_enabled = true
	value.fit_content = true
	value.scroll_active = false
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.custom_minimum_size = Vector2(28, 0)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if UIManager.font_8px != null:
		value.add_theme_font_override("normal_font", UIManager.font_8px)
	value.add_theme_font_size_override("normal_font_size", 8)
	var number_hex: String = (GameColors.TEXT_SUCCESS if capped
			else GameColors.TEXT_PRIMARY).to_html(false)
	var tally_hex: String = GameColorPalette.get_color("Yellow", 5).to_html(false)
	value.text = "[color=#%s]%d[/color][color=#%s]%s[/color]" % [
			number_hex, _character.get(stat_name), tally_hex, "+".repeat(points)]
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(value)

	content.add_child(_make_alloc_button("−", points > 0,
			"refund a StatUp (−10%% %s)" % abbrev if points > 0 else "nothing allocated here",
			_on_stat_decrement.bind(stat_name)))
	var can_add: bool = remaining > 0 and points < StatAllocation.PER_STAT_CAP
	var plus_tip: String = "spend a StatUp (+10%% %s, %d max)" % [abbrev, StatAllocation.PER_STAT_CAP]
	if points >= StatAllocation.PER_STAT_CAP:
		plus_tip = "%d points is the per-stat cap" % StatAllocation.PER_STAT_CAP
	elif remaining <= 0:
		plus_tip = "no StatUp to spend"
	content.add_child(_make_alloc_button("+", can_add, plus_tip,
			_on_stat_increment.bind(stat_name)))
	return row


func _cap_tooltip(stat_name: String, abbrev: String, level_value: int, capped: bool) -> String:
	var cap: int = _character.get_stat_cap(stat_name)
	var class_text: String = Enums.get_class_display_name(_character.current_class)
	if capped:
		return "%s is at the %s cap of %d — growths skip it, so bEXP levels concentrate elsewhere" % [
				abbrev, class_text, cap]
	return "%d of %d (%s cap) · game max %d" % [
			level_value, cap, class_text, _character.get_global_stat_cap(stat_name)]


## The [−]/[+] pair. A child Button inside the row button — its clicks are
## consumed here and never bubble into slot selection.
func _make_alloc_button(glyph: String, enabled: bool, tip: String,
		handler: Callable) -> Button:
	var button := Button.new()
	button.text = glyph
	button.custom_minimum_size = Vector2(12, 12)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.disabled = not enabled
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	if UIManager.font_8px != null:
		button.add_theme_font_override("font", UIManager.font_8px)
	button.add_theme_font_size_override("font_size", 8)
	button.pressed.connect(handler)
	return button


func _on_stat_increment(stat_name: String) -> void:
	var points: int = _character.get_allocated_points(stat_name)
	if points >= StatAllocation.PER_STAT_CAP:
		return
	if _character.allocated_total() >= _character.available_stat_ups:
		return
	# No stat-cap gate, on purpose: StatUps may exceed the class ceiling.
	_character.set_allocated_points(stat_name, points + 1)
	refresh()
	changed.emit()


func _on_stat_decrement(stat_name: String) -> void:
	var points: int = _character.get_allocated_points(stat_name)
	if points <= 0:
		return
	_character.set_allocated_points(stat_name, points - 1)
	refresh()
	changed.emit()


## `StatUps ●●●` — the unspent pool, pips capped at ten with an overflow
## ellipsis. An always-empty line (rather than a vanishing one) keeps the
## sections below from jumping as points are spent.
func _build_statup_pool_line() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size = Vector2(0, 6)
	var margin := _margins(5, 5, 0, 0)
	margin.add_child(row)
	_stack.add_child(margin)

	var unspent: int = _character.available_stat_ups - _character.allocated_total()
	if unspent <= 0:
		return
	var key_label := Label.new()
	key_label.text = "StatUps"
	_style_dim(key_label)
	row.add_child(key_label)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 2)
	pips.tooltip_text = "%d StatUp unspent" % unspent
	pips.mouse_filter = Control.MOUSE_FILTER_PASS
	for i: int in mini(unspent, 10):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(3, 3)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.color = GameColorPalette.get_color("Yellow", 5)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	row.add_child(pips)
	if unspent > 10:
		var more := Label.new()
		more.text = "…"
		_style_dim(more)
		row.add_child(more)


# =============================================================================
# MOVES / PASSIVES / INJURIES
# =============================================================================

func _build_move_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 0)
	var margin := _margins(4, 4, 0, 0)
	margin.add_child(grid)
	_stack.add_child(margin)

	for i: int in MOVE_SLOT_COUNT:
		var move: Move = null
		if i < _character.equipped_moves.size():
			move = _character.equipped_moves[i]
		var empty: bool = is_empty_move(move)
		var slot := _slot_button(_is_selected("move", i))
		slot.custom_minimum_size = Vector2(0, 14)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.pressed.connect(_pick.bind("move", i))

		var content := HBoxContainer.new()
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 3
		content.add_theme_constant_override("separation", 3)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(content)
		if not empty:
			_add_type_icon(content, move.element_type)
		var name_label := Label.new()
		name_label.text = "— empty —" if empty else move.move_name
		name_label.clip_text = true
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if UIManager.font_8px != null:
			name_label.add_theme_font_override("font", UIManager.font_8px)
		name_label.add_theme_font_size_override("font_size", 8)
		name_label.add_theme_color_override("font_color",
				GameColorPalette.get_color("Gray", 5) if empty else GameColors.TEXT_PRIMARY)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(name_label)
		grid.add_child(slot)


func _build_passive_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	var margin := _margins(4, 4, 0, 0)
	margin.add_child(grid)
	_stack.add_child(margin)

	for i: int in PASSIVE_SLOT_COUNT:
		var passive_name: String = ""
		if i < _character.equipped_passives.size() and _character.equipped_passives[i] != null:
			passive_name = str(_character.equipped_passives[i])
		var empty: bool = passive_name == ""
		var slot := _slot_button(_is_selected("passive", i))
		slot.custom_minimum_size = Vector2(0, 14)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.pressed.connect(_pick.bind("passive", i))

		var name_label := Label.new()
		name_label.text = "— empty —" if empty else passive_name
		name_label.clip_text = true
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		name_label.offset_left = 3
		if UIManager.font_8px != null:
			name_label.add_theme_font_override("font", UIManager.font_8px)
		name_label.add_theme_font_size_override("font_size", 8)
		name_label.add_theme_color_override("font_color",
				GameColorPalette.get_color("Gray", 5) if empty else GameColors.TEXT_PRIMARY)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(name_label)
		grid.add_child(slot)


func _build_injury_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var margin := _margins(5, 5, 0, 4)
	margin.add_child(row)
	_stack.add_child(margin)

	if _character.current_injuries.is_empty():
		var none := Label.new()
		none.text = "no injuries"
		_style_dim(none)
		none.modulate.a = 0.6
		row.add_child(none)
		return

	for i: int in _character.current_injuries.size():
		var injury: Injury = _character.current_injuries[i]
		var data: InjuryData = injury.get_data()
		var display: String = data.display_name if data != null else injury.injury_id.capitalize()

		var chip := _slot_button(_is_selected("injury", i))
		chip.custom_minimum_size = Vector2(0, 12)
		chip.pressed.connect(_pick.bind("injury", i))
		# Injuries wear the WARNING voice, not the azure slot chrome — the chip
		# is a fact about damage, and its selected wash stays in that voice.
		var chip_style: StyleBoxFlat = chip.get_theme_stylebox("normal") as StyleBoxFlat
		chip_style.border_color = GameColors.TEXT_WARNING
		chip_style.set_border_width_all(1)
		if _is_selected("injury", i):
			chip_style.bg_color = GameColors.with_alpha(GameColors.TEXT_WARNING, 0.25)

		var content := HBoxContainer.new()
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 3
		content.offset_right = -3
		content.add_theme_constant_override("separation", 2)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(content)
		if data != null and data.icon_path != "" and ResourceLoader.exists(data.icon_path):
			content.add_child(_make_icon(load(data.icon_path) as Texture2D))
		var name_label := Label.new()
		name_label.text = display
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if UIManager.font_8px != null:
			name_label.add_theme_font_override("font", UIManager.font_8px)
		name_label.add_theme_font_size_override("font_size", 8)
		name_label.add_theme_color_override("font_color", GameColors.TEXT_WARNING)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(name_label)
		row.add_child(chip)


# =============================================================================
# SHARED WIDGET HELPERS
# =============================================================================

## The common slot chrome: transparent at rest, azure wash on hover, azure
## border + wash when selected — the same vocabulary as the rail cards.
func _slot_button(selected: bool) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.TRANSPARENT
	var hover := StyleBoxFlat.new()
	hover.bg_color = GameColors.with_alpha(GameColorPalette.get_color("Azure", 2), 0.3)
	if selected:
		normal.bg_color = GameColors.with_alpha(GameColorPalette.get_color("Azure", 2), 0.6)
		normal.border_color = GameColors.INTERACTIVE_BORDER_FOCUS
		normal.set_border_width_all(1)
		hover = normal
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	return button


func _section_header(title: String) -> Control:
	var label := Label.new()
	label.text = title
	_style_dim(label)
	var margin := _margins(5, 5, 3, 0)
	margin.add_child(label)
	return margin


func _style_dim(label: Label) -> void:
	if UIManager.font_8px != null:
		label.add_theme_font_override("font", UIManager.font_8px)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", GameColorPalette.get_color("Straw2", 5))


func _margins(left: int, right: int, top: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _add_type_icon(parent: Container, element_type: Enums.ElementalType) -> void:
	if element_type == Enums.ElementalType.NONE:
		return
	var path: String = ELEMENTAL_ICON_DIR + \
			str(Enums.ElementalType.keys()[element_type]).to_lower() + ".png"
	if not ResourceLoader.exists(path):
		return
	parent.add_child(_make_icon(load(path) as Texture2D))


func _make_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
