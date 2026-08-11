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
## Emitted after battle_ended processing completes. The report is an Array of
## Dictionaries, one per character in the pre-commit roster snapshot, with keys:
##   "character_name": String
##   "new_injuries": Array[Injury]        # committed this mission
##   "recovered_injuries": Array[Injury]  # expired from recovery tick
##   "permadead": bool                    # slot overflow during commit
##   "is_victory": bool
signal post_mission_report_ready(report: Array)
## Fires whenever the shared bonus-XP pool changes — award on victory, spend
## from the bEXP screen. UIs that display the pool can subscribe instead of
## polling.
signal bonus_xp_changed(new_pool: int)


## Shared squad-wide pool of bonus XP. Spent on the post-mission bEXP screen
## by pouring it into individual characters' regular `experience` field. Stays
## across missions; carries forward when the player skips the screen.
##
## Income per [[mission_objectives.md]] (amended 2026-08-03): itemized award
## lines from MissionCatalog — turn-par bands + completed objectives — summed
## into the pool at battle end. The flat per-victory grant is retired.
var bonus_xp_pool: int = 0

## Itemized income from the most recent battle_ended, verbatim from
## MissionCatalog.compute_award_lines ({label, amount} dicts). Transient
## display data for the result + bEXP screens — deliberately NOT persisted;
## a mid-battle save predates the awards and a post-mission save has already
## banked them into bonus_xp_pool.
var last_mission_award_lines: Array[Dictionary] = []


# Default roster bootstrapped at game start. THE ORDER IS CANON (RQD
# 2026-08-10): squad order is the order these people joined — Ma'am, then
# Ernesto, then Max, then the Elf Pirate — and it's what the rail's default
# sort shows and what spawn position derives from (intermission.md §4a/§4d).
# ElfPirate is the squad's only Air-type — kept in the starting roster on
# purpose so terrain that's only traversable by fliers (Wall, Volcano, Water)
# is always testable without rolling for them in the recruit picker.
const DEFAULT_ROSTER_PATHS: Array[String] = [
	"res://data/characters/maam.json",
	"res://data/characters/ernesto.json",
	"res://data/characters/spaceman.json",
	"res://data/characters/elf_pirate.json",
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
	if not turn_manager.battle_started.is_connected(_on_battle_started):
		turn_manager.battle_started.connect(_on_battle_started)


# character_id -> Dictionary { level, stat_ups, growth_gains: {field: int} }
# captured at battle_started. The level-up report diffs each character's
# current state against this so combat-XP-driven level-ups are reflected the
# same way as post-victory rolls — same animation, same per-stat reveals.
# Cleared each battle so multi-mission campaigns don't carry stale state.
var _pre_battle_snapshots: Dictionary = {}


## Snapshots level, stat-up pool, and every growth_gains_* field for each
## deployed player unit. Called from TurnManager.battle_started. The growth
## snapshot is what lets us diff per-stat: "STR grew during this mission"
## becomes `current_growth_gains_strength > snapshot.growth_gains_strength`.
func _on_battle_started(player_units: Array) -> void:
	_pre_battle_snapshots.clear()
	for unit: Variant in player_units:
		if unit == null:
			continue
		var data: CharacterData = unit.character_data if "character_data" in unit else null
		if data == null:
			continue
		# Refill PP on every equipped move. CharacterData (and its move list)
		# persists across missions via this manager, so without this each
		# move's current_uses would carry the depleted state from the prior
		# battle. Enemies don't need this — they spawn from fresh JSON copies.
		for move: Move in data.equipped_moves:
			if move != null:
				move.reset_uses()
		var growth_snapshot: Dictionary = {}
		for entry: Array in _GROWTH_FIELDS:
			growth_snapshot[entry[1]] = data.get(entry[1])
		_pre_battle_snapshots[data.character_id] = {
			"level": data.level,
			"stat_ups": data.available_stat_ups,
			"growth_gains": growth_snapshot,
		}


# =============================================================================
# MISSION END HOOK
# =============================================================================

## How many process_level_up rolls each surviving player character earns per
## victorious mission *on top of* combat XP gained during the fight.
##
## Combat XP via CombatXpCalculator is now the primary driver of leveling
## (Radiant Dawn–style). This freebie is kept at 0 by default; flip to 1 to
## A/B compare against the old "everyone gets a free level on victory"
## baseline, or to soften early missions where chip damage is rare.
const LEVELS_PER_VICTORY: int = 0

# Stat keys paired with their growth_gains_* property name. Used to diff growth
# rolls before/after a level-up so the post-mission report can show "+1 STR".
const _GROWTH_FIELDS: Array = [
	["max_hp", "growth_gains_hp", "HP"],
	["strength", "growth_gains_strength", "STR"],
	["special", "growth_gains_special", "SPC"],
	["skill", "growth_gains_skill", "SKL"],
	["agility", "growth_gains_agility", "AGL"],
	["athleticism", "growth_gains_athleticism", "ATH"],
	["defense", "growth_gains_defense", "DEF"],
	["resistance", "growth_gains_resistance", "RES"],
]


## Called when TurnManager emits battle_ended. Walks the active roster:
##   1. Ticks recovery on each character's PRE-EXISTING injuries
##   2. Commits any pending injuries earned this battle (slot overflow → permadeath)
##   3. On victory, runs LEVELS_PER_VICTORY level-up rolls on each survivor so
##      growths + stat-up points flow into the prep-screen allocation UI.
##
## Tick-before-commit order is load-bearing: commit-then-tick burned a recovery
## battle off the injury the unit JUST earned, so a 1-battle injury (same-type
## Minor) expired inside the same battle_ended pass and never appeared in any
## fight. Ticking first also means an injury that expires this pass frees its
## slot before the overflow/permadeath check — the recovery happened during the
## same downtime, so the freed slot fairly counts.
func _on_battle_ended(is_victory: bool) -> void:
	# Snapshot active roster — mark_permadead mutates the dict during iteration.
	var snapshot: Array[CharacterData] = get_active_roster()
	var report: Array = []
	for character: CharacterData in snapshot:
		# Capture new injuries (the pending list, which commit_pending_injuries clears).
		var new_injuries: Array = character.pending_injuries.duplicate()
		var pre_tick_snapshot: Array = character.current_injuries.duplicate()

		InjurySystem.tick_recovery(character)
		var recovered: Array = []
		for prior in pre_tick_snapshot:
			if not character.current_injuries.has(prior):
				recovered.append(prior)

		var alive: bool = InjurySystem.commit_pending_injuries(character)
		var permadead: bool = not alive
		if permadead:
			mark_permadead(character)

		# The pre-battle snapshot is the source of truth for level_before /
		# pool_before / which growths happened — combat XP can grow either of
		# them mid-battle, so the values at battle_ended don't reflect "what
		# the unit had when the mission started." Fall back to current state
		# for undeployed roster members (no snapshot → no delta).
		var pre_snapshot: Dictionary = _pre_battle_snapshots.get(character.character_id, {})
		var level_before: int = pre_snapshot.get("level", character.level)
		var pool_before: int = pre_snapshot.get("stat_ups", character.available_stat_ups)
		var pre_growths: Dictionary = pre_snapshot.get("growth_gains", {})
		var growths_gained: Array[String] = []
		if not permadead:
			# Reset transient battle state so the next spawn starts clean —
			# otherwise stale status_modifier_* values (from buffs/debuffs active
			# at battle end) leak into the next mission and can zero out HP.
			character.reset_status_modifiers()

			if is_victory:
				# Optional freebie roll (LEVELS_PER_VICTORY) runs on top of
				# combat XP. Its growths get folded into the same diff below.
				_apply_post_victory_level_ups(character)
			# Diff every growth_gains_* against the pre-battle snapshot.
			# Combat-XP-driven and freebie-driven gains both show up here.
			for entry: Array in _GROWTH_FIELDS:
				var field: String = entry[1]
				var current: int = int(character.get(field))
				var before: int = int(pre_growths.get(field, current))
				if current > before:
					growths_gained.append(entry[2])

		report.append({
			"character_name": character.character_name,
			"new_injuries": new_injuries,
			"recovered_injuries": recovered,
			"permadead": permadead,
			"level_before": level_before,
			"level_after": character.level,
			"stat_ups_gained": character.available_stat_ups - pool_before,
			"growths_gained": growths_gained,
			"is_victory": is_victory,
		})

	# Bank the mission's itemized bEXP income (par bands + objectives). The
	# mission path can be empty outside a campaign (ad-hoc battle scene) —
	# MissionCatalog serves defaults so those still pay out.
	var mission_path: String = CampaignManager.get_current_mission_path()
	last_mission_award_lines = MissionCatalog.compute_award_lines(
			MissionCatalog.entry_for(mission_path),
			TurnManager.turn_count, is_victory)
	var income: int = MissionCatalog.total_of(last_mission_award_lines)
	if income > 0:
		bonus_xp_pool += income
		bonus_xp_changed.emit(bonus_xp_pool)

	DebugConfig.log_unit_init("SquadManager: battle_ended processed — active roster: %s" % [_roster_by_id.keys()])
	post_mission_report_ready.emit(report)


# bEXP is a FLAT POOL, not a currency with prices (doctrine amended
# 2026-08-05 — see [.claude/mission_objectives.md] "XP Economy").
#
# The retired model charged BASE * unit_level / squad_max_level, so a high-level
# unit paid more per level. That is "higher level = harder to level" wearing a
# different hat, and it's the exact thing RQD argued against for combat XP. It
# had been recorded as locked but was never actually ratified.
#
# Catch-up belongs in the combat award (CombatXpCalculator's exponential), full
# stop. One rubber band, in one place, that the player can actually observe. A
# second one hidden in a shop price is a rule you can't see and can't learn.
const BEXP_LEVEL_COST: int = 100


## Buys one bEXP level. A level costs BEXP_LEVEL_COST regardless of who is
## buying or how high they are — same 100 XP a level costs in the field.
## Partial combat XP is untouched: a unit at 40/100 levels and is still at
## 40/100 in the new level.
##
## Deliberately does NOT route through CharacterData.grant_xp, because that
## path uses the combat level-up (rolls every stat against its growth rate).
## bEXP is a mechanically different XP source: process_bexp_level_up grants
## exactly BEXP_GROWTHS_PER_LEVEL growths, capped stats excluded.
##
## NOTE for the bEXP screen: this commits immediately and irreversibly — the
## growth rolls happen inside it. The mockup's refundable pouring (the [-1] and
## [-10] buttons) therefore needs a staging layer on top of this, holding
## uncommitted XP until the player confirms. Don't wire those buttons straight
## through to here.
func buy_bexp_level(character: CharacterData) -> bool:
	if character == null:
		return false
	if bonus_xp_pool < BEXP_LEVEL_COST:
		return false
	bonus_xp_pool -= BEXP_LEVEL_COST
	character.process_bexp_level_up()
	bonus_xp_changed.emit(bonus_xp_pool)
	return true


## Snapshots growth_gains_*, runs LEVELS_PER_VICTORY level-up rolls, and returns
## the abbreviations of every stat that actually grew across all rolls (e.g.
## ["STR", "AGL"]). A stat appears at most once regardless of how many rolls
## hit it — the report just wants the shape of the level, not exact magnitudes.
func _apply_post_victory_level_ups(character: CharacterData) -> Array[String]:
	var before: Dictionary = {}
	for entry: Array in _GROWTH_FIELDS:
		before[entry[1]] = character.get(entry[1])
	for _i: int in range(LEVELS_PER_VICTORY):
		character.process_level_up()
	var grew: Array[String] = []
	for entry: Array in _GROWTH_FIELDS:
		if character.get(entry[1]) > before[entry[1]]:
			grew.append(entry[2])
	return grew


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
# SAVE / LOAD — orchestrated by SaveManager
# =============================================================================

## The pre-battle level snapshot, exposed for battle saves: a resumed battle
## must diff its level-up report against the levels at BATTLE start, which a
## process restart would otherwise have forgotten.
func get_pre_battle_snapshots() -> Dictionary:
	return _pre_battle_snapshots.duplicate(true)


## Restores get_pre_battle_snapshots() output on battle resume, coercing JSON
## floats back to the ints the report's typed locals expect. Resume never
## re-emits battle_started (that would refill PP mid-fight), so this is the
## only way the snapshot survives a reload.
func restore_pre_battle_snapshots(snapshots: Dictionary) -> void:
	_pre_battle_snapshots.clear()
	for id: Variant in snapshots.keys():
		var entry: Variant = snapshots[id]
		if not entry is Dictionary:
			continue
		var growth: Dictionary = {}
		var growth_in: Variant = entry.get("growth_gains", {})
		if growth_in is Dictionary:
			for field: Variant in growth_in.keys():
				growth[str(field)] = int(growth_in[field])
		_pre_battle_snapshots[str(id)] = {
			"level": int(entry.get("level", 1)),
			"stat_ups": int(entry.get("stat_ups", 0)),
			"growth_gains": growth,
		}


## Serializes the whole persistent squad: every roster member as (source JSON
## path + CharacterData deltas), the permadead set, and the bEXP pool.
func capture_save_state() -> Dictionary:
	var characters: Array = []
	for id: String in _roster_by_id.keys():
		characters.append({
			"path": _path_by_id.get(id, ""),
			"data": (_roster_by_id[id] as CharacterData).to_save_dict(),
		})
	return {
		"characters": characters,
		"permadead_ids": _permadead_ids.keys(),
		"bonus_xp_pool": bonus_xp_pool,
	}


## Replaces the current roster wholesale with a capture_save_state() snapshot.
## Each character reloads FRESH from their authored JSON and then gets the
## saved deltas layered on — the reconstruct-don't-restore rule, so rebalanced
## character/move data flows into old saves. Characters whose JSON no longer
## loads are dropped with a warning rather than failing the whole restore.
func restore_save_state(state: Dictionary) -> void:
	_roster_by_id.clear()
	_path_by_id.clear()
	_permadead_ids.clear()
	_pre_battle_snapshots.clear()

	for id: Variant in state.get("permadead_ids", []):
		_permadead_ids[str(id)] = true

	for entry: Variant in state.get("characters", []):
		if not entry is Dictionary:
			continue
		var path: String = str(entry.get("path", ""))
		var character: CharacterData = CharacterDataLoader.load_character(path)
		if character == null:
			push_warning("SquadManager: saved character at '%s' failed to load — dropped" % path)
			continue
		character.apply_save_dict(entry.get("data", {}))
		_register(character, path)

	bonus_xp_pool = int(state.get("bonus_xp_pool", 0))
	bonus_xp_changed.emit(bonus_xp_pool)
	DebugConfig.log_unit_init("SquadManager: restored %d characters from save: %s" % [
		_roster_by_id.size(), _roster_by_id.keys()])


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
