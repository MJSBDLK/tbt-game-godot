## Tag Along: when a foe that started its walk next to him ends it out of
## reach, he steps into the tile it left. Fires on a COMMITTED walk
## (Unit.path_traversed from set_acted, PassiveEffectsSystem.notify_walked).
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"

var _saved_players: Array[Unit] = []
var _saved_enemies: Array[Unit] = []


func before_each() -> void:
	GridManager.clear_grid()
	_saved_players = TurnManager._player_units
	_saved_enemies = TurnManager._enemy_units
	TurnManager._player_units = [] as Array[Unit]
	TurnManager._enemy_units = [] as Array[Unit]


func after_each() -> void:
	TurnManager._player_units = _saved_players
	TurnManager._enemy_units = _saved_enemies


func after_all() -> void:
	GridManager.clear_grid()


func _open_grid(width: int = 5, height: int = 3) -> void:
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
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = SPACEMAN_PATH
	unit.faction = faction
	add_child_autofree(unit)
	unit.initialize(_tile(cell))
	unit.unit_name = label
	unit.character_data.equipped_passives = passives.duplicate()
	if faction == Enums.UnitFaction.PLAYER:
		TurnManager._player_units.append(unit)
	else:
		TurnManager._enemy_units.append(unit)
	return unit


func _tile(cell: Vector2i) -> Tile:
	return GridManager.get_tile(cell.x, cell.y)


## `walker` walks from where it stands to `to` and the walk commits.
func _walk(walker: Unit, to: Vector2i) -> void:
	var from := walker.current_tile
	walker.move_to_tile(_tile(to))
	PassiveEffectsSystem.notify_walked(walker, [from, _tile(to)] as Array[Tile])


func _thumps() -> Unit:
	return _unit("thumps", Enums.UnitFaction.ENEMY, Vector2i(2, 1), ["Tag Along"])


func test_he_follows_a_foe_that_walks_away() -> void:
	_open_grid()
	var thumps := _thumps()
	var foe := _unit("foe", Enums.UnitFaction.PLAYER, Vector2i(1, 1))
	_walk(foe, Vector2i(0, 0))
	assert_eq(thumps.current_tile, _tile(Vector2i(1, 1)), "into the tile it left")
	assert_null(_tile(Vector2i(2, 1)).current_unit, "his old tile is free")


func test_a_foe_that_stays_alongside_is_not_followed() -> void:
	_open_grid()
	var thumps := _thumps()
	var foe := _unit("foe", Enums.UnitFaction.PLAYER, Vector2i(1, 1))
	_walk(foe, Vector2i(2, 2))
	assert_eq(thumps.current_tile, _tile(Vector2i(2, 1)))


func test_a_foe_that_started_away_from_him_is_not_followed() -> void:
	_open_grid()
	var thumps := _thumps()
	var foe := _unit("foe", Enums.UnitFaction.PLAYER, Vector2i(0, 1))
	_walk(foe, Vector2i(0, 2))
	assert_eq(thumps.current_tile, _tile(Vector2i(2, 1)))


func test_a_friend_walking_off_is_not_followed() -> void:
	_open_grid()
	var thumps := _thumps()
	var friend := _unit("friend", Enums.UnitFaction.ENEMY, Vector2i(1, 1))
	_walk(friend, Vector2i(0, 0))
	assert_eq(thumps.current_tile, _tile(Vector2i(2, 1)))


func test_rooted_he_stays() -> void:
	_open_grid()
	var thumps := _thumps()
	StatusEffectSystem.apply_status_effect_by_name(thumps, thumps, "ROOTED", 1)
	var foe := _unit("foe", Enums.UnitFaction.PLAYER, Vector2i(1, 1))
	_walk(foe, Vector2i(0, 0))
	assert_eq(thumps.current_tile, _tile(Vector2i(2, 1)))


func test_two_followers_one_tile() -> void:
	_open_grid()
	var first := _thumps()
	var second := _unit("second", Enums.UnitFaction.ENEMY, Vector2i(1, 2), ["Tag Along"])
	var foe := _unit("foe", Enums.UnitFaction.PLAYER, Vector2i(1, 1))
	_walk(foe, Vector2i(0, 0))
	var left_tile := _tile(Vector2i(1, 1))
	assert_true(first.current_tile == left_tile or second.current_tile == left_tile, "one of them takes it")
	assert_ne(first.current_tile, second.current_tile, "the other finds it taken and stays")


func test_without_the_passive_he_stays() -> void:
	_open_grid()
	var thumps := _unit("thumps", Enums.UnitFaction.ENEMY, Vector2i(2, 1))
	var foe := _unit("foe", Enums.UnitFaction.PLAYER, Vector2i(1, 1))
	_walk(foe, Vector2i(0, 0))
	assert_eq(thumps.current_tile, _tile(Vector2i(2, 1)))


func test_the_committed_walk_drags_him() -> void:
	_open_grid()
	var thumps := _thumps()
	var foe := _unit("foe", Enums.UnitFaction.PLAYER, Vector2i(1, 1))
	PassiveEffectsSystem.register_battle_units(TurnManager._player_units, TurnManager._enemy_units)
	var from := foe.current_tile
	foe.move_to_tile(_tile(Vector2i(0, 0)))
	foe._pending_track_tiles = [from, _tile(Vector2i(0, 1)), _tile(Vector2i(0, 0))] as Array[Tile]
	assert_eq(thumps.current_tile, _tile(Vector2i(2, 1)), "not before the move commits")
	foe.set_acted()
	assert_eq(thumps.current_tile, from)
