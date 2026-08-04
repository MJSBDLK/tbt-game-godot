## Autoload singleton owning save files: schema, disk I/O, slot rings, and the
## load/restore flow. THIS HEADER IS THE LIVING DOC for the save system.
##
## Philosophy — serialize FACTS, not objects; reconstruct, don't restore:
## a save stores references (character JSON paths, move names) plus deltas
## (level, PP, injuries), never copies of authored data. Load rebuilds through
## the normal pipelines (CharacterDataLoader, MoveData.get_move) and layers
## the deltas on, so rebalanced data files flow into old saves for free.
##
## Schema (JSON, one file per save):
##   {
##     "save_version": 1,              // gate + migration hook
##     "kind": "auto_battle" | "auto_turn" | "manual",
##     "created_unix": 1784000000,
##     "label": "Mission 2 · Turn 5",  // display line for the load UI
##     "rng": {"seed": "...", "state": "..."},   // GameRng.capture_state()
##     "campaign": {...},              // CampaignManager.capture_save_state()
##     "squad": {...},                 // SquadManager.capture_save_state()
##     "battle": {...}                 // mid-battle snapshot; ABSENT between missions
##   }
##
## Slot rings (RQD 2026-08-01, rule of 4): two independent 4-slot rotating
## rings under user://saves/ —
##   auto_battle/slot_0..3  — written when a battle begins   (BLUE identity in UI)
##   auto_turn/slot_0..3    — written at player-phase start  (YELLOW identity in UI)
## A write lands on the first EMPTY slot, else overwrites the OLDEST
## (created_unix; a corrupt/unreadable slot reads as oldest, so damaged slots
## are reclaimed first). Manual saves (kind "manual") get their own directory
## when the save UI lands.
##
## Durability: writes are atomic — content goes to <path>.tmp, the previous
## good file rotates to <path>.bak, then tmp renames over the real path. A
## crash mid-write can never eat an existing save; a save of a corrupted
## session still leaves .bak recoverable.
##
## RNG policy: every save RECORDS the dice (GameRng). Settings.seeded_reload
## decides at LOAD time whether to restore them (default — same actions after
## a reload repeat the same outcomes) or reseed (reload re-rolls fate).
## Flipping the setting never invalidates a save.
##
## Registered as "SaveManager" in project.godot (after Campaign/SquadManager).
extends Node


signal save_written(kind: String, path: String)
signal save_loaded(path: String)


## Bump when the schema changes shape; add the upgrade to _migrate. Saves from
## NEWER versions than the running build are refused, never guessed at.
const SAVE_VERSION: int = 1

const SLOT_COUNT: int = 4
const KIND_AUTO_BATTLE: String = "auto_battle"
const KIND_AUTO_TURN: String = "auto_turn"
const KIND_MANUAL: String = "manual"

const DEFAULT_SAVE_ROOT: String = "user://saves"

## Overridable so tests write to a throwaway directory instead of the player's
## real saves (same pattern as Settings.settings_path).
var save_root: String = DEFAULT_SAVE_ROOT

## Battle section stashed by load_save_and_continue for the mission scene to
## consume: BattleScene._on_grid_ready calls take_pending_battle_restore() and,
## when non-empty, rebuilds the board from it instead of rolling fresh spawns.
var _pending_battle_restore: Dictionary = {}

## Set alongside _pending_battle_restore: the resume path re-emits
## player_phase_started, and without this latch the autosave trigger would
## immediately write a duplicate of the save that was just loaded — burning a
## ring slot per reload.
var _skip_next_phase_autosave: bool = false


func _ready() -> void:
	# TurnManager loads after SaveManager (autoload order) — defer the hookup.
	call_deferred("_connect_autosave_triggers")


## The one autosave trigger: every player-phase start. Turn 1 is the battle's
## first breath → blue ring (auto_battle); later turns → yellow (auto_turn).
## Capturing at phase start means upkeep (status ticks, refreshes, control
## locks) has ALREADY run — restore re-enters play without re-ticking it.
func _connect_autosave_triggers() -> void:
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager == null:
		push_warning("SaveManager: TurnManager autoload not found — autosaves not wired")
		return
	if not turn_manager.player_phase_started.is_connected(_on_player_phase_started):
		turn_manager.player_phase_started.connect(_on_player_phase_started)


func _on_player_phase_started(turn: int) -> void:
	if _skip_next_phase_autosave:
		_skip_next_phase_autosave = false
		return
	# F6 straight onto a map = no campaign; nothing meaningful to restore into.
	if not CampaignManager.is_active():
		return
	var battle: Dictionary = capture_battle_snapshot()
	if battle.is_empty():
		return
	var mission_number: int = CampaignManager.get_current_mission_index() + 1
	var kind: String = KIND_AUTO_BATTLE if turn <= 1 else KIND_AUTO_TURN
	var label: String = "Mission %d · Start" % mission_number if turn <= 1 \
			else "Mission %d · Turn %d" % [mission_number, turn]
	write_autosave(kind, build_snapshot(kind, label, battle))


# =============================================================================
# SNAPSHOT ASSEMBLY
# =============================================================================

## Assembles a complete campaign-layer save dict. `battle` is merged in when
## resuming mid-battle state matters (the autosave triggers pass it); an empty
## dict means "between missions" and the key is omitted entirely.
func build_snapshot(kind: String, label: String, battle: Dictionary = {}) -> Dictionary:
	var snapshot: Dictionary = {
		"save_version": SAVE_VERSION,
		"kind": kind,
		"created_unix": int(Time.get_unix_time_from_system()),
		"label": label,
		"rng": GameRng.capture_state(),
		"campaign": CampaignManager.capture_save_state(),
		"squad": SquadManager.capture_save_state(),
	}
	if not battle.is_empty():
		snapshot["battle"] = battle
	return snapshot


# =============================================================================
# WRITING
# =============================================================================

## Manual save (the system menu's Save button): campaign layer plus the live
## battle when one is running. Manual saves get their own 4-slot ring — rule
## of 4, same rotation as the autosave rings — until a real slot-management UI
## exists. Returns the path written, or "" (no active campaign / disk failure).
func write_manual_save() -> String:
	if not CampaignManager.is_active():
		push_warning("SaveManager: manual save refused — no active campaign to record")
		return ""
	var battle: Dictionary = {}
	if not TurnManager.is_battle_ended():
		battle = capture_battle_snapshot()
	var mission_number: int = CampaignManager.get_current_mission_index() + 1
	var label: String = "Mission %d · Turn %d" % [mission_number, TurnManager.turn_count] \
			if not battle.is_empty() else "Mission %d" % mission_number
	return write_autosave(KIND_MANUAL, build_snapshot(KIND_MANUAL, label, battle))


## Writes a snapshot into `kind`'s ring: first empty slot, else the oldest.
## (Despite the name it serves all three rings — manual saves rotate the same
## way.) Returns the path written, or "" on failure.
func write_autosave(kind: String, snapshot: Dictionary) -> String:
	var path: String = _pick_ring_slot(kind)
	if not write_save_file(path, snapshot):
		return ""
	_capture_screenshot(screenshot_path_for(path))
	save_written.emit(kind, path)
	DebugConfig.log_unit_init("SaveManager: %s autosave → %s" % [kind, path])
	return path


## Sibling screenshot for a save file: same basename, .png. The main menu's
## save-aware backdrop ("Black Mesa mode" — MenuStageBackdrop) shows the
## newest save's frame; ring-slot reuse overwrites the sibling too, so stale
## screenshots self-heal.
func screenshot_path_for(save_path: String) -> String:
	return save_path.get_basename() + ".png"


## Grabs the composed frame (world + HUD) at save time, downscaled to the
## 640×360 reference so backdrop files stay small and consistent across
## window sizes. Headless runs (GUT, CI) have no frame to grab — skip
## silently so tests stay fast. Best-effort: a failed capture never fails
## the save.
func _capture_screenshot(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return
	image.resize(640, 360, Image.INTERPOLATE_BILINEAR)
	image.save_png(path)


## Atomic write: tmp file → rotate previous to .bak → rename tmp into place.
func write_save_file(path: String, snapshot: Dictionary) -> bool:
	var make_err: int = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if make_err != OK:
		push_error("SaveManager: cannot create '%s' (error %d)" % [path.get_base_dir(), make_err])
		return false

	var tmp_path: String = path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open '%s' for writing (error %d)" % [
			tmp_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(snapshot, "\t"))
	file.close()

	if FileAccess.file_exists(path):
		var bak_path: String = path + ".bak"
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		DirAccess.rename_absolute(path, bak_path)

	var rename_err: int = DirAccess.rename_absolute(tmp_path, path)
	if rename_err != OK:
		push_error("SaveManager: failed to land '%s' (error %d)" % [path, rename_err])
		return false
	return true


# =============================================================================
# READING
# =============================================================================

## Parses + version-gates one save file. Returns {} on any failure (missing,
## unparseable, or from a newer build). Older versions run through _migrate.
func read_save_file(path: String) -> Dictionary:
	var content: String = FileAccess.get_file_as_string(path)
	if content.is_empty():
		return {}
	# JSON instance, not JSON.parse_string — the static helper pushes an engine
	# error on malformed input, and a corrupt save slot is an expected condition
	# (we quietly reclaim it), not an engine fault.
	var json := JSON.new()
	if json.parse(content) != OK or not json.data is Dictionary:
		push_warning("SaveManager: '%s' is not valid save JSON" % path)
		return {}
	var snapshot: Dictionary = json.data as Dictionary
	var version: int = int(snapshot.get("save_version", 0))
	if version > SAVE_VERSION:
		push_warning("SaveManager: '%s' is save_version %d but this build reads %d — refusing" % [
			path, version, SAVE_VERSION])
		return {}
	if version < SAVE_VERSION:
		snapshot = _migrate(snapshot, version)
	return snapshot


## Metadata for every readable save, newest first — the load UI's row source.
## Each entry: {path, kind, label, created_unix, has_battle}.
func list_saves() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for kind: String in [KIND_AUTO_BATTLE, KIND_AUTO_TURN, KIND_MANUAL]:
		for i: int in range(SLOT_COUNT):
			var path: String = _slot_path(kind, i)
			var snapshot: Dictionary = read_save_file(path)
			if snapshot.is_empty():
				continue
			out.append({
				"path": path,
				"kind": str(snapshot.get("kind", kind)),
				"label": str(snapshot.get("label", "")),
				"created_unix": int(snapshot.get("created_unix", 0)),
				"has_battle": snapshot.has("battle"),
			})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["created_unix"]) > int(b["created_unix"]))
	return out


# =============================================================================
# RESTORE
# =============================================================================

## State-only load: read → restore squad + campaign + dice. NO scene routing —
## that's load_save_and_continue's job, keeping this callable headless (tests)
## and from any future entry point. Returns false (state untouched) if the
## file can't be read.
##
## Dice branch: seeded_reload restores the recorded stream (same actions after
## a reload → same outcomes); off means reload re-rolls fate.
func load_and_restore(path: String) -> bool:
	var snapshot: Dictionary = read_save_file(path)
	if snapshot.is_empty():
		push_warning("SaveManager: nothing restorable at '%s'" % path)
		return false

	SquadManager.restore_save_state(snapshot.get("squad", {}))
	CampaignManager.restore_save_state(snapshot.get("campaign", {}))

	if Settings.seeded_reload:
		GameRng.restore_state(snapshot.get("rng", {}))
	else:
		GameRng.reseed()

	save_loaded.emit(path)
	return true


## The UI-facing load flow: restore state, then route the player somewhere
## sensible. A snapshot with a "battle" section routes straight into the
## mission scene with the section stashed — BattleScene._on_grid_ready finds
## it via take_pending_battle_restore() and rebuilds the board mid-fight.
## Between-mission snapshots land at the prep screen.
func load_save_and_continue(path: String) -> bool:
	if not load_and_restore(path):
		return false

	var snapshot: Dictionary = read_save_file(path)
	if snapshot.has("battle") and CampaignManager.is_active():
		_pending_battle_restore = snapshot["battle"]
		_skip_next_phase_autosave = true
		SceneRouter.change_scene_to(CampaignManager.get_current_mission_path())
		return true

	if CampaignManager.is_active():
		SceneRouter.change_scene_to(CampaignManager.PREP_SCREEN_PATH)
	else:
		SceneRouter.change_scene_to(CampaignManager.START_SCREEN_PATH)
	return true


# =============================================================================
# BATTLE SNAPSHOT — capture side
# =============================================================================

## Serializes the live board mid-battle. Called at player-phase start (post-
## upkeep), but written to work mid-phase too — future manual saves capture
## between actions, so acted-latches (can_act/can_move) ride along.
##
## Player units store only battle-transient state + a character_id pointing
## into the squad section (their CharacterData already rides there, mid-battle
## PP included). Enemies aren't in any roster, so they carry their own full
## delta dict — same to_save_dict pipeline, which also means a rebalanced
## enemy JSON flows into old saves exactly like player characters.
func capture_battle_snapshot() -> Dictionary:
	if TurnManager.is_battle_ended():
		return {}
	var units: Array = []
	# is_instance_valid guards: TurnManager's lists can hold freed units after
	# a scene change (it's an autoload; battle scenes die under it).
	for unit: Unit in TurnManager.get_player_units():
		if is_instance_valid(unit) and not unit.is_defeated():
			units.append(_unit_to_save_dict(unit))
	for unit: Unit in TurnManager.get_enemy_units():
		if is_instance_valid(unit) and not unit.is_defeated():
			units.append(_unit_to_save_dict(unit))
	if units.is_empty():
		return {}
	return {
		"turn_count": TurnManager.turn_count,
		"units": units,
		# The level-up report diffs against battle-START state; without this a
		# resumed battle would report level_before as of the resume, not the
		# mission start.
		"pre_battle_snapshots": SquadManager.get_pre_battle_snapshots(),
	}


func _unit_to_save_dict(unit: Unit) -> Dictionary:
	var moves: Array[Move] = unit.character_data.equipped_moves \
			if unit.character_data != null else ([] as Array[Move])
	var statuses: Array = []
	for effect: StatusEffect in unit.active_status_effects:
		statuses.append(_status_to_dict(effect))
	var entry: Dictionary = {
		"faction": unit.faction,
		"grid_x": unit.current_tile.grid_x if unit.current_tile != null else 0,
		"grid_y": unit.current_tile.grid_y if unit.current_tile != null else 0,
		"current_hp": unit.current_hp,
		"can_act": unit.can_act,
		"can_move": unit.can_move,
		"pending_crit": unit.pending_crit,
		"assigned_move_index": moves.find(unit.assigned_move),
		"last_used_move_index": unit.last_used_move_index,
		"statuses": statuses,
		# Pending delayed strikes ON this unit (Phase 4) — plain data, schema in
		# ScheduledEffects' header. Restored with int re-coercion (JSON floats).
		"scheduled_effects": unit.scheduled_effects.duplicate(true),
	}
	if unit.faction == Enums.UnitFaction.PLAYER:
		entry["character_id"] = unit.character_data.character_id if unit.character_data != null else ""
	else:
		entry["json_path"] = unit.character_json_path
		entry["character"] = unit.character_data.to_save_dict() \
				if unit.character_data != null else {}
		var enemy_ai: Node = unit.get_node_or_null("EnemyAI")
		entry["ai_behavior"] = enemy_ai.behavior_type if enemy_ai != null \
				else Enums.AIBehaviorType.AGGRESSIVE
	return entry


static func _status_to_dict(effect: StatusEffect) -> Dictionary:
	var entry: Dictionary = {
		"effect_type_name": effect.effect_type_name,
		"category": effect.category,
		"affected_stat": effect.affected_stat,
		"stacks": effect.stacks,
		"caster_level": effect.caster_level,
		"dot_damage_per_tick": effect.dot_damage_per_tick,
		"hot_heal_per_tick": effect.hot_heal_per_tick,
		"locked_slots": effect.locked_slots.duplicate(true),
		"source_element": effect.source_element,
		"source_damage_type": effect.source_damage_type,
	}
	# Live unit references can't ride in a file — persist the source (the
	# CHALLENGED challenger) as its board cell; resolve_status_sources
	# re-points it after restore re-places everyone.
	if effect.source_unit != null and is_instance_valid(effect.source_unit):
		var source_tile: Variant = effect.source_unit.get("current_tile")
		if source_tile != null:
			entry["source_cell"] = [source_tile.grid_x, source_tile.grid_y]
	return entry


# =============================================================================
# BATTLE SNAPSHOT — restore side
# =============================================================================

## One-shot read of the stashed battle section. BattleScene calls this on
## grid-ready; empty means "normal spawn flow."
func take_pending_battle_restore() -> Dictionary:
	var battle: Dictionary = _pending_battle_restore
	_pending_battle_restore = {}
	return battle


## Applies one _unit_to_save_dict entry onto a freshly-spawned Unit: acted
## latches, banked crit, assigned move, rebuilt status effects (stat modifiers
## RECOMPUTED, never trusted from the file), then HP — clamped to the
## possibly-status-shifted max. Spawning the unit is the caller's job
## (BattleScene owns scenes and tiles); this owns the save-schema knowledge.
func apply_unit_state(unit: Unit, entry: Dictionary) -> void:
	unit.can_act = bool(entry.get("can_act", true))
	unit.can_move = bool(entry.get("can_move", true))
	# The acted gray-out is applied by set_acted(), never derived from can_act —
	# and resume_battle skips the phase upkeep that would repaint it. Without
	# this, a mid-phase save restores expended units in fresh full color.
	if unit.can_act:
		unit._apply_active_modulate()
	else:
		unit._apply_acted_modulate()
	unit.pending_crit = bool(entry.get("pending_crit", false))
	unit.last_used_move_index = int(entry.get("last_used_move_index", -1))

	if unit.character_data != null:
		var move_index: int = int(entry.get("assigned_move_index", -1))
		if move_index >= 0 and move_index < unit.character_data.equipped_moves.size():
			unit.assigned_move = unit.character_data.equipped_moves[move_index]

	unit.active_status_effects.clear()
	for status_entry: Variant in entry.get("statuses", []):
		if status_entry is Dictionary:
			unit.active_status_effects.append(_status_from_dict(status_entry))
	StatusEffectSystem.recalculate_stat_modifiers(unit)
	unit._update_status_indicators()

	unit.scheduled_effects.clear()
	for pending_entry: Variant in entry.get("scheduled_effects", []):
		if pending_entry is Dictionary:
			unit.scheduled_effects.append(_scheduled_from_dict(pending_entry))

	if unit.character_data != null:
		unit.current_hp = clampi(int(entry.get("current_hp", unit.character_data.max_hp)),
				1, unit.character_data.max_hp)
	unit._update_health_bar()


## After a battle restore has re-placed every unit, re-point status source
## references (the CHALLENGED challenger) from saved grid cells to the live
## units now standing there. Unresolvable cells (occupant gone) degrade to a
## sourceless status — the compulsion lapses, nothing breaks.
static func resolve_status_sources(units: Array[Unit]) -> void:
	for unit: Unit in units:
		for effect: StatusEffect in unit.active_status_effects:
			if effect.pending_source_cell == null:
				continue
			var cell: Array = effect.pending_source_cell
			effect.pending_source_cell = null
			var tile: Tile = GridManager.get_tile(int(cell[0]), int(cell[1]))
			if tile != null and tile.current_unit is Unit:
				effect.source_unit = tile.current_unit


## JSON round-trip re-coercion for one scheduled-effect entry (schema in
## ScheduledEffects' header). Ints ride home as floats; handlers compare ints.
static func _scheduled_from_dict(entry: Dictionary) -> Dictionary:
	return {
		"faction": int(entry.get("faction", Enums.UnitFaction.ENEMY)),
		"turns_remaining": int(entry.get("turns_remaining", 1)),
		"effect": str(entry.get("effect", "")),
		"marker": str(entry.get("marker", "")),
		"stacks": int(entry.get("stacks", 1)),
		"immune": str(entry.get("immune", "")),
		"params": (entry.get("params", {}) as Dictionary).duplicate(true),
		"source_name": str(entry.get("source_name", "")),
	}


static func _status_from_dict(entry: Dictionary) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_type_name = str(entry.get("effect_type_name", ""))
	effect.category = int(entry.get("category", Enums.EffectCategory.DEBUFF)) as Enums.EffectCategory
	effect.affected_stat = str(entry.get("affected_stat", ""))
	effect.stacks = int(entry.get("stacks", 0))
	effect.caster_level = int(entry.get("caster_level", 1))
	effect.dot_damage_per_tick = int(entry.get("dot_damage_per_tick", 0))
	effect.hot_heal_per_tick = int(entry.get("hot_heal_per_tick", 0))
	effect.source_element = int(entry.get("source_element", Enums.ElementalType.NONE)) as Enums.ElementalType
	effect.source_damage_type = int(entry.get("source_damage_type", Enums.DamageType.PHYSICAL)) as Enums.DamageType
	if entry.has("source_cell"):
		var cell: Variant = entry.get("source_cell")
		if cell is Array and (cell as Array).size() == 2:
			effect.pending_source_cell = [int(cell[0]), int(cell[1])]
	# JSON floats → the ints the lock-check compares against.
	for slot: Variant in entry.get("locked_slots", []):
		if slot is Dictionary:
			effect.locked_slots.append({
				"kind": str(slot.get("kind", "")),
				"index": int(slot.get("index", 0)),
			})
	return effect


# =============================================================================
# INTERNAL
# =============================================================================

func _slot_path(kind: String, index: int) -> String:
	return "%s/%s/slot_%d.json" % [save_root, kind, index]


## First empty slot wins; otherwise the oldest created_unix is overwritten.
## A corrupt slot parses to {} → created 0 → treated as oldest → reclaimed
## before any healthy save is touched.
func _pick_ring_slot(kind: String) -> String:
	var oldest_path: String = _slot_path(kind, 0)
	var oldest_time: int = 0x7FFFFFFFFFFFFFFF
	for i: int in range(SLOT_COUNT):
		var path: String = _slot_path(kind, i)
		if not FileAccess.file_exists(path):
			return path
		var created: int = int(read_save_file(path).get("created_unix", 0))
		if created < oldest_time:
			oldest_time = created
			oldest_path = path
	return oldest_path


## Schema upgrades, applied stepwise oldest→current. Version 1 is the first
## shipped schema, so this is identity until SAVE_VERSION bumps.
func _migrate(snapshot: Dictionary, _from_version: int) -> Dictionary:
	return snapshot
