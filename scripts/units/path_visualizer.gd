## Visualizes the planned movement path for a unit using animated beacons.
## Each tile along the path gets a non-rotated beacon sprite. Beacons play a
## 5-step pulse (idle -> mid -> dipped -> mid -> idle) staggered along the path
## so the wave appears to travel from the unit toward the destination. After
## the last tile resolves to idle, the cycle holds for CYCLE_PAUSE_MS, then
## loops. Beacon color follows unit faction: blue for player, red for enemy.
## Set as top_level in unit.tscn so positions are in world space.
class_name PathVisualizer
extends Node2D


const FRAME_SIZE: Vector2i = Vector2i(9, 9)

# Animation timings (milliseconds). Tune at playtest.
const FRAME_DURATION_MS: float = 125
const TILE_DELAY_MS: float = 200.0
const CYCLE_PAUSE_MS: float = 400.0

# Strip layout: 3 frames laid out horizontally, 9px each. Index 2 (last) is the
# idle/rest pose; index 0 is the deepest part of the dip. Sequence opens and
# closes on idle so wave-start/end blend invisibly into the rest state.
const WAVE_SEQUENCE: Array[int] = [2, 1, 0, 1, 2]
const IDLE_STRIP_INDEX: int = 2

const _BEACON_BLUE: Texture2D = preload("res://art/sprites/ui/move_preview/path_beacon/blue.png")
const _BEACON_RED: Texture2D = preload("res://art/sprites/ui/move_preview/path_beacon/red.png")


var _path_tiles: Array[Tile] = []
var _faction: Enums.UnitFaction = Enums.UnitFaction.PLAYER
var _beacon_sprites: Array[Sprite2D] = []
var _animation_time_ms: float = 0.0


func _ready() -> void:
	z_index = ZIndexCalculator.calculate_sorting_order(
		0, 100, ZIndexCalculator.ZIndexLayer.PATH_INDICATORS)


func update_path(unit: Node2D) -> void:
	_faction = unit.get("faction")

	var current_tile: Tile = unit.get("current_tile")
	var planned_waypoints: Array = unit.get("planned_waypoints")

	var full_path: Array[Tile] = []
	if current_tile != null and not planned_waypoints.is_empty():
		var start: Tile = current_tile
		for waypoint: Variant in planned_waypoints:
			var segment := GridManager.find_path(start, waypoint.tile, unit)
			for tile: Tile in segment:
				if not full_path.has(tile):
					full_path.append(tile)
			start = waypoint.tile

	_path_tiles = full_path
	_animation_time_ms = 0.0
	_rebuild_beacon_nodes()


func clear_arrows() -> void:
	_path_tiles.clear()
	_rebuild_beacon_nodes()


func _process(delta: float) -> void:
	if _beacon_sprites.is_empty():
		return
	_animation_time_ms += delta * 1000.0

	var wave_duration_ms: float = WAVE_SEQUENCE.size() * FRAME_DURATION_MS
	var last_start_ms: float = (_beacon_sprites.size() - 1) * TILE_DELAY_MS
	var cycle_total_ms: float = last_start_ms + wave_duration_ms + CYCLE_PAUSE_MS
	var t_in_cycle: float = fmod(_animation_time_ms, cycle_total_ms)

	for index: int in range(_beacon_sprites.size()):
		var sprite: Sprite2D = _beacon_sprites[index]
		var atlas: AtlasTexture = sprite.texture as AtlasTexture
		if atlas == null:
			continue

		var local_t: float = t_in_cycle - index * TILE_DELAY_MS
		var frame_index: int = IDLE_STRIP_INDEX
		if local_t >= 0.0 and local_t < wave_duration_ms:
			var seq_index: int = int(local_t / FRAME_DURATION_MS)
			seq_index = clamp(seq_index, 0, WAVE_SEQUENCE.size() - 1)
			frame_index = WAVE_SEQUENCE[seq_index]

		atlas.region = Rect2(frame_index * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)


func _rebuild_beacon_nodes() -> void:
	for sprite: Sprite2D in _beacon_sprites:
		sprite.queue_free()
	_beacon_sprites.clear()

	if _path_tiles.is_empty():
		return

	var strip: Texture2D = _BEACON_RED if _faction == Enums.UnitFaction.ENEMY else _BEACON_BLUE

	for tile: Tile in _path_tiles:
		var sprite := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = strip
		atlas.region = Rect2(IDLE_STRIP_INDEX * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		sprite.texture = atlas
		sprite.global_position = tile.global_position
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		_beacon_sprites.append(sprite)
