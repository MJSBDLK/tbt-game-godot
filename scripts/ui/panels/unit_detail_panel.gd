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

const _HYPOESTHESIA_STATIC_MATERIAL: ShaderMaterial = preload("res://resources/injury_static.tres")

# STAT_DISPLAY_MAX (60.0) and STAT_BAR_MIN_WIDTH (3.0) retired 2026-08-06 —
# StatCapBar scales against ClassStatCaps.GLOBAL instead, so a full bar means
# the game's maximum rather than an arbitrary 60.
const STAT_BAR_MAX_WIDTH: float = 44.0

var _character_data: CharacterData = null
var _unit: Variant = null  # Unit reference for current_hp and status effects
var _passive_configs: Dictionary = {}  # passive_name -> { abbrevName, description }

# Left column node references
var _portrait: TextureRect = null
var _name_label: Label = null
var _class_label: Label = null
var _type_icon_primary: TextureRect = null
var _type_icon_secondary: TextureRect = null
var _type_icon_container_primary: Control = null
var _type_icon_container_secondary: Control = null
var _hp_bar: ColorRect = null
var _hp_bar_background: ColorRect = null
var _hp_label: Label = null
var _hp_max_label: Label = null  # Reuses StatModifier node to show "/max_hp"
var _hp_censor: StaticCensorOverlay = null
var _stat_rows: Dictionary = {}  # display_key -> { cap_bar, bar_bg, value_label, modifier_label, name_label }

# Center column tablets
var _move_chips: Array[MoveChipButton] = []
var _passive_panels: Array[PanelContainer] = []
var _status_panels: Array[PanelContainer] = []
var _passives_section: VBoxContainer = null
var _status_section: Container = null

# Right column detail containers
var _move_description: VBoxContainer = null
var _passive_description: VBoxContainer = null
# EffectDescription is shared by status (boost/affliction) and injury click handlers.
# Both render into the same node via different formatters (_show_status_detail / _show_injury_detail).
var _effect_description: VBoxContainer = null

# Move detail labels
var _move_detail_name_label: Label = null
var _move_detail_element_icon: TextureRect = null
var _move_detail_damage_type_icon: TextureRect = null
var _move_detail_damage_type_container: Control = null
var _move_detail_power_label: Label = null
var _move_detail_range_label: Label = null
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

# Effect detail labels (shared by status and injury detail formatters)
var _effect_detail_name_label: Label = null
var _effect_detail_icon: TextureRect = null
var _effect_detail_description_label: Label = null

# Injury slot panels — 4 total (2 per column). See _update_injury_panels().
var _injuries_section: VBoxContainer = null
var _injury_column_1: VBoxContainer = null
var _injury_column_2: VBoxContainer = null
var _injury_panels: Array[PanelContainer] = []  # [InjuryPanel1, InjuryPanel4, InjuryPanel2, InjuryPanel3]
var _injury_slot_to_injury: Array[Injury] = []  # parallel to _injury_panels — null = empty placeholder
var _injury_filled_stylebox: StyleBox = null
var _injury_empty_stylebox: StyleBox = null

# Selection state
enum SelectionType { NONE, MOVE, PASSIVE, STATUS, INJURY }
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
	var ui_manager: Node = UIManager
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
	TapTooltip.dismiss()
	visible = false
	closed.emit()


# =============================================================================
# NODE REFERENCE CACHING
# =============================================================================

func _cache_node_references() -> void:
	var left_column: VBoxContainer = get_node("MainRow/LeftColumnMargin/LeftColumn")
	var center_column: VBoxContainer = get_node("MainRow/CenterColumnMargin/CenterColumn")

	# Portrait — recursive search so the lookup survives layout reshuffles
	# (e.g. wrapping the portrait + border in an AspectRatioContainer).
	_portrait = left_column.find_child("Portrait", true, false)

	# Unit name and types (from unit_row instance)
	var unit_name_row: Control = left_column.get_node("UnitNameAndTypes")
	_name_label = _find_label_in_row(unit_name_row)
	_type_icon_primary = _find_type_icon(unit_name_row, 0)
	_type_icon_secondary = _find_type_icon(unit_name_row, 1)
	_type_icon_container_primary = _find_type_icon_container(unit_name_row, 0)
	_type_icon_container_secondary = _find_type_icon_container(unit_name_row, 1)

	# Class name and level. The ClassNameAndLevel HBoxContainer holds an icon
	# slot + a MarginContainer2/GlowLabel directly — different structure from
	# the UnitNameAndTypes instance above (which nests its label under an
	# auto-created HBoxContainer). _find_label_in_row assumes the latter shape
	# and silently returns null here, leaving the scene's editor placeholder
	# ("SPACEMAN Lv.1") on screen for every unit. Recursive find_child handles
	# both shapes without depending on the wrapper structure.
	var class_row: Control = left_column.get_node("ClassNameAndLevel")
	_class_label = class_row.find_child("GlowLabel", true, false) as Label

	# HP
	var hp_container: Control = left_column.get_node("StatsContainer/HPContainer")
	var hp_hbox: HBoxContainer = hp_container.get_node("HBoxContainer")
	var hp_bar_container: Control = hp_hbox.get_node("StatBarContainer")
	_hp_bar_background = hp_bar_container.get_node("StatBarBackground") if hp_bar_container.has_node("StatBarBackground") else null
	_hp_bar = hp_bar_container.get_node("StatBar")
	# Duplicate the shared `hud_glow.tres` material per-node so each bar's glow_color
	# can be driven independently by HP% without bleeding into other UI.
	if _hp_bar != null and _hp_bar.material != null:
		_hp_bar.material = _hp_bar.material.duplicate()
	if _hp_bar_background != null and _hp_bar_background.material != null:
		_hp_bar_background.material = _hp_bar_background.material.duplicate()
	_hp_label = _find_label_in_node(hp_hbox.get_node("StatValue"))
	_hp_max_label = _find_label_in_node(hp_hbox.get_node("StatModifier"))  # Repurposed as "/max_hp"
	if _hp_label != null and _hp_label.material != null:
		_hp_label.material = _hp_label.material.duplicate()
	if _hp_max_label != null and _hp_max_label.material != null:
		_hp_max_label.material = _hp_max_label.material.duplicate()

	_hp_censor = StaticCensorOverlay.new()
	hp_hbox.add_child(_hp_censor)
	# Cover bar + current value, leave "/max" readable.
	var stat_value_node: Control = hp_hbox.get_node("StatValue") as Control
	var targets: Array[Control] = [hp_bar_container, stat_value_node]
	_hp_censor.set_targets(targets)

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
		# The scene ships StatBar/StatBonusBar ColorRects that this panel used
		# to size by hand. Hide them and lay a StatCapBar over the same slot —
		# same rendering as CharacterSheetPanel, from one implementation.
		var scene_base: ColorRect = bar_container.get_node("StatBar")
		var scene_bonus: ColorRect = bar_container.get_node("StatBonusBar")
		scene_base.visible = false
		scene_bonus.visible = false

		var cap_bar := StatCapBar.new(STAT_DISPLAY_MAP[display_key], int(scene_base.size.y))
		cap_bar.position = scene_base.position
		cap_bar.size = Vector2(STAT_BAR_MAX_WIDTH, scene_base.size.y)
		bar_container.add_child(cap_bar)

		_stat_rows[display_key] = {
			"name_label": _find_label_in_node(hbox.get_node("MarginContainer")),
			"value_label": _find_label_in_node(hbox.get_node("StatValue")),
			"modifier_label": _find_label_in_node(hbox.get_node("StatModifier")),
			"bar_bg": bar_container.get_node("StatBarBackground"),
			"cap_bar": cap_bar,
		}

	# Center column — move chips. The scene's MovePanel tablets are replaced
	# in place with real MoveChipButtons (2026-07-19 adoption): same component
	# as the action menu, wider name column, full names.
	var moves_section: VBoxContainer = center_column.get_node("MovesSection")
	for child: Node in moves_section.get_children():
		if child.name.begins_with("MovePanel") and child is PanelContainer:
			var chip_button := MoveChipButton.new()
			chip_button.custom_minimum_size = Vector2(0, 14)
			chip_button.prefer_full_name = true
			# Identity-only selectors: the pane beside these already shows
			# Power/Rng/Acc/Usg — on-chip data was duplication that couldn't
			# fit the column anyway ("not populating" = clipped away,
			# RQD 2026-07-19).
			chip_button.show_scheme_and_range = false
			chip_button.show_uses = false
			# No-op venue for hold-to-peek (RQD 2026-07-21): the detail pane
			# beside these chips IS the tooltip's content, live and larger.
			chip_button.peek_enabled = false
			child.add_sibling(chip_button)
			moves_section.remove_child(child)
			child.queue_free()
			_move_chips.append(chip_button)

	# Center column — passive panels
	_passives_section = center_column.get_node("PassivesSection")
	for child: Node in _passives_section.get_children():
		if child.name.begins_with("PassivePanel") and child is PanelContainer:
			_passive_panels.append(child as PanelContainer)

	# Center column — affliction/boost section.
	# New layout: AfflictionBoostSection contains StatusSection (afflictions) and BoostSection (boosts).
	# _status_panels order: [BoostPanel (slot 0=buff), StatusPanel1 (slot 1=debuff)].
	_status_section = center_column.get_node_or_null("AfflictionBoostSection")
	if _status_section == null:
		# Legacy single-section fallback.
		_status_section = center_column.get_node_or_null("StatusSection")
	if _status_section != null:
		var boost_panel: Node = _status_section.get_node_or_null("BoostSection/BoostPanel")
		if boost_panel is PanelContainer:
			_status_panels.append(boost_panel as PanelContainer)
		var status_panel: Node = _status_section.get_node_or_null("StatusSection/StatusPanel1")
		if status_panel is PanelContainer:
			_status_panels.append(status_panel as PanelContainer)
		# Legacy: flat StatusPanel* children directly under _status_section.
		if _status_panels.is_empty():
			for child: Node in _status_section.get_children():
				if child.name.begins_with("StatusPanel") and child is PanelContainer:
					_status_panels.append(child as PanelContainer)

	# Right column — detail containers
	var detail_parent: VBoxContainer = get_node("MainRow/RightColumnMargin/MovePassiveStatusParent")
	_move_description = detail_parent.get_node("MoveDescription")
	_passive_description = detail_parent.get_node("PassiveDescription")
	# EffectDescription replaces the old StatusDescription — used by both status and injury detail.
	_effect_description = detail_parent.get_node_or_null("EffectDescription")
	if _effect_description == null:
		# Fallback for transitional state where the scene still uses the old name.
		_effect_description = detail_parent.get_node_or_null("StatusDescription")

	# Move detail sub-nodes
	var move_container: HBoxContainer = _move_description.get_node("MoveContainer")
	_move_detail_name_label = _find_label_in_node(move_container.get_node("MarginContainer"))
	_move_detail_element_icon = move_container.get_node("ElementalTypeContainer/TextureRect")
	if move_container.has_node("MoveTypeContainer"):
		_move_detail_damage_type_container = move_container.get_node("MoveTypeContainer")
		_move_detail_damage_type_icon = move_container.get_node("MoveTypeContainer/TextureRect")

	# Power/Acc/Usage mini-panels
	var power_acc_usg: HBoxContainer = _move_description.get_node("PowerAccUsgContainer")
	_move_detail_power_label = _find_label_in_panel(power_acc_usg.get_node("PowerPanelContainer"), 1)
	_move_detail_accuracy_label = _find_label_in_panel(power_acc_usg.get_node("AccuracyPanelContainer"), 1)
	_move_detail_usage_label = _find_label_in_panel(power_acc_usg.get_node("UsagePanelContainer"), 1)

	# Range mini-panel — cloned from Accuracy at runtime (the row's mini-panels
	# are structurally identical) instead of authored into the .tscn. Sits
	# between Power and Accuracy. Range was previously listed NOWHERE in the UI.
	var range_panel: PanelContainer = power_acc_usg.get_node("AccuracyPanelContainer").duplicate()
	range_panel.name = "RangePanelContainer"
	power_acc_usg.add_child(range_panel)
	power_acc_usg.move_child(range_panel, power_acc_usg.get_node("PowerPanelContainer").get_index() + 1)
	var range_header: Label = _find_label_in_panel(range_panel, 0)
	if range_header != null:
		range_header.text = "Rng."
	_move_detail_range_label = _find_label_in_panel(range_panel, 1)

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

	# Effect detail sub-nodes (shared by status and injury formatters).
	# Container names changed during the buff/affliction/injury rework — try new names
	# first, fall back to legacy names so older scene revisions still work.
	if _effect_description != null:
		var header_hbox: HBoxContainer = _effect_description.get_node("HBoxContainer")
		var header_node: Node = header_hbox.get_node_or_null("EffectHeader")
		if header_node == null:
			header_node = header_hbox.get_node_or_null("StatusHeader")
		_effect_detail_name_label = _find_label_in_node(header_node) if header_node != null else null
		_effect_detail_icon = header_hbox.get_node_or_null("TextureRect") as TextureRect

		var desc_panel: PanelContainer = _effect_description.get_node_or_null("EffectDescriptionContainer")
		if desc_panel == null:
			desc_panel = _effect_description.get_node_or_null("PowerPanelContainer2")
		if desc_panel != null:
			_effect_detail_description_label = _find_label_in_node(desc_panel.get_node("MarginContainer"))

	# Injuries section — 4 slots laid out as 2 columns of 2 panels each.
	# Empty placeholder template = InjuryPanel3's stylebox; filled = InjuryPanel1's.
	_injuries_section = center_column.get_node_or_null("InjuriesSection")
	if _injuries_section != null:
		var injury_hbox: HBoxContainer = _injuries_section.get_node("HBoxContainer")
		_injury_column_1 = injury_hbox.get_node("VBoxContainer") as VBoxContainer
		_injury_column_2 = injury_hbox.get_node("VBoxContainer2") as VBoxContainer
		# Order: column 1 (top, bottom), column 2 (top, bottom)
		var p1: PanelContainer = _injury_column_1.get_node_or_null("InjuryPanel1") as PanelContainer
		var p4: PanelContainer = _injury_column_1.get_node_or_null("InjuryPanel4") as PanelContainer
		var p2: PanelContainer = _injury_column_2.get_node_or_null("InjuryPanel2") as PanelContainer
		var p3: PanelContainer = _injury_column_2.get_node_or_null("InjuryPanel3") as PanelContainer
		for panel: PanelContainer in [p1, p4, p2, p3]:
			if panel != null:
				_injury_panels.append(panel)
		# Cache the two stylebox templates from existing panels.
		if p1 != null:
			_injury_filled_stylebox = p1.get_theme_stylebox("panel")
		if p3 != null:
			_injury_empty_stylebox = p3.get_theme_stylebox("panel")


# =============================================================================
# TABLET CLICK HANDLING
# =============================================================================

func _setup_tablet_input() -> void:
	for i: int in range(_move_chips.size()):
		var index := i
		# Chips are real buttons — pressed inspects. A depleted chip is
		# disabled-tier but must STAY inspectable: in this venue the "why"
		# IS the detail pane, so denied routes to the same select.
		_move_chips[i].pressed.connect(func() -> void:
			_select(SelectionType.MOVE, index))
		_move_chips[i].denied.connect(func() -> void:
			_select(SelectionType.MOVE, index))

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

	for i: int in range(_injury_panels.size()):
		var index := i
		_ensure_unique_style(_injury_panels[i])
		_set_children_mouse_pass(_injury_panels[i])
		_injury_panels[i].gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select(SelectionType.INJURY, index)
		)
		_injury_panels[i].mouse_filter = Control.MOUSE_FILTER_STOP


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
	# Move chips speak the vocabulary: snapping brackets = "you are
	# inspecting this" (§14 selected). The other tablet families keep the
	# border trick until they get their own adoption.
	for i: int in range(_move_chips.size()):
		_move_chips[i].selected = \
				_selection_type == SelectionType.MOVE and i == _selection_index

	for panel: PanelContainer in _passive_panels:
		_set_tablet_selected(panel, false)
	for panel: PanelContainer in _status_panels:
		_set_tablet_selected(panel, false)
	for panel: PanelContainer in _injury_panels:
		_set_tablet_selected(panel, false)

	var panels: Array[PanelContainer] = []
	match _selection_type:
		SelectionType.PASSIVE:
			panels = _passive_panels
		SelectionType.STATUS:
			panels = _status_panels
		SelectionType.INJURY:
			panels = _injury_panels

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
	if _effect_description:
		_effect_description.visible = false


func _update_detail_panel() -> void:
	_hide_all_details()

	match _selection_type:
		SelectionType.MOVE:
			_show_move_detail(_selection_index)
		SelectionType.PASSIVE:
			_show_passive_detail(_selection_index)
		SelectionType.STATUS:
			_show_status_detail(_selection_index)
		SelectionType.INJURY:
			_show_injury_detail(_selection_index)


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
	_update_injury_panels()


func _update_portrait() -> void:
	if _portrait == null:
		return
	CharacterPortrait.bind_to_texture_rect(_portrait, _character_data)


func _update_identity() -> void:
	if _name_label:
		_name_label.text = _character_data.character_name.to_upper()

	if _class_label:
		var class_text: String = Enums.get_class_display_name(_character_data.current_class)
		_class_label.text = class_text.to_upper() + " Lv." + str(_character_data.level)
		# XP progress rides the class row for PLAYER units (2026-08-03 XP
		# visibility pass — combat XP existed for months with no readout
		# anywhere, so players believed fighting earned nothing). Enemies
		# never earn XP; showing their 0/100 would be noise.
		if _unit != null and _unit.get("faction") == Enums.UnitFaction.PLAYER:
			_class_label.text += "  ·  %d/100 XP" % _character_data.experience

	# Type icons
	var primary_visible := _character_data.primary_type != Enums.ElementalType.NONE
	if _type_icon_primary:
		_type_icon_primary.texture = _get_elemental_icon(_character_data.primary_type)
	if _type_icon_container_primary:
		_type_icon_container_primary.visible = primary_visible
		if primary_visible:
			_type_icon_container_primary.tooltip_text = "Type: %s" % Enums.elemental_type_to_string(_character_data.primary_type).capitalize()

	var secondary_visible := _character_data.secondary_type != Enums.ElementalType.NONE
	if _type_icon_secondary:
		_type_icon_secondary.texture = _get_elemental_icon(_character_data.secondary_type)
	if _type_icon_container_secondary:
		_type_icon_container_secondary.visible = secondary_visible
		if secondary_visible:
			_type_icon_container_secondary.tooltip_text = "Type: %s" % Enums.elemental_type_to_string(_character_data.secondary_type).capitalize()


func _update_hp() -> void:
	var current_hp: int = _unit.current_hp if _unit != null else _character_data.max_hp
	var max_hp: int = _character_data.max_hp

	var health_percent: float = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	var health_color: Color = GameColors.get_health_color(health_percent)

	var health_bg_color: Color = GameColors.get_health_bg_color(health_percent)

	if _hp_label:
		_hp_label.text = str(current_hp)
		_hp_label.add_theme_color_override("font_color", health_color)
		if _hp_label.material is ShaderMaterial:
			_hp_label.material.set_shader_parameter("glow_color", health_bg_color)
	if _hp_max_label:
		_hp_max_label.text = "/%d" % max_hp
		_hp_max_label.add_theme_color_override("font_color", health_color)
		if _hp_max_label.material is ShaderMaterial:
			_hp_max_label.material.set_shader_parameter("glow_color", health_bg_color)

	if _hp_bar and _hp_bar_background:
		var fill_ratio: float = clampf(float(current_hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 0.0
		_hp_bar.size.x = fill_ratio * _hp_bar_background.size.x
		_hp_bar.color = health_color
		_hp_bar_background.color = health_bg_color
		if _hp_bar.material is ShaderMaterial:
			_hp_bar.material.set_shader_parameter("glow_color", health_bg_color)
		if _hp_bar_background.material is ShaderMaterial:
			_hp_bar_background.material.set_shader_parameter("glow_color", health_bg_color)

	if _hp_censor != null and _character_data != null:
		_hp_censor.set_censored(_character_data.is_health_bar_hidden(current_hp))


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

		# Track, fill, bonus and the at-cap colour all come from the shared
		# StatCapBar now (2026-08-06). The scene's StatBar/StatBonusBar
		# ColorRects are hidden rather than deleted so the .tscn keeps working
		# if this ever gets reverted; the sizing math they used lived here in
		# a near-identical copy of CharacterSheetPanel's, scaled against a flat
		# STAT_DISPLAY_MAX = 60 that matched no real ceiling.
		var cap_bar: StatCapBar = row.get("cap_bar")
		if cap_bar:
			cap_bar.set_stat(_character_data, stat_name)


func _update_move_tablets() -> void:
	for i: int in range(_move_chips.size()):
		var chip_button := _move_chips[i]
		if i < _character_data.equipped_moves.size() \
				and _character_data.equipped_moves[i] != null:
			var move: Move = _character_data.equipped_moves[i]
			chip_button.visible = true
			# VOID lock is per-battle — only meaningful with a live unit.
			# NO assigned marker: this venue inspects the roster, it doesn't
			# arm moves (was "brackets double-book" under the parked-bracket
			# scheme, RQD 2026-07-19; the orbit COULD coexist with inspection
			# brackets now — revisit only if the marker hunt asks for it).
			chip_button.setup(move, false,
					_unit != null and _unit.is_move_index_locked(i))
		else:
			chip_button.visible = false


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
			# VOID can lock passives too; is_passive_index_locked is false when the
			# panel is showing base-pool passives (nothing equipped to lock).
			VoidLockOverlay.set_locked(panel, _unit != null and _unit.is_passive_index_locked(i))
		else:
			panel.visible = false
			VoidLockOverlay.set_locked(panel, false)

	if _passives_section:
		_passives_section.visible = not passive_names.is_empty()


## Slot 0 holds the active buff (if any), slot 1 holds the active debuff.
## Slots 2+ are hidden — under the 1-buff/1-debuff slot model they are unused.
func _update_status_tablets() -> void:
	var slot_effects: Array[StatusEffect] = _get_slot_effects()
	var configs := StatusEffectData.get_default_configs()

	for i: int in range(_status_panels.size()):
		var panel: PanelContainer = _status_panels[i]
		var hbox: HBoxContainer = panel.get_node("HBoxContainer")
		var name_label: Label = _find_label_in_node(hbox.get_node("MarginContainer"))
		var icon_container: MarginContainer = hbox.get_node("ElemetalTypeIconContainer") if hbox.has_node("ElemetalTypeIconContainer") else null
		var type_icon: TextureRect = icon_container.get_node("TextureRect") if icon_container else null

		var effect: StatusEffect = slot_effects[i] if i < slot_effects.size() else null
		if effect == null:
			panel.visible = false
			continue

		var config: StatusEffectData = configs.get(effect.effect_type_name, null)
		panel.visible = true

		if name_label:
			if config != null and config.abbrev_name != "":
				name_label.text = config.abbrev_name.to_upper()
			else:
				name_label.text = effect.effect_type_name.to_upper()

		if type_icon:
			if config != null and config.icon_path != "" and ResourceLoader.exists(config.icon_path):
				type_icon.texture = load(config.icon_path) as Texture2D
				type_icon.visible = true
			else:
				type_icon.visible = false

	if _status_section:
		var any_visible: bool = false
		for effect: StatusEffect in slot_effects:
			if effect != null:
				any_visible = true
				break
		_status_section.visible = any_visible


## Updates the InjuriesSection panels to reflect the unit's current_injuries.
##
## Layout: 4 panels arranged as 2 columns of 2 (col1: [Panel1, Panel4], col2: [Panel2, Panel3]).
## Per column rules:
##   - Major injury (2 slots): one panel Filled (Major content), the other Hidden.
##     With only 1 panel visible in the column, EXPAND_FILL makes it look Major-sized.
##   - Two Minors: both Filled (Minor content). Both visible → each takes half the column.
##   - One Minor: 1 Filled + 1 Empty placeholder. Both visible → both Minor-sized.
##   - Empty column: 2 Empty placeholders.
##
## The whole InjuriesSection is hidden if the unit has zero current_injuries.
func _update_injury_panels() -> void:
	# Reset the slot→injury mapping (used by _show_injury_detail click handler).
	_injury_slot_to_injury.clear()
	for i: int in range(_injury_panels.size()):
		_injury_slot_to_injury.append(null)

	# Hide the entire section if the unit has no injuries.
	if _injuries_section == null:
		return
	var injuries: Array[Injury] = []
	if _character_data != null:
		injuries = _character_data.current_injuries
	if injuries.is_empty():
		_injuries_section.visible = false
		return
	_injuries_section.visible = true

	# Place injuries into columns. Each column has capacity 2 slots.
	# Column 1 panels: [_injury_panels[0]=Panel1 (top), _injury_panels[1]=Panel4 (bottom)]
	# Column 2 panels: [_injury_panels[2]=Panel2 (top), _injury_panels[3]=Panel3 (bottom)]
	var col1_remaining: int = 2
	var col2_remaining: int = 2
	var col1_assignments: Array[Injury] = []  # ordered by placement
	var col2_assignments: Array[Injury] = []

	for injury: Injury in injuries:
		var slots: int = injury.slots_occupied()
		if col1_remaining >= slots:
			col1_assignments.append(injury)
			col1_remaining -= slots
		elif col2_remaining >= slots:
			col2_assignments.append(injury)
			col2_remaining -= slots
		# else: would exceed slot cap — shouldn't happen because commit enforces this,
		# but if it does we silently drop the overflow rather than crash.

	_apply_column_state(col1_assignments, [_injury_panels[0], _injury_panels[1]], 0)
	_apply_column_state(col2_assignments, [_injury_panels[2], _injury_panels[3]], 2)


## Apply the visual state for a single column.
##   assignments: ordered list of injuries to place (max 2)
##   panels:      [top_panel, bottom_panel]
##   slot_offset: index into _injury_slot_to_injury for the top panel (0 for col1, 2 for col2)
func _apply_column_state(assignments: Array[Injury], panels: Array, slot_offset: int) -> void:
	if panels.size() != 2:
		return
	var top_panel: PanelContainer = panels[0]
	var bot_panel: PanelContainer = panels[1]

	if assignments.is_empty():
		# Empty column → both panels show as empty placeholders.
		_set_injury_panel(top_panel, null, slot_offset)
		_set_injury_panel(bot_panel, null, slot_offset + 1)
		return

	if assignments.size() == 1 and assignments[0].slots_occupied() == 2:
		# Major in this column → only top panel visible (Major content), bottom hidden.
		_set_injury_panel(top_panel, assignments[0], slot_offset)
		bot_panel.visible = false
		return

	# 1 or 2 minors in the column.
	_set_injury_panel(top_panel, assignments[0], slot_offset)
	if assignments.size() >= 2:
		_set_injury_panel(bot_panel, assignments[1], slot_offset + 1)
	else:
		_set_injury_panel(bot_panel, null, slot_offset + 1)  # empty placeholder


## Set the visual state of a single injury panel.
##   injury: null = empty placeholder; otherwise filled with this injury's data.
##   slot_index: position in _injury_slot_to_injury so the click handler can look up the right injury.
func _set_injury_panel(panel: PanelContainer, injury: Injury, slot_index: int) -> void:
	if panel == null:
		return
	panel.visible = true
	_injury_slot_to_injury[slot_index] = injury

	# Apply the right stylebox.
	var target_style: StyleBox = _injury_filled_stylebox if injury != null else _injury_empty_stylebox
	if target_style != null:
		panel.add_theme_stylebox_override("panel", target_style.duplicate())

	# Find the inner widgets (same path used by _update_status_tablets for shared layout).
	var hbox: HBoxContainer = panel.get_node_or_null("HBoxContainer") as HBoxContainer
	if hbox == null:
		return
	var name_label: Label = _find_label_in_node(hbox.get_node_or_null("MarginContainer"))
	var icon_container: MarginContainer = hbox.get_node_or_null("ElemetalTypeIconContainer") as MarginContainer
	var type_icon: TextureRect = icon_container.get_node_or_null("TextureRect") as TextureRect if icon_container != null else null
	var usages_container: Node = hbox.get_node_or_null("UsagesContainer")
	var usages_label: Label = _find_label_in_node(usages_container) if usages_container != null else null
	var infinity_symbol: Node = usages_container.get_node_or_null("InfinitySymbol") if usages_container != null else null

	if injury == null:
		# Empty placeholder — clear all content.
		if name_label:
			name_label.text = ""
		if type_icon:
			type_icon.visible = false
		if usages_label:
			usages_label.visible = false
		if infinity_symbol:
			infinity_symbol.visible = false
		return

	# Filled — show injury data.
	var data: InjuryData = injury.get_data()
	if name_label:
		var display: String = data.display_name if data != null else injury.injury_id
		name_label.text = display.to_upper()
	if type_icon:
		if data != null and data.icon_path != "" and ResourceLoader.exists(data.icon_path):
			type_icon.texture = load(data.icon_path) as Texture2D
			type_icon.visible = true
		else:
			type_icon.visible = false
		_apply_hypoesthesia_static(type_icon, injury.injury_id == "hypoesthesia")
	if usages_label:
		usages_label.text = str(injury.battles_remaining)
		usages_label.visible = true
	if infinity_symbol:
		# Permanent injuries (scars) deferred from v1 — never show infinity yet.
		infinity_symbol.visible = false


func _apply_hypoesthesia_static(icon: TextureRect, enabled: bool) -> void:
	icon.material = _HYPOESTHESIA_STATIC_MATERIAL if enabled else null


## Returns a fixed-length array sized to _status_panels.size():
##   [0] = active buff or null
##   [1] = active debuff or null
##   [2..] = null
func _get_slot_effects() -> Array[StatusEffect]:
	var slots: Array[StatusEffect] = []
	for i: int in range(_status_panels.size()):
		slots.append(null)

	if _unit == null:
		return slots
	var effects: Array = _unit.active_status_effects
	for entry: StatusEffect in effects:
		match entry.category:
			Enums.EffectCategory.BUFF:
				if slots[0] == null:
					slots[0] = entry
			Enums.EffectCategory.DEBUFF:
				if slots.size() > 1 and slots[1] == null:
					slots[1] = entry
	return slots


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
	if _move_detail_damage_type_container:
		var damage_type_name: String = Enums.DamageType.keys()[move.damage_type].capitalize()
		if move.damage_type == Enums.DamageType.SUPPORT:
			_move_detail_damage_type_container.tooltip_text = "Move type: %s" % damage_type_name
		else:
			_move_detail_damage_type_container.tooltip_text = "Damage type: %s" % damage_type_name

	if _move_detail_power_label:
		_move_detail_power_label.text = "%d" % move.base_power if move.base_power > 0 else "--"

	if _move_detail_range_label:
		# Base reach only — Extendo's +1 and other passives are situational and
		# belong to the combat preview, not the move's stat sheet.
		_move_detail_range_label.text = "%d" % move.attack_range

	if _move_detail_accuracy_label:
		# Shows the move's base accuracy rating — the actual combat hit chance
		# (which factors skill/agility/passives) is shown in the combat preview
		# panel during target selection, where attacker + defender are known.
		_move_detail_accuracy_label.text = "%d%%" % move.accuracy

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
	var slot_effects: Array[StatusEffect] = _get_slot_effects()
	if index < 0 or index >= slot_effects.size():
		return
	var effect: StatusEffect = slot_effects[index]
	if effect == null:
		return
	if _effect_description == null:
		return

	_effect_description.visible = true

	var configs := StatusEffectData.get_default_configs()
	var config: StatusEffectData = configs.get(effect.effect_type_name, null)

	if _effect_detail_name_label:
		_effect_detail_name_label.text = effect.effect_type_name.to_upper()

	if _effect_detail_icon:
		var icon: Texture2D = _get_status_effect_icon_by_name(effect.effect_type_name)
		_effect_detail_icon.texture = icon
		_effect_detail_icon.visible = icon != null

	if _effect_detail_description_label:
		var desc_text: String = ""
		if config != null:
			desc_text = config.description
		if effect.stacks > 0:
			desc_text += "\n%d stack(s) remaining." % effect.stacks
		_effect_detail_description_label.text = desc_text


## Show injury details in the shared EffectDescription right-column container.
## Takes the same slot index as the InjuryPanel that was clicked; resolves to the
## actual Injury via the parallel _injury_slot_to_injury list.
func _show_injury_detail(index: int) -> void:
	if index < 0 or index >= _injury_slot_to_injury.size():
		return
	var injury: Injury = _injury_slot_to_injury[index]
	if injury == null:
		return  # Empty slot click — no detail to show
	if _effect_description == null:
		return

	_effect_description.visible = true

	var data: InjuryData = injury.get_data()

	if _effect_detail_name_label:
		var severity_tag: String = " (Major)" if injury.severity == Enums.InjurySeverity.MAJOR else ""
		var display: String = data.display_name if data != null else injury.injury_id
		_effect_detail_name_label.text = display.to_upper() + severity_tag

	if _effect_detail_icon:
		if data != null and data.icon_path != "" and ResourceLoader.exists(data.icon_path):
			_effect_detail_icon.texture = load(data.icon_path) as Texture2D
			_effect_detail_icon.visible = true
		else:
			_effect_detail_icon.visible = false

	if _effect_detail_description_label:
		var desc_text: String = ""
		if data != null:
			desc_text = data.description
		desc_text += "\n%d battle(s) until recovered." % injury.battles_remaining
		_effect_detail_description_label.text = desc_text


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
	var container: Control = _find_type_icon_container(row, index)
	if container == null:
		return null
	for child: Node in container.get_children():
		if child is TextureRect:
			return child as TextureRect
	return null


func _find_type_icon_container(row: Control, index: int) -> Control:
	## Find a type icon container inside a unit_row instance.
	if row == null:
		return null
	var hbox: Node = row.get_node_or_null("HBoxContainer")
	if hbox == null:
		return null
	var container_name: String = "UnitTypeIconContainer" if index == 0 else "UnitTypeIconContainer2"
	return hbox.get_node_or_null(container_name) as Control


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
