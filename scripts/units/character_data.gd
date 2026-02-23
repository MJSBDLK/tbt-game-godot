## Complete character stat block, types, class, and equipped moves.
## Final stat = base + growth_gains + allocated + support + passive + status_modifier
## Ported from Unity's CharacterData.cs (510 lines).
class_name CharacterData
extends Resource


# =============================================================================
# IDENTITY
# =============================================================================

@export var character_name: String = ""
@export var primary_type: Enums.ElementalType = Enums.ElementalType.NONE
@export var secondary_type: Enums.ElementalType = Enums.ElementalType.NONE
@export var current_class: Enums.CharacterClass = Enums.CharacterClass.SPACEMAN
@export var specialization: Enums.Specialization = Enums.Specialization.NONE
@export var level: int = 1
@export var experience: int = 0


# =============================================================================
# BASE STATS (from JSON, never modified at runtime)
# =============================================================================

@export_group("Base Stats")
@export var base_max_hp: int = 20
@export var base_strength: int = 5
@export var base_special: int = 5
@export var base_skill: int = 5
@export var base_agility: int = 5
@export var base_athleticism: int = 5
@export var base_defense: int = 5
@export var base_resistance: int = 5


# =============================================================================
# GROWTH RATES (0-100%, chance to gain +1 on level up)
# =============================================================================

@export_group("Growth Rates")
@export var growth_rate_hp: int = 50
@export var growth_rate_strength: int = 50
@export var growth_rate_special: int = 50
@export var growth_rate_skill: int = 50
@export var growth_rate_agility: int = 50
@export var growth_rate_athleticism: int = 50
@export var growth_rate_defense: int = 50
@export var growth_rate_resistance: int = 50


# =============================================================================
# PHYSICAL ATTRIBUTES
# =============================================================================

@export_group("Physical")
@export var move_distance: int = 3
@export var constitution: int = 5
@export var carry: int = 8


# =============================================================================
# RUNTIME STAT MODIFIERS (not exported — set during gameplay)
# =============================================================================

# Growth gains (accumulated from level ups)
var growth_gains_hp: int = 0
var growth_gains_strength: int = 0
var growth_gains_special: int = 0
var growth_gains_skill: int = 0
var growth_gains_agility: int = 0
var growth_gains_athleticism: int = 0
var growth_gains_defense: int = 0
var growth_gains_resistance: int = 0

# Allocated stat ups (player-distributed between missions)
var allocated_hp: int = 0
var allocated_strength: int = 0
var allocated_special: int = 0
var allocated_skill: int = 0
var allocated_agility: int = 0
var allocated_athleticism: int = 0
var allocated_defense: int = 0
var allocated_resistance: int = 0
var available_stat_ups: int = 0

# Support bonuses (from adjacent allies)
var support_bonus_hp: int = 0
var support_bonus_strength: int = 0
var support_bonus_special: int = 0
var support_bonus_skill: int = 0
var support_bonus_agility: int = 0
var support_bonus_athleticism: int = 0
var support_bonus_defense: int = 0
var support_bonus_resistance: int = 0

# Passive bonuses (from equipped passives)
var passive_bonus_hp: int = 0
var passive_bonus_strength: int = 0
var passive_bonus_special: int = 0
var passive_bonus_skill: int = 0
var passive_bonus_agility: int = 0
var passive_bonus_athleticism: int = 0
var passive_bonus_defense: int = 0
var passive_bonus_resistance: int = 0

# Status effect modifiers (temporary, from combat)
var status_modifier_hp: int = 0
var status_modifier_strength: int = 0
var status_modifier_special: int = 0
var status_modifier_skill: int = 0
var status_modifier_agility: int = 0
var status_modifier_athleticism: int = 0
var status_modifier_defense: int = 0
var status_modifier_resistance: int = 0


# =============================================================================
# COMPUTED FINAL STATS
# =============================================================================

var max_hp: int:
	get: return base_max_hp + growth_gains_hp + allocated_hp + support_bonus_hp + passive_bonus_hp + status_modifier_hp

var strength: int:
	get: return base_strength + growth_gains_strength + allocated_strength + support_bonus_strength + passive_bonus_strength + status_modifier_strength

var special: int:
	get: return base_special + growth_gains_special + allocated_special + support_bonus_special + passive_bonus_special + status_modifier_special

var skill: int:
	get: return base_skill + growth_gains_skill + allocated_skill + support_bonus_skill + passive_bonus_skill + status_modifier_skill

var agility: int:
	get: return base_agility + growth_gains_agility + allocated_agility + support_bonus_agility + passive_bonus_agility + status_modifier_agility

var athleticism: int:
	get: return base_athleticism + growth_gains_athleticism + allocated_athleticism + support_bonus_athleticism + passive_bonus_athleticism + status_modifier_athleticism

var defense: int:
	get: return base_defense + growth_gains_defense + allocated_defense + support_bonus_defense + passive_bonus_defense + status_modifier_defense

var resistance: int:
	get: return base_resistance + growth_gains_resistance + allocated_resistance + support_bonus_resistance + passive_bonus_resistance + status_modifier_resistance


# =============================================================================
# EQUIPMENT
# =============================================================================

var equipped_moves: Array[Move] = []      # Max 4
var equipped_passives: Array = []          # Max 4, PassiveData placeholder (Phase 7)
var base_pool_moves: Array[String] = []    # All learnable move names
var base_pool_passives: Array[String] = [] # All learnable passive names


# =============================================================================
# HELPERS
# =============================================================================

func get_stat(stat_name: String) -> int:
	match stat_name:
		"max_hp": return max_hp
		"strength": return strength
		"special": return special
		"skill": return skill
		"agility": return agility
		"athleticism": return athleticism
		"defense": return defense
		"resistance": return resistance
	return 0


func reset_status_modifiers() -> void:
	status_modifier_hp = 0
	status_modifier_strength = 0
	status_modifier_special = 0
	status_modifier_skill = 0
	status_modifier_agility = 0
	status_modifier_athleticism = 0
	status_modifier_defense = 0
	status_modifier_resistance = 0


func reset_support_bonuses() -> void:
	support_bonus_hp = 0
	support_bonus_strength = 0
	support_bonus_special = 0
	support_bonus_skill = 0
	support_bonus_agility = 0
	support_bonus_athleticism = 0
	support_bonus_defense = 0
	support_bonus_resistance = 0
