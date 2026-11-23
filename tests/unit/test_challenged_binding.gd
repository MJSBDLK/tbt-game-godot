## CHALLENGED binds the player side too (Staredown, Gloat): a challenged unit's
## single-target attacks can only go to its challenger. Self-casts and moves
## for allies stay free. MoveTargeting.can_target is the one predicate, so the
## menu, highlights, clicks and the AI all follow it.
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()


func after_all() -> void:
	GridManager.clear_grid()


func _open_grid(width: int, height: int) -> void:
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


func _unit(label: String, faction: Enums.UnitFaction, x: int, y: int = 0) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.unit_name = label
	unit.faction = faction
	unit.current_hp = 20
	unit.character_data = CharacterData.new()
	var tile := GridManager.get_tile(x, y)
	unit.current_tile = tile
	tile.current_unit = unit
	return unit


func _ranged_attack() -> Move:
	var move := Move.new()
	move.move_name = "Test Shot"
	move.base_power = 5
	move.attack_range = 3
	return move


func test_a_challenged_player_can_only_aim_at_the_challenger() -> void:
	_open_grid(5, 1)
	var hero := _unit("hero", Enums.UnitFaction.PLAYER, 0)
	var challenger := _unit("challenger", Enums.UnitFaction.ENEMY, 1)
	var other := _unit("other", Enums.UnitFaction.ENEMY, 2)
	StatusEffectSystem.apply_status_effect_by_name(challenger, hero, "CHALLENGED")
	assert_true(MoveTargeting.can_target(hero, challenger, _ranged_attack()))
	assert_false(MoveTargeting.can_target(hero, other, _ranged_attack()))
	var tiles := MoveTargeting.get_valid_target_tiles(hero, _ranged_attack())
	assert_eq_deep(tiles, [challenger.current_tile] as Array[Tile])


func test_unchallenged_aim_is_free() -> void:
	_open_grid(5, 1)
	var hero := _unit("hero", Enums.UnitFaction.PLAYER, 0)
	_unit("first", Enums.UnitFaction.ENEMY, 1)
	var other := _unit("other", Enums.UnitFaction.ENEMY, 2)
	assert_true(MoveTargeting.can_target(hero, other, _ranged_attack()))


func test_moves_for_allies_stay_free() -> void:
	_open_grid(5, 1)
	var hero := _unit("hero", Enums.UnitFaction.PLAYER, 0)
	var friend := _unit("friend", Enums.UnitFaction.PLAYER, 1)
	var challenger := _unit("challenger", Enums.UnitFaction.ENEMY, 2)
	StatusEffectSystem.apply_status_effect_by_name(challenger, hero, "CHALLENGED")
	friend.current_hp = 5
	assert_true(MoveTargeting.can_target(hero, friend, MoveData.get_move("First Aid")))


func test_self_casts_stay_free() -> void:
	_open_grid(5, 1)
	var hero := _unit("hero", Enums.UnitFaction.PLAYER, 1)
	_unit("bystander", Enums.UnitFaction.ENEMY, 0)
	var challenger := _unit("challenger", Enums.UnitFaction.ENEMY, 3)
	StatusEffectSystem.apply_status_effect_by_name(challenger, hero, "CHALLENGED")
	assert_true(MoveTargeting.can_target(hero, hero, MoveData.get_move("Elbows")),
			"Elbows still swings at whoever is close")


func test_the_bond_breaks_when_the_challenger_falls() -> void:
	_open_grid(5, 1)
	var hero := _unit("hero", Enums.UnitFaction.PLAYER, 0)
	var challenger := _unit("challenger", Enums.UnitFaction.ENEMY, 1)
	var other := _unit("other", Enums.UnitFaction.ENEMY, 2)
	StatusEffectSystem.apply_status_effect_by_name(challenger, hero, "CHALLENGED")
	challenger.current_hp = 0
	challenger.is_defeated_flag = true
	assert_null(MoveTargeting.active_challenger(hero))
	assert_true(MoveTargeting.can_target(hero, other, _ranged_attack()))


func test_the_ai_reads_the_same_challenger() -> void:
	_open_grid(5, 1)
	var brute := _unit("brute", Enums.UnitFaction.ENEMY, 0)
	var squash := _unit("squash", Enums.UnitFaction.PLAYER, 2)
	StatusEffectSystem.apply_status_effect(squash, brute, MoveData.get_move("Staredown"))
	var ai := EnemyAI.new()
	autofree(ai)
	ai._unit = brute
	assert_eq(ai._active_challenger(), squash)
