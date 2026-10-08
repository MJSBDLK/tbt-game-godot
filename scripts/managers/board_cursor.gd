## BoardCursor: the CURSOR model's "you are here" on the board, the §14
## brackets (GridManager.display_target_cursor) on one tile. Two cursors share
## the one renderer and never coexist: the FREE cursor roams the whole grid in
## the map-view states (FE-style: select, plan, act without a pointer); the
## AIM cursor snaps between an attack's valid targets. InputManager owns this,
## decides which cursor a state wants and where it summons, and turns `moved`
## into the hover. Holding a direction keeps stepping (hold / repeat_due).
class_name BoardCursor
extends RefCounted


## Every placement. The owner makes the tile the hover; `aimed` = the AIM cursor.
signal moved(tile: Tile, aimed: bool)

## Hold-to-repeat's first step waits this long; the rest ride the player's
## Options "Cursor Speed" (Settings.cursor_repeat_interval_seconds). OS key
## echo is ignored (InputSource.navigation_direction filters it): joypads never
## echo, so this one timer serves keyboard, d-pad and stick alike.
const REPEAT_DELAY_SECONDS: float = 0.35

## Null = no cursor: the pointer is driving, or a menu owns the brackets.
var free_tile: Tile = null
var aim_tile: Tile = null

var _held_direction: Vector2i = Vector2i.ZERO
var _repeat_at: float = 0.0


func has_free() -> bool:
	return free_tile != null and is_instance_valid(free_tile)


func place_free(tile: Tile) -> void:
	free_tile = tile
	_show(tile, false)


func place_aim(tile: Tile) -> void:
	aim_tile = tile
	_show(tile, true)


func clear_free() -> void:
	if free_tile == null:
		return
	free_tile = null
	GridManager.clear_target_cursor()


func clear_aim() -> void:
	aim_tile = null
	GridManager.clear_target_cursor()


## One grid step in a screen direction; the map edge or a hole holds it.
func roam(direction: Vector2i) -> void:
	assert(has_free(), "BoardCursor.roam: summon the free cursor first")
	# Screen convention (up = -y) → Y-up game grid: flip the vertical.
	var next := GridManager.get_tile(free_tile.grid_x + direction.x, free_tile.grid_y - direction.y)
	if next != null:
		place_free(next)


## To the nearest of `targets` lying the pressed way; nothing that way holds it.
func aim(direction: Vector2i, targets: Array[Tile]) -> void:
	assert(aim_tile != null, "BoardCursor.aim: adopt a target first")
	# The same vertical flip as roam: without it "up" walked the cursor to the
	# target visually BELOW.
	var index := pick_target_in_direction(Vector2i(aim_tile.grid_x, aim_tile.grid_y),
			cells_of(targets), Vector2i(direction.x, -direction.y))
	if index >= 0:
		place_aim(targets[index])


## Summon the AIM cursor onto the target nearest `origin` (the attacker).
func adopt(targets: Array[Tile], origin: Vector2i) -> void:
	var index := pick_initial_target(origin, cells_of(targets))
	if index >= 0:
		place_aim(targets[index])


func _show(tile: Tile, aimed: bool) -> void:
	GridManager.display_target_cursor(tile)
	moved.emit(tile, aimed)
	# FE courtesy: a step near (or past) the view edge glides the camera just
	# far enough to keep the brackets comfortably on screen.
	var camera := SceneRouter.get_world_camera() as CameraController
	if camera != null:
		camera.ensure_point_visible(tile.global_position, float(GridManager.tile_size) * 1.5)


# =============================================================================
# HOLD-TO-REPEAT
# =============================================================================

## A direction was pressed at `now`: the first repeat waits REPEAT_DELAY_SECONDS.
func hold(direction: Vector2i, now: float) -> void:
	_held_direction = direction
	_repeat_at = now + REPEAT_DELAY_SECONDS


func release() -> void:
	_held_direction = Vector2i.ZERO


## The direction to step at `now`, or ZERO. Letting go of the direction, or
## the pointer taking over, disarms it. `now` is injected for GUT.
func repeat_due(now: float) -> Vector2i:
	if _held_direction == Vector2i.ZERO:
		return Vector2i.ZERO
	if not InputSource.is_cursor_driven():
		release()
		return Vector2i.ZERO
	var action: StringName = InputSource.action_for_direction(_held_direction)
	if action == &"" or not Input.is_action_pressed(action):
		release()
		return Vector2i.ZERO
	if now < _repeat_at:
		return Vector2i.ZERO
	_repeat_at = now + Settings.cursor_repeat_interval_seconds()
	return _held_direction


# =============================================================================
# GEOMETRY — pure + static for GUT
# =============================================================================

static func cells_of(tiles: Array[Tile]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for tile: Tile in tiles:
		cells.append(Vector2i(tile.grid_x, tile.grid_y))
	return cells


## Nearest candidate in the pressed direction's half-plane: candidates behind
## or perpendicular to the press never win; among the rest, straight-ahead
## beats diagonal drift (sideways distance counts double). Returns an index
## into `candidates`, or -1 when nothing lies that way — the cursor then
## stays put rather than wrapping.
static func pick_target_in_direction(current: Vector2i, candidates: Array[Vector2i],
		direction: Vector2i) -> int:
	var best := -1
	var best_score := 0
	for i: int in candidates.size():
		var delta := candidates[i] - current
		if delta == Vector2i.ZERO:
			continue
		var along := delta.x * direction.x + delta.y * direction.y
		if along <= 0:
			continue
		var across := absi(delta.x * direction.y) + absi(delta.y * direction.x)
		var score := along + across * 2
		if best == -1 or score < best_score:
			best = i
			best_score = score
	return best


## The summon target for a fresh AIM cursor: nearest candidate to the
## attacker (Manhattan), first-listed wins ties.
static func pick_initial_target(origin: Vector2i, candidates: Array[Vector2i]) -> int:
	var best := -1
	var best_distance := 0
	for i: int in candidates.size():
		var distance := absi(candidates[i].x - origin.x) + absi(candidates[i].y - origin.y)
		if best == -1 or distance < best_distance:
			best = i
			best_distance = distance
	return best
