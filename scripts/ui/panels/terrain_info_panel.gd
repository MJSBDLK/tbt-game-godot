## Displays hovered tile terrain info in the left panel: name, move cost, defense mod.
## PDA-style dark blue background. Shown on tile hover, hidden when leaving tiles.
## 140x140px at reference resolution.
class_name TerrainInfoPanel
extends PanelContainer


const PANEL_WIDTH: int = 140
const PANEL_HEIGHT: int = 140

var _terrain_name_label: Label = null
var _move_cost_label: Label = null
var _defense_label: Label = null


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null:
		var border: Variant = ui_manager.create_terrain_info_border()
		if border != null:
			add_theme_stylebox_override("panel", border)
		else:
			add_theme_stylebox_override("panel", ui_manager.create_pda_style())

	_build_content()
	visible = false


# =============================================================================
# PUBLIC API
# =============================================================================

func show_tile(tile: Tile) -> void:
	if tile == null:
		hide_panel()
		return

	visible = true

	# Terrain name
	_terrain_name_label.text = tile.terrain_type_name.capitalize()

	# Movement cost
	var move_cost: float = tile.get_movement_cost_for_unit()
	if move_cost >= 99.0:
		_move_cost_label.text = "Move: Impassable"
		_move_cost_label.add_theme_color_override("font_color", GameColors.TEXT_DANGER)
	elif move_cost > 1.0:
		_move_cost_label.text = "Move: %.1f" % move_cost
		_move_cost_label.add_theme_color_override("font_color", GameColors.TEXT_WARNING)
	else:
		_move_cost_label.text = "Move: %.1f" % move_cost
		_move_cost_label.add_theme_color_override("font_color", GameColors.TEXT_SUCCESS)

	# Defense modifier
	var defense_mod: float = tile.get_defense_modifier_for_unit()
	if defense_mod > 0.0:
		_defense_label.text = "Def: +%d" % int(defense_mod)
		_defense_label.add_theme_color_override("font_color", GameColors.TEXT_SUCCESS)
	elif defense_mod < 0.0:
		_defense_label.text = "Def: %d" % int(defense_mod)
		_defense_label.add_theme_color_override("font_color", GameColors.TEXT_DANGER)
	else:
		_defense_label.text = "Def: --"
		_defense_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)


func hide_panel() -> void:
	visible = false


# =============================================================================
# BUILD CONTENT
# =============================================================================

func _build_content() -> void:
	var ui_manager: Node = get_node_or_null("/root/UIManager")

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	add_child(container)

	# Terrain name (8px)
	_terrain_name_label = Label.new()
	if ui_manager != null:
		_terrain_name_label.add_theme_font_override("font", ui_manager.font_8px)
		_terrain_name_label.add_theme_font_size_override("font_size", 8)
	_terrain_name_label.add_theme_color_override("font_color", GameColors.PDA_TEXT_PRIMARY)
	_terrain_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_terrain_name_label)

	# Movement cost (5px)
	_move_cost_label = _create_info_label(ui_manager)
	container.add_child(_move_cost_label)

	# Defense modifier (5px)
	_defense_label = _create_info_label(ui_manager)
	container.add_child(_defense_label)


func _create_info_label(ui_manager: Node) -> Label:
	var label := Label.new()
	if ui_manager != null:
		label.add_theme_font_override("font", ui_manager.font_5px)
		label.add_theme_font_size_override("font_size", 5)
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
