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
const MOVE_SPEED: float = 200.0  # Pixels per second
const HIT_DELAY: float = 0.3  # Seconds between combat hits


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
		return character_data.move_distance * MOVEMENT_SCALE


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

var _start_tile_before_move: Tile = null
var _selection_tween: Tween = null

# Child node references
var _sprite: Sprite2D = null
var _health_bar_background: ColorRect = null
var _health_bar_fill: ColorRect = null
var _path_visualizer: Node2D = null  # PathVisualizer


# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_sprite = $Sprite2D as Sprite2D
	_health_bar_background = $HealthBar/Background as ColorRect
	_health_bar_fill = $HealthBar/Fill as ColorRect
	if has_node("PathVisualizer"):
		_path_visualizer = $PathVisualizer


func initialize(starting_tile: Tile) -> void:
	# Load character data from JSON
	if character_json_path != "":
		character_data = CharacterDataLoader.load_character(character_json_path)
	if character_data == null:
		character_data = CharacterData.new()
		DebugConfig.log_error("Unit '%s': No character data loaded" % unit_name)

	# Sync name
	unit_name = character_data.character_name
	name = "Unit_%s" % unit_name

	# Place on starting tile
	move_to_tile(starting_tile)

	# Init HP
	current_hp = character_data.max_hp

	# Visuals
	_apply_faction_color()
	_update_z_index()
	_update_health_bar()

	can_act = true
	is_selected = false

	DebugConfig.log_unit_init("Unit '%s' at %s | faction=%s type=%s HP=%d move=%d" % [
		unit_name, starting_tile.get_coordinates(),
		Enums.UnitFaction.keys()[faction],
		Enums.elemental_type_to_string(character_data.primary_type),
		current_hp, character_data.move_distance])


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
	_start_tile_before_move = null
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
		GameColors.UNIT_SELECTED, 0.4)
	_selection_tween.tween_property(_sprite, "modulate",
		GameColors.brightened(GameColors.UNIT_SELECTED, 1.3), 0.4)


func _stop_selection_pulse() -> void:
	if _selection_tween != null:
		_selection_tween.kill()
		_selection_tween = null
	if can_act:
		_apply_faction_color()
	else:
		if _sprite != null:
			_sprite.modulate = GameColors.UNIT_ACTED


# =============================================================================
# TURN STATE
# =============================================================================

func refresh_unit() -> void:
	can_act = true
	_start_tile_before_move = current_tile
	_apply_faction_color()


func set_acted() -> void:
	can_act = false
	if _sprite != null:
		_sprite.modulate = GameColors.UNIT_ACTED


# =============================================================================
# HEALTH
# =============================================================================

func take_damage(amount: int) -> void:
	current_hp = maxi(0, current_hp - amount)
	_update_health_bar()
	health_changed.emit(self, current_hp, character_data.max_hp)
	if current_hp <= 0 and not is_defeated_flag:
		is_defeated_flag = true
		unit_defeated.emit(self)


func heal(amount: int) -> void:
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
	_health_bar_fill.color = GameColors.get_health_color(health_percent)


# =============================================================================
# COMBAT — MOVE ASSIGNMENT
# =============================================================================

func assign_move(move: Move) -> void:
	assigned_move = move


func auto_assign_first_usable_move() -> void:
	if character_data == null:
		return
	for move: Move in character_data.equipped_moves:
		if move.has_uses_remaining() and not StatusEffectSystem.is_move_locked(self, character_data.equipped_moves.find(move)):
			assigned_move = move
			return
	assigned_move = null


func is_defeated() -> bool:
	return current_hp <= 0


# =============================================================================
# COMBAT — SEQUENCE EXECUTION
# =============================================================================

## Execute a full combat sequence: attacker hits, counter-attacks, bonus hits.
## This is an async method — caller must await it.
func execute_combat_sequence(defender: Unit, attacker_move: Move) -> void:
	if defender == null or attacker_move == null:
		return

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
func _execute_single_hit(target: Unit, move: Move, apply_status: bool) -> void:
	# Stub attack animation
	if move.damage_type == Enums.DamageType.PHYSICAL:
		await _play_physical_attack_stub()
	else:
		await _play_special_attack_stub()

	var damage := DamageCalculator.calculate_damage(self, target, move)
	var type_multiplier := DamageCalculator.get_type_effectiveness(self, target, move)
	var effectiveness_text := TypeChart.get_effectiveness_text(type_multiplier)

	target.take_damage(damage)
	combat_hit.emit(self, target, damage)

	# Spawn damage popup
	_spawn_damage_popup(target, damage, effectiveness_text, type_multiplier)

	DebugConfig.log_combat("Hit: %s -> %s for %d damage (x%.2f %s)" % [
		unit_name, target.unit_name, damage, type_multiplier, effectiveness_text])

	# Apply status effect on first hit only
	if apply_status and move.status_effect_type != Enums.StatusEffectType.NONE:
		StatusEffectSystem.apply_status_effect(self, target, move)


func _play_physical_attack_stub() -> void:
	# Quick bump animation toward target direction
	await get_tree().create_timer(0.15).timeout


func _play_special_attack_stub() -> void:
	# Slightly longer delay for special attacks
	await get_tree().create_timer(0.25).timeout


func _spawn_damage_popup(target: Unit, damage: int, effectiveness_text: String, multiplier: float) -> void:
	var popup_scene := preload("res://scenes/ui/damage_popup.tscn")
	var popup: Node2D = popup_scene.instantiate()
	popup.global_position = target.global_position + Vector2(0, -8)
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
		_sprite.modulate = GameColors.UNIT_ACTED

	# Hide health bar
	if _health_bar_background != null:
		_health_bar_background.visible = false
	if _health_bar_fill != null:
		_health_bar_fill.visible = false

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

func _apply_faction_color() -> void:
	if _sprite == null:
		return
	match faction:
		Enums.UnitFaction.PLAYER:
			_sprite.modulate = GameColors.PLAYER_UNIT
		Enums.UnitFaction.ENEMY:
			_sprite.modulate = GameColors.ENEMY_UNIT
		Enums.UnitFaction.NEUTRAL:
			_sprite.modulate = GameColors.NEUTRAL_UNIT


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
	var row_index: int = (offset_y + height - 1) - current_tile.grid_y
	z_index = ZIndexCalculator.calculate_sorting_order(row_index, 100, ZIndexCalculator.ZIndexLayer.UNITS)
