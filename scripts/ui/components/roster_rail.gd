## The ROSTER RAIL — left column of Manage Units ([.claude/intermission.md] §4).
## One sortable, searchable, deploy-toggling index; benching and the unit
## browser are THE SAME OBJECT, so neither needs a home of its own.
##
## THE SORT KEY IS THE READOUT (§4a). A 132px rail can't show eight stats and
## doesn't need to: sorting by SKL puts SKL on every card, right-aligned, in
## order. One number per card, always the one you asked for — scanning and
## sorting become the same act. Default key is SQUAD ORDER ascending, the only
## key that carries narrative: the roster doubles as the order these people
## joined.
##
## DEPLOYMENT IS A SET, NEVER AN ORDER (§4d). `deployment_changed` always
## emits ids in SquadManager roster order, whatever the rail is sorted by — a
## sortable rail cannot also be the spawn order, or re-sorting to compare AGL
## would silently rearrange the battlefield. Spawn position belongs to Show
## Map when it ships; until then it stays roster order, stable.
##
## BENCHING IS A PIP, NOT A BUTTON (§4c). Filled = deployed, hollow = benched.
## Deployed cards always sort above the bench line whatever the key; benched
## cards stay in the same rail, dimmed — never on a separate tab, because the
## bEXP doctrine wants players not to permanently forget anyone. At cap,
## bench→deploy pips go inert rather than silently ignoring the click. The
## squad CAN reach zero (RQD 2026-08-16): the last deployed pip used to go
## inert — and, being drawn hollow when disabled, read as "benched" while the
## unit was in fact deployed. An empty selection is a real 0/N now
## (CampaignManager.has_deployment splits it from the unset everyone-
## sentinel) and the hub's Begin Mission is what refuses to launch it.
class_name RosterRail
extends PanelContainer


## A unit card was clicked (not its pip). Fires even when re-clicking the
## already-selected unit — the workbench may want the re-focus.
signal unit_selected(character_id: String)
## A pip toggled. Ids arrive in ROSTER order (§4d), ready for
## CampaignManager.set_deployment verbatim.
signal deployment_changed(deployed_ids: Array[String])


const RAIL_WIDTH: int = 132

## Key → label, in cycle order. Squad order leads and is the default.
const SORT_KEYS: Array = [
	["ord", "SQUAD ORDER"], ["lv", "LEVEL"], ["nm", "NAME"], ["hp", "HP"],
	["str", "STR"], ["spc", "SPC"], ["skl", "SKL"], ["agl", "AGL"],
	["ath", "ATH"], ["def", "DEF"], ["res", "RES"],
]

const PIP_SIZE: int = 5
const PORTRAIT_SIZE: int = 16
const CARD_HEIGHT: int = 20
const BENCHED_ALPHA: float = 0.52

const REASON_SQUAD_FULL: String = "squad is full"


var _roster: Array[CharacterData] = []
# character_id -> true. A set — order is derived from _roster at emit time.
var _deployed: Dictionary = {}
var _cap: int = 0
var _sort_key: String = "ord"
var _sort_ascending: bool = true
var _query: String = ""
var _selected_id: String = ""

var _search_edit: LineEdit = null
var _sort_key_button: Button = null
var _sort_dir_button: Button = null
var _card_list: VBoxContainer = null


func _ready() -> void:
	custom_minimum_size = Vector2(RAIL_WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.HUD_PANEL_BACKGROUND
	style.border_color = GameColorPalette.get_color("Straw2", 3)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)
	_build_chrome()
	_rebuild_cards()


# =============================================================================
# PURE CORE — the rules, testable without a viewport
# =============================================================================

## The comparable value behind a sort key. `roster_index` is the unit's
## position in SquadManager roster order — squad order is a fact about the
## roster, not a field on the character.
static func sort_value(character: CharacterData, key: String, roster_index: int) -> Variant:
	match key:
		"ord": return roster_index
		"lv": return character.level
		"nm": return character.character_name.to_lower()
		"hp": return character.max_hp
		"str": return character.strength
		"spc": return character.special
		"skl": return character.skill
		"agl": return character.agility
		"ath": return character.athleticism
		"def": return character.defense
		"res": return character.resistance
	return roster_index


## Roster indices in display order for (key, ascending). Ties break on squad
## order EXPLICITLY — Godot's sort_custom is not stable, and without the
## tiebreak two Lv 5 units could swap places every re-sort.
static func sort_order(roster: Array[CharacterData], key: String, ascending: bool) -> Array[int]:
	var indices: Array[int] = []
	for i: int in roster.size():
		indices.append(i)
	indices.sort_custom(func(a: int, b: int) -> bool:
		var value_a: Variant = sort_value(roster[a], key, a)
		var value_b: Variant = sort_value(roster[b], key, b)
		if value_a == value_b:
			return a < b
		if ascending:
			return value_a < value_b
		return value_a > value_b)
	return indices


## The one number a card shows — the sort key's value. Name sort shows
## nothing (the name is already the card), squad order counts from 1
## (players don't count from zero).
static func card_readout(character: CharacterData, key: String, roster_index: int) -> String:
	match key:
		"nm": return ""
		"ord": return str(roster_index + 1)
	return str(sort_value(character, key, roster_index))


## Substring across name, class, and elemental type (§4b) — substring, not
## fuzzy, because predictable beats clever at roster sizes under ~30.
static func matches_search(character: CharacterData, query: String) -> bool:
	var needle: String = query.strip_edges().to_lower()
	if needle == "":
		return true
	var haystack: String = character.character_name.to_lower()
	haystack += " " + str(Enums.CharacterClass.keys()[character.current_class]).to_lower()
	if character.primary_type != Enums.ElementalType.NONE:
		haystack += " " + str(Enums.ElementalType.keys()[character.primary_type]).to_lower()
	if character.secondary_type != Enums.ElementalType.NONE:
		haystack += " " + str(Enums.ElementalType.keys()[character.secondary_type]).to_lower()
	return haystack.contains(needle)


## §4d serialization: whatever order pips were clicked in, the emitted list is
## roster order. This is the invariant that keeps spawn positions stable
## under rail sorting.
static func deployment_in_roster_order(roster: Array[CharacterData],
		deployed_set: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for character: CharacterData in roster:
		if deployed_set.has(character.character_id):
			ids.append(character.character_id)
	return ids


## Turns a saved/carried selection into a valid one for THIS roster and THIS
## map: prunes ids the roster no longer has (permadeath), truncates over the
## cap in roster order (a selection carried from a 6-spawn map onto a 4-spawn
## map keeps the first 4), and — when nothing survives — seeds the first
## `cap` units in roster order, the same set the hub sub-line advertises.
## Cap 0 means the mission is unknown/unloadable: seed nobody, so a broken
## map path can't write "deploy everyone onto no spawn tiles".
##
## `chosen` = the selection was written by the player (CampaignManager.
## has_deployment). A chosen EMPTY selection is "bench everyone" and stays
## empty — seeding it would silently undo the choice on the next hub arrival.
## An unset one (empty because nobody wrote it) seeds as before, and so does
## a chosen non-empty one that permadeath pruned to nothing: the player never
## asked for zero there.
static func resolved_deployment(roster: Array[CharacterData],
		selection: Array[String], cap: int, chosen: bool = false) -> Array[String]:
	if chosen and selection.is_empty():
		return []
	var picked: Array[String] = []
	for character: CharacterData in roster:
		if cap > 0 and picked.size() >= cap:
			break
		if selection.has(character.character_id):
			picked.append(character.character_id)
	if not picked.is_empty():
		return picked
	for character: CharacterData in roster:
		if cap <= 0 or picked.size() >= cap:
			break
		picked.append(character.character_id)
	return picked


## Why this pip can't be pressed, or "" when it can. At cap, bench→deploy
## pips go inert (never silently ignored). Benching is always free — down to
## zero; the hub, not the pip, is where an empty squad is refused.
static func pip_inert_reason(is_deployed: bool, deployed_count: int, cap: int) -> String:
	if not is_deployed and cap > 0 and deployed_count >= cap:
		return REASON_SQUAD_FULL
	return ""


# =============================================================================
# PUBLIC API
# =============================================================================

## Hands the rail its world. `deployed_ids` is the resolved selection (see
## resolved_deployment); the rail treats it as a set from here on.
func set_state(roster: Array[CharacterData], deployed_ids: Array[String], cap: int) -> void:
	_roster = roster
	_deployed.clear()
	for id: String in deployed_ids:
		_deployed[id] = true
	_cap = cap
	# A stale selection (permadeath between missions) falls back to the first
	# card in display order, same as no selection at all.
	if _find_roster_index(_selected_id) == -1:
		_selected_id = ""
	if _selected_id == "" and not _roster.is_empty():
		var order: Array[int] = _display_order()
		if not order.is_empty():
			_selected_id = _roster[order[0]].character_id
	_rebuild_cards()


func select_unit(character_id: String) -> void:
	_selected_id = character_id
	_rebuild_cards()


func get_selected_id() -> String:
	return _selected_id


## Programmatic sort — the bEXP deep link opens level-ASCENDING (§3g), so the
## units the catch-up economy exists for are already on top.
func set_sort(key: String, ascending: bool) -> void:
	_sort_key = key
	_sort_ascending = ascending
	_refresh_sort_label()
	_rebuild_cards()


func deployed_count() -> int:
	return _deployed.size()


func is_deployed(character_id: String) -> bool:
	return _deployed.has(character_id)


## Rebuild the cards against current character state — the ★N badges and sort
## readouts go stale whenever the sheet or workbench mutates a unit.
func refresh() -> void:
	_rebuild_cards()


func _find_roster_index(character_id: String) -> int:
	for i: int in _roster.size():
		if _roster[i].character_id == character_id:
			return i
	return -1


# =============================================================================
# CHROME — railhead (search + sort), then the scrolling card list
# =============================================================================

func _build_chrome() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	add_child(column)

	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 3)
	column.add_child(head)

	var head_margin := MarginContainer.new()
	head_margin.add_theme_constant_override("margin_left", 4)
	head_margin.add_theme_constant_override("margin_right", 4)
	head_margin.add_theme_constant_override("margin_top", 3)
	head.add_child(head_margin)

	var head_stack := VBoxContainer.new()
	head_stack.add_theme_constant_override("separation", 3)
	head_margin.add_child(head_stack)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "search roster"
	_search_edit.custom_minimum_size = Vector2(0, 12)
	var search_style := StyleBoxFlat.new()
	search_style.bg_color = GameColors.with_alpha(GameColorPalette.get_color("Gray", 0), 0.6)
	search_style.border_color = GameColorPalette.get_color("Straw2", 3)
	search_style.set_border_width_all(1)
	search_style.content_margin_left = 3
	search_style.content_margin_right = 3
	_search_edit.add_theme_stylebox_override("normal", search_style)
	_search_edit.add_theme_stylebox_override("focus", search_style)
	if UIManager.font_8px != null:
		_search_edit.add_theme_font_override("font", UIManager.font_8px)
	_search_edit.add_theme_font_size_override("font_size", 8)
	# The glow material is safe on a LineEdit after all: the caret and
	# selection box render as opaque untextured rects, which the shader
	# passes through untouched (the same reason the Equip button's stylebox
	# doesn't halo) — only glyphs glow. The pair swaps with state so body and
	# halo always travel together: MUTED while showing the placeholder,
	# PRIMARY once the player is typing.
	_search_edit.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	_search_edit.add_theme_color_override("font_placeholder_color", GameColors.TEXT_MUTED)
	var search_glow := (load("res://resources/hud_glow.tres") as Material).duplicate()
	(search_glow as ShaderMaterial).set_shader_parameter("glow_color",
			GameColors.TEXT_MUTED_GLOW)
	_search_edit.material = search_glow
	_search_edit.text_changed.connect(_on_search_changed)
	_search_edit.text_changed.connect(func(new_text: String) -> void:
		(search_glow as ShaderMaterial).set_shader_parameter("glow_color",
				GameColors.TEXT_MUTED_GLOW if new_text.is_empty()
				else GameColors.TEXT_PRIMARY_GLOW))
	head_stack.add_child(_search_edit)

	var sort_row := HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 4)
	head_stack.add_child(sort_row)

	sort_row.add_child(_dim_label("sort"))

	_sort_key_button = _make_link_button(GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW)
	_sort_key_button.tooltip_text = "cycle the sort key — it becomes every card's readout"
	_sort_key_button.pressed.connect(_on_sort_key_pressed)
	sort_row.add_child(_sort_key_button)

	_sort_dir_button = _make_link_button(GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW)
	_sort_dir_button.tooltip_text = "flip sort direction"
	# The ▲/▼ glyphs hang LOW in the fallback font (opposite problem to the
	# UndeadPixel baseline): shift the caret 2px up by tilting the button's
	# content margins — min size stays put, centering does the rest.
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var caret_box := StyleBoxEmpty.new()
		caret_box.content_margin_top = -2
		caret_box.content_margin_bottom = 2
		_sort_dir_button.add_theme_stylebox_override(state, caret_box)
	_sort_dir_button.pressed.connect(_on_sort_dir_pressed)
	sort_row.add_child(_sort_dir_button)
	_refresh_sort_label()

	head.add_child(_hairline())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_card_list = VBoxContainer.new()
	_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_list.add_theme_constant_override("separation", 0)
	scroll.add_child(_card_list)


## A bare-text button in a semantic voice. Safe to put the glow material on
## the Button itself ONLY because every stylebox is empty — the shader glows
## whatever the control draws, and here that is exactly the glyphs.
func _make_link_button(text_color: Color, glow: Color) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	if UIManager.font_8px != null:
		button.add_theme_font_override("font", UIManager.font_8px)
	button.add_theme_font_size_override("font_size", 8)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", GameColors.brightened(text_color))
	var glow_material := (load("res://resources/hud_glow.tres") as Material).duplicate()
	(glow_material as ShaderMaterial).set_shader_parameter("glow_color", glow)
	button.material = glow_material
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


## Structural text — headers, keys, hints — wears the SECONDARY voice.
func _dim_label(text_value: String) -> GlowLabel:
	return GlowLabel.styled(text_value, UIManager.font_8px, 8,
			GameColors.TEXT_SECONDARY, GameColors.TEXT_SECONDARY_GLOW)


func _hairline() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = GameColorPalette.get_color("Straw2", 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


# =============================================================================
# CARDS
# =============================================================================

func _display_order() -> Array[int]:
	var order: Array[int] = sort_order(_roster, _sort_key, _sort_ascending)
	var shown: Array[int] = []
	for index: int in order:
		if matches_search(_roster[index], _query):
			shown.append(index)
	return shown


## Full rebuild on every change. The roster tops out around ~30 units and a
## card is a dozen nodes — rebuilding beats reconciling for code this cold.
func _rebuild_cards() -> void:
	if _card_list == null:
		return
	for child: Node in _card_list.get_children():
		child.queue_free()

	var shown: Array[int] = _display_order()
	var squad_indices: Array[int] = []
	var bench_indices: Array[int] = []
	for index: int in shown:
		if _deployed.has(_roster[index].character_id):
			squad_indices.append(index)
		else:
			bench_indices.append(index)

	var full: bool = _cap > 0 and _deployed.size() >= _cap
	_card_list.add_child(_make_group_header("SQUAD", _cap_text(), full))
	for index: int in squad_indices:
		_card_list.add_child(_make_card(index))
	_card_list.add_child(_make_group_header("BENCH", "", false))
	if bench_indices.is_empty():
		_card_list.add_child(_make_empty_hint())
	for index: int in bench_indices:
		_card_list.add_child(_make_card(index))


func _cap_text() -> String:
	if _cap > 0:
		return "%d/%d" % [_deployed.size(), _cap]
	return str(_deployed.size())


func _make_group_header(title: String, cap_text: String, full: bool) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_child(row)
	wrap.add_child(margin)

	row.add_child(_dim_label(title))

	if cap_text != "":
		# The cap is half the information; it turns warning-hot when the squad
		# is full so "why is this pip dead" has a visible answer.
		var cap_label := GlowLabel.styled(cap_text, UIManager.font_8px, 8,
				GameColors.TEXT_WARNING if full else GameColors.TEXT_PRIMARY,
				GameColors.TEXT_WARNING_GLOW if full else GameColors.TEXT_PRIMARY_GLOW)
		row.add_child(cap_label)

	wrap.add_child(_hairline())
	return wrap


func _make_empty_hint() -> Control:
	# Absence speaks MUTED, not modulated-SECONDARY — the violet halo goes
	# muddy under an alpha fade (RQD 2026-08-10).
	var hint := GlowLabel.styled("(empty)", UIManager.font_8px, 8,
			GameColors.TEXT_MUTED, GameColors.TEXT_MUTED_GLOW)
	var hint_margin := MarginContainer.new()
	hint_margin.add_theme_constant_override("margin_left", 4)
	hint_margin.add_child(hint)
	return hint_margin


func _make_card(roster_index: int) -> Button:
	var character: CharacterData = _roster[roster_index]
	var is_deployed: bool = _deployed.has(character.character_id)
	var is_selected: bool = character.character_id == _selected_id

	var card := Button.new()
	card.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.pressed.connect(_on_card_pressed.bind(character.character_id))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.TRANSPARENT
	var hover := StyleBoxFlat.new()
	hover.bg_color = GameColors.with_alpha(GameColorPalette.get_color("Azure", 2), 0.35)
	if is_selected:
		normal.bg_color = GameColors.with_alpha(GameColorPalette.get_color("Azure", 2), 0.65)
		normal.border_color = GameColors.INTERACTIVE_BORDER_IDLE
		normal.set_border_width_all(1)
		hover = normal
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)
	card.add_theme_stylebox_override("focus", hover)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	# The pip is its own Button INSIDE the card button — its clicks are
	# consumed at that node and never bubble up into card selection.
	row.add_child(_make_pip(character.character_id, is_deployed))

	var portrait_texture: Texture2D = CharacterPortrait.get_sprite_crop_for(character)
	if portrait_texture != null:
		var portrait := TextureRect.new()
		portrait.texture = portrait_texture
		portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(portrait)

	var name_label := GlowLabel.styled(character.character_name, UIManager.font_8px, 8,
			GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW)
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)

	# ★N — the compact StatUp glyph. The word "StatUp" lives in the tooltip;
	# the glyph is the only spelling that fits a 132px card (RQD round 11).
	# UNSPENT StatUps advertise in the INFO voice (a live value, like the hub
	# sub-line); once SPENT they become modifiers and switch to SECONDARY —
	# see the sheet's tally.
	var unspent: int = character.available_stat_ups - character.allocated_total()
	if unspent > 0:
		var star := GlowLabel.styled("★%d" % unspent, UIManager.font_8px, 8,
				GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW)
		star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		star.tooltip_text = "%d StatUp unspent" % unspent
		star.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(star)

	# The sort readout is a live value — INFO voice, like the pool.
	var value_label := GlowLabel.styled(card_readout(character, _sort_key, roster_index),
			UIManager.font_8px, 8, GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW)
	value_label.custom_minimum_size = Vector2(16, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)

	if not is_deployed:
		# Dim the CONTENT, not the button — a modulated Button would also dim
		# its hover/selection chrome and the pip inside.
		margin.modulate.a = BENCHED_ALPHA
	return card


func _make_pip(character_id: String, is_deployed: bool) -> Button:
	var pip := Button.new()
	pip.custom_minimum_size = Vector2(PIP_SIZE, PIP_SIZE)
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pip.focus_mode = Control.FOCUS_NONE

	var reason: String = pip_inert_reason(is_deployed, _deployed.size(), _cap)
	var style := StyleBoxFlat.new()
	style.set_border_width_all(1)
	if reason != "":
		pip.disabled = true
		pip.tooltip_text = reason
		style.bg_color = Color.TRANSPARENT
		style.border_color = GameColors.INTERACTIVE_BORDER_DISABLED
	elif is_deployed:
		pip.tooltip_text = "bench this unit"
		style.bg_color = GameColors.INTERACTIVE_BORDER_IDLE
		style.border_color = GameColors.INTERACTIVE_BORDER_IDLE
	else:
		pip.tooltip_text = "deploy this unit"
		style.bg_color = Color.TRANSPARENT
		style.border_color = GameColors.INTERACTIVE_BORDER_IDLE
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		pip.add_theme_stylebox_override(state, style)
	pip.pressed.connect(_on_pip_pressed.bind(character_id))
	return pip


# =============================================================================
# HANDLERS
# =============================================================================

func _on_card_pressed(character_id: String) -> void:
	_selected_id = character_id
	_rebuild_cards()
	unit_selected.emit(character_id)


func _on_pip_pressed(character_id: String) -> void:
	var is_deployed: bool = _deployed.has(character_id)
	# The disabled state already blocks this; guard anyway so a stale click
	# can't slip a unit past the cap.
	if pip_inert_reason(is_deployed, _deployed.size(), _cap) != "":
		return
	if is_deployed:
		_deployed.erase(character_id)
	else:
		_deployed[character_id] = true
	_rebuild_cards()
	deployment_changed.emit(deployment_in_roster_order(_roster, _deployed))


func _on_search_changed(new_text: String) -> void:
	_query = new_text
	_rebuild_cards()


func _on_sort_key_pressed() -> void:
	for i: int in SORT_KEYS.size():
		if SORT_KEYS[i][0] == _sort_key:
			_sort_key = SORT_KEYS[(i + 1) % SORT_KEYS.size()][0]
			break
	_refresh_sort_label()
	_rebuild_cards()


func _on_sort_dir_pressed() -> void:
	_sort_ascending = not _sort_ascending
	_refresh_sort_label()
	_rebuild_cards()


func _refresh_sort_label() -> void:
	if _sort_key_button == null:
		return
	for entry: Array in SORT_KEYS:
		if entry[0] == _sort_key:
			_sort_key_button.text = entry[1]
			break
	_sort_dir_button.text = "▲" if _sort_ascending else "▼"
