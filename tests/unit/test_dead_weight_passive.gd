## Dead Weight: when the owner falls, by any cause, every foe next to it is
## ROOTED for a turn. Dispatched from PassiveEffectsSystem on Unit.unit_defeated.
extends GutTest


var _saved_players: Array[Unit] = []
var _saved_enemies: Array[Unit] = []


func before_each() -> void:
	GridManager.clear_grid()
	_saved_players = TurnManager._player_units
	_saved_enemies = TurnManager._enemy_units


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
	var unit := Unit.new()
	autofree(unit)
	unit.unit_name = label
	unit.faction = faction
	unit.current_hp = 20
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	var tile := GridManager.get_tile(cell.x, cell.y)
	unit.current_tile = tile
	tile.current_unit = unit
	return unit


func _rooted(unit: Unit) -> int:
	return StatusEffectSystem.get_effect_stacks(unit, "ROOTED")


func test_foes_next_to_the_body_are_pinned() -> void:
	_open_grid()
	var squash := _unit("squash", Enums.UnitFaction.ENEMY, Vector2i(2, 1), ["Dead Weight"])
	var left := _unit("left", Enums.UnitFaction.PLAYER, Vector2i(1, 1))
	var below := _unit("below", Enums.UnitFaction.PLAYER, Vector2i(2, 0))
	var far := _unit("far", Enums.UnitFaction.PLAYER, Vector2i(4, 1))
	var friend := _unit("friend", Enums.UnitFaction.ENEMY, Vector2i(3, 1))
	squash.current_hp = 0
	squash.is_defeated_flag = true
	PassiveEffectsSystem.notify_fallen(squash)
	assert_eq([_rooted(left), _rooted(below)], [1, 1])
	assert_eq([_rooted(far), _rooted(friend)], [0, 0])


func test_any_death_counts() -> void:
	_open_grid()
	var squash := _unit("squash", Enums.UnitFaction.ENEMY, Vector2i(2, 1), ["Dead Weight"])
	var foe := _unit("foe", Enums.UnitFaction.PLAYER, Vector2i(1, 1))
	TurnManager._player_units = [foe] as Array[Unit]
	TurnManager._enemy_units = [squash] as Array[Unit]
	PassiveEffectsSystem.register_battle_units([foe] as Array[Unit], [squash] as Array[Unit])
	squash.take_damage(999, {"name": "Burn"})
	assert_eq(_rooted(foe), 1, "a DoT kill pins too: the signal path, not the hit path")


func test_without_the_passive_the_body_is_just_a_body() -> void:
	_open_grid()
	var squash := _unit("squash", Enums.UnitFaction.ENEMY, Vector2i(2, 1))
	var foe := _unit("foe", Enums.UnitFaction.PLAYER, Vector2i(1, 1))
	squash.current_hp = 0
	squash.is_defeated_flag = true
	PassiveEffectsSystem.notify_fallen(squash)
	assert_eq(_rooted(foe), 0)


func test_registry_resolves_dead_weight() -> void:
	assert_true(PassiveRegistry.get_handler("Dead Weight") is DeadWeightPassive)
