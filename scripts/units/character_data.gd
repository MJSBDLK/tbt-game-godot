## Complete character stat block, types, class, and equipped moves.
## Final stat = base + growth_gains + allocated + bond + passive + status_modifier
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
# Specialization: free-form ±10% stat picks at class levels 2/3 (replaces named enum)
# TODO: implement as Array of {stat_name: String, modifier: int} pairs
#@export var specialization: Enums.Specialization = Enums.Specialization.NONE
@export var level: int = 0
@export var experience: int = 0

# Portrait (high-res concept art crop)
@export var portrait_path: String = ""

# Sprite sheet reference (Aseprite JSON atlas)
@export var sprite_sheet_path: String = ""
@export var sprite_atlas_path: String = ""
@export var sprite_frame_index: int = 0


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

# Bond bonuses (from adjacent allies)
var bond_bonus_hp: int = 0
var bond_bonus_strength: int = 0
var bond_bonus_special: int = 0
var bond_bonus_skill: int = 0
var bond_bonus_agility: int = 0
var bond_bonus_athleticism: int = 0
var bond_bonus_defense: int = 0
var bond_bonus_resistance: int = 0

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
	get: return base_max_hp + growth_gains_hp + allocated_hp + bond_bonus_hp + passive_bonus_hp + status_modifier_hp

var strength: int:
	get: return base_strength + growth_gains_strength + allocated_strength + bond_bonus_strength + passive_bonus_strength + status_modifier_strength

var special: int:
	get: return base_special + growth_gains_special + allocated_special + bond_bonus_special + passive_bonus_special + status_modifier_special

var skill: int:
	get: return base_skill + growth_gains_skill + allocated_skill + bond_bonus_skill + passive_bonus_skill + status_modifier_skill

var agility: int:
	get: return base_agility + growth_gains_agility + allocated_agility + bond_bonus_agility + passive_bonus_agility + status_modifier_agility

var athleticism: int:
	get: return base_athleticism + growth_gains_athleticism + allocated_athleticism + bond_bonus_athleticism + passive_bonus_athleticism + status_modifier_athleticism

var defense: int:
	get: return base_defense + growth_gains_defense + allocated_defense + bond_bonus_defense + passive_bonus_defense + status_modifier_defense

var resistance: int:
	get: return base_resistance + growth_gains_resistance + allocated_resistance + bond_bonus_resistance + passive_bonus_resistance + status_modifier_resistance


# =============================================================================
# EQUIPMENT
# =============================================================================

var equipped_moves: Array[Move] = []      # Max 4
var equipped_passives: Array = []          # Max 4, PassiveData placeholder (Phase 7)
var base_pool_moves: Array[String] = []    # All learnable move names
var base_pool_passives: Array[String] = [] # All learnable passive names


# =============================================================================
# STAT CAPS (default values — will be class-based via CLASS_INFO later)
# =============================================================================

const DEFAULT_STAT_CAPS: Dictionary = {
	"max_hp": 60,
	"strength": 25,
	"special": 25,
	"skill": 30,
	"agility": 30,
	"athleticism": 30,
	"defense": 25,
	"resistance": 25,
}


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


## Returns the unmodified stat (everything in pass 1: base + growth + allocated + bond + passive
## + future injuries). Excludes status_modifier so % buff/debuff calculations have a stable base
## that doesn't compound with other status effects.
func get_unmodified_stat(stat_name: String) -> int:
	return get_stat(stat_name) - _get_status_modifier(stat_name)


func _get_status_modifier(stat_name: String) -> int:
	match stat_name:
		"max_hp": return status_modifier_hp
		"strength": return status_modifier_strength
		"special": return status_modifier_special
		"skill": return status_modifier_skill
		"agility": return status_modifier_agility
		"athleticism": return status_modifier_athleticism
		"defense": return status_modifier_defense
		"resistance": return status_modifier_resistance
	return 0


func get_stat_cap(stat_name: String) -> int:
	return DEFAULT_STAT_CAPS.get(stat_name, 20)


func get_base_plus_growth(stat_name: String) -> int:
	match stat_name:
		"max_hp": return base_max_hp + growth_gains_hp
		"strength": return base_strength + growth_gains_strength
		"special": return base_special + growth_gains_special
		"skill": return base_skill + growth_gains_skill
		"agility": return base_agility + growth_gains_agility
		"athleticism": return base_athleticism + growth_gains_athleticism
		"defense": return base_defense + growth_gains_defense
		"resistance": return base_resistance + growth_gains_resistance
	return 0


func get_bonus_total(stat_name: String) -> int:
	## Returns the sum of allocated + bond + passive + status modifiers (excludes base and growth).
	var allocated: int = 0
	var bond: int = 0
	var passive: int = 0
	var status: int = 0
	match stat_name:
		"max_hp":
			allocated = allocated_hp; bond = bond_bonus_hp
			passive = passive_bonus_hp; status = status_modifier_hp
		"strength":
			allocated = allocated_strength; bond = bond_bonus_strength
			passive = passive_bonus_strength; status = status_modifier_strength
		"special":
			allocated = allocated_special; bond = bond_bonus_special
			passive = passive_bonus_special; status = status_modifier_special
		"skill":
			allocated = allocated_skill; bond = bond_bonus_skill
			passive = passive_bonus_skill; status = status_modifier_skill
		"agility":
			allocated = allocated_agility; bond = bond_bonus_agility
			passive = passive_bonus_agility; status = status_modifier_agility
		"athleticism":
			allocated = allocated_athleticism; bond = bond_bonus_athleticism
			passive = passive_bonus_athleticism; status = status_modifier_athleticism
		"defense":
			allocated = allocated_defense; bond = bond_bonus_defense
			passive = passive_bonus_defense; status = status_modifier_defense
		"resistance":
			allocated = allocated_resistance; bond = bond_bonus_resistance
			passive = passive_bonus_resistance; status = status_modifier_resistance
	return allocated + bond + passive + status


func is_at_stat_cap(stat_name: String) -> bool:
	return get_base_plus_growth(stat_name) >= get_stat_cap(stat_name)


func reset_status_modifiers() -> void:
	status_modifier_hp = 0
	status_modifier_strength = 0
	status_modifier_special = 0
	status_modifier_skill = 0
	status_modifier_agility = 0
	status_modifier_athleticism = 0
	status_modifier_defense = 0
	status_modifier_resistance = 0


func reset_bond_bonuses() -> void:
	bond_bonus_hp = 0
	bond_bonus_strength = 0
	bond_bonus_special = 0
	bond_bonus_skill = 0
	bond_bonus_agility = 0
	bond_bonus_athleticism = 0
	bond_bonus_defense = 0
	bond_bonus_resistance = 0
