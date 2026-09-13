## Runtime overlay that lays directional foot-track sprites along the path a
## unit actually walked. Mirrors TerrainSpriteRenderer/PathVisualizer: per-cell
## Sprite2D nodes, NEAREST filter, per-row z via ZIndexCalculator (FOOT_TRACKS
## band, beneath terrain effects/modifiers). Tracks stack where paths cross,
## capped at `max_depth`; the newest renders on top (sibling draw order at
## equal z, so no per-sprite z-fighting math is needed).
##
## Variant selection (which terrain's tracks) is FootTrackLibrary; direction
## selection (which cell of the variant) is FootTrackDirections. See
## data/design/foot_tracks.md.
class_name FootTrackRenderer
extends Node2D

## How the two interchangeable straight variants (SN/NS, WE/EW) are chosen along
## a run, to avoid a repeating-texture corridor.
enum StraightMode { ALTERNATE, RANDOMIZE }

## When laid tracks are removed. Only WHOLE_BATTLE is wired in V1; the others are
## reserved playtest knobs (they need turn signals to drive).
enum Persistence { WHOLE_BATTLE, FADE_AFTER_TURNS, CLEAR_EACH_TURN }

@export var max_depth: int = 4
@export var straight_mode: StraightMode = StraightMode.ALTERNATE
@export var persistence: Persistence = Persistence.WHOLE_BATTLE

var _library: FootTrackLibrary = null
var _cosmetic_rng: RandomNumberGenerator = null
# grid cell (Vector2i) -> Array[Sprite2D], oldest first
var _cell_stacks: Dictionary = {}


func _ready() -> void:
	max_depth = maxi(1, max_depth)
	_library = FootTrackLibrary.new()
	_library.load_library()
	# Dedicated cosmetic RNG — never the gameplay RNG, so randomized variant
	# picks can't perturb crit/AI sequences.
	_cosmetic_rng = RandomNumberGenerator.new()
	_cosmetic_rng.randomize()


## Connect to every battle unit's path_traversed signal. Call from BattleScene
## after units spawn (mirrors PassiveEffectsSystem.register_battle_units).
func register_battle_units(player_units: Array[Unit], enemy_units: Array[Unit]) -> void:
	for unit in player_units:
		_connect_unit(unit)
	for unit in enemy_units:
		_connect_unit(unit)


func _connect_unit(unit: Unit) -> void:
	if unit == null:
		return
	if not unit.path_traversed.is_connected(_on_path_traversed):
		unit.path_traversed.connect(_on_path_traversed)


func _on_path_traversed(_unit: Unit, tiles: Array) -> void:
	lay_path(tiles)


## Lay tracks for a walked path: `tiles` is the committed route (start tile
## first, duplicates preserved). Each tile gets a directional track for its
## terrain's variant, if one exists.
func lay_path(tiles: Array) -> void:
	if _library == null or tiles.size() < 2:
		return
	var straight_counter := 0
	for i in range(tiles.size()):
		var tile: Tile = tiles[i]
		if tile == null:
			continue
		var variant := _library.variant_for_terrain(tile.terrain_type_name)
		if variant.is_empty():
			continue  # no tracks on this terrain
		var cur_cell := Vector2i(tile.grid_x, tile.grid_y)
		var edges := FootTrackDirections.connected_edges(
				_cell_of(tiles, i - 1), cur_cell, _cell_of(tiles, i + 1))
		var straight_pick := 0
		if FootTrackDirections.is_straight(edges):
			if straight_mode == StraightMode.RANDOMIZE:
				straight_pick = _cosmetic_rng.randi() & 1
			else:
				straight_pick = straight_counter & 1
				straight_counter += 1
		var direction := FootTrackDirections.label_for_edges(edges, straight_pick)
		if direction.is_empty():
			continue
		_spawn_track(tile, cur_cell, variant, direction)


## Grid cell of tiles[index], or null when out of range (a path endpoint).
func _cell_of(tiles: Array, index: int) -> Variant:
	if index < 0 or index >= tiles.size():
		return null
	var tile: Tile = tiles[index]
	if tile == null:
		return null
	return Vector2i(tile.grid_x, tile.grid_y)


func _spawn_track(tile: Tile, cell: Vector2i, variant: String, direction: String) -> void:
	var row := tile.grid_y - GridManager.grid_offset_y
	_spawn_at(tile.global_position, cell, row, variant, direction)


## Ingest a designer-painted seed layer: each painted cell becomes a depth-1
## track. A source texture's filename is the variant (regolith.png -> regolith);
## the atlas coord is the direction, reverse-looked-up via the sidecar. The
## runtime then stacks unit-walked tracks on top, up to max_depth. Call once at
## scene load. See data/design/foot_tracks.md "Stamp tiles".
func ingest_seed_layer(layer: TileMapLayer) -> void:
	if layer == null or layer.tile_set == null or _library == null:
		return
	var offset_y: int = GridManager.grid_offset_y
	for cell in layer.get_used_cells():
		var source_id := layer.get_cell_source_id(cell)
		if source_id < 0:
			continue
		var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null or source.texture == null:
			continue
		var variant := source.texture.resource_path.get_file().get_basename().to_lower()
		var direction := _library.direction_for_cell(variant, layer.get_cell_atlas_coords(cell))
		if direction.is_empty():
			continue
		# Tilemap cell (Y-down) -> game grid cell (Y-up), per tilemap_grid_builder.
		var grid_cell := Vector2i(cell.x, -cell.y)
		var row := grid_cell.y - offset_y
		_spawn_at(layer.to_global(layer.map_to_local(cell)), grid_cell, row, variant, direction)


## Spawn one track sprite at a world position and push it onto its cell's depth
## stack (newest on top; oldest dropped past max_depth).
func _spawn_at(world_position: Vector2, cell: Vector2i, row: int, variant: String, direction: String) -> void:
	var texture := _library.get_texture(variant)
	if texture == null:
		return
	var region := _library.get_cell_region(variant, direction)
	if region.size == Vector2.ZERO:
		return  # variant lacks this direction cell
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_as_relative = false
	add_child(sprite)
	sprite.global_position = world_position
	sprite.z_index = ZIndexCalculator.calculate_sorting_order(
			row, 100, ZIndexCalculator.ZIndexLayer.FOOT_TRACKS)

	var stack: Array = _cell_stacks.get(cell, [])
	stack.append(sprite)
	while stack.size() > max_depth:
		var oldest: Sprite2D = stack.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	_cell_stacks[cell] = stack
	# Runtime invariant: a cell never holds more than max_depth tracks.
	assert(stack.size() <= max_depth, "foot-track stack exceeded max_depth")


## Drop every track (battle teardown, or a CLEAR_EACH_TURN playtest pass).
func clear_all() -> void:
	for cell in _cell_stacks:
		for sprite in _cell_stacks[cell]:
			if is_instance_valid(sprite):
				sprite.queue_free()
	_cell_stacks.clear()
