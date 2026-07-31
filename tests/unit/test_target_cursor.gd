## The board cursors (RQD 2026-07-31: "still not seeing the brackets when
## picking which unit to attack with the arrow keys" — ATTACK_TARGETING had no
## keyboard support at all; the menus did). Under the CURSOR model, arrows walk
## a cursor wearing the §14 brackets on its tile (TargetCursorRenderer via
## GridManager): constrained to valid targets during ATTACK_TARGETING, and —
## since the FE free-cursor pass — roaming the whole grid during the map-view
## states, where accept carries exact click semantics. Doctrine mirrors the
## menus exactly: cursor-driven entry adopts immediately; pointer entry stays
## quiet until the first arrow press summons. Grid harness mirrors
## test_extendo_passive.gd.
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()
	InputSource.last_kind = InputSource.Kind.POINTER
	InputManager.cancel_attack_targeting()
	InputManager.deselect_unit()
	InputManager._clear_board_cursor()
	InputManager._held_nav_direction = Vector2i.ZERO
	InputManager.enable_input()


func after_each() -> void:
	InputSource.last_kind = InputSource.Kind.POINTER
	InputManager.cancel_attack_targeting()
	InputManager.deselect_unit()
	InputManager._clear_board_cursor()
	InputManager._held_nav_direction = Vector2i.ZERO
	InputManager.enable_input()
	GameStateManager.change_state(Enums.InputState.DEFAULT)


func after_all() -> void:
	GridManager.clear_grid()


func _unit(faction: Enums.UnitFaction = Enums.UnitFaction.PLAYER) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.faction = faction
	unit.current_hp = 10
	unit.character_data = CharacterData.new()
	return unit


func _move(attack_range: int = 2) -> Move:
	var move := Move.new()
	move.damage_type = Enums.DamageType.PHYSICAL
	move.base_power = 10
	move.attack_range = attack_range
	move.target_type = Enums.TargetType.SINGLE
	return move


func _grid_tile(x: int, y: int) -> void:
	var tile := Tile.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	add_child_autofree(tile)
	tile.grid_x = x
	tile.grid_y = y
	tile.terrain_type_name = "Plains"
	GridManager.register_tile(tile)


func _open_grid(min_x: int, max_x: int, min_y: int, max_y: int) -> void:
	for x: int in range(min_x, max_x + 1):
		for y: int in range(min_y, max_y + 1):
			_grid_tile(x, y)


func _place(unit: Unit, x: int, y: int) -> void:
	var tile := GridManager.get_tile(x, y)
	unit.current_tile = tile
	tile.current_unit = unit


func _nav(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


# =============================================================================
# Pure geometry — the direction picker
# =============================================================================

func test_direction_picker_finds_nearest_in_half_plane() -> void:
	var candidates: Array[Vector2i] = [Vector2i(3, 0), Vector2i(1, 0), Vector2i(-2, 0)]
	var picked := InputManager.pick_target_in_direction(Vector2i.ZERO, candidates, Vector2i(1, 0))
	assert_eq(picked, 1, "nearest candidate to the right wins; the one behind never does")
	assert_eq(InputManager.pick_target_in_direction(Vector2i.ZERO, candidates, Vector2i(0, -1)),
			-1, "nothing upward -> -1, the cursor stays put (no wrap)")


func test_direction_picker_prefers_straight_ahead_over_diagonal_drift() -> void:
	# Right press: (2,0) is dead ahead at distance 2; (1,2) is nearer overall
	# but two tiles of sideways drift (counted double) makes it lose.
	var candidates: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 0)]
	assert_eq(InputManager.pick_target_in_direction(Vector2i.ZERO, candidates, Vector2i(1, 0)),
			1, "sideways distance counts double")
	assert_eq(InputManager.pick_target_in_direction(Vector2i.ZERO, [] as Array[Vector2i],
			Vector2i(1, 0)), -1, "empty set -> -1")


func test_initial_pick_is_nearest_to_attacker() -> void:
	var candidates: Array[Vector2i] = [Vector2i(5, 5), Vector2i(1, 0), Vector2i(0, 1)]
	assert_eq(InputManager.pick_initial_target(Vector2i.ZERO, candidates), 1,
			"nearest Manhattan wins; first-listed breaks ties")
	assert_eq(InputManager.pick_initial_target(Vector2i.ZERO, [] as Array[Vector2i]), -1)


func test_navigation_direction_mapping() -> void:
	assert_eq(InputSource.navigation_direction(_nav("ui_up")), Vector2i(0, -1))
	assert_eq(InputSource.navigation_direction(_nav("ui_down")), Vector2i(0, 1))
	assert_eq(InputSource.navigation_direction(_nav("ui_left")), Vector2i(-1, 0))
	assert_eq(InputSource.navigation_direction(_nav("ui_right")), Vector2i(1, 0))
	assert_eq(InputSource.navigation_direction(_nav("ui_accept")), Vector2i.ZERO,
			"accept is a confirm, never a summons")


# =============================================================================
# The cursor in a real targeting session
# =============================================================================

func test_cursor_driven_entry_adopts_the_nearest_target() -> void:
	_open_grid(0, 4, 0, 0)
	var attacker := _unit()
	_place(attacker, 0, 0)
	var near := _unit(Enums.UnitFaction.ENEMY)
	_place(near, 1, 0)
	var far := _unit(Enums.UnitFaction.ENEMY)
	_place(far, 2, 0)

	InputSource.last_kind = InputSource.Kind.CURSOR
	InputManager.start_attack_targeting(attacker, _move(2))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(1, 0),
			"cursor-model entry: brackets land on the nearest target immediately")


func test_pointer_entry_is_quiet_until_an_arrow_summons_the_cursor() -> void:
	_open_grid(0, 4, 0, 0)
	var attacker := _unit()
	_place(attacker, 0, 0)
	var near := _unit(Enums.UnitFaction.ENEMY)
	_place(near, 1, 0)

	InputSource.last_kind = InputSource.Kind.POINTER
	InputManager.start_attack_targeting(attacker, _move(2))
	assert_null(GridManager.target_cursor_tile(), "pointer entry shows no phantom cursor")

	InputManager._unhandled_input(_nav("ui_right"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(1, 0),
			"the first arrow press summons the cursor onto the nearest target")


func test_arrows_step_the_cursor_between_targets() -> void:
	_open_grid(0, 4, 0, 0)
	var attacker := _unit()
	_place(attacker, 0, 0)
	var near := _unit(Enums.UnitFaction.ENEMY)
	_place(near, 1, 0)
	var far := _unit(Enums.UnitFaction.ENEMY)
	_place(far, 2, 0)

	InputSource.last_kind = InputSource.Kind.CURSOR
	InputManager.start_attack_targeting(attacker, _move(2))
	InputManager._unhandled_input(_nav("ui_right"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(2, 0),
			"right steps to the next target that way")
	InputManager._unhandled_input(_nav("ui_right"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(2, 0),
			"no further target right -> the cursor stays put")
	InputManager._unhandled_input(_nav("ui_left"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(1, 0),
			"left steps back")


func test_cancel_clears_the_board_cursor() -> void:
	_open_grid(0, 2, 0, 0)
	var attacker := _unit()
	_place(attacker, 0, 0)
	var enemy := _unit(Enums.UnitFaction.ENEMY)
	_place(enemy, 1, 0)

	InputSource.last_kind = InputSource.Kind.CURSOR
	InputManager.start_attack_targeting(attacker, _move(1))
	assert_not_null(GridManager.target_cursor_tile(), "precondition: cursor worn")
	# Pointer-driven cancel: the attack cursor's brackets leave with it. (A
	# CURSOR-driven cancel into DEFAULT immediately re-adopts the FREE cursor
	# at the remembered spot — that continuity is pinned separately below.)
	InputSource.last_kind = InputSource.Kind.POINTER
	InputManager.cancel_attack_targeting()
	assert_null(InputManager._keyboard_target_tile, "the attack cursor itself is gone")
	assert_null(GridManager.target_cursor_tile(), "cancel takes the brackets with it")


func test_attack_cursor_vertical_steps_match_screen_direction() -> void:
	# REGRESSION (found during the free-cursor pass): the game grid is Y-up but
	# navigation_direction speaks screen convention (up = -y). Without the flip
	# in _move_target_cursor, "up" walked the cursor to the target visually
	# BELOW. The original stepping tests used a one-row grid, so it hid.
	_open_grid(0, 4, 0, 4)
	var attacker := _unit()
	_place(attacker, 2, 1)
	var below := _unit(Enums.UnitFaction.ENEMY)
	_place(below, 2, 0)
	var above := _unit(Enums.UnitFaction.ENEMY)
	_place(above, 2, 3)

	InputSource.last_kind = InputSource.Kind.CURSOR
	InputManager.start_attack_targeting(attacker, _move(2))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(2, 0),
			"precondition: adopts the nearest target (the one below)")
	InputManager._unhandled_input(_nav("ui_up"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(2, 3),
			"screen-up walks to the target visually above (grid_y is Y-up)")
	InputManager._unhandled_input(_nav("ui_down"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(2, 0),
			"screen-down walks back")


# =============================================================================
# The FREE board cursor — full-map roam in the map-view states
# =============================================================================

func test_first_arrow_summons_the_free_cursor_at_the_hovered_tile() -> void:
	_open_grid(0, 4, 0, 4)
	InputSource.last_kind = InputSource.Kind.CURSOR
	InputManager._hovered_tile = GridManager.get_tile(2, 2)
	InputManager._unhandled_input(_nav("ui_right"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(2, 2),
			"first press summons (mouse→keys continuity), never steps")


func test_free_cursor_steps_in_screen_directions() -> void:
	_open_grid(0, 4, 0, 4)
	InputSource.last_kind = InputSource.Kind.CURSOR
	InputManager._hovered_tile = GridManager.get_tile(2, 2)
	InputManager._unhandled_input(_nav("ui_right"))

	InputManager._unhandled_input(_nav("ui_up"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(2, 3),
			"screen-up = grid_y + 1 on the Y-up grid")
	InputManager._unhandled_input(_nav("ui_right"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(3, 3))
	InputManager._unhandled_input(_nav("ui_down"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(3, 2))
	InputManager._unhandled_input(_nav("ui_left"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(2, 2))


func test_free_cursor_stays_put_at_the_map_edge() -> void:
	_open_grid(0, 1, 0, 0)
	InputSource.last_kind = InputSource.Kind.CURSOR
	InputManager._hovered_tile = GridManager.get_tile(0, 0)
	InputManager._unhandled_input(_nav("ui_right"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(0, 0),
			"precondition: summoned at the corner")

	InputManager._unhandled_input(_nav("ui_left"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(0, 0),
			"no tile west -> stays put, no wrap")
	InputManager._unhandled_input(_nav("ui_down"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(0, 0),
			"no tile south -> stays put")
	InputManager._unhandled_input(_nav("ui_right"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(1, 0),
			"open direction still steps")


func test_accept_selects_the_player_unit_under_the_cursor() -> void:
	_open_grid(0, 4, 0, 4)
	var unit := _unit()
	_place(unit, 1, 1)

	InputSource.last_kind = InputSource.Kind.CURSOR
	InputManager._hovered_tile = GridManager.get_tile(1, 1)
	InputManager._unhandled_input(_nav("ui_right"))
	InputManager._unhandled_input(_nav("ui_accept"))
	assert_eq(InputManager.get_selected_unit(), unit,
			"accept on a ready player unit = the click that selects it")
	assert_eq(GameStateManager.current_state, Enums.InputState.UNIT_SELECTED)


func test_accept_on_a_reachable_tile_drops_a_waypoint() -> void:
	_open_grid(0, 4, 0, 4)
	var unit := _unit()
	_place(unit, 1, 1)

	InputSource.last_kind = InputSource.Kind.CURSOR
	InputManager._hovered_tile = GridManager.get_tile(1, 1)
	InputManager._unhandled_input(_nav("ui_right"))
	InputManager._unhandled_input(_nav("ui_accept"))

	InputManager._unhandled_input(_nav("ui_right"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(2, 1),
			"selection does not eat the cursor; it keeps roaming")
	InputManager._unhandled_input(_nav("ui_accept"))
	assert_eq(unit.planned_waypoints.size(), 1,
			"accept on an in-range tile plans a waypoint, same as the click")
	assert_eq(GameStateManager.current_state, Enums.InputState.MOVEMENT_PLANNING)


func test_menus_retire_the_cursor_and_cursor_driven_reentry_resummons() -> void:
	_open_grid(0, 2, 0, 2)
	InputSource.last_kind = InputSource.Kind.CURSOR
	InputManager._hovered_tile = GridManager.get_tile(1, 1)
	InputManager._unhandled_input(_nav("ui_right"))
	assert_not_null(GridManager.target_cursor_tile(), "precondition: cursor worn")

	GameStateManager.change_state(Enums.InputState.ACTION_MENU_OPEN)
	assert_null(GridManager.target_cursor_tile(),
			"a menu raises its own brackets; the board cursor yields")

	GameStateManager.change_state(Enums.InputState.DEFAULT)
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(1, 1),
			"cursor-driven re-entry adopts immediately at the remembered spot")


func test_pointer_reclaim_doffs_the_free_cursor() -> void:
	_open_grid(0, 2, 0, 2)
	InputSource.last_kind = InputSource.Kind.CURSOR
	InputManager._hovered_tile = GridManager.get_tile(1, 1)
	InputManager._unhandled_input(_nav("ui_right"))
	assert_not_null(GridManager.target_cursor_tile(), "precondition: cursor worn")

	InputSource.last_kind = InputSource.Kind.POINTER
	InputManager._update_hover()
	assert_null(GridManager.target_cursor_tile(),
			"real mouse motion flips the model; brackets follow the CURSOR model only")


func test_disable_input_retires_the_free_cursor() -> void:
	_open_grid(0, 2, 0, 2)
	InputSource.last_kind = InputSource.Kind.CURSOR
	InputManager._hovered_tile = GridManager.get_tile(1, 1)
	InputManager._unhandled_input(_nav("ui_right"))
	assert_not_null(GridManager.target_cursor_tile(), "precondition: cursor worn")

	InputManager.disable_input()
	assert_null(GridManager.target_cursor_tile(),
			"no agency, no 'you are here' — AI phases take the cursor with them")
	InputManager.enable_input()


func test_phase_start_summons_on_the_first_ready_unit() -> void:
	_open_grid(0, 3, 0, 0)
	var unit := _unit()
	_place(unit, 3, 0)
	var previous_units: Array[Unit] = TurnManager._player_units
	var roster: Array[Unit] = [unit]
	TurnManager._player_units = roster

	InputSource.last_kind = InputSource.Kind.CURSOR
	InputManager._hovered_tile = GridManager.get_tile(0, 0)
	InputManager._on_player_phase_started(1)
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(3, 0),
			"a new phase greets you on your army, not the parked hover")
	TurnManager._player_units = previous_units


func test_hold_to_repeat_steps_after_delay_then_interval() -> void:
	_open_grid(0, 4, 0, 4)
	InputSource.last_kind = InputSource.Kind.CURSOR
	InputManager._hovered_tile = GridManager.get_tile(0, 2)
	InputManager._unhandled_input(_nav("ui_right"))
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(0, 2),
			"precondition: summoned")

	Input.action_press("ui_right")
	InputManager._begin_nav_repeat(Vector2i(1, 0), 0.0)
	InputManager._tick_nav_repeat(0.2)
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(0, 2),
			"inside the initial delay: no step")
	InputManager._tick_nav_repeat(0.4)
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(1, 2),
			"past the delay: first repeat step")
	InputManager._tick_nav_repeat(0.44)
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(1, 2),
			"inside the repeat interval: no step")
	InputManager._tick_nav_repeat(0.5)
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(2, 2),
			"each interval: another step")

	Input.action_release("ui_right")
	InputManager._tick_nav_repeat(0.7)
	assert_eq(GridManager.target_cursor_tile(), GridManager.get_tile(2, 2),
			"release disarms the repeat")


func test_action_for_direction_is_navigation_directions_inverse() -> void:
	assert_eq(InputSource.action_for_direction(Vector2i(0, -1)), &"ui_up")
	assert_eq(InputSource.action_for_direction(Vector2i(0, 1)), &"ui_down")
	assert_eq(InputSource.action_for_direction(Vector2i(-1, 0)), &"ui_left")
	assert_eq(InputSource.action_for_direction(Vector2i(1, 0)), &"ui_right")
	assert_eq(InputSource.action_for_direction(Vector2i.ZERO), &"",
			"ZERO backs no action — the repeat engine disarms on it")


# =============================================================================
# Debug menu badges (PanelBorderOverlay)
# =============================================================================

func test_badge_initials_derivation() -> void:
	assert_eq(PanelBorderOverlay.badge_initials("ActionMenuPanel"), "AMP")
	assert_eq(PanelBorderOverlay.badge_initials("SystemMenuPanel"), "SMP")
	assert_eq(PanelBorderOverlay.badge_initials("UnitPreviewPanel"), "UPP")
	assert_eq(PanelBorderOverlay.badge_initials("plain"), "PLA",
			"no capitals -> first three letters, uppercased")


func test_badge_rides_the_flag() -> void:
	var was_on: bool = DebugConfig.debug_menu_badges
	DebugConfig.debug_menu_badges = true
	var host := Control.new()
	add_child_autofree(host)
	var overlay := PanelBorderOverlay.new()
	host.add_child(overlay)
	assert_not_null(overlay.get_node_or_null("DebugBadge"), "flag on -> etched tag")

	DebugConfig.debug_menu_badges = false
	var quiet_overlay := PanelBorderOverlay.new()
	host.add_child(quiet_overlay)
	assert_null(quiet_overlay.get_node_or_null("DebugBadge"), "flag off -> clean border")
	DebugConfig.debug_menu_badges = was_on
