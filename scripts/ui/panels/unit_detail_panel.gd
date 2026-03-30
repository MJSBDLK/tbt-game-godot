## Populates the unit detail panel scene with character data.
## Handles move/passive/status tablet selection and detail panel display.
class_name UnitDetailPanel
extends PanelContainer


signal closed

## The stat display abbreviation -> CharacterData field name mapping.
const STAT_DISPLAY_MAP: Dictionary = {
	"STR": "strength",
	"SPC": "special",
	"SKL": "skill",
	"AGL": "agility",
	"ATH": "athleticism",
	"DEF": "defense",
	"RES": "resistance",
}

## Maps stat container node name prefix -> stat display key.
const STAT_NODE_MAP: Dictionary = {
	"Str": "STR",
	"Spe": "SPC",
	"Skl": "SKL",
	"Agl": "AGL",
	"Ath": "ATH",
	"Def": "DEF",
	"Res": "RES",
}

const STAT_DISPLAY_MAX: float = 60.0
const STAT_BAR_MAX_WIDTH: float = 44.0
const STAT_BAR_MIN_WIDTH: float = 3.0

var _character_data: CharacterData = null
var _unit: Variant = null  # Unit reference for current_hp and status effects
var _passive_configs: Dictionary = {}  # passive_name -> { abbrevName, description }

# Left column node references
var _portrait: TextureRect = null
var _name_label: Label = null
var _class_label: Label = null
var _type_icon_primary: TextureRect = null
var _type_icon_secondary: TextureRect = null
var _hp_bar: ColorRect = null
var _hp_bar_background: ColorRect = null
var _hp_label: Label = null
var _hp_max_label: Label = null  # Reuses StatModifier node to show "/max_hp"
var _stat_rows: Dictionary = {}  # display_key -> { bar_base, bar_bonus, bar_bg, value_label, modifier_label, name_label }

# Center column tablets
var _move_panels: Array[PanelContainer] = []
var _passive_panels: Array[PanelContainer] = []
var _status_panels: Array[PanelContainer] = []
var _passives_section: VBoxContainer = null
var _status_section: VBoxContainer = null

# Right column detail containers
var _move_description: VBoxContainer = null
var _passive_description: VBoxContainer = null
var _status_description: VBoxContainer = null

# Move detail labels
var _move_detail_name_label: Label = null
var _move_detail_element_icon: TextureRect = null
var _move_detail_damage_type_icon: TextureRect = null
var _move_detail_power_label: Label = null
var _move_detail_accuracy_label: Label = null
var _move_detail_usage_label: Label = null
var _move_detail_effect_label: Label = null
var _move_detail_effect_chance_label: Label = null
var _move_detail_effect_icon: TextureRect = null
var _move_detail_effect_name_label: Label = null
var _move_detail_effect_panel: PanelContainer = null
var _move_detail_flavor_label: Label = null

# Passive detail labels
var _passive_detail_name_label: Label = null
var _passive_detail_description_label: Label = null
var _passive_detail_flavor_label: Label = null

# Status detail labels
var _status_detail_name_label: Label = null
var _status_detail_icon: TextureRect = null
var _status_detail_description_label: Label = null
var _status_detail_stacks_container: Control = null

# Selection state
enum SelectionType { NONE, MOVE, PASSIVE, STATUS }
var _selection_type: SelectionType = SelectionType.NONE
var _selection_index: int = -1


func _ready() -> void:
	_cache_node_references()
	_load_passive_configs()
	_setup_tablet_input()
	_hide_all_details()
	_add_border_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("unit_info"):
		hide_panel()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT or mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if not get_global_rect().has_point(mouse_event.position):
				hide_panel()
				get_viewport().set_input_as_handled()


func _add_border_overlay() -> void:
	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null and ui_manager.has_method("create_fullscreen_border_overlay"):
		var overlay: PanelBorderOverlay = ui_manager.create_fullscreen_border_overlay()
		add_child(overlay)


# =============================================================================
# PUBLIC API
# =============================================================================

func show_unit(unit: Variant) -> void:
	## Show the detail panel for a unit. Accepts a Unit node or CharacterData.
	if unit == null:
		return

	if unit is CharacterData:
		_character_data = unit
		_unit = null
	elif "character_data" in unit:
		_unit = unit
		_character_data = unit.character_data
	else:
		return

	_update_all()
	_deselect_all()
	visible = true


func show_character(character_data: CharacterData) -> void:
	show_unit(character_data)


func hide_panel() -> void:
	_character_data = null
	_unit = null
	visible = false
	closed.emit()


# =============================================================================
# NODE REFERENCE CACHING
# =============================================================================

func _cache_node_references() -> void:
	var left_column: VBoxContainer = get_node("MainRow/LeftColumnMargin/LeftColumn")
	var center_column: VBoxContainer = get_node("MainRow/CenterColumnMargin/CenterColumn")

	# Portrait
	_portrait = left_column.get_node("MarginContainer/Portrait")

	# Unit name and types (from unit_row instance)
	var unit_name_row: Control = left_column.get_node("UnitNameAndTypes")
	_name_label = _find_label_in_row(unit_name_row)
	_type_icon_primary = _find_type_icon(unit_name_row, 0)
	_type_icon_secondary = _find_type_icon(unit_name_row, 1)

	# Class name and level
	var class_row: Control = left_column.get_node("ClassNameAndLevel")
	_class_label = _find_label_in_row(class_row)

	# HP
	var hp_container: Control = left_column.get_node("StatsContainer/HPContainer")
	var hp_hbox: HBoxContainer = hp_container.get_node("HBoxContainer")
	var hp_bar_container: Control = hp_hbox.get_node("StatBarContainer")
	_hp_bar_background = hp_bar_container.get_node("StatBarBackground") if hp_bar_container.has_node("StatBarBackground") else null
	_hp_bar = hp_bar_container.get_node("StatBar")
	_hp_label = _find_label_in_node(hp_hbox.get_node("StatValue"))
	_hp_max_label = _find_label_in_node(hp_hbox.get_node("StatModifier"))  # Repurposed as "/max_hp"

	# Stat rows
	var stats_container: VBoxContainer = left_column.get_node("StatsContainer")
	for node_prefix: String in STAT_NODE_MAP:
		var display_key: String = STAT_NODE_MAP[node_prefix]
		var container_name: String = node_prefix + "Container"
		if not stats_container.has_node(container_name):
			continue
		var stat_container: Control = stats_container.get_node(container_name)
		var hbox: HBoxContainer = stat_container.get_node("HBoxContainer")
		var bar_container: Control = hbox.get_node("StatBarContainer")
		_stat_rows[display_key] = {
			"name_label": _find_label_in_node(hbox.get_node("MarginContainer")),
			"value_label": _find_label_in_node(hbox.get_node("StatValue")),
			"modifier_label": _find_label_in_node(hbox.get_node("StatModifier")),
			"bar_bg": bar_container.get_node("StatBarBackground"),
			"bar_base": bar_container.get_node("StatBar"),
			"bar_bonus": bar_container.get_node("StatBonusBar"),
		}

	# Center column — move panels
	var moves_section: VBoxContainer = center_column.get_node("MovesSection")
	for child: Node in moves_section.get_children():
		if child.name.begins_with("MovePanel") and child is PanelContainer:
			_move_panels.append(child as PanelContainer)

	# Center column — passive panels
	_passives_section = center_column.get_node("PassivesSection")
	for child: Node in _passives_section.get_children():
		if child.name.begins_with("PassivePanel") and child is PanelContainer:
			_passive_panels.append(child as PanelContainer)

	# Center column — status panels
	_status_section = center_column.get_node("StatusSection")
	for child: Node in _status_section.get_children():
		if child.name.begins_with("StatusPanel") and child is PanelContainer:
			_status_panels.append(child as PanelContainer)

	# Right column — detail containers
	var detail_parent: VBoxContainer = get_node("MainRow/RightColumnMargin/MovePassiveStatusParent")
	_move_description = detail_parent.get_node("MoveDescription")
	_passive_description = detail_parent.get_node("PassiveDescription")
	_status_description = detail_parent.get_node("StatusDescription")

	# Move detail sub-nodes
	var move_container: HBoxContainer = _move_description.get_node("MoveContainer")
	_move_detail_name_label = _find_label_in_node(move_container.get_node("MarginContainer"))
	_move_detail_element_icon = move_container.get_node("ElementalTypeContainer/TextureRect")
	if move_container.has_node("MoveTypeContainer"):
		_move_detail_damage_type_icon = move_container.get_node("MoveTypeContainer/TextureRect")

	# Power/Acc/Usage mini-panels
	var power_acc_usg: HBoxContainer = _move_description.get_node("PowerAccUsgContainer")
	_move_detail_power_label = _find_label_in_panel(power_acc_usg.get_node("PowerPanelContainer"), 1)
	_move_detail_accuracy_label = _find_label_in_panel(power_acc_usg.get_node("AccuracyPanelContainer"), 1)
	_move_detail_usage_label = _find_label_in_panel(power_acc_usg.get_node("UsagePanelContainer"), 1)

	# Secondary effect panel
	_move_detail_effect_panel = _move_description.get_node("PowerPanelContainer")
	var effect_vbox: VBoxContainer = _move_detail_effect_panel.get_node("VBoxContainer")
	var effect_hbox: HBoxContainer = effect_vbox.get_node("HBoxContainer")
	_move_detail_effect_label = _find_label_in_node(effect_hbox.get_node("MarginContainer"))
	_move_detail_effect_chance_label = _find_label_in_node(effect_hbox.get_node("EffectChanceContainer"))
	# Effect icon + name row (HBoxContainer2)
	var effect_name_row: HBoxContainer = effect_vbox.get_node("HBoxContainer2")
	_move_detail_effect_icon = effect_name_row.get_node("ElemetalTypeIconContainer/TextureRect")
	_move_detail_effect_name_label = _find_label_in_node(effect_name_row.get_node("MarginContainer2"))

	# Flavor text panel
	var flavor_panel: PanelContainer = _move_description.get_node("PowerPanelContainer2")
	_move_detail_flavor_label = _find_label_in_node(flavor_panel.get_node("MarginContainer"))

	# Passive detail sub-nodes
	_passive_detail_name_label = _find_label_in_node(_passive_description.get_node("PassivesHeader"))
	var passive_desc_panel: PanelContainer = _passive_description.get_node("PowerPanelContainer2")
	_passive_detail_description_label = _find_label_in_node(passive_desc_panel.get_node("MarginContainer"))
	var passive_flavor_panel: PanelContainer = _passive_description.get_node("PowerPanelContainer3")
	_passive_detail_flavor_label = _find_label_in_node(passive_flavor_panel.get_node("MarginContainer"))

	# Status detail sub-nodes
	var status_header_hbox: HBoxContainer = _status_description.get_node("HBoxContainer")
	_status_detail_name_label = _find_label_in_node(status_header_hbox.get_node("StatusHeader"))
	_status_detail_icon = status_header_hbox.get_node("TextureRect")
	var status_desc_panel: PanelContainer = _status_description.get_node("PowerPanelContainer2")
	_status_detail_description_label = _find_label_in_node(status_desc_panel.get_node("MarginContainer"))
	_status_detail_stacks_container = _status_description.get_node("PowerPanelContainer3")


# =============================================================================
# TABLET CLICK HANDLING
# =============================================================================

func _setup_tablet_input() -> void:
	for i: int in range(_move_panels.size()):
		var index := i
		_ensure_unique_style(_move_panels[i])
		_set_children_mouse_pass(_move_panels[i])
		_move_panels[i].gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select(SelectionType.MOVE, index)
		)
		_move_panels[i].mouse_filter = Control.MOUSE_FILTER_STOP

	for i: int in range(_passive_panels.size()):
		var index := i
		_ensure_unique_style(_passive_panels[i])
		_set_children_mouse_pass(_passive_panels[i])
		_passive_panels[i].gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select(SelectionType.PASSIVE, index)
		)
		_passive_panels[i].mouse_filter = Control.MOUSE_FILTER_STOP

	for i: int in range(_status_panels.size()):
		var index := i
		_ensure_unique_style(_status_panels[i])
		_set_children_mouse_pass(_status_panels[i])
		_status_panels[i].gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select(SelectionType.STATUS, index)
		)
		_status_panels[i].mouse_filter = Control.MOUSE_FILTER_STOP


func _ensure_unique_style(panel: PanelContainer) -> void:
	## Duplicate the panel's StyleBox so modifying it doesn't affect other panels
	## that share the same resource.
	var style: StyleBox = panel.get_theme_stylebox("panel")
	if style != null:
		panel.add_theme_stylebox_override("panel", style.duplicate())


func _set_children_mouse_pass(panel: Control) -> void:
	## Set all descendants to MOUSE_FILTER_PASS so clicks fall through to the panel.
	for child: Node in panel.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
			_set_children_mouse_pass(child)


func _select(type: SelectionType, index: int) -> void:
	# Deselect if clicking the same tablet
	if type == _selection_type and index == _selection_index:
		_deselect_all()
		return

	_selection_type = type
	_selection_index = index
	_update_tablet_selection()
	_update_detail_panel()


func _deselect_all() -> void:
	_selection_type = SelectionType.NONE
	_selection_index = -1
	_update_tablet_selection()
	_hide_all_details()


func _update_tablet_selection() -> void:
	# Reset all tablets to default appearance
	for panel: PanelContainer in _move_panels:
		_set_tablet_selected(panel, false)
	for panel: PanelContainer in _passive_panels:
		_set_tablet_selected(panel, false)
	for panel: PanelContainer in _status_panels:
		_set_tablet_selected(panel, false)

	# Highlight the selected tablet
	var panels: Array[PanelContainer] = []
	match _selection_type:
		SelectionType.MOVE:
			panels = _move_panels
		SelectionType.PASSIVE:
			panels = _passive_panels
		SelectionType.STATUS:
			panels = _status_panels

	if _selection_index >= 0 and _selection_index < panels.size():
		_set_tablet_selected(panels[_selection_index], true)


func _set_tablet_selected(panel: PanelContainer, selected: bool) -> void:
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	if selected:
		style.border_width_left = 0
		style.border_width_right = 0
		style.border_width_top = 0
		style.border_width_bottom = 0
	else:
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1


func _hide_all_details() -> void:
	if _move_description:
		_move_description.visible = false
	if _passive_description:
		_passive_description.visible = false
	if _status_description:
		_status_description.visible = false


func _update_detail_panel() -> void:
	_hide_all_details()

	match _selection_type:
		SelectionType.MOVE:
			_show_move_detail(_selection_index)
		SelectionType.PASSIVE:
			_show_passive_detail(_selection_index)
		SelectionType.STATUS:
			_show_status_detail(_selection_index)


# =============================================================================
# DISPLAY UPDATES
# =============================================================================

func _update_all() -> void:
	if _character_data == null:
		return
	_update_portrait()
	_update_identity()
	_update_hp()
	_update_stats()
	_update_move_tablets()
	_update_passive_tablets()
	_update_status_tablets()


func _update_portrait() -> void:
	if _portrait == null or _character_data.portrait_path.is_empty():
		return
	var texture: Texture2D = load(_character_data.portrait_path) as Texture2D
	_portrait.texture = texture


func _update_identity() -> void:
	if _name_label:
		_name_label.text = _character_data.character_name.to_upper()

	if _class_label:
		var class_text: String = Enums.get_class_display_name(_character_data.current_class)
		_class_label.text = class_text.to_upper() + " Lv." + str(_character_data.level)

	# Type icons
	if _type_icon_primary:
		_type_icon_primary.texture = _get_elemental_icon(_character_data.primary_type)
		_type_icon_primary.visible = _character_data.primary_type != Enums.ElementalType.NONE

	if _type_icon_secondary:
		_type_icon_secondary.texture = _get_elemental_icon(_character_data.secondary_type)
		_type_icon_secondary.visible = _character_data.secondary_type != Enums.ElementalType.NONE


func _update_hp() -> void:
	var current_hp: int = _unit.current_hp if _unit != null else _character_data.max_hp
	var max_hp: int = _character_data.max_hp

	var health_percent: float = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	var health_color: Color = GameColors.get_health_color(health_percent)

	if _hp_label:
		_hp_label.text = str(current_hp)
		_hp_label.add_theme_color_override("font_color", health_color)
	if _hp_max_label:
		_hp_max_label.text = "/%d" % max_hp

	if _hp_bar and _hp_bar_background:
		var fill_ratio: float = clampf(float(current_hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 0.0
		_hp_bar.size.x = fill_ratio * _hp_bar_background.size.x
		_hp_bar.color = health_color
		_hp_bar_background.color = GameColors.get_health_bg_color(health_percent)


func _update_stats() -> void:
	for display_key: String in STAT_DISPLAY_MAP:
		var stat_name: String = STAT_DISPLAY_MAP[display_key]
		var row: Dictionary = _stat_rows.get(display_key, {})
		if row.is_empty():
			continue

		var base_value: int = _character_data.get_base_plus_growth(stat_name)
		var bonus_value: int = _character_data.get_bonus_total(stat_name)
		var total_value: int = base_value + bonus_value
		var at_cap: bool = _character_data.is_at_stat_cap(stat_name)

		# Value label
		var value_label: Label = row["value_label"]
		if value_label:
			value_label.text = "%d" % total_value

		# Modifier label — set visibility on the PARENT container, not just the label
		var modifier_label: Label = row["modifier_label"]
		if modifier_label:
			var modifier_container: Control = modifier_label.get_parent() as Control
			if bonus_value > 0:
				modifier_label.text = "+%d" % bonus_value
				_set_label_color(modifier_label, GameColors.TEXT_SUCCESS, GameColors.TEXT_SUCCESS_GLOW)
				if modifier_container:
					modifier_container.visible = true
			elif bonus_value < 0:
				modifier_label.text = "%d" % bonus_value
				_set_label_color(modifier_label, GameColors.TEXT_DANGER, GameColors.TEXT_DANGER_GLOW)
				if modifier_container:
					modifier_container.visible = true
			else:
				if modifier_container:
					modifier_container.visible = false

		# Color: green at cap, red for negative bonus, default otherwise
		var name_label: Label = row["name_label"]
		if at_cap:
			if value_label:
				_set_label_color(value_label, GameColors.TEXT_SUCCESS, GameColors.TEXT_SUCCESS_GLOW)
			if name_label:
				_set_label_color(name_label, GameColors.TEXT_SUCCESS, GameColors.TEXT_SUCCESS_GLOW)
		elif bonus_value > 0:
			if value_label:
				_set_label_color(value_label, GameColors.TEXT_SUCCESS, GameColors.TEXT_SUCCESS_GLOW)
			if name_label:
				_reset_label_color(name_label)
		elif bonus_value < 0:
			if value_label:
				_set_label_color(value_label, GameColors.TEXT_DANGER, GameColors.TEXT_DANGER_GLOW)
			if name_label:
				_reset_label_color(name_label)
		else:
			if value_label:
				_reset_label_color(value_label)
			if name_label:
				_reset_label_color(name_label)

		# Base bar width
		var base_pixels: int = 0
		if base_value > 0:
			base_pixels = maxi(roundi(base_value / STAT_DISPLAY_MAX * STAT_BAR_MAX_WIDTH), int(STAT_BAR_MIN_WIDTH))

		var bar_base: ColorRect = row["bar_base"]
		if bar_base:
			bar_base.size.x = base_pixels
			bar_base.color = GameColors.TEXT_SUCCESS if at_cap else GameColors.PLAYER_UNIT
			bar_base.visible = base_pixels > 0

		# Bonus bar
		var bonus_pixels: int = 0
		if bonus_value > 0:
			bonus_pixels = maxi(roundi(bonus_value / STAT_DISPLAY_MAX * STAT_BAR_MAX_WIDTH), int(STAT_BAR_MIN_WIDTH))

		var bar_bonus: ColorRect = row["bar_bonus"]
		if bar_bonus:
			var overlap: int = 1 if base_pixels > 0 else 0
			bar_bonus.position.x = base_pixels - overlap
			bar_bonus.size.x = bonus_pixels
			bar_bonus.visible = bonus_pixels > 0


func _update_move_tablets() -> void:
	for i: int in range(_move_panels.size()):
		var panel: PanelContainer = _move_panels[i]
		var hbox: HBoxContainer = panel.get_node("HBoxContainer")
		var name_label: Label = _find_label_in_node(hbox.get_node("MarginContainer"))
		var usage_label: Label = _find_label_in_node(hbox.get_node("UsagesContainer"))
		var icon_container: MarginContainer = hbox.get_node("ElemetalTypeIconContainer") if hbox.has_node("ElemetalTypeIconContainer") else null
		var type_icon: TextureRect = icon_container.get_node("TextureRect") if icon_container else null

		if i < _character_data.equipped_moves.size():
			var move: Move = _character_data.equipped_moves[i]
			panel.visible = true
			if name_label:
				name_label.text = move.move_name.to_upper()
			if usage_label:
				usage_label.text = "%d/%d" % [move.current_uses, move.max_uses]
			if type_icon:
				type_icon.texture = _get_elemental_icon(move.element_type)
				type_icon.visible = move.element_type != Enums.ElementalType.NONE
		else:
			panel.visible = false


func _update_passive_tablets() -> void:
	var passive_names: Array = []
	if not _character_data.equipped_passives.is_empty():
		for passive: Variant in _character_data.equipped_passives:
			if passive is String:
				passive_names.append(passive)
			elif passive != null and "passive_name" in passive:
				passive_names.append(passive.passive_name)
	else:
		for passive_name: String in _character_data.base_pool_passives:
			passive_names.append(passive_name)

	for i: int in range(_passive_panels.size()):
		var panel: PanelContainer = _passive_panels[i]
		var hbox: HBoxContainer = panel.get_node("HBoxContainer")
		var name_label: Label = _find_label_in_node(hbox.get_node("MarginContainer"))

		if i < passive_names.size():
			panel.visible = true
			if name_label:
				name_label.text = str(passive_names[i]).to_upper()
		else:
			panel.visible = false

	if _passives_section:
		_passives_section.visible = not passive_names.is_empty()


func _update_status_tablets() -> void:
	var effects: Array = _unit.active_status_effects if _unit != null else []
	var configs := StatusEffectData.get_default_configs()

	for i: int in range(_status_panels.size()):
		var panel: PanelContainer = _status_panels[i]
		var hbox: HBoxContainer = panel.get_node("HBoxContainer")
		var name_label: Label = _find_label_in_node(hbox.get_node("MarginContainer"))
		var icon_container: MarginContainer = hbox.get_node("ElemetalTypeIconContainer") if hbox.has_node("ElemetalTypeIconContainer") else null
		var type_icon: TextureRect = icon_container.get_node("TextureRect") if icon_container else null

		if i < effects.size():
			var effect: StatusEffect = effects[i] as StatusEffect
			var config: StatusEffectData = configs.get(effect.effect_type_name, null)
			panel.visible = true

			if name_label:
				if config != null and config.abbrev_name != "":
					name_label.text = config.abbrev_name.to_upper()
				else:
					name_label.text = effect.effect_type_name.to_upper()

			if type_icon:
				if config != null and config.icon_path != "":
					type_icon.texture = load(config.icon_path) as Texture2D
					type_icon.visible = true
				else:
					type_icon.visible = false
		else:
			panel.visible = false

	if _status_section:
		_status_section.visible = not effects.is_empty()


# =============================================================================
# DETAIL PANEL DISPLAY
# =============================================================================

func _show_move_detail(index: int) -> void:
	if _character_data == null or index < 0 or index >= _character_data.equipped_moves.size():
		return

	var move: Move = _character_data.equipped_moves[index]

	_move_description.visible = true

	if _move_detail_name_label:
		_move_detail_name_label.text = move.move_name.to_upper()

	if _move_detail_element_icon:
		_move_detail_element_icon.texture = _get_elemental_icon(move.element_type)

	if _move_detail_damage_type_icon:
		var icon_path: String = Enums.get_damage_type_icon(move.damage_type)
		if icon_path != "" and ResourceLoader.exists(icon_path):
			_move_detail_damage_type_icon.texture = load(icon_path) as Texture2D
			_move_detail_damage_type_icon.get_parent().visible = true
		else:
			_move_detail_damage_type_icon.get_parent().visible = false

	if _move_detail_power_label:
		_move_detail_power_label.text = "%d" % move.base_power if move.base_power > 0 else "--"

	if _move_detail_accuracy_label:
		_move_detail_accuracy_label.text = "100%"  # TODO: when accuracy is added to Move

	if _move_detail_usage_label:
		_move_detail_usage_label.text = "%d/%d" % [move.current_uses, move.max_uses]

	# Secondary effect
	var has_effect: bool = move.status_effect_type != Enums.StatusEffectType.NONE
	if _move_detail_effect_panel:
		_move_detail_effect_panel.visible = has_effect
	if has_effect:
		var effect_name: String = Enums.StatusEffectType.keys()[move.status_effect_type]
		if _move_detail_effect_chance_label:
			_move_detail_effect_chance_label.text = "%d%%" % roundi(move.status_effect_chance * 100)
		if _move_detail_effect_name_label:
			_move_detail_effect_name_label.text = effect_name
		if _move_detail_effect_icon:
			var effect_key: String = Enums.StatusEffectType.keys()[move.status_effect_type]
			var icon: Texture2D = _get_status_effect_icon_by_name(effect_key)
			_move_detail_effect_icon.texture = icon
			_move_detail_effect_icon.get_parent().visible = icon != null

	# Flavor text
	var has_flavor: bool = not move.description.is_empty()
	if _move_detail_flavor_label:
		_move_detail_flavor_label.text = move.description if has_flavor else ""
		_move_detail_flavor_label.get_parent().visible = has_flavor


func _show_passive_detail(index: int) -> void:
	if _character_data == null:
		return
	var passive_names: Array = []
	if not _character_data.equipped_passives.is_empty():
		for passive: Variant in _character_data.equipped_passives:
			if passive is String:
				passive_names.append(passive)
			elif passive != null and "passive_name" in passive:
				passive_names.append(passive.passive_name)
	else:
		for name: String in _character_data.base_pool_passives:
			passive_names.append(name)

	if index < 0 or index >= passive_names.size():
		return

	_passive_description.visible = true

	var passive_name: String = str(passive_names[index])
	if _passive_detail_name_label:
		_passive_detail_name_label.text = passive_name.to_upper()

	# Populate description from passives.json
	var config: Variant = _passive_configs.get(passive_name, null)
	if _passive_detail_description_label:
		var desc: String = config["description"] if config is Dictionary and config.has("description") else ""
		_passive_detail_description_label.text = desc
		_passive_detail_description_label.get_parent().get_parent().visible = not desc.is_empty()

	if _passive_detail_flavor_label:
		_passive_detail_flavor_label.text = ""
		_passive_detail_flavor_label.get_parent().get_parent().visible = false


func _show_status_detail(index: int) -> void:
	var effects: Array = _unit.active_status_effects if _unit != null else []
	if index < 0 or index >= effects.size():
		return

	_status_description.visible = true

	var effect: StatusEffect = effects[index] as StatusEffect
	var configs := StatusEffectData.get_default_configs()
	var config: StatusEffectData = configs.get(effect.effect_type_name, null)

	# Header name
	if _status_detail_name_label:
		_status_detail_name_label.text = effect.effect_type_name.to_upper()

	# Header icon
	if _status_detail_icon:
		var icon: Texture2D = _get_status_effect_icon_by_name(effect.effect_type_name)
		_status_detail_icon.texture = icon
		_status_detail_icon.visible = icon != null

	# Description
	if _status_detail_description_label:
		var desc_text: String = ""
		if config != null:
			desc_text = config.description
		if effect.remaining_turns > 0:
			desc_text += "\n%d turn(s) remaining." % effect.remaining_turns
		_status_detail_description_label.text = desc_text
		_status_detail_description_label.get_parent().get_parent().visible = not desc_text.is_empty()

	# Stacks container — show stack icons for stackable effects (e.g., VOID)
	if _status_detail_stacks_container:
		_status_detail_stacks_container.visible = false


# =============================================================================
# HELPERS
# =============================================================================

func _set_label_color(label: Label, font_color: Color, glow_color: Color) -> void:
	label.add_theme_color_override("font_color", font_color)
	if label is GlowLabel:
		label.glow_color = glow_color


func _reset_label_color(label: Label) -> void:
	label.remove_theme_color_override("font_color")
	if label is GlowLabel:
		label.glow_color = GameColors.TEXT_PRIMARY_GLOW


func _load_passive_configs() -> void:
	var file := FileAccess.open("res://data/passives.json", FileAccess.READ)
	if file == null:
		DebugConfig.log_error("UnitDetailPanel: Could not load passives.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		DebugConfig.log_error("UnitDetailPanel: Failed to parse passives.json")
		return
	_passive_configs = json.data as Dictionary


func _get_status_effect_icon_by_name(effect_type_name: String) -> Texture2D:
	var configs := StatusEffectData.get_default_configs()
	var config: StatusEffectData = configs.get(effect_type_name, null)
	if config == null or config.icon_path == "":
		return null
	return load(config.icon_path) as Texture2D


func _get_elemental_icon(element_type: Enums.ElementalType) -> Texture2D:
	if element_type == Enums.ElementalType.NONE:
		return null
	var type_name: String = Enums.elemental_type_to_string(element_type).to_lower()
	var path: String = "res://art/sprites/ui/elemental_type_icons_10x10/%s.png" % type_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _find_label_in_row(row: Control) -> Label:
	## Find the first Label inside a unit_row instance (through HBoxContainer/MarginContainer).
	if row == null:
		return null
	var hbox: Node = row.get_node_or_null("HBoxContainer")
	if hbox == null:
		return null
	var margin: Node = hbox.get_node_or_null("MarginContainer")
	if margin == null:
		return null
	for child: Node in margin.get_children():
		if child is Label:
			return child as Label
	return null


func _find_label_in_node(node: Node) -> Label:
	## Find the first Label child of a node (usually a MarginContainer wrapping a Label).
	if node == null:
		return null
	if node is Label:
		return node as Label
	for child: Node in node.get_children():
		if child is Label:
			return child as Label
	return null


func _find_type_icon(row: Control, index: int) -> TextureRect:
	## Find a type icon TextureRect inside a unit_row instance.
	if row == null:
		return null
	var hbox: Node = row.get_node_or_null("HBoxContainer")
	if hbox == null:
		return null
	var container_name: String = "UnitTypeIconContainer" if index == 0 else "UnitTypeIconContainer2"
	var container: Node = hbox.get_node_or_null(container_name)
	if container == null:
		return null
	for child: Node in container.get_children():
		if child is TextureRect:
			return child as TextureRect
	return null


func _find_label_in_panel(panel: PanelContainer, label_index: int) -> Label:
	## Find a label inside a mini-panel by traversing VBoxContainer children.
	## label_index 0 = header label ("Power"), 1 = value label ("65")
	if panel == null:
		return null
	var vbox: Node = panel.get_node_or_null("VBoxContainer")
	if vbox == null:
		return null
	var count: int = 0
	for child: Node in vbox.get_children():
		var label: Label = _find_label_in_node(child)
		if label and count == label_index:
			return label
		if label:
			count += 1
	return null
