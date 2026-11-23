## Outburst: with two or more foes next to him, his multi-hit moves land one
## more hit (DamageCalculator.volley_hits asks the attacker's passives).
## Tantrum's crowded case is in test_tantrum.
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()


func after_all() -> void:
	GridManager.clear_grid()


func _open_grid(width: int = 3, height: int = 3) -> void:
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


func _unit(faction: Enums.UnitFaction, cell: Vector2i, passives: Array = []) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.faction = faction
	unit.current_hp = 20
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	var tile := GridManager.get_tile(cell.x, cell.y)
	unit.current_tile = tile
	tile.current_unit = unit
	return unit


func _thumps() -> Unit:
	return _unit(Enums.UnitFaction.ENEMY, Vector2i(1, 1), ["Outburst"])


func test_two_foes_alongside_set_him_off() -> void:
	_open_grid()
	var thumps := _thumps()
	_unit(Enums.UnitFaction.PLAYER, Vector2i(0, 1))
	_unit(Enums.UnitFaction.PLAYER, Vector2i(1, 2))
	assert_eq(DamageCalculator.volley_hits(thumps, MoveData.get_move("Pound")), 3)
	assert_eq(DamageCalculator.volley_hits(thumps, MoveData.get_move("Maul")), 4)


func test_one_foe_is_not_a_crowd() -> void:
	_open_grid()
	var thumps := _thumps()
	_unit(Enums.UnitFaction.PLAYER, Vector2i(0, 1))
	_unit(Enums.UnitFaction.PLAYER, Vector2i(0, 0))
	assert_eq(DamageCalculator.volley_hits(thumps, MoveData.get_move("Pound")), 2,
			"a diagonal foe isn't next to him")


func test_friends_alongside_do_not_count() -> void:
	_open_grid()
	var thumps := _thumps()
	_unit(Enums.UnitFaction.PLAYER, Vector2i(0, 1))
	_unit(Enums.UnitFaction.ENEMY, Vector2i(2, 1))
	assert_eq(DamageCalculator.volley_hits(thumps, MoveData.get_move("Pound")), 2)


func test_a_fallen_foe_does_not_count() -> void:
	_open_grid()
	var thumps := _thumps()
	_unit(Enums.UnitFaction.PLAYER, Vector2i(0, 1))
	_unit(Enums.UnitFaction.PLAYER, Vector2i(2, 1)).current_hp = 0
	assert_eq(DamageCalculator.volley_hits(thumps, MoveData.get_move("Pound")), 2)


func test_single_hit_moves_stay_single() -> void:
	_open_grid()
	var thumps := _thumps()
	_unit(Enums.UnitFaction.PLAYER, Vector2i(0, 1))
	_unit(Enums.UnitFaction.PLAYER, Vector2i(2, 1))
	assert_eq(DamageCalculator.volley_hits(thumps, MoveData.get_move("Hurl")), 1)


func test_without_the_passive_the_count_is_the_moves() -> void:
	_open_grid()
	var thumps := _unit(Enums.UnitFaction.ENEMY, Vector2i(1, 1))
	_unit(Enums.UnitFaction.PLAYER, Vector2i(0, 1))
	_unit(Enums.UnitFaction.PLAYER, Vector2i(2, 1))
	assert_eq(DamageCalculator.volley_hits(thumps, MoveData.get_move("Pound")), 2)
