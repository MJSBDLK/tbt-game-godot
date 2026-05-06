## Shows combat preview during attack targeting.
## Displays attacker/defender stats, damage preview, and projected HP.
## Located in the right panel, shown when hovering over valid targets.
##
## HOW THE WIRING WORKS:
## This script attaches to the root node of combat_preview_panel.tscn.
## In _ready(), we walk the scene tree to find each label/pip bar by its path.
## Then show_preview() just sets .text on those labels with live combat data.
## UIManager calls show_preview() / hide_panel() — we never touch the visuals.
class_name CombatPreviewPanel
extends Control


# =============================================================================
# NODE REFERENCES — hybrid approach (% unique names + relative paths)
# =============================================================================
# The 4 container-level nodes get unique names (%) so they survive reparenting.
# The labels INSIDE use relative paths from their container, because they live
# in a shared sub-scene (unit_container.tscn) — renaming them would affect
# every instance. Since both containers use the same sub-scene, the internal
# paths are identical, stored as constants.
#
# To set a unique name: right-click a node → "Access as Unique Name"

# Shared paths within each UnitContainer instance (same sub-scene structure)
const _NAME_LABEL_PATH = "UnitRow/HBoxContainer/MarginContainer/Label"
const _MOVE_LABEL_PATH = "MoveRow/HBoxContainer/MarginContainer/Label"
const _MOVE_HITS_PATH = "MoveRow/HBoxContainer/MarginContainer2/Label"
const _DAMAGE_VALUE_PATH = "PercentageAndMultipliersSection/DamageValueContainer/GlowLabel"
const _HIT_VALUE_PATH = "PercentageAndMultipliersSection/HitPercentageContainer/GlowLabel"
const _SECONDARY_VALUE_PATH = "PercentageAndMultipliersSection/SecondaryChanceContainer/GlowLabel"
const _MULTIPLIER_VALUE_PATH = "PercentageAndMultipliersSection/DamageMultiplierContainer/GlowLabel"
const _PRIMARY_TYPE_ICON_PATH = "UnitRow/HBoxContainer/UnitTypeIconContainer/TextureRect"
const _SECONDARY_TYPE_ICON_PATH = "UnitRow/HBoxContainer/UnitTypeIconContainer2/TextureRect"
const _MOVE_TYPE_ICON_PATH = "MoveRow/HBoxContainer/UnitTypeIconContainer/TextureRect"
const _MOVE_DAMAGE_TYPE_ICON_PATH = "MoveRow/HBoxContainer/UnitTypeIconContainer2/TextureRect"

# 4 unique-named containers (set "Access as Unique Name" on these in the editor)
@onready var _attacker_section: Control = %AttackerContainer
@onready var _defender_section: Control = %DefenderContainer
@onready var _top_health_pips: HealthPipBar = %AttackerHealthPips
@onready var _bottom_health_pips: HealthPipBar = %DefenderHealthPips
@onready var _attacker_arrow: TextureRect = _top_health_pips.get_node("AttackerHealthBarArrow")
@onready var _defender_arrow: TextureRect = _bottom_health_pips.get_node("DefenderHealthBarArrow")

# Labels resolved relative to their section — @onready runs in declaration order,
# so _attacker_section and _defender_section are already set when these resolve.
@onready var _attacker_name_label: Label = _attacker_section.get_node(_NAME_LABEL_PATH)
@onready var _attacker_move_label: Label = _attacker_section.get_node(_MOVE_LABEL_PATH)
@onready var _attacker_damage_label: Label = _attacker_section.get_node(_DAMAGE_VALUE_PATH)
@onready var _attacker_hit_label: Label = _attacker_section.get_node(_HIT_VALUE_PATH)
@onready var _attacker_secondary_label: Label = _attacker_section.get_node(_SECONDARY_VALUE_PATH)
@onready var _attacker_multiplier_label: Label = _attacker_section.get_node(_MULTIPLIER_VALUE_PATH)
@onready var _attacker_hits_label: Label = _attacker_section.get_node(_MOVE_HITS_PATH)

@onready var _defender_name_label: Label = _defender_section.get_node(_NAME_LABEL_PATH)
@onready var _defender_move_label: Label = _defender_section.get_node(_MOVE_LABEL_PATH)
@onready var _defender_damage_label: Label = _defender_section.get_node(_DAMAGE_VALUE_PATH)
@onready var _defender_hit_label: Label = _defender_section.get_node(_HIT_VALUE_PATH)
@onready var _defender_secondary_label: Label = _defender_section.get_node(_SECONDARY_VALUE_PATH)
@onready var _defender_multiplier_label: Label = _defender_section.get_node(_MULTIPLIER_VALUE_PATH)
@onready var _defender_hits_label: Label = _defender_section.get_node(_MOVE_HITS_PATH)

# Unit type icons (primary + secondary) and move element icon per section
@onready var _attacker_primary_type_icon: TextureRect = _attacker_section.get_node(_PRIMARY_TYPE_ICON_PATH)
@onready var _attacker_secondary_type_icon: TextureRect = _attacker_section.get_node(_SECONDARY_TYPE_ICON_PATH)
@onready var _attacker_move_type_icon: TextureRect = _attacker_section.get_node(_MOVE_TYPE_ICON_PATH)
@onready var _defender_primary_type_icon: TextureRect = _defender_section.get_node(_PRIMARY_TYPE_ICON_PATH)
@onready var _defender_secondary_type_icon: TextureRect = _defender_section.get_node(_SECONDARY_TYPE_ICON_PATH)
@onready var _defender_move_type_icon: TextureRect = _defender_section.get_node(_MOVE_TYPE_ICON_PATH)
@onready var _attacker_move_damage_type_icon: TextureRect = _attacker_section.get_node(_MOVE_DAMAGE_TYPE_ICON_PATH)
@onready var _defender_move_damage_type_icon: TextureRect = _defender_section.get_node(_MOVE_DAMAGE_TYPE_ICON_PATH)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No manual node lookup needed — @onready + % handles it automatically.
	# When this node enters the scene tree, Godot resolves all the %Names above.
	# Stay visible when previewing this scene standalone (F6)
	if get_tree().current_scene != self:
		visible = false


# =============================================================================
# PUBLIC API — called by UIManager, which is called by InputManager
# =============================================================================

func show_preview(attacker: Node, defender: Node, move: Move) -> void:
	if attacker == null or defender == null or move == null:
		hide_panel()
		return

	visible = true
	_reset_pip_colors()
	_update_attacker_section(attacker, defender, move)
	_update_defender_section(attacker, defender, move)
	_update_health_pips(attacker, defender, move)


## Like show_preview but for ally-targeting (heal/support) moves.
## `heal_amount` is the final HP that will land — caller computes via
## DamageCalculator.calculate_heal_amount so the panel never duplicates the formula.
func show_heal_preview(caster: Node, target: Node, move: Move, heal_amount: int) -> void:
	if caster == null or target == null or move == null:
		hide_panel()
		return

	visible = true
	_apply_pip_heal_colors()
	_update_caster_section_for_heal(caster, move, heal_amount)
	_update_target_section_for_heal(target)
	_update_heal_pips(caster, target, heal_amount)


func hide_panel() -> void:
	visible = false


# =============================================================================
# ATTACKER SECTION — populate the top half with attack stats
# =============================================================================

func _update_attacker_section(attacker: Node, defender: Node, move: Move) -> void:
	var attacker_name: String = attacker.get("unit_name") if attacker.get("unit_name") else "???"
	_attacker_name_label.text = _truncate(attacker_name)

	var attacker_data: CharacterData = attacker.get("character_data")
	_set_unit_type_icons(_attacker_primary_type_icon, _attacker_secondary_type_icon, attacker_data)
	_set_elemental_icon(_attacker_move_type_icon, move.element_type)
	_set_damage_type_icon(_attacker_move_damage_type_icon, move.damage_type)

	_attacker_move_label.text = _truncate(move.abbrev_name)

	# Damage per hit and hit count (from athleticism comparison)
	var damage_per_hit := DamageCalculator.calculate_damage(attacker, defender, move)
	var hit_count := DamageCalculator.calculate_attack_count(attacker, defender)
	_attacker_damage_label.text = str(damage_per_hit)
	_set_hits_label(_attacker_hits_label, hit_count)

	# Secondary chance — status effect proc chance from the move
	if move.status_effect_chance > 0.0 and move.status_effect_type != Enums.StatusEffectType.NONE:
		_attacker_secondary_label.text = "%d%%" % int(move.status_effect_chance * 100)
	else:
		_attacker_secondary_label.text = "--"

	# Type effectiveness multiplier
	var effectiveness := DamageCalculator.get_type_effectiveness(attacker, defender, move)
	_set_multiplier_label(_attacker_multiplier_label, effectiveness)

	DebugConfig.log_combat_preview("Preview: %s uses %s → %d dmg x%d (%.1fx)" % [
		attacker_name, move.move_name, damage_per_hit, hit_count, effectiveness])


# =============================================================================
# DEFENDER SECTION — populate the bottom half with counter-attack stats
# =============================================================================

func _update_defender_section(attacker: Node, defender: Node, move: Move) -> void:
	var defender_name: String = defender.get("unit_name") if defender.get("unit_name") else "???"
	_defender_name_label.text = _truncate(defender_name)

	var defender_data: CharacterData = defender.get("character_data")
	_set_unit_type_icons(_defender_primary_type_icon, _defender_secondary_type_icon, defender_data)

	var can_counter := DamageCalculator.can_counter_attack(defender, attacker)
	if can_counter:
		var counter_move: Move = defender.get("assigned_move")
		_defender_move_label.text = _truncate(counter_move.abbrev_name)
		_set_elemental_icon(_defender_move_type_icon, counter_move.element_type)
		_set_damage_type_icon(_defender_move_damage_type_icon, counter_move.damage_type)

		var counter_damage := DamageCalculator.calculate_damage(defender, attacker, counter_move)
		var counter_hits := DamageCalculator.calculate_attack_count(defender, attacker)
		_defender_damage_label.text = str(counter_damage)
		_set_hits_label(_defender_hits_label, counter_hits)

		if counter_move.status_effect_chance > 0.0 and counter_move.status_effect_type != Enums.StatusEffectType.NONE:
			_defender_secondary_label.text = "%d%%" % int(counter_move.status_effect_chance * 100)
		else:
			_defender_secondary_label.text = "--"

		var counter_effectiveness := DamageCalculator.get_type_effectiveness(
			defender, attacker, counter_move)
		_set_multiplier_label(_defender_multiplier_label, counter_effectiveness)
	else:
		_defender_move_label.text = "--"
		_defender_move_type_icon.get_parent().visible = false
		_defender_move_damage_type_icon.get_parent().visible = false
		_set_hits_label(_defender_hits_label, 0)
		_defender_damage_label.text = "0"
		_defender_hit_label.text = "--"
		_defender_secondary_label.text = "--"
		_set_multiplier_label(_defender_multiplier_label, 0.0)


# =============================================================================
# HEALTH PIPS — shader-driven HP bars with damage preview
# =============================================================================
# HealthPipBar uses two values:
#   health_fill = projected HP after damage (the green/healthy portion)
#   damage_fill = HP that will be lost (the pulsing damage preview band)
# The shader renders three zones from bottom: filled, damage preview, empty.

func _update_health_pips(attacker: Node, defender: Node, move: Move) -> void:
	var attacker_data: CharacterData = attacker.get("character_data")
	var attacker_hp: int = attacker.get("current_hp")
	var attacker_max_hp: int = attacker_data.max_hp if attacker_data else 1

	var defender_data: CharacterData = defender.get("character_data")
	var defender_hp: int = defender.get("current_hp")
	var defender_max_hp: int = defender_data.max_hp if defender_data else 1

	# Attacker HP — show counter-attack damage preview if defender can counter
	var can_counter := DamageCalculator.can_counter_attack(defender, attacker)
	if can_counter:
		var counter_move: Move = defender.get("assigned_move")
		var counter_damage := DamageCalculator.calculate_damage(defender, attacker, counter_move)
		var counter_hits := DamageCalculator.calculate_attack_count(defender, attacker)
		var attacker_projected := maxi(0, attacker_hp - counter_damage * counter_hits)
		_top_health_pips.health_fill = float(attacker_projected) / float(attacker_max_hp)
		_top_health_pips.damage_fill = float(attacker_hp - attacker_projected) / float(attacker_max_hp)
	else:
		_top_health_pips.health_fill = float(attacker_hp) / float(attacker_max_hp)
		_top_health_pips.damage_fill = 0.0

	# Defender HP — show incoming attack damage preview
	var damage_per_hit := DamageCalculator.calculate_damage(attacker, defender, move)
	var hit_count := DamageCalculator.calculate_attack_count(attacker, defender)
	var defender_projected := maxi(0, defender_hp - damage_per_hit * hit_count)

	_bottom_health_pips.health_fill = float(defender_projected) / float(defender_max_hp)
	_bottom_health_pips.damage_fill = float(defender_hp - defender_projected) / float(defender_max_hp)

	# Position arrows at the projected health boundary
	var attacker_health_ratio := _top_health_pips.health_fill
	_position_arrow(_attacker_arrow, _top_health_pips, attacker_health_ratio, false)

	var defender_health_ratio := _bottom_health_pips.health_fill
	_position_arrow(_defender_arrow, _bottom_health_pips, defender_health_ratio, true)


# =============================================================================
# ARROW POSITIONING — slide arrows to the projected health boundary
# =============================================================================
# The arrow centers on the line between the filled zone and the damage zone.
# Normal bar (attacker): fills bottom-to-top, boundary at UV.y = 1.0 - health_fill
# Inverted bar (defender): fills top-to-bottom, boundary at UV.y = health_fill

func _position_arrow(arrow: TextureRect, pip_bar: HealthPipBar, health_ratio: float, inverted: bool) -> void:
	var bar_height := pip_bar.size.y
	var arrow_height := arrow.size.y

	# Boundary position in pixels from the top of the bar
	var boundary_y: float
	if inverted:
		boundary_y = health_ratio * bar_height
	else:
		boundary_y = (1.0 - health_ratio) * bar_height

	# Center the arrow on the boundary
	arrow.position.y = boundary_y - arrow_height * 0.5


# =============================================================================
# HELPERS
# =============================================================================

const _MAX_LABEL_LENGTH := 10


func _truncate(text: String) -> String:
	if text.length() > _MAX_LABEL_LENGTH:
		return text.left(_MAX_LABEL_LENGTH)
	return text


func _format_multiplier(effectiveness: float) -> String:
	if TypeChart.is_immune(effectiveness):
		return "x0"
	if effectiveness == int(effectiveness):
		return "x%d" % int(effectiveness)
	return "x%.2f" % effectiveness


# Multiplier color pairs from Lawrence's spec (text color + glow color per stage tier).
# Stage +2 / +1 / 0 / -1 / -2 / immune. With TYPE_COEFFICIENT in play, type effectiveness
# only ever produces these stages — no intermediate "x3" tier is reachable via type matchups.
const _MULTIPLIER_COLORS := {
	"ouch2":  [Color(0.863, 0.388, 0.310), Color(0.322, 0.035, 0.016)],   # Red
	"ouch":   [Color(0.961, 0.804, 0.396), Color(0.376, 0.227, 0.059)],   # YellowOrange
	"neut":   [Color(0.824, 0.808, 0.416), Color(0.494, 0.427, 0.141)],   # Yellow
	"rsst":   [Color(0.573, 0.788, 0.549), Color(0.176, 0.310, 0.180)],   # Green
	"rsst2":  [Color(0.271, 0.796, 0.808), Color(0.000, 0.302, 0.337)],   # Cyan
	"immune": [Color(0.271, 0.796, 0.808), Color(0.000, 0.302, 0.337)],   # Cyan
}


func _set_hits_label(label: Label, hit_count: int) -> void:
	if hit_count <= 1:
		label.get_parent().visible = false
	else:
		label.get_parent().visible = true
		label.text = "x%d" % hit_count


func _set_multiplier_label(label: Label, effectiveness: float) -> void:
	if effectiveness == 1.0 or effectiveness == 0.0:
		label.get_parent().visible = false
	else:
		label.get_parent().visible = true
		label.text = _format_multiplier(effectiveness)
		_color_multiplier_label(label, effectiveness)


func _color_multiplier_label(label: Label, effectiveness: float) -> void:
	var colors: Array
	if TypeChart.is_immune(effectiveness):
		colors = _MULTIPLIER_COLORS["immune"]
	else:
		var stage := TypeChart.multiplier_to_stage(effectiveness)
		match stage:
			2:
				colors = _MULTIPLIER_COLORS["ouch2"]
			1:
				colors = _MULTIPLIER_COLORS["ouch"]
			-1:
				colors = _MULTIPLIER_COLORS["rsst"]
			-2:
				colors = _MULTIPLIER_COLORS["rsst2"]
			_:
				colors = _MULTIPLIER_COLORS["neut"]

	label.add_theme_color_override("font_color", colors[0])
	# GlowLabel exposes glow_color for the shader — set it if available
	if label.has_method("_apply_glow_color"):
		label.set("glow_color", colors[1])


func _set_unit_type_icons(primary_icon: TextureRect, secondary_icon: TextureRect, data: CharacterData) -> void:
	if data:
		_set_elemental_icon(primary_icon, data.primary_type)
		_set_elemental_icon(secondary_icon, data.secondary_type)
	else:
		primary_icon.get_parent().visible = false
		secondary_icon.get_parent().visible = false


func _set_damage_type_icon(icon: TextureRect, damage_type: Enums.DamageType) -> void:
	var icon_path: String = Enums.get_damage_type_icon(damage_type)
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path) as Texture2D
		icon.get_parent().visible = true
	else:
		icon.get_parent().visible = false


func _set_elemental_icon(icon: TextureRect, element_type: Enums.ElementalType) -> void:
	if element_type == Enums.ElementalType.NONE:
		icon.get_parent().visible = false
	else:
		var type_name: String = Enums.elemental_type_to_string(element_type).to_lower()
		var path: String = "res://art/sprites/ui/elemental_type_icons_10x10/%s.png" % type_name
		if ResourceLoader.exists(path):
			icon.texture = load(path) as Texture2D
			icon.get_parent().visible = true
		else:
			icon.get_parent().visible = false


# =============================================================================
# HEAL PREVIEW
# =============================================================================
# Shares the panel layout with the damage path. The pip-bar `damage_*` slots are
# repurposed as the "gain" band — green/teal pulse above current HP rather than
# red pulse above projected HP. _reset_pip_colors restores the damage path on
# next damage preview so heal/damage previews can interleave without leakage.

const _HEAL_BAND_COLOR: Color = Color(0.314, 0.690, 0.404, 1.0)   # Green 6
const _HEAL_BAND_GLOW: Color  = Color(0.118, 0.341, 0.165, 1.0)   # Green 8 (darker)
const _HEAL_NUMBER_FONT: Color = Color(0.573, 0.788, 0.549, 1.0)  # matches "rsst" multiplier text
const _HEAL_NUMBER_GLOW: Color = Color(0.176, 0.310, 0.180, 1.0)  # matches "rsst" glow

# Original ColorRect-style damage pulse defaults from health_pip_bar.gd.
const _DAMAGE_BAND_COLOR_DEFAULT: Color = Color(0.5, 0.5, 0.5, 1.0)
const _DAMAGE_BAND_GLOW_DEFAULT: Color  = Color(0.3, 0.3, 0.3, 1.0)


func _apply_pip_heal_colors() -> void:
	for pip: HealthPipBar in [_top_health_pips, _bottom_health_pips]:
		pip.damage_color = _HEAL_BAND_COLOR
		pip.damage_glow = _HEAL_BAND_GLOW


func _reset_pip_colors() -> void:
	for pip: HealthPipBar in [_top_health_pips, _bottom_health_pips]:
		pip.damage_color = _DAMAGE_BAND_COLOR_DEFAULT
		pip.damage_glow = _DAMAGE_BAND_GLOW_DEFAULT


func _update_caster_section_for_heal(caster: Node, move: Move, heal_amount: int) -> void:
	var caster_name: String = caster.get("unit_name") if caster.get("unit_name") else "???"
	_attacker_name_label.text = _truncate(caster_name)

	var caster_data: CharacterData = caster.get("character_data")
	_set_unit_type_icons(_attacker_primary_type_icon, _attacker_secondary_type_icon, caster_data)
	_set_elemental_icon(_attacker_move_type_icon, move.element_type)
	_set_damage_type_icon(_attacker_move_damage_type_icon, move.damage_type)

	_attacker_move_label.text = _truncate(move.abbrev_name)

	_attacker_damage_label.text = "+%d" % heal_amount
	_attacker_damage_label.add_theme_color_override("font_color", _HEAL_NUMBER_FONT)
	if _attacker_damage_label.has_method("_apply_glow_color"):
		_attacker_damage_label.set("glow_color", _HEAL_NUMBER_GLOW)

	# Heals are single-application, no type effectiveness. Status proc only shows
	# if the move actually carries one (rare on heals).
	_set_hits_label(_attacker_hits_label, 0)
	if move.status_effect_chance > 0.0 and move.status_effect_type != Enums.StatusEffectType.NONE:
		_attacker_secondary_label.get_parent().visible = true
		_attacker_secondary_label.text = "%d%%" % int(move.status_effect_chance * 100)
	else:
		_attacker_secondary_label.get_parent().visible = false
	_set_multiplier_label(_attacker_multiplier_label, 0.0)


func _update_target_section_for_heal(target: Node) -> void:
	var target_name: String = target.get("unit_name") if target.get("unit_name") else "???"
	_defender_name_label.text = _truncate(target_name)

	var target_data: CharacterData = target.get("character_data")
	_set_unit_type_icons(_defender_primary_type_icon, _defender_secondary_type_icon, target_data)

	# No counter, no incoming move from the target — collapse the move row + stats.
	_defender_move_label.text = "--"
	_defender_move_type_icon.get_parent().visible = false
	_defender_move_damage_type_icon.get_parent().visible = false
	_set_hits_label(_defender_hits_label, 0)
	_defender_damage_label.text = "--"
	_defender_hit_label.text = "--"
	_defender_secondary_label.get_parent().visible = false
	_set_multiplier_label(_defender_multiplier_label, 0.0)


func _update_heal_pips(caster: Node, target: Node, heal_amount: int) -> void:
	# Caster's bar: just show their current HP, no band — they aren't taking or gaining damage.
	var caster_data: CharacterData = caster.get("character_data")
	var caster_hp: int = caster.get("current_hp")
	var caster_max: int = caster_data.max_hp if caster_data != null else 1
	_top_health_pips.health_fill = float(caster_hp) / float(caster_max)
	_top_health_pips.damage_fill = 0.0

	# Target's bar: solid current HP at the bottom, pulsing gain band stacked on top.
	var target_data: CharacterData = target.get("character_data")
	var target_hp: int = target.get("current_hp")
	var target_max: int = target_data.max_hp if target_data != null else 1

	_bottom_health_pips.health_fill = float(target_hp) / float(target_max)
	_bottom_health_pips.damage_fill = float(heal_amount) / float(target_max)

	_position_arrow(_attacker_arrow, _top_health_pips, _top_health_pips.health_fill, false)
	# Position the target arrow at the TOP of the gain band (the projected new HP).
	var target_projected_ratio := float(target_hp + heal_amount) / float(target_max)
	_position_arrow(_defender_arrow, _bottom_health_pips, target_projected_ratio, true)
