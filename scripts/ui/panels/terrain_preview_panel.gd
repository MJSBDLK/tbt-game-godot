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

	# Clear dynamic rows (everything after the first 5 header icons). Freed
	# immediately (not queue_free) so the height fit below measures only the
	# rows actually being shown, not last hover's corpses.
	var children: Array[Node] = _grid.get_children()
	for i: int in range(children.size() - 1, 4, -1):
		_grid.remove_child(children[i])
		children[i].free()

	# Get terrain definition for override data
	var terrain_manager: Node = get_node_or_null("/root/TerrainDataManager")
	if terrain_manager == null:
		return

	var definition: Variant = terrain_manager.get_terrain_definition(tile.terrain_type_name)

	# Default row. Defense carries the melee/ranged style split (Crater et al.)
	# folded in: what's shown is the COMBINED base×style multiplier per style,
	# because that's what the defender actually experiences.
	var default_walkable: bool = tile.can_unit_move_to()
	var default_move: float = tile.get_movement_cost_for_unit()
	var default_def: float = tile.get_defense_multiplier_for_unit()
	var default_def_melee: float = default_def * tile.get_defense_vs_melee_multiplier_for_unit()
	var default_def_ranged: float = default_def * tile.get_defense_vs_ranged_multiplier_for_unit()
	var default_avoid: float = tile.get_avoid_multiplier_for_unit()
	var default_atk: float = tile.get_attack_multiplier_for_unit()

	_add_row(null, default_walkable, default_move, default_def_melee, default_def_ranged,
			default_avoid, default_atk)

	# Override rows — check each unit type for differences
	if definition != null:
		var override_types: Array[String] = _get_override_types(definition)
		for unit_type: String in override_types:
			var walkable: bool = terrain_manager.can_unit_walk_on_terrain(tile.terrain_type_name, unit_type)
			var move: float = terrain_manager.get_movement_cost(tile.terrain_type_name, unit_type)
			var def_mod: float = terrain_manager.get_defense_multiplier(tile.terrain_type_name, unit_type)
			var def_melee: float = def_mod * terrain_manager.get_defense_multiplier_vs_melee(
					tile.terrain_type_name, unit_type)
			var def_ranged: float = def_mod * terrain_manager.get_defense_multiplier_vs_ranged(
					tile.terrain_type_name, unit_type)
			var avoid: float = terrain_manager.get_avoid_multiplier(tile.terrain_type_name, unit_type)
			var atk: float = terrain_manager.get_attack_multiplier(tile.terrain_type_name, unit_type)

			# Add a row if ANY attribute differs from default — including
			# walkability. Without the walkability check, a type that can cross
			# an otherwise-impassable terrain (fliers over a Wall) whose
			# move/def/avoid/atk happen to match the default would be silently
			# dropped, hiding the one thing that makes it special.
			if walkable != default_walkable or \
					not is_equal_approx(move, default_move) or \
					not is_equal_approx(def_melee, default_def_melee) or \
					not is_equal_approx(def_ranged, default_def_ranged) or \
					not is_equal_approx(avoid, default_avoid) or \
					not is_equal_approx(atk, default_atk):
				_add_row(unit_type, walkable, move, def_melee, def_ranged, avoid, atk)

	_fit_height_to_rows()


## 140x140 is the design size, but terrains with several per-type override rows
## (a 4-entry modifier) need more. Grow the panel downward so the icon+title
## stay pinned at the top and the anchored background stretches with the rows —
## previously the full-rect containers grew in BOTH directions and shoved the
## header off the panel's top edge.
func _fit_height_to_rows() -> void:
	var content: Control = get_node_or_null("ContentMargin")
	if content == null:
		return
	size = Vector2(140.0, maxf(140.0, content.get_combined_minimum_size().y))


func hide_panel() -> void:
	TapTooltip.dismiss()
	visible = false
	_current_terrain_type = ""


# =============================================================================
# GRID ROW BUILDING
# =============================================================================

func _add_row(unit_type: Variant, walkable: bool, move_cost: float, defense_vs_melee: float,
		defense_vs_ranged: float, avoid: float, attack: float) -> void:
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

	# Column 2: movement cost — or a red X when this type can't enter at all.
	# Impassable terrain's movePenalty default is still 1, so without this it
	# would read as a normal cost of "1" and look walkable.
	if not walkable:
		_add_value_cell("X", GameColors.TEXT_DANGER, GameColors.TEXT_DANGER_GLOW,
				"Impassable — this type cannot enter.")
	else:
		var move_color: Color = GameColors.get_movement_cost_color(move_cost)
		var move_glow: Color = GameColors.get_movement_cost_bg_color(move_cost)
		_add_value_cell(_format_move_cost(move_cost), move_color, move_glow)

	# Column 3: defense multiplier (color-coded). When the terrain defends
	# differently against melee vs ranged (Crater), the cell splits into two
	# stacked M/R lines so both numbers are visible at a glance — a single
	# value here would hide the tile's whole identity.
	if is_equal_approx(defense_vs_melee, defense_vs_ranged):
		_add_multiplier_cell(defense_vs_melee)
	else:
		_add_split_defense_cell(defense_vs_melee, defense_vs_ranged)

	# Column 4: avoid multiplier (color-coded)
	_add_multiplier_cell(avoid)

	# Column 5: attack multiplier (color-coded)
	_add_multiplier_cell(attack)


## Movement costs can be fractional (Road = 0.5) — ceiling them to "1" made
## cheap terrain look ordinary. Halves render with the ½ glyph (present in
## UndeadPixelLight8, the grid-cell font); anything else falls back to decimals.
static func _format_move_cost(cost: float) -> String:
	var whole := int(cost)
	if is_equal_approx(cost, float(whole)):
		return str(whole)
	if is_equal_approx(cost - float(whole), 0.5):
		return "½" if whole == 0 else "%d½" % whole
	return String.num(cost, 2)


func _add_value_cell(text: String, color: Color, glow: Color = Color(-1, -1, -1), tooltip: String = "") -> void:
	if _text_container_scene != null:
		var cell: Control = _text_container_scene.instantiate()
		var label: Label = cell.get_node("Label") as Label
		label.text = text
		label.add_theme_color_override("font_color", color)
		if glow.r >= 0.0 and label is GlowLabel:
			label.glow_color = glow
		if tooltip != "":
			cell.tooltip_text = tooltip
			_add_tap_tooltip(cell)
		_grid.add_child(cell)
	else:
		var label := Label.new()
		label.text = text
		label.add_theme_color_override("font_color", color)
		if tooltip != "":
			label.tooltip_text = tooltip
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


## The two display lines of a split defense cell. "M"/"R" letter prefixes are
## the interim melee/ranged markers until Lawrence's 5px glyphs land (see Art
## Needed in todo.md); values print explicitly (no "—") because the contrast
## between the two lines IS the information.
static func _format_split_defense(melee_value: float, ranged_value: float) -> Array[String]:
	return ["M%.1f" % melee_value, "R%.1f" % ranged_value]


## Defense column when melee and ranged differ: two stacked mini-lines, each
## color-coded like a normal multiplier cell, sharing one tap-tooltip.
func _add_split_defense_cell(melee_value: float, ranged_value: float) -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	var lines: Array[String] = _format_split_defense(melee_value, ranged_value)
	var values: Array[float] = [melee_value, ranged_value]
	for i: int in range(lines.size()):
		if _text_container_scene != null:
			var cell: Control = _text_container_scene.instantiate()
			var label: Label = cell.get_node("Label") as Label
			label.text = lines[i]
			label.add_theme_color_override("font_color",
					GameColors.get_terrain_modifier_color(values[i]))
			if label is GlowLabel:
				label.glow_color = GameColors.get_terrain_modifier_bg_color(values[i])
			stack.add_child(cell)
		else:
			var label := Label.new()
			label.text = lines[i]
			label.add_theme_color_override("font_color",
					GameColors.get_terrain_modifier_color(values[i]))
			stack.add_child(label)
	stack.tooltip_text = "Defense vs melee attacks: x%.1f\nDefense vs ranged attacks: x%.1f" % [
			melee_value, ranged_value]
	_add_tap_tooltip(stack)
	_grid.add_child(stack)


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
	var properties: Array[String] = ["move_penalty", "attack_multiplier", "defense_multiplier",
			"defense_multiplier_vs_melee", "defense_multiplier_vs_ranged", "avoid_multiplier", "walkable"]
	for prop_name: String in properties:
		var prop: Variant = definition.get(prop_name)
		if prop != null and "unit_type_overrides" in prop:
			for unit_type: String in prop.unit_type_overrides.keys():
				if unit_type not in types:
					types.append(unit_type)
	return types


func _unit_type_string_to_enum(unit_type: String) -> Enums.ElementalType:
	# Case-insensitive: override keys arrive UPPERCASE from
	# TerrainDataManager's normalized storage. "Ice" is a legacy alias for
	# COLD that may linger in older data.
	if unit_type.to_upper() == "ICE":
		return Enums.ElementalType.COLD
	return Enums.string_to_elemental_type(unit_type)
