## Displays selected unit info in the left panel: name, HP, stats, move, status.
## PDA-style dark blue background with faction-colored text.
## 140x220px at reference resolution.
class_name UnitInfoPanelTest
extends PanelContainer


const PANEL_WIDTH: int = 140
const PANEL_HEIGHT: int = 220

var _tracked_unit: Unit = null

# Labels
var _name_label: Label = null
var _level_label: Label = null
var _faction_bar: ColorRect = null
var _hp_bar_background: ColorRect = null
var _hp_bar_fill: ColorRect = null
var _hp_label: Label = null
var _stats_label: Label = null
var _move_label: Label = null
var _status_label: Label = null


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null:
		var border: Variant = ui_manager.create_unit_info_border()
		if border != null:
			add_theme_stylebox_override("panel", border)
		else:
			add_theme_stylebox_override("panel", ui_manager.create_pda_style())

	_build_content()
	visible = false


# =============================================================================
# PUBLIC API
# =============================================================================

func show_unit(unit: Unit) -> void:
	if unit == null:
		hide_panel()
		return

	_tracked_unit = unit
	visible = true

	_update_name(unit)
	_update_level(unit)
	_update_faction_bar(unit)
	_update_hp(unit)
	_update_stats(unit)
	_update_move(unit)
	_update_status(unit)


func hide_panel() -> void:
	_tracked_unit = null
	visible = false


func refresh() -> void:
	if _tracked_unit != null and is_instance_valid(_tracked_unit):
		show_unit(_tracked_unit)


# =============================================================================
# DISPLAY UPDATES
# =============================================================================

func _update_name(unit: Unit) -> void:
	_name_label.text = unit.unit_name
	_name_label.add_theme_color_override("font_color", _get_faction_color(unit.faction))


func _update_level(unit: Unit) -> void:
	if unit.character_data != null:
		_level_label.text = "Lv. %d" % unit.character_data.level
	else:
		_level_label.text = ""


func _update_faction_bar(unit: Unit) -> void:
	_faction_bar.color = _get_faction_color(unit.faction)


func _update_hp(unit: Unit) -> void:
	if unit.character_data == null:
		return
	var current_hp: int = unit.current_hp
	var max_hp: int = unit.character_data.max_hp
	var health_percent: float = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0

	var bar_width: int = PANEL_WIDTH - 24  # Account for border (10px) + content padding (2px) per side
	_hp_bar_fill.size.x = int(health_percent * bar_width)
	_hp_bar_fill.color = GameColors.get_health_color(health_percent)
	_hp_label.text = "HP: %d/%d" % [current_hp, max_hp]


func _update_stats(unit: Unit) -> void:
	if unit.character_data == null:
		_stats_label.text = ""
		return
	var data: CharacterData = unit.character_data
	_stats_label.text = "STR:%d DEF:%d\nSPC:%d RES:%d\nSKL:%d AGI:%d\nATH:%d" % [
		data.strength, data.defense, data.special, data.resistance,
		data.skill, data.agility, data.athleticism]


func _update_move(unit: Unit) -> void:
	if unit.assigned_move != null:
		_move_label.text = "Move: %s (%d/%d)" % [
			unit.assigned_move.move_name, unit.assigned_move.current_uses,
			unit.assigned_move.max_uses]
	else:
		_move_label.text = "Move: (none)"


func _update_status(unit: Unit) -> void:
	if unit.active_status_effects.is_empty():
		_status_label.text = ""
		return
	var parts: Array[String] = []
	for effect: Variant in unit.active_status_effects:
		parts.append("%s(%dx)" % [effect.effect_type_name, effect.stacks])
	_status_label.text = ", ".join(parts)
	_status_label.add_theme_color_override("font_color", GameColors.TEXT_DANGER)


# =============================================================================
# BUILD CONTENT
# =============================================================================

func _build_content() -> void:
	var ui_manager: Node = get_node_or_null("/root/UIManager")

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	add_child(container)

	# Unit name (8px, faction-colored)
	_name_label = Label.new()
	if ui_manager != null:
		_name_label.add_theme_font_override("font", ui_manager.font_8px)
		_name_label.add_theme_font_size_override("font_size", 8)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_name_label)

	# Level (5px)
	_level_label = _create_small_label(ui_manager)
	container.add_child(_level_label)

	# Faction color bar (thin colored line)
	_faction_bar = ColorRect.new()
	_faction_bar.custom_minimum_size = Vector2(0, 2)
	_faction_bar.color = GameColors.PLAYER_UNIT
	_faction_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_faction_bar)

	# HP bar
	var hp_container := Control.new()
	hp_container.custom_minimum_size = Vector2(0, 8)
	hp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(hp_container)

	var bar_width: int = PANEL_WIDTH - 24
	_hp_bar_background = ColorRect.new()
	_hp_bar_background.color = Color(0.1, 0.1, 0.15, 1.0)
	_hp_bar_background.size = Vector2(bar_width, 6)
	_hp_bar_background.position = Vector2(0, 1)
	_hp_bar_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_container.add_child(_hp_bar_background)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = GameColors.HEALTH_FULL
	_hp_bar_fill.size = Vector2(bar_width, 6)
	_hp_bar_fill.position = Vector2(0, 1)
	_hp_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_container.add_child(_hp_bar_fill)

	# HP text (5px)
	_hp_label = _create_small_label(ui_manager)
	container.add_child(_hp_label)

	# Stats (5px, multiline)
	_stats_label = _create_small_label(ui_manager)
	container.add_child(_stats_label)

	# Assigned move (5px)
	_move_label = _create_small_label(ui_manager)
	container.add_child(_move_label)

	# Status effects (5px, wrapping)
	_status_label = _create_small_label(ui_manager)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	container.add_child(_status_label)


func _create_small_label(ui_manager: Node) -> Label:
	var label := Label.new()
	if ui_manager != null:
		label.add_theme_font_override("font", ui_manager.font_5px)
		label.add_theme_font_size_override("font_size", 5)
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _get_faction_color(faction: Enums.UnitFaction) -> Color:
	match faction:
		Enums.UnitFaction.PLAYER:
			return GameColors.PLAYER_UNIT
		Enums.UnitFaction.ENEMY:
			return GameColors.ENEMY_UNIT
		_:
			return GameColors.NEUTRAL_UNIT
