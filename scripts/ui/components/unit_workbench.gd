## The WORKBENCH — right column of Manage Units ([.claude/intermission.md]
## §3c–§3d). Downstream of whatever slot the sheet has selected: it offers
## what fits in that slot. No mode toggle, no tabs — the lane is implied by
## what was clicked. This absorbs EquipmentPicker's bank, filters, and detail
## (its mode toggle and carry/swap state machine are the things that die).
##
## READING BEATS SWAPPING (§3c). The lane reads top to bottom detail → swap
## bar → bank. Clicking an equipped slot is an INSPECT: the thing you touched
## gets the headline and nothing suggests you were about to change it. Picking
## a bank entry is the second, explicit step — the detail switches to the
## CANDIDATE (you're now reading about the incoming move) while the swap bar
## keeps the outgoing one's numbers in view. Clicking the same bank row again
## drops the candidate. Equip commits live, no confirm (squad_manager.md §6).
##
## Lanes: move / passive (bank + swap), stat (pure meaning — the +/− live on
## the sheet row, so this panel explains: what the stat does, where it stands
## against its cap, and the same stat across the squad), injury (real copy),
## and the unit summary when nothing is selected. The bEXP lane on the level
## row is slice 4.
class_name UnitWorkbench
extends PanelContainer


## An equip was committed (live, already written to CharacterData). The sheet
## and rail want a refresh; the hub's save latch wants re-arming.
signal changed


## What each stat DOES — §3d's sleeper win. Nothing else in the game explains
## that ATH is attack count, and this panel is the permanent home for that
## copy at exactly the moment the player cares. Wording locked in the mockup.
const STAT_BLURBS: Dictionary = {
	"max_hp": "Hit points. How much punishment you absorb before you go down.",
	"strength": "Strength. Drives damage on physical moves.",
	"special": "Special. Drives damage on special moves.",
	"skill": "Skill. Accuracy — each point adds about 1.5% to your hit chance.",
	"agility": "Evasion. Each point takes about 1.5% off the attacker's hit chance.",
	"athleticism": "Athleticism. Attack count — outpace the defender's ATH and you strike more than once.",
	"defense": "Defense. Cuts physical damage taken.",
	"resistance": "Resistance. Cuts special damage taken.",
}

const ICON_SIZE: int = 10
const GLOW_MATERIAL_PATH: String = "res://resources/hud_glow.tres"
const ELEMENTAL_ICON_DIR: String = "res://art/sprites/ui/elemental_type_icons_10x10/"
## Damage-type icons live flat in ui/. `special_a` is one of seven candidate
## special glyphs (`special_a`…`special_g`) — nobody has picked the final one
## (§3f open question), so the mockup's choice carries over.
const DAMAGE_ICON_PATHS: Dictionary = {
	Enums.DamageType.PHYSICAL: "res://art/sprites/ui/physical.png",
	Enums.DamageType.SPECIAL: "res://art/sprites/ui/special_a.png",
	Enums.DamageType.SUPPORT: "res://art/sprites/ui/support.png",
}


var _character: CharacterData = null
var _kind: String = "none"
var _key: Variant = null
## The deployed squad, for the stat lane's ACROSS THE SQUAD list.
var _squad: Array[CharacterData] = []
## Candidate picked from the bank ("" = nothing picked, reading the equipped).
var _bank_pick: String = ""
## Filter sets persist across lane changes and units, like a real workshop
## leaves its jigs where you set them.
var _damage_filter: Dictionary = {}
var _element_filter: Dictionary = {}

var _head_label: GlowLabel = null
var _body: VBoxContainer = null


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.HUD_PANEL_BACKGROUND
	style.border_color = GameColorPalette.get_color("Straw2", 3)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	add_child(stack)

	_head_label = GlowLabel.styled("", UIManager.font_8px, 8,
			GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW)
	var head_margin := MarginContainer.new()
	head_margin.add_theme_constant_override("margin_left", 5)
	head_margin.add_theme_constant_override("margin_top", 3)
	head_margin.add_theme_constant_override("margin_bottom", 3)
	head_margin.add_child(_head_label)
	stack.add_child(head_margin)

	var hairline := ColorRect.new()
	hairline.custom_minimum_size = Vector2(0, 1)
	hairline.color = GameColorPalette.get_color("Straw2", 2)
	hairline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(hairline)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 0)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_body)
	_rebuild()


# =============================================================================
# PURE CORE — bank building and equip commits, pinned by tests
# =============================================================================

## The move bank: learnable pool minus what's equipped, alphabetized (the
## predictability rule — same reason rail search is substring). Filter sets
## hold enum values; an empty set means "no filter", not "nothing".
static func move_bank(character: CharacterData, damage_filter: Dictionary,
		element_filter: Dictionary) -> Array[String]:
	var equipped_names: Dictionary = {}
	for move: Move in character.equipped_moves:
		if move != null:
			equipped_names[move.move_name] = true
	var available: Array[String] = []
	for name: String in character.base_pool_moves:
		if equipped_names.has(name):
			continue
		var move: Move = MoveData.get_move(name)
		if move == null:
			continue
		if not damage_filter.is_empty() and not damage_filter.has(move.damage_type):
			continue
		if not element_filter.is_empty() and not element_filter.has(move.element_type):
			continue
		available.append(name)
	available.sort()
	return available


static func passive_bank(character: CharacterData) -> Array[String]:
	var equipped_names: Dictionary = {}
	for passive: Variant in character.equipped_passives:
		if passive != null:
			equipped_names[str(passive)] = true
	var available: Array[String] = []
	for name: String in character.base_pool_passives:
		if not equipped_names.has(name):
			available.append(name)
	available.sort()
	return available


## Live commit of a bank move into an equipped slot. The displaced move falls
## back into the bank automatically — the bank is always recomputed as pool
## minus equipped. Appends empty slots when equipping past the current list
## length (filling slot 3 of a unit with 2 moves).
static func equip_move(character: CharacterData, slot_index: int, move_name: String) -> bool:
	var new_move: Move = MoveData.get_move(move_name)
	if new_move == null or slot_index < 0:
		return false
	while character.equipped_moves.size() <= slot_index:
		character.equipped_moves.append(Move.EMPTY)
	character.equipped_moves[slot_index] = new_move
	return true


static func equip_passive(character: CharacterData, slot_index: int, passive_name: String) -> bool:
	if PassiveData.get_passive(passive_name) == null or slot_index < 0:
		return false
	while character.equipped_passives.size() <= slot_index:
		character.equipped_passives.append(null)
	character.equipped_passives[slot_index] = passive_name
	return true


## `8 - capped` open stats — the number the at-cap explainer quotes.
static func open_stat_count(character: CharacterData) -> int:
	var open: int = 0
	for entry: Array in UnitSheet.STAT_ROWS:
		var stat_name: String = str(entry[0])
		if character.get_base_plus_growth(stat_name) < character.get_stat_cap(stat_name):
			open += 1
	return open


# =============================================================================
# PUBLIC API
# =============================================================================

## The deployed squad, freshest copy — only the stat lane reads it.
func set_squad(squad: Array[CharacterData]) -> void:
	_squad = squad


## Point the bench at a slot. Clears any half-picked candidate — a candidate
## belongs to the lane it was picked in.
func show_lane(character: CharacterData, kind: String, key: Variant) -> void:
	_character = character
	_kind = kind
	_key = key
	_bank_pick = ""
	_rebuild()


# =============================================================================
# LANE DISPATCH
# =============================================================================

func _rebuild() -> void:
	if _body == null:
		return
	for child: Node in _body.get_children():
		child.queue_free()
	if _character == null:
		_head_label.text = "UNIT SUMMARY"
		return
	match _kind:
		"move":
			_head_label.text = "MOVE SLOT %d" % [int(_key) + 1]
			_build_equip_lane(true)
		"passive":
			_head_label.text = "PASSIVE SLOT %d" % [int(_key) + 1]
			_build_equip_lane(false)
		"stat":
			_head_label.text = "STAT — %s" % UnitSheet.stat_label(str(_key))
			_build_stat_lane()
		"injury":
			_head_label.text = "INJURY"
			_build_injury_lane()
		_:
			_head_label.text = "UNIT SUMMARY"
			_build_summary_lane()


# =============================================================================
# MOVE / PASSIVE LANE — detail, swap bar, filters, bank
# =============================================================================

func _equipped_name(is_move: bool) -> String:
	var index: int = int(_key)
	if is_move:
		if index < _character.equipped_moves.size() \
				and not UnitSheet.is_empty_move(_character.equipped_moves[index]):
			return _character.equipped_moves[index].move_name
		return ""
	if index < _character.equipped_passives.size() and _character.equipped_passives[index] != null:
		return str(_character.equipped_passives[index])
	return ""


func _build_equip_lane(is_move: bool) -> void:
	var equipped: String = _equipped_name(is_move)
	# With nothing picked from the bank, the detail describes what's already
	# in the slot — "what does this move do" answered without a swap in sight.
	var shown: String = _bank_pick if _bank_pick != "" else equipped

	if shown != "":
		if is_move:
			_build_move_detail(MoveData.get_move(shown))
		else:
			_build_passive_detail(shown)
	else:
		_build_detail_text("Empty slot", "", "Pick something below to equip it.")

	_build_swap_bar(is_move, equipped)
	if is_move:
		_build_filters()
	_build_bank(is_move)


func _build_move_detail(move: Move) -> void:
	if move == null:
		return
	var box := _detail_box()
	box.add_child(_headline(move.move_name))
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 3)
	_add_damage_icon(meta, move.damage_type)
	_add_type_icon(meta, move.element_type)
	var meta_label := _dim_label("%s · Range %d · AOE %d · Uses %d" % [
			("Pow %d" % move.base_power) if move.base_power > 0 else "no damage",
			move.attack_range, move.area_of_effect, move.max_uses])
	meta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta.add_child(meta_label)
	box.add_child(meta)
	box.add_child(_body_copy(move.description))


func _build_passive_detail(passive_name: String) -> void:
	var box := _detail_box()
	box.add_child(_headline(passive_name))
	box.add_child(_dim_label("Passive"))
	box.add_child(_body_copy(PassiveData.get_description(passive_name)))


## `meta_color`/`meta_glow` default to the SECONDARY structural voice; lanes
## with a semantic claim on their meta line (injury → DANGER) override.
func _build_detail_text(title: String, meta: String, copy: String,
		meta_color: Color = GameColors.TEXT_SECONDARY,
		meta_glow: Color = GameColors.TEXT_SECONDARY_GLOW) -> void:
	var box := _detail_box()
	box.add_child(_headline(title))
	if meta != "":
		box.add_child(GlowLabel.styled(meta, UIManager.font_8px, 8, meta_color, meta_glow))
	if copy != "":
		box.add_child(_body_copy(copy))


## The second, explicit step lives here. Reading state: "equipped — pick one
## below to swap it out". Candidate state: the outgoing item's name + numbers
## stay in view next to the one button that commits.
func _build_swap_bar(is_move: bool, equipped: String) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	var margin := _margins(5, 5, 3, 3)
	margin.add_child(bar)
	_body.add_child(margin)

	if _bank_pick == "" or _bank_pick == equipped:
		bar.add_child(_dim_label("equipped — pick one below to swap it out" \
				if equipped != "" else "empty slot — pick one below to equip"))
		return

	var verb := _dim_label("replaces" if equipped != "" else "fills this slot")
	verb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(verb)

	if equipped != "":
		var out_label := GlowLabel.styled(equipped, UIManager.font_8px, 8,
				GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW)
		out_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bar.add_child(out_label)
		if is_move:
			var out_move: Move = MoveData.get_move(equipped)
			if out_move != null:
				var numbers := _dim_label("%s R%d" % [
						("Pow %d" % out_move.base_power) if out_move.base_power > 0 else "—",
						out_move.attack_range])
				numbers.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				bar.add_child(numbers)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	# §14: the lit border marks the one press that changes something — and it
	# glows, text AND outline (RQD 2026-08-10). Composition: the stylebox
	# carries only the bg fill (opaque draws pass through the glow shader
	# untouched), the Button's material glows the glyphs, and the outline is a
	# border_mode GlowColorRect overlaid on top — it only paints the 1px ring
	# and its halo, so it never covers the text.
	var equip_button := Button.new()
	equip_button.text = "Equip"
	equip_button.custom_minimum_size = Vector2(40, 15)
	if UIManager.font_8px != null:
		equip_button.add_theme_font_override("font", UIManager.font_8px)
	equip_button.add_theme_font_size_override("font_size", 8)
	equip_button.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	var text_glow := (load(GLOW_MATERIAL_PATH) as Material).duplicate()
	(text_glow as ShaderMaterial).set_shader_parameter("glow_color",
			GameColors.TEXT_PRIMARY_GLOW)
	equip_button.material = text_glow
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = GameColors.ACTION_BUTTON_BG_NORMAL
	equip_button.add_theme_stylebox_override("normal", button_style)
	var button_hover := button_style.duplicate() as StyleBoxFlat
	button_hover.bg_color = GameColors.ACTION_BUTTON_BG_HOVERED
	equip_button.add_theme_stylebox_override("hover", button_hover)
	equip_button.add_theme_stylebox_override("pressed", button_hover)
	equip_button.add_theme_stylebox_override("focus", button_style)

	var outline := GlowColorRect.new()
	outline.material = (load(GLOW_MATERIAL_PATH) as Material).duplicate()
	outline.border_mode = true
	# border_mode reads the ring color from vertex COLOR = color × self_modulate;
	# keep color white so self_modulate alone names the border state.
	outline.color = Color.WHITE
	outline.self_modulate = GameColors.INTERACTIVE_BORDER_IDLE
	outline.glow_color = GameColors.TEXT_PRIMARY_GLOW
	outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equip_button.add_child(outline)
	equip_button.mouse_entered.connect(func() -> void:
		outline.self_modulate = GameColors.INTERACTIVE_BORDER_FOCUS)
	equip_button.mouse_exited.connect(func() -> void:
		outline.self_modulate = GameColors.INTERACTIVE_BORDER_IDLE)

	equip_button.pressed.connect(_on_equip_pressed.bind(is_move))
	bar.add_child(equip_button)


func _on_equip_pressed(is_move: bool) -> void:
	# Live commit, no confirm — squad_manager.md §6.
	var committed: bool = equip_move(_character, int(_key), _bank_pick) if is_move \
			else equip_passive(_character, int(_key), _bank_pick)
	if not committed:
		return
	_bank_pick = ""
	_rebuild()
	changed.emit()


## Damage types then elements, all as their real 10×10 art (§3f) — toggling
## chips shrinks the bank live.
func _build_filters() -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 3)
	flow.add_theme_constant_override("v_separation", 3)
	var margin := _margins(5, 5, 0, 3)
	margin.add_child(flow)
	_body.add_child(margin)

	for damage_type: Enums.DamageType in DAMAGE_ICON_PATHS.keys():
		flow.add_child(_make_filter_chip(str(DAMAGE_ICON_PATHS[damage_type]),
				str(Enums.DamageType.keys()[damage_type]).capitalize(),
				_damage_filter.has(damage_type),
				_on_damage_filter_toggled.bind(damage_type)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(4, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_child(gap)
	for element: Enums.ElementalType in Enums.ElementalType.values():
		if element == Enums.ElementalType.NONE:
			continue
		var path: String = ELEMENTAL_ICON_DIR + \
				str(Enums.ElementalType.keys()[element]).to_lower() + ".png"
		if not ResourceLoader.exists(path):
			continue
		flow.add_child(_make_filter_chip(path,
				Enums.elemental_type_to_string(element).capitalize(),
				_element_filter.has(element),
				_on_element_filter_toggled.bind(element)))


func _make_filter_chip(icon_path: String, tip: String, active: bool,
		handler: Callable) -> Button:
	var chip := Button.new()
	chip.custom_minimum_size = Vector2(14, 14)
	chip.tooltip_text = tip
	chip.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.set_border_width_all(1)
	if active:
		style.bg_color = GameColors.with_alpha(GameColorPalette.get_color("Azure", 2), 0.5)
		style.border_color = GameColors.INTERACTIVE_BORDER_IDLE
	else:
		style.bg_color = GameColors.with_alpha(GameColorPalette.get_color("Gray", 0), 0.5)
		style.border_color = GameColorPalette.get_color("Straw2", 3)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		chip.add_theme_stylebox_override(state, style)
	if ResourceLoader.exists(icon_path):
		var icon := _make_icon(load(icon_path) as Texture2D)
		# Buttons don't lay out children — park the 10px icon at the 14px
		# chip's center by hand.
		icon.position = Vector2(2, 2)
		icon.size = Vector2(ICON_SIZE, ICON_SIZE)
		chip.add_child(icon)
	chip.pressed.connect(handler)
	return chip


func _on_damage_filter_toggled(damage_type: Enums.DamageType) -> void:
	if _damage_filter.has(damage_type):
		_damage_filter.erase(damage_type)
	else:
		_damage_filter[damage_type] = true
	_rebuild()


func _on_element_filter_toggled(element: Enums.ElementalType) -> void:
	if _element_filter.has(element):
		_element_filter.erase(element)
	else:
		_element_filter[element] = true
	_rebuild()


func _build_bank(is_move: bool) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)

	var names: Array[String] = move_bank(_character, _damage_filter, _element_filter) \
			if is_move else passive_bank(_character)
	if names.is_empty():
		var empty := _muted_label("nothing matches those filters" \
				if is_move and not (_damage_filter.is_empty() and _element_filter.is_empty()) \
				else "(nothing else available)")
		var margin := _margins(5, 5, 3, 0)
		margin.add_child(empty)
		list.add_child(margin)
		return

	for name: String in names:
		list.add_child(_make_bank_row(name, is_move))


func _make_bank_row(name: String, is_move: bool) -> Button:
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.focus_mode = Control.FOCUS_NONE
	var selected: bool = name == _bank_pick
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.TRANSPARENT
	var hover := StyleBoxFlat.new()
	hover.bg_color = GameColors.with_alpha(GameColorPalette.get_color("Azure", 2), 0.3)
	if selected:
		normal.bg_color = GameColors.with_alpha(GameColorPalette.get_color("Azure", 2), 0.6)
		normal.border_color = GameColors.INTERACTIVE_BORDER_IDLE
		normal.set_border_width_all(1)
		hover = normal
	row.add_theme_stylebox_override("normal", normal)
	row.add_theme_stylebox_override("hover", hover)
	row.add_theme_stylebox_override("pressed", hover)
	row.add_theme_stylebox_override("focus", hover)
	row.pressed.connect(_on_bank_row_pressed.bind(name))

	var content := HBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 5
	content.offset_right = -5
	content.add_theme_constant_override("separation", 3)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)

	var move: Move = MoveData.get_move(name) if is_move else null
	if move != null:
		_add_damage_icon(content, move.damage_type)
		_add_type_icon(content, move.element_type)
	var name_label := GlowLabel.styled(name, UIManager.font_8px, 8,
			GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW)
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(name_label)
	if move != null:
		var power := _dim_label(("Pow %d" % move.base_power) if move.base_power > 0 else "—")
		power.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(power)
		var range_label := _dim_label("R%d" % move.attack_range)
		range_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(range_label)
	return row


func _on_bank_row_pressed(name: String) -> void:
	# Same row again drops the candidate and falls back to reading the
	# equipped item (§3c).
	_bank_pick = "" if _bank_pick == name else name
	_rebuild()


# =============================================================================
# STAT LANE — pure meaning; the +/− live on the sheet row
# =============================================================================

func _build_stat_lane() -> void:
	var stat_name: String = str(_key)
	var abbrev: String = UnitSheet.stat_label(stat_name)
	var level_value: int = _character.get_base_plus_growth(stat_name)
	var cap: int = _character.get_stat_cap(stat_name)
	var invested: int = _character.get_allocated_points(stat_name)

	var meta: String = "%d of %d %s cap · game max %d" % [
			level_value, cap, Enums.get_class_display_name(_character.current_class),
			_character.get_global_stat_cap(stat_name)]
	if invested > 0:
		meta += " · %d StatUp invested" % invested
	_build_detail_text(abbrev, meta, str(STAT_BLURBS.get(stat_name, "")))

	if level_value >= cap:
		# The at-cap consequence wears SUCCESS — same voice as the bar's fill
		# and the number on the sheet row, so "maxed" is one color everywhere.
		var capped_copy := _body_copy(
				("At the class ceiling. Level-ups can't raise it, so bEXP growths " +
				"concentrate into this unit's remaining %d open stats. StatUps " +
				"still work — they're allowed past the cap.") % open_stat_count(_character))
		capped_copy.add_theme_color_override("font_color", GameColors.TEXT_SUCCESS)
		capped_copy.glow_color = GameColors.TEXT_SUCCESS_GLOW
		var margin := _margins(5, 5, 0, 0)
		margin.add_child(capped_copy)
		_body.add_child(margin)

	# ACROSS THE SQUAD — the deployed roster sorted by this stat. The rail
	# can only show one stat per card; this is where a stat gets compared
	# without re-sorting the world.
	_body.add_child(_squad_section_header("ACROSS THE SQUAD"))
	var sorted_squad: Array[CharacterData] = _squad.duplicate()
	sorted_squad.sort_custom(func(a: CharacterData, b: CharacterData) -> bool:
		return int(a.get(stat_name)) > int(b.get(stat_name)))
	for member: CharacterData in sorted_squad:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		var row_margin := _margins(5, 5, 1, 0)
		row_margin.add_child(row)
		_body.add_child(row_margin)
		# The current unit's whole row lifts to PRIMARY; the rest read as
		# structural names with INFO values, same as the rail's readout.
		var is_current: bool = member == _character
		var name_label := GlowLabel.styled(member.character_name, UIManager.font_8px, 8,
				GameColors.TEXT_PRIMARY if is_current else GameColors.TEXT_SECONDARY,
				GameColors.TEXT_PRIMARY_GLOW if is_current else GameColors.TEXT_SECONDARY_GLOW)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var value_label := GlowLabel.styled(str(member.get(stat_name)),
				UIManager.font_8px, 8,
				GameColors.TEXT_PRIMARY if is_current else GameColors.TEXT_INFO,
				GameColors.TEXT_PRIMARY_GLOW if is_current else GameColors.TEXT_INFO_GLOW)
		row.add_child(value_label)


# =============================================================================
# INJURY LANE
# =============================================================================

func _build_injury_lane() -> void:
	var index: int = int(_key)
	if index < 0 or index >= _character.current_injuries.size():
		_build_summary_lane()
		return
	var injury: Injury = _character.current_injuries[index]
	var data: InjuryData = injury.get_data()
	var display: String = data.display_name if data != null else injury.injury_id.capitalize()
	var severity: String = "Major" if injury.severity == Enums.InjurySeverity.MAJOR else "Minor"

	var meta_parts: Array[String] = [severity]
	if data != null and data.affected_stat != "":
		meta_parts.append("affects %s" % UnitSheet.stat_label(data.affected_stat))
	meta_parts.append("%d battle%s to recover" % [injury.battles_remaining,
			"" if injury.battles_remaining == 1 else "s"])
	# The meta line carries the wound facts, so it speaks DANGER like the chip
	# that opened it; the description below stays PRIMARY reading copy.
	_build_detail_text(display, " · ".join(meta_parts),
			data.description if data != null else "",
			GameColors.TEXT_DANGER, GameColors.TEXT_DANGER_GLOW)


# =============================================================================
# SUMMARY LANE — nothing selected
# =============================================================================

func _build_summary_lane() -> void:
	if _character == null:
		return
	var equipped_count: int = 0
	for move: Move in _character.equipped_moves:
		if not UnitSheet.is_empty_move(move):
			equipped_count += 1
	# Nothing is selected, so nothing here is live — the meta reads MUTED
	# (RQD 2026-08-10, 3A first crack; muted semantic set pending Lawrence).
	_build_detail_text(_character.character_name,
			"%s · Lv %d · %d move%s equipped" % [
				Enums.get_class_display_name(_character.current_class), _character.level,
				equipped_count, "" if equipped_count == 1 else "s"],
			"Click a move, a passive, a stat, or an injury in the middle column. " +
			"Whatever you touch, this panel explains it — and becomes the place " +
			"you change it.",
			GameColors.TEXT_MUTED, GameColors.TEXT_MUTED_GLOW)

	_body.add_child(_squad_section_header("EQUIPPED"))
	for move: Move in _character.equipped_moves:
		if UnitSheet.is_empty_move(move):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var margin := _margins(5, 5, 1, 0)
		margin.add_child(row)
		_body.add_child(margin)
		_add_damage_icon(row, move.damage_type)
		_add_type_icon(row, move.element_type)
		var name_label := GlowLabel.styled(move.move_name, UIManager.font_8px, 8,
				GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)


# =============================================================================
# SHARED WIDGET HELPERS
# =============================================================================

func _detail_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var margin := _margins(5, 5, 4, 3)
	margin.add_child(box)
	_body.add_child(margin)
	return box


func _headline(text_value: String) -> GlowLabel:
	return GlowLabel.styled(text_value, UIManager.font_11px, 11,
			GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW)


func _body_copy(text_value: String) -> GlowLabel:
	var label := GlowLabel.styled(text_value, UIManager.font_8px, 8,
			GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _squad_section_header(title: String) -> Control:
	var margin := _margins(5, 5, 5, 1)
	margin.add_child(_dim_label(title))
	return margin


## Structural text — headers, metas, hints — wears the SECONDARY voice.
func _dim_label(text_value: String) -> GlowLabel:
	return GlowLabel.styled(text_value, UIManager.font_8px, 8,
			GameColors.TEXT_SECONDARY, GameColors.TEXT_SECONDARY_GLOW)


## Absence — empty banks, deselected summaries — wears MUTED.
func _muted_label(text_value: String) -> GlowLabel:
	return GlowLabel.styled(text_value, UIManager.font_8px, 8,
			GameColors.TEXT_MUTED, GameColors.TEXT_MUTED_GLOW)


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


func _add_damage_icon(parent: Container, damage_type: Enums.DamageType) -> void:
	var path: String = str(DAMAGE_ICON_PATHS.get(damage_type, ""))
	if path == "" or not ResourceLoader.exists(path):
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
