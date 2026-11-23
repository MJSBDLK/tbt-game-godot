## Big Gut: a foe that lands a melee hit on the owner is bounced one tile back
## (constitution save, Bounce Out's margin), once per exchange, after the
## counters. Dispatched by Unit._run_offensive_exchange through
## PassiveEffectsSystem.notify_attacked.
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"


func before_each() -> void:
	GridManager.clear_grid()


func after_all() -> void:
	GridManager.clear_grid()


func _open_row(width: int) -> void:
	for x: int in range(width):
		var tile := Tile.new()
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		tile.add_child(sprite)
		add_child_autofree(tile)
		tile.grid_x = x
		tile.grid_y = 0
		tile.terrain_type_name = "Plains"
		GridManager.register_tile(tile)


func _scene_unit(json_path: String, faction: Enums.UnitFaction, x: int) -> Unit:
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	add_child_autofree(unit)
	unit.initialize(GridManager.get_tile(x, 0))
	unit.character_data.equipped_passives = []
	unit.assigned_move = null
	return unit


## A sturdy Big Gut owner at x = 2 and a lighter attacker at `attacker_x`.
func _setup(attacker_x: int = 1) -> Array[Unit]:
	_open_row(5)
	var attacker := _scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, attacker_x)
	var squash := _scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 2)
	squash.character_data.equipped_passives = ["Big Gut"]
	squash.character_data.constitution = 8
	attacker.character_data.constitution = 5
	squash.character_data.base_max_hp += 80
	squash.current_hp = squash.character_data.max_hp
	return [attacker, squash]


func _poke(attack_range: int = 1, accuracy: int = 500) -> Move:
	var move := Move.new()
	move.move_name = "Test Poke"
	move.base_power = 1
	move.accuracy = accuracy
	move.attack_range = attack_range
	move.max_uses = 5
	move.current_uses = 5
	return move


func test_a_melee_hit_bounces_off_the_belly() -> void:
	var units := _setup()
	await units[0].execute_combat_sequence(units[1], _poke(), RecordingPresenter.new())
	assert_eq(units[0].current_tile, GridManager.get_tile(0, 0), "bounced one tile back")
	assert_eq(units[1].current_tile, GridManager.get_tile(2, 0), "the belly holds its ground")


func test_a_stout_attacker_holds() -> void:
	var units := _setup()
	units[0].character_data.constitution = 8
	await units[0].execute_combat_sequence(units[1], _poke(), RecordingPresenter.new())
	assert_eq(units[0].current_tile, GridManager.get_tile(1, 0))


func test_a_ranged_hit_doesnt_touch_the_belly() -> void:
	var units := _setup(0)
	await units[0].execute_combat_sequence(units[1], _poke(2), RecordingPresenter.new())
	assert_eq(units[0].current_tile, GridManager.get_tile(0, 0))


func test_a_miss_doesnt_bounce() -> void:
	var units := _setup()
	await units[0].execute_combat_sequence(units[1], _poke(1, -500), RecordingPresenter.new())
	assert_eq(units[0].current_tile, GridManager.get_tile(1, 0))


func test_the_bounce_waits_for_his_counter() -> void:
	var units := _setup()
	var counter := _poke()
	units[1].assigned_move = counter
	var attacker_hp := units[0].current_hp
	var presenter := RecordingPresenter.new()
	await units[0].execute_combat_sequence(units[1], _poke(), presenter)
	assert_lt(units[0].current_hp, attacker_hp, "he got his counter in")
	assert_eq(presenter.beat_names().back(), "close")
	var names := presenter.beat_names()
	assert_gt(names.rfind("displace"), names.rfind("strike"), "the bounce comes after every swing")
	assert_eq(units[0].current_tile, GridManager.get_tile(0, 0))


func test_registry_resolves_big_gut() -> void:
	assert_true(PassiveRegistry.get_handler("Big Gut") is BigGutPassive)
