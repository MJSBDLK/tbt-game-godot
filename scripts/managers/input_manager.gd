## Central input dispatcher. Routes clicks/keys based on GameStateManager state.
## Handles unit selection, waypoint placement, movement execution, attack targeting,
## and which board cursor each state owns (BoardCursor does the stepping; the
## dev cheat keys are BattleCheats).
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

# The CURSOR model's brackets on the board: the free cursor in the map-view
# states, the aim cursor during attack targeting. Accept presses its tile
# with exact click semantics.
var _cursor := BoardCursor.new()

# Long-press detection for opening unit detail on touch
const LONG_PRESS_DURATION: float = 0.2  # seconds
var _press_start_time: float = -1.0
var _press_start_tile: Tile = null
var _long_press_fired: bool = false


func _ready() -> void:
	_cursor.moved.connect(_on_cursor_moved)
	# TurnManager autoloads after this node, so signal hookup waits a frame.
	_connect_cursor_signals.call_deferred()


func _connect_cursor_signals() -> void:
	var state_manager: Node = get_node("/root/GameStateManager")
	state_manager.state_changed.connect(_on_game_state_changed)
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager != null:
		turn_manager.player_phase_started.connect(_on_player_phase_started)


# =============================================================================
# PUBLIC API
# =============================================================================

func enable_input() -> void:
	input_enabled = true


func disable_input() -> void:
	input_enabled = false
	# No agency, no "you are here": AI phases, cutscenes, and menus all take
	# the board cursor with them (menus raise their own §14 brackets instead).
	_cursor.clear_free()
	_cursor.release()


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
	_attackable_tiles = MoveTargeting.get_valid_target_tiles(attacker, move)
	GridManager.clear_movement_range()
	GridManager.display_attack_range(_attackable_tiles)

	var ui_manager: Node = _get_ui_manager()
	if ui_manager != null:
		ui_manager.hide_unit_info()

	var state_manager: Node = get_node("/root/GameStateManager")
	state_manager.change_state(Enums.InputState.ATTACK_TARGETING, attacker)
	DebugConfig.log_input("InputManager: Attack targeting with '%s' (%d valid tiles)" % [
		move.move_name, _attackable_tiles.size()])

	# Cursor-model courtesy (InputSource, same doctrine as the menus): a
	# keyboard/controller-driven entry adopts the nearest target immediately;
	# a pointer-driven entry stays quiet until the first arrow press.
	if InputSource.is_cursor_driven():
		_adopt_initial_target()


func cancel_attack_targeting() -> void:
	_is_selecting_attack_target = false
	_attacking_unit = null
	_attack_move = null
	_attackable_tiles.clear()
	_cursor.clear_aim()
	GridManager.clear_attack_range()
	GridManager.clear_displacement_preview()

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
	# The dev console gate is here, not just in InputRouter: hover and the
	# repeats POLL the mouse and Input, which don't care what was handled.
	if not input_enabled or not GridManager.is_grid_ready() or DevConsole.is_open():
		return
	_update_hover()
	_check_long_press()
	_tick_nav_repeat(Time.get_ticks_msec() / 1000.0)


func _unhandled_input(event: InputEvent) -> void:
	# Cheat keybinds run even when input is disabled (e.g. mid-AI phase),
	# so you can always bail out of a stuck battle.
	if DebugConfig.cheats_enabled and event is InputEventKey and BattleCheats.handle(
			event, GridManager.get_tile_at_position(_get_world_mouse_position())):
		get_viewport().set_input_as_handled()
		return

	# GRID READINESS IS THE BATTLE GATE. This is an autoload, so it keeps
	# receiving input on menus and the intermission — and every handler below
	# is battle-only: end turn, escape-to-system-menu, unit info, attack
	# targeting, board cursor. Without this, Escape on the intermission hub
	# reached _handle_escape(), read the state as DEFAULT, and opened the
	# BATTLE pause menu over a screen with no battle behind it (found on F5,
	# 2026-08-07). _process already gated on exactly this pair; the input path
	# just never did.
	if not input_enabled or not GridManager.is_grid_ready():
		return

	# End turn shortcut (E key, and the hint bar's touch button)
	if event.is_action_pressed("end_turn"):
		UIManager.request_end_turn()
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

	# Attack targeting under the CURSOR model: arrows walk the board target
	# cursor across the valid targets (it wears the §14 brackets); accept
	# confirms it. Pointer entry stays quiet — the first arrow press adopts
	# the nearest target, mirroring the menus' quiet-open adoption.
	if _is_selecting_attack_target:
		var direction: Vector2i = InputSource.navigation_direction(event)
		if direction != Vector2i.ZERO:
			_move_target_cursor(direction)
			_cursor.hold(direction, Time.get_ticks_msec() / 1000.0)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept") and _cursor.aim_tile != null:
			_try_attack_tile(_cursor.aim_tile)
			get_viewport().set_input_as_handled()
			return
	# Free board cursor (CURSOR model): during the map-view states the arrows
	# roam the whole grid — first press summons, later presses step — and
	# accept presses the cursor's tile with exact click semantics (select a
	# unit, drop a waypoint, execute on the waypoint, inspect an enemy).
	elif _is_map_view_state():
		var direction: Vector2i = InputSource.navigation_direction(event)
		if direction != Vector2i.ZERO:
			_move_board_cursor(direction)
			_cursor.hold(direction, Time.get_ticks_msec() / 1000.0)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept") and _cursor.has_free():
			_press_board_cursor_tile()
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
	# Cursor-model guard (InputSource): while keyboard/controller drives, the
	# mouse's PARKED position must not fight the board cursor for hover every
	# frame. The next real mouse motion (≥4px) flips the model back to POINTER
	# and this resumes from the live mouse position.
	if InputSource.is_cursor_driven():
		return
	# The pointer has (re)taken the wheel — both board cursors doff their
	# brackets (brackets follow the CURSOR model only) and hover goes back to
	# tracking the mouse. Targeting itself continues; only the cursor display
	# yields, and the next arrow press re-adopts.
	_cursor.clear_free()
	if _cursor.aim_tile != null:
		_cursor.clear_aim()
	# Camera2D is in the root viewport (WorldRoot's tree). This autoload is at
	# /root, so get_viewport() returns the root viewport directly.
	var camera := SceneRouter.get_world_camera() as CameraController
	if camera == null:
		return
	if camera.is_panning:
		return
	# Skip hover updates when the mouse is outside the visible game area —
	# otherwise zoom changes remap an offscreen cursor onto arbitrary tiles
	# and leak into the terrain preview.
	var root_viewport: Viewport = get_viewport()
	var mouse_pos: Vector2 = root_viewport.get_mouse_position()
	if not root_viewport.get_visible_rect().has_point(mouse_pos):
		return
	# Drop stale tile refs after a scene transition — this autoload survives
	# the battle scene, so _hovered_tile may point at a freed Tile.
	if _hovered_tile != null and not is_instance_valid(_hovered_tile):
		_hovered_tile = null
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

	if tile != null and _attackable_tiles.has(tile) and tile.current_unit != null and tile.current_unit is Unit:
		var target := tile.current_unit as Unit
		if MoveTargeting.is_valid_target(target, _attacking_unit, _attack_move):
			if _attack_move.heals:
				var heal_amount := DamageCalculator.calculate_heal_amount(_attacking_unit, target, _attack_move)
				ui_manager.show_heal_preview(_attacking_unit, target, _attack_move, heal_amount)
				GridManager.clear_displacement_preview()
				return
			if _attack_move.targets_allies():
				# Non-healing buff/support — no preview UI yet, defer that pass.
				ui_manager.hide_combat_preview()
				GridManager.clear_displacement_preview()
				return
			# Preview the unit the shot will actually hit — a Protector between the
			# attacker and the aimed-at enemy body-blocks, so show it taking the hit.
			var actual: Unit = MoveTargeting.resolve_actual_target(_attacking_unit, target, _attack_move)
			ui_manager.show_combat_preview(_attacking_unit, actual, _attack_move)
			# Displacing moves ALSO play their future on the board — ghosts,
			# arrows, slam stars (DisplacementPreviewRenderer). No-op for
			# non-displacing moves.
			GridManager.preview_displacement(_attacking_unit, actual, _attack_move)
			return

	ui_manager.hide_combat_preview()
	GridManager.clear_displacement_preview()


# =============================================================================
# CLICK HANDLERS
# =============================================================================

func _handle_left_click() -> void:
	var state_manager: Node = get_node("/root/GameStateManager")
	var state: Enums.InputState = state_manager.current_state
	var tile := GridManager.get_tile_at_position(_get_world_mouse_position())

	match state:
		Enums.InputState.DEFAULT:
			_handle_default_press(tile)
		Enums.InputState.UNIT_SELECTED, Enums.InputState.MOVEMENT_PLANNING:
			_handle_movement_planning_press(tile)
		Enums.InputState.ATTACK_TARGETING:
			_try_attack_tile(tile)


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
	if _press_start_time < 0.0:
		# Press-down was consumed by GUI (e.g. action menu button) — ignore the release
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


func _open_system_menu() -> void:
	var state_manager: Node = get_node("/root/GameStateManager")
	state_manager.push_state(Enums.InputState.PAUSED)
	var ui_manager: Node = _get_ui_manager()
	if ui_manager != null:
		ui_manager.show_system_menu()


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
			_open_system_menu()


## Press semantics for the DEFAULT state — shared verbatim by the mouse click
## and the board cursor's accept (the cursor is a click that walked here).
func _handle_default_press(clicked_tile: Tile) -> void:
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager != null and not turn_manager.is_player_phase():
		return

	if clicked_tile == null:
		return

	if clicked_tile.current_unit != null and clicked_tile.current_unit is Unit:
		var clicked_unit := clicked_tile.current_unit as Unit
		if clicked_unit.faction == Enums.UnitFaction.PLAYER and clicked_unit.can_act:
			select_unit(clicked_unit)
		else:
			# Set before the detail push: that state change releases the notice.
			_set_inspect_notice(HintBarCommands.inspect_notice_for(
					clicked_unit.faction, clicked_unit.can_act))
			var ui_manager: Node = _get_ui_manager()
			if ui_manager != null:
				if ui_manager.get_previewed_unit() == clicked_unit:
					_open_unit_detail(clicked_unit)
				else:
					ui_manager.show_unit_info(clicked_unit)
	else:
		_set_inspect_notice(HintBarCommands.InspectNotice.NONE)
		var ui_manager: Node = _get_ui_manager()
		if ui_manager != null:
			ui_manager.hide_unit_info()


func _set_inspect_notice(notice: HintBarCommands.InspectNotice) -> void:
	var ui_manager: Node = _get_ui_manager()
	if ui_manager == null:
		return
	var hint_bar: HintBar = ui_manager.get_hint_bar()
	if hint_bar != null:
		hint_bar.set_inspect_notice(notice)


## Press semantics for UNIT_SELECTED / MOVEMENT_PLANNING — shared verbatim by
## the mouse click and the board cursor's accept. Cursor consequence worth
## knowing: accept outside the movement range deselects, exactly like a click.
func _handle_movement_planning_press(clicked_tile: Tile) -> void:
	if clicked_tile == null:
		return

	# Click on a unit
	if clicked_tile.current_unit != null and clicked_tile.current_unit is Unit:
		var clicked_unit := clicked_tile.current_unit as Unit

		# Click enemy while unit selected → combat (shortcut if already in range).
		# can_target matches the highlighted attack tiles exactly (effective range
		# + Extendo reach LoS), so the shortcut never fires on an unreachable tile.
		# Opt-in (Settings, default off): new players kept attacking enemies they
		# meant to inspect. Disabled, the click falls through to show-unit-info
		# and attacks go through the action menu's explicit target step.
		if Settings.click_to_attack_enabled \
				and _selected_unit != null and clicked_unit.faction != _selected_unit.faction:
			if not clicked_unit.is_defeated() and _selected_unit.assigned_move != null:
				if MoveTargeting.can_target(_selected_unit, clicked_unit, _selected_unit.assigned_move):
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
		# Press the LAST marker → execute (the marker double-press confirm).
		# Press an EARLIER marker → back the plan up to it; it is now the last
		# marker, so pressing it again confirms. Until 2026-09-10 EVERY marker
		# press executed, so a 3 → 2 → 3 plan walked 3 → 2 on the third press
		# and stopped on 2 (RQD: "the game moves you to space 2").
		if _is_last_waypoint_tile(clicked_tile):
			_execute_movement()
			return
		if _is_waypoint_tile(clicked_tile):
			if _selected_unit.truncate_waypoints_to(clicked_tile):
				GridManager.display_movement_range(_selected_unit)
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


## Shared confirm for the mouse click and the board cursor's accept press. A
## press on anything outside the valid set cancels targeting — unchanged
## click semantics; the keyboard path can only arrive with a valid tile.
func _try_attack_tile(tile: Tile) -> void:
	if tile == null or not _attackable_tiles.has(tile) \
			or tile.current_unit == null or tile.current_unit is not Unit:
		cancel_attack_targeting()
		return

	var target := tile.current_unit as Unit
	if not MoveTargeting.is_valid_target(target, _attacking_unit, _attack_move):
		cancel_attack_targeting()
		return

	_execute_attack(target)


# =============================================================================
# BOARD CURSOR — which cursor a state owns and where it summons (BoardCursor
# does the stepping, brackets and repeat)
# =============================================================================

## The cursor IS the hover under the CURSOR model: tile tint, the unit-info
## hotkey, and the readout follow it (the combat preview while aiming, the
## terrain panel while roaming).
func _on_cursor_moved(tile: Tile, aimed: bool) -> void:
	_hovered_tile = tile
	GridManager.set_hovered_tile(tile)
	if aimed:
		_update_combat_preview(tile)
		return
	var ui_manager: Node = _get_ui_manager()
	if ui_manager != null:
		ui_manager.show_terrain_info(tile)


## The aim cursor, during targeting: arrows walk it between the valid targets.
func _move_target_cursor(direction: Vector2i) -> void:
	if _attackable_tiles.is_empty():
		return
	# First press on a quiet (pointer-opened) targeting session summons the
	# cursor onto the nearest target instead of stepping.
	if _cursor.aim_tile == null or not _attackable_tiles.has(_cursor.aim_tile):
		_adopt_initial_target()
		return
	_cursor.aim(direction, _attackable_tiles)


func _adopt_initial_target() -> void:
	if _attacking_unit == null or _attacking_unit.current_tile == null:
		return
	_cursor.adopt(_attackable_tiles,
			Vector2i(_attacking_unit.current_tile.grid_x, _attacking_unit.current_tile.grid_y))


## The free cursor roams the whole grid in the map-view states (DEFAULT /
## UNIT_SELECTED / MOVEMENT_PLANNING): select a unit, plan movement, act, all
## without a pointer.
func _is_map_view_state() -> bool:
	var state_manager: Node = get_node("/root/GameStateManager")
	return Enums.MAP_VIEW_STATES.has(state_manager.current_state)


func _move_board_cursor(direction: Vector2i) -> void:
	# First press summons the cursor rather than stepping — the board twin of
	# the menus' quiet-open adoption.
	if not _cursor.has_free():
		_summon_board_cursor()
		return
	_cursor.roam(direction)


func _summon_board_cursor(prefer_active_unit: bool = false) -> void:
	if not GridManager.is_grid_ready():
		return
	var tile := _board_cursor_summon_tile(prefer_active_unit)
	if tile != null:
		_cursor.place_free(tile)


## Where a fresh cursor materializes: the selected unit if there is one, then
## the last hovered tile (continuity when swapping mouse → keys mid-thought),
## then the first player unit still able to act. Phase-start summons swap the
## last two — a new turn should greet you on your army, not wherever the
## pointer parked during the enemy phase.
func _board_cursor_summon_tile(prefer_active_unit: bool) -> Tile:
	if _selected_unit != null and is_instance_valid(_selected_unit) \
			and _selected_unit.current_tile != null:
		return _selected_unit.current_tile
	var hovered: Tile = null
	if _hovered_tile != null and is_instance_valid(_hovered_tile):
		hovered = _hovered_tile
	var unit_tile: Tile = _first_actable_player_unit_tile()
	if prefer_active_unit:
		return unit_tile if unit_tile != null else hovered
	return hovered if hovered != null else unit_tile


func _first_actable_player_unit_tile() -> Tile:
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager == null:
		return null
	for unit: Unit in turn_manager.get_player_units():
		if unit != null and is_instance_valid(unit) and not unit.is_defeated() \
				and unit.can_act and unit.current_tile != null:
			return unit.current_tile
	return null


func _press_board_cursor_tile() -> void:
	var state_manager: Node = get_node("/root/GameStateManager")
	match state_manager.current_state:
		Enums.InputState.DEFAULT:
			_handle_default_press(_cursor.free_tile)
		Enums.InputState.UNIT_SELECTED, Enums.InputState.MOVEMENT_PLANNING:
			_handle_movement_planning_press(_cursor.free_tile)


## Hold-to-repeat (called from _process; `now` injected for GUT): steps
## whichever cursor the current state owns; a state with neither disarms it.
func _tick_nav_repeat(now: float) -> void:
	var direction := _cursor.repeat_due(now)
	if direction == Vector2i.ZERO:
		return
	if _is_selecting_attack_target:
		_move_target_cursor(direction)
	elif _is_map_view_state():
		_move_board_cursor(direction)
	else:
		_cursor.release()


## Board-cursor lifecycle vs the state machine: leaving the map-view states
## (menus, targeting, overlays) always retires the free cursor — whatever
## opens raises its own "you are here" and only one may exist. Cursor-driven
## re-entry to the board adopts immediately, mirroring cursor-driven menu
## opens; pointer re-entry stays quiet.
func _on_game_state_changed(old_state: Enums.InputState, new_state: Enums.InputState) -> void:
	if not Enums.MAP_VIEW_STATES.has(new_state):
		_cursor.clear_free()
		return
	if not Enums.MAP_VIEW_STATES.has(old_state) and InputSource.is_cursor_driven():
		_summon_board_cursor()


## FE courtesy: when the keyboard/controller is driving, a new player phase
## greets you with the cursor already on your first ready unit.
func _on_player_phase_started(_turn_count: int) -> void:
	if InputSource.is_cursor_driven():
		_summon_board_cursor(true)


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


## The marker whose second press confirms the plan (hint bar: "select the
## marker again to move") — only ever the newest stop.
func _is_last_waypoint_tile(tile: Tile) -> bool:
	if _selected_unit == null or _selected_unit.planned_waypoints.is_empty():
		return false
	return _selected_unit.planned_waypoints.back().tile == tile


## The hint bar's CALL TO ACTION ("select the marker again to move"): pressing
## the line is pressing the last marker. Same gates as the board press — a
## live battle, a selected unit that hasn't moved, a plan on the board, and
## the planning state. Returns whether a move was started.
func confirm_planned_movement() -> bool:
	if not input_enabled or not GridManager.is_grid_ready():
		return false
	if _selected_unit == null or not _selected_unit.can_act or _unit_has_moved:
		return false
	if _selected_unit.planned_waypoints.is_empty():
		return false
	var state_manager: Node = get_node("/root/GameStateManager")
	if state_manager.current_state != Enums.InputState.MOVEMENT_PLANNING:
		return false
	_execute_movement()
	return true


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
	_cursor.clear_aim()
	GridManager.clear_attack_range()
	GridManager.clear_displacement_preview()

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

	# The staged walk plays now, then the swing. No-op when nothing is staged
	# (the unit acted in place).
	await attacker.play_deferred_walk()
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
	## Anchored on current_tile, not global_position: the sprite is still at
	## the origin here (deferred walk) — the tile is where the plan (ghost,
	## ranges, the action about to be chosen) lives.
	var unit_anchor: Vector2 = unit.current_tile.global_position \
			if unit.current_tile != null else unit.global_position
	var positions: Array[Vector2] = [unit_anchor]
	for move: Move in unit.get_usable_moves():
		for tile: Tile in MoveTargeting.get_valid_target_tiles(unit, move):
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


func _get_ui_manager() -> Node:
	return UIManager


func _get_camera() -> CameraController:
	return SceneRouter.get_world_camera() as CameraController


func _get_world_mouse_position() -> Vector2:
	# Camera2D.get_global_mouse_position() uses the camera's own viewport for
	# the screen→world transform. Camera is in the root viewport (native pixels),
	# and the mouse position there is also in native pixels, so the math is
	# self-consistent.
	var camera := SceneRouter.get_world_camera()
	if camera != null:
		return camera.get_global_mouse_position()
	return get_viewport().get_mouse_position()
