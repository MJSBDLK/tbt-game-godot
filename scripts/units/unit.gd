## A unit on the battle grid — player, enemy, or neutral.
## Satisfies GridManager's duck-typed interface for movement range and pathfinding.
## Ported from Unity's Unit.cs.
class_name Unit
extends Node2D


# =============================================================================
# SIGNALS
# =============================================================================

signal unit_selected(unit: Unit)
signal unit_deselected(unit: Unit)
signal movement_started(unit: Unit)
signal movement_completed(unit: Unit)
signal movement_cancelled(unit: Unit)
## Emitted after a committed move finishes, carrying the exact walked path
## (start tile first, duplicates preserved). Drives foot-track rendering.
signal path_traversed(unit: Unit, tiles: Array[Tile])
signal health_changed(unit: Unit, new_hp: int, max_hp: int)
signal unit_defeated(unit: Unit)
signal combat_started(attacker: Unit, defender: Unit)
signal combat_hit(attacker: Unit, defender: Unit, damage: int)
signal combat_completed(attacker: Unit, defender: Unit)


# =============================================================================
# CONSTANTS
# =============================================================================

const MOVEMENT_SCALE: int = 2
const MOVE_SPEED: float = 600.0  # Pixels per second
const HIT_DELAY: float = 0.3  # Seconds between combat hits (a presenter hold; skip → 0)
# A Bellows-boosted fire hit never lands soft: impact weight floors here so the
# flash/shake/hitlag sell the boost (crits floor at 0.8 — this is the lesser
# beat). RQD 2026-08-21, todo #2A.
const BELLOWS_IMPACT_FLOOR: float = 0.6


# =============================================================================
# EXPORTS
# =============================================================================

@export var unit_name: String = "Unit"
@export var faction: Enums.UnitFaction = Enums.UnitFaction.PLAYER
@export var character_json_path: String = ""


# =============================================================================
# GRIDMANAGER INTERFACE PROPERTIES
# These are read by GridManager via duck-typed .get() calls.
# =============================================================================

var character_data: CharacterData = null
var current_tile: Tile = null
var planned_waypoints: Array = []  # Array of Waypoint

var max_movement_range: int:
	get:
		if character_data == null:
			return 0
		# ROOTED/FREEZE hard-stop movement for the whole turn. The lock is latched
		# into can_move at turn start (StatusEffectSystem.process_control_locks)
		# BEFORE the stack is decremented — that ordering is what makes a single
		# stack reliably cost exactly one turn. Read the latch, not live stacks:
		# a stack applied before this turn must still gate it even though it's
		# about to be consumed this turn.
		if not can_move:
			return 0
		return character_data.get_effective_move_distance() * MOVEMENT_SCALE


# =============================================================================
# STATE
# =============================================================================

var is_selected: bool = false
var can_act: bool = true
# Turn-scoped movement lock, mirroring can_act. Reset true each turn by
# refresh_unit, then set false by StatusEffectSystem.process_control_locks when
# ROOTED/FREEZE is active. max_movement_range reads this latch.
var can_move: bool = true
var is_moving: bool = false
var is_defeated_flag: bool = false
var _defeat_visuals_played: bool = false
var current_hp: int = 0
var assigned_move: Move = null
var last_used_move_index: int = -1  # Index into equipped_moves of the most recently executed move (for Capricious passive)
var active_status_effects: Array = []  # Array of StatusEffect
# Banked crit (from a setup move like Focus/Uppercut). The unit's next damaging
# hit crits, then this clears (CritEffect consumes it). Persists across turns —
# a setup move spends the turn, so the crit must survive to the next attack. Not
# an affliction/boost; lives purely in the combat pipeline. Reset at battle init.
var pending_crit: bool = false
# Pending delayed effects queued ON this unit (Phase 4 — Shriek's chain-
# lightning mark). Entry schema + tick clock live in ScheduledEffects' header;
# TurnManager ticks these at the CASTING faction's phase start. Plain data —
# SaveManager serializes the queue verbatim.
var scheduled_effects: Array[Dictionary] = []
# Move-uses this unit has INITIATED since its last turn refresh (counters don't
# count — only combats this unit starts). Drives Impetuous (+20% on the 1st, then
# -10% per use after). Counts every move use, attack or support.
var attacks_this_turn: int = 0

# Enemies whose engagement already paid this unit survival XP, keyed by
# attacker instance id (see _award_survival_xp). Per-battle by construction:
# units are freshly instantiated each battle scene load. (A mid-battle
# save/load rebuilds units and forgets these — an accepted leniency, the
# re-earn is a few XP.)
var _survival_xp_sources: Dictionary = {}
# Pre-grant stat snapshot for the mid-battle level-up reveal — captured by
# _grant_combat_xp the first time a level fires in a sequence, consumed and
# cleared by _flush_xp_feedback. Empty = nothing to celebrate.
var _level_up_snapshot: Dictionary = {}

# XP earned during the current combat sequence, batched into ONE "+N XP"
# callout when it ends (per-hit popups would spam a 4-hit chain). Flushed by
# _flush_xp_feedback; levels ride along for the LEVEL UP! callout.
var _combat_xp_gained: int = 0
var _combat_levels_gained: int = 0
# On-map XP bar (RQD 2026-08-21): `experience` as it stood BEFORE the first
# grant of this sequence (-1 = no sequence open), so the bar can sweep from
# where the unit started to where it landed — first grant wins, like the
# level-up snapshot. Consumed + reset by _flush_xp_feedback.
var _xp_before_sequence: int = -1

# Set by take_damage when the killing blow lands. Used by InjurySystem to
# pick the right injury when the unit_defeated handler runs.
# Shape: { "element": Enums.ElementalType, "damage_type": Enums.DamageType, "name": String }
var last_killing_source: Dictionary = {}
var last_damage_overkill: int = 0

# Per-turn injury state (cleared and re-rolled at start of each turn).
# Set by InjurySystem.process_turn_start.
var injury_locked_move_indices: Array[int] = []

var _start_tile_before_move: Tile = null
# The committed walk (start tile first), captured during the tentative move and
# held until the action is finalized. Foot tracks lay on set_acted() (commit),
# NOT on the tentative walk — so a cancelled move (Escape) leaves none.
var _pending_track_tiles: Array[Tile] = []

# ACT_THEN_WALK (Settings.move_commit_mode, todo 4A): the walk captured at
# plan-confirm, replayed by play_deferred_walk() when the action commits.
# Non-empty exactly while a walk is staged. While staged, LOGIC (current_tile,
# occupancy, ranges) is already at the destination but global_position — the
# sprite and everything riding it — is still at the origin, standing behind
# the PathVisualizer's staged ghost.
var _deferred_walk_path: Array[Tile] = []
var _selection_tween: Tween = null

# Topmost opaque pixel of the sprite art in texture coords (canvas top-left = 0).
# Lawrence's centered-canvas sprites have transparent padding; this is the y of
# the actual visible art so the health bar can sit above the unit, not the canvas.
# Loaded from the idle.json sidecar's `art_bounds.top`; 0 if no sidecar.
var _art_top: float = 0.0

# How far the sprite's VISUAL FEET sit below the node origin, in pixels.
# Lawrence authors the BODY centered on the canvas, so the runtime anchor
# (canvas center = cell center) is mid-body and the feet land ~10-16px lower
# — uniformly true across the whole cast (RQD survey 2026-07-31). The unit
# STANDS correctly that way; only the cast shadow needs the true feet line,
# so it pivots at the boots instead of the waist. From the idle.json
# sidecar's `art_bounds.bottom` minus the pivot; 0 if no sidecar.
var _art_feet_drop: float = 0.0

# Plays attack-clip strips on _sprite (frame timing, hit marker, idle
# restore) — ONE per sprite so a newer clip can cancel an older tail. Driven
# by the exchange's CombatPresenter (MapPresenter today); null for bare test
# units with no Sprite2D.
var clip_player: ClipPlayer = null

# Same-row z_index tie resolution. Attacker and defender on the same row
# compute identical z_index ((99-row)*10 + UNITS_layer), so Godot falls back
# to sibling tree order — later child draws on top. During an attack clip
# (or boop nudge) we move this unit to the end of its sibling list, then
# restore the recorded index at clip end.
#
# Reference-counted because multi-hit moves chain attacks via HIT_DELAY,
# and per-hit tails are fire-and-forget — Hit 2 starts before Hit 1's tail
# completes. Each raise increments the count and (on the first raise)
# stashes the original sibling index; each lower decrements and only
# actually restores tree position when the count returns to zero. Every
# exit of a clip tail / boop return in MapPresenter lowers exactly once.
var _attack_raised_original_index: int = -1
var _attack_raise_count: int = 0

# Child node references
var _sprite: Sprite2D = null
var _shadow: UnitShadow = null
var _health_bar: Node2D = null
var _health_bar_background: ColorRect = null
var _health_bar_fill: ColorRect = null
# On-map XP bar — built by _build_xp_bar under HealthBar, hidden at rest.
var _xp_bar: Node2D = null
var _xp_bar_fill: ColorRect = null
# Bumped on every play so an older run's tail can't hide a newer run's bar.
var _xp_bar_serial: int = 0
var _xp_bar_tween: Tween = null
var _status_indicator: StatusEffectIndicator = null
var _level_label: Label = null
# Elemental type icon sprites, mirrored right of the health bar (level sits
# left). Rebuilt by _update_type_icons.
var _type_icons: Array[Sprite2D] = []
var _path_visualizer: Node2D = null  # PathVisualizer
var _static_overlay: Sprite2D = null
var _static_tick_accum: float = 0.0

const _STATIC_NOISE_TEX: Texture2D = preload("res://art/sprites/ui/static_noise.png")
const _STATIC_BAR_WIDTH: int = 24
const _STATIC_BAR_HEIGHT: int = 2
const _STATIC_TICK_INTERVAL: float = 0.12

# On-map XP bar geometry + pacing (RQD 2026-08-21). Same footprint as the
# health bar, parked one pixel BELOW it (above is the status-icon row; RQD:
# "beneath seems more natural" — set XP_BAR_OFFSET_Y to -4.0 to try above;
# the health bar spans y -1..1, so +2 leaves a 1px gap). Fade in fast, fill,
# hold, fade out slow. A level wrap fills to full, flashes, restarts from 0.
# Reduce-motion parks the bar at the final fraction for the hold and skips
# every tween. All const-tunable; eyeball at playtest.
const XP_BAR_WIDTH: int = 24
const XP_BAR_HEIGHT: int = 2
const XP_BAR_OFFSET_Y: float = 2.0
const XP_BAR_FADE_IN_SECONDS: float = 0.1
const XP_BAR_FILL_SECONDS_PER_LEVEL: float = 0.45  # a full 0→100 sweep
const XP_BAR_FILL_MIN_SECONDS: float = 0.08
const XP_BAR_WRAP_FLASH_SECONDS: float = 0.1
const XP_BAR_HOLD_SECONDS: float = 0.5
const XP_BAR_FADE_OUT_SECONDS: float = 0.6
# Placeholder sample from tools/godot/generate_ui_sfx.gd — a rising tick
# train; Lawrence replaces the file, same name.
const XP_FILL_STREAM_PATH: String = "res://audio/ui/xp_fill.wav"


# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_sprite = $Sprite2D as Sprite2D
	# Generated cast shadow mirroring whatever frame _sprite shows (see
	# UnitShadow's header). Bare test units have no Sprite2D — no shadow.
	if _sprite != null:
		_shadow = UnitShadow.new()
		_shadow.name = "CastShadow"
		_shadow.source_sprite = _sprite
		add_child(_shadow)
		clip_player = ClipPlayer.new(_sprite, _load_character_sprite)
	_health_bar = $HealthBar as Node2D
	_health_bar_background = $HealthBar/Background as ColorRect
	_health_bar_fill = $HealthBar/Fill as ColorRect
	_status_indicator = $HealthBar/StatusEffectIndicator as StatusEffectIndicator
	_level_label = $HealthBar/LevelLabel as Label
	_style_level_label()
	if has_node("PathVisualizer"):
		_path_visualizer = $PathVisualizer
	_build_static_overlay()
	_build_xp_bar()
	set_process(true)
	StatusEffectSystem.status_effect_applied.connect(_on_status_effect_applied)
	StatusEffectSystem.status_effect_removed.connect(_on_status_effect_changed)
	# Type icons are gated on a live setting — rebuild when the player flips
	# the Options toggle mid-battle. Rebuilding on unrelated setting changes is
	# a cheap idempotent no-op (same pattern as HDPortraitSlot).
	Settings.changed.connect(_update_type_icons)


func initialize(starting_tile: Tile) -> void:
	# If character_data was injected before initialize() (BattleScene route for
	# persistent player units via SquadManager), skip the JSON load. Otherwise
	# fall back to loading from json_path (used by enemy units and tests).
	if character_data == null and character_json_path != "":
		character_data = CharacterDataLoader.load_character(character_json_path)
	if character_data == null:
		character_data = CharacterData.new()
		DebugConfig.log_error("Unit '%s': No character data loaded" % unit_name)

	# Apply persistent injury stat modifiers from prior missions. Safe to call
	# even on a freshly-loaded character with no injuries.
	InjurySystem.recalculate_injury_modifiers(character_data)

	# Sync name
	unit_name = character_data.character_name
	name = "Unit_%s" % unit_name

	# Place on starting tile
	move_to_tile(starting_tile)

	# Init HP
	current_hp = character_data.max_hp

	# Visuals
	_load_character_sprite()
	if _shadow != null:
		_shadow.feet_drop = _art_feet_drop
		# Blob disc radius: the character JSON override wins when set
		# (>= 0; 0 legitimately means "casts no blob"); otherwise measure
		# the idle stance ONCE — constant across every animation frame so
		# the shadow never breathes mid-attack.
		if character_data.shadow_blob_radius >= 0.0:
			_shadow.blob_radius = character_data.shadow_blob_radius
		elif _sprite != null and _sprite.texture != null:
			_shadow.blob_radius = UnitShadow.measure_stance_radius(_sprite.texture)
	_apply_faction_healthbar()
	_update_level_label()
	_update_type_icons()
	_update_healthbar_position()
	_update_z_index()
	_update_health_bar()

	can_act = true
	can_move = true
	pending_crit = false
	attacks_this_turn = 0
	is_selected = false

	DebugConfig.log_unit_init("Unit '%s' at %s | faction=%s type=%s HP=%d move=%d" % [
		unit_name, starting_tile.get_coordinates(),
		Enums.UnitFaction.keys()[faction],
		Enums.elemental_type_to_string(character_data.primary_type),
		current_hp, character_data.move_distance])

	if DebugConfig.testing_passives:
		_apply_random_debug_passives()

	if DebugConfig.testing_status_effects:
		_apply_random_debug_status_effects()

	if DebugConfig.testing_void_lock_debuff:
		_apply_debug_void_lock()

	if DebugConfig.testing_random_injuries_on_spawn and faction == Enums.UnitFaction.PLAYER:
		_apply_random_debug_injuries()

	if DebugConfig.testing_enemy_ghost and faction == Enums.UnitFaction.ENEMY:
		if not character_data.has_equipped_passive("Ghost"):
			character_data.equipped_passives.append("Ghost")

	if (DebugConfig.testing_hypoesthesia or DebugConfig.testing_hypoesthesia_major) \
			and faction == Enums.UnitFaction.PLAYER:
		_apply_debug_hypoesthesia()

	if DebugConfig.testing_random_hp_on_spawn and faction == Enums.UnitFaction.PLAYER:
		current_hp = maxi(1, roundi(character_data.max_hp * randf_range(0.15, 1.0)))

	if DebugConfig.testing_phase4_moves and faction == Enums.UnitFaction.PLAYER:
		_apply_debug_kit_moves(DEBUG_PHASE4_KIT)
	elif DebugConfig.testing_displacement_moves and faction == Enums.UnitFaction.PLAYER:
		_apply_debug_kit_moves(DEBUG_DISPLACEMENT_KIT)

	_update_health_bar()


# =============================================================================
# GRIDMANAGER INTERFACE: MOVEMENT COST
# =============================================================================

func get_total_planned_movement_cost() -> int:
	if planned_waypoints.is_empty():
		return 0
	return planned_waypoints[-1].movement_cost_to_reach


# =============================================================================
# WAYPOINT MANAGEMENT
# =============================================================================

func add_waypoint(target_tile: Tile) -> bool:
	if target_tile == null:
		return false

	var start_tile: Tile
	if planned_waypoints.size() > 0:
		start_tile = planned_waypoints[-1].tile
	else:
		start_tile = current_tile

	var path := GridManager.find_path(start_tile, target_tile, self)
	if path.is_empty():
		return false

	var path_cost := GridManager.calculate_path_cost(path, self)
	var cumulative_cost := get_total_planned_movement_cost() + path_cost

	if cumulative_cost > max_movement_range:
		DebugConfig.log_unit_move("Unit '%s': Can't afford waypoint at %s (cost %d > %d)" % [
			unit_name, target_tile.get_coordinates(), cumulative_cost, max_movement_range])
		return false

	var waypoint := Waypoint.new(target_tile, cumulative_cost)
	planned_waypoints.append(waypoint)

	DebugConfig.log_unit_move("Unit '%s': Waypoint at %s (cost %d/%d)" % [
		unit_name, target_tile.get_coordinates(), cumulative_cost, max_movement_range])

	if _path_visualizer != null and _path_visualizer.has_method("update_path"):
		_path_visualizer.call("update_path", self)

	return true


func clear_waypoints() -> void:
	planned_waypoints.clear()
	if _path_visualizer != null and _path_visualizer.has_method("clear_arrows"):
		_path_visualizer.call("clear_arrows")


# =============================================================================
# MOVEMENT EXECUTION
# =============================================================================

func execute_planned_movement() -> void:
	if planned_waypoints.is_empty():
		movement_completed.emit(self)
		return

	_start_tile_before_move = current_tile

	var full_path := _build_full_path()

	# Capture the walk for foot tracks: the start tile (which _build_full_path
	# excludes) followed by every tile actually traversed, duplicates preserved
	# so self-crossings overlay. current_tile is still the start tile here. The
	# move is tentative until set_acted(), so we only STASH now and lay tracks on
	# commit — a cancelled move (Escape) must leave none.
	var traversed_tiles: Array[Tile] = []
	if _start_tile_before_move != null:
		traversed_tiles.append(_start_tile_before_move)
	traversed_tiles.append_array(full_path)

	# ACT_THEN_WALK stages instead of walking. Player-only: the AI's walk is
	# its telegraph, so it always animates immediately regardless of the mode.
	if faction == Enums.UnitFaction.PLAYER and Settings != null \
			and Settings.move_commit_mode == Settings.MoveCommitMode.ACT_THEN_WALK:
		_stage_deferred_movement(full_path, traversed_tiles)
		return

	is_moving = true
	movement_started.emit(self)

	if _path_visualizer != null and _path_visualizer.has_method("clear_arrows"):
		_path_visualizer.call("clear_arrows")

	await _move_along_path(full_path)

	is_moving = false
	planned_waypoints.clear()
	_pending_track_tiles = traversed_tiles
	# NOTE: _start_tile_before_move is intentionally kept alive here.
	# It persists until set_acted() or cancel_movement() so the player
	# can press Escape to snap back after moving but before acting.
	movement_completed.emit(self)


## ACT_THEN_WALK: commit the LOGIC of the plan instantly — occupancy, ranges,
## previews and every movement_completed listener (auras, threat) read the
## destination — while the sprite stays at the origin behind the staged ghost.
## Ghost parks BEFORE the claim: UnitGhost.anchor_offset measures the sprite
## against current_tile, so both must still agree on the origin here. z is
## deliberately NOT restamped — the visual row hasn't changed; the deferred
## walk restamps it row by row as the sprite actually passes.
func _stage_deferred_movement(full_path: Array[Tile], traversed_tiles: Array[Tile]) -> void:
	var destination: Tile = full_path.back() if not full_path.is_empty() else current_tile
	if _path_visualizer != null and _path_visualizer.has_method("show_staged_ghost"):
		_path_visualizer.call("show_staged_ghost", self, destination)
	elif _path_visualizer != null and _path_visualizer.has_method("clear_arrows"):
		_path_visualizer.call("clear_arrows")
	_claim_tile_keep_position(destination)
	_deferred_walk_path = full_path
	planned_waypoints.clear()
	_pending_track_tiles = traversed_tiles
	movement_completed.emit(self)


## True while an ACT_THEN_WALK plan is staged and its walk hasn't played.
func has_deferred_walk() -> bool:
	return not _deferred_walk_path.is_empty()


## ACT_THEN_WALK: the staged walk, played when the action commits. Logic is
## already at the destination — this animates ONLY the sprite along the
## captured path, restamping z per row as it passes so layering follows the
## visible walk. No-op when nothing is staged, so every commit path can await
## it unconditionally.
func play_deferred_walk() -> void:
	if _deferred_walk_path.is_empty():
		return
	var path: Array[Tile] = _deferred_walk_path
	_deferred_walk_path = []
	# Frees the staged ghost the moment the real sprite starts covering the
	# same ground.
	if _path_visualizer != null and _path_visualizer.has_method("clear_arrows"):
		_path_visualizer.call("clear_arrows")
	is_moving = true
	movement_started.emit(self)
	for tile: Tile in path:
		var target_position := tile.global_position
		var distance := global_position.distance_to(target_position)
		var duration := distance / MOVE_SPEED
		if duration < 0.01:
			duration = 0.01
		var tween := create_tween()
		tween.tween_property(self, "global_position", target_position, duration)
		await tween.finished
		_update_z_index_for_row(tile.grid_y)
	is_moving = false


func cancel_movement() -> void:
	# A staged ACT_THEN_WALK walk dies with the plan. The sprite never moved,
	# so the move_to_tile below re-seats logic at the origin with no visible
	# jump — the honesty win of the mode.
	_deferred_walk_path = []
	if _start_tile_before_move != null:
		move_to_tile(_start_tile_before_move)
		_start_tile_before_move = null

	# Drop the un-committed walk so the undone move leaves no foot tracks.
	_pending_track_tiles = []
	planned_waypoints.clear()
	if _path_visualizer != null and _path_visualizer.has_method("clear_arrows"):
		_path_visualizer.call("clear_arrows")
	is_moving = false
	movement_cancelled.emit(self)


# =============================================================================
# TILE PLACEMENT (instant, no animation)
# =============================================================================

func move_to_tile(new_tile: Tile) -> void:
	_claim_tile_keep_position(new_tile)
	if current_tile != null:
		global_position = current_tile.global_position
	_update_z_index()


## The occupancy half of move_to_tile: transfer tile registration without
## touching the sprite. ACT_THEN_WALK stages through this so global_position
## (and z — the visual row hasn't changed) stay at the origin; everything else
## wants move_to_tile. Tile.set_unit snaps the unit onto the tile as a side
## effect, so the position is restored around the claim — that's the "keep"
## in the name.
func _claim_tile_keep_position(new_tile: Tile) -> void:
	var sprite_position: Vector2 = global_position
	if current_tile != null and current_tile.current_unit == self:
		current_tile.clear_unit()
	current_tile = new_tile
	if current_tile != null:
		if current_tile.current_unit == null:
			current_tile.set_unit(self)
		elif current_tile.current_unit != self:
			push_warning("Unit '%s' told to move_to_tile [%d,%d] already occupied by '%s'" % [
				unit_name, current_tile.grid_x, current_tile.grid_y, current_tile.current_unit.unit_name])
	global_position = sprite_position


# =============================================================================
# ANIMATED MOVEMENT
# =============================================================================

func _move_along_path(path: Array[Tile]) -> void:
	for tile: Tile in path:
		var target_position := tile.global_position
		var distance := global_position.distance_to(target_position)
		var duration := distance / MOVE_SPEED
		if duration < 0.01:
			duration = 0.01

		var tween := create_tween()
		tween.tween_property(self, "global_position", target_position, duration)
		await tween.finished

		# Update tile occupancy tile-by-tile. Only clear our OWN registration on
		# the previous tile, and only claim the new tile if it's free. This
		# prevents a walking unit from stomping another unit's occupancy when
		# paths unexpectedly cross.
		if current_tile != null and current_tile.current_unit == self:
			current_tile.clear_unit()
		current_tile = tile
		if tile.current_unit == null:
			tile.set_unit(self)
		else:
			push_warning("Unit '%s' stepped onto tile [%d,%d] already occupied by '%s' — skipping set_unit to preserve occupancy" % [
				unit_name, tile.grid_x, tile.grid_y, tile.current_unit.unit_name])
		_update_z_index()


func _build_full_path() -> Array[Tile]:
	var full_path: Array[Tile] = []
	var start: Tile = current_tile

	for waypoint: Variant in planned_waypoints:
		var segment := GridManager.find_path(start, waypoint.tile, self)
		# Preserve duplicates so self-crossing paths walk the literal route the
		# player drew. find_path excludes the start tile, so segments don't
		# introduce seam dupes — every repeat reflects a real revisit.
		full_path.append_array(segment)
		start = waypoint.tile

	return full_path


# =============================================================================
# SELECTION
# =============================================================================

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selected:
		_start_selection_pulse()
		unit_selected.emit(self)
	else:
		_stop_selection_pulse()
		unit_deselected.emit(self)


func _start_selection_pulse() -> void:
	_stop_selection_pulse()
	# Sprite-less units (headless tests select bare Units) have nothing to
	# pulse — tween_property on a null target is an engine error, not a no-op.
	if _sprite == null:
		return
	_selection_tween = create_tween().set_loops()
	_selection_tween.tween_property(_sprite, "modulate",
		Color(1.3, 1.3, 1.3, 1.0), 0.4)
	_selection_tween.tween_property(_sprite, "modulate",
		Color.WHITE, 0.4)


func _stop_selection_pulse() -> void:
	if _selection_tween != null:
		_selection_tween.kill()
		_selection_tween = null
	if can_act:
		_apply_active_modulate()
	else:
		_apply_acted_modulate()


# =============================================================================
# TURN STATE
# =============================================================================

func refresh_unit() -> void:
	can_act = true
	can_move = true
	attacks_this_turn = 0
	_start_tile_before_move = current_tile
	_apply_active_modulate()


func set_acted() -> void:
	# ACT_THEN_WALK: every commit path awaits play_deferred_walk() first —
	# committing with a staged walk would lay foot tracks under a sprite that
	# never walks them.
	assert(_deferred_walk_path.is_empty(),
			"set_acted with a staged walk pending — play_deferred_walk() must run first")
	can_act = false
	_start_tile_before_move = null
	# Move is now committed — lay the foot tracks captured during the walk.
	if _pending_track_tiles.size() > 1:
		path_traversed.emit(self, _pending_track_tiles)
	_pending_track_tiles = []
	_apply_acted_modulate()


# =============================================================================
# HEALTH
# =============================================================================

## Apply damage to this unit. The optional source dict carries the
## attribution data InjurySystem needs to assign an injury at death:
##   { "element": Enums.ElementalType, "damage_type": Enums.DamageType }
## Sources may also include a free-form "name" key for logging.
## When the killing blow lands, this caches source on the unit so the
## injury system can read it during the unit_defeated handler.
func take_damage(amount: int, source: Dictionary = {}) -> void:
	# Compute overkill BEFORE clamping current_hp. If a 5 HP unit takes 12 damage,
	# pre_clamp_hp = -7, so overkill = 7.
	var pre_clamp_hp: int = current_hp - amount
	current_hp = maxi(0, pre_clamp_hp)
	if pre_clamp_hp < 0:
		last_damage_overkill = -pre_clamp_hp
	_update_health_bar()
	health_changed.emit(self, current_hp, character_data.max_hp)
	if current_hp <= 0 and not is_defeated_flag:
		is_defeated_flag = true
		last_killing_source = source
		# Queue an injury based on the killing source. Player units get the actual
		# injury queued; enemy units skip injury queuing entirely (their character_data
		# isn't persisted between missions). This is checked by faction.
		if faction == Enums.UnitFaction.PLAYER:
			InjurySystem.queue_injury_from_death(self)
		unit_defeated.emit(self)


## Apply a final heal amount to this unit. Caller is responsible for computing
## the post-reduction value via DamageCalculator.apply_healing_reduction (or
## .calculate_heal_amount for move-driven heals). This function only adds + clamps.
func heal(amount: int) -> void:
	if amount <= 0:
		return
	current_hp = mini(character_data.max_hp, current_hp + amount)
	_update_health_bar()
	health_changed.emit(self, current_hp, character_data.max_hp)


func _update_health_bar() -> void:
	if _health_bar_fill == null or character_data == null:
		return
	if character_data.max_hp <= 0:
		return
	var health_percent := float(current_hp) / float(character_data.max_hp)
	_health_bar_fill.scale.x = health_percent
	# Hypoesthesia: swap the fill for a static-noise overlay when the injury
	# threshold is exceeded. The bar itself stays visible so the censor reads.
	var censor: bool = character_data.is_health_bar_hidden(current_hp)
	_health_bar_fill.visible = not censor
	if _static_overlay != null:
		_static_overlay.visible = censor


func _build_static_overlay() -> void:
	if _health_bar == null:
		return
	_static_overlay = Sprite2D.new()
	_static_overlay.name = "StaticOverlay"
	_static_overlay.texture = _STATIC_NOISE_TEX
	_static_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_static_overlay.centered = false
	_static_overlay.region_enabled = true
	_static_overlay.region_rect = Rect2(0, 0, _STATIC_BAR_WIDTH, _STATIC_BAR_HEIGHT)
	# Background ColorRect spans offset_left=-12..right=12, top=-1..bottom=1.
	# Sprite2D is uncentered, so position at the top-left corner.
	_static_overlay.position = Vector2(-_STATIC_BAR_WIDTH / 2.0, -_STATIC_BAR_HEIGHT / 2.0)
	_static_overlay.visible = false
	_health_bar.add_child(_static_overlay)


# =============================================================================
# ON-MAP XP BAR (RQD 2026-08-21, todo #1)
# =============================================================================
# The in-the-moment companion to the "+N XP" callout: a yellow-on-black bar
# the health bar's size, one pixel beneath it, that fades in, sweeps from the
# pre-combat XP to the new total (wrapping with a flash on a level-up), holds,
# and fades out. Built in code like the static overlay so bare test units and
# the .tscn stay untouched; enemies build one too but never show it (only
# player units earn XP).

func _build_xp_bar() -> void:
	if _health_bar == null:
		return
	_xp_bar = Node2D.new()
	_xp_bar.name = "XpBar"
	_xp_bar.visible = false
	var half_width := float(XP_BAR_WIDTH) / 2.0
	var background := ColorRect.new()
	background.name = "Background"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = GameColors.UNIT_BAR_BACKGROUND
	background.position = Vector2(-half_width, XP_BAR_OFFSET_Y)
	background.size = Vector2(XP_BAR_WIDTH, XP_BAR_HEIGHT)
	_xp_bar.add_child(background)
	# Left-anchored like the health bar's fill: the rect's origin is its left
	# edge, so scale.x grows rightward from there.
	_xp_bar_fill = ColorRect.new()
	_xp_bar_fill.name = "Fill"
	_xp_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_bar_fill.color = GameColors.XP_BAR_FILL
	_xp_bar_fill.position = Vector2(-half_width, XP_BAR_OFFSET_Y)
	_xp_bar_fill.size = Vector2(XP_BAR_WIDTH, XP_BAR_HEIGHT)
	_xp_bar_fill.scale.x = 0.0
	_xp_bar.add_child(_xp_bar_fill)
	_health_bar.add_child(_xp_bar)


## The bar's sweep as [start, end] fill fractions, one pair per segment —
## pure, so the wrap logic is testable without a tree. No level: one segment
## from→to. N levels: from→full, then (N-1)× 0→full, then 0→to; the renderer
## flashes and resets to 0 between segments.
static func xp_bar_fill_segments(from_xp: int, to_xp: int, levels_gained: int) -> Array[Array]:
	var per_level := float(CharacterData.XP_PER_LEVEL)
	var from_fraction := clampf(float(from_xp) / per_level, 0.0, 1.0)
	var to_fraction := clampf(float(to_xp) / per_level, 0.0, 1.0)
	var segments: Array[Array] = []
	if levels_gained <= 0:
		segments.append([from_fraction, to_fraction])
		return segments
	segments.append([from_fraction, 1.0])
	for _extra: int in range(levels_gained - 1):
		segments.append([0.0, 1.0])
	segments.append([0.0, to_fraction])
	return segments


## Play the bar for one flushed sequence. Fire-and-forget from
## _flush_xp_feedback so it runs alongside the callouts; a newer play kills
## the older tween and takes over the bar.
func _play_xp_bar(from_xp: int, to_xp: int, levels_gained: int) -> void:
	if _xp_bar == null or _xp_bar_fill == null:
		return
	_xp_bar_serial += 1
	var serial: int = _xp_bar_serial
	if _xp_bar_tween != null and _xp_bar_tween.is_valid():
		_xp_bar_tween.kill()
	var segments := xp_bar_fill_segments(from_xp, to_xp, levels_gained)
	assert(not segments.is_empty(), "xp_bar_fill_segments always yields at least one segment")
	_xp_bar.visible = true
	_xp_bar_fill.color = GameColors.XP_BAR_FILL

	var motion: bool = Settings == null or Settings.ui_motion_enabled
	if not motion or not is_inside_tree():
		# Reduce-motion (or no tree to tween in): park at the landing fraction
		# for the hold, then hide. The callout still carries the number.
		_xp_bar.modulate.a = 1.0
		_xp_bar_fill.scale.x = segments.back()[1]
		_play_xp_fill_sfx()
		if is_inside_tree():
			await get_tree().create_timer(XP_BAR_HOLD_SECONDS).timeout
		if serial == _xp_bar_serial and is_instance_valid(_xp_bar):
			_xp_bar.visible = false
		return

	_xp_bar.modulate.a = 0.0
	_xp_bar_fill.scale.x = segments[0][0]
	var tween := create_tween()
	_xp_bar_tween = tween
	tween.tween_property(_xp_bar, "modulate:a", 1.0, XP_BAR_FADE_IN_SECONDS)
	for index: int in segments.size():
		var segment: Array = segments[index]
		if index > 0:
			# Level wrap: flash, then restart from empty.
			tween.tween_property(_xp_bar_fill, "color", GameColors.XP_BAR_FLASH, XP_BAR_WRAP_FLASH_SECONDS / 2.0)
			tween.tween_property(_xp_bar_fill, "color", GameColors.XP_BAR_FILL, XP_BAR_WRAP_FLASH_SECONDS / 2.0)
			tween.tween_callback(func() -> void: _xp_bar_fill.scale.x = segment[0])
		tween.tween_callback(_play_xp_fill_sfx)
		var distance: float = maxf(0.0, segment[1] - segment[0])
		var duration: float = maxf(XP_BAR_FILL_MIN_SECONDS, distance * XP_BAR_FILL_SECONDS_PER_LEVEL)
		tween.tween_property(_xp_bar_fill, "scale:x", segment[1], duration)
	tween.tween_interval(XP_BAR_HOLD_SECONDS)
	tween.tween_property(_xp_bar, "modulate:a", 0.0, XP_BAR_FADE_OUT_SECONDS)
	tween.tween_callback(func() -> void:
		if serial == _xp_bar_serial and is_instance_valid(_xp_bar):
			_xp_bar.visible = false)


## The filling sound — same fire-and-forget one-shot player as the level-up
## ding (LevelUpReportPanel._play_ding) and the UI blips. Silent when the
## sample is missing so a stripped build never errors.
func _play_xp_fill_sfx() -> void:
	if not is_inside_tree() or not ResourceLoader.exists(XP_FILL_STREAM_PATH):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(XP_FILL_STREAM_PATH) as AudioStream
	player.bus = &"SFX"
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _process(delta: float) -> void:
	if _static_overlay == null or not _static_overlay.visible:
		return
	_static_tick_accum += delta
	if _static_tick_accum < _STATIC_TICK_INTERVAL:
		return
	_static_tick_accum = 0.0
	var tex_size: Vector2i = _STATIC_NOISE_TEX.get_size()
	var max_x: int = maxi(0, tex_size.x - _STATIC_BAR_WIDTH)
	var max_y: int = maxi(0, tex_size.y - _STATIC_BAR_HEIGHT)
	var rx: int = randi() % (max_x + 1)
	var ry: int = randi() % (max_y + 1)
	_static_overlay.region_rect = Rect2(rx, ry, _STATIC_BAR_WIDTH, _STATIC_BAR_HEIGHT)


# =============================================================================
# COMBAT — MOVE ASSIGNMENT
# =============================================================================

func assign_move(move: Move) -> void:
	assigned_move = move


## Returns true if the given move slot index is locked by either a status effect (VOID)
## or an active per-turn injury effect (Bends).
func is_move_index_locked(index: int) -> bool:
	if StatusEffectSystem.is_move_locked(self, index):
		return true
	if index in injury_locked_move_indices:
		return true
	return false


## Returns true if the given passive slot index (into character_data.equipped_passives)
## is locked by VOID. A locked passive is skipped wherever passive handlers are
## gathered (see PassiveRegistry.get_handlers_for), so its combat effect goes inert.
func is_passive_index_locked(index: int) -> bool:
	return StatusEffectSystem.is_passive_locked(self, index)


func auto_assign_first_usable_move() -> void:
	if character_data == null:
		return
	for move: Move in character_data.equipped_moves:
		if move.has_uses_remaining() and not is_move_index_locked(character_data.equipped_moves.find(move)):
			assigned_move = move
			return
	assigned_move = null


func get_usable_moves() -> Array[Move]:
	var usable: Array[Move] = []
	if character_data == null:
		return usable
	for index: int in range(character_data.equipped_moves.size()):
		var move: Move = character_data.equipped_moves[index]
		if move.has_uses_remaining() and not is_move_index_locked(index):
			usable.append(move)
	return usable


func is_defeated() -> bool:
	return current_hp <= 0


## Returns a random non-defeated ally within manhattan `attack_range` of this unit,
## or null if none exist. Used by the FRIENDLY_FIRE injury mechanic to retarget.
func _pick_random_ally_in_range(attack_range: int) -> Unit:
	# Autoload accessed by global name (house style) — also keeps this callable
	# from units not yet in the tree (tests).
	var pool: Array[Unit] = []
	if faction == Enums.UnitFaction.PLAYER:
		pool = TurnManager.get_player_units()
	else:
		pool = TurnManager.get_enemy_units()

	var candidates: Array[Unit] = []
	for ally: Unit in pool:
		if ally == self or ally.is_defeated() or ally.current_tile == null or current_tile == null:
			continue
		var dist: int = absi(ally.current_tile.grid_x - current_tile.grid_x) + absi(ally.current_tile.grid_y - current_tile.grid_y)
		if dist <= attack_range:
			candidates.append(ally)

	if candidates.is_empty():
		return null
	return candidates[GameRng.randi() % candidates.size()]


## Corruption's retarget decision, split out for testability: the ally-victim
## on a proc, or the ORIGINAL defender when no ally is in range. Never null —
## a proc with nobody around proceeds normally instead of fizzling (design call
## 2026-07-06: isolating a corrupted unit from its allies is the counterplay,
## so standing alone must be safe, not wasted).
func resolve_friendly_fire_victim(original_defender: Unit, move: Move) -> Unit:
	var ally: Unit = _pick_random_ally_in_range(move.attack_range)
	if ally == null:
		return original_defender
	return ally


# =============================================================================
# COMBAT — SEQUENCE EXECUTION
# Logic only. Every visual beat goes through a CombatPresenter (its header is
# the living map): scripts/combat/presenter/combat_presenter.gd.
# =============================================================================

## Run one full exchange: the attacker's move against `defender`, counters,
## multi-hits, and everything that rides on them. LOGIC lives here — rolls,
## damage, the pipeline, live range re-checks, XP banking. Every visual
## moment is a beat on `presenter` (CombatPresenter — its header is the
## living map of the battle-animation system). Pass a presenter to choose
## the presentation (tests hand in a RecordingPresenter); null lets
## CombatPresenter.for_exchange decide.
func execute_combat_sequence(defender: Unit, attacker_move: Move,
		presenter: CombatPresenter = null) -> void:
	if defender == null or attacker_move == null:
		return
	# ACT_THEN_WALK: the sprite must have walked before it swings — commit
	# paths await play_deferred_walk() first.
	assert(_deferred_walk_path.is_empty(),
			"combat with a staged walk pending — play_deferred_walk() must run first")

	# Friendly casts: ally-targeting moves AND self-casts (Fortify, Roar) both
	# resolve as a single application — no counter, no multi-hit, no corruption
	# retarget, no Protector body-block.
	var is_ally_move := attacker_move.targets_allies() \
			or attacker_move.target_type == Enums.TargetType.SELF

	# Friendly fire (Corruption injury): the attacker has been "acting shifty."
	# On a proc, retarget a random ally in range. If no ally is in range, the
	# attack proceeds against the original target — Corruption never fizzles
	# (design call 2026-07-06: isolating a corrupted unit from its allies is the
	# counterplay, so standing alone must be safe, not wasted).
	# Skipped for ally-targeting moves (they're already friendly).
	# This is a MAP beat on purpose: it explains the retarget before any
	# presenter opens, so the scene always shows the real combatants.
	if not is_ally_move and character_data != null and character_data.friendly_fire_chance_pct() > 0.0:
		if GameRng.randf() * 100.0 < character_data.friendly_fire_chance_pct():
			var victim: Unit = resolve_friendly_fire_victim(defender, attacker_move)
			if victim == defender:
				DebugConfig.log_combat("FriendlyFire: %s procced with no ally in range — attack proceeds normally" % unit_name)
			else:
				# Surface the proc to the player BEFORE the swing animation so the
				# cause-and-effect ("Corruption fired → I hit my ally") reads cleanly
				# instead of looking like a bug. Brief pause lets the callout register
				# before the attacker pivots toward the new target.
				spawn_text_callout("CORRUPTION", GameColors.TEXT_DANGER)
				await get_tree().create_timer(0.4).timeout
				DebugConfig.log_combat("FriendlyFire: %s redirected attack from %s to %s" % [
					unit_name, defender.unit_name, victim.unit_name])
				defender = victim

	# Protector: a ranged offensive attack that passes over an ally-bodyguard of
	# the target hits the bodyguard instead. No-op for ally moves, off-axis shots,
	# or adjacency. Runs after friendly-fire (if that procced, the target is now
	# our own ally and nothing redirects). Single point that covers player + AI.
	if not is_ally_move:
		defender = MoveTargeting.resolve_actual_target(self, defender, attacker_move)

	# The presentation is chosen once, AFTER the combatants are final.
	if presenter == null:
		presenter = CombatPresenter.for_exchange(self, defender, attacker_move)

	combat_started.emit(self, defender)
	# Count this move use for the turn (Impetuous reads it). Counters go through
	# _execute_single_hit, not here, so they don't count.
	attacks_this_turn += 1
	DebugConfig.log_combat("Combat: %s (move=%s) vs %s" % [unit_name, attacker_move.move_name, defender.unit_name])
	await presenter.open(self, defender, attacker_move)

	# Friendly casts (heals, buffs, self-target support): single application, no
	# counter, no multi-hit. A self-cast whose payload is entirely for OTHERS
	# (Roar's shout, Shriek's mark — nothing self-directed) skips the primary
	# self application; the cast flourish + AoE pass below ARE the move.
	if is_ally_move:
		attacker_move.consume_use()
		if defender != self or _self_cast_has_self_payload(attacker_move):
			await _execute_single_hit(defender, attacker_move, true, presenter)
		else:
			await presenter.cast_flourish(self, attacker_move)
		await _execute_area_applications(defender, attacker_move, presenter)
		# Non-heal support casts pay flat XP once per CAST (a 5-victim Roar is
		# one cast, not five awards). Heals award inside _execute_heal_hit —
		# skipping them here prevents a double grant. No meaningful-effect
		# check needed at this point: has_meaningful_effect_on gates targeting
		# (chip greyed, tile invalid), so a cast that executed is a cast that
		# mattered — and re-checking NOW would wrongly fail, since the buff has
		# already landed and the target reads as "already buffed."
		if not attacker_move.heals:
			_award_support_xp(attacker_move)
		await presenter.close()
		await _flush_xp_feedback()
		combat_completed.emit(self, defender)
		return

	var completed_normally: bool = await _run_offensive_exchange(defender, attacker_move, presenter)
	# XP feedback and the mid-battle level-up play on the MAP, after the
	# presenter has closed — never under a scene overlay.
	await presenter.close()
	assert(not presenter.is_open(), "presenter still open after close")
	if not completed_normally:
		# A combatant fell on hit 1 / counter 1: no bonus hits, no survival XP,
		# no Capricious reroll (the exchange never reached its natural end).
		# The survivor's XP still flushes HERE — before the seam this path
		# returned without it, so a first-hit kill (the most common kill) hid
		# its +XP callout and level-up celebration until the killer's next
		# exchange. Pinned by test_combat_xp's first-hit-kill test.
		if not is_defeated():
			await _flush_xp_feedback()
		if is_instance_valid(defender) and not defender.is_defeated():
			await defender._flush_xp_feedback()
		combat_completed.emit(self, defender)
		return

	# Survival XP: the defender lived through an enemy's offensive engagement
	# (tank or dodge — the sequence ran either way). First engagement from
	# THIS attacker only; repeats are tracked per battle on the defender.
	defender._award_survival_xp(self)

	# Capricious: each combatant who has the passive re-rolls their assigned_move
	# for next combat. Within THIS combat the move was locked in (so a multi-hit
	# counter doesn't swap moves mid-chain — per design); the reroll happens once
	# now, after every hit landed, so the next time this unit fights they're
	# using a different move.
	_capricious_post_combat_reroll(self)
	_capricious_post_combat_reroll(defender)

	# XP feedback, batched per combatant. XP earned by a unit that then died
	# stays banked (earned before dying counts) — only its popup is skipped;
	# _handle_defeat may have started freeing the node.
	if not is_defeated():
		await _flush_xp_feedback()
	if is_instance_valid(defender) and not defender.is_defeated():
		await defender._flush_xp_feedback()

	combat_completed.emit(self, defender)
	DebugConfig.log_combat("Combat complete: %s HP=%d, %s HP=%d" % [
		unit_name, current_hp, defender.unit_name, defender.current_hp])


## The offensive exchange proper: hit 1, counter 1, bonus hits, bonus
## counters, with the live range re-checks between them. Returns false when
## a combatant fell on hit 1 or counter 1 (the sequence ends there — no
## bonus hits, and the caller skips the post-combat rewards, as it always
## has); true when the exchange ran to its natural end.
func _run_offensive_exchange(defender: Unit, attacker_move: Move,
		presenter: CombatPresenter) -> bool:
	var attacker_hits := DamageCalculator.calculate_attack_count(self, defender)
	# Only ELIGIBILITY (alive, usable damaging move) locks in up front. The
	# range half is checked live before every counter, because displacement
	# cuts both ways: a shove can deny a counter that was in range at planning,
	# and a pull (Grav Hook) can GRANT one to a defender that started out of
	# reach. `had_counter_range` remembers the planning-time verdict purely for
	# the out-of-range callout — a melee defender plinked by an archer three
	# tiles away just doesn't counter, silently, same as always.
	var defender_counter_eligible := DamageCalculator.is_counter_eligible(defender)
	var defender_had_counter_range := defender_counter_eligible \
			and DamageCalculator.is_within_attack_range(defender, self, defender.assigned_move)
	var defender_hits := 0
	if defender_counter_eligible:
		defender_hits = DamageCalculator.calculate_attack_count(defender, self)

	# The attacker pays PP up front. The defender pays at counter time instead:
	# displacement can shove either combatant out of range between hits (denying
	# the counter is knockback's tactical payoff), and a counter that never
	# fires shouldn't cost PP. One consume covers the whole counter chain.
	# Each side announces a range-denied follow-up at most once per combat.
	attacker_move.consume_use()
	var defender_counter_paid := false
	var attacker_denial_shown := false
	var defender_denial_shown := false

	# === Hit 1: Attacker ===
	await _execute_single_hit(defender, attacker_move, true, presenter)
	if defender.is_defeated():
		await defender._handle_defeat(presenter)
		return false

	# === Counter 1: Defender ===
	# Range checked at execution time, not planning — hit 1 may have displaced
	# someone, in either direction: shoved out (counter denied) or pulled in
	# (counter granted to a defender that started beyond reach).
	if defender_counter_eligible and not defender.is_defeated():
		if DamageCalculator.is_within_attack_range(defender, self, defender.assigned_move):
			defender.assigned_move.consume_use()
			defender_counter_paid = true
			await presenter.hold(HIT_DELAY)
			await defender._execute_single_hit(self, defender.assigned_move, true, presenter)
			if is_defeated():
				await _handle_defeat(presenter)
				return false
		elif defender_had_counter_range and not defender_denial_shown:
			defender_denial_shown = true
			await presenter.out_of_range(defender)

	# === Bonus attacker hits (2nd through Nth) ===
	# A knockback move's own shove can push the target out of reach mid-chain —
	# the remaining hits are forfeit, not teleporting lunges.
	for i: int in range(1, attacker_hits):
		if defender.is_defeated():
			break
		if not DamageCalculator.is_within_attack_range(self, defender, attacker_move):
			if not attacker_denial_shown:
				attacker_denial_shown = true
				await presenter.out_of_range(self)
			break
		await presenter.hold(HIT_DELAY)
		await _execute_single_hit(defender, attacker_move, false, presenter)

	if defender.is_defeated():
		await defender._handle_defeat(presenter)

	# === Bonus defender counters (2nd through Nth) ===
	if defender_counter_eligible:
		for i: int in range(1, defender_hits):
			if is_defeated() or defender.is_defeated():
				break
			if not DamageCalculator.is_within_attack_range(defender, self, defender.assigned_move):
				# Announce only when a counter was actually taken away — they
				# had range at planning or already landed counter 1 (a pulled-
				# in defender the bonus hits shoved back out again).
				if (defender_had_counter_range or defender_counter_paid) \
						and not defender_denial_shown:
					defender_denial_shown = true
					await presenter.out_of_range(defender)
				break
			if not defender_counter_paid:
				defender.assigned_move.consume_use()
				defender_counter_paid = true
			await presenter.hold(HIT_DELAY)
			await defender._execute_single_hit(self, defender.assigned_move, false, presenter)

	if is_defeated():
		await _handle_defeat(presenter)
	return true

## After combat, record what move `combatant` just used and (if they have a
## move-randomizer passive, i.e. Capricious) re-pick assigned_move from their
## remaining usable moves so their next combat — including counter-attacks from
## enemies later this turn — uses a different move. Skips silently for units
## without the capability and for defeated units.
func _capricious_post_combat_reroll(combatant: Unit) -> void:
	if combatant == null or combatant.is_defeated():
		return
	var data: CharacterData = combatant.character_data
	if data == null:
		return
	# Only move-randomizer passives (Capricious) reroll. Read from the handlers.
	var should_randomize: bool = false
	for handler: CombatEffect in PassiveRegistry.get_handlers_for(data, combatant):
		if handler.randomizes_move():
			should_randomize = true
			break
	if not should_randomize:
		return
	if combatant.assigned_move != null:
		combatant.last_used_move_index = data.equipped_moves.find(combatant.assigned_move)

	var usable_indices: Array[int] = []
	for index: int in range(data.equipped_moves.size()):
		var move: Move = data.equipped_moves[index]
		if move.has_uses_remaining() and not combatant.is_move_index_locked(index):
			usable_indices.append(index)

	# Prefer a move different from the one just used. If only one usable
	# move remains, keep the current assignment — Capricious can't conjure
	# variety out of nothing.
	var different: Array[int] = []
	for idx: int in usable_indices:
		if idx != combatant.last_used_move_index:
			different.append(idx)
	if different.is_empty():
		return
	var chosen: int = different[GameRng.randi() % different.size()]
	combatant.assigned_move = data.equipped_moves[chosen]


## Execute a single hit against a target. Calculates damage (or healing for
## support moves), optionally applies status effects, runs on-hit riders.
## Sequence: strike to contact → hitlag freeze → release + impact + damage
## + popup. Every visual moment is a `presenter` beat (see CombatPresenter);
## null means "whatever the map does" — direct callers (tests, the AoE
## pass's fallback) never need to care.
func _execute_single_hit(target: Unit, move: Move, apply_status: bool,
		presenter: CombatPresenter = null) -> void:
	if presenter == null:
		# A lone hit is not an exchange — never the scene (tests, AoE victims).
		presenter = MapPresenter.new()
	if move.heals:
		await _execute_heal_hit(target, move, apply_status, presenter)
		return
	if move.damage_type == Enums.DamageType.SUPPORT:
		await _execute_support_hit(target, move, apply_status, presenter)
		return

	# Hit roll. Miss path plays the approach but skips damage/flash/popup/status
	# so the swing reads as a swing-and-dodge rather than "nothing happened."
	# Move usage is NOT refunded on miss — RD style.
	var hit_pct := DamageCalculator.hit_chance_pct(self, target, move)
	if GameRng.randi() % 100 >= hit_pct:
		await presenter.miss(self, target, move)
		DebugConfig.log_combat("Miss: %s -> %s (hit %d%%)" % [unit_name, target.unit_name, hit_pct])
		return

	# Build the combat context + gather effect handlers, then run damage modifiers
	# (crit, etc.) so the final damage drives impact weight, the hit, and the
	# popup. Phase 0 has no damage-modifying handlers, so damage == base.
	var ctx := CombatHitContext.new()
	ctx.attacker = self
	ctx.defender = target
	ctx.move = move
	ctx.apply_status = apply_status
	ctx.presenter = presenter
	var effects := CombatEffectPipeline.gather(ctx)

	ctx.base_damage = DamageCalculator.calculate_damage(self, target, move)
	ctx.damage = ctx.base_damage
	CombatEffectPipeline.run_modify_damage(ctx, effects)
	var damage := ctx.damage

	var type_multiplier := DamageCalculator.get_type_effectiveness(self, target, move)
	var effectiveness_text := TypeChart.get_effectiveness_text(type_multiplier)
	var impact_weight := DamageCalculator.calculate_impact_weight(damage, target.character_data.max_hp if target.character_data else 1)

	# Crits hit harder — floor the impact so even a low-power crit gets a weighty
	# flash/shake/hitlag. The doubled damage already shows in the popup.
	if ctx.is_crit:
		impact_weight = maxf(impact_weight, 0.8)

	# Bellows-boosted swing (RQD 2026-08-21, todo #2A): announce the exact
	# multiplier over the attacker BEFORE the approach — the pips on the icon
	# are one pixel, and "obliterated on the next hit" needs a named cause.
	# Same number the calculator applied (one helper), element ink like the
	# AI's move-name callouts (this is "what's firing," not a warning), and a
	# warm hit flash + impact floor so the target side sells it too.
	var bellows_scale := DamageCalculator.bellows_multiplier(self, move)
	var hit_flash_tint := Color.TRANSPARENT
	if bellows_scale > 1.0:
		impact_weight = maxf(impact_weight, BELLOWS_IMPACT_FLOOR)
		hit_flash_tint = GameColorPalette.get_color("Orange", 7)
		presenter.callout(self, bellows_callout_text(bellows_scale),
				GameColors.get_move_chip_foreground(Enums.ElementalType.FIRE))

	# Phase 1: Approach — through the hit frame of a matching clip, or the
	# boop nudge when there is none. The presenter decides which.
	await presenter.strike_to_contact(self, target, move)

	# Phase 2: Hitlag — both units freeze at moment of contact
	var hitlag_duration := CombatPresenter.hitlag_seconds(impact_weight)
	await presenter.hold(hitlag_duration)

	# Phase 3: Snap back + hit flash + screenshake + damage (all fire together as hitlag releases)
	presenter.release_contact(self)
	presenter.impact(target, impact_weight, hit_flash_tint)

	target.take_damage(damage, {
		"element": move.element_type,
		"damage_type": move.damage_type,
		"name": move.move_name,
	})
	# RD-style XP grant: only player units accumulate XP. The kill check has
	# to read is_defeated AFTER take_damage but before _handle_defeat clears
	# state — both are fine at this point in the sequence.
	_award_combat_xp(target, target.is_defeated())
	combat_hit.emit(self, target, damage)

	presenter.show_damage(self, target, damage, effectiveness_text, type_multiplier)
	if ctx.is_crit:
		presenter.callout(self, "CRIT!", GameColors.TEXT_SECONDARY)

	DebugConfig.log_combat("Hit: %s -> %s for %d damage (x%.2f %s, bellows=x%.2f, impact=%.2f, hitlag=%.3fs)" % [
		unit_name, target.unit_name, damage, type_multiplier, effectiveness_text, bellows_scale, impact_weight, hitlag_duration])

	# On-hit rider effects (afflictions, cleanse, displacement) and per-hit passive
	# triggers (e.g. Bellows) run through the combat effect pipeline using the
	# handlers gathered above. Affliction applies on first hit only (apply_status);
	# cleanse, displacement, and passive triggers run every hit.
	await CombatEffectPipeline.run_on_hit(ctx, effects)

	# On-kill effects (e.g. Waste Not refunds the killer's move use) when this hit
	# defeated the target. Handlers gate on the relevant unit (killer = attacker).
	if target.is_defeated():
		CombatEffectPipeline.run_on_kill(ctx, effects)

## Heal-side counterpart to _execute_single_hit. No hit flash, no screenshake,
## no displacement. Heal amount = caster.special + move.base_power. The
## approach is a friendly nudge, never a swing — a healer with a melee clip
## must not slash the ally it's mending.
func _execute_heal_hit(target: Unit, move: Move, apply_status: bool,
		presenter: CombatPresenter) -> void:
	var heal_amount: int = DamageCalculator.calculate_heal_amount(self, target, move)

	await presenter.nudge_to_contact(self, target)
	# Brief beat for the heal to feel weighty without the full damage hitlag.
	await presenter.hold(CombatPresenter.HITLAG_MIN)
	presenter.release_contact(self)

	target.heal(heal_amount)
	_award_heal_xp(target, heal_amount)
	combat_hit.emit(self, target, -heal_amount)
	presenter.show_heal(self, target, heal_amount)

	DebugConfig.log_combat("Heal: %s -> %s for %d HP (move=%s)" % [
		unit_name, target.unit_name, heal_amount, move.move_name])

	# On-hit riders (affliction on first hit, cleanse every hit). Heals never
	# displace, so the pipeline omits displacement for is_heal contexts.
	var ctx := CombatHitContext.new()
	ctx.attacker = self
	ctx.defender = target
	ctx.move = move
	ctx.is_heal = true
	ctx.apply_status = apply_status
	ctx.presenter = presenter
	var effects := CombatEffectPipeline.gather(ctx)
	await CombatEffectPipeline.run_on_hit(ctx, effects)

## Support-side counterpart to _execute_single_hit for non-heal, non-damage
## applications (Fortify's buff, Roar's shout landing on a victim, Shriek's
## mark). Support moves auto-hit — no accuracy roll (their riders' own chance
## fields are the gate), no damage, no XP, no approach animation (the cast
## flourish or the primary combat beat already carried the motion). Everything
## lands through the pipeline so afflictions, conditionals, marks, cleanses,
## and support shoves use the same machinery as combat hits.
func _execute_support_hit(target: Unit, move: Move, apply_status: bool,
		presenter: CombatPresenter = null) -> void:
	var ctx := CombatHitContext.new()
	ctx.attacker = self
	ctx.defender = target
	ctx.move = move
	ctx.apply_status = apply_status
	ctx.is_support = true
	ctx.presenter = presenter
	var effects := CombatEffectPipeline.gather(ctx)
	DebugConfig.log_combat("Support: %s -> %s (move=%s)" % [
		unit_name, target.unit_name, move.move_name])
	await CombatEffectPipeline.run_on_hit(ctx, effects)


## The AoE pass: after the primary application, every OTHER unit inside the
## move's area (epicenter = the primary target's tile; for a self-cast, the
## caster's own tile) gets its own pipeline application. AoE victims never
## counter and never trigger multi-hit — that belongs to the primary exchange.
func _execute_area_applications(primary: Unit, move: Move, presenter: CombatPresenter) -> void:
	if move.area_of_effect <= 0:
		return
	var epicenter: Tile = primary.current_tile if primary != null else current_tile
	if epicenter == null:
		return
	for victim: Unit in MoveTargeting.get_area_victims(self, epicenter, move):
		if victim == primary:
			continue
		await _execute_single_hit(victim, move, true, presenter)
		if victim.is_defeated():
			await victim._handle_defeat(presenter)

## Does a SELF-cast of this move do anything to the caster themselves? Heals,
## flat statuses, cleanses, and displacement are self-directed on a self-cast;
## conditional statuses and scheduled effects on a self-cast AoE are for the
## VICTIMS (skipping the primary self application keeps Roar from shocking
## its own caster).
func _self_cast_has_self_payload(move: Move) -> bool:
	return move.heals \
			or move.status_effect_type != Enums.StatusEffectType.NONE \
			or not move.cleanse_effects.is_empty() \
			or move.displace_distance > 0


## Fear-cluster query — see CombatPredicates.is_brave (the one source of truth).
func is_brave() -> bool:
	return CombatPredicates.is_brave(self)


## Grant combat XP to this unit (the attacker) for a hit on `target`. Only
## fires for PLAYER faction — enemies don't level mid-mission. The kill flag
## is passed in by the caller since it knows whether THIS hit killed the
## target (a counter-killer wouldn't credit the original attacker).
##
## On level-up we refresh the level label + health bar so the visual reflects
## the new state immediately. The full level-up celebration runs at the end
## of mission via LevelUpReportPanel (uses SquadManager's pre-battle snapshot
## to detect the delta).
func _award_combat_xp(target: Unit, killed: bool) -> void:
	if faction != Enums.UnitFaction.PLAYER:
		return
	if character_data == null or target == null or target.character_data == null:
		return
	var xp: int = CombatXpCalculator.compute_combat_xp(
			character_data, target.character_data, killed)
	_grant_combat_xp(xp)


## Heal-side XP grant. RD awards a flat amount per cast regardless of HP
## restored — passing `amount` so we can switch to fraction-of-max scaling
## later without changing call sites.
func _award_heal_xp(target: Unit, amount: int) -> void:
	if faction != Enums.UnitFaction.PLAYER:
		return
	if character_data == null or amount <= 0:
		return
	var target_data: CharacterData = target.character_data if target != null else null
	_grant_combat_xp(CombatXpCalculator.compute_heal_xp(character_data, target_data))


## Support-cast XP grant (buffs, cleanses, shouts — the non-heal friendly
## casts that used to pay nothing). Once per cast; called from the friendly
## branch of execute_combat_sequence.
func _award_support_xp(move: Move) -> void:
	if faction != Enums.UnitFaction.PLAYER or character_data == null:
		return
	_grant_combat_xp(CombatXpCalculator.compute_support_xp(character_data, move))


## Survival XP: awarded to a player unit that lived through an enemy's
## offensive combat sequence — tanked or dodged, surviving is the lesson.
## Pays only on the FIRST engagement from each attacker per battle, so
## stalling next to a harmless enemy pays ~1 XP once and then never again
## (the doctrine's north star: don't incentivize stalling).
func _award_survival_xp(attacker: Unit) -> void:
	if faction != Enums.UnitFaction.PLAYER or character_data == null:
		return
	if attacker == null or attacker.faction != Enums.UnitFaction.ENEMY:
		return
	if is_defeated():
		return
	var source_id: int = attacker.get_instance_id()
	if _survival_xp_sources.has(source_id):
		return
	_survival_xp_sources[source_id] = true
	_grant_combat_xp(CombatXpCalculator.compute_survival_xp(
			character_data, attacker.character_data))


## The one funnel every XP award flows through. Banks into the character,
## accumulates for the end-of-combat "+N XP" callout, and refreshes the
## on-map labels when a level fires. Callers have already faction-guarded.
##
## The pre-grant snapshot feeds the mid-battle celebration: growth rolls
## happen inside grant_xp, so the "what grew" diff has to be captured here.
## First snapshot of the sequence wins — a double level-up in one combat
## shows its total growth against where the unit STARTED.
func _grant_combat_xp(xp: int) -> void:
	if xp <= 0:
		return
	if _xp_before_sequence < 0:
		_xp_before_sequence = character_data.experience
	_combat_xp_gained += xp
	var snapshot: Dictionary = LevelUpStatPanel.stat_snapshot(character_data)
	var levels_gained: int = character_data.grant_xp(xp)
	if levels_gained > 0:
		if _level_up_snapshot.is_empty():
			_level_up_snapshot = snapshot
		_combat_levels_gained += levels_gained
		_update_level_label()
		_update_health_bar()


## End-of-combat XP feedback: one gold "+N XP" callout for everything earned
## this sequence (hits, kills, heals, support, survival — batched so a 4-hit
## chain doesn't spam four popups), then LEVEL UP! on a beat of its own,
## then the LevelUpStatPanel stat reveal (RQD 2026-08-11 — the in-the-moment
## dopamine beat; LevelUpReportPanel keeps the end-of-mission aggregate).
## The panel is awaited, so the turn flow holds while the reveal plays.
func _flush_xp_feedback() -> void:
	if _combat_xp_gained <= 0:
		return
	spawn_text_callout("+%d XP" % _combat_xp_gained, GameColorPalette.get_color("Yellow", 7))
	# The on-map bar sweeps alongside the callout (not awaited — it has its own
	# pacing and must not hold the turn). Every grant goes through
	# _grant_combat_xp, which opens the sequence, so the snapshot is always set.
	assert(_xp_before_sequence >= 0, "XP was banked without _grant_combat_xp opening the sequence")
	_play_xp_bar(maxi(_xp_before_sequence, 0), character_data.experience, _combat_levels_gained)
	_xp_before_sequence = -1
	if _combat_levels_gained > 0 and is_inside_tree():
		await get_tree().create_timer(0.5).timeout
		spawn_text_callout("LEVEL UP!", GameColorPalette.get_color("Yellow", 8))
		if not _level_up_snapshot.is_empty():
			await UIManager.show_level_up_celebration(character_data, _level_up_snapshot)
	_combat_xp_gained = 0
	_combat_levels_gained = 0
	_level_up_snapshot = {}


## Delta from self to target in tile coords (public — MapPresenter mirrors the
## clip on its sign). Falls back to global_position
## divided by tile size if either unit isn't on a tile yet.
func attack_delta_tiles(target: Unit) -> Vector2i:
	if current_tile != null and target != null and target.current_tile != null:
		return Vector2i(target.current_tile.grid_x - current_tile.grid_x,
				target.current_tile.grid_y - current_tile.grid_y)
	if target == null:
		return Vector2i.ZERO
	var dp := target.global_position - global_position
	var tile_px: float = float(GridManager.tile_size)  # 32 on registered battle maps
	return Vector2i(roundi(dp.x / tile_px), roundi(dp.y / tile_px))


## Move this unit to the end of its sibling list so it draws on top of any
## same-z_index neighbor during the attack. Same-row units share z_index
## (computed as `(99 - row_index) * 10 + UNITS_layer`), so without this
## tie-break the render order is determined by spawn sequence — which makes
## the attacker render behind the defender about half the time.
##
## Why tree reorder and not a z_index bump:
##   A z_index bump (e.g., attacker.z += 1) would land at a value where
##   other units' FX (status icons, etc.) may already live, introducing
##   new ties at +1. Sibling reorder only resolves the EXISTING tie at the
##   unit's own z, without touching any z values.
##
## Refcounted: chained multi-hits raise multiple times before any tail
## lowers. First raise stashes the original index; subsequent raises just
## bump the count (and re-pin to end-of-siblings, which is a no-op when
## already there). Each raise must be paired with exactly one lower.
func _raise_for_attack() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	if _attack_raise_count == 0:
		_attack_raised_original_index = get_index()
	_attack_raise_count += 1
	parent_node.move_child(self, parent_node.get_child_count() - 1)


## Decrement the raise refcount. Only restores the sibling position when
## the count returns to zero, so a chained Hit 2's raise keeps the attacker
## on top while Hit 1's tail is still running. Clamps the target index in
## case siblings were added/removed during the attack (defensive — turn-
## based combat doesn't normally spawn/despawn units mid-clip).
func _lower_after_attack() -> void:
	if _attack_raise_count == 0:
		return
	_attack_raise_count -= 1
	if _attack_raise_count > 0:
		return
	if _attack_raised_original_index == -1:
		return
	var parent_node := get_parent()
	if parent_node != null:
		var target_idx: int = mini(_attack_raised_original_index, parent_node.get_child_count() - 1)
		parent_node.move_child(self, target_idx)
	_attack_raised_original_index = -1


## Attach a popup where it can live: the current scene normally, this unit's
## parent when there is no current scene (headless tests, detached contexts).
## Freed unspawned if neither exists. Position MUST be set before add_child:
## DamagePopup._ready anchors its rise animation to the position it wakes up
## with — positioned after, every popup snaps to the host's origin on the next
## frame (the center-screen-popups regression, RQD 2026-08-01).
## Returns false when there was nowhere to host the popup (out-of-tree bare
## test units) — the popup is already freed, so callers must NOT touch it.
func _host_popup(popup: Node2D, at_global: Vector2) -> bool:
	# is_inside_tree() first: get_tree() on an out-of-tree node LOGS an engine
	# error even though it returns null.
	var host: Node = get_tree().current_scene if is_inside_tree() else null
	if host == null:
		host = get_parent()
	if host == null:
		# free(), not queue_free(): with no tree there's nothing to defer to.
		popup.free()
		return false
	popup.global_position = at_global
	host.add_child(popup)
	return true


func _spawn_damage_popup(target: Unit, damage: int, effectiveness_text: String, multiplier: float) -> void:
	var popup_scene := preload("res://scenes/ui/damage_popup.tscn")
	var popup: Node2D = popup_scene.instantiate()
	popup.z_index = target.z_index + 2  # UNITS layer + 2 = UI layer, always above defending unit
	if not _host_popup(popup, target.global_position + Vector2(0, -8)):
		return
	if popup.has_method("initialize"):
		popup.call("initialize", damage, effectiveness_text, multiplier)


func _spawn_heal_popup(target: Unit, amount: int) -> void:
	var popup_scene := preload("res://scenes/ui/damage_popup.tscn")
	var popup: Node2D = popup_scene.instantiate()
	popup.z_index = target.z_index + 2
	if not _host_popup(popup, target.global_position + Vector2(0, -8)):
		return
	if popup.has_method("initialize_heal"):
		popup.call("initialize_heal", amount)


## Float a text callout above THIS unit (e.g. "BACKHAND" when an enemy
## commits to an attack so the player knows what's about to land). Spawned
## higher than damage popups so they can stack without overlap.
func spawn_text_callout(text: String, color: Color) -> void:
	var popup_scene := preload("res://scenes/ui/damage_popup.tscn")
	var popup: Node2D = popup_scene.instantiate()
	popup.z_index = z_index + 2
	if not _host_popup(popup, global_position + Vector2(0, -20)):
		return
	if popup.has_method("initialize_callout"):
		popup.call("initialize_callout", text, color)


## Handle unit defeat: flip the flags, play the death (through `presenter`
## when an exchange owns the moment, else the map's own fade), clear the
## tile. The LOGIC half is unconditional — a RecordingPresenter that draws
## nothing still leaves a correctly dead unit. Self-guards against a double
## play (combat and displacement can both discover the same corpse).
func _handle_defeat(presenter: CombatPresenter = null) -> void:
	if _defeat_visuals_played:
		return
	_defeat_visuals_played = true
	is_defeated_flag = true
	DebugConfig.log_combat("Unit defeated: %s" % unit_name)

	# Stop any selection effects
	_stop_selection_pulse()

	if presenter != null:
		await presenter.death(self)
	else:
		await play_defeat_visuals()

	# Clear tile occupancy
	if current_tile != null:
		current_tile.clear_unit()
		current_tile = null

# =============================================================================
# VISUAL HELPERS
# =============================================================================

## The map's death: gray out, hide the bars, fade over a second. Awaitable.
## MapPresenter.death routes here; callers outside an exchange
## (DisplacementSystem collateral, ScheduledEffects, the cheat kill) reach
## it through _handle_defeat.
func play_defeat_visuals() -> void:
	if _sprite != null:
		_sprite.modulate = Color(0.4, 0.4, 0.4, 1.0)
	if _health_bar_background != null:
		_health_bar_background.visible = false
	if _health_bar_fill != null:
		_health_bar_fill.visible = false
	if _status_indicator != null:
		_status_indicator.visible = false
	if _xp_bar != null:
		_xp_bar.visible = false
	if _level_label != null:
		_level_label.visible = false
	for icon: Sprite2D in _type_icons:
		icon.visible = false

	# Fade out over 1 second (tweens need the tree; bare test units skip the fade)
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 1.0)
		await tween.finished


## Load the character's sprite from an Aseprite atlas spritesheet.
## Falls back to the placeholder texture if no sprite data is configured.
func _load_character_sprite() -> void:
	if _sprite == null or character_data == null:
		return
	_art_feet_drop = 0.0
	if character_data.sprite_sheet_path == "":
		return

	# Atlas-less single-frame PNG (e.g. programmer-art idle.png) — load directly.
	# If a pivot sidecar JSON exists next to the PNG (emitted by the aseprite
	# tag exporter when the .aseprite file has a slice with pivot), use it to
	# anchor the sprite. Otherwise fall back to feet-at-tile-center.
	if character_data.sprite_atlas_path == "":
		var raw_texture: Texture2D = load(character_data.sprite_sheet_path) as Texture2D
		if raw_texture == null:
			return
		_sprite.texture = raw_texture
		_sprite.offset = _resolve_pivot_offset(character_data.sprite_sheet_path, raw_texture)
		return

	var atlas_texture := SpriteAtlasLoader.get_frame_texture(
		character_data.sprite_sheet_path,
		character_data.sprite_atlas_path,
		character_data.sprite_frame_index)
	if atlas_texture == null:
		return

	_sprite.texture = atlas_texture

	# Apply trim offset so the sprite aligns correctly with tile center.
	var trim_offset := SpriteAtlasLoader.get_frame_offset(
		character_data.sprite_atlas_path,
		character_data.sprite_frame_index)
	_sprite.offset = trim_offset

	# Feet line for the cast shadow. Atlas frames carry no pivot sidecar, but
	# Aseprite's trim rect IS the art bounds — its bottom edge is the lowest
	# opaque row, sitting trim_offset.y + frame_height/2 below the node
	# origin. Same gap the sidecar's art_bounds.bottom − pivot.y yields for
	# per-character exports. Without this every atlas character cast from the
	# waist — the floating mid-body smear (RQD 2026-08-03, found on the
	# then-"Blood Mage", now the sidecar'd Keener).
	_art_feet_drop = maxf(0.0, trim_offset.y + atlas_texture.get_height() / 2.0)


## Resolve the Sprite2D.offset for an atlas-less PNG. Reads a sidecar JSON
## (same path with .json extension) emitted by the Aseprite tag exporter when
## the source .aseprite file has a slice with pivot. Pivot coords are in
## pixel-corner space relative to the canvas top-left. Falls back to
## feet-at-tile-center for sprites without a sidecar.
func _resolve_pivot_offset(sheet_path: String, texture: Texture2D) -> Vector2:
	# Shared with CombatPuppet so the stage stands a unit exactly like the map.
	var sidecar: Dictionary = SpriteSidecar.read(sheet_path, texture)
	_art_top = sidecar["art_top"]
	if sidecar["has_pivot"]:
		_art_feet_drop = sidecar["feet_drop"]
	return sidecar["offset"]


## One-time font + outline-shader setup for the level number. Pulled out so
## `_ready` can run it before initialize() — we don't depend on character_data
## here. The label's text is empty until _update_level_label fills it.
func _style_level_label() -> void:
	if _level_label == null:
		return
	var ui_manager: Node = UIManager
	if ui_manager != null:
		_level_label.add_theme_font_override("font", ui_manager.font_5px)
		_level_label.add_theme_font_size_override("font_size", 5)
	# Orthogonal glow shader as outline so the number reads against any
	# terrain. Same material as damage popups for visual consistency.
	var outline_color: Color = Color(GameColorPalette.get_color("Gray", 1), 0.975)
	var material_instance: ShaderMaterial = preload("res://resources/hud_glow.tres").duplicate()
	material_instance.set_shader_parameter("glow_color", outline_color)
	_level_label.material = material_instance


## Refreshes the level number from character_data.level. Cheap — call any time
## the unit's level changes (currently only at spawn; bEXP-driven mid-prep
## levels happen on the intermission screens, not in-battle).
func _update_level_label() -> void:
	if _level_label == null or character_data == null:
		return
	_level_label.text = "%d" % character_data.level


const _TYPE_ICON_DIRECTORY: String = "res://art/sprites/ui/elemental_type_icons_10x10/"
# First icon center sits 6px past the bar's right edge (bar half-width 12 + 6);
# a second (dual-type) icon follows with a 1px gap.
const _TYPE_ICON_START_X: float = 18.0
const _TYPE_ICON_SPACING: float = 11.0


## Rebuilds the elemental type icon(s) to the right of the health bar — the
## in-world mirror of the level number on the left, so typing is readable
## without opening a panel. Opt-in via Settings.unit_type_icons_enabled
## (default off — playtest found it noisy). Uses effective_* types
## (Crystallization strips them) and skips types with no icon on disk
## (e.g. new types pending art).
func _update_type_icons() -> void:
	for icon: Sprite2D in _type_icons:
		icon.queue_free()
	_type_icons.clear()
	if not Settings.unit_type_icons_enabled:
		return
	if _health_bar == null or character_data == null or is_defeated_flag:
		return
	var types: Array[Enums.ElementalType] = [
		character_data.effective_primary_type(),
		character_data.effective_secondary_type(),
	]
	var slot: int = 0
	for element_type: Enums.ElementalType in types:
		if element_type == Enums.ElementalType.NONE:
			continue
		var icon_path: String = _TYPE_ICON_DIRECTORY \
				+ Enums.elemental_type_to_string(element_type).to_lower() + ".png"
		if not ResourceLoader.exists(icon_path):
			continue
		var sprite := Sprite2D.new()
		sprite.texture = load(icon_path)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(_TYPE_ICON_START_X + slot * _TYPE_ICON_SPACING, 0.0)
		_health_bar.add_child(sprite)
		_type_icons.append(sprite)
		slot += 1


## Set health bar fill to faction color. Background stays dark for contrast.
func _apply_faction_healthbar() -> void:
	if _health_bar_background == null or _health_bar_fill == null:
		return
	_health_bar_background.color = GameColors.UNIT_BAR_BACKGROUND
	match faction:
		Enums.UnitFaction.PLAYER:
			_health_bar_fill.color = GameColors.FACTION_HEALTHBAR_PLAYER
		Enums.UnitFaction.ENEMY:
			_health_bar_fill.color = GameColors.FACTION_HEALTHBAR_ENEMY
		Enums.UnitFaction.ALLY:
			_health_bar_fill.color = GameColors.FACTION_HEALTHBAR_ALLY
		Enums.UnitFaction.NEUTRAL:
			_health_bar_fill.color = GameColors.FACTION_HEALTHBAR_NEUTRAL


## Position the health bar just above the topmost pixel of the sprite.
## Status icons sit above the health bar (anchored to it), so they move together.
func _update_healthbar_position() -> void:
	if _health_bar == null or _sprite == null or _sprite.texture == null:
		return
	# Texture top in sprite-local coords, then shift down by the transparent
	# padding above the visible art so the bar sits above the unit, not above
	# the canvas. _art_top is 0 for atlas-trimmed sprites (no sidecar) — the
	# old behavior is preserved in that case.
	var sprite_top := _sprite.offset.y - _sprite.texture.get_height() / 2.0 + _art_top
	_health_bar.position.y = sprite_top - 3.0


## Called when any status effect is applied or removed on any unit.
func _on_status_effect_changed(unit: Node2D, _effect_type_name: String) -> void:
	if unit != self:
		return
	_update_status_indicators()


## Applied (new OR restacked — StatusEffectSystem emits for both): refresh the
## icons like a removal would, then SAY it. Every status used to land
## silently except for a 6x6 icon + 1px pips (RQD 2026-08-21, todo #2A:
## "I unknowingly activated the enemy's Bellows"). Generic on purpose — one
## rule for all 19 statuses, not a Bellows special case.
func _on_status_effect_applied(unit: Node2D, effect_type_name: String) -> void:
	if unit != self:
		return
	_update_status_indicators()
	_announce_status_applied(effect_type_name)


## Float the status's name over the unit in its category's semantic ink —
## buffs in the success green, debuffs in the danger red (ui-style-guide §3
## pairings). NOT element ink: the AI floats MOVE NAMES in element color, and
## "BELLOWS" in fire-orange would read as an attack announcement. A restack
## counts up ("BURN x2") so stacking statuses show their growth; the first
## application is just the name. The icon pops in the same beat.
func _announce_status_applied(effect_type_name: String) -> void:
	var configs := StatusEffectData.get_default_configs()
	var config: StatusEffectData = configs.get(effect_type_name, null)
	var stacks: int = StatusEffectSystem.get_effect_stacks(self, effect_type_name)
	var label: String = config.abbrev_name if config != null else effect_type_name.capitalize()
	var is_buff: bool = config != null and config.category == Enums.EffectCategory.BUFF
	spawn_text_callout(status_callout_text(label, stacks),
			GameColors.TEXT_SUCCESS if is_buff else GameColors.TEXT_DANGER)
	if _status_indicator != null:
		_status_indicator.pop_icon(effect_type_name)


## "BURN" on first application, "BURN x2" on a restack — pure, for tests.
static func status_callout_text(abbrev_name: String, stacks: int) -> String:
	var text := abbrev_name.to_upper()
	if stacks > 1:
		text += " ×%d" % stacks
	return text


## "BELLOWS ×1.25" / "×1.5" / "×2" — trailing zeros trimmed so the number
## reads like a multiplier, not a stat readout (String.num keeps "2.0"). Pure,
## for tests.
static func bellows_callout_text(multiplier: float) -> String:
	var number := ("%.2f" % multiplier).rstrip("0").rstrip(".")
	return "BELLOWS ×%s" % number


## Rebuild the status icon row and adjust health bar position.
func _update_status_indicators() -> void:
	if _status_indicator == null:
		return
	_status_indicator.update_icons(active_status_effects)
	# Position icons above the health bar — pip bars overlap health bar top pixel
	_status_indicator.position.y = -5.0
	_update_healthbar_position()


## Debug: randomly equip 1-4 passives from passives.json.
## Prefers the character's base pool; fills remaining slots from the full JSON pool.
## The displacement test kit (DebugConfig.testing_displacement_moves): every
## subject, vector family, and on_blocked policy across two 4-move windows.
## Units take rotating windows of 4, so unit 1 gets the target-shove pack and
## unit 2 the exotics; unit 3 wraps around.
const DEBUG_DISPLACEMENT_KIT: Array[String] = [
	"Bounce Out",      # target push 2 + constitution contest + wall-slam bonus damage
	"Grav Hook",       # ranged pull (toward_attacker)
	"Mass Drive",      # push_chain domino
	"Shockwave",       # row(3) wave push
	"Compressed Air",  # self recoil (ranged, Hasted rider)
	"Slingshot",       # fall_through — sails clean over bystanders
	"Orbit",           # ring(1) rotate_cw spin around the target
	"Switcheroo",      # self charge + swap places with the target
]

## The Phase 4 test kit (DebugConfig.testing_phase4_moves): window 1 is the
## fear cluster loop — roar them, shriek them, defuse the mark, patch up;
## window 2 is the revived self-cast buffs (unreachable before the SELF
## targeting fix). Roar's CHALLENGED branch needs a brave enemy on the field
## (knight, buglers, ogre_squire, pierre) to show its teeth.
const DEBUG_PHASE4_KIT: Array[String] = [
	"Roar",                  # self AoE 2 — SHOCKED, or CHALLENGED on the brave
	"Shriek of the Damned",  # self AoE 5 — delayed chain-lightning marks
	"Steady",                # ally cleanse — defuses marks, settles SHOCKED
	"First Aid",             # ally heal (splash damage patch-up)
	"Focus",                 # self: banks a crit
	"Fortify",               # self: Fortified
	"Battle Cry",            # self: Rallied
	"Bloom",                 # self: Regen
]

static var _debug_kit_cursor: int = 0


## Debug: replace this player unit's equipped moves with the next 4-move window
## of the given kit. Mutates character_data.equipped_moves — in a campaign the
## squad keeps the kit until re-equipped, so this is meant for F6 battle-scene
## runs (fresh spawns every launch).
func _apply_debug_kit_moves(kit: Array[String]) -> void:
	if character_data == null:
		return
	var equipped: Array[Move] = []
	for i: int in range(4):
		var kit_index: int = (Unit._debug_kit_cursor + i) % kit.size()
		var move: Move = MoveData.get_move(kit[kit_index])
		if move != null:
			equipped.append(move)
	if equipped.is_empty():
		return
	Unit._debug_kit_cursor = (Unit._debug_kit_cursor + 4) % kit.size()
	character_data.equipped_moves = equipped
	auto_assign_first_usable_move()
	var names: Array[String] = []
	for move: Move in equipped:
		names.append(move.move_name)
	DebugConfig.log_unit_init("Debug move kit for '%s': %s" % [unit_name, str(names)])


func _apply_random_debug_passives() -> void:
	if character_data == null:
		return
	var all_passives := _load_passive_names_from_json()
	if all_passives.is_empty():
		return
	var pool: Array[String] = character_data.base_pool_passives.duplicate()
	if pool.is_empty():
		pool = all_passives.duplicate()
	pool.shuffle()
	var count := randi_range(1, mini(4, pool.size()))
	character_data.equipped_passives.clear()
	for i: int in range(count):
		character_data.equipped_passives.append(pool[i])
	DebugConfig.log_unit_init("Debug passives for '%s': %s" % [unit_name, str(character_data.equipped_passives)])


static var _cached_passive_names: Array[String] = []

static func _load_passive_names_from_json() -> Array[String]:
	if not _cached_passive_names.is_empty():
		return _cached_passive_names
	var file := FileAccess.open("res://data/passives.json", FileAccess.READ)
	if file == null:
		return _cached_passive_names
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return _cached_passive_names
	var data: Dictionary = json.data as Dictionary
	for key: String in data.keys():
		_cached_passive_names.append(key)
	return _cached_passive_names


## Debug: assign 1-4 random status effects to this unit for visual testing.
## First unit always gets 4 to ensure max-icon layout is visible.
static var _debug_status_unit_count: int = 0

func _apply_random_debug_status_effects() -> void:
	var configs := StatusEffectData.get_default_configs()
	var all_types: Array = configs.keys()
	all_types.shuffle()
	# Under the 1-buff/1-debuff slot model, the system rejects more than one effect
	# per category. We just attempt 4 random effects and let the system enforce slots.
	var count: int = mini(4, all_types.size())
	for i: int in range(count):
		StatusEffectSystem.apply_status_effect_by_name(null, self, all_types[i])
	_debug_status_unit_count += 1


## Debug: slap 1-4 stacks of VOID (the real max) on the unit so the void-lock FX +
## the move/passive-inert mechanic can be eyeballed on every spawn (players AND
## enemies). replace_existing so it lands even if another debuff already holds the
## lone debuff slot.
func _apply_debug_void_lock() -> void:
	var stacks: int = randi_range(1, 4)
	StatusEffectSystem.apply_status_effect_by_name(null, self, "VOID", stacks, true)
	DebugConfig.log_unit_init("Debug VOID lock on '%s': %d stack(s)" % [unit_name, stacks])


## Debug: directly inject 0-4 random injuries into character_data.current_injuries.
## Bypasses the normal queue/commit pipeline so we can see UI states without dying.
## Severity weighted 70% Minor / 30% Major. Stops adding once slot capacity (4) would overflow.
func _apply_random_debug_injuries() -> void:
	if character_data == null:
		return
	character_data.current_injuries.clear()
	var all_injuries: Array[InjuryData] = InjuryDatabase.get_all_injuries()
	if all_injuries.is_empty():
		return
	all_injuries.shuffle()
	var target_count: int = randi_range(0, 4)
	var added: int = 0
	for data: InjuryData in all_injuries:
		if added >= target_count:
			break
		var severity: Enums.InjurySeverity = Enums.InjurySeverity.MAJOR if randf() < 0.3 else Enums.InjurySeverity.MINOR
		var slots: int = 2 if severity == Enums.InjurySeverity.MAJOR else 1
		if not character_data.can_accept_injury(slots):
			continue
		var injury: Injury = InjurySystem.build_injury(data, severity)
		character_data.current_injuries.append(injury)
		added += 1
	InjurySystem.recalculate_injury_modifiers(character_data)
	DebugConfig.log_unit_init("Debug injuries on '%s': %d injuries (%d slots used)" % [
		unit_name, character_data.current_injuries.size(), character_data.injury_slots_used()])


func _apply_debug_hypoesthesia() -> void:
	if character_data == null:
		return
	var data: InjuryData = InjuryDatabase.get_injury_by_id("hypoesthesia")
	if data == null:
		return
	if not character_data.can_accept_injury(1):
		return
	for entry: Injury in character_data.current_injuries:
		if entry.injury_id == "hypoesthesia":
			return
	var severity: Enums.InjurySeverity = Enums.InjurySeverity.MAJOR if DebugConfig.testing_hypoesthesia_major else Enums.InjurySeverity.MINOR
	var injury: Injury = InjurySystem.build_injury(data, severity)
	character_data.current_injuries.append(injury)
	InjurySystem.recalculate_injury_modifiers(character_data)


## Reset sprite modulate to full color (active unit).
func _apply_active_modulate() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color.WHITE


## Darken and desaturate sprite to show the unit has acted.
func _apply_acted_modulate() -> void:
	if _sprite == null:
		return
	match faction:
		Enums.UnitFaction.PLAYER:
			_sprite.modulate = GameColors.PLAYER_UNIT_ACTED
		Enums.UnitFaction.ENEMY:
			_sprite.modulate = GameColors.ENEMY_UNIT_ACTED
		Enums.UnitFaction.ALLY:
			_sprite.modulate = GameColors.ALLY_UNIT_ACTED
		_:
			_sprite.modulate = Color(0.5, 0.5, 0.5, 1.0)


func _update_z_index() -> void:
	if current_tile == null:
		return
	_update_z_index_for_row(current_tile.grid_y)


## Calculate z-index from grid coordinates directly (not pixel position) to
## avoid the pixel-space mismatch in GridZIndexHandler. Split from
## _update_z_index so the ACT_THEN_WALK deferred walk can restamp z per row
## the SPRITE is passing — current_tile already sits at the destination then.
func _update_z_index_for_row(grid_y: int) -> void:
	var grid_manager: Node = get_node_or_null("/root/GridManager")
	if grid_manager == null:
		return
	var offset_y: int = grid_manager.grid_offset_y
	var row_index: int = grid_y - offset_y  # Front row (lowest grid_y) → index 0 (highest z)
	z_index = ZIndexCalculator.calculate_sorting_order(row_index, 100, ZIndexCalculator.ZIndexLayer.UNITS)
