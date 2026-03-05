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

# 4 unique-named containers (set "Access as Unique Name" on these in the editor)
@onready var _attacker_section: Control = %AttackerContainer
@onready var _defender_section: Control = %DefenderContainer
@onready var _top_health_pips: HealthPipBar = %AttackerHealthPips
@onready var _bottom_health_pips: HealthPipBar = %DefenderHealthPips

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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No manual node lookup needed — @onready + % handles it automatically.
	# When this node enters the scene tree, Godot resolves all the %Names above.
	visible = false


# =============================================================================
# PUBLIC API — called by UIManager, which is called by InputManager
# =============================================================================

func show_preview(attacker: Node, defender: Node, move: Move) -> void:
	if attacker == null or defender == null or move == null:
		hide_panel()
		return

	visible = true
	_update_attacker_section(attacker, defender, move)
	_update_defender_section(attacker, defender, move)
	_update_health_pips(attacker, defender, move)


func hide_panel() -> void:
	visible = false


# =============================================================================
# ATTACKER SECTION — populate the top half with attack stats
# =============================================================================

func _update_attacker_section(attacker: Node, defender: Node, move: Move) -> void:
	var attacker_name: String = attacker.get("unit_name") if attacker.get("unit_name") else "???"
	_attacker_name_label.text = _truncate(attacker_name)

	_attacker_move_label.text = _truncate(move.abbrev_name)

	# Damage per hit and hit count (from athleticism comparison)
	var damage_per_hit := DamageCalculator.calculate_damage(attacker, defender, move)
	var hit_count := DamageCalculator.calculate_attack_count(attacker, defender)
	_attacker_damage_label.text = str(damage_per_hit)
	_attacker_hits_label.text = "x%d" % hit_count

	# Secondary chance — status effect proc chance from the move
	if move.status_effect_chance > 0.0 and move.status_effect_type != Enums.StatusEffectType.NONE:
		_attacker_secondary_label.text = "%d%%" % int(move.status_effect_chance * 100)
	else:
		_attacker_secondary_label.text = "--"

	# Type effectiveness multiplier
	var effectiveness := DamageCalculator.get_type_effectiveness(attacker, defender, move)
	_attacker_multiplier_label.text = _format_multiplier(effectiveness)
	_color_multiplier_label(_attacker_multiplier_label, effectiveness)

	DebugConfig.log_combat_preview("Preview: %s uses %s → %d dmg x%d (%.1fx)" % [
		attacker_name, move.move_name, damage_per_hit, hit_count, effectiveness])


# =============================================================================
# DEFENDER SECTION — populate the bottom half with counter-attack stats
# =============================================================================

func _update_defender_section(attacker: Node, defender: Node, move: Move) -> void:
	var defender_name: String = defender.get("unit_name") if defender.get("unit_name") else "???"
	_defender_name_label.text = _truncate(defender_name)

	var can_counter := DamageCalculator.can_counter_attack(defender, attacker)
	if can_counter:
		var counter_move: Move = defender.get("assigned_move")
		_defender_move_label.text = _truncate(counter_move.abbrev_name)

		var counter_damage := DamageCalculator.calculate_damage(defender, attacker, counter_move)
		var counter_hits := DamageCalculator.calculate_attack_count(defender, attacker)
		_defender_damage_label.text = str(counter_damage)
		_defender_hits_label.text = "x%d" % counter_hits

		if counter_move.status_effect_chance > 0.0 and counter_move.status_effect_type != Enums.StatusEffectType.NONE:
			_defender_secondary_label.text = "%d%%" % int(counter_move.status_effect_chance * 100)
		else:
			_defender_secondary_label.text = "--"

		var counter_effectiveness := DamageCalculator.get_type_effectiveness(
			defender, attacker, counter_move)
		_defender_multiplier_label.text = _format_multiplier(counter_effectiveness)
		_color_multiplier_label(_defender_multiplier_label, counter_effectiveness)
	else:
		_defender_move_label.text = "No Counter"
		_defender_hits_label.text = ""
		_defender_damage_label.text = "0"
		_defender_hit_label.text = "--"
		_defender_secondary_label.text = "--"
		_defender_multiplier_label.text = "--"


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


# =============================================================================
# HELPERS
# =============================================================================

const _MAX_LABEL_LENGTH := 10


func _truncate(text: String) -> String:
	if text.length() > _MAX_LABEL_LENGTH:
		return text.left(_MAX_LABEL_LENGTH)
	return text


func _format_multiplier(effectiveness: float) -> String:
	if effectiveness == int(effectiveness):
		return "x%d" % int(effectiveness)
	return "x%.1f" % effectiveness


# Multiplier color pairs from Lawrence's spec (text color + glow color per ramp)
const _MULTIPLIER_COLORS := {
	"x4":   [Color(0.863, 0.388, 0.310), Color(0.322, 0.035, 0.016)],   # Red
	"x3":   [Color(0.788, 0.553, 0.278), Color(0.345, 0.149, 0.051)],   # Orange
	"x2":   [Color(0.961, 0.804, 0.396), Color(0.376, 0.227, 0.059)],   # YellowOrange
	"x1":   [Color(0.824, 0.808, 0.416), Color(0.494, 0.427, 0.141)],   # Yellow
	"half": [Color(0.573, 0.788, 0.549), Color(0.176, 0.310, 0.180)],   # Green
	"qtr":  [Color(0.271, 0.796, 0.808), Color(0.000, 0.302, 0.337)],   # Cyan
}


func _color_multiplier_label(label: Label, effectiveness: float) -> void:
	var colors: Array
	if effectiveness >= 4.0:
		colors = _MULTIPLIER_COLORS["x4"]
	elif effectiveness >= 3.0:
		colors = _MULTIPLIER_COLORS["x3"]
	elif effectiveness >= 2.0:
		colors = _MULTIPLIER_COLORS["x2"]
	elif effectiveness == 1.0:
		colors = _MULTIPLIER_COLORS["x1"]
	elif effectiveness >= 0.5:
		colors = _MULTIPLIER_COLORS["half"]
	elif effectiveness > 0.0:
		colors = _MULTIPLIER_COLORS["qtr"]
	else:
		colors = _MULTIPLIER_COLORS["qtr"]

	label.add_theme_color_override("font_color", colors[0])
	# GlowLabel exposes glow_color for the shader — set it if available
	if label.has_method("_apply_glow_color"):
		label.set("glow_color", colors[1])
