## Autoload singleton holding all injury definitions, keyed by source (element, damage_type).
## Use InjuryDatabase.lookup(element, damage_type) to find the appropriate injury for a kill.
## Registered as "InjuryDatabase" in project.godot.
extends Node


# All defined injuries, keyed by injury_id.
var _injuries_by_id: Dictionary = {}  # String -> InjuryData

# Lookup table for kill attribution.
# Key format: "%d:%d" % [element_int, damage_type_int]
# A wildcard damage type uses "%d:*" so the lookup checks the wildcard if the
# specific (element, damage_type) pair has no entry.
var _lookup: Dictionary = {}  # String -> InjuryData


func _ready() -> void:
	_build_definitions()
	DebugConfig.log_status("InjuryDatabase: Loaded %d injury definitions" % _injuries_by_id.size())


# =============================================================================
# PUBLIC API
# =============================================================================

## Returns the InjuryData matching the killing source's element and damage type,
## or null if none is defined for this combination.
func lookup(element: Enums.ElementalType, damage_type: Enums.DamageType) -> InjuryData:
	var specific_key: String = "%d:%d" % [element, damage_type]
	if _lookup.has(specific_key):
		return _lookup[specific_key]
	var wildcard_key: String = "%d:*" % element
	if _lookup.has(wildcard_key):
		return _lookup[wildcard_key]
	return null


func get_injury_by_id(injury_id: String) -> InjuryData:
	return _injuries_by_id.get(injury_id, null)


func get_all_injuries() -> Array[InjuryData]:
	var out: Array[InjuryData] = []
	for entry: InjuryData in _injuries_by_id.values():
		out.append(entry)
	return out


# =============================================================================
# DEFINITIONS
# =============================================================================

func _build_definitions() -> void:
	# --- Stat-pct injuries (most elements) ---
	_register(_make_stat_pct(
		"burn_scar", "Burn Scar",
		"A persistent burn scar that weakens the muscles beneath.",
		Enums.ElementalType.FIRE, true, Enums.DamageType.PHYSICAL,
		"strength", 10.0, 25.0))

	_register(_make_stat_pct(
		"frostbite", "Frostbite",
		"Lingering nerve damage from the cold slows the body.",
		Enums.ElementalType.COLD, true, Enums.DamageType.PHYSICAL,
		"agility", 10.0, 25.0))

	_register(_make_stat_pct(
		"nerve_damage", "Nerve Damage",
		"Misfiring nerves blunt the unit's reflexes.",
		Enums.ElementalType.ELECTRIC, true, Enums.DamageType.PHYSICAL,
		"skill", 10.0, 25.0))

	_register(_make_stat_pct(
		"contusion", "Contusion",
		"Deep bruising makes movement through rough terrain a chore.",
		Enums.ElementalType.PLANT, false, Enums.DamageType.PHYSICAL,
		"athleticism", 10.0, 25.0))

	_register(_make_stat_pct(
		"infection", "Infection",
		"A festering plant infection erodes the body's resistance.",
		Enums.ElementalType.PLANT, false, Enums.DamageType.SPECIAL,
		"resistance", 10.0, 25.0))

	_register(_make_stat_pct(
		"concussion", "Concussion",
		"A rattled head dulls the unit's coordination.",
		Enums.ElementalType.AIR, true, Enums.DamageType.PHYSICAL,
		"skill", 10.0, 25.0))

	_register(_make_stat_pct(
		"trauma_heraldic", "Trauma",
		"Battered armor and bones leave the unit's defenses compromised.",
		Enums.ElementalType.HERALDIC, false, Enums.DamageType.PHYSICAL,
		"defense", 10.0, 25.0))

	_register(_make_stat_pct(
		"trauma_simple", "Trauma",
		"Generic blunt-force trauma weakens the unit's stance.",
		Enums.ElementalType.SIMPLE, false, Enums.DamageType.PHYSICAL,
		"defense", 10.0, 25.0))

	_register(_make_stat_pct(
		"amnesia", "Amnesia",
		"The unit struggles to recall the techniques of focused attacks.",
		Enums.ElementalType.SIMPLE, false, Enums.DamageType.SPECIAL,
		"special", 10.0, 25.0))

	# --- maxHP-pct injuries ---
	_register(_make_max_hp_pct(
		"wound_chivalric", "Wound",
		"A deep wound from a chivalric weapon caps the unit's vitality.",
		Enums.ElementalType.CHIVALRIC, true, Enums.DamageType.PHYSICAL,
		20.0, 40.0))

	_register(_make_max_hp_pct(
		"wound_gentry", "Wound",
		"A precise stab from a gentry blade caps the unit's vitality.",
		Enums.ElementalType.GENTRY, false, Enums.DamageType.PHYSICAL,
		20.0, 40.0))

	# --- Move distance penalty ---
	_register(_make_move_distance(
		"broken_bone", "Broken Bone",
		"A broken bone makes every step harder.",
		Enums.ElementalType.GRAVITY, true, Enums.DamageType.PHYSICAL,
		1, 2))

	# --- Healing reduction ---
	_register(_make_healing_reduced(
		"laceration", "Laceration",
		"A clean cut that resists clotting. Healing is less effective.",
		Enums.ElementalType.ROBO, false, Enums.DamageType.PHYSICAL,
		25.0, 50.0))

	# --- Luck reduction ---
	_register(_make_luck_pct(
		"curse", "Curse",
		"An occult hex saps the unit's luck on every action.",
		Enums.ElementalType.OCCULT, true, Enums.DamageType.PHYSICAL,
		10.0, 20.0))

	# --- Turn skip chance ---
	_register(_make_turn_skip(
		"ptsd", "PTSD",
		"Each turn, the unit may freeze in fear and lose its action.",
		Enums.ElementalType.HERALDIC, false, Enums.DamageType.SPECIAL,
		6.25, 12.5))

	# --- Friendly fire (Corruption) ---
	# Flavor: "<UnitName> has been acting shifty lately..."
	_register(_make_friendly_fire(
		"corruption_gentry", "Corruption",
		"Has been acting shifty lately...",
		Enums.ElementalType.GENTRY, false, Enums.DamageType.SPECIAL,
		10.0, 20.0))

	_register(_make_friendly_fire(
		"corruption_obsidian", "Corruption",
		"Has been acting shifty lately...",
		Enums.ElementalType.OBSIDIAN, false, Enums.DamageType.SPECIAL,
		10.0, 20.0))

	# --- Move/passive lock ---
	_register(_make_move_lock(
		"bends", "Bends",
		"Void exposure locks one or more random move/passive slots each turn.",
		Enums.ElementalType.VOID, true, Enums.DamageType.PHYSICAL,
		1, 2))

	# --- Hide health ---
	# Minor: hides bar when HP > 50%; Major: always hides (threshold 0).
	_register(_make_hide_health(
		"hypoesthesia", "Hypoesthesia",
		"Numbness from electric trauma masks the unit's pain. Health is hard to read.",
		Enums.ElementalType.ROBO, false, Enums.DamageType.SPECIAL,
		0.5, 0.0))

	# --- Type removal ---
	_register(_make_remove_type(
		"crystallization", "Crystallization",
		"Obsidian shards alter the unit's elemental nature.",
		Enums.ElementalType.OBSIDIAN, false, Enums.DamageType.PHYSICAL,
		1, 2))


# =============================================================================
# REGISTRATION HELPERS
# =============================================================================

func _register(data: InjuryData) -> void:
	_injuries_by_id[data.injury_id] = data
	if data.matches_any_damage_type:
		_lookup["%d:*" % data.source_element] = data
	else:
		_lookup["%d:%d" % [data.source_element, data.source_damage_type]] = data


func _make_stat_pct(id: String, name: String, desc: String,
		element: Enums.ElementalType, any_dmg: bool, dmg: Enums.DamageType,
		stat: String, minor: float, major: float) -> InjuryData:
	var d := InjuryData.new()
	d.injury_id = id
	d.display_name = name
	d.description = desc
	d.source_element = element
	d.matches_any_damage_type = any_dmg
	d.source_damage_type = dmg
	d.mechanic = Enums.InjuryMechanic.STAT_PCT
	d.affected_stat = stat
	d.minor_magnitude = minor
	d.major_magnitude = major
	return d


func _make_max_hp_pct(id: String, name: String, desc: String,
		element: Enums.ElementalType, any_dmg: bool, dmg: Enums.DamageType,
		minor: float, major: float) -> InjuryData:
	var d := InjuryData.new()
	d.injury_id = id
	d.display_name = name
	d.description = desc
	d.source_element = element
	d.matches_any_damage_type = any_dmg
	d.source_damage_type = dmg
	d.mechanic = Enums.InjuryMechanic.MAX_HP_PCT
	d.minor_magnitude = minor
	d.major_magnitude = major
	return d


func _make_move_distance(id: String, name: String, desc: String,
		element: Enums.ElementalType, any_dmg: bool, dmg: Enums.DamageType,
		minor: int, major: int) -> InjuryData:
	var d := InjuryData.new()
	d.injury_id = id
	d.display_name = name
	d.description = desc
	d.source_element = element
	d.matches_any_damage_type = any_dmg
	d.source_damage_type = dmg
	d.mechanic = Enums.InjuryMechanic.MOVE_DISTANCE
	d.minor_magnitude = float(minor)
	d.major_magnitude = float(major)
	return d


func _make_healing_reduced(id: String, name: String, desc: String,
		element: Enums.ElementalType, any_dmg: bool, dmg: Enums.DamageType,
		minor: float, major: float) -> InjuryData:
	var d := InjuryData.new()
	d.injury_id = id
	d.display_name = name
	d.description = desc
	d.source_element = element
	d.matches_any_damage_type = any_dmg
	d.source_damage_type = dmg
	d.mechanic = Enums.InjuryMechanic.HEALING_REDUCED
	d.minor_magnitude = minor
	d.major_magnitude = major
	return d


func _make_luck_pct(id: String, name: String, desc: String,
		element: Enums.ElementalType, any_dmg: bool, dmg: Enums.DamageType,
		minor: float, major: float) -> InjuryData:
	var d := InjuryData.new()
	d.injury_id = id
	d.display_name = name
	d.description = desc
	d.source_element = element
	d.matches_any_damage_type = any_dmg
	d.source_damage_type = dmg
	d.mechanic = Enums.InjuryMechanic.LUCK_PCT
	d.minor_magnitude = minor
	d.major_magnitude = major
	return d


func _make_turn_skip(id: String, name: String, desc: String,
		element: Enums.ElementalType, any_dmg: bool, dmg: Enums.DamageType,
		minor: float, major: float) -> InjuryData:
	var d := InjuryData.new()
	d.injury_id = id
	d.display_name = name
	d.description = desc
	d.source_element = element
	d.matches_any_damage_type = any_dmg
	d.source_damage_type = dmg
	d.mechanic = Enums.InjuryMechanic.TURN_SKIP_CHANCE
	d.minor_magnitude = minor
	d.major_magnitude = major
	return d


func _make_friendly_fire(id: String, name: String, desc: String,
		element: Enums.ElementalType, any_dmg: bool, dmg: Enums.DamageType,
		minor: float, major: float) -> InjuryData:
	var d := InjuryData.new()
	d.injury_id = id
	d.display_name = name
	d.description = desc
	d.source_element = element
	d.matches_any_damage_type = any_dmg
	d.source_damage_type = dmg
	d.mechanic = Enums.InjuryMechanic.FRIENDLY_FIRE
	d.minor_magnitude = minor
	d.major_magnitude = major
	return d


func _make_move_lock(id: String, name: String, desc: String,
		element: Enums.ElementalType, any_dmg: bool, dmg: Enums.DamageType,
		minor: int, major: int) -> InjuryData:
	var d := InjuryData.new()
	d.injury_id = id
	d.display_name = name
	d.description = desc
	d.source_element = element
	d.matches_any_damage_type = any_dmg
	d.source_damage_type = dmg
	d.mechanic = Enums.InjuryMechanic.MOVE_LOCK
	d.minor_magnitude = float(minor)
	d.major_magnitude = float(major)
	return d


func _make_hide_health(id: String, name: String, desc: String,
		element: Enums.ElementalType, any_dmg: bool, dmg: Enums.DamageType,
		minor_threshold: float, major_threshold: float) -> InjuryData:
	var d := InjuryData.new()
	d.injury_id = id
	d.display_name = name
	d.description = desc
	d.source_element = element
	d.matches_any_damage_type = any_dmg
	d.source_damage_type = dmg
	d.mechanic = Enums.InjuryMechanic.HIDE_HEALTH
	d.minor_magnitude = minor_threshold
	d.major_magnitude = major_threshold
	return d


func _make_remove_type(id: String, name: String, desc: String,
		element: Enums.ElementalType, any_dmg: bool, dmg: Enums.DamageType,
		minor_count: int, major_count: int) -> InjuryData:
	var d := InjuryData.new()
	d.injury_id = id
	d.display_name = name
	d.description = desc
	d.source_element = element
	d.matches_any_damage_type = any_dmg
	d.source_damage_type = dmg
	d.mechanic = Enums.InjuryMechanic.REMOVE_TYPE
	d.minor_magnitude = float(minor_count)
	d.major_magnitude = float(major_count)
	return d
