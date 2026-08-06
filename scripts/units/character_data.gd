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

# Class tier — 1 = base class, 2 = first promotion, 3 = second promotion.
# Intended to be DERIVED from level once promotion exists (1-20 / 21-40 /
# 41-60), not tracked independently. Deliberately absent from the XP formula:
# tier must never affect XP rate, or class choice becomes a leveling decision
# instead of a build decision. See CombatXpCalculator's header for the version
# of this that got deleted and why. Promotion mechanics aren't implemented yet;
# all roster JSONs leave this at 1 until they are.
@export var tier: int = 1

# Portrait (high-res concept art crop)
@export var portrait_path: String = ""

# Optional HD line-art portrait. When set, UI panels swap their pixel portrait
# for an HDPortraitSlot pointed at this asset — rendered at native window
# resolution via the HDLayer overlay. Leave empty to keep the pixel portrait.
@export var lineart_path: String = ""

# Named sub-regions of the line-art. Keys are framing names ("portrait",
# "thumbnail", "fullbody"); values are paths to AtlasTexture .tres resources
# that crop the lineart down to that region. UI consumers ask for a specific
# region name; if missing, falls back to lineart_path (whole image).
@export var lineart_atlases: Dictionary = {}

# Sprite sheet reference (Aseprite JSON atlas)
@export var sprite_sheet_path: String = ""
@export var sprite_atlas_path: String = ""
@export var sprite_frame_index: int = 0

# Optional blob-shadow override, JSON `sprite.shadowBlobRadius` (pixels,
# pre-distortion). Negative = unset → UnitShadow measures the idle stance
# (feet-band percentile width). 0 = this character casts NO blob (ghosts,
# floaters). Positive = artist-authored radius, used verbatim. The escape
# hatch for stances the measurement misjudges — RQD 2026-08-01.
@export var shadow_blob_radius: float = -1.0

# Optional attack-animation clips keyed by clip name. Each entry is a Dictionary:
#   { "path": String, "frames": int, "fps": int, "hit_frame": int,
#     "use_when": { "direction": "horizontal"|"vertical"|"any", "range": int|null } }
# Strips are laid out as N frames of (idle_width × idle_height) concatenated
# left-to-right. unit.gd picks a clip per attack via _pick_attack_clip; misses
# fall back to the boop nudge.
@export var attack_animations: Dictionary = {}


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

# Player-distributed stat-up points (0..StatAllocation.PER_STAT_CAP per stat).
# These are point counts, NOT raw stat deltas — the actual stat bonus is
# computed by StatAllocation.compute_delta() so flat vs percentage modes can
# be flipped without touching player allocation state.
var allocated_hp: int = 0
var allocated_strength: int = 0
var allocated_special: int = 0
var allocated_skill: int = 0
var allocated_agility: int = 0
var allocated_athleticism: int = 0
var allocated_defense: int = 0
var allocated_resistance: int = 0
# Total earned points the player can still distribute (level-up rewards).
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
# Dedicated avoid channel (NOT a base stat — no getter). A flat dodge modifier
# subtracted from incoming hit chance in DamageCalculator.hit_chance_pct. Written
# by stat-aura passives (Glib) and zeroed each recompute alongside the bonuses
# above. Kept separate from agility so avoid doesn't bleed into turn speed / doubles.
var passive_bonus_avoid: int = 0
# True while a nearby Stellar ally is granting the Maximum effect. Set by the
# Stellar aura each recompute (and zeroed alongside passive bonuses). Combined
# with the Maximum passive in has_maximum_protection().
var maximum_from_aura: bool = false

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
	get:
		var lv: int = base_max_hp + growth_gains_hp
		return lv + StatAllocation.compute_delta("max_hp", lv, allocated_hp) + bond_bonus_hp + passive_bonus_hp + injury_modifier_hp + status_modifier_hp

var strength: int:
	get:
		var lv: int = base_strength + growth_gains_strength
		return lv + StatAllocation.compute_delta("strength", lv, allocated_strength) + bond_bonus_strength + passive_bonus_strength + injury_modifier_strength + status_modifier_strength

var special: int:
	get:
		var lv: int = base_special + growth_gains_special
		return lv + StatAllocation.compute_delta("special", lv, allocated_special) + bond_bonus_special + passive_bonus_special + injury_modifier_special + status_modifier_special

var skill: int:
	get:
		var lv: int = base_skill + growth_gains_skill
		return lv + StatAllocation.compute_delta("skill", lv, allocated_skill) + bond_bonus_skill + passive_bonus_skill + injury_modifier_skill + status_modifier_skill

var agility: int:
	get:
		var lv: int = base_agility + growth_gains_agility
		return lv + StatAllocation.compute_delta("agility", lv, allocated_agility) + bond_bonus_agility + passive_bonus_agility + injury_modifier_agility + status_modifier_agility

var athleticism: int:
	get:
		var lv: int = base_athleticism + growth_gains_athleticism
		return lv + StatAllocation.compute_delta("athleticism", lv, allocated_athleticism) + bond_bonus_athleticism + passive_bonus_athleticism + injury_modifier_athleticism + status_modifier_athleticism

var defense: int:
	get:
		var lv: int = base_defense + growth_gains_defense
		return lv + StatAllocation.compute_delta("defense", lv, allocated_defense) + bond_bonus_defense + passive_bonus_defense + injury_modifier_defense + status_modifier_defense

var resistance: int:
	get:
		var lv: int = base_resistance + growth_gains_resistance
		return lv + StatAllocation.compute_delta("resistance", lv, allocated_resistance) + bond_bonus_resistance + passive_bonus_resistance + injury_modifier_resistance + status_modifier_resistance


# =============================================================================
# EQUIPMENT
# =============================================================================

var equipped_moves: Array[Move] = []      # Max 4
var equipped_passives: Array = []          # Max 4, PassiveData placeholder (Phase 7)
var base_pool_moves: Array[String] = []    # All learnable move names
var base_pool_passives: Array[String] = [] # All learnable passive names


## Case-insensitive check for an equipped passive by display name. Passives are
## currently stored as strings (PassiveData resource placeholder); this helper
## abstracts the lookup so pathfinding / combat can test for specific effects
## without caring about representation.
func has_equipped_passive(passive_name: String) -> bool:
	var target: String = passive_name.to_lower()
	for passive: Variant in equipped_passives:
		var name_str: String = ""
		if passive is String:
			name_str = passive as String
		elif passive != null and passive.get("name") != null:
			name_str = str(passive.get("name"))
		if name_str.to_lower() == target:
			return true
	return false


## True if this unit's stats are protected from being lowered by status debuffs —
## either from the Maximum passive or a nearby Stellar ally's aura. Read by
## StatusEffectSystem._recalculate_stat_modifiers to floor negative modifiers at 0.
func has_maximum_protection() -> bool:
	return has_equipped_passive("Maximum") or maximum_from_aura


# =============================================================================
# STAT CAPS (default values — will be class-based via CLASS_INFO later)
# =============================================================================

## 2:1 HP-to-other-stat ratio: HP /20
## and every other stat /10
## both top out at 5px
## these are the practical cap a maxed-late-game unit might pull off.
const DEFAULT_STAT_CAPS: Dictionary = {
	"max_hp": 100,
	"strength": 50,
	"special": 50,
	"skill": 50,
	"agility": 50,
	"athleticism": 50,
	"defense": 50,
	"resistance": 50,
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
	## `allocated` is a stat delta computed via StatAllocation, not raw points.
	var bond: int = 0
	var passive: int = 0
	var status: int = 0
	match stat_name:
		"max_hp":
			bond = bond_bonus_hp; passive = passive_bonus_hp; status = status_modifier_hp
		"strength":
			bond = bond_bonus_strength; passive = passive_bonus_strength; status = status_modifier_strength
		"special":
			bond = bond_bonus_special; passive = passive_bonus_special; status = status_modifier_special
		"skill":
			bond = bond_bonus_skill; passive = passive_bonus_skill; status = status_modifier_skill
		"agility":
			bond = bond_bonus_agility; passive = passive_bonus_agility; status = status_modifier_agility
		"athleticism":
			bond = bond_bonus_athleticism; passive = passive_bonus_athleticism; status = status_modifier_athleticism
		"defense":
			bond = bond_bonus_defense; passive = passive_bonus_defense; status = status_modifier_defense
		"resistance":
			bond = bond_bonus_resistance; passive = passive_bonus_resistance; status = status_modifier_resistance
	var level_value: int = get_base_plus_growth(stat_name)
	var allocated_delta: int = StatAllocation.compute_delta(stat_name, level_value, get_allocated_points(stat_name))
	return allocated_delta + bond + passive + status


func get_allocated_points(stat_name: String) -> int:
	match stat_name:
		"max_hp": return allocated_hp
		"strength": return allocated_strength
		"special": return allocated_special
		"skill": return allocated_skill
		"agility": return allocated_agility
		"athleticism": return allocated_athleticism
		"defense": return allocated_defense
		"resistance": return allocated_resistance
	return 0


func set_allocated_points(stat_name: String, value: int) -> void:
	match stat_name:
		"max_hp": allocated_hp = value
		"strength": allocated_strength = value
		"special": allocated_special = value
		"skill": allocated_skill = value
		"agility": allocated_agility = value
		"athleticism": allocated_athleticism = value
		"defense": allocated_defense = value
		"resistance": allocated_resistance = value


## Sum of points spent across all 8 stats. Pair with `available_stat_ups` to
## know how many remain (`available - allocated_total`).
func allocated_total() -> int:
	return (allocated_hp + allocated_strength + allocated_special + allocated_skill
		+ allocated_agility + allocated_athleticism + allocated_defense + allocated_resistance)


## Returns spent points to the pool. Used by the prep screen's reset button.
func reset_allocations() -> void:
	allocated_hp = 0
	allocated_strength = 0
	allocated_special = 0
	allocated_skill = 0
	allocated_agility = 0
	allocated_athleticism = 0
	allocated_defense = 0
	allocated_resistance = 0


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
	return GameRng.randf() < modified


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


# =============================================================================
# AUTO-LEVELING — ported from Unity CharacterData.ProcessLevelUp()
# =============================================================================

## Roll growth checks for one level. For each stat, if randf() * 100 falls
## below that stat's growth rate AND the stat isn't capped, increment the
## corresponding growth_gains_* counter. Increments level by 1.
##
## Class-progression rewards (Unity's ProcessLevelUpReward path) are NOT yet
## implemented — the class progression schedule resource doesn't exist in the
## Godot port. Stat-up allocation points and unlocked moves/passives will land
## with the squad/prep screen (alpha item #3).
func process_level_up() -> void:
	if GameRng.randf() * 100.0 < growth_rate_hp and not is_at_stat_cap("max_hp"):
		growth_gains_hp += 1
	if GameRng.randf() * 100.0 < growth_rate_strength and not is_at_stat_cap("strength"):
		growth_gains_strength += 1
	if GameRng.randf() * 100.0 < growth_rate_special and not is_at_stat_cap("special"):
		growth_gains_special += 1
	if GameRng.randf() * 100.0 < growth_rate_skill and not is_at_stat_cap("skill"):
		growth_gains_skill += 1
	if GameRng.randf() * 100.0 < growth_rate_agility and not is_at_stat_cap("agility"):
		growth_gains_agility += 1
	if GameRng.randf() * 100.0 < growth_rate_athleticism and not is_at_stat_cap("athleticism"):
		growth_gains_athleticism += 1
	if GameRng.randf() * 100.0 < growth_rate_defense and not is_at_stat_cap("defense"):
		growth_gains_defense += 1
	if GameRng.randf() * 100.0 < growth_rate_resistance and not is_at_stat_cap("resistance"):
		growth_gains_resistance += 1
	level += 1
	available_stat_ups += StatAllocation.points_awarded_at_level(level)


## Simulate level-ups from the character's current level up to `target_level`.
## No-ops if already at or above the target. Each level uses the unit's growth
## rates to decide whether each stat ticks up — same algorithm as the Unity
## level-up at the end of a real battle, just run repeatedly.
func simulate_levels_up_to(target_level: int) -> void:
	while level < target_level:
		process_level_up()


# Stat metadata for the bEXP level-up. Each row: [stat_name (for cap check),
# growth_rate_field, growth_gains_field]. Mirrors process_level_up's eight
# stats; pulled into a table so the bEXP roll can weight them dynamically.
const _BEXP_STAT_TABLE: Array = [
	["max_hp",       "growth_rate_hp",          "growth_gains_hp"],
	["strength",     "growth_rate_strength",    "growth_gains_strength"],
	["special",      "growth_rate_special",     "growth_gains_special"],
	["skill",        "growth_rate_skill",       "growth_gains_skill"],
	["agility",      "growth_rate_agility",     "growth_gains_agility"],
	["athleticism",  "growth_rate_athleticism", "growth_gains_athleticism"],
	["defense",      "growth_rate_defense",     "growth_gains_defense"],
	["resistance",   "growth_rate_resistance",  "growth_gains_resistance"],
]

## How many growths a single bEXP level-up grants. Matches Radiant Dawn.
const BEXP_GROWTHS_PER_LEVEL: int = 3


## Radiant Dawn–style bEXP level-up: exactly BEXP_GROWTHS_PER_LEVEL stat
## growths, weighted by the unit's growth rates, with capped stats excluded
## from the candidate pool. This is what makes bEXP "feel smart" with capped
## units — the fewer eligible stats there are, the higher the odds your bEXP
## hits one you wanted.
##
## If the unit has fewer uncapped stats than the target count (e.g. only 2
## stats left to grow), it just grants as many as it can. If the total
## growth rate across uncapped stats is zero (degenerate JSON), falls back
## to uniform random so we always grant something.
##
## Distinct from process_level_up() so combat XP and bEXP can evolve their
## formulas independently — see [.claude/](.claude/) design discussion.
func process_bexp_level_up() -> void:
	# Build candidate pool: [growth_rate_field, growth_gains_field] for each
	# uncapped stat. Capped stats drop out — bEXP can't grow them.
	var candidates: Array = []
	for entry: Array in _BEXP_STAT_TABLE:
		if not is_at_stat_cap(entry[0]):
			candidates.append(entry)

	var growths_to_apply: int = mini(BEXP_GROWTHS_PER_LEVEL, candidates.size())
	for _i: int in range(growths_to_apply):
		var total_weight: float = 0.0
		for c: Array in candidates:
			total_weight += float(get(c[1]))
		var picked_index: int
		if total_weight <= 0.0:
			picked_index = GameRng.randi() % candidates.size()
		else:
			var roll: float = GameRng.randf() * total_weight
			var cumulative: float = 0.0
			picked_index = candidates.size() - 1
			for j: int in range(candidates.size()):
				cumulative += float(get(candidates[j][1]))
				if roll <= cumulative:
					picked_index = j
					break
		var picked: Array = candidates[picked_index]
		set(picked[2], int(get(picked[2])) + 1)
		# Remove so we can't double-pick the same stat in one level.
		candidates.remove_at(picked_index)

	level += 1
	available_stat_ups += StatAllocation.points_awarded_at_level(level)


## Adds `amount` to `experience`, cascading process_level_up for every full
## 100-XP threshold crossed. Returns the number of level-ups that fired so
## callers can drive popups / SFX. The 100-XP threshold matches Radiant Dawn
## and lines up with CharacterSheetPanel._xp_for_next_level / the bEXP
## screen's per-level cost — keep them in sync if either side moves.
func grant_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	experience += amount
	var levels_gained: int = 0
	# 100 XP per level, flat. RD uses 100 too; the per-level threshold doesn't
	# scale with level in RD — what scales is how much XP each *action* awards.
	while experience >= 100:
		experience -= 100
		process_level_up()
		levels_gained += 1
	return levels_gained


# =============================================================================
# SAVE / LOAD
# =============================================================================

## Every persistent scalar the save system carries per character. Everything
## NOT here is either authored data (re-loaded from the character's JSON on
## load) or derived state that a recompute pass rebuilds: passive_bonus_* (aura
## pass), status_modifier_* (re-applying active status effects), and
## injury_modifier_* (InjurySystem.recalculate_injury_modifiers, which
## apply_save_dict runs after restoring the injury lists).
const _SAVE_SCALAR_FIELDS: Array[String] = [
	"level", "experience", "tier",
	"growth_gains_hp", "growth_gains_strength", "growth_gains_special",
	"growth_gains_skill", "growth_gains_agility", "growth_gains_athleticism",
	"growth_gains_defense", "growth_gains_resistance",
	"allocated_hp", "allocated_strength", "allocated_special",
	"allocated_skill", "allocated_agility", "allocated_athleticism",
	"allocated_defense", "allocated_resistance",
	"available_stat_ups",
	"bond_bonus_hp", "bond_bonus_strength", "bond_bonus_special",
	"bond_bonus_skill", "bond_bonus_agility", "bond_bonus_athleticism",
	"bond_bonus_defense", "bond_bonus_resistance",
]


## Serializes this character's persistent DELTAS from their authored JSON —
## references and numbers, never copies of static data. Moves ship as names
## (+ current PP): a rebalanced move bank flows into old saves automatically
## because load re-resolves through MoveData.get_move.
func to_save_dict() -> Dictionary:
	var fields: Dictionary = {}
	for field: String in _SAVE_SCALAR_FIELDS:
		fields[field] = get(field)
	var moves: Array = []
	for move: Move in equipped_moves:
		if move != null:
			moves.append({"name": move.move_name, "current_uses": move.current_uses})
	return {
		"character_id": character_id,
		"fields": fields,
		"current_injuries": _injuries_to_dicts(current_injuries),
		"pending_injuries": _injuries_to_dicts(pending_injuries),
		"equipped_moves": moves,
		"equipped_passives": equipped_passives.duplicate(),
	}


## Applies a to_save_dict() snapshot onto a freshly-JSON-loaded character.
## Call ONLY on a fresh load — deltas layer onto authored baselines, so
## applying twice would still be idempotent for scalars but would re-resolve
## moves and stomp any in-session mutations. Ends with an injury-modifier
## recompute so stat getters reflect restored injuries immediately.
func apply_save_dict(save: Dictionary) -> void:
	var fields: Dictionary = save.get("fields", {})
	for field: String in _SAVE_SCALAR_FIELDS:
		if fields.has(field):
			# JSON numbers arrive as floats — every scalar here is an int.
			set(field, int(fields[field]))

	current_injuries = _injuries_from_dicts(save.get("current_injuries", []))
	pending_injuries = _injuries_from_dicts(save.get("pending_injuries", []))

	equipped_moves.clear()
	for entry: Variant in save.get("equipped_moves", []):
		if not entry is Dictionary:
			continue
		var move: Move = MoveData.get_move(str(entry.get("name", "")))
		if move == null:
			push_warning("CharacterData: saved move '%s' no longer in the bank — dropped on load" % [entry.get("name", "")])
			continue
		move.current_uses = int(entry.get("current_uses", move.max_uses))
		equipped_moves.append(move)

	equipped_passives.clear()
	for passive_name: Variant in save.get("equipped_passives", []):
		equipped_passives.append(str(passive_name))

	InjurySystem.recalculate_injury_modifiers(self)


static func _injuries_to_dicts(injuries: Array[Injury]) -> Array:
	var out: Array = []
	for injury: Injury in injuries:
		out.append({
			"injury_id": injury.injury_id,
			"severity": injury.severity,
			"battles_remaining": injury.battles_remaining,
		})
	return out


static func _injuries_from_dicts(entries: Variant) -> Array[Injury]:
	var out: Array[Injury] = []
	if not entries is Array:
		return out
	for entry: Variant in entries:
		if not entry is Dictionary:
			continue
		var injury := Injury.new()
		injury.injury_id = str(entry.get("injury_id", ""))
		injury.severity = int(entry.get("severity", Enums.InjurySeverity.MINOR)) as Enums.InjurySeverity
		injury.battles_remaining = int(entry.get("battles_remaining", 0))
		out.append(injury)
	return out
