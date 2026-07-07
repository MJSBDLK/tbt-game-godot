## Corruption (friendly fire) retarget decision — Unit.resolve_friendly_fire_victim.
## Pins the 2026-07-06 design call: a proc with NO ally in range falls through to
## the ORIGINAL defender (the attack proceeds), it never fizzles. Isolating a
## corrupted unit from its allies is the intended counterplay, so standing alone
## must be safe, not a wasted action. The execute_combat_sequence wiring is not
## re-driven here (same stance as the Protector test) — the decision is what's
## worth pinning.
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()
	_set_battle_units([], [])


func after_all() -> void:
	GridManager.clear_grid()
	_set_battle_units([], [])


func _set_battle_units(players: Array[Unit], enemies: Array[Unit]) -> void:
	TurnManager._player_units = players
	TurnManager._enemy_units = enemies


func _grid_tile(x: int, y: int) -> Tile:
	var tile := Tile.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	add_child_autofree(tile)
	tile.grid_x = x
	tile.grid_y = y
	tile.terrain_type_name = "Plains"
	GridManager.register_tile(tile)
	return tile


func _unit(faction: Enums.UnitFaction, x: int, y: int) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.faction = faction
	unit.current_hp = 10
	unit.character_data = CharacterData.new()
	unit.current_tile = _grid_tile(x, y)
	return unit


func _move(range_value: int = 1) -> Move:
	var move := Move.new()
	move.attack_range = range_value
	return move


func test_no_ally_in_range_keeps_original_target() -> void:
	var attacker := _unit(Enums.UnitFaction.PLAYER, 0, 0)
	var enemy := _unit(Enums.UnitFaction.ENEMY, 1, 0)
	_set_battle_units([attacker], [enemy])
	assert_eq(attacker.resolve_friendly_fire_victim(enemy, _move(1)), enemy,
			"a proc with no ally in range proceeds against the original target (no fizzle)")


func test_ally_in_range_is_hit_instead() -> void:
	var attacker := _unit(Enums.UnitFaction.PLAYER, 0, 0)
	var ally := _unit(Enums.UnitFaction.PLAYER, 0, 1)
	var enemy := _unit(Enums.UnitFaction.ENEMY, 1, 0)
	_set_battle_units([attacker, ally], [enemy])
	assert_eq(attacker.resolve_friendly_fire_victim(enemy, _move(1)), ally,
			"with an ally in reach, the proc redirects onto them")


func test_out_of_range_ally_does_not_attract_the_proc() -> void:
	var attacker := _unit(Enums.UnitFaction.PLAYER, 0, 0)
	var far_ally := _unit(Enums.UnitFaction.PLAYER, 5, 5)
	var enemy := _unit(Enums.UnitFaction.ENEMY, 1, 0)
	_set_battle_units([attacker, far_ally], [enemy])
	assert_eq(attacker.resolve_friendly_fire_victim(enemy, _move(1)), enemy,
			"allies beyond the move's range don't count — attack proceeds normally")


func test_defeated_ally_is_not_a_victim_candidate() -> void:
	var attacker := _unit(Enums.UnitFaction.PLAYER, 0, 0)
	var dead_ally := _unit(Enums.UnitFaction.PLAYER, 0, 1)
	dead_ally.current_hp = 0
	var enemy := _unit(Enums.UnitFaction.ENEMY, 1, 0)
	_set_battle_units([attacker, dead_ally], [enemy])
	assert_eq(attacker.resolve_friendly_fire_victim(enemy, _move(1)), enemy,
			"a downed ally can't soak the proc — attack proceeds normally")
