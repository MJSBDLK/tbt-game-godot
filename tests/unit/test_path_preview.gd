## A selected unit that hasn't moved: the beacons preview the route to the
## tile under the pointer or cursor, inside the movement range left. Before a
## stop is plotted there's no ghost (the ghost marks a plotted plan); after
## one, the beacons run on from the last stop while the ghost keeps riding
## only the plotted route. A marker shows just the plan. Harness mirrors
## test_path_ghost.gd: real unit scenes on a real row of tiles.
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"


func before_each() -> void:
	GridManager.clear_grid()
	InputManager.deselect_unit()
	GameStateManager.change_state(Enums.InputState.DEFAULT)


func after_each() -> void:
	InputManager.deselect_unit()
	GameStateManager.change_state(Enums.InputState.DEFAULT)


func after_all() -> void:
	GridManager.clear_grid()


## A player spaceman at the west end of a row of `length` tiles.
func _selected_unit_on_a_row(length: int) -> Unit:
	for x: int in range(length):
		var tile := Tile.new()
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		tile.add_child(sprite)
		add_child_autofree(tile)
		tile.position = Vector2(x * 16, 0)
		tile.grid_x = x
		tile.terrain_type_name = "Plains"
		GridManager.register_tile(tile)
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = SPACEMAN_PATH
	unit.faction = Enums.UnitFaction.PLAYER
	add_child_autofree(unit)
	unit.initialize(GridManager.get_tile(0, 0))
	InputManager.select_unit(unit)
	return unit


func _beacons(unit: Unit) -> Array[Tile]:
	return (unit._path_visualizer as PathVisualizer)._path_tiles


func test_hovering_in_range_previews_the_path_without_a_ghost() -> void:
	var unit := _selected_unit_on_a_row(5)
	InputManager.hover_changed.emit(GridManager.get_tile(2, 0))
	assert_eq(_beacons(unit), [GridManager.get_tile(1, 0), GridManager.get_tile(2, 0)] as Array[Tile],
			"the beacons run from the unit to the tile under the cursor")
	assert_false((unit._path_visualizer as PathVisualizer).has_destination_ghost(),
			"no ghost until a path is plotted")
	InputManager.hover_changed.emit(GridManager.get_tile(0, 0))
	assert_true(_beacons(unit).is_empty(), "back on the unit: no path")


func test_outside_the_movement_range_shows_nothing() -> void:
	var unit := _selected_unit_on_a_row(16)
	var far := GridManager.get_tile(15, 0)
	assert_false(GridManager.is_in_current_movement_range(far), "precondition: out of reach")
	InputManager.hover_changed.emit(GridManager.get_tile(2, 0))
	InputManager.hover_changed.emit(far)
	assert_true(_beacons(unit).is_empty(), "out of range: the preview clears")


func _row(xs: Array) -> Array[Tile]:
	var tiles: Array[Tile] = []
	for x: int in xs:
		tiles.append(GridManager.get_tile(x, 0))
	return tiles


func test_after_a_stop_the_beacons_run_on_and_the_ghost_keeps_the_plan() -> void:
	var unit := _selected_unit_on_a_row(6)
	var visualizer := unit._path_visualizer as PathVisualizer
	InputManager._handle_movement_planning_press(GridManager.get_tile(2, 0))
	assert_true(visualizer.has_destination_ghost(), "plotted: the ghost joins")
	var ghost_route := visualizer._walk_floor_points
	assert_true(GridManager.is_in_current_movement_range(GridManager.get_tile(3, 0)),
			"precondition: movement left past the stop")
	InputManager.hover_changed.emit(GridManager.get_tile(3, 0))
	assert_eq(_beacons(unit), _row([1, 2, 3]), "the plan, then on to the cursor")
	assert_eq(visualizer._walk_floor_points, ghost_route, "the ghost rides only what's plotted")
	InputManager.hover_changed.emit(GridManager.get_tile(2, 0))
	assert_eq(_beacons(unit), _row([1, 2]), "on the marker: just the plan")


func test_with_the_movement_used_up_nothing_runs_on() -> void:
	var unit := _selected_unit_on_a_row(16)
	var farthest := 0
	while GridManager.is_in_current_movement_range(GridManager.get_tile(farthest + 1, 0)):
		farthest += 1
	InputManager._handle_movement_planning_press(GridManager.get_tile(farthest, 0))
	InputManager.hover_changed.emit(GridManager.get_tile(farthest + 1, 0))
	assert_eq(_beacons(unit).size(), farthest, "every step spent: the beacons stay the plan")


func test_deselecting_clears_the_preview() -> void:
	var unit := _selected_unit_on_a_row(5)
	InputManager.hover_changed.emit(GridManager.get_tile(2, 0))
	InputManager.deselect_unit()
	assert_true(_beacons(unit).is_empty())


func test_nothing_previews_without_a_selection() -> void:
	var unit := _selected_unit_on_a_row(5)
	InputManager.deselect_unit()
	GameStateManager.change_state(Enums.InputState.DEFAULT)
	InputManager.hover_changed.emit(GridManager.get_tile(2, 0))
	assert_true(_beacons(unit).is_empty())
