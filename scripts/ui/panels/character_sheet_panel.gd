## Full character sheet: portrait, identity, stats with bars and cap indicators, moves, passives.
## Used between fights in the roguelite flow and from squad overview.
## Fills the 640x360 reference viewport.
class_name CharacterSheetPanel
extends PanelContainer


signal closed

const SHEET_WIDTH: int = 640
const SHEET_HEIGHT: int = 360
const PORTRAIT_SIZE: int = 96
const STAT_BAR_MAX_WIDTH: int = 44
const STAT_BAR_HEIGHT: int = 4
const STAT_DISPLAY_MAX: float = 60.0  # All bars scale relative to this
const STAT_BAR_MIN_WIDTH: int = 3     # Minimum width for glow to render
const STAT_LABEL_WIDTH: int = 28
const STAT_VALUE_WIDTH: int = 42

# Maps display abbreviation -> CharacterData stat name
const STAT_DISPLAY_MAP: Dictionary = {
	"STR": "strength",
	"SPE": "special",
	"SKL": "skill",
	"AGI": "agility",
	"ATH": "athleticism",
	"DEF": "defense",
	"RES": "resistance",
}

var _character_data: CharacterData = null

# Header
var _portrait_rect: TextureRect = null
var _name_label: Label = null
var _level_label: Label = null
var _xp_label: Label = null
var _type_label: Label = null
var _class_label: Label = null
var _specialization_label: Label = null

# HP
var _hp_bar_background: ColorRect = null
var _hp_bar_fill: ColorRect = null
var _hp_label: Label = null

# Stats — each entry: { "name_label": Label, "value_label": Label, "bar_bg": ColorRect, "bar_base": ColorRect, "bar_bonus": ColorRect }
var _stat_rows: Dictionary = {}
var _constitution_label: Label = null
var _carry_label: Label = null

# Equipment
var _move_labels: Array[Label] = []
var _passive_label: Label = null


func _ready() -> void:
	custom_minimum_size = Vector2(SHEET_WIDTH, SHEET_HEIGHT)
	size = Vector2(SHEET_WIDTH, SHEET_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.HUD_PANEL_BACKGROUND
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)

	_build_content()
	visible = false


# =============================================================================
# PUBLIC API
# =============================================================================

func show_character(character_data: CharacterData) -> void:
	if character_data == null:
		return
	_character_data = character_data
	_update_all()
	visible = true


func hide_panel() -> void:
	_character_data = null
	visible = false
	closed.emit()


# =============================================================================
# DISPLAY UPDATES
# =============================================================================

func _update_all() -> void:
	var data := _character_data
	if data == null:
		return

	_update_portrait(data)
	_update_identity(data)
	_update_hp(data)
	_update_stats(data)
	_update_moves(data)
	_update_passives(data)


func _update_portrait(data: CharacterData) -> void:
	if data.portrait_path.is_empty():
		_portrait_rect.texture = null
		return
	var texture: Texture2D = load(data.portrait_path) as Texture2D
	_portrait_rect.texture = texture


func _update_identity(data: CharacterData) -> void:
	_name_label.text = data.character_name
	_level_label.text = "Lv. %d" % data.level

	var xp_needed: int = _xp_for_next_level(data.level)
	_xp_label.text = "XP: %d/%d" % [data.experience, xp_needed]

	var type_text: String = Enums.elemental_type_to_string(data.primary_type)
	if data.secondary_type != Enums.ElementalType.NONE:
		type_text += " / " + Enums.elemental_type_to_string(data.secondary_type)
	_type_label.text = type_text

	_class_label.text = Enums.get_class_display_name(data.current_class)

	# TODO: show free-form specialization stat picks when implemented
	_specialization_label.visible = false


func _update_hp(data: CharacterData) -> void:
	var current_hp: int = data.max_hp
	var max_hp: int = data.max_hp
	var cap: int = data.get_stat_cap("max_hp")
	var fill_ratio: float = clampf(float(current_hp) / float(cap), 0.0, 1.0)
	var at_cap: bool = data.is_at_stat_cap("max_hp")

	_hp_bar_fill.size.x = int(fill_ratio * _hp_bar_background.size.x)
	_hp_bar_fill.color = GameColors.TEXT_SUCCESS if at_cap else GameColors.get_health_color(1.0)

	if at_cap:
		_hp_label.text = "HP: %d/%d  MAX" % [current_hp, max_hp]
		_hp_label.add_theme_color_override("font_color", GameColors.TEXT_SUCCESS)
	else:
		_hp_label.text = "HP: %d/%d" % [current_hp, max_hp]
		_hp_label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)


func _update_stats(data: CharacterData) -> void:
	for display_key: String in STAT_DISPLAY_MAP:
		var stat_name: String = STAT_DISPLAY_MAP[display_key]
		var row: Dictionary = _stat_rows.get(display_key, {})
		if row.is_empty():
			continue

		var base_value: int = data.get_base_plus_growth(stat_name)
		var bonus_value: int = data.get_bonus_total(stat_name)
		var total_value: int = base_value + bonus_value
		var at_cap: bool = data.is_at_stat_cap(stat_name)

		# Value label: "6" or "6 (+2)"
		var value_label: Label = row["value_label"]
		if bonus_value != 0:
			var mod_text: String = "+%d" % bonus_value if bonus_value > 0 else "%d" % bonus_value
			value_label.text = "%d (%s)" % [total_value, mod_text]
		else:
			value_label.text = "%d" % total_value

		# Color: green at cap, red for negative bonus, green for positive, default otherwise
		var name_label: Label = row["name_label"]
		if at_cap:
			value_label.add_theme_color_override("font_color", GameColors.TEXT_SUCCESS)
			name_label.add_theme_color_override("font_color", GameColors.TEXT_SUCCESS)
		elif bonus_value > 0:
			value_label.add_theme_color_override("font_color", GameColors.TEXT_SUCCESS)
			name_label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
		elif bonus_value < 0:
			value_label.add_theme_color_override("font_color", GameColors.TEXT_DANGER)
			name_label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
		else:
			value_label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
			name_label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)

		# Base bar width (clamped to min 3px for glow, 0 if stat is 0)
		var base_pixels: int = 0
		if base_value > 0:
			base_pixels = maxi(roundi(base_value / STAT_DISPLAY_MAX * STAT_BAR_MAX_WIDTH), STAT_BAR_MIN_WIDTH)

		# Bonus bar width (clamped to min 3px for glow, 0 if bonus is 0)
		var bonus_pixels: int = 0
		if bonus_value > 0:
			bonus_pixels = maxi(roundi(bonus_value / STAT_DISPLAY_MAX * STAT_BAR_MAX_WIDTH), STAT_BAR_MIN_WIDTH)

		# Base bar
		var bar_base: ColorRect = row["bar_base"]
		bar_base.size.x = base_pixels
		bar_base.color = GameColors.TEXT_SUCCESS if at_cap else GameColors.PLAYER_UNIT
		bar_base.visible = base_pixels > 0

		# Bonus bar — shift 1px left to overlap with base bar's glow edge,
		# avoiding a visible gap between glow effects. Skip overlap if base
		# is 0 since there's no base glow to connect to.
		var bar_bonus: ColorRect = row["bar_bonus"]
		var overlap: int = 1 if base_pixels > 0 else 0
		bar_bonus.position.x = base_pixels - overlap
		bar_bonus.size.x = bonus_pixels
		bar_bonus.visible = bonus_pixels > 0

	_constitution_label.text = "CON  %d" % data.constitution
	_carry_label.text = "CAR  %d" % data.carry


func _update_moves(data: CharacterData) -> void:
	for i: int in range(4):
		var label: Label = _move_labels[i]
		if i < data.equipped_moves.size():
			var move: Move = data.equipped_moves[i]
			var type_str: String = Enums.elemental_type_to_string(move.element_type)
			var dmg_str: String = "Phys" if move.damage_type == Enums.DamageType.PHYSICAL else "Spec"
			label.text = "%s  %s/%s  Pw:%d  PP:%d/%d" % [
				move.move_name, type_str, dmg_str,
				move.base_power, move.current_uses, move.max_uses]
			label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
		else:
			label.text = "---"
			label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)


func _update_passives(data: CharacterData) -> void:
	if data.equipped_passives.is_empty() and data.base_pool_passives.is_empty():
		_passive_label.text = "(none)"
		_passive_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
		return

	var names: Array = []
	if not data.equipped_passives.is_empty():
		for passive: Variant in data.equipped_passives:
			if passive is String:
				names.append(passive)
			elif passive != null and "passive_name" in passive:
				names.append(passive.passive_name)
	else:
		for passive_name: String in data.base_pool_passives:
			names.append(passive_name)

	_passive_label.text = "  |  ".join(names)
	_passive_label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)


# =============================================================================
# HELPERS
# =============================================================================


func _xp_for_next_level(level: int) -> int:
	return level * 100


# =============================================================================
# BUILD CONTENT
# =============================================================================

func _build_content() -> void:
	var ui_manager: Node = get_node_or_null("/root/UIManager")

	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 12)
	main_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_row)

	# --- Left column: portrait + identity ---
	var left_column := VBoxContainer.new()
	left_column.add_theme_constant_override("separation", 4)
	left_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_row.add_child(left_column)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_column.add_child(_portrait_rect)
	GameColors.add_portrait_border(_portrait_rect)

	_type_label = _create_small_label(ui_manager)
	_type_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	_type_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_type_label.custom_minimum_size.x = PORTRAIT_SIZE
	left_column.add_child(_type_label)

	_class_label = _create_small_label(ui_manager)
	_class_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	left_column.add_child(_class_label)

	_specialization_label = _create_small_label(ui_manager)
	_specialization_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	left_column.add_child(_specialization_label)

	_constitution_label = _create_small_label(ui_manager)
	left_column.add_child(_constitution_label)

	_carry_label = _create_small_label(ui_manager)
	left_column.add_child(_carry_label)

	var left_spacer := Control.new()
	left_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_column.add_child(left_spacer)

	# --- Right column: everything else ---
	var right_column := VBoxContainer.new()
	right_column.add_theme_constant_override("separation", 3)
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_row.add_child(right_column)

	# Name row
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_column.add_child(name_row)

	_name_label = Label.new()
	if ui_manager != null:
		_name_label.add_theme_font_override("font", ui_manager.font_11px)
		_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.add_theme_color_override("font_color", GameColors.PLAYER_UNIT)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(_name_label)

	_level_label = _create_body_label(ui_manager)
	_level_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	name_row.add_child(_level_label)

	_xp_label = _create_small_label(ui_manager)
	_xp_label.size_flags_vertical = Control.SIZE_SHRINK_END
	name_row.add_child(_xp_label)

	right_column.add_child(_create_separator())

	# HP bar (shows fill relative to cap, not just current/max)
	var hp_section := Control.new()
	hp_section.custom_minimum_size = Vector2(0, 10)
	hp_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_column.add_child(hp_section)

	var hp_bar_width: int = 400
	_hp_bar_background = ColorRect.new()
	_hp_bar_background.color = Color(0.1, 0.1, 0.15, 1.0)
	_hp_bar_background.size = Vector2(hp_bar_width, 6)
	_hp_bar_background.position = Vector2(0, 2)
	_hp_bar_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_section.add_child(_hp_bar_background)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = GameColors.HEALTH_FULL
	_hp_bar_fill.size = Vector2(hp_bar_width, 6)
	_hp_bar_fill.position = Vector2(0, 2)
	_hp_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_section.add_child(_hp_bar_fill)

	_hp_label = _create_small_label(ui_manager)
	right_column.add_child(_hp_label)

	right_column.add_child(_create_separator())

	# Stats: two columns of stat rows with bars
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 16)
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_column.add_child(stats_row)

	var left_stats := VBoxContainer.new()
	left_stats.add_theme_constant_override("separation", 2)
	left_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.add_child(left_stats)

	var right_stats := VBoxContainer.new()
	right_stats.add_theme_constant_override("separation", 2)
	right_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.add_child(right_stats)

	for key: String in ["STR", "SPE", "SKL", "ATH"]:
		_stat_rows[key] = _build_stat_row(key, ui_manager, left_stats)

	for key: String in ["DEF", "RES", "AGI"]:
		_stat_rows[key] = _build_stat_row(key, ui_manager, right_stats)

	right_column.add_child(_create_separator())

	# Moves
	var moves_header := _create_small_label(ui_manager)
	moves_header.text = "EQUIPPED MOVES"
	moves_header.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	right_column.add_child(moves_header)

	for i: int in range(4):
		var label := _create_small_label(ui_manager)
		_move_labels.append(label)
		right_column.add_child(label)

	right_column.add_child(_create_separator())

	# Passives
	var passives_header := _create_small_label(ui_manager)
	passives_header.text = "EQUIPPED PASSIVES"
	passives_header.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	right_column.add_child(passives_header)

	_passive_label = _create_small_label(ui_manager)
	_passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	right_column.add_child(_passive_label)


func _build_stat_row(display_key: String, ui_manager: Node, parent: VBoxContainer) -> Dictionary:
	# Each stat row: [NAME] [████▓▓░░░░] [VALUE (+mod)]
	# ████ = base+growth bar, ▓▓ = bonus bar (allocated/bond/passive/status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	# Stat name label (fixed width)
	var name_label := _create_small_label(ui_manager)
	name_label.text = display_key
	name_label.custom_minimum_size.x = STAT_LABEL_WIDTH
	row.add_child(name_label)

	# Bar container
	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(STAT_BAR_MAX_WIDTH, STAT_BAR_HEIGHT + 4)
	bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar_container)

	var bar_y: float = (STAT_BAR_HEIGHT + 4 - STAT_BAR_HEIGHT) / 2.0

	var bar_background := ColorRect.new()
	bar_background.color = Color(0.1, 0.1, 0.15, 1.0)
	bar_background.size = Vector2(STAT_BAR_MAX_WIDTH, STAT_BAR_HEIGHT)
	bar_background.position = Vector2(0, bar_y)
	bar_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bar_background)

	# Bonus bar renders behind the base bar
	var bar_bonus := ColorRect.new()
	bar_bonus.color = GameColors.TEXT_SECONDARY
	bar_bonus.size = Vector2(0, STAT_BAR_HEIGHT)
	bar_bonus.position = Vector2(0, bar_y)
	bar_bonus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bonus.visible = false
	bar_container.add_child(bar_bonus)

	# Base bar renders on top
	var bar_base := ColorRect.new()
	bar_base.color = GameColors.PLAYER_UNIT
	bar_base.size = Vector2(0, STAT_BAR_HEIGHT)
	bar_base.position = Vector2(0, bar_y)
	bar_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bar_base)

	# Value + modifier label (fixed width)
	var value_label := _create_small_label(ui_manager)
	value_label.custom_minimum_size.x = STAT_VALUE_WIDTH
	row.add_child(value_label)

	return {
		"name_label": name_label,
		"value_label": value_label,
		"bar_bg": bar_background,
		"bar_base": bar_base,
		"bar_bonus": bar_bonus,
	}


func _create_body_label(ui_manager: Node) -> Label:
	var label := Label.new()
	if ui_manager != null:
		label.add_theme_font_override("font", ui_manager.font_8px)
		label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _create_small_label(ui_manager: Node) -> Label:
	var label := Label.new()
	if ui_manager != null:
		label.add_theme_font_override("font", ui_manager.font_5px)
		label.add_theme_font_size_override("font_size", 5)
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _create_separator() -> ColorRect:
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = GameColors.with_alpha(GameColors.TEXT_SECONDARY, 0.3)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sep
