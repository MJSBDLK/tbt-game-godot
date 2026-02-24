## Developer HUD for playtesting. Displays selected unit info, terrain info,
## move list, and controls hint. Built in code (no .tscn) for rapid iteration.
## Will be replaced by the full UI system in Phase 5.
class_name BattleHUD
extends CanvasLayer


const PANEL_WIDTH: int = 140
const FONT_SIZE_NORMAL: int = 7
const FONT_SIZE_TITLE: int = 8
const FONT_SIZE_SMALL: int = 6
const PANEL_MARGIN: int = 4
const LINE_HEIGHT: int = 10

# Left panel — unit info
var _left_panel: PanelContainer = null
var _unit_name_label: Label = null
var _unit_hp_bar_background: ColorRect = null
var _unit_hp_bar_fill: ColorRect = null
var _unit_hp_label: Label = null
var _unit_stats_label: Label = null
var _unit_move_label: Label = null
var _unit_status_label: Label = null

# Left panel — terrain info
var _terrain_panel: PanelContainer = null
var _terrain_name_label: Label = null
var _terrain_cost_label: Label = null
var _terrain_defense_label: Label = null

# Right panel — move list
var _right_panel: PanelContainer = null
var _move_labels: Array[Label] = []
var _controls_label: Label = null

var _tracked_unit: Unit = null

## Set to true to show the debug move list / controls panel on the right side.
## Disabled by default since Phase 4 ActionMenuManager handles move selection.
var show_debug_move_panel: bool = false


func _ready() -> void:
	layer = 10
	_build_left_panel()
	_build_terrain_panel()
	_build_right_panel()
	hide_unit_info()
	hide_terrain_info()
	_hide_right_panel()


# =============================================================================
# PUBLIC API
# =============================================================================

func show_unit_info(unit: Unit) -> void:
	if unit == null:
		hide_unit_info()
		return

	_tracked_unit = unit
	_left_panel.visible = true

	# Name with faction color
	var faction_color: Color = _get_faction_color(unit.faction)
	_unit_name_label.add_theme_color_override("font_color", faction_color)
	_unit_name_label.text = unit.unit_name

	_update_hp_display(unit)
	_update_stats_display(unit)
	_update_move_display(unit)
	_update_status_display(unit)
	update_move_list(unit)


func hide_unit_info() -> void:
	_tracked_unit = null
	_left_panel.visible = false
	_hide_right_panel()


func show_terrain_info(tile: Tile) -> void:
	if tile == null:
		hide_terrain_info()
		return

	_terrain_panel.visible = true

	# Terrain name
	var terrain_name: String = tile.terrain_type_name
	_terrain_name_label.text = terrain_name.capitalize()

	# Movement cost
	var move_cost: float = tile.get_movement_cost_for_unit()
	if move_cost >= 99.0:
		_terrain_cost_label.text = "Move: Impassable"
		_terrain_cost_label.add_theme_color_override("font_color", GameColors.TEXT_DANGER)
	elif move_cost > 1.0:
		_terrain_cost_label.text = "Move: %.1f" % move_cost
		_terrain_cost_label.add_theme_color_override("font_color", GameColors.TEXT_WARNING)
	else:
		_terrain_cost_label.text = "Move: %.1f" % move_cost
		_terrain_cost_label.add_theme_color_override("font_color", GameColors.TEXT_SUCCESS)

	# Defense modifier
	var defense_mod: float = tile.get_defense_modifier_for_unit()
	if defense_mod > 0.0:
		_terrain_defense_label.text = "Def: +%d" % int(defense_mod)
		_terrain_defense_label.add_theme_color_override("font_color", GameColors.TEXT_SUCCESS)
	elif defense_mod < 0.0:
		_terrain_defense_label.text = "Def: %d" % int(defense_mod)
		_terrain_defense_label.add_theme_color_override("font_color", GameColors.TEXT_DANGER)
	else:
		_terrain_defense_label.text = "Def: --"
		_terrain_defense_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)


func hide_terrain_info() -> void:
	_terrain_panel.visible = false


func update_move_list(unit: Unit) -> void:
	if not show_debug_move_panel:
		_hide_right_panel()
		return
	if unit == null or unit.character_data == null:
		_hide_right_panel()
		return

	_right_panel.visible = true
	var moves: Array[Move] = unit.character_data.equipped_moves

	for index: int in range(4):
		if index >= _move_labels.size():
			break

		if index < moves.size() and moves[index] != null:
			var move: Move = moves[index]
			var is_assigned := (unit.assigned_move == move)
			var prefix := "> " if is_assigned else "  "
			_move_labels[index].text = "%s%d: %s (%d/%d)" % [
				prefix, index + 1, move.move_name, move.current_uses, move.max_uses]

			if is_assigned:
				_move_labels[index].add_theme_color_override("font_color", GameColors.TEXT_WARNING)
			else:
				_move_labels[index].add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
		else:
			_move_labels[index].text = "  %d: --" % (index + 1)
			_move_labels[index].add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)


func refresh() -> void:
	if _tracked_unit != null and is_instance_valid(_tracked_unit):
		show_unit_info(_tracked_unit)


# =============================================================================
# DISPLAY UPDATES
# =============================================================================

func _update_hp_display(unit: Unit) -> void:
	var current_hp: int = unit.current_hp
	var max_hp: int = unit.character_data.max_hp
	var health_percent: float = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0

	_unit_hp_bar_fill.size.x = int(health_percent * (PANEL_WIDTH - PANEL_MARGIN * 2 - 4))
	_unit_hp_bar_fill.color = GameColors.get_health_color(health_percent)
	_unit_hp_label.text = "HP: %d/%d" % [current_hp, max_hp]


func _update_stats_display(unit: Unit) -> void:
	var data: CharacterData = unit.character_data
	_unit_stats_label.text = "STR:%d DEF:%d\nSPC:%d RES:%d\nSKL:%d AGI:%d\nATH:%d" % [
		data.strength, data.defense, data.special, data.resistance,
		data.skill, data.agility, data.athleticism]


func _update_move_display(unit: Unit) -> void:
	if unit.assigned_move != null:
		_unit_move_label.text = "Move: %s (%d/%d)" % [
			unit.assigned_move.move_name, unit.assigned_move.current_uses, unit.assigned_move.max_uses]
	else:
		_unit_move_label.text = "Move: (none)"


func _update_status_display(unit: Unit) -> void:
	if unit.active_status_effects.is_empty():
		_unit_status_label.text = ""
		return

	var parts: Array[String] = []
	for effect: Variant in unit.active_status_effects:
		parts.append("%s(%dt)" % [effect.effect_type_name, effect.remaining_turns])
	_unit_status_label.text = ", ".join(parts)
	_unit_status_label.add_theme_color_override("font_color", GameColors.TEXT_DANGER)


# =============================================================================
# BUILD UI
# =============================================================================

func _build_left_panel() -> void:
	_left_panel = _create_panel(0, 0, PANEL_WIDTH, 180)

	var container := VBoxContainer.new()
	container.position = Vector2(PANEL_MARGIN, PANEL_MARGIN)
	container.size = Vector2(PANEL_WIDTH - PANEL_MARGIN * 2, 170)
	_left_panel.add_child(container)

	_unit_name_label = _create_label(FONT_SIZE_TITLE)
	_unit_name_label.text = "Unit Name"
	container.add_child(_unit_name_label)

	# HP bar
	var hp_container := Control.new()
	hp_container.custom_minimum_size = Vector2(PANEL_WIDTH - PANEL_MARGIN * 2, 12)
	container.add_child(hp_container)

	_unit_hp_bar_background = ColorRect.new()
	_unit_hp_bar_background.color = Color(0.15, 0.15, 0.15, 1.0)
	_unit_hp_bar_background.size = Vector2(PANEL_WIDTH - PANEL_MARGIN * 2 - 4, 8)
	_unit_hp_bar_background.position = Vector2(0, 2)
	_unit_hp_bar_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_container.add_child(_unit_hp_bar_background)

	_unit_hp_bar_fill = ColorRect.new()
	_unit_hp_bar_fill.color = GameColors.HEALTH_FULL
	_unit_hp_bar_fill.size = Vector2(PANEL_WIDTH - PANEL_MARGIN * 2 - 4, 8)
	_unit_hp_bar_fill.position = Vector2(0, 2)
	_unit_hp_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_container.add_child(_unit_hp_bar_fill)

	_unit_hp_label = _create_label(FONT_SIZE_SMALL)
	container.add_child(_unit_hp_label)

	# Stats
	_unit_stats_label = _create_label(FONT_SIZE_SMALL)
	container.add_child(_unit_stats_label)

	# Assigned move
	_unit_move_label = _create_label(FONT_SIZE_SMALL)
	container.add_child(_unit_move_label)

	# Status effects
	_unit_status_label = _create_label(FONT_SIZE_SMALL)
	_unit_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	container.add_child(_unit_status_label)


func _build_terrain_panel() -> void:
	_terrain_panel = _create_panel(0, 184, PANEL_WIDTH, 60)

	var container := VBoxContainer.new()
	container.position = Vector2(PANEL_MARGIN, PANEL_MARGIN)
	container.size = Vector2(PANEL_WIDTH - PANEL_MARGIN * 2, 50)
	_terrain_panel.add_child(container)

	_terrain_name_label = _create_label(FONT_SIZE_TITLE)
	container.add_child(_terrain_name_label)

	_terrain_cost_label = _create_label(FONT_SIZE_SMALL)
	container.add_child(_terrain_cost_label)

	_terrain_defense_label = _create_label(FONT_SIZE_SMALL)
	container.add_child(_terrain_defense_label)


func _build_right_panel() -> void:
	_right_panel = _create_panel(640 - PANEL_WIDTH, 0, PANEL_WIDTH, 140)

	var container := VBoxContainer.new()
	container.position = Vector2(PANEL_MARGIN, PANEL_MARGIN)
	container.size = Vector2(PANEL_WIDTH - PANEL_MARGIN * 2, 130)
	_right_panel.add_child(container)

	# Header
	var header := _create_label(FONT_SIZE_TITLE)
	header.text = "Moves"
	container.add_child(header)

	# 4 move slots
	for index: int in range(4):
		var move_label := _create_label(FONT_SIZE_NORMAL)
		move_label.text = "  %d: --" % (index + 1)
		container.add_child(move_label)
		_move_labels.append(move_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	container.add_child(spacer)

	# Controls hint
	_controls_label = _create_label(FONT_SIZE_SMALL)
	_controls_label.text = "LClick: Select\nClick WP: Move\nEsc: Undo/Cancel\n1-4: Assign Move"
	_controls_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	_controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	container.add_child(_controls_label)


func _hide_right_panel() -> void:
	_right_panel.visible = false


# =============================================================================
# HELPERS
# =============================================================================

func _create_panel(panel_x: int, panel_y: int, width: int, height: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = Vector2(panel_x, panel_y)
	panel.size = Vector2(width, height)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Style: dark semi-transparent background
	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.MENU_BACKGROUND
	style.border_color = GameColors.MENU_BORDER
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)

	add_child(panel)
	return panel


func _create_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
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
