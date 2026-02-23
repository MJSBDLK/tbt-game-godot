## A unit on the battle grid — player, enemy, or neutral.
## Satisfies GridManager's duck-typed interface for movement range and pathfinding.
## Ported from Unity's Unit.cs (pre-combat section, ~873 lines).
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


# =============================================================================
# CONSTANTS
# =============================================================================

const MOVEMENT_SCALE: int = 2
const MOVE_SPEED: float = 200.0  # Pixels per second


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
var current_hp: int = 0
var assigned_move: Move = null  # Phase 3: currently selected move for targeting

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
	if current_hp <= 0:
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
