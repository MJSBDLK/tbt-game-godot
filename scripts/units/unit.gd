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
const HIT_DELAY: float = 0.3  # Seconds between combat hits
const BOOP_DISTANCE: float = 8.0  # Pixels the sprite bumps toward target during attack
const HITLAG_MIN: float = 0.05  # Minimum freeze on any hit (seconds)
const HITLAG_MAX: float = 0.25  # Maximum freeze on a devastating hit (seconds)
const ATTACK_CLIP_DEFAULT_FPS: int = 12  # Fallback when a clip omits "fps"

# When true, an attack that isn't a due north/south (vertical) shot uses the
# horizontal (east/west) clip instead of falling back to the boop nudge — so a
# diagonal attack shows the side-swing, mirrored by flip_h on delta.x's sign
# (NE flips east, NW stays west). Range then matches on Chebyshev (ring)
# distance so a diagonally-adjacent target still reads as range 1 and picks the
# melee clip, not the ranged one. Flip to false to restore strict matching
# (horizontal clips only for a due east/west delta; diagonals boop). See
# _select_attack_clip.
const DIAGONAL_USES_SIDE_ANIMATION: bool = true


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

# XP earned during the current combat sequence, batched into ONE "+N XP"
# callout when it ends (per-hit popups would spam a 4-hit chain). Flushed by
# _flush_xp_feedback; levels ride along for the LEVEL UP! callout.
var _combat_xp_gained: int = 0
var _combat_levels_gained: int = 0

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

# Bumped every time a new attack clip starts. Pending coroutines that finish
# the tail of the previous clip check this before mutating region_rect, so a
# fresh clip can't be corrupted by a stale "after hit" continuation.
var _attack_clip_generation: int = 0

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
# actually restores tree position when the count returns to zero. Bail
# paths in clip playback also call lower to keep the count balanced.
var _attack_raised_original_index: int = -1
var _attack_raise_count: int = 0

# Child node references
var _sprite: Sprite2D = null
var _shadow: UnitShadow = null
var _health_bar: Node2D = null
var _health_bar_background: ColorRect = null
var _health_bar_fill: ColorRect = null
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
	_health_bar = $HealthBar as Node2D
	_health_bar_background = $HealthBar/Background as ColorRect
	_health_bar_fill = $HealthBar/Fill as ColorRect
	_status_indicator = $HealthBar/StatusEffectIndicator as StatusEffectIndicator
	_level_label = $HealthBar/LevelLabel as Label
	_style_level_label()
	if has_node("PathVisualizer"):
		_path_visualizer = $PathVisualizer
	_build_static_overlay()
	set_process(true)
	StatusEffectSystem.status_effect_applied.connect(_on_status_effect_changed)
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
	is_moving = true
	movement_started.emit(self)

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


func cancel_movement() -> void:
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
	if current_tile != null and current_tile.current_unit == self:
		current_tile.clear_unit()
	current_tile = new_tile
	if current_tile != null:
		if current_tile.current_unit == null:
			current_tile.set_unit(self)
		elif current_tile.current_unit != self:
			push_warning("Unit '%s' told to move_to_tile [%d,%d] already occupied by '%s'" % [
				unit_name, current_tile.grid_x, current_tile.grid_y, current_tile.current_unit.unit_name])
		global_position = current_tile.global_position
	_update_z_index()


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
# =============================================================================

## Execute a full combat sequence: attacker hits, counter-attacks, bonus hits.
## This is an async method — caller must await it.
func execute_combat_sequence(defender: Unit, attacker_move: Move) -> void:
	if defender == null or attacker_move == null:
		return

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

	combat_started.emit(self, defender)
	# Count this move use for the turn (Impetuous reads it). Counters go through
	# _execute_single_hit, not here, so they don't count.
	attacks_this_turn += 1
	DebugConfig.log_combat("Combat: %s (move=%s) vs %s" % [unit_name, attacker_move.move_name, defender.unit_name])

	# Friendly casts (heals, buffs, self-target support): single application, no
	# counter, no multi-hit. A self-cast whose payload is entirely for OTHERS
	# (Roar's shout, Shriek's mark — nothing self-directed) skips the primary
	# self application; the cast flourish + AoE pass below ARE the move.
	if is_ally_move:
		attacker_move.consume_use()
		if defender != self or _self_cast_has_self_payload(attacker_move):
			await _execute_single_hit(defender, attacker_move, true)
		else:
			await _play_support_cast_flourish(attacker_move)
		await _execute_area_applications(defender, attacker_move)
		# Non-heal support casts pay flat XP once per CAST (a 5-victim Roar is
		# one cast, not five awards). Heals award inside _execute_heal_hit —
		# skipping them here prevents a double grant. No meaningful-effect
		# check needed at this point: has_meaningful_effect_on gates targeting
		# (chip greyed, tile invalid), so a cast that executed is a cast that
		# mattered — and re-checking NOW would wrongly fail, since the buff has
		# already landed and the target reads as "already buffed."
		if not attacker_move.heals:
			_award_support_xp(attacker_move)
		await _flush_xp_feedback()
		combat_completed.emit(self, defender)
		return

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
	await _execute_single_hit(defender, attacker_move, true)
	if defender.is_defeated():
		await defender._handle_defeat()
		combat_completed.emit(self, defender)
		return

	# === Counter 1: Defender ===
	# Range checked at execution time, not planning — hit 1 may have displaced
	# someone, in either direction: shoved out (counter denied) or pulled in
	# (counter granted to a defender that started beyond reach).
	if defender_counter_eligible and not defender.is_defeated():
		if DamageCalculator.is_within_attack_range(defender, self, defender.assigned_move):
			defender.assigned_move.consume_use()
			defender_counter_paid = true
			await get_tree().create_timer(HIT_DELAY).timeout
			await defender._execute_single_hit(self, defender.assigned_move, true)
			if is_defeated():
				await _handle_defeat()
				combat_completed.emit(self, defender)
				return
		elif defender_had_counter_range and not defender_denial_shown:
			defender_denial_shown = true
			await defender._announce_out_of_range()

	# === Bonus attacker hits (2nd through Nth) ===
	# A knockback move's own shove can push the target out of reach mid-chain —
	# the remaining hits are forfeit, not teleporting lunges.
	for i: int in range(1, attacker_hits):
		if defender.is_defeated():
			break
		if not DamageCalculator.is_within_attack_range(self, defender, attacker_move):
			if not attacker_denial_shown:
				attacker_denial_shown = true
				await _announce_out_of_range()
			break
		await get_tree().create_timer(HIT_DELAY).timeout
		await _execute_single_hit(defender, attacker_move, false)

	if defender.is_defeated():
		await defender._handle_defeat()

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
					await defender._announce_out_of_range()
				break
			if not defender_counter_paid:
				defender.assigned_move.consume_use()
				defender_counter_paid = true
			await get_tree().create_timer(HIT_DELAY).timeout
			await defender._execute_single_hit(self, defender.assigned_move, false)

	if is_defeated():
		await _handle_defeat()

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


## Execute a single hit against a target. Calculates damage (or healing for support
## moves), spawns popup, optionally applies status effects, runs on-hit cleanses.
## Sequence: boop out → hitlag freeze at contact → snap back + damage + popup.
func _execute_single_hit(target: Unit, move: Move, apply_status: bool) -> void:
	if move.heals:
		await _execute_heal_hit(target, move, apply_status)
		return
	if move.damage_type == Enums.DamageType.SUPPORT:
		await _execute_support_hit(target, move, apply_status)
		return

	# Hit roll. Miss path plays the approach but skips damage/flash/popup/status
	# so the swing reads as a swing-and-dodge rather than "nothing happened."
	# Move usage is NOT refunded on miss — RD style.
	var hit_pct := DamageCalculator.hit_chance_pct(self, target, move)
	if GameRng.randi() % 100 >= hit_pct:
		await _play_miss(target, move)
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

	# Phase 1: Approach. If the attacker has a clip matching this attack's
	# direction+range, play it through to its hit frame; otherwise nudge.
	var clip := _pick_attack_clip(target, move)
	var use_clip: bool = not clip.is_empty()
	if use_clip:
		await _play_clip_to_hit(clip, target)
	else:
		await _play_boop_out(target)

	# Phase 2: Hitlag — both units freeze at moment of contact
	var hitlag_duration := lerpf(HITLAG_MIN, HITLAG_MAX, impact_weight)
	await get_tree().create_timer(hitlag_duration).timeout

	# Phase 3: Snap back + hit flash + screenshake + damage (all fire together as hitlag releases)
	if use_clip:
		_play_clip_after_hit(clip)
	else:
		_play_boop_return()
	VisualFeedbackManager.apply_hit_flash(target, impact_weight)

	var camera := get_viewport().get_camera_2d() as CameraController
	if camera != null:
		camera.screenshake(impact_weight)

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

	_spawn_damage_popup(target, damage, effectiveness_text, type_multiplier)
	if ctx.is_crit:
		spawn_text_callout("CRIT!", GameColors.TEXT_SECONDARY)

	DebugConfig.log_combat("Hit: %s -> %s for %d damage (x%.2f %s, impact=%.2f, hitlag=%.3fs)" % [
		unit_name, target.unit_name, damage, type_multiplier, effectiveness_text, impact_weight, hitlag_duration])

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
## no displacement. Heal amount = caster.special + move.base_power.
func _execute_heal_hit(target: Unit, move: Move, apply_status: bool) -> void:
	var heal_amount: int = DamageCalculator.calculate_heal_amount(self, target, move)

	await _play_boop_out(target)
	# Brief beat for the heal to feel weighty without the full damage hitlag.
	await get_tree().create_timer(HITLAG_MIN).timeout
	_play_boop_return()

	target.heal(heal_amount)
	_award_heal_xp(target, heal_amount)
	combat_hit.emit(self, target, -heal_amount)
	_spawn_heal_popup(target, heal_amount)

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
	var effects := CombatEffectPipeline.gather(ctx)
	await CombatEffectPipeline.run_on_hit(ctx, effects)


## Support-side counterpart to _execute_single_hit for non-heal, non-damage
## applications (Fortify's buff, Roar's shout landing on a victim, Shriek's
## mark). Support moves auto-hit — no accuracy roll (their riders' own chance
## fields are the gate), no damage, no XP, no approach animation (the cast
## flourish or the primary combat beat already carried the motion). Everything
## lands through the pipeline so afflictions, conditionals, marks, cleanses,
## and support shoves use the same machinery as combat hits.
func _execute_support_hit(target: Unit, move: Move, apply_status: bool) -> void:
	var ctx := CombatHitContext.new()
	ctx.attacker = self
	ctx.defender = target
	ctx.move = move
	ctx.apply_status = apply_status
	ctx.is_support = true
	var effects := CombatEffectPipeline.gather(ctx)
	DebugConfig.log_combat("Support: %s -> %s (move=%s)" % [
		unit_name, target.unit_name, move.move_name])
	await CombatEffectPipeline.run_on_hit(ctx, effects)


## The AoE pass: after the primary application, every OTHER unit inside the
## move's area (epicenter = the primary target's tile; for a self-cast, the
## caster's own tile) gets its own pipeline application. AoE victims never
## counter and never trigger multi-hit — that belongs to the primary exchange.
func _execute_area_applications(primary: Unit, move: Move) -> void:
	if move.area_of_effect <= 0:
		return
	var epicenter: Tile = primary.current_tile if primary != null else current_tile
	if epicenter == null:
		return
	for victim: Unit in MoveTargeting.get_area_victims(self, epicenter, move):
		if victim == primary:
			continue
		await _execute_single_hit(victim, move, true)
		if victim.is_defeated():
			await victim._handle_defeat()


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


## The visible beat for a self-cast whose payload is all AoE (Roar, Shriek):
## a quick sprite pulse, plus the move-name callout for PLAYER casters (the
## enemy AI already announces its move pre-swing — a second callout would
## read as a stutter).
func _play_support_cast_flourish(move: Move) -> void:
	if faction == Enums.UnitFaction.PLAYER:
		var callout_color: Color = GameColors.get_move_chip_foreground(move.element_type) \
				if move.element_type != Enums.ElementalType.NONE else GameColors.PLAYER_UNIT
		spawn_text_callout(move.move_name.to_upper(), callout_color)
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_IN)
	await tween.finished


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
func _grant_combat_xp(xp: int) -> void:
	if xp <= 0:
		return
	_combat_xp_gained += xp
	var levels_gained: int = character_data.grant_xp(xp)
	if levels_gained > 0:
		_combat_levels_gained += levels_gained
		_update_level_label()
		_update_health_bar()


## End-of-combat XP feedback: one gold "+N XP" callout for everything earned
## this sequence (hits, kills, heals, support, survival — batched so a 4-hit
## chain doesn't spam four popups), then LEVEL UP! on a beat of its own.
## The mid-battle celebration stays deliberately small — the full stat
## reveal belongs to LevelUpReportPanel at mission end.
func _flush_xp_feedback() -> void:
	if _combat_xp_gained <= 0:
		return
	spawn_text_callout("+%d XP" % _combat_xp_gained, GameColorPalette.get_color("Yellow", 7))
	if _combat_levels_gained > 0 and is_inside_tree():
		await get_tree().create_timer(0.5).timeout
		spawn_text_callout("LEVEL UP!", GameColorPalette.get_color("Yellow", 8))
	_combat_xp_gained = 0
	_combat_levels_gained = 0


## Miss path: attacker plays its approach, brief hold so the player can read
## "MISS" on the target, then return to idle. No damage, no flash, no
## screenshake, no status proc, no XP — just animation + callout.
func _play_miss(target: Unit, move: Move) -> void:
	var clip := _pick_attack_clip(target, move)
	var use_clip: bool = not clip.is_empty()
	if use_clip:
		await _play_clip_to_hit(clip, target)
	else:
		await _play_boop_out(target)

	# Match the minimum-hitlag hold so the MISS callout has time to land before
	# the attacker snaps back. Keeps the swing-and-dodge rhythm consistent with
	# a low-impact hit.
	await get_tree().create_timer(HITLAG_MIN).timeout

	if use_clip:
		_play_clip_after_hit(clip)
	else:
		_play_boop_return()
	target.spawn_text_callout("MISS", GameColorPalette.get_color("Gray", 5))


## Boop out: sprite bumps toward the target. Awaitable — completes at the contact point.
func _play_boop_out(target: Unit) -> void:
	if _sprite == null or target == null:
		await get_tree().create_timer(0.08).timeout
		return
	# Raise above same-row neighbors for the swing window. Paired with the
	# _lower_after_attack triggered when _play_boop_return's tween finishes.
	_raise_for_attack()
	var direction := (target.global_position - global_position).normalized()
	var boop_offset := direction * BOOP_DISTANCE
	var tween := create_tween()
	tween.tween_property(_sprite, "position", boop_offset, 0.08).set_ease(Tween.EASE_OUT)
	await tween.finished


## Boop return: sprite snaps back to center. Fire-and-forget (not awaited).
## Lowers the unit (refcount-aware) when the return tween finishes, so the
## raise from _play_boop_out is balanced even when chained Hit 2 starts
## before this tween completes — refcount stays consistent across hits.
func _play_boop_return() -> void:
	if _sprite == null:
		_lower_after_attack()
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "position", Vector2.ZERO, 0.12).set_ease(Tween.EASE_IN)
	tween.finished.connect(_lower_after_attack)


## Manhattan delta from self to target in tile coords. Falls back to global_position
## divided by tile size if either unit isn't on a tile yet.
func _attack_delta_tiles(target: Unit) -> Vector2i:
	if current_tile != null and target != null and target.current_tile != null:
		return Vector2i(target.current_tile.grid_x - current_tile.grid_x,
				target.current_tile.grid_y - current_tile.grid_y)
	if target == null:
		return Vector2i.ZERO
	var dp := target.global_position - global_position
	return Vector2i(roundi(dp.x / 16.0), roundi(dp.y / 16.0))


## Returns the best-matching clip dict from character_data.attack_animations
## given direction-to-target, range, and the move's animation style. Empty dict
## means "no match — fall back to boop nudge". Thin wrapper that resolves the
## tile delta, then defers to the pure select_styled_attack_clip so the
## matching logic stays unit-testable.
func _pick_attack_clip(target: Unit, move: Move) -> Dictionary:
	if character_data == null or character_data.attack_animations.is_empty():
		return {}
	if target == null:
		return {}
	return select_styled_attack_clip(character_data.attack_animations,
			_attack_delta_tiles(target), move, DIAGONAL_USES_SIDE_ANIMATION)


## Style-aware clip selection: a ranged move fired point-blank should read as a
## shot, not a melee swing (and an explicitly melee-tagged reach move as a
## swing, not a shot). Tries the move's effective_animation_style first by
## projecting the delta to a distance that matches that style, then falls back
## to the true distance — so a melee-only sprite using a ranged move up close
## still swings instead of booping.
static func select_styled_attack_clip(attack_animations: Dictionary, delta: Vector2i,
		move: Move, diagonal_as_side: bool) -> Dictionary:
	var styled_delta := _style_adjusted_delta(delta, move)
	if styled_delta != delta:
		var styled := _select_attack_clip(attack_animations, styled_delta, diagonal_as_side)
		if not styled.is_empty():
			return styled
	return _select_attack_clip(attack_animations, delta, diagonal_as_side)


## Projects an attack delta to the distance band matching the move's animation
## style, preserving direction: ranged moves read as at least ring distance 2,
## melee moves as the adjacent ring. Identity for null moves or when the delta
## already sits in the style's band.
static func _style_adjusted_delta(delta: Vector2i, move: Move) -> Vector2i:
	if move == null or delta == Vector2i.ZERO:
		return delta
	match move.effective_animation_style():
		"ranged":
			if maxi(absi(delta.x), absi(delta.y)) < 2:
				return delta * 2
		"melee":
			return Vector2i(signi(delta.x), signi(delta.y))
	return delta


## Pure clip selection: given the animation table and the attacker→target tile
## delta, return the first clip whose use_when filters pass. First-match wins;
## clip ordering in JSON matters only when two clips' filters would both pass
## (avoid that). Empty dict means no match (caller boops).
##
## direction filter: "vertical" needs a due north/south delta; "horizontal"
## needs an east/west component. When diagonal_as_side is true a diagonal counts
## as horizontal (shows the side-swing, mirrored later by flip_h) and range is
## matched on Chebyshev (ring) distance, so a diagonally-adjacent target reads as
## range 1 and picks melee rather than the ranged clip. Chebyshev == Manhattan
## for orthogonal attacks, so straight-line matching is untouched. With the flag
## off, diagonals match neither directional clip (legacy boop fallback) and range
## is Manhattan — exactly the original behavior.
##
## Static + pure so it's testable without a scene tree, tiles, or live targets.
static func _select_attack_clip(attack_animations: Dictionary, delta: Vector2i,
		diagonal_as_side: bool) -> Dictionary:
	var vertical: bool = delta.x == 0 and delta.y != 0
	var horizontal: bool
	var range_distance: int
	if diagonal_as_side:
		horizontal = delta.x != 0  # pure east/west OR any diagonal
		range_distance = maxi(absi(delta.x), absi(delta.y))  # Chebyshev / ring
	else:
		horizontal = delta.y == 0 and delta.x != 0
		range_distance = absi(delta.x) + absi(delta.y)  # Manhattan
	for clip_name: Variant in attack_animations.keys():
		var clip_value: Variant = attack_animations[clip_name]
		if not (clip_value is Dictionary):
			continue
		var clip: Dictionary = clip_value
		var use_when: Dictionary = clip.get("use_when", {})
		var dir_req: String = str(use_when.get("direction", "any"))
		if dir_req == "horizontal" and not horizontal:
			continue
		if dir_req == "vertical" and not vertical:
			continue
		if use_when.has("range") and int(use_when["range"]) != range_distance:
			continue
		if use_when.has("range_min") and int(use_when["range_min"]) > range_distance:
			continue
		if use_when.has("range_max") and int(use_when["range_max"]) < range_distance:
			continue
		return clip
	return {}


## Resolves both per-frame durations (seconds) and hit_frame for a clip.
## Both are sourced from the sidecar JSON when present (the exporter writes
## them from Lawrence's authored timings and `hit` marker tags). Falls back
## to the clip JSON's `fps` / `hit_frame` when absent — so clips authored
## before the exporter update still play.
## Returns: { "durations_s": Array[float], "hit_frame": int }.
func _resolve_clip_playback(strip_path: String, clip: Dictionary, frames: int) -> Dictionary:
	var durations_s: Array[float] = []
	var hit_frame: int = int(clip.get("hit_frame", frames / 2))
	var sidecar_path: String = strip_path.trim_suffix(".png") + ".json"
	if FileAccess.file_exists(sidecar_path):
		var content := FileAccess.get_file_as_string(sidecar_path)
		if not content.is_empty():
			var parsed: Variant = JSON.parse_string(content)
			if parsed is Dictionary:
				if parsed.has("frame_durations_ms"):
					var ms_array: Array = parsed["frame_durations_ms"]
					if ms_array.size() == frames:
						for ms: Variant in ms_array:
							durations_s.append(float(ms) / 1000.0)
				if parsed.has("hit_frame"):
					hit_frame = int(parsed["hit_frame"])
	if durations_s.is_empty():
		var fps: int = max(1, int(clip.get("fps", ATTACK_CLIP_DEFAULT_FPS)))
		var dt: float = 1.0 / float(fps)
		for _i in range(frames):
			durations_s.append(dt)
	hit_frame = clampi(hit_frame, 0, frames - 1)
	return { "durations_s": durations_s, "hit_frame": hit_frame }


## Plays clip frames 0..hit_frame inclusive, awaiting on each frame. Mirrors via
## flip_h when the target is east of self (clips authored left-facing). Assumes
## the clip's pivot.x is at frame center — off-center pivots would visibly jump
## on flip; revisit if/when Lawrence delivers an off-center clip.
func _play_clip_to_hit(clip: Dictionary, target: Unit) -> void:
	if _sprite == null or clip.is_empty():
		await get_tree().create_timer(0.08).timeout
		return
	var strip_path: String = clip.get("path", "")
	var strip_texture: Texture2D = load(strip_path) as Texture2D
	if strip_texture == null:
		await get_tree().create_timer(0.08).timeout
		return
	_attack_clip_generation += 1
	var generation: int = _attack_clip_generation
	var frames: int = max(1, int(clip.get("frames", 1)))
	var playback: Dictionary = _resolve_clip_playback(strip_path, clip, frames)
	var hit_frame: int = playback["hit_frame"]
	var durations_s: Array[float] = playback["durations_s"]
	var frame_width: float = float(strip_texture.get_width()) / float(frames)
	var frame_height: float = float(strip_texture.get_height())

	var delta := _attack_delta_tiles(target)
	_sprite.flip_h = delta.x > 0
	_sprite.texture = strip_texture
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0.0, 0.0, frame_width, frame_height)
	# Raise above same-row neighbors for the duration of the swing —
	# attacker should always render in front of the defender. See
	# _raise_for_attack for the full rationale.
	_raise_for_attack()

	for frame_index: int in range(0, hit_frame):
		await get_tree().create_timer(durations_s[frame_index]).timeout
		if _attack_clip_generation != generation or _sprite == null:
			return
		_sprite.region_rect = Rect2((frame_index + 1) * frame_width, 0.0, frame_width, frame_height)


## Plays the remaining frames (hit_frame+1 .. last), then restores idle.
## Fire-and-forget — runs while damage popups/screenshake play. Guards against
## a newer clip starting mid-tail via the generation counter.
##
## Bail paths still call _lower_after_attack to keep the raise refcount
## balanced — the matching raise happened in _play_clip_to_hit. The newer
## clip's own tail handles its own restore_idle_sprite; we only release our
## refcount slot.
func _play_clip_after_hit(clip: Dictionary) -> void:
	if _sprite == null or clip.is_empty():
		_lower_after_attack()
		return
	var generation: int = _attack_clip_generation
	var frames: int = max(1, int(clip.get("frames", 1)))
	var strip_path: String = clip.get("path", "")
	var playback: Dictionary = _resolve_clip_playback(strip_path, clip, frames)
	var hit_frame: int = playback["hit_frame"]
	var durations_s: Array[float] = playback["durations_s"]
	var frame_width: float = _sprite.region_rect.size.x
	var frame_height: float = _sprite.region_rect.size.y
	for frame_index: int in range(hit_frame + 1, frames):
		await get_tree().create_timer(durations_s[frame_index]).timeout
		if _attack_clip_generation != generation or _sprite == null:
			_lower_after_attack()
			return
		_sprite.region_rect = Rect2(frame_index * frame_width, 0.0, frame_width, frame_height)
	# Brief hold on the final frame before resetting to idle.
	await get_tree().create_timer(durations_s[frames - 1]).timeout
	if _attack_clip_generation != generation or _sprite == null:
		_lower_after_attack()
		return
	_restore_idle_sprite()


## Reverts the Sprite2D back to the idle texture+offset emitted by
## _load_character_sprite. Called at the tail of an attack clip. Also
## restores the sibling tree position raised in _raise_for_attack.
func _restore_idle_sprite() -> void:
	if _sprite == null or character_data == null:
		return
	_sprite.region_enabled = false
	_sprite.flip_h = false
	_load_character_sprite()
	_lower_after_attack()


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


## Surface a follow-up (counter or bonus hit) that the mid-combat range
## re-check refused — displacement moved someone out of reach. Without this
## the lost attack is invisible negative space: the player reads "the game
## forgot to counter," not "they got shoved out of reach." Same muted ink as
## MISS (the "attack didn't happen" family) + the CORRUPTION-style read-beat
## so cause-and-effect lands before combat moves on.
func _announce_out_of_range() -> void:
	spawn_text_callout("OUT OF RANGE", GameColorPalette.get_color("Gray", 5))
	await get_tree().create_timer(0.4).timeout


## Handle unit defeat: gray out, fade, clear tile.
func _handle_defeat() -> void:
	if _defeat_visuals_played:
		return
	_defeat_visuals_played = true
	is_defeated_flag = true
	DebugConfig.log_combat("Unit defeated: %s" % unit_name)

	# Stop any selection effects
	_stop_selection_pulse()

	# Gray out
	if _sprite != null:
		_sprite.modulate = Color(0.4, 0.4, 0.4, 1.0)

	# Hide health bar and status icons
	if _health_bar_background != null:
		_health_bar_background.visible = false
	if _health_bar_fill != null:
		_health_bar_fill.visible = false
	if _status_indicator != null:
		_status_indicator.visible = false
	if _level_label != null:
		_level_label.visible = false
	for icon: Sprite2D in _type_icons:
		icon.visible = false

	# Fade out over 1 second (tweens need the tree; bare test units skip the fade)
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 1.0)
		await tween.finished

	# Clear tile occupancy
	if current_tile != null:
		current_tile.clear_unit()
		current_tile = null


# =============================================================================
# VISUAL HELPERS
# =============================================================================

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
	var width := float(texture.get_width())
	var height := float(texture.get_height())
	_art_top = 0.0
	var sidecar_path: String = sheet_path.trim_suffix(".png") + ".json"
	if FileAccess.file_exists(sidecar_path):
		var content := FileAccess.get_file_as_string(sidecar_path)
		if not content.is_empty():
			var parsed: Variant = JSON.parse_string(content)
			if parsed is Dictionary and parsed.has("pivot"):
				var pivot: Dictionary = parsed["pivot"]
				var px := float(pivot.get("x", width / 2.0))
				var py := float(pivot.get("y", height))
				if parsed.has("art_bounds"):
					var bounds: Dictionary = parsed["art_bounds"]
					_art_top = float(bounds.get("top", 0))
					# Visual feet = bottom of the opaque art. With the cast's
					# body-centered canvases the pivot is mid-body; the gap is
					# what the shadow needs to pivot at the boots.
					_art_feet_drop = maxf(0.0, float(bounds.get("bottom", py)) - py)
				return Vector2(width / 2.0 - px, height / 2.0 - py)
	return Vector2(0, -height / 2.0)


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
## levels happen in prep_screen, not in-battle).
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
	_health_bar_background.color = Color(0.1, 0.1, 0.1, 1.0)
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
	# Calculate z-index from grid coordinates directly (not pixel position)
	# to avoid the pixel-space mismatch in GridZIndexHandler.
	var grid_manager: Node = get_node_or_null("/root/GridManager")
	if grid_manager == null:
		return
	var offset_y: int = grid_manager.grid_offset_y
	var height: int = grid_manager.grid_height
	var row_index: int = current_tile.grid_y - offset_y  # Front row (lowest grid_y) → index 0 (highest z)
	z_index = ZIndexCalculator.calculate_sorting_order(row_index, 100, ZIndexCalculator.ZIndexLayer.UNITS)
