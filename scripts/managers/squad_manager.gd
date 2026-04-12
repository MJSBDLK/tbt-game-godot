## Autoload singleton holding the player's persistent squad of CharacterData
## across missions. Each character is identified by character_id (declared in
## the JSON or derived from the filename).
##
## Bootstrap: at startup, loads the default roster (Spaceman, Ernesto, Ma'am).
## Lookup: BattleScene calls get_character_by_path(json_path) when spawning a
## player unit on a tile. SquadManager returns the existing roster entry if it
## exists, lazily loads from JSON if it doesn't, or returns null if the
## character has been permadead.
##
## Permadeath: InjurySystem calls mark_permadead(character_data) when an
## injury commit fails. The character is removed from the active roster and
## their id is added to a permadead set so future spawn requests return null.
##
## Future expansion (not yet implemented):
##   - Save/load roster state to disk
##   - Pre-mission squad selection UI (player picks 4 of N to deploy)
##   - Recruitment of new characters
##   - Roster size cap (currently unlimited)
##
## Registered as "SquadManager" in project.godot.
extends Node


signal character_added(character_data: CharacterData)
signal character_permadead(character_id: String)


# Default roster bootstrapped at game start.
const DEFAULT_ROSTER_PATHS: Array[String] = [
	"res://data/characters/spaceman.json",
	"res://data/characters/ernesto.json",
	"res://data/characters/maam.json",
]

# character_id -> CharacterData (active roster)
var _roster_by_id: Dictionary = {}
# character_id -> source JSON path (so we can identify which character a path corresponds to)
var _path_by_id: Dictionary = {}
# Set of permadead character ids (key is id, value is true)
var _permadead_ids: Dictionary = {}


func _ready() -> void:
	_bootstrap_default_roster()
	# TurnManager loads after SquadManager (autoload order in project.godot),
	# so defer the connect until both are ready.
	call_deferred("_connect_turn_manager")
	if DebugConfig.testing_injuries:
		call_deferred("_run_injury_self_test")


func _connect_turn_manager() -> void:
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager == null:
		push_warning("SquadManager: TurnManager autoload not found — battle_ended hook not wired")
		return
	if not turn_manager.battle_ended.is_connected(_on_battle_ended):
		turn_manager.battle_ended.connect(_on_battle_ended)


# =============================================================================
# MISSION END HOOK
# =============================================================================

## Called when TurnManager emits battle_ended. Walks the active roster:
##   1. Commits any pending injuries on each character (slot overflow → permadeath)
##   2. Ticks recovery on every active roster member (regardless of participation)
func _on_battle_ended(_is_victory: bool) -> void:
	# Snapshot active roster — mark_permadead mutates the dict during iteration.
	var snapshot: Array[CharacterData] = get_active_roster()
	for character: CharacterData in snapshot:
		var alive: bool = InjurySystem.commit_pending_injuries(character)
		if not alive:
			mark_permadead(character)
	# Tick recovery on the surviving roster (the snapshot contained permadead-to-be
	# members, but those are gone now, so re-fetch).
	for character: CharacterData in get_active_roster():
		InjurySystem.tick_recovery(character)
	DebugConfig.log_unit_init("SquadManager: battle_ended processed — active roster: %s" % _roster_by_id.keys())


# =============================================================================
# BOOTSTRAP
# =============================================================================

func _bootstrap_default_roster() -> void:
	for path: String in DEFAULT_ROSTER_PATHS:
		var character: CharacterData = CharacterDataLoader.load_character(path)
		if character == null:
			push_warning("SquadManager: Bootstrap failed to load '%s'" % path)
			continue
		_register(character, path)
	DebugConfig.log_unit_init("SquadManager: Bootstrapped %d characters: %s" % [
		_roster_by_id.size(), _roster_by_id.keys()])


# =============================================================================
# LOOKUP — used by BattleScene when spawning player units
# =============================================================================

## Returns the persistent CharacterData for a given JSON path, or null if the
## character is permadead. Falls back to a fresh JSON load (and caches it) if
## the path's character is not yet in the roster.
##
## BattleScene should call this for every player spawn tile and skip the spawn
## if the result is null.
func get_character_by_path(json_path: String) -> CharacterData:
	# Check the path -> id reverse map first (cheap path-based lookup).
	for id: String in _path_by_id.keys():
		if _path_by_id[id] == json_path:
			if _permadead_ids.has(id):
				DebugConfig.log_unit_init("SquadManager: Refusing spawn — %s is permadead" % id)
				return null
			return _roster_by_id[id]

	# Not in roster yet — load it fresh and add it.
	var character: CharacterData = CharacterDataLoader.load_character(json_path)
	if character == null:
		return null

	# If the freshly-loaded character has an id matching a permadead one, refuse.
	if _permadead_ids.has(character.character_id):
		DebugConfig.log_unit_init("SquadManager: Refusing spawn — %s is permadead" % character.character_id)
		return null

	_register(character, json_path)
	return character


func get_character_by_id(character_id: String) -> CharacterData:
	if _permadead_ids.has(character_id):
		return null
	return _roster_by_id.get(character_id, null)


## Returns all currently active (non-permadead) roster entries.
func get_active_roster() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for entry: CharacterData in _roster_by_id.values():
		out.append(entry)
	return out


func is_permadead(character_id: String) -> bool:
	return _permadead_ids.has(character_id)


# =============================================================================
# MUTATIONS — called by InjurySystem on permadeath
# =============================================================================

## Removes a character from the active roster and marks them permadead.
## Future spawn requests for this character will return null.
func mark_permadead(character_data: CharacterData) -> void:
	if character_data == null:
		return
	var id: String = character_data.character_id
	if id == "":
		push_warning("SquadManager: Cannot permadead a character with no id")
		return
	_permadead_ids[id] = true
	_roster_by_id.erase(id)
	# Keep _path_by_id as-is so future lookups by path can still detect permadeath.
	character_permadead.emit(id)
	DebugConfig.log_unit_init("SquadManager: %s permadead" % id)


# =============================================================================
# INTERNAL
# =============================================================================

# =============================================================================
# DEBUG SELF-TEST
# =============================================================================

## Programmatic end-to-end test of the injury pipeline. Mocks a unit death,
## queues an injury, runs commit, ticks recovery, and verifies stat penalties.
## Toggle on with DebugConfig.testing_injuries = true.
func _run_injury_self_test() -> void:
	print("=== InjurySystem self-test ===")

	var spaceman: CharacterData = get_character_by_id("spaceman")
	if spaceman == null:
		push_error("Self-test: spaceman missing from roster")
		return

	var base_str: int = spaceman.strength
	print("  spaceman.strength baseline: %d" % base_str)

	# --- Test 1: Minor stat-pct injury ---
	print("\n[Test 1] Queue Minor Burn Scar (Fire/Physical)")
	var injury1 := Injury.new()
	injury1.injury_id = "burn_scar"
	injury1.severity = Enums.InjurySeverity.MINOR
	injury1.battles_remaining = 4
	spaceman.pending_injuries.append(injury1)
	print("  pending_injuries: %d" % spaceman.pending_injuries.size())

	InjurySystem.commit_pending_injuries(spaceman)
	print("  current_injuries: %d, slots_used: %d" % [
		spaceman.current_injuries.size(), spaceman.injury_slots_used()])
	print("  spaceman.strength after Minor Burn Scar: %d (expected ~%d)" % [
		spaceman.strength, base_str - max(1, int(base_str * 0.10))])
	print("  injury_modifier_strength: %d" % spaceman.injury_modifier_strength)

	# --- Test 2: Tick recovery ---
	print("\n[Test 2] Tick recovery 4 times")
	for i: int in range(4):
		InjurySystem.tick_recovery(spaceman)
		print("  after tick %d: %d injuries, str=%d" % [
			i + 1, spaceman.current_injuries.size(), spaceman.strength])

	if spaceman.current_injuries.is_empty():
		print("  PASS: injury expired after 4 battles")
	else:
		push_error("  FAIL: injury did not expire")

	# --- Test 3: Major injury (frostbite from Cold/Special) ---
	print("\n[Test 3] Queue Major Frostbite on Ernesto")
	var ernesto: CharacterData = get_character_by_id("ernesto")
	if ernesto == null:
		push_error("Self-test: ernesto missing from roster")
		return
	var data: InjuryData = InjuryDatabase.lookup(Enums.ElementalType.COLD, Enums.DamageType.SPECIAL)
	if data == null:
		push_error("  Lookup failed for (Cold, Special)")
		return
	var base_agi: int = ernesto.agility
	var major := Injury.new()
	major.injury_id = data.injury_id
	major.severity = Enums.InjurySeverity.MAJOR
	major.battles_remaining = data.major_recovery_battles
	ernesto.pending_injuries.append(major)
	InjurySystem.commit_pending_injuries(ernesto)
	print("  ernesto.current_injuries: %d, slots_used: %d (expected 2)" % [
		ernesto.current_injuries.size(), ernesto.injury_slots_used()])
	print("  ernesto.agility: %d (was %d, expected ~25%% lower)" % [ernesto.agility, base_agi])

	# --- Test 4: Slot overflow → permadeath ---
	print("\n[Test 4] Slot overflow on Ma'am")
	var maam: CharacterData = get_character_by_id("maam")
	if maam == null:
		push_error("Self-test: maam missing from roster")
		return
	# Fill 3 slots with minor injuries
	for i: int in range(3):
		var minor := Injury.new()
		minor.injury_id = "burn_scar"
		minor.severity = Enums.InjurySeverity.MINOR
		minor.battles_remaining = 4
		maam.current_injuries.append(minor)
	print("  maam slots: %d/4" % maam.injury_slots_used())

	# Queue a major (2 slots) -> total would be 5 -> permadeath
	var fatal := Injury.new()
	fatal.injury_id = "wound_chivalric"
	fatal.severity = Enums.InjurySeverity.MAJOR
	fatal.battles_remaining = 8
	maam.pending_injuries.append(fatal)
	var alive: bool = InjurySystem.commit_pending_injuries(maam)
	if not alive:
		mark_permadead(maam)
	print("  alive after commit: %s" % alive)
	print("  maam in roster: %s" % (get_character_by_id("maam") != null))
	print("  is_permadead('maam'): %s" % is_permadead("maam"))

	print("\n=== Self-test complete ===")


func _register(character: CharacterData, source_path: String) -> void:
	if character.character_id == "":
		push_warning("SquadManager: Cannot register character with empty id (path=%s)" % source_path)
		return
	if _roster_by_id.has(character.character_id):
		# Already registered — keep the existing instance.
		return
	_roster_by_id[character.character_id] = character
	_path_by_id[character.character_id] = source_path
	character_added.emit(character)
