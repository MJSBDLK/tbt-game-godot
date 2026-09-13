## Marker presses during MOVEMENT_PLANNING (RQD 2026-09-10, the "nonsense
## path" bug): only the LAST marker confirms the plan; pressing an EARLIER
## marker backs the plan up to it (FE re-route) instead of executing. Before
## the fix every marker press executed, so a 3 → 2 → 3 plan committed 3 → 2 on
## the third press and the unit ended on 2. Drives the REAL InputManager press
## path (the one the mouse click and the board cursor's accept share), so a
## confirm here is the staged deferred walk exactly as in play: logic commits,
## the sprite waits behind the ghost, the action menu opens.
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"  # move 5


func before_each() -> void:
	GridManager.clear_grid()


func after_each() -> void:
	ActionMenuManager.hide_action_menu()
	InputManager._cancel_and_deselect()
	InputManager.enable_input()
	GameStateManager.clear_state_stack()
	GameStateManager.change_state(Enums.InputState.DEFAULT)


func after_all() -> void:
	GridManager.clear_grid()


## One row of Plains at real 16px spread so "the sprite stayed" is falsifiable.
func _open_row(max_x: int) -> void:
	for x: int in range(max_x + 1):
		var tile := Tile.new()
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		tile.add_child(sprite)
		add_child_autofree(tile)
		tile.position = Vector2(x * 16, 0)
		tile.grid_x = x
		tile.grid_y = 0
		tile.terrain_type_name = "Plains"
		GridManager.register_tile(tile)


func _spawn_player(x: int) -> Unit:
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = SPACEMAN_PATH
	unit.faction = Enums.UnitFaction.PLAYER
	add_child_autofree(unit)
	unit.initialize(GridManager.get_tile(x, 0))
	return unit


func _press(x: int) -> void:
	InputManager._handle_movement_planning_press(GridManager.get_tile(x, 0))


func _stops(unit: Unit) -> Array[int]:
	var xs: Array[int] = []
	for waypoint: Variant in unit.planned_waypoints:
		xs.append((waypoint.tile as Tile).grid_x)
	return xs


# =============================================================================
# THE BUG: 3 → 2 → 3
# =============================================================================

func test_pressing_an_earlier_marker_backs_the_plan_up_instead_of_committing() -> void:
	_open_row(4)
	var unit := _spawn_player(0)
	InputManager.select_unit(unit)
	_press(3)
	var cost_to_three: int = unit.get_total_planned_movement_cost()
	_press(2)
	assert_eq(_stops(unit), [3, 2] as Array[int], "precondition: the nonsense plan is drawn")
	assert_gt(unit.get_total_planned_movement_cost(), cost_to_three, "precondition: the detour costs")
	assert_eq(GameStateManager.current_state, Enums.InputState.MOVEMENT_PLANNING)

	_press(3)
	assert_eq(_stops(unit), [3] as Array[int], "the earlier marker is now the last stop")
	assert_eq(unit.current_tile, GridManager.get_tile(0, 0), "nothing committed")
	assert_false(unit.has_deferred_walk(), "nothing staged")
	assert_lt(unit.global_position.distance_to(GridManager.get_tile(0, 0).global_position), 0.5,
			"the sprite is still on the start tile")
	assert_eq(GameStateManager.current_state, Enums.InputState.MOVEMENT_PLANNING,
			"still planning — backing up is not a confirm")
	assert_eq(unit.get_total_planned_movement_cost(), cost_to_three,
			"the kept stop's cumulative cost survives untouched")
	var visualizer: PathVisualizer = unit._path_visualizer as PathVisualizer
	assert_eq(visualizer._path_tiles.size(), 3, "beacons redraw from the shortened plan (0→3)")
	assert_true(visualizer.has_destination_ghost(), "the ghost re-parks on the new last stop")


func test_pressing_the_backed_up_marker_again_confirms_the_plan_there() -> void:
	_open_row(4)
	var unit := _spawn_player(0)
	InputManager.select_unit(unit)
	_press(3)
	_press(2)
	_press(3)  # back up
	_press(3)  # confirm
	var origin: Tile = GridManager.get_tile(0, 0)
	var destination: Tile = GridManager.get_tile(3, 0)
	assert_eq(unit.current_tile, destination, "3 → 2 → 3 commits to 3, not 2")
	assert_true(unit.has_deferred_walk(), "logic committed; the walk waits for the action")
	assert_lt(unit.global_position.distance_to(origin.global_position), 0.5,
			"the sprite waits at the origin behind the ghost")
	await unit.play_deferred_walk()
	assert_lt(unit.global_position.distance_to(destination.global_position), 0.5,
			"…and walks the confirmed path when the action commits")


# =============================================================================
# THE CONFIRM GESTURE STAYS: the last marker's second press commits
# =============================================================================

func test_pressing_the_last_marker_still_confirms_the_plan() -> void:
	_open_row(3)
	var unit := _spawn_player(0)
	InputManager.select_unit(unit)
	_press(2)
	_press(2)
	assert_eq(unit.current_tile, GridManager.get_tile(2, 0))
	assert_true(unit.has_deferred_walk())
	assert_eq(GameStateManager.current_state, Enums.InputState.ACTION_MENU_OPEN,
			"the confirm hands off to the action menu as before")


# =============================================================================
# Unit.truncate_waypoints_to on its own
# =============================================================================

func test_truncate_to_a_tile_that_is_not_a_stop_changes_nothing() -> void:
	_open_row(3)
	var unit := _spawn_player(0)
	assert_true(unit.add_waypoint(GridManager.get_tile(2, 0)))
	assert_false(unit.truncate_waypoints_to(GridManager.get_tile(1, 0)),
			"a pass-through tile is not a stop")
	assert_false(unit.truncate_waypoints_to(null))
	assert_eq(_stops(unit), [2] as Array[int], "the plan is untouched")


func test_truncate_keeps_stops_up_to_and_including_the_tile() -> void:
	_open_row(4)
	var unit := _spawn_player(0)
	assert_true(unit.add_waypoint(GridManager.get_tile(1, 0)))
	assert_true(unit.add_waypoint(GridManager.get_tile(2, 0)))
	var cost_to_two: int = unit.get_total_planned_movement_cost()
	assert_true(unit.add_waypoint(GridManager.get_tile(3, 0)))
	assert_true(unit.truncate_waypoints_to(GridManager.get_tile(2, 0)))
	assert_eq(_stops(unit), [1, 2] as Array[int])
	assert_eq(unit.get_total_planned_movement_cost(), cost_to_two)
