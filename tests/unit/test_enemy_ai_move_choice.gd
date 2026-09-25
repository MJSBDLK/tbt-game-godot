## EnemyAI move choice: per target, the usable damaging move with the best
## expected damage, whatever slot it sits in; a walk that falls short of its
## target swings at whoever it did reach.
extends GutTest


var _saved_player_units: Array[Unit] = []


func before_each() -> void:
	GridManager.clear_grid()
	_saved_player_units = TurnManager._player_units


func after_each() -> void:
	TurnManager._player_units = _saved_player_units


func after_all() -> void:
	GridManager.clear_grid()


func _open_grid(max_x: int, max_y: int) -> void:
	for x: int in range(max_x + 1):
		for y: int in range(max_y + 1):
			var tile := Tile.new()
			var sprite := Sprite2D.new()
			sprite.name = "Sprite2D"
			tile.add_child(sprite)
			add_child_autofree(tile)
			tile.grid_x = x
			tile.grid_y = y
			tile.terrain_type_name = "Plains"
			GridManager.register_tile(tile)


func _attack(move_name: String, power: int, attack_range: int = 1) -> Move:
	var move := Move.new()
	move.move_name = move_name
	move.damage_type = Enums.DamageType.PHYSICAL
	move.base_power = power
	move.attack_range = attack_range
	return move


func _self_buff() -> Move:
	var move := Move.new()
	move.move_name = "Fortify"
	move.damage_type = Enums.DamageType.SUPPORT
	move.target_type = Enums.TargetType.SELF
	move.attack_range = 0
	return move


func _unit(faction: Enums.UnitFaction, x: int, y: int, moves: Array = []) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.unit_name = "unit %d,%d" % [x, y]
	unit.faction = faction
	var data := CharacterData.new()
	var typed_moves: Array[Move] = []
	for move: Move in moves:
		typed_moves.append(move)
	data.equipped_moves = typed_moves
	unit.character_data = data
	unit.current_hp = data.max_hp
	var tile: Tile = GridManager.get_tile(x, y)
	unit.current_tile = tile
	tile.current_unit = unit
	return unit


func _ai_for(unit: Unit) -> EnemyAI:
	# In the tree so target scoring can reach /root/TurnManager; its _ready binds
	# to the test (not a Unit) and no-ops, so bind the unit directly.
	var ai := EnemyAI.new()
	add_child_autofree(ai)
	ai._unit = unit
	return ai


func test_a_support_move_on_top_no_longer_benches_the_attack() -> void:
	_open_grid(2, 0)
	var bonk := _attack("Bonk", 5)
	var enemy := _unit(Enums.UnitFaction.ENEMY, 0, 0, [_self_buff(), bonk])
	var player := _unit(Enums.UnitFaction.PLAYER, 1, 0)
	assert_eq(_ai_for(enemy)._pick_attack_move(player), bonk,
			"the damaging move in slot 2 is found and swung")


func test_the_hardest_expected_hit_wins() -> void:
	_open_grid(2, 0)
	var tap := _attack("Tap", 5)
	var wallop := _attack("Wallop", 15)
	var enemy := _unit(Enums.UnitFaction.ENEMY, 0, 0, [tap, wallop])
	var player := _unit(Enums.UnitFaction.PLAYER, 1, 0)
	assert_eq(_ai_for(enemy)._pick_attack_move(player), wallop,
			"slot order doesn't win over a bigger hit")


func test_a_spent_move_is_passed_over() -> void:
	_open_grid(2, 0)
	var wallop := _attack("Wallop", 15)
	wallop.current_uses = 0
	var tap := _attack("Tap", 5)
	var enemy := _unit(Enums.UnitFaction.ENEMY, 0, 0, [wallop, tap])
	var player := _unit(Enums.UnitFaction.PLAYER, 1, 0)
	assert_eq(_ai_for(enemy)._pick_attack_move(player), tap,
			"an empty move no longer silences the whole kit")


func test_only_moves_that_reach_are_considered() -> void:
	_open_grid(3, 0)
	var bonk := _attack("Bonk", 15, 1)
	var sling := _attack("Sling", 5, 3)
	var enemy := _unit(Enums.UnitFaction.ENEMY, 0, 0, [bonk, sling])
	var player := _unit(Enums.UnitFaction.PLAYER, 3, 0)
	var ai := _ai_for(enemy)
	assert_eq(ai._pick_attack_move(player), sling, "the long move is the one that reaches")
	sling.attack_range = 2
	assert_null(ai._pick_attack_move(player), "nothing reaches — no swing")


func test_a_short_walk_swings_at_whoever_it_reached() -> void:
	# The wounded far unit out-scores the healthy adjacent one, so it's the
	# chosen target — but only the adjacent one can be hit from here.
	_open_grid(4, 0)
	var enemy := _unit(Enums.UnitFaction.ENEMY, 0, 0, [_attack("Bonk", 5)])
	var adjacent := _unit(Enums.UnitFaction.PLAYER, 1, 0)
	var wounded := _unit(Enums.UnitFaction.PLAYER, 3, 0)
	wounded.current_hp = 1
	TurnManager._player_units = [adjacent, wounded]
	var ai := _ai_for(enemy)
	assert_eq(ai._find_best_target(), wounded, "precondition: blood in the water wins scoring")
	assert_eq(ai._find_best_target(true), adjacent, "in reach narrows the field to who can be hit")


func test_in_reach_returns_null_when_nobody_is() -> void:
	_open_grid(4, 0)
	var enemy := _unit(Enums.UnitFaction.ENEMY, 0, 0, [_attack("Bonk", 5)])
	TurnManager._player_units = [_unit(Enums.UnitFaction.PLAYER, 3, 0)]
	assert_null(_ai_for(enemy)._find_best_target(true))


func test_the_swung_move_stays_armed_for_the_counter() -> void:
	# Spawn arms the first usable move; with a support move on top the unit
	# couldn't counter at all until it first attacked.
	_open_grid(0, 0)
	var bonk := _attack("Bonk", 5)
	var enemy := _unit(Enums.UnitFaction.ENEMY, 0, 0, [_self_buff(), bonk])
	enemy.auto_assign_first_usable_move()
	assert_eq(enemy.assigned_move.move_name, "Fortify", "precondition: spawn armed the buff")
	_ai_for(enemy)._prefer_damaging_counter_move()
	assert_eq(enemy.assigned_move, bonk, "an AI unit arms its first damaging move")
	assert_true(DamageCalculator.is_counter_eligible(enemy), "so it can counter from turn one")


func test_a_support_only_kit_keeps_its_arming() -> void:
	_open_grid(0, 0)
	var buff := _self_buff()
	var enemy := _unit(Enums.UnitFaction.ENEMY, 0, 0, [buff])
	enemy.assigned_move = buff
	_ai_for(enemy)._prefer_damaging_counter_move()
	assert_eq(enemy.assigned_move, buff, "nothing damaging to arm — leave it be")
