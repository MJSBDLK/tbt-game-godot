## Displays a condensed unit summary in the left panel on hover/select.
## Shows name, class, HP, move chips with PP fill, passives, and status icons.
## Replaces the old programmatic UnitInfoPanel.
class_name UnitPreviewPanel
extends PanelContainer


var _tracked_unit: Unit = null


func get_tracked_unit() -> Unit:
	return _tracked_unit
var _passive_configs: Dictionary = {}  # passive_name -> { abbrevName, description }

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
var _hp_censor: StaticCensorOverlay = null

# Sections
var _moves_container: VBoxContainer = null
var _passives_container: GridContainer = null
var _status_container: GridContainer = null

# Threat-zone pin chip (enemies only) — see _build_range_toggle
var _range_toggle_button: Button = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resolve_nodes()
	_load_passive_configs()
	# Stay visible when previewing this scene standalone (F6)
	if get_tree().current_scene != self:
		visible = false


func _resolve_nodes() -> void:
	var vbox: VBoxContainer = get_node("MarginContainer/VBoxContainer")
	var header: HBoxContainer = vbox.get_node("HBoxContainer")
	var info_vbox: VBoxContainer = header.get_node("VBoxContainer")

	# Recursive name lookup survives layout reshuffles (e.g. wrapping the
	# portrait in a PanelContainer for the 1px AA border).
	_portrait = header.find_child("Portrait", true, false) as TextureRect
	_type_icon_primary = info_vbox.get_node("HBoxContainer/TextureRect") as TextureRect
	_type_icon_secondary = info_vbox.get_node("HBoxContainer/TextureRect2") as TextureRect
	_name_label = info_vbox.get_node("MarginContainer/Label") as Label
	_class_level_label = info_vbox.get_node("MarginContainer2/Label") as Label

	var hp_bar: HBoxContainer = vbox.get_node("HPBar")
	_hp_background = hp_bar.get_node("HPBarContainer/HpBackground") as ColorRect
	_hp_fill = hp_bar.get_node("HPBarContainer/HPFill") as ColorRect
	# Both bars share `hud_glow.tres` as a scene-level ExtResource. Duplicate per-node so
	# we can drive each one's `glow_color` independently from HP without bleeding into
	# every other UI element using the same material.
	if _hp_background.material != null:
		_hp_background.material = _hp_background.material.duplicate()
	if _hp_fill.material != null:
		_hp_fill.material = _hp_fill.material.duplicate()
	_hp_value_label = hp_bar.get_node("HBoxContainer/MarginContainer/Label") as Label
	_hp_max_label = hp_bar.get_node("HBoxContainer/MarginContainer2/Label") as Label
	if _hp_value_label != null and _hp_value_label.material != null:
		_hp_value_label.material = _hp_value_label.material.duplicate()
	if _hp_max_label != null and _hp_max_label.material != null:
		_hp_max_label.material = _hp_max_label.material.duplicate()

	_hp_censor = StaticCensorOverlay.new()
	hp_bar.add_child(_hp_censor)
	# Cover the bar + current value, but leave "/max" readable.
	var hp_value_container: Control = hp_bar.get_node("HBoxContainer/MarginContainer") as Control
	var hp_bar_container: Control = hp_bar.get_node("HPBarContainer") as Control
	var targets: Array[Control] = [hp_bar_container, hp_value_container]
	_hp_censor.set_targets(targets)

	_moves_container = vbox.get_node("MovesContainer") as VBoxContainer
	_passives_container = vbox.get_node("PassivesContainer") as GridContainer
	_status_container = vbox.get_node("StatusContainer") as GridContainer
	_build_range_toggle(vbox)


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
	_update_range_toggle(unit)


func hide_panel() -> void:
	_tracked_unit = null
	visible = false


func refresh() -> void:
	if _tracked_unit != null and is_instance_valid(_tracked_unit):
		show_unit(_tracked_unit)


# =============================================================================
# DISPLAY UPDATES
# =============================================================================

# =============================================================================
# THREAT-ZONE PIN CHIP
# =============================================================================
# Enemies only: toggles this enemy's danger zone via ThreatOverlayController.
# Pins PERSIST after the panel closes (design call 2026-07: tap-anywhere
# dismisses the panel, so panel lifetime can't own zone lifetime); V /
# clear-all is the global off-switch. Built in code — the panel scene predates
# the threat overlay. The panel root is MOUSE_FILTER_IGNORE by design; the
# button itself is STOP, so it's the one clickable thing on the panel and its
# press is consumed in HUDViewport (won't leak a map click underneath).

func _build_range_toggle(vbox: VBoxContainer) -> void:
	_range_toggle_button = Button.new()
	_range_toggle_button.visible = false
	_range_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_range_toggle_button.custom_minimum_size = Vector2(0, 12)
	_range_toggle_button.tooltip_text = "Show this enemy's danger zone on the map. Stays on until toggled off (V clears all)."
	var ui_manager: Node = UIManager
	if ui_manager != null:
		_range_toggle_button.add_theme_font_override("font", ui_manager.font_5px)
		_range_toggle_button.add_theme_font_size_override("font_size", 5)
	_range_toggle_button.pressed.connect(_on_range_toggle_pressed)
	vbox.add_child(_range_toggle_button)


func _threat_controller() -> ThreatOverlayController:
	# The controller lives world-side (battle_scene); this panel lives in
	# HUDViewport. Groups span the whole SceneTree, so lookup works across
	# viewports. Null outside battles (prep screen, menus).
	return get_tree().get_first_node_in_group(
			ThreatOverlayController.GROUP_NAME) as ThreatOverlayController


func _on_range_toggle_pressed() -> void:
	var controller := _threat_controller()
	if controller == null or _tracked_unit == null or not is_instance_valid(_tracked_unit):
		return
	controller.toggle_unit(_tracked_unit)
	_update_range_toggle(_tracked_unit)


func _update_range_toggle(unit: Unit) -> void:
	if _range_toggle_button == null:
		return
	var controller := _threat_controller()
	var is_living_enemy: bool = unit != null and is_instance_valid(unit) \
			and unit.faction == Enums.UnitFaction.ENEMY and not unit.is_defeated()
	_range_toggle_button.visible = is_living_enemy and controller != null
	if not _range_toggle_button.visible:
		return
	# Track external state changes (V clearing all, pin pruned on death) so the
	# chip's label never lies while the panel is up.
	if not controller.changed.is_connected(_on_threat_state_changed):
		controller.changed.connect(_on_threat_state_changed)
	_range_toggle_button.text = "HIDE RANGE" if controller.is_unit_shown(unit) else "SHOW RANGE"


func _on_threat_state_changed() -> void:
	if visible and _tracked_unit != null and is_instance_valid(_tracked_unit):
		_update_range_toggle(_tracked_unit)


func _update_header(unit: Unit) -> void:
	var data: CharacterData = unit.character_data

	# Portrait — bind_to_texture_rect promotes the slot to an HD line-art
	# overlay if the character has one, falling back to the painted pixel
	# portrait otherwise.
	CharacterPortrait.bind_to_texture_rect(_portrait, data)

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
	if _hp_fill.material is ShaderMaterial:
		_hp_fill.material.set_shader_parameter("glow_color", health_bg_color)

	# Background tracks health color too
	_hp_background.color = health_bg_color
	if _hp_background.material is ShaderMaterial:
		_hp_background.material.set_shader_parameter("glow_color", health_bg_color)

	# Labels
	_hp_value_label.text = str(current_hp)
	_hp_value_label.add_theme_color_override("font_color", health_color)
	if _hp_value_label.material is ShaderMaterial:
		_hp_value_label.material.set_shader_parameter("glow_color", health_bg_color)
	_hp_max_label.text = "/%d" % max_hp
	_hp_max_label.add_theme_color_override("font_color", health_color)
	if _hp_max_label.material is ShaderMaterial:
		_hp_max_label.material.set_shader_parameter("glow_color", health_bg_color)

	if _hp_censor != null:
		_hp_censor.set_censored(unit.character_data.is_health_bar_hidden(current_hp))


func _update_moves(unit: Unit) -> void:
	var data: CharacterData = unit.character_data
	var moves: Array[Move] = data.equipped_moves if data != null else []

	# Since the 2026-07-19 adoption these are real MoveChipButtons in display
	# mode (no hover/focus/press — the lit contract stays honest). The scene's
	# authored placeholder chips are cleared on first update; they stay in the
	# .tscn so the editor preview still reads.
	var chip_buttons: Array[MoveChipButton] = []
	for child: Node in _moves_container.get_children():
		if child is MoveChipButton:
			chip_buttons.append(child)
		else:
			_moves_container.remove_child(child)
			child.queue_free()
	while chip_buttons.size() < moves.size():
		var chip_button := MoveChipButton.new()
		chip_button.custom_minimum_size = Vector2(0, 14)
		chip_button.make_display_only()
		_moves_container.add_child(chip_button)
		chip_buttons.append(chip_button)

	for i: int in range(chip_buttons.size()):
		var chip_button := chip_buttons[i]
		if i < moves.size() and moves[i] != null:
			chip_button.visible = true
			# The assigned move carries its parked brackets here too — the
			# vocabulary means the same thing in every venue.
			chip_button.setup(moves[i], unit.assigned_move == moves[i],
					unit.is_move_index_locked(i))
		else:
			chip_button.visible = false


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
				var passive_name: String = ""
				if passives[i] is String:
					passive_name = passives[i]
				elif passives[i].get("passive_name") != null:
					passive_name = passives[i].passive_name
				label.text = _get_passive_abbrev(passive_name)
			# VOID can lock a passive slot too (same combined pool as moves).
			VoidLockOverlay.set_locked(chip, unit.is_passive_index_locked(i))
		else:
			chip.visible = false
			VoidLockOverlay.set_locked(chip, false)

	_passives_container.visible = not passives.is_empty()


## Slot 0 = active buff, slot 1 = active debuff. Remaining chips are hidden.
func _update_statuses(unit: Unit) -> void:
	var statuses: Array = unit.active_status_effects
	var configs := StatusEffectData.get_default_configs()

	var status_chips: Array[Node] = []
	for child: Node in _status_container.get_children():
		if child is ColorRect:
			status_chips.append(child)

	# Pick first buff + first debuff
	var buff: StatusEffect = null
	var debuff: StatusEffect = null
	for entry: StatusEffect in statuses:
		if entry.category == Enums.EffectCategory.BUFF and buff == null:
			buff = entry
		elif entry.category == Enums.EffectCategory.DEBUFF and debuff == null:
			debuff = entry
	var slot_effects: Array[StatusEffect] = [buff, debuff]

	var any_visible: bool = false
	for i: int in range(status_chips.size()):
		var chip: ColorRect = status_chips[i] as ColorRect
		var effect: StatusEffect = slot_effects[i] if i < slot_effects.size() else null
		if effect != null:
			chip.visible = true
			any_visible = true
			_update_status_chip(chip, effect, configs.get(effect.effect_type_name, null))
		else:
			chip.visible = false

	_status_container.visible = any_visible


func _update_status_chip(chip: ColorRect, effect: StatusEffect, config: StatusEffectData) -> void:
	var parts := _find_status_chip_parts(chip)

	# Icon
	if parts.icon != null:
		if config != null and config.icon_path != "":
			parts.icon.texture = load(config.icon_path) as Texture2D
			parts.icon.visible = true
		else:
			parts.icon.visible = false

	# Name label
	if parts.name_label != null:
		if config != null and config.abbrev_name != "":
			parts.name_label.text = config.abbrev_name
		else:
			parts.name_label.text = effect.effect_type_name.capitalize()

	# Stack count label (formerly "turns remaining")
	if parts.turns_label != null:
		parts.turns_label.text = str(effect.stacks)


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


func _get_elemental_icon(element_type: Enums.ElementalType) -> Texture2D:
	if element_type == Enums.ElementalType.NONE:
		return null
	var type_name: String = Enums.elemental_type_to_string(element_type).to_lower()
	var path: String = "res://art/sprites/ui/elemental_type_icons_10x10/%s.png" % type_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _load_passive_configs() -> void:
	var file := FileAccess.open("res://data/passives.json", FileAccess.READ)
	if file == null:
		DebugConfig.log_error("UnitPreviewPanel: Could not load passives.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		DebugConfig.log_error("UnitPreviewPanel: Failed to parse passives.json")
		return
	_passive_configs = json.data as Dictionary


func _get_passive_abbrev(passive_name: String) -> String:
	var config: Variant = _passive_configs.get(passive_name, null)
	if config is Dictionary and config.has("abbrevName"):
		return config["abbrevName"]
	return passive_name


## Returns {icon: TextureRect, name_label: Label, turns_label: Label} for a status chip.
## Status chip layout: ColorRect > HBoxContainer > [IconContainer, NameContainer, Spacer, TurnsContainer]
func _find_status_chip_parts(chip: ColorRect) -> Dictionary:
	var result := { "icon": null, "name_label": null, "turns_label": null }
	for child: Node in chip.get_children():
		if not child is HBoxContainer:
			continue
		var hbox_children: Array[Node] = child.get_children()
		var labels_found: Array[Label] = []
		for hbox_child: Node in hbox_children:
			if hbox_child is MarginContainer:
				for grandchild: Node in hbox_child.get_children():
					if grandchild is TextureRect and result.icon == null:
						result.icon = grandchild
					elif grandchild is Label:
						labels_found.append(grandchild)
		# First label is the name, last label is the turns count
		if labels_found.size() >= 1:
			result.name_label = labels_found[0]
		if labels_found.size() >= 2:
			result.turns_label = labels_found[labels_found.size() - 1]
	return result
