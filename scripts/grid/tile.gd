## A single grid tile with terrain properties loaded from TerrainDataManager.
## Coordinates are INTEGER only: (0,0), (1,0), (2,0), etc.
## Created at runtime by TilemapGridBuilder from TileMapLayer data.
class_name Tile
extends Node2D


# Grid coordinates (integer only, never fractional)
var grid_x: int = 0
var grid_y: int = 0

# Terrain type name matching terrain_data.json keys
var terrain_type_name: String = "Plains"

# Cached terrain properties (refreshed from TerrainDataManager)
var walkable: float = 1.0
var move_penalty: float = 1.0
var attack_multiplier: float = 1.0
var defense_modifier: float = 0.0
var avoid_modifier: float = 0.0
var terrain_status_immunity: Array[String] = []

# Reference to the unit currently standing on this tile (null if empty)
var current_unit: Node2D = null

# Child node references
var _sprite: Sprite2D = null


func _ready() -> void:
	_sprite = $Sprite2D as Sprite2D


func initialize(x: int, y: int) -> void:
	grid_x = x
	grid_y = y
	name = "Tile_%d_%d" % [x, y]
	refresh_terrain_properties()


## Reload terrain properties from TerrainDataManager for the current terrain type.
func refresh_terrain_properties(unit_type: String = "") -> void:
	var terrain_manager: Node = get_node_or_null("/root/TerrainDataManager")
	if terrain_manager == null:
		return

	walkable = 1.0 if terrain_manager.can_unit_walk_on_terrain(terrain_type_name, unit_type) else 0.0
	move_penalty = terrain_manager.get_movement_cost(terrain_type_name, unit_type)
	attack_multiplier = terrain_manager.get_attack_multiplier(terrain_type_name, unit_type)
	defense_modifier = terrain_manager.get_defense_modifier(terrain_type_name, unit_type)
	avoid_modifier = terrain_manager.get_avoid_modifier(terrain_type_name, unit_type)

	var definition: Variant = terrain_manager.get_terrain_definition(terrain_type_name)
	if definition != null:
		terrain_status_immunity = definition.terrain_status_immunity.duplicate()


# =============================================================================
# QUERIES
# =============================================================================

## Whether this tile is empty and a unit of the given type can walk here.
func can_move_to(unit_type: String = "") -> bool:
	return can_unit_move_to(unit_type) and current_unit == null


## Whether the terrain allows the given unit type to enter (ignores occupancy).
func can_unit_move_to(unit_type: String = "") -> bool:
	var terrain_manager: Node = get_node_or_null("/root/TerrainDataManager")
	if terrain_manager != null:
		return terrain_manager.can_unit_walk_on_terrain(terrain_type_name, unit_type)
	# Fallback if manager not loaded
	return walkable > 0.0


func get_movement_cost_for_unit(unit_type: String = "") -> float:
	var terrain_manager: Node = get_node_or_null("/root/TerrainDataManager")
	if terrain_manager != null:
		return terrain_manager.get_movement_cost(terrain_type_name, unit_type)
	return move_penalty


func get_attack_multiplier_for_unit(unit_type: String = "") -> float:
	var terrain_manager: Node = get_node_or_null("/root/TerrainDataManager")
	if terrain_manager != null:
		return terrain_manager.get_attack_multiplier(terrain_type_name, unit_type)
	return attack_multiplier


func get_defense_modifier_for_unit(unit_type: String = "") -> float:
	var terrain_manager: Node = get_node_or_null("/root/TerrainDataManager")
	if terrain_manager != null:
		return terrain_manager.get_defense_modifier(terrain_type_name, unit_type)
	return defense_modifier


func get_avoid_modifier_for_unit(unit_type: String = "") -> float:
	var terrain_manager: Node = get_node_or_null("/root/TerrainDataManager")
	if terrain_manager != null:
		return terrain_manager.get_avoid_modifier(terrain_type_name, unit_type)
	return avoid_modifier


# =============================================================================
# UNIT MANAGEMENT
# =============================================================================

func set_unit(unit: Node2D) -> void:
	current_unit = unit
	if unit != null:
		unit.global_position = global_position


func clear_unit() -> void:
	current_unit = null


# =============================================================================
# VISUAL
# =============================================================================

func set_color(color: Color) -> void:
	if _sprite != null:
		_sprite.modulate = color


# =============================================================================
# UTILITY
# =============================================================================

func get_coordinates() -> String:
	return "[%d,%d]" % [grid_x, grid_y]
