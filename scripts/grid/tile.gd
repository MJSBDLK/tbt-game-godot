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
var defense_multiplier: float = 1.0
var avoid_multiplier: float = 1.0
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
	_load_terrain_sprite()


## Reload terrain properties from TerrainDataManager for the current terrain type.
func refresh_terrain_properties(unit_type: String = "") -> void:
	var terrain_manager: Node = get_node_or_null("/root/TerrainDataManager")
	if terrain_manager == null:
		return

	walkable = 1.0 if terrain_manager.can_unit_walk_on_terrain(terrain_type_name, unit_type) else 0.0
	move_penalty = terrain_manager.get_movement_cost(terrain_type_name, unit_type)
	attack_multiplier = terrain_manager.get_attack_multiplier(terrain_type_name, unit_type)
	defense_multiplier = terrain_manager.get_defense_multiplier(terrain_type_name, unit_type)
	avoid_multiplier = terrain_manager.get_avoid_multiplier(terrain_type_name, unit_type)

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


func get_defense_multiplier_for_unit(unit_type: String = "") -> float:
	var terrain_manager: Node = get_node_or_null("/root/TerrainDataManager")
	if terrain_manager != null:
		return terrain_manager.get_defense_multiplier(terrain_type_name, unit_type)
	return defense_multiplier


func get_avoid_multiplier_for_unit(unit_type: String = "") -> float:
	var terrain_manager: Node = get_node_or_null("/root/TerrainDataManager")
	if terrain_manager != null:
		return terrain_manager.get_avoid_multiplier(terrain_type_name, unit_type)
	return avoid_multiplier


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

func _load_terrain_sprite() -> void:
	# The TileMapLayer displays the actual tileset art. The Tile sprite is only
	# used as a color overlay for highlights (movement range, selection, hover).
	# Start fully transparent so it doesn't overdraw the tilemap.
	if _sprite != null:
		_sprite.modulate = Color.TRANSPARENT


func set_color(color: Color) -> void:
	if _sprite == null:
		return
	# TILE_DEFAULT (white) means "no highlight" — make the overlay fully transparent.
	# Any other color is a highlight (movement range, attack range, hover, selected)
	# shown as a semi-transparent overlay on top of the TileMapLayer art.
	if color == Color.WHITE:
		_sprite.modulate = Color.TRANSPARENT
	else:
		_sprite.modulate = Color(color, 0.45)


# =============================================================================
# TEXTURE EXTRACTION
# =============================================================================

## Returns the tile's visual texture from the TileMapLayer tileset.
## Used by UI panels that need a snapshot of what this tile looks like.
## Prefers the modifier covering this cell (three-tier rule: the modifier
## IS this tile's identity when present); falls back to the floor art.
func get_tile_texture() -> Texture2D:
	var builder: Node = get_parent().get_parent()  # Tiles -> TilemapGridBuilder
	if builder == null:
		return null

	# Convert game-grid coords back to tilemap cell coords (Y-flip)
	var cell := Vector2i(grid_x, -grid_y)

	var modifier_layer: TileMapLayer = builder.get_node_or_null("ModifierTileLayer") as TileMapLayer
	var modifier_texture := _texture_from_modifier_layer(modifier_layer, cell)
	if modifier_texture != null:
		return modifier_texture

	var floor_layer: TileMapLayer = builder.get_node_or_null("TerrainTileLayer") as TileMapLayer
	if floor_layer == null:
		return null
	return _texture_from_layer_cell(floor_layer, cell, cell)


## Texture for the modifier covering `cell`, or null when none does. The
## layer stores only each modifier's anchor (NW) cell, so cells covered by
## a multi-cell footprint (e.g. the other 3 cells of a 2x2 castle) need a
## scan over painted anchors testing footprint rects.
func _texture_from_modifier_layer(layer: TileMapLayer, cell: Vector2i) -> Texture2D:
	if layer == null:
		return null
	# Fast path: the cell itself is an anchor.
	if layer.get_cell_source_id(cell) >= 0:
		return _texture_from_layer_cell(layer, cell, cell)
	# Slow path: any anchor whose footprint rect covers this cell.
	for anchor: Vector2i in layer.get_used_cells():
		var source := layer.tile_set.get_source(layer.get_cell_source_id(anchor)) as TileSetAtlasSource
		if source == null:
			continue
		var footprint: Vector2i = source.get_tile_size_in_atlas(layer.get_cell_atlas_coords(anchor))
		if Rect2i(anchor, footprint).has_point(cell):
			return _texture_from_layer_cell(layer, anchor, cell)
	return null


## AtlasTexture for the painted tile at `painted_cell` on `layer`. When the
## tile is multi-cell, returns just the one 32x32 sub-cell corresponding to
## `query_cell` so the preview shows the chunk the cursor is actually on.
func _texture_from_layer_cell(layer: TileMapLayer, painted_cell: Vector2i, query_cell: Vector2i) -> Texture2D:
	var source_id := layer.get_cell_source_id(painted_cell)
	if source_id < 0:
		return null
	var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null:
		return null

	var atlas_coords := layer.get_cell_atlas_coords(painted_cell)
	var region := source.get_tile_texture_region(atlas_coords)

	# Multi-cell tile: narrow the region to the 32x32 sub-cell under query_cell.
	var cell_offset := query_cell - painted_cell
	if cell_offset != Vector2i.ZERO:
		var cell_px: Vector2i = layer.tile_set.tile_size
		region = Rect2i(
				region.position + Vector2i(cell_offset.x * cell_px.x, cell_offset.y * cell_px.y),
				cell_px)

	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = source.texture
	atlas_texture.region = region
	return atlas_texture


# =============================================================================
# UTILITY
# =============================================================================

func get_coordinates() -> String:
	return "[%d,%d]" % [grid_x, grid_y]
