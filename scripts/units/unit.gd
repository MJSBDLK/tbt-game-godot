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
		return character_data.get_effective_move_distance() * MOVEMENT_SCALE


# =============================================================================
# STATE
# =============================================================================

var is_selected: bool = false
var can_act: bool = true
var is_moving: bool = false
var is_defeated_flag: bool = false
var _defeat_visuals_played: bool = false
var current_hp: int = 0
var assigned_move: Move = null
var last_used_move_index: int = -1  # Index into equipped_moves of the most recently executed move (for Capricious passive)
var active_status_effects: Array = []  # Array of StatusEffect

# Set by take_damage when the killing blow lands. Used by InjurySystem to
# pick the right injury when the unit_defeated handler runs.
# Shape: { "element": Enums.ElementalType, "damage_type": Enums.DamageType, "name": String }
var last_killing_source: Dictionary = {}
var last_damage_overkill: int = 0

# Per-turn injury state (cleared and re-rolled at start of each turn).
# Set by InjurySystem.process_turn_start.
var injury_locked_move_indices: Array[int] = []

var _start_tile_before_move: Tile = null
var _selection_tween: Tween = null

# Topmost opaque pixel of the sprite art in texture coords (canvas top-left = 0).
# Lawrence's centered-canvas sprites have transparent padding; this is the y of
# the actual visible art so the health bar can sit above the unit, not the canvas.
# Loaded from the idle.json sidecar's `art_bounds.top`; 0 if no sidecar.
var _art_top: float = 0.0

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
var _health_bar: Node2D = null
var _health_bar_background: ColorRect = null
var _health_bar_fill: ColorRect = null
var _status_indicator: StatusEffectIndicator = null
var _level_label: Label = null
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
	_apply_faction_healthbar()
	_update_level_label()
	_update_healthbar_position()
	_update_z_index()
	_update_health_bar()

	can_act = true
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

	if _path_visualizer != null and _path_visualizer.has_method("clear_arrows"):
		_path_visualizer.call("clear_arrows")

	await _move_along_path(full_path)

	is_moving = false
	planned_waypoints.clear()
	# NOTE: _start_tile_before_move is intentionally kept alive here.
	# It persists until set_acted() or cancel_movement() so the player
	# can press Escape to snap back after moving but before acting.
	movement_completed.emit(self)


func cancel_movement() -> void:
	if _start_tile_before_move != null:
		move_to_tile(_start_tile_before_move)
		_start_tile_before_move = null

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
		for tile: Tile in segment:
			if not full_path.has(tile):
				full_path.append(tile)
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
	_start_tile_before_move = current_tile
	_apply_active_modulate()


func set_acted() -> void:
	can_act = false
	_start_tile_before_move = null
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
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager == null:
		return null
	var pool: Array[Unit] = []
	if faction == Enums.UnitFaction.PLAYER:
		pool = turn_manager.get_player_units()
	else:
		pool = turn_manager.get_enemy_units()

	var candidates: Array[Unit] = []
	for ally: Unit in pool:
		if ally == self or ally.is_defeated() or ally.current_tile == null or current_tile == null:
			continue
		var dist: int = absi(ally.current_tile.grid_x - current_tile.grid_x) + absi(ally.current_tile.grid_y - current_tile.grid_y)
		if dist <= attack_range:
			candidates.append(ally)

	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


# =============================================================================
# COMBAT — SEQUENCE EXECUTION
# =============================================================================

## Execute a full combat sequence: attacker hits, counter-attacks, bonus hits.
## This is an async method — caller must await it.
func execute_combat_sequence(defender: Unit, attacker_move: Move) -> void:
	if defender == null or attacker_move == null:
		return

	var is_ally_move := attacker_move.targets_allies()

	# Friendly fire (Corruption injury): the attacker has been "acting shifty."
	# On a proc, retarget a random ally in range. If no ally is in range, the
	# attack fizzles entirely — flavor: the unit hesitates.
	# Skipped for ally-targeting moves (they're already friendly).
	if not is_ally_move and character_data != null and character_data.friendly_fire_chance_pct() > 0.0:
		if randf() * 100.0 < character_data.friendly_fire_chance_pct():
			var ally: Unit = _pick_random_ally_in_range(attacker_move.attack_range)
			if ally == null:
				DebugConfig.log_combat("FriendlyFire: %s hesitated (no ally in range)" % unit_name)
				return
			DebugConfig.log_combat("FriendlyFire: %s redirected attack from %s to %s" % [
				unit_name, defender.unit_name, ally.unit_name])
			defender = ally

	combat_started.emit(self, defender)
	DebugConfig.log_combat("Combat: %s (move=%s) vs %s" % [unit_name, attacker_move.move_name, defender.unit_name])

	# Ally-targeting moves (heals, buffs): single application, no counter, no multi-hit.
	if is_ally_move:
		attacker_move.consume_use()
		await _execute_single_hit(defender, attacker_move, true)
		combat_completed.emit(self, defender)
		return

	var attacker_hits := DamageCalculator.calculate_attack_count(self, defender)
	var defender_can_counter := DamageCalculator.can_counter_attack(defender, self)
	var defender_hits := 0
	if defender_can_counter:
		defender_hits = DamageCalculator.calculate_attack_count(defender, self)

	# Consume PP once per combatant
	attacker_move.consume_use()
	if defender_can_counter and defender.assigned_move != null:
		defender.assigned_move.consume_use()

	# === Hit 1: Attacker ===
	await _execute_single_hit(defender, attacker_move, true)
	if defender.is_defeated():
		await defender._handle_defeat()
		combat_completed.emit(self, defender)
		return

	# === Counter 1: Defender ===
	if defender_can_counter and not defender.is_defeated():
		await get_tree().create_timer(HIT_DELAY).timeout
		await defender._execute_single_hit(self, defender.assigned_move, true)
		if is_defeated():
			await _handle_defeat()
			combat_completed.emit(self, defender)
			return

	# === Bonus attacker hits (2nd through Nth) ===
	for i: int in range(1, attacker_hits):
		if defender.is_defeated():
			break
		await get_tree().create_timer(HIT_DELAY).timeout
		await _execute_single_hit(defender, attacker_move, false)

	if defender.is_defeated():
		await defender._handle_defeat()

	# === Bonus defender counters (2nd through Nth) ===
	if defender_can_counter:
		for i: int in range(1, defender_hits):
			if is_defeated() or defender.is_defeated():
				break
			await get_tree().create_timer(HIT_DELAY).timeout
			await defender._execute_single_hit(self, defender.assigned_move, false)

	if is_defeated():
		await _handle_defeat()

	combat_completed.emit(self, defender)
	DebugConfig.log_combat("Combat complete: %s HP=%d, %s HP=%d" % [
		unit_name, current_hp, defender.unit_name, defender.current_hp])


## Execute a single hit against a target. Calculates damage (or healing for support
## moves), spawns popup, optionally applies status effects, runs on-hit cleanses.
## Sequence: boop out → hitlag freeze at contact → snap back + damage + popup.
func _execute_single_hit(target: Unit, move: Move, apply_status: bool) -> void:
	if move.heals:
		await _execute_heal_hit(target, move, apply_status)
		return

	# Hit roll. Miss path plays the approach but skips damage/flash/popup/status
	# so the swing reads as a swing-and-dodge rather than "nothing happened."
	# Move usage is NOT refunded on miss — RD style.
	var hit_pct := DamageCalculator.hit_chance_pct(self, target, move)
	if randi() % 100 >= hit_pct:
		await _play_miss(target, move)
		DebugConfig.log_combat("Miss: %s -> %s (hit %d%%)" % [unit_name, target.unit_name, hit_pct])
		return

	# Pre-calculate damage so we know impact weight before the hit lands
	var damage := DamageCalculator.calculate_damage(self, target, move)
	var type_multiplier := DamageCalculator.get_type_effectiveness(self, target, move)
	var effectiveness_text := TypeChart.get_effectiveness_text(type_multiplier)
	var impact_weight := DamageCalculator.calculate_impact_weight(damage, target.character_data.max_hp if target.character_data else 1)

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

	DebugConfig.log_combat("Hit: %s -> %s for %d damage (x%.2f %s, impact=%.2f, hitlag=%.3fs)" % [
		unit_name, target.unit_name, damage, type_multiplier, effectiveness_text, impact_weight, hitlag_duration])

	# Apply status effect on first hit only
	if apply_status and move.status_effect_type != Enums.StatusEffectType.NONE:
		StatusEffectSystem.apply_status_effect(self, target, move)

	# On-hit cleanse: remove specified status effects from the target.
	_apply_cleanse(target, move)

	# On-hit instant effects (displacement, etc.). Runs every hit, after damage.
	await DisplacementSystem.resolve(self, target, move, damage)

	# Check passive triggers (e.g. Bellows: air hit grants fire buff)
	StatusEffectSystem.check_passive_triggers_on_hit(self, target, move)


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

	if apply_status and move.status_effect_type != Enums.StatusEffectType.NONE:
		StatusEffectSystem.apply_status_effect(self, target, move)

	_apply_cleanse(target, move)


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
	var levels_gained: int = character_data.grant_xp(xp)
	if levels_gained > 0:
		_update_level_label()
		_update_health_bar()


## Heal-side XP grant. RD awards a flat amount per cast regardless of HP
## restored — passing `amount` so we can switch to fraction-of-max scaling
## later without changing call sites.
func _award_heal_xp(target: Unit, amount: int) -> void:
	if faction != Enums.UnitFaction.PLAYER:
		return
	if character_data == null or amount <= 0:
		return
	var target_data: CharacterData = target.character_data if target != null else null
	var xp: int = CombatXpCalculator.compute_heal_xp(character_data, target_data)
	var levels_gained: int = character_data.grant_xp(xp)
	if levels_gained > 0:
		_update_level_label()
		_update_health_bar()


func _apply_cleanse(target: Unit, move: Move) -> void:
	if move.cleanse_effects.is_empty():
		return
	for effect_name: String in move.cleanse_effects:
		StatusEffectSystem.remove_status_effect(target, effect_name)
		DebugConfig.log_combat("Cleanse: %s removed %s from %s" % [unit_name, effect_name, target.unit_name])


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
## given direction-to-target and Manhattan range. Empty dict means "no match —
## fall back to boop nudge". First-match wins; clip ordering in JSON matters
## only when two clips' use_when filters would both pass (avoid that).
func _pick_attack_clip(target: Unit, _move: Move) -> Dictionary:
	if character_data == null or character_data.attack_animations.is_empty():
		return {}
	if target == null:
		return {}
	var delta := _attack_delta_tiles(target)
	var horizontal: bool = delta.y == 0 and delta.x != 0
	var vertical: bool = delta.x == 0 and delta.y != 0
	var manhattan: int = absi(delta.x) + absi(delta.y)
	for clip_name: Variant in character_data.attack_animations.keys():
		var clip_value: Variant = character_data.attack_animations[clip_name]
		if not (clip_value is Dictionary):
			continue
		var clip: Dictionary = clip_value
		var use_when: Dictionary = clip.get("use_when", {})
		var dir_req: String = str(use_when.get("direction", "any"))
		if dir_req == "horizontal" and not horizontal:
			continue
		if dir_req == "vertical" and not vertical:
			continue
		if use_when.has("range") and int(use_when["range"]) != manhattan:
			continue
		if use_when.has("range_min") and int(use_when["range_min"]) > manhattan:
			continue
		if use_when.has("range_max") and int(use_when["range_max"]) < manhattan:
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


func _spawn_damage_popup(target: Unit, damage: int, effectiveness_text: String, multiplier: float) -> void:
	var popup_scene := preload("res://scenes/ui/damage_popup.tscn")
	var popup: Node2D = popup_scene.instantiate()
	popup.global_position = target.global_position + Vector2(0, -8)
	popup.z_index = target.z_index + 2  # UNITS layer + 2 = UI layer, always above defending unit
	get_tree().current_scene.add_child(popup)
	if popup.has_method("initialize"):
		popup.call("initialize", damage, effectiveness_text, multiplier)


func _spawn_heal_popup(target: Unit, amount: int) -> void:
	var popup_scene := preload("res://scenes/ui/damage_popup.tscn")
	var popup: Node2D = popup_scene.instantiate()
	popup.global_position = target.global_position + Vector2(0, -8)
	popup.z_index = target.z_index + 2
	get_tree().current_scene.add_child(popup)
	if popup.has_method("initialize_heal"):
		popup.call("initialize_heal", amount)


## Float a text callout above THIS unit (e.g. "BACKHAND" when an enemy
## commits to an attack so the player knows what's about to land). Spawned
## higher than damage popups so they can stack without overlap.
func spawn_text_callout(text: String, color: Color) -> void:
	var popup_scene := preload("res://scenes/ui/damage_popup.tscn")
	var popup: Node2D = popup_scene.instantiate()
	popup.global_position = global_position + Vector2(0, -20)
	popup.z_index = z_index + 2
	get_tree().current_scene.add_child(popup)
	if popup.has_method("initialize_callout"):
		popup.call("initialize_callout", text, color)


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

	# Fade out over 1 second
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
		var injury := Injury.new()
		injury.injury_id = data.injury_id
		injury.severity = severity
		injury.battles_remaining = data.major_recovery_battles if severity == Enums.InjurySeverity.MAJOR else data.minor_recovery_battles
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
	var injury := Injury.new()
	injury.injury_id = "hypoesthesia"
	if DebugConfig.testing_hypoesthesia_major:
		injury.severity = Enums.InjurySeverity.MAJOR
		injury.battles_remaining = data.major_recovery_battles
	else:
		injury.severity = Enums.InjurySeverity.MINOR
		injury.battles_remaining = data.minor_recovery_battles
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
