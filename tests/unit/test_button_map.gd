## The board's context-sensitive buttons, InputManager's side. Next /
## previous unit (E / Q, RB / LB, touch's Next) selects the next player unit
## that can still act, in roster order and wrapping, counting from the
## selected unit or the one under the cursor; it works only on the open board.
## The info button (I / Y) with no unit to read shows the type icons instead.
## Back (right click) steps back like Escape but never opens the system menu.
## The zone button's side is in test_threat_overlay_controller.
extends GutTest


var _units: Array[Unit] = []
var _type_icons_were: bool = false


func before_each() -> void:
	GridManager.clear_grid()
	InputManager.deselect_unit()
	InputManager.enable_input()
	InputManager._hovered_tile = null
	GameStateManager.change_state(Enums.InputState.DEFAULT)
	for x: int in range(0, 6):
		var tile := Tile.new()
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		tile.add_child(sprite)
		add_child_autofree(tile)
		tile.grid_x = x
		tile.terrain_type_name = "Plains"
		GridManager.register_tile(tile)
	_units = [_unit_at(0), _unit_at(2), _unit_at(4)] as Array[Unit]
	TurnManager._player_units = _units
	_type_icons_were = Settings.unit_type_icons_enabled


func after_each() -> void:
	InputManager.deselect_unit()
	InputManager._hovered_tile = null
	TurnManager._player_units = ([] as Array[Unit])
	Settings.unit_type_icons_enabled = _type_icons_were  # direct write: tests must not persist
	GameStateManager.change_state(Enums.InputState.DEFAULT)
	GridManager.clear_grid()


func _unit_at(x: int) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.current_hp = 10
	unit.character_data = CharacterData.new()
	var tile := GridManager.get_tile(x, 0)
	unit.current_tile = tile
	tile.current_unit = unit
	return unit


func _press(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_next_and_previous_walk_the_ready_units_in_roster_order() -> void:
	InputManager.cycle_unit(1)
	assert_eq(InputManager.get_selected_unit(), _units[0], "nothing selected: Next starts at the first")
	InputManager.cycle_unit(1)
	assert_eq(InputManager.get_selected_unit(), _units[1])
	_units[2].can_act = false
	InputManager.cycle_unit(1)
	assert_eq(InputManager.get_selected_unit(), _units[0], "a spent unit is skipped; the end wraps")
	InputManager.cycle_unit(-1)
	assert_eq(InputManager.get_selected_unit(), _units[1], "Previous wraps back")


func test_counting_starts_at_the_unit_under_the_cursor() -> void:
	InputManager._hovered_tile = _units[1].current_tile
	InputManager.cycle_unit(1)
	assert_eq(InputManager.get_selected_unit(), _units[2])


func test_the_last_ready_unit_keeps_its_plan() -> void:
	_units[0].can_act = false
	_units[1].can_act = false
	InputManager.select_unit(_units[2])
	_units[2].planned_waypoints.append("a stop")  # re-selecting clears the plan
	InputManager.cycle_unit(1)
	assert_eq(InputManager.get_selected_unit(), _units[2])
	assert_eq(_units[2].planned_waypoints.size(), 1, "already selected: only the camera moves")


func test_the_buttons_cycle_on_the_open_board_only() -> void:
	InputManager._unhandled_input(_press(&"unit_next"))
	assert_eq(InputManager.get_selected_unit(), _units[0], "E / RB on the open board")
	InputManager.deselect_unit()
	GameStateManager.change_state(Enums.InputState.ACTION_MENU_OPEN)
	InputManager._unhandled_input(_press(&"unit_prev"))
	assert_null(InputManager.get_selected_unit(), "a menu owns the bumpers")


func test_the_info_button_on_no_unit_shows_the_type_icons() -> void:
	InputManager._hovered_tile = GridManager.get_tile(1, 0)
	InputManager._handle_unit_info_hotkey()
	assert_ne(Settings.unit_type_icons_enabled, _type_icons_were,
			"an empty tile: the Options 'Type Icons' setting flips")
	InputManager._handle_unit_info_hotkey()
	assert_eq(Settings.unit_type_icons_enabled, _type_icons_were, "and flips back")


func test_a_freed_hovered_tile_reads_as_none() -> void:
	# InputManager outlives the board: after a battle its last hovered tile is
	# freed, and the zone button and the hint bar both pass it on to a typed
	# parameter, where a freed object is a script error.
	var tile := Tile.new()
	InputManager._hovered_tile = tile
	tile.free()
	assert_null(InputManager.get_hovered_tile())


func test_back_cancels_a_selection_but_never_opens_the_menu() -> void:
	InputManager._unhandled_input(_press(&"back"))
	assert_eq(GameStateManager.current_state, Enums.InputState.DEFAULT,
			"the open board: a stray right click opens no menu (Escape does)")
	InputManager.select_unit(_units[0])
	InputManager._unhandled_input(_press(&"back"))
	assert_null(InputManager.get_selected_unit(), "a selection: back cancels it")
	assert_eq(GameStateManager.current_state, Enums.InputState.DEFAULT)
