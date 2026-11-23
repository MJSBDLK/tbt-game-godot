## On Duty: the owner never ends up more than OnDutyPassive.LEASH_TILES from
## where its turn began. Walking is capped in GridManager; every displacement
## resolver asks GridManager.displacement_allows against Unit.turn_start_cell.
## Layouts assume LEASH_TILES = 1.
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()


func after_all() -> void:
	GridManager.clear_grid()


func _open_grid(width: int = 7, height: int = 3) -> void:
	for x: int in range(width):
		for y: int in range(height):
			var tile := Tile.new()
			var sprite := Sprite2D.new()
			sprite.name = "Sprite2D"
			tile.add_child(sprite)
			add_child_autofree(tile)
			tile.grid_x = x
			tile.grid_y = y
			tile.terrain_type_name = "Plains"
			GridManager.register_tile(tile)


func _unit(label: String, cell: Vector2i, passives: Array = [],
		faction: Enums.UnitFaction = Enums.UnitFaction.PLAYER) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.unit_name = label
	unit.faction = faction
	unit.current_hp = 20
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	data.move_distance = 5
	unit.character_data = data
	var tile := GridManager.get_tile(cell.x, cell.y)
	unit.current_tile = tile
	tile.current_unit = unit
	return unit


func _on_duty(label: String, cell: Vector2i, turn_start: Vector2i) -> Unit:
	var unit := _unit(label, cell, ["On Duty"], Enums.UnitFaction.ENEMY)
	unit.turn_start_cell = turn_start
	return unit


func _shove(distance: int, vector: String = "away_from_attacker", on_blocked: String = "stop") -> Move:
	var move := Move.new()
	move.move_name = "Test Shove"
	move.displace_distance = distance
	move.displace_vector = vector
	move.displace_on_blocked = on_blocked
	return move


func _final_cell(plan: DisplacementSystem.DisplacePlan, unit: Unit) -> Vector2i:
	var mover: Dictionary = plan.mover_for(unit)
	if mover.is_empty():
		return Vector2i(-999, -999)
	var tile: Tile = (mover.path as Array[Tile]).back()
	return Vector2i(tile.grid_x, tile.grid_y)


func test_the_leash_is_one_tile() -> void:
	assert_eq(OnDutyPassive.LEASH_TILES, 1, "these layouts assume 1; re-lay them if N changes")


# =============================================================================
# Walking
# =============================================================================

func test_he_walks_one_tile_at_most() -> void:
	_open_grid()
	var squash := _unit("squash", Vector2i(3, 1), ["On Duty"])
	var reach := GridManager.get_movement_range(squash)
	assert_false(reach.is_empty())
	for tile: Tile in reach:
		assert_lte(absi(tile.grid_x - 3) + absi(tile.grid_y - 1), 1)
	assert_true(GridManager.find_path(squash.current_tile, GridManager.get_tile(5, 1), squash).is_empty())


func test_without_the_passive_he_walks_his_full_move() -> void:
	_open_grid()
	var squash := _unit("squash", Vector2i(3, 1))
	assert_has(GridManager.get_movement_range(squash), GridManager.get_tile(5, 1))


func test_his_turn_start_pins_the_line() -> void:
	_open_grid()
	var squash := _unit("squash", Vector2i(3, 1), ["On Duty"])
	OnDutyPassive.new().on_turn_start(squash, [] as Array[Unit])
	assert_eq(squash.turn_start_cell, Vector2i(3, 1))


# =============================================================================
# Displacement
# =============================================================================

func test_a_push_stops_at_the_line_without_a_slam() -> void:
	_open_grid()
	var shover := _unit("shover", Vector2i(1, 1))
	var squash := _on_duty("squash", Vector2i(2, 1), Vector2i(2, 1))
	_unit("bystander", Vector2i(4, 1))
	var plan := DisplacementSystem.build_plan(shover, squash, _shove(2, "away_from_attacker", "bonus_damage"))
	assert_eq(_final_cell(plan, squash), Vector2i(3, 1), "one tile, then the line")
	assert_true(plan.collisions.is_empty(), "the line isn't a wall: no collision damage")


func test_once_at_the_line_he_wont_go_further() -> void:
	_open_grid()
	var shover := _unit("shover", Vector2i(2, 1))
	var squash := _on_duty("squash", Vector2i(3, 1), Vector2i(2, 1))
	var plan := DisplacementSystem.build_plan(shover, squash, _shove(2))
	assert_true(plan.mover_for(squash).is_empty())


func test_he_can_be_pushed_back_toward_his_post() -> void:
	_open_grid()
	var shover := _unit("shover", Vector2i(4, 1))
	var squash := _on_duty("squash", Vector2i(3, 1), Vector2i(2, 1))
	var plan := DisplacementSystem.build_plan(shover, squash, _shove(2))
	assert_eq(_final_cell(plan, squash), Vector2i(1, 1), "back across his post and one past")


func test_an_unpinned_line_pins_where_he_stands() -> void:
	_open_grid()
	var shover := _unit("shover", Vector2i(1, 1))
	var squash := _unit("squash", Vector2i(2, 1), ["On Duty"], Enums.UnitFaction.ENEMY)
	assert_null(squash.turn_start_cell)
	var plan := DisplacementSystem.build_plan(shover, squash, _shove(3))
	assert_eq(_final_cell(plan, squash), Vector2i(3, 1))
	assert_eq(squash.turn_start_cell, Vector2i(2, 1), "a second shove measures from here too")


func test_a_throw_over_the_thrower_finds_no_landing() -> void:
	_open_grid()
	var thrower := _unit("thrower", Vector2i(2, 1))
	var squash := _on_duty("squash", Vector2i(3, 1), Vector2i(3, 1))
	var plan := DisplacementSystem.build_plan(thrower, squash, MoveData.get_move("Toss"))
	assert_true(plan.mover_for(squash).is_empty(), "the landing is 2 tiles out")


func test_a_swap_that_would_carry_him_past_the_line_becomes_a_stop() -> void:
	_open_grid()
	var shover := _unit("shover", Vector2i(0, 1))
	var subject := _unit("subject", Vector2i(1, 1), [], Enums.UnitFaction.ENEMY)
	var squash := _on_duty("squash", Vector2i(2, 1), Vector2i(3, 1))
	var plan := DisplacementSystem.build_plan(shover, subject, _shove(1, "away_from_attacker", "swap"))
	assert_true(plan.mover_for(subject).is_empty())
	assert_true(plan.mover_for(squash).is_empty())


func test_a_swap_inside_the_line_goes_ahead() -> void:
	_open_grid()
	var shover := _unit("shover", Vector2i(0, 1))
	var subject := _unit("subject", Vector2i(1, 1), [], Enums.UnitFaction.ENEMY)
	var squash := _on_duty("squash", Vector2i(2, 1), Vector2i(2, 1))
	var plan := DisplacementSystem.build_plan(shover, subject, _shove(1, "away_from_attacker", "swap"))
	assert_eq(_final_cell(plan, squash), Vector2i(1, 1))


func test_he_jams_a_push_chain_at_the_line() -> void:
	_open_grid()
	var shover := _unit("shover", Vector2i(0, 1))
	var subject := _unit("subject", Vector2i(1, 1), [], Enums.UnitFaction.ENEMY)
	var squash := _on_duty("squash", Vector2i(2, 1), Vector2i(2, 1))
	var plan := DisplacementSystem.build_plan(shover, subject, _shove(2, "away_from_attacker", "push_chain"))
	assert_eq(_final_cell(plan, squash), Vector2i(3, 1), "one step, then the line")
	assert_eq(_final_cell(plan, subject), Vector2i(2, 1), "the train stops with him")


func test_a_rotation_past_the_line_leaves_him_put() -> void:
	_open_grid()
	var caster := _unit("caster", Vector2i(0, 1))
	var epicenter := _unit("epicenter", Vector2i(2, 1), [], Enums.UnitFaction.ENEMY)
	# Both ring neighbors of (3, 1) are 2 from (4, 1).
	var squash := _on_duty("squash", Vector2i(3, 1), Vector2i(4, 1))
	var spin := _shove(1, "rotate_cw")
	spin.displace_subject = "others_in_shape"
	spin.displace_shape = "ring(1)"
	var plan := DisplacementSystem.build_plan(caster, epicenter, spin)
	assert_true(plan.mover_for(squash).is_empty())
	squash.turn_start_cell = Vector2i(3, 1)
	var control := DisplacementSystem.build_plan(caster, epicenter, spin)
	assert_false(control.mover_for(squash).is_empty(), "control: from his post, the step is legal")


func test_without_a_leash_displacement_is_unbounded() -> void:
	_open_grid()
	var unit := _unit("anyone", Vector2i(2, 1))
	assert_true(GridManager.displacement_allows(unit, Vector2i(6, 2)))


func test_registry_resolves_on_duty() -> void:
	assert_true(PassiveRegistry.get_handler("On Duty") is OnDutyPassive)
