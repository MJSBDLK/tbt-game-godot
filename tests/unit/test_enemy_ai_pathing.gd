## EnemyAI approach-tile selection (_find_best_move_tile) + the GridManager
## approach-cost field behind it. Regression for "enemy pathing is really stupid
## and they can't path through obstacles": scoring candidate tiles by straight-
## line Manhattan distance walked the AI into the dead end nearest the target
## (flat against a wall) instead of routing around it. Tiles are scored by a
## terrain-aware route-cost field now; Manhattan only breaks ties and covers
## terrain-unreachable targets.
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()


func after_all() -> void:
	GridManager.clear_grid()


func _grid_tile(x: int, y: int, terrain: String = "Plains") -> Tile:
	var tile := Tile.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	add_child_autofree(tile)
	tile.grid_x = x
	tile.grid_y = y
	tile.terrain_type_name = terrain
	GridManager.register_tile(tile)
	return tile


## Rectangular all-Plains grid; walls punched in afterwards by re-typing tiles.
func _open_grid(max_x: int, max_y: int) -> void:
	for x: int in range(max_x + 1):
		for y: int in range(max_y + 1):
			_grid_tile(x, y)


func _wall(x: int, y: int) -> void:
	GridManager.get_tile(x, y).terrain_type_name = "Wall"


func _unit(faction: Enums.UnitFaction, x: int, y: int, move_distance: int = 3) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.faction = faction
	unit.current_hp = 10
	var data := CharacterData.new()
	data.move_distance = move_distance
	unit.character_data = data
	var tile: Tile = GridManager.get_tile(x, y)
	unit.current_tile = tile
	tile.current_unit = unit
	return unit


func _ai_for(unit: Unit) -> EnemyAI:
	var ai := EnemyAI.new()
	autofree(ai)
	ai._unit = unit
	return ai


func test_routes_around_a_wall_instead_of_parking_against_it() -> void:
	# Wall column at x=2 (rows 0-2), doorway at (2,3). The Manhattan-closest
	# reachable tile is (1,1) — a dead end flat against the wall. The correct
	# choice is (1,3), heading for the doorway.
	#   y0:  .  .  W  .
	#   y1:  E  .  W  T
	#   y2:  .  .  W  .
	#   y3:  .  .  .  .
	_open_grid(3, 3)
	for y: int in range(3):
		_wall(2, y)
	var enemy := _unit(Enums.UnitFaction.ENEMY, 0, 1)
	var player := _unit(Enums.UnitFaction.PLAYER, 3, 1)
	var chosen: Tile = _ai_for(enemy)._find_best_move_tile(player)
	assert_eq(Vector2i(chosen.grid_x, chosen.grid_y), Vector2i(1, 3),
			"the AI heads for the doorway, not the dead end nearest the target")


func test_open_ground_still_beelines() -> void:
	# No obstacles: route distance and Manhattan agree — behavior unchanged.
	_open_grid(6, 1)
	var enemy := _unit(Enums.UnitFaction.ENEMY, 0, 0)
	var player := _unit(Enums.UnitFaction.PLAYER, 6, 0)
	var chosen: Tile = _ai_for(enemy)._find_best_move_tile(player)
	assert_eq(Vector2i(chosen.grid_x, chosen.grid_y), Vector2i(3, 0),
			"open ground: still closes the gap in a straight line")


func test_unreachable_target_falls_back_to_closing_the_gap() -> void:
	# Full wall column, no doorway: no terrain route exists at all. The enemy
	# should still advance to the Manhattan-closest tile (old behavior) rather
	# than stand frozen.
	_open_grid(6, 2)
	for y: int in range(3):
		_wall(4, y)
	var enemy := _unit(Enums.UnitFaction.ENEMY, 0, 1)
	var player := _unit(Enums.UnitFaction.PLAYER, 6, 1)
	var chosen: Tile = _ai_for(enemy)._find_best_move_tile(player)
	assert_eq(Vector2i(chosen.grid_x, chosen.grid_y), Vector2i(3, 1),
			"island target: fall back to closing the straight-line gap")


func test_approach_cost_field_ignores_unit_occupancy() -> void:
	# A unit standing in the doorway must not poison the field — units move
	# between turns, terrain doesn't. Only terrain shapes the route costs.
	_open_grid(3, 3)
	for y: int in range(3):
		_wall(2, y)
	var enemy := _unit(Enums.UnitFaction.ENEMY, 0, 1)
	var player := _unit(Enums.UnitFaction.PLAYER, 3, 1)
	_unit(Enums.UnitFaction.PLAYER, 2, 3)  # doorway camper
	var field: Dictionary = GridManager.get_approach_cost_field(player.current_tile, enemy)
	assert_true(field.has(GridManager.get_tile(0, 1)),
			"a route to the target exists through the occupied doorway")
