## The board target cursor (RQD 2026-07-31: "still not seeing the brackets
## when picking which unit to attack with the arrow keys" — ATTACK_TARGETING
## had no keyboard support at all; the menus did). Under the CURSOR model,
## arrows walk a cursor across the valid targets, it wears the §14 brackets
## on the tile (TargetCursorRenderer via GridManager), and accept confirms.
## Doctrine mirrors the menus exactly: cursor-driven entry adopts the nearest
## target immediately; pointer entry stays quiet until the first arrow press.
## Grid harness mirrors test_extendo_passive.gd.
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()
	InputManager.cancel_attack_targeting()
	InputSource.last_kind = InputSource.Kind.POINTER


func after_each() -> void:
	InputManager.cancel_attack_targeting()
	InputSource.last_kind = InputSource.Kind.POINTER
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
	InputManager.cancel_attack_targeting()
	assert_null(GridManager.target_cursor_tile(), "cancel takes the brackets with it")


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
