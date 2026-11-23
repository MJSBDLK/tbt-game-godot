## Stonewall: a foe that steps next to the owner stops there. GridManager's
## movement range, remaining range (waypoints) and pathfinding all honor the
## zone, so the player's range, threat zones and the AI agree.
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()


func after_all() -> void:
	GridManager.clear_grid()


## 7 wide, 3 tall: the wall at (3, 1) zones off the whole x = 3 column.
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


func _unit(label: String, faction: Enums.UnitFaction, cell: Vector2i, passives: Array = []) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.unit_name = label
	unit.faction = faction
	unit.current_hp = 20
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	data.move_distance = 6
	unit.character_data = data
	var tile := GridManager.get_tile(cell.x, cell.y)
	unit.current_tile = tile
	tile.current_unit = unit
	return unit


func _cells(tiles: Array[Tile]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for tile: Tile in tiles:
		cells.append(Vector2i(tile.grid_x, tile.grid_y))
	return cells


func _tile(cell: Vector2i) -> Tile:
	return GridManager.get_tile(cell.x, cell.y)


func test_a_foe_stops_next_to_the_wall() -> void:
	_open_grid()
	_unit("squash", Enums.UnitFaction.ENEMY, Vector2i(3, 1), ["Stonewall"])
	var walker := _unit("walker", Enums.UnitFaction.PLAYER, Vector2i(0, 1))
	var reach := _cells(GridManager.get_movement_range(walker))
	assert_has(reach, Vector2i(3, 0), "it may stop next to him")
	assert_has(reach, Vector2i(2, 1))
	assert_does_not_have(reach, Vector2i(4, 0), "but not walk past")


func test_without_the_passive_the_way_is_open() -> void:
	_open_grid()
	_unit("squash", Enums.UnitFaction.ENEMY, Vector2i(3, 1))
	var walker := _unit("walker", Enums.UnitFaction.PLAYER, Vector2i(0, 1))
	assert_has(_cells(GridManager.get_movement_range(walker)), Vector2i(4, 0))


func test_a_foe_starting_in_the_zone_can_step_out() -> void:
	_open_grid()
	_unit("squash", Enums.UnitFaction.ENEMY, Vector2i(3, 1), ["Stonewall"])
	var walker := _unit("walker", Enums.UnitFaction.PLAYER, Vector2i(2, 1))
	var reach := _cells(GridManager.get_movement_range(walker))
	assert_has(reach, Vector2i(0, 1), "walks away freely")
	assert_does_not_have(reach, Vector2i(4, 0), "still can't slip past")


func test_his_allies_walk_past() -> void:
	_open_grid()
	_unit("squash", Enums.UnitFaction.ENEMY, Vector2i(3, 1), ["Stonewall"])
	var friend := _unit("friend", Enums.UnitFaction.ENEMY, Vector2i(0, 1))
	assert_has(_cells(GridManager.get_movement_range(friend)), Vector2i(4, 0))


func test_a_fallen_wall_stops_nobody() -> void:
	_open_grid()
	var squash := _unit("squash", Enums.UnitFaction.ENEMY, Vector2i(3, 1), ["Stonewall"])
	squash.current_hp = 0
	squash.is_defeated_flag = true
	var walker := _unit("walker", Enums.UnitFaction.PLAYER, Vector2i(0, 1))
	assert_has(_cells(GridManager.get_movement_range(walker)), Vector2i(4, 0))


func test_paths_agree_with_the_range() -> void:
	_open_grid()
	_unit("squash", Enums.UnitFaction.ENEMY, Vector2i(3, 1), ["Stonewall"])
	var walker := _unit("walker", Enums.UnitFaction.PLAYER, Vector2i(0, 1))
	assert_true(GridManager.find_path(walker.current_tile, _tile(Vector2i(4, 0)), walker).is_empty(),
			"no route around the wall")
	assert_false(GridManager.find_path(walker.current_tile, _tile(Vector2i(3, 0)), walker).is_empty(),
			"a route up to it")


func test_a_waypoint_in_the_zone_ends_the_walk() -> void:
	_open_grid()
	_unit("squash", Enums.UnitFaction.ENEMY, Vector2i(3, 1), ["Stonewall"])
	var walker := _unit("walker", Enums.UnitFaction.PLAYER, Vector2i(0, 0))
	assert_true(walker.add_waypoint(_tile(Vector2i(3, 0))), "walks up to him")
	assert_true(GridManager.get_remaining_movement_range(walker).is_empty(), "and stops")
	assert_false(walker.add_waypoint(_tile(Vector2i(4, 0))), "no second leg out of the zone")


func test_registry_resolves_stonewall() -> void:
	assert_true(PassiveRegistry.get_handler("Stonewall") is StonewallPassive)
