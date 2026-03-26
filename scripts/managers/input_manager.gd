## Central input dispatcher. Routes clicks/keys based on GameStateManager state.
## Handles unit selection, waypoint placement, movement execution, attack targeting.
## Registered as Autoload "InputManager".
extends Node


var input_enabled: bool = true

var _hovered_tile: Tile = null
var _selected_unit: Unit = null
var _unit_has_moved: bool = false
var _camera_precentered: bool = false

# Attack targeting state
var _is_selecting_attack_target: bool = false
var _attacking_unit: Unit = null
var _attack_move: Move = null
var _attackable_tiles: Array[Tile] = []

# Long-press detection for opening unit detail on touch
const LONG_PRESS_DURATION: float = 0.2  # seconds
var _press_start_time: float = -1.0
var _press_start_tile: Tile = null
var _long_press_fired: bool = false


# =============================================================================
# PUBLIC API
# =============================================================================

func enable_input() -> void:
	input_enabled = true


func disable_input() -> void:
	input_enabled = false


func get_hovered_tile() -> Tile:
	return _hovered_tile


func get_selected_unit() -> Unit:
	return _selected_unit


func select_unit(unit: Unit) -> void:
	if unit == null:
		return
	if _selected_unit != null:
		_cancel_and_deselect()
	_selected_unit = unit
	_unit_has_moved = false
	_selected_unit.set_selected(true)
	GridManager.set_selected_tile(unit.current_tile)
	GridManager.display_movement_range(_selected_unit)

	var ui_manager: Node = _get_ui_manager()
	if ui_manager != null:
		ui_manager.show_unit_info(unit)

	var state_manager: Node = get_node("/root/GameStateManager")
	state_manager.change_state(Enums.InputState.UNIT_SELECTED, unit)
	DebugConfig.log_input("InputManager: Selected '%s'" % unit.unit_name)


func deselect_unit() -> void:
	if _selected_unit == null:
		return
	_selected_unit.set_selected(false)
	_selected_unit.clear_waypoints()
	GridManager.clear_movement_range()
	GridManager.clear_selected_tile()
	_selected_unit = null
	_unit_has_moved = false

	var ui_manager: Node = _get_ui_manager()
	if ui_manager != null:
		ui_manager.hide_unit_info()


func start_attack_targeting(attacker: Unit, move: Move) -> void:
	_is_selecting_attack_target = true
	_attacking_unit = attacker
	_attack_move = move
	_attackable_tiles = _get_valid_attack_tiles(attacker, move)
	GridManager.clear_movement_range()
	GridManager.display_attack_range(_attackable_tiles)

	var ui_manager: Node = _get_ui_manager()
	if ui_manager != null:
		ui_manager.hide_unit_info()

	var state_manager: Node = get_node("/root/GameStateManager")
	state_manager.change_state(Enums.InputState.ATTACK_TARGETING, attacker)
	DebugConfig.log_input("InputManager: Attack targeting with '%s' (%d valid tiles)" % [
		move.move_name, _attackable_tiles.size()])


func cancel_attack_targeting() -> void:
	_is_selecting_attack_target = false
	_attacking_unit = null
	_attack_move = null
	_attackable_tiles.clear()
	GridManager.clear_attack_range()

	var ui_manager: Node = _get_ui_manager()
	if ui_manager != null:
		ui_manager.hide_combat_preview()
		if _selected_unit != null:
			ui_manager.show_unit_info(_selected_unit)

	var action_menu_manager: Node = get_node_or_null("/root/ActionMenuManager")
	if action_menu_manager != null and _selected_unit != null:
		action_menu_manager.show_action_menu(_selected_unit)
	else:
		var state_manager: Node = get_node("/root/GameStateManager")
		state_manager.change_state(Enums.InputState.DEFAULT)


# =============================================================================
# INPUT PROCESSING
# =============================================================================

func _process(_delta: float) -> void:
	if not input_enabled or not GridManager.is_grid_ready():
		return
	_update_hover()
	_check_long_press()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return

	# End turn shortcut (E key)
	if event.is_action_pressed("end_turn"):
		var turn_manager: Node = get_node_or_null("/root/TurnManager")
		if turn_manager != null and turn_manager.is_player_phase():
			turn_manager.force_end_player_turn()
		get_viewport().set_input_as_handled()
		return

	# Escape: step back through states
	if event.is_action_pressed("ui_cancel"):
		_handle_escape()
		get_viewport().set_input_as_handled()
		return

	# Unit info hotkey (I key / Y button)
	if event.is_action_pressed("unit_info"):
		_handle_unit_info_hotkey()
		get_viewport().set_input_as_handled()
		return

	# Mouse/touch clicks
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_start_press()
			else:
				_end_press()
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_handle_right_click()
			get_viewport().set_input_as_handled()


# =============================================================================
# HOVER
# =============================================================================

func _update_hover() -> void:
	var world_position := _get_world_mouse_position()
	var tile := GridManager.get_tile_at_position(world_position)
	if tile != _hovered_tile:
		_hovered_tile = tile
		GridManager.set_hovered_tile(tile)

		var ui_manager: Node = _get_ui_manager()
		if ui_manager != null:
			ui_manager.show_terrain_info(tile)

		# Combat preview during attack targeting
		_update_combat_preview(tile)


func _update_combat_preview(tile: Tile) -> void:
	var ui_manager: Node = _get_ui_manager()
	if ui_manager == null:
		return

	if not _is_selecting_attack_target or _attacking_unit == null or _attack_move == null:
		return

	if tile != null and tile.current_unit != null and tile.current_unit is Unit:
		var target := tile.current_unit as Unit
		if target.faction != _attacking_unit.faction and not target.is_defeated():
			ui_manager.show_combat_preview(_attacking_unit, target, _attack_move)
			return

	ui_manager.hide_combat_preview()


# =============================================================================
# CLICK HANDLERS
# =============================================================================

func _handle_left_click() -> void:
	var state_manager: Node = get_node("/root/GameStateManager")
	var state: Enums.InputState = state_manager.current_state

	match state:
		Enums.InputState.DEFAULT:
			_handle_default_click()
		Enums.InputState.UNIT_SELECTED, Enums.InputState.MOVEMENT_PLANNING:
			_handle_movement_planning_click()
		Enums.InputState.ATTACK_TARGETING:
			_handle_attack_target_click()


func _handle_right_click() -> void:
	if _selected_unit != null:
		_cancel_and_deselect()
		var state_manager: Node = get_node("/root/GameStateManager")
		state_manager.change_state(Enums.InputState.DEFAULT)


func _handle_unit_info_hotkey() -> void:
	var unit: Unit = null
	if _selected_unit != null:
		unit = _selected_unit
	elif _hovered_tile != null and _hovered_tile.current_unit is Unit:
		unit = _hovered_tile.current_unit as Unit
	if unit == null:
		return
	_open_unit_detail(unit)


# =============================================================================
# LONG-PRESS / SECOND-TAP → UNIT DETAIL
# =============================================================================

func _start_press() -> void:
	_press_start_time = Time.get_ticks_msec() / 1000.0
	_press_start_tile = GridManager.get_tile_at_position(_get_world_mouse_position())
	_long_press_fired = false


func _end_press() -> void:
	if _long_press_fired:
		# Long press already opened unit detail — don't also fire a click
		_reset_press()
		return
	_handle_left_click()
	_reset_press()


func _reset_press() -> void:
	_press_start_time = -1.0
	_press_start_tile = null
	_long_press_fired = false


func _check_long_press() -> void:
	if _press_start_time < 0.0 or _long_press_fired:
		return
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _press_start_time
	if elapsed < LONG_PRESS_DURATION:
		return
	# Verify finger hasn't drifted to a different tile
	var current_tile := GridManager.get_tile_at_position(_get_world_mouse_position())
	if current_tile != _press_start_tile:
		_reset_press()
		return
	if current_tile != null and current_tile.current_unit is Unit:
		_long_press_fired = true
		_open_unit_detail(current_tile.current_unit as Unit)


func _open_unit_detail(unit: Unit) -> void:
	var state_manager: Node = get_node("/root/GameStateManager")
	state_manager.push_state(Enums.InputState.UNIT_DETAIL, unit)
	var ui_manager: Node = _get_ui_manager()
	if ui_manager != null:
		ui_manager.show_unit_detail(unit)


func _handle_escape() -> void:
	var state_manager: Node = get_node("/root/GameStateManager")
	var state: Enums.InputState = state_manager.current_state

	match state:
		Enums.InputState.ATTACK_TARGETING:
			cancel_attack_targeting()
		Enums.InputState.UNIT_SELECTED, Enums.InputState.MOVEMENT_PLANNING:
			_cancel_and_deselect()
			state_manager.clear_state_stack()
			state_manager.change_state(Enums.InputState.DEFAULT)
		Enums.InputState.DEFAULT:
			pass


func _handle_default_click() -> void:
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager != null and not turn_manager.is_player_phase():
		return

	var clicked_tile := GridManager.get_tile_at_position(_get_world_mouse_position())
	if clicked_tile == null:
		return

	if clicked_tile.current_unit != null and clicked_tile.current_unit is Unit:
		var clicked_unit := clicked_tile.current_unit as Unit
		if clicked_unit.faction == Enums.UnitFaction.PLAYER and clicked_unit.can_act:
			select_unit(clicked_unit)
		else:
			var ui_manager: Node = _get_ui_manager()
			if ui_manager != null:
				# Second tap on same unit → open full detail panel
				if ui_manager.get_previewed_unit() == clicked_unit:
					_open_unit_detail(clicked_unit)
				else:
					ui_manager.show_unit_info(clicked_unit)
	else:
		# Clicked empty tile — dismiss any open unit preview
		var ui_manager: Node = _get_ui_manager()
		if ui_manager != null:
			ui_manager.hide_unit_info()


func _handle_movement_planning_click() -> void:
	var clicked_tile := GridManager.get_tile_at_position(_get_world_mouse_position())
	if clicked_tile == null:
		return

	# Click on a unit
	if clicked_tile.current_unit != null and clicked_tile.current_unit is Unit:
		var clicked_unit := clicked_tile.current_unit as Unit

		# Click enemy while unit selected → combat (shortcut if already in range)
		if _selected_unit != null and clicked_unit.faction != _selected_unit.faction:
			if not clicked_unit.is_defeated() and _selected_unit.assigned_move != null:
				var distance := DamageCalculator.get_manhattan_distance(_selected_unit, clicked_unit)
				if distance <= _selected_unit.assigned_move.attack_range:
					_execute_direct_combat(clicked_unit)
					return

		# Click own selected unit → action menu (act in place)
		if clicked_unit == _selected_unit:
			_show_action_menu_for_unit(_selected_unit)
			return

		# Click different player unit → switch selection
		if clicked_unit.faction == Enums.UnitFaction.PLAYER and clicked_unit.can_act:
			select_unit(clicked_unit)
			return

		# Click enemy/neutral → show info
		var ui_manager: Node = _get_ui_manager()
		if ui_manager != null:
			ui_manager.show_unit_info(clicked_unit)
		return

	# Click on empty tile with unit selected
	if _selected_unit != null and _selected_unit.can_act and not _unit_has_moved:
		# Click existing waypoint → execute movement
		if _is_waypoint_tile(clicked_tile):
			_execute_movement()
			return

		# Add waypoint if in movement range
		if GridManager.is_in_current_movement_range(clicked_tile):
			var success := _selected_unit.add_waypoint(clicked_tile)
			if success:
				GridManager.display_movement_range(_selected_unit)
				var state_manager: Node = get_node("/root/GameStateManager")
				state_manager.change_state(Enums.InputState.MOVEMENT_PLANNING, _selected_unit)
			return

		# Click outside range → deselect
		_cancel_and_deselect()
		var state_mgr: Node = get_node("/root/GameStateManager")
		state_mgr.change_state(Enums.InputState.DEFAULT)


func _handle_attack_target_click() -> void:
	var clicked_tile := GridManager.get_tile_at_position(_get_world_mouse_position())
	if clicked_tile == null:
		cancel_attack_targeting()
		return

	if not _attackable_tiles.has(clicked_tile):
		cancel_attack_targeting()
		return

	if clicked_tile.current_unit == null or clicked_tile.current_unit is not Unit:
		cancel_attack_targeting()
		return

	var target := clicked_tile.current_unit as Unit
	if target.faction == _attacking_unit.faction or target.is_defeated():
		cancel_attack_targeting()
		return

	# Execute attack
	_execute_attack(target)


# =============================================================================
# MOVEMENT
# =============================================================================

func _is_waypoint_tile(tile: Tile) -> bool:
	if _selected_unit == null:
		return false
	for waypoint: Variant in _selected_unit.planned_waypoints:
		if waypoint.tile == tile:
			return true
	return false


func _execute_movement() -> void:
	if _selected_unit == null:
		return
	GridManager.clear_movement_range()
	await _selected_unit.execute_planned_movement()
	_unit_has_moved = true
	var cam := _get_camera()
	if cam:
		cam.center_on(_get_post_move_camera_target(_selected_unit))
	_camera_precentered = true
	_show_action_menu_for_unit(_selected_unit)


func _cancel_and_deselect() -> void:
	if _selected_unit == null:
		return
	if _unit_has_moved:
		_selected_unit.cancel_movement()
		_unit_has_moved = false
	_camera_precentered = false
	deselect_unit()


# =============================================================================
# COMBAT
# =============================================================================

func _execute_direct_combat(target: Unit) -> void:
	if _selected_unit == null or _selected_unit.assigned_move == null:
		return
	GridManager.clear_movement_range()
	var cam := _get_camera()
	if cam:
		cam.center_on((_selected_unit.global_position + target.global_position) / 2.0)
	await _selected_unit.execute_combat_sequence(target, _selected_unit.assigned_move)
	_finish_unit_action()


func _execute_attack(target: Unit) -> void:
	if _attacking_unit == null or _attack_move == null:
		return

	var attacker := _attacking_unit
	var move := _attack_move

	_is_selecting_attack_target = false
	_attackable_tiles.clear()
	GridManager.clear_attack_range()

	var ui_manager: Node = _get_ui_manager()
	if ui_manager != null:
		ui_manager.hide_combat_preview()

	var action_menu_manager: Node = get_node_or_null("/root/ActionMenuManager")
	if action_menu_manager != null:
		action_menu_manager.clear_selected_move()

	if not _camera_precentered:
		var cam := _get_camera()
		if cam:
			cam.center_on((attacker.global_position + target.global_position) / 2.0)

	await attacker.execute_combat_sequence(target, move)

	if ui_manager != null:
		ui_manager.refresh()

	_attacking_unit = null
	_attack_move = null
	_finish_unit_action()


func _finish_unit_action() -> void:
	if _selected_unit != null:
		_selected_unit.set_acted()
		_selected_unit.set_selected(false)
	_selected_unit = null
	_unit_has_moved = false
	_camera_precentered = false
	GridManager.clear_selected_tile()

	var ui_manager: Node = _get_ui_manager()
	if ui_manager != null:
		ui_manager.hide_unit_info()

	var state_manager: Node = get_node("/root/GameStateManager")
	state_manager.clear_state_stack()
	state_manager.change_state(Enums.InputState.DEFAULT)

	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager != null:
		turn_manager.check_end_player_turn()


# =============================================================================
# ACTION MENU
# =============================================================================

func _show_action_menu_for_unit(unit: Unit) -> void:
	var action_menu_manager: Node = get_node_or_null("/root/ActionMenuManager")
	if action_menu_manager != null:
		action_menu_manager.show_action_menu(unit)


# =============================================================================
# HELPERS
# =============================================================================

func _get_post_move_camera_target(unit: Unit) -> Vector2:
	## After movement, pan to the bounding box center of the unit and all reachable targets.
	## Falls back to the unit's own position if no targets are in range.
	var positions: Array[Vector2] = [unit.global_position]
	for move: Move in unit.get_usable_moves():
		for tile: Tile in _get_valid_attack_tiles(unit, move):
			if tile.current_unit != null:
				positions.append(tile.current_unit.global_position)
	if positions.size() == 1:
		return unit.global_position
	var min_pos := positions[0]
	var max_pos := positions[0]
	for pos: Vector2 in positions:
		min_pos = min_pos.min(pos)
		max_pos = max_pos.max(pos)
	return (min_pos + max_pos) / 2.0


func _get_valid_attack_tiles(attacker: Unit, move: Move) -> Array[Tile]:
	var tiles: Array[Tile] = []
	if attacker == null or move == null or attacker.current_tile == null:
		return tiles
	var all_tiles := GridManager.get_tiles_within_range(attacker.current_tile, move.attack_range)
	for tile: Tile in all_tiles:
		if tile.current_unit != null and tile.current_unit is Unit:
			var target := tile.current_unit as Unit
			if target.faction != attacker.faction and not target.is_defeated():
				tiles.append(tile)
	return tiles


func _get_ui_manager() -> Node:
	return get_node_or_null("/root/UIManager")


func _get_camera() -> CameraController:
	return get_viewport().get_camera_2d() as CameraController


func _get_world_mouse_position() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2.ZERO
	var camera := viewport.get_camera_2d()
	if camera != null:
		return camera.get_global_mouse_position()
	return viewport.get_mouse_position()
