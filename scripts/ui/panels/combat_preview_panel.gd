## Shows combat preview during attack targeting.
## Displays attacker/defender info, damage, hit count, counter status, projected HP.
## Located in the right panel, shown when hovering over valid targets.
class_name CombatPreviewPanel
extends PanelContainer


const PANEL_WIDTH: int = 140

# Attacker section
var _attacker_name_label: Label = null
var _attacker_move_label: Label = null
var _attacker_damage_label: Label = null
var _attacker_hits_label: Label = null
var _effectiveness_label: Label = null

# Separator
var _separator: ColorRect = null

# Defender section
var _defender_name_label: Label = null
var _defender_hp_label: Label = null
var _defender_hp_bar_background: ColorRect = null
var _defender_hp_bar_current: ColorRect = null
var _defender_hp_bar_projected: ColorRect = null
var _counter_label: Label = null
var _counter_damage_label: Label = null


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null:
		var border: Variant = ui_manager.create_combat_preview_border()
		if border != null:
			add_theme_stylebox_override("panel", border)
		else:
			add_theme_stylebox_override("panel", ui_manager.create_pda_style())

	_build_content()
	visible = false


# =============================================================================
# PUBLIC API
# =============================================================================

func show_preview(attacker: Node, defender: Node, move: Move) -> void:
	if attacker == null or defender == null or move == null:
		hide_panel()
		return

	visible = true
	_update_attacker_section(attacker, defender, move)
	_update_defender_section(attacker, defender, move)


func hide_panel() -> void:
	visible = false


# =============================================================================
# ATTACKER SECTION
# =============================================================================

func _update_attacker_section(attacker: Node, defender: Node, move: Move) -> void:
	var attacker_name: String = attacker.get("unit_name") if attacker.get("unit_name") else "???"
	var attacker_faction: Enums.UnitFaction = attacker.get("faction")
	_attacker_name_label.text = attacker_name
	_attacker_name_label.add_theme_color_override("font_color", _get_faction_color(attacker_faction))

	_attacker_move_label.text = move.move_name

	# Damage per hit
	var damage_per_hit := DamageCalculator.calculate_damage(attacker, defender, move)
	var hit_count := DamageCalculator.calculate_attack_count(attacker, defender)
	_attacker_damage_label.text = "DMG: %d" % damage_per_hit
	_attacker_hits_label.text = "Hits: %d" % hit_count

	# Type effectiveness
	var effectiveness := DamageCalculator.get_type_effectiveness(attacker, defender, move)
	if effectiveness >= 4.0:
		_effectiveness_label.text = "4x Super Effective!"
		_effectiveness_label.add_theme_color_override("font_color", GameColors.MULTIPLIER_X4_LIGHT)
	elif effectiveness >= 2.0:
		_effectiveness_label.text = "2x Super Effective"
		_effectiveness_label.add_theme_color_override("font_color", GameColors.MULTIPLIER_X2_LIGHT)
	elif effectiveness == 1.0:
		_effectiveness_label.text = ""
	elif effectiveness > 0.0:
		_effectiveness_label.text = "Not Very Effective"
		_effectiveness_label.add_theme_color_override("font_color", GameColors.MULTIPLIER_HALF_LIGHT)
	else:
		_effectiveness_label.text = "No Effect"
		_effectiveness_label.add_theme_color_override("font_color", GameColors.MULTIPLIER_X0_LIGHT)

	DebugConfig.log_combat_preview("Preview: %s uses %s → %d dmg x%d (%.1fx)" % [
		attacker_name, move.move_name, damage_per_hit, hit_count, effectiveness])


# =============================================================================
# DEFENDER SECTION
# =============================================================================

func _update_defender_section(attacker: Node, defender: Node, move: Move) -> void:
	var defender_name: String = defender.get("unit_name") if defender.get("unit_name") else "???"
	var defender_faction: Enums.UnitFaction = defender.get("faction")
	_defender_name_label.text = defender_name
	_defender_name_label.add_theme_color_override("font_color", _get_faction_color(defender_faction))

	# Current and projected HP
	var current_hp: int = defender.get("current_hp")
	var defender_data: CharacterData = defender.get("character_data")
	var max_hp: int = defender_data.max_hp if defender_data != null else 1

	var damage_per_hit := DamageCalculator.calculate_damage(attacker, defender, move)
	var hit_count := DamageCalculator.calculate_attack_count(attacker, defender)
	var total_damage := damage_per_hit * hit_count
	var projected_hp := maxi(0, current_hp - total_damage)

	_defender_hp_label.text = "HP: %d → %d" % [current_hp, projected_hp]

	# HP bar visualization
	var bar_width: int = PANEL_WIDTH - 24
	var current_percent: float = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	var projected_percent: float = float(projected_hp) / float(max_hp) if max_hp > 0 else 0.0

	_defender_hp_bar_current.size.x = int(current_percent * bar_width)
	_defender_hp_bar_current.color = GameColors.get_health_color(current_percent)

	_defender_hp_bar_projected.size.x = int(projected_percent * bar_width)
	_defender_hp_bar_projected.color = GameColors.get_health_color(projected_percent)

	# Counter-attack info
	var can_counter := DamageCalculator.can_counter_attack(defender, attacker)
	if can_counter:
		var counter_move: Move = defender.get("assigned_move")
		var counter_damage := DamageCalculator.calculate_damage(defender, attacker, counter_move)
		var counter_hits := DamageCalculator.calculate_attack_count(defender, attacker)
		_counter_label.text = "Counter: %s" % counter_move.move_name
		_counter_label.add_theme_color_override("font_color", GameColors.TEXT_WARNING)
		_counter_damage_label.text = "DMG: %d x%d" % [counter_damage, counter_hits]
		_counter_damage_label.visible = true
	else:
		_counter_label.text = "No Counter"
		_counter_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
		_counter_damage_label.visible = false


# =============================================================================
# BUILD CONTENT
# =============================================================================

func _build_content() -> void:
	var ui_manager: Node = get_node_or_null("/root/UIManager")

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	add_child(container)

	# -- ATTACKER SECTION --
	_attacker_name_label = _create_label_8px(ui_manager)
	container.add_child(_attacker_name_label)

	_attacker_move_label = _create_label_5px(ui_manager)
	container.add_child(_attacker_move_label)

	_attacker_damage_label = _create_label_5px(ui_manager)
	container.add_child(_attacker_damage_label)

	_attacker_hits_label = _create_label_5px(ui_manager)
	container.add_child(_attacker_hits_label)

	_effectiveness_label = _create_label_5px(ui_manager)
	container.add_child(_effectiveness_label)

	# -- SEPARATOR --
	_separator = ColorRect.new()
	_separator.custom_minimum_size = Vector2(0, 1)
	_separator.color = GameColors.PDA_BORDER_GLOW
	_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_separator)

	# -- DEFENDER SECTION --
	_defender_name_label = _create_label_8px(ui_manager)
	container.add_child(_defender_name_label)

	_defender_hp_label = _create_label_5px(ui_manager)
	container.add_child(_defender_hp_label)

	# HP bar with current (behind) and projected (in front)
	var hp_bar_container := Control.new()
	hp_bar_container.custom_minimum_size = Vector2(0, 6)
	hp_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(hp_bar_container)

	var bar_width: int = PANEL_WIDTH - 24
	_defender_hp_bar_background = ColorRect.new()
	_defender_hp_bar_background.color = Color(0.1, 0.1, 0.15, 1.0)
	_defender_hp_bar_background.size = Vector2(bar_width, 4)
	_defender_hp_bar_background.position = Vector2(0, 1)
	_defender_hp_bar_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar_container.add_child(_defender_hp_bar_background)

	_defender_hp_bar_current = ColorRect.new()
	_defender_hp_bar_current.color = GameColors.HEALTH_FULL
	_defender_hp_bar_current.size = Vector2(bar_width, 4)
	_defender_hp_bar_current.position = Vector2(0, 1)
	_defender_hp_bar_current.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar_container.add_child(_defender_hp_bar_current)

	_defender_hp_bar_projected = ColorRect.new()
	_defender_hp_bar_projected.color = GameColors.HEALTH_CRITICAL
	_defender_hp_bar_projected.size = Vector2(bar_width, 4)
	_defender_hp_bar_projected.position = Vector2(0, 1)
	_defender_hp_bar_projected.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar_container.add_child(_defender_hp_bar_projected)

	# Counter info
	_counter_label = _create_label_5px(ui_manager)
	container.add_child(_counter_label)

	_counter_damage_label = _create_label_5px(ui_manager)
	container.add_child(_counter_damage_label)


func _create_label_8px(ui_manager: Node) -> Label:
	var label := Label.new()
	if ui_manager != null:
		label.add_theme_font_override("font", ui_manager.font_8px)
		label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _create_label_5px(ui_manager: Node) -> Label:
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
