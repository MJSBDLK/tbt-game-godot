## Displays a condensed unit summary in the left panel on hover/select.
## Shows name, class, HP, move chips with PP fill, passives, and status icons.
## Replaces the old programmatic UnitInfoPanel.
class_name UnitPreviewPanel
extends PanelContainer


var _tracked_unit: Unit = null

# Header — resolved in _ready via node paths
var _portrait: TextureRect = null
var _type_icon_primary: TextureRect = null
var _type_icon_secondary: TextureRect = null
var _name_label: Label = null
var _class_level_label: Label = null

# HP
var _hp_background: ColorRect = null
var _hp_fill: ColorRect = null
var _hp_value_label: Label = null
var _hp_max_label: Label = null

# Sections
var _moves_container: VBoxContainer = null
var _passives_container: GridContainer = null
var _status_container: GridContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resolve_nodes()
	# Stay visible when previewing this scene standalone (F6)
	if get_tree().current_scene != self:
		visible = false


func _resolve_nodes() -> void:
	var vbox: VBoxContainer = get_node("MarginContainer/VBoxContainer")
	var header: HBoxContainer = vbox.get_node("HBoxContainer")
	var info_vbox: VBoxContainer = header.get_node("VBoxContainer")

	_portrait = header.get_node("TextureRect") as TextureRect
	_type_icon_primary = info_vbox.get_node("HBoxContainer/TextureRect") as TextureRect
	_type_icon_secondary = info_vbox.get_node("HBoxContainer/TextureRect2") as TextureRect
	_name_label = info_vbox.get_node("MarginContainer/Label") as Label
	_class_level_label = info_vbox.get_node("MarginContainer2/Label") as Label

	var hp_bar: HBoxContainer = vbox.get_node("HPBar")
	_hp_background = hp_bar.get_node("HPBarContainer/HpBackground") as ColorRect
	_hp_fill = hp_bar.get_node("HPBarContainer/HPFill") as ColorRect
	_hp_value_label = hp_bar.get_node("HBoxContainer/MarginContainer/Label") as Label
	_hp_max_label = hp_bar.get_node("HBoxContainer/MarginContainer2/Label") as Label

	_moves_container = vbox.get_node("MovesContainer") as VBoxContainer
	_passives_container = vbox.get_node("PassivesContainer") as GridContainer
	_status_container = vbox.get_node("StatusContainer") as GridContainer


# =============================================================================
# PUBLIC API
# =============================================================================

func show_unit(unit: Unit) -> void:
	if unit == null:
		hide_panel()
		return

	_tracked_unit = unit
	visible = true

	_update_header(unit)
	_update_hp(unit)
	_update_moves(unit)
	_update_passives(unit)
	_update_statuses(unit)


func hide_panel() -> void:
	_tracked_unit = null
	visible = false


func refresh() -> void:
	if _tracked_unit != null and is_instance_valid(_tracked_unit):
		show_unit(_tracked_unit)


# =============================================================================
# DISPLAY UPDATES
# =============================================================================

func _update_header(unit: Unit) -> void:
	var data: CharacterData = unit.character_data

	# Portrait
	if data != null and data.portrait_path != "" and ResourceLoader.exists(data.portrait_path):
		_portrait.texture = load(data.portrait_path) as Texture2D
	else:
		_portrait.texture = null

	# Name
	_name_label.text = unit.unit_name

	# Class + Level
	if data != null:
		var class_display: String = Enums.get_class_display_name(data.current_class)
		_class_level_label.text = "%s Lv.%d" % [class_display, data.level]
	else:
		_class_level_label.text = ""

	# Type icons
	if data != null:
		_type_icon_primary.texture = _get_elemental_icon(data.primary_type)
		_type_icon_primary.visible = data.primary_type != Enums.ElementalType.NONE
		_type_icon_secondary.texture = _get_elemental_icon(data.secondary_type)
		_type_icon_secondary.visible = data.secondary_type != Enums.ElementalType.NONE
	else:
		_type_icon_primary.visible = false
		_type_icon_secondary.visible = false


func _update_hp(unit: Unit) -> void:
	if unit.character_data == null:
		return
	var current_hp: int = unit.current_hp
	var max_hp: int = unit.character_data.max_hp
	var health_percent: float = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0

	var health_color: Color = GameColors.get_health_color(health_percent)
	var health_bg_color: Color = GameColors.get_health_bg_color(health_percent)

	# Fill bar via anchors — zero offsets so only anchors control size
	_hp_fill.offset_right = 0.0
	_hp_fill.anchor_right = health_percent
	_hp_fill.color = health_color
	if _hp_fill.has_method("_apply_glow_color"):
		_hp_fill.glow_color = health_bg_color

	# Background tracks health color too
	_hp_background.color = health_bg_color
	if _hp_background.has_method("_apply_glow_color"):
		_hp_background.glow_color = health_bg_color

	# Labels
	_hp_value_label.text = str(current_hp)
	_hp_value_label.add_theme_color_override("font_color", health_color)
	if _hp_value_label is GlowLabel:
		_hp_value_label.glow_color = health_bg_color
	_hp_max_label.text = "/%d" % max_hp


func _update_moves(unit: Unit) -> void:
	var data: CharacterData = unit.character_data
	var moves: Array[Move] = data.equipped_moves if data != null else []

	# Collect MoveContainer children (they have the move_chip.gd script)
	var move_chips: Array[Node] = []
	for child: Node in _moves_container.get_children():
		if child is ColorRect and child.has_method("_apply_shader_params"):
			move_chips.append(child)

	for i: int in range(move_chips.size()):
		var chip: ColorRect = move_chips[i] as ColorRect
		if i < moves.size() and moves[i] != null:
			var move: Move = moves[i]
			chip.visible = true
			_update_move_chip(chip, move)
		else:
			chip.visible = false


func _update_move_chip(chip: ColorRect, move: Move) -> void:
	# Set the move name label
	var label: Label = _find_label_in_chip(chip)
	if label != null:
		label.text = move.abbrev_name if move.abbrev_name != "" else move.move_name

	# Set the type icon
	var icon: TextureRect = _find_icon_in_chip(chip)
	if icon != null:
		icon.texture = _get_elemental_icon(move.element_type)
		icon.visible = move.element_type != Enums.ElementalType.NONE

	# Set fill percent and colors via MoveChip script exports
	var fill: float = float(move.current_uses) / float(move.max_uses) if move.max_uses > 0 else 0.0
	# DEBUG: uncomment to randomize fill for visual testing
	#fill = randf_range(0.1, 0.9)
	var bright_color: Color = GameColors.get_move_chip_fill(move.element_type)
	var dark_color: Color = GameColors.get_move_chip_empty(move.element_type)

	chip.set("fill_color", bright_color)
	chip.set("empty_color", dark_color)
	chip.set("fill_percent", fill)

	# Grey out depleted moves
	if move.current_uses <= 0:
		chip.set("fill_color", Color(0.15, 0.15, 0.15, 1.0))
		chip.set("empty_color", Color(0.08, 0.08, 0.08, 1.0))


func _update_passives(unit: Unit) -> void:
	var data: CharacterData = unit.character_data
	var passives: Array = data.equipped_passives if data != null else []

	var passive_chips: Array[Node] = []
	for child: Node in _passives_container.get_children():
		if child is ColorRect:
			passive_chips.append(child)

	for i: int in range(passive_chips.size()):
		var chip: ColorRect = passive_chips[i] as ColorRect
		if i < passives.size() and passives[i] != null:
			chip.visible = true
			var label: Label = _find_label_in_chip(chip)
			if label != null:
				# PassiveData is a placeholder — handle strings or objects
				if passives[i] is String:
					label.text = passives[i]
				elif passives[i].get("passive_name") != null:
					label.text = passives[i].passive_name
		else:
			chip.visible = false

	_passives_container.visible = not passives.is_empty()


func _update_statuses(unit: Unit) -> void:
	var statuses: Array = unit.active_status_effects

	# Clear existing status icons
	for child: Node in _status_container.get_children():
		child.queue_free()

	if statuses.is_empty():
		_status_container.visible = false
		return

	_status_container.visible = true
	for effect: Variant in statuses:
		var icon_texture: Texture2D = _get_status_effect_icon(effect.effect_type)
		if icon_texture != null:
			var icon := TextureRect.new()
			icon.texture = icon_texture
			icon.custom_minimum_size = Vector2(10, 10)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_status_container.add_child(icon)


# =============================================================================
# HELPERS
# =============================================================================

func _find_label_in_chip(chip: ColorRect) -> Label:
	for child: Node in chip.get_children():
		if child is HBoxContainer:
			for grandchild: Node in child.get_children():
				if grandchild is Label:
					return grandchild as Label
				for great_grandchild: Node in grandchild.get_children():
					if great_grandchild is Label:
						return great_grandchild as Label
	return null


func _find_icon_in_chip(chip: ColorRect) -> TextureRect:
	for child: Node in chip.get_children():
		if child is HBoxContainer:
			var children: Array[Node] = child.get_children()
			for i: int in range(children.size() - 1, -1, -1):
				if children[i] is MarginContainer:
					for grandchild: Node in children[i].get_children():
						if grandchild is TextureRect:
							return grandchild as TextureRect
	return null


func _get_elemental_icon(element_type: Enums.ElementalType) -> Texture2D:
	if element_type == Enums.ElementalType.NONE:
		return null
	var type_name: String = Enums.elemental_type_to_string(element_type).to_lower()
	var path: String = "res://art/sprites/ui/elemental_type_icons_10x10/%s.png" % type_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _get_status_effect_icon(_effect_type: Enums.StatusEffectType) -> Texture2D:
	# TODO: Load from art/sprites/ui/status_icons/ once icons are created
	return null
