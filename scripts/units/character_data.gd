## Complete character stat block, types, class, and equipped moves.
## Final stat = base + growth_gains + allocated + bond + passive + status_modifier
## Ported from Unity's CharacterData.cs (510 lines).
class_name CharacterData
extends Resource


# =============================================================================
# IDENTITY
# =============================================================================

# Stable identifier used by SquadManager to look up persistent character state
# across missions. Must be unique within the roster. Should be lowercase with
# underscores (e.g. "spaceman", "ernesto"). The character JSON should declare
# this; if missing, the loader derives it from the JSON filename.
@export var character_id: String = ""

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

# Injury modifiers (semi-permanent, from being killed in past missions).
# Computed from current_injuries via InjurySystem.recalculate_injury_modifiers().
# Applied as the second pass of the stat calc: raw_passive + injury_modifier = unmodified.
var injury_modifier_hp: int = 0
var injury_modifier_strength: int = 0
var injury_modifier_special: int = 0
var injury_modifier_skill: int = 0
var injury_modifier_agility: int = 0
var injury_modifier_athleticism: int = 0
var injury_modifier_defense: int = 0
var injury_modifier_resistance: int = 0

# Status effect modifiers (temporary, from combat).
# Applied as the third pass of the stat calc: unmodified + status_modifier = effective.
var status_modifier_hp: int = 0
var status_modifier_strength: int = 0
var status_modifier_special: int = 0
var status_modifier_skill: int = 0
var status_modifier_agility: int = 0
var status_modifier_athleticism: int = 0
var status_modifier_defense: int = 0
var status_modifier_resistance: int = 0


# =============================================================================
# INJURIES (semi-permanent, from past missions)
# =============================================================================

# Active injuries on the unit. Total slots_occupied across all entries must
# never exceed MAX_INJURY_SLOTS — exceeding it triggers permadeath at queue time.
var current_injuries: Array[Injury] = []

# Queued injuries waiting to be committed at mission end (set by InjurySystem
# when the unit is killed mid-mission).
var pending_injuries: Array[Injury] = []

# Invisible LUCK stat. Sum of luck reductions from active injuries (Curse).
# Stored as a positive percentage value (e.g. 10.0 = -10% luck).
var luck_penalty_pct: float = 0.0

# Cached healing reduction percentage from active injuries (Laceration).
# Applied at heal time: actual_heal = max(1, base_heal * (1 - healing_reduction_pct/100))
var healing_reduction_pct: float = 0.0

const MAX_INJURY_SLOTS: int = 4


# =============================================================================
# COMPUTED FINAL STATS
# =============================================================================

var max_hp: int:
	get: return base_max_hp + growth_gains_hp + allocated_hp + bond_bonus_hp + passive_bonus_hp + injury_modifier_hp + status_modifier_hp

var strength: int:
	get: return base_strength + growth_gains_strength + allocated_strength + bond_bonus_strength + passive_bonus_strength + injury_modifier_strength + status_modifier_strength

var special: int:
	get: return base_special + growth_gains_special + allocated_special + bond_bonus_special + passive_bonus_special + injury_modifier_special + status_modifier_special

var skill: int:
	get: return base_skill + growth_gains_skill + allocated_skill + bond_bonus_skill + passive_bonus_skill + injury_modifier_skill + status_modifier_skill

var agility: int:
	get: return base_agility + growth_gains_agility + allocated_agility + bond_bonus_agility + passive_bonus_agility + injury_modifier_agility + status_modifier_agility

var athleticism: int:
	get: return base_athleticism + growth_gains_athleticism + allocated_athleticism + bond_bonus_athleticism + passive_bonus_athleticism + injury_modifier_athleticism + status_modifier_athleticism

var defense: int:
	get: return base_defense + growth_gains_defense + allocated_defense + bond_bonus_defense + passive_bonus_defense + injury_modifier_defense + status_modifier_defense

var resistance: int:
	get: return base_resistance + growth_gains_resistance + allocated_resistance + bond_bonus_resistance + passive_bonus_resistance + injury_modifier_resistance + status_modifier_resistance


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


## Returns the raw passive stat (pass 1): base + growth + allocated + bond + passive.
## This is the value that injury percentages are calculated against — injuries scale
## off the unit's "natural" capability and don't compound with each other or with
## other percentage modifiers.
func get_raw_passive_stat(stat_name: String) -> int:
	return get_stat(stat_name) - _get_injury_modifier(stat_name) - _get_status_modifier(stat_name)


## Returns the unmodified stat (pass 2): raw_passive + injury_modifier.
## This is the value that status (buff/debuff) percentages are calculated against,
## so a unit's buffs build off its already-injured state.
func get_unmodified_stat(stat_name: String) -> int:
	return get_stat(stat_name) - _get_status_modifier(stat_name)


func _get_injury_modifier(stat_name: String) -> int:
	match stat_name:
		"max_hp": return injury_modifier_hp
		"strength": return injury_modifier_strength
		"special": return injury_modifier_special
		"skill": return injury_modifier_skill
		"agility": return injury_modifier_agility
		"athleticism": return injury_modifier_athleticism
		"defense": return injury_modifier_defense
		"resistance": return injury_modifier_resistance
	return 0


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


func reset_injury_modifiers() -> void:
	injury_modifier_hp = 0
	injury_modifier_strength = 0
	injury_modifier_special = 0
	injury_modifier_skill = 0
	injury_modifier_agility = 0
	injury_modifier_athleticism = 0
	injury_modifier_defense = 0
	injury_modifier_resistance = 0
	luck_penalty_pct = 0.0
	healing_reduction_pct = 0.0


# =============================================================================
# INJURY HELPERS
# =============================================================================

## Total injury slots currently occupied by all active injuries.
func injury_slots_used() -> int:
	var total: int = 0
	for entry: Injury in current_injuries:
		total += entry.slots_occupied()
	return total


## How many slots remain free.
func injury_slots_free() -> int:
	return MAX_INJURY_SLOTS - injury_slots_used()


## Returns true if this unit can fit a new injury occupying `slots`.
## A return of false means accepting the injury would push slot total over the cap.
func can_accept_injury(slots: int) -> bool:
	return injury_slots_used() + slots <= MAX_INJURY_SLOTS


## Roll a chance check, modified by the unit's LUCK penalty (Curse).
## A unit with -10% luck has every chance reduced by 0.10 (so a 50% chance becomes 40%).
## Returns true on success.
func roll_succeeds(chance: float) -> bool:
	var modified: float = chance - (luck_penalty_pct / 100.0)
	return randf() < modified


## Returns the unit's move distance after Broken Bone injury penalties.
## Floored at 1 — a unit can always move at least 1 tile per turn.
func get_effective_move_distance() -> int:
	var penalty: int = 0
	for entry: Injury in current_injuries:
		var data: InjuryData = entry.get_data()
		if data == null:
			continue
		if data.mechanic == Enums.InjuryMechanic.MOVE_DISTANCE:
			penalty += int(entry.magnitude())
	return maxi(1, move_distance - penalty)


## Returns the summed friendly-fire proc chance from active Corruption injuries,
## as a percentage (0.0 if none). Sums multiple instances additively, capped at 100.
func friendly_fire_chance_pct() -> float:
	var total: float = 0.0
	for entry: Injury in current_injuries:
		var data: InjuryData = entry.get_data()
		if data == null:
			continue
		if data.mechanic == Enums.InjuryMechanic.FRIENDLY_FIRE:
			total += entry.magnitude()
	return clampf(total, 0.0, 100.0)


## Returns the count of elemental types removed by Crystallization injuries.
## Sums magnitude across all REMOVE_TYPE injuries (1 for minor, 2 for major).
func _types_removed_count() -> int:
	var total: int = 0
	for entry: Injury in current_injuries:
		var data: InjuryData = entry.get_data()
		if data == null:
			continue
		if data.mechanic == Enums.InjuryMechanic.REMOVE_TYPE:
			total += int(entry.magnitude())
	return total


## Returns the unit's effective primary type — NONE if Crystallization has
## removed it. Combat code should use this instead of primary_type directly.
func effective_primary_type() -> Enums.ElementalType:
	if _types_removed_count() >= 1:
		return Enums.ElementalType.NONE
	return primary_type


## Returns the unit's effective secondary type — NONE if Crystallization has
## removed both types (count >= 2). Combat code should use this instead of
## secondary_type directly.
func effective_secondary_type() -> Enums.ElementalType:
	if _types_removed_count() >= 2:
		return Enums.ElementalType.NONE
	return secondary_type


## Returns true if the unit's health bar should be hidden due to a Hypoesthesia
## injury at the unit's current HP fraction.
##   Minor: hidden when HP fraction > 0.5 (visible when wounded below 50%)
##   Major: hidden when HP fraction > 0.0 (always hidden unless dead)
## Multiple Hypoesthesia injuries take the lowest threshold.
func is_health_bar_hidden(current_hp: int) -> bool:
	if max_hp <= 0:
		return false
	var hp_fraction: float = float(current_hp) / float(max_hp)
	var lowest_threshold: float = INF
	for entry: Injury in current_injuries:
		var data: InjuryData = entry.get_data()
		if data == null:
			continue
		if data.mechanic == Enums.InjuryMechanic.HIDE_HEALTH:
			lowest_threshold = minf(lowest_threshold, entry.magnitude())
	if lowest_threshold == INF:
		return false
	return hp_fraction > lowest_threshold


func reset_bond_bonuses() -> void:
	bond_bonus_hp = 0
	bond_bonus_strength = 0
	bond_bonus_special = 0
	bond_bonus_skill = 0
	bond_bonus_agility = 0
	bond_bonus_athleticism = 0
	bond_bonus_defense = 0
	bond_bonus_resistance = 0
