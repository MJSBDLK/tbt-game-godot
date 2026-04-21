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
var current_hp: int = 0
var assigned_move: Move = null
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

# Child node references
var _sprite: Sprite2D = null
var _health_bar: Node2D = null
var _health_bar_background: ColorRect = null
var _health_bar_fill: ColorRect = null
var _status_indicator: StatusEffectIndicator = null
var _path_visualizer: Node2D = null  # PathVisualizer


# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_sprite = $Sprite2D as Sprite2D
	_health_bar = $HealthBar as Node2D
	_health_bar_background = $HealthBar/Background as ColorRect
	_health_bar_fill = $HealthBar/Fill as ColorRect
	_status_indicator = $HealthBar/StatusEffectIndicator as StatusEffectIndicator
	if has_node("PathVisualizer"):
		_path_visualizer = $PathVisualizer
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
	if current_tile != null:
		current_tile.clear_unit()
	current_tile = new_tile
	if current_tile != null:
		current_tile.set_unit(self)
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

		# Update tile occupancy tile-by-tile
		if current_tile != null:
			current_tile.clear_unit()
		current_tile = tile
		tile.set_unit(self)
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


## Heal this unit by amount. The actual heal is reduced by Laceration
## (character_data.healing_reduction_pct) but always restores at least 1 HP if amount > 0.
func heal(amount: int) -> void:
	if amount <= 0:
		return
	var reduction: float = character_data.healing_reduction_pct
	var actual: int = amount
	if reduction > 0.0:
		actual = maxi(1, int(floor(amount * (1.0 - reduction / 100.0))))
	current_hp = mini(character_data.max_hp, current_hp + actual)
	_update_health_bar()
	health_changed.emit(self, current_hp, character_data.max_hp)


func _update_health_bar() -> void:
	if _health_bar_fill == null or character_data == null:
		return
	if character_data.max_hp <= 0:
		return
	var health_percent := float(current_hp) / float(character_data.max_hp)
	_health_bar_fill.scale.x = health_percent
	# Hypoesthesia: hide the whole bar when an HP-hide injury threshold is exceeded.
	if _health_bar != null:
		_health_bar.visible = not character_data.is_health_bar_hidden(current_hp)


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

	# Friendly fire (Corruption injury): the attacker has been "acting shifty."
	# On a proc, retarget a random ally in range. If no ally is in range, the
	# attack fizzles entirely — flavor: the unit hesitates.
	if character_data != null and character_data.friendly_fire_chance_pct() > 0.0:
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

	if defender.is_defeated() and not defender.is_defeated_flag:
		await defender._handle_defeat()

	# === Bonus defender counters (2nd through Nth) ===
	if defender_can_counter:
		for i: int in range(1, defender_hits):
			if is_defeated() or defender.is_defeated():
				break
			await get_tree().create_timer(HIT_DELAY).timeout
			await defender._execute_single_hit(self, defender.assigned_move, false)

	if is_defeated() and not is_defeated_flag:
		await _handle_defeat()

	combat_completed.emit(self, defender)
	DebugConfig.log_combat("Combat complete: %s HP=%d, %s HP=%d" % [
		unit_name, current_hp, defender.unit_name, defender.current_hp])


## Execute a single hit against a target. Calculates damage, spawns popup, optionally applies status.
## Sequence: boop out → hitlag freeze at contact → snap back + damage + popup.
func _execute_single_hit(target: Unit, move: Move, apply_status: bool) -> void:
	# Pre-calculate damage so we know impact weight before the hit lands
	var damage := DamageCalculator.calculate_damage(self, target, move)
	var type_multiplier := DamageCalculator.get_type_effectiveness(self, target, move)
	var effectiveness_text := TypeChart.get_effectiveness_text(type_multiplier)
	var impact_weight := DamageCalculator.calculate_impact_weight(damage, target.character_data.max_hp if target.character_data else 1)

	# Phase 1: Boop toward target
	await _play_boop_out(target)

	# Phase 2: Hitlag — both units freeze at moment of contact
	var hitlag_duration := lerpf(HITLAG_MIN, HITLAG_MAX, impact_weight)
	await get_tree().create_timer(hitlag_duration).timeout

	# Phase 3: Snap back + hit flash + screenshake + damage (all fire together as hitlag releases)
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
	combat_hit.emit(self, target, damage)

	_spawn_damage_popup(target, damage, effectiveness_text, type_multiplier)

	DebugConfig.log_combat("Hit: %s -> %s for %d damage (x%.2f %s, impact=%.2f, hitlag=%.3fs)" % [
		unit_name, target.unit_name, damage, type_multiplier, effectiveness_text, impact_weight, hitlag_duration])

	# Apply status effect on first hit only
	if apply_status and move.status_effect_type != Enums.StatusEffectType.NONE:
		StatusEffectSystem.apply_status_effect(self, target, move)

	# Check passive triggers (e.g. Bellows: air hit grants fire buff)
	StatusEffectSystem.check_passive_triggers_on_hit(self, target, move)


## Boop out: sprite bumps toward the target. Awaitable — completes at the contact point.
func _play_boop_out(target: Unit) -> void:
	if _sprite == null or target == null:
		await get_tree().create_timer(0.08).timeout
		return
	var direction := (target.global_position - global_position).normalized()
	var boop_offset := direction * BOOP_DISTANCE
	var tween := create_tween()
	tween.tween_property(_sprite, "position", boop_offset, 0.08).set_ease(Tween.EASE_OUT)
	await tween.finished


## Boop return: sprite snaps back to center. Fire-and-forget (not awaited).
func _play_boop_return() -> void:
	if _sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "position", Vector2.ZERO, 0.12).set_ease(Tween.EASE_IN)


func _spawn_damage_popup(target: Unit, damage: int, effectiveness_text: String, multiplier: float) -> void:
	var popup_scene := preload("res://scenes/ui/damage_popup.tscn")
	var popup: Node2D = popup_scene.instantiate()
	popup.global_position = target.global_position + Vector2(0, -8)
	popup.z_index = target.z_index + 2  # UNITS layer + 2 = UI layer, always above defending unit
	get_tree().current_scene.add_child(popup)
	if popup.has_method("initialize"):
		popup.call("initialize", damage, effectiveness_text, multiplier)


## Handle unit defeat: gray out, fade, clear tile.
func _handle_defeat() -> void:
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
	if character_data.sprite_sheet_path == "" or character_data.sprite_atlas_path == "":
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
	var sprite_top := _sprite.offset.y - _sprite.texture.get_height() / 2.0
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
