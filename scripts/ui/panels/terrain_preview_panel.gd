## Displays hovered tile terrain info: name, terrain icon, and a grid of
## movement/defense/avoid/attack modifiers with per-type overrides.
## Replaces the old TerrainInfoPanel.
class_name TerrainPreviewPanel
extends Control


# Scene node references (set in _ready via node paths)
var _terrain_name_label: Label = null
var _terrain_icon: TextureRect = null
var _grid: GridContainer = null

# Elemental type icon directory
const TYPE_ICON_DIR := "res://art/sprites/ui/elemental_type_icons_10x10/"

# The scene used for text cells in the grid
var _text_container_scene: PackedScene = null
var _current_terrain_type: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(140, 140)
	size = Vector2(140, 140)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_tree().current_scene != self:
		visible = false

	_text_container_scene = load("res://art/sprites/ui/ui_text_container.tscn")

	var vbox: VBoxContainer = $ContentMargin/VBoxContainer
	var terrain_container: HBoxContainer = vbox.get_node("TerrainContainer")
	_terrain_icon = terrain_container.get_node("TextureRect") as TextureRect
	_terrain_name_label = terrain_container.get_node("MarginContainer/Label") as Label

	var grid_margin: MarginContainer = vbox.get_node("MarginContainer")
	_grid = grid_margin.get_node("GridContainer") as GridContainer


# =============================================================================
# PUBLIC API
# =============================================================================

func show_tile(tile: Tile) -> void:
	if tile == null:
		hide_panel()
		return
	if tile.terrain_type_name == _current_terrain_type and visible:
		return
	_current_terrain_type = tile.terrain_type_name

	visible = true
	_terrain_name_label.text = tile.terrain_type_name.capitalize()

	var tile_texture := tile.get_tile_texture()
	if tile_texture:
		_terrain_icon.texture = tile_texture

	# Clear dynamic rows (everything after the first 5 header icons)
	var children: Array[Node] = _grid.get_children()
	for i: int in range(children.size() - 1, 4, -1):
		children[i].queue_free()

	# Get terrain definition for override data
	var terrain_manager: Node = get_node_or_null("/root/TerrainDataManager")
	if terrain_manager == null:
		return

	var definition: Variant = terrain_manager.get_terrain_definition(tile.terrain_type_name)

	# Default row
	var default_move: float = tile.get_movement_cost_for_unit()
	var default_def: float = tile.get_defense_multiplier_for_unit()
	var default_avoid: float = tile.get_avoid_multiplier_for_unit()
	var default_atk: float = tile.get_attack_multiplier_for_unit()

	_add_row(null, default_move, default_def, default_avoid, default_atk)

	# Override rows — check each unit type for differences
	if definition != null:
		var override_types: Array[String] = _get_override_types(definition)
		for unit_type: String in override_types:
			var move: float = terrain_manager.get_movement_cost(tile.terrain_type_name, unit_type)
			var def_mod: float = terrain_manager.get_defense_multiplier(tile.terrain_type_name, unit_type)
			var avoid: float = terrain_manager.get_avoid_multiplier(tile.terrain_type_name, unit_type)
			var atk: float = terrain_manager.get_attack_multiplier(tile.terrain_type_name, unit_type)

			# Only add row if at least one value differs from default
			if not is_equal_approx(move, default_move) or \
					not is_equal_approx(def_mod, default_def) or \
					not is_equal_approx(avoid, default_avoid) or \
					not is_equal_approx(atk, default_atk):
				_add_row(unit_type, move, def_mod, avoid, atk)


func hide_panel() -> void:
	TapTooltip.dismiss()
	visible = false
	_current_terrain_type = ""


# =============================================================================
# GRID ROW BUILDING
# =============================================================================

func _add_row(unit_type: Variant, move_cost: float, defense: float, avoid: float, attack: float) -> void:
	# Column 1: type icon or "default" placeholder
	if unit_type == null:
		var placeholder := _create_icon_cell(load("res://art/sprites/ui/placeholder_10x10.png"))
		placeholder.tooltip_text = "Default type:\nAll types have these attributes unless otherwise specified."
		_add_tap_tooltip(placeholder)
		_grid.add_child(placeholder)
	else:
		var element_type: Enums.ElementalType = _unit_type_string_to_enum(unit_type)
		var enum_name: String = Enums.ElementalType.keys()[element_type].to_lower()
		var icon_path: String = TYPE_ICON_DIR + enum_name + ".png"
		var icon_texture: Texture2D = load(icon_path) as Texture2D
		var icon_cell := _create_icon_cell(icon_texture)
		icon_cell.tooltip_text = "Type: %s" % unit_type
		_add_tap_tooltip(icon_cell)
		_grid.add_child(icon_cell)

	# Column 2: movement cost (color-coded, inverted — lower is better)
	var move_color: Color = GameColors.get_movement_cost_color(move_cost)
	var move_glow: Color = GameColors.get_movement_cost_bg_color(move_cost)
	_add_value_cell(str(ceili(move_cost)), move_color, move_glow)

	# Column 3: defense multiplier (color-coded)
	_add_multiplier_cell(defense)

	# Column 4: avoid multiplier (color-coded)
	_add_multiplier_cell(avoid)

	# Column 5: attack multiplier (color-coded)
	_add_multiplier_cell(attack)


func _add_value_cell(text: String, color: Color, glow: Color = Color(-1, -1, -1)) -> void:
	if _text_container_scene != null:
		var cell: Control = _text_container_scene.instantiate()
		var label: Label = cell.get_node("Label") as Label
		label.text = text
		label.add_theme_color_override("font_color", color)
		if glow.r >= 0.0 and label is GlowLabel:
			label.glow_color = glow
		_grid.add_child(cell)
	else:
		var label := Label.new()
		label.text = text
		label.add_theme_color_override("font_color", color)
		_grid.add_child(label)


func _add_multiplier_cell(value: float) -> void:
	var text: String
	if is_equal_approx(value, 1.0):
		text = "—"
	else:
		text = "%.1f" % value
	var color: Color = GameColors.get_terrain_modifier_color(value)
	var glow: Color = GameColors.get_terrain_modifier_bg_color(value)
	_add_value_cell(text, color, glow)


func _create_icon_cell(texture: Texture2D) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 0)
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(10, 10)
	tex_rect.texture = texture
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	margin.add_child(tex_rect)
	return margin


func _add_tap_tooltip(control: Control) -> void:
	var tooltip := TapTooltip.new()
	control.add_child(tooltip)


# =============================================================================
# HELPERS
# =============================================================================

## Collects all unit type strings that have overrides in any property.
func _get_override_types(definition: Variant) -> Array[String]:
	var types: Array[String] = []
	var properties: Array[String] = ["move_penalty", "attack_multiplier", "defense_multiplier", "avoid_multiplier", "walkable"]
	for prop_name: String in properties:
		var prop: Variant = definition.get(prop_name)
		if prop != null and "unit_type_overrides" in prop:
			for unit_type: String in prop.unit_type_overrides.keys():
				if unit_type not in types:
					types.append(unit_type)
	return types


func _unit_type_string_to_enum(unit_type: String) -> Enums.ElementalType:
	match unit_type:
		"Fire": return Enums.ElementalType.FIRE
		"Electric": return Enums.ElementalType.ELECTRIC
		"Plant": return Enums.ElementalType.PLANT
		"Ice", "Cold": return Enums.ElementalType.COLD
		"Air": return Enums.ElementalType.AIR
		"Gravity": return Enums.ElementalType.GRAVITY
		"Void": return Enums.ElementalType.VOID
		"Occult": return Enums.ElementalType.OCCULT
		"Chivalric": return Enums.ElementalType.CHIVALRIC
		"Heraldic": return Enums.ElementalType.HERALDIC
		"Gentry": return Enums.ElementalType.GENTRY
		"Robo": return Enums.ElementalType.ROBO
		"Obsidian": return Enums.ElementalType.OBSIDIAN
		"Simple": return Enums.ElementalType.SIMPLE
		_: return Enums.ElementalType.NONE
