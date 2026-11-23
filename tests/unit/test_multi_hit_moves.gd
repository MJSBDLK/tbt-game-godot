## Multi-hit moves (Move.hits): one use swings several times. Each hit rolls
## its own accuracy, crit and secondary and deals 1/hits of the damage, so the
## attack stat counts once (DamageCalculator.calculate_damage). The exchange
## runs every "hit" as a volley (Unit._execute_volley), counters included.
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"


func before_each() -> void:
	GridManager.clear_grid()


func after_all() -> void:
	GridManager.clear_grid()


func _open_grid(width: int, height: int = 1) -> void:
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


## Both sides are Spacemen with their passives stripped, so speed is even
## (no bonus swings) and the defender has HP to spare. Thumps fights on the
## enemy side: a player-side level-up would wait for a press.
func _scene_unit(label: String, faction: Enums.UnitFaction, x: int) -> Unit:
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = SPACEMAN_PATH
	unit.faction = faction
	add_child_autofree(unit)
	unit.initialize(GridManager.get_tile(x, 0))
	unit.unit_name = label
	unit.character_data.equipped_passives = []
	unit.character_data.base_max_hp += 200
	unit.current_hp = unit.character_data.max_hp
	return unit


func _bare_unit(strength: int, defense: int) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.current_hp = 20
	var data := CharacterData.new()
	data.base_strength = strength
	data.base_defense = defense
	unit.character_data = data
	return unit


func _sure_hit(move: Move) -> Move:
	move.accuracy = 500
	move.crit_chance = 0.0
	return move


func _strikers(presenter: RecordingPresenter) -> Array[String]:
	var names: Array[String] = []
	for entry: Dictionary in presenter.beats_named("strike"):
		names.append(entry["actor"])
	return names


# =============================================================================
# The numbers
# =============================================================================

func test_a_moves_damage_splits_between_its_hits() -> void:
	var attacker := _bare_unit(10, 0)
	var defender := _bare_unit(0, 2)
	var single := MoveData.get_move("Hurl")
	assert_eq(DamageCalculator.calculate_damage(attacker, defender, single), 14, "10 + 6 - 2")
	assert_eq(DamageCalculator.calculate_damage(attacker, defender, MoveData.get_move("Pound")), 7,
			"the same power in two hits: half each")
	assert_eq(DamageCalculator.calculate_damage(attacker, defender, MoveData.get_move("Maul")), 5,
			"a third each, rounded")


func test_bugle_lands_on_every_hit() -> void:
	var attacker := _bare_unit(10, 0)
	var defender := _bare_unit(0, 2)
	var pummel := MoveData.get_move("Pummel")
	var plain := DamageCalculator.calculate_damage(attacker, defender, pummel)
	StatusEffectSystem.apply_status_effect_by_name(attacker, defender, "BUGLE")
	assert_eq(DamageCalculator.calculate_damage(attacker, defender, pummel), plain + 1,
			"after the split, so three hits take +3")


func test_the_forecast_counts_every_hit() -> void:
	var attacker := _bare_unit(10, 0)
	var defender := _bare_unit(0, 2)
	var pound := MoveData.get_move("Pound")
	assert_eq(DamageCalculator.hits_in_exchange(attacker, defender, pound), 2)
	attacker.character_data.base_athleticism = defender.character_data.athleticism * 2
	assert_eq(DamageCalculator.hits_in_exchange(attacker, defender, pound), 4,
			"a speed double swings the whole volley twice")


func test_thick_skin_stops_speed_not_the_volley() -> void:
	var attacker := _bare_unit(10, 0)
	var defender := _bare_unit(0, 2)
	defender.character_data.equipped_passives = ["Thick Skin"]
	attacker.character_data.base_athleticism = defender.character_data.athleticism * 4
	assert_eq(DamageCalculator.hits_in_exchange(attacker, defender, MoveData.get_move("Pound")), 2)


# =============================================================================
# The exchange
# =============================================================================

func test_pound_swings_twice_before_the_counter() -> void:
	_open_grid(2)
	var thumps := _scene_unit("thumps", Enums.UnitFaction.ENEMY, 0)
	var foe := _scene_unit("foe", Enums.UnitFaction.PLAYER, 1)
	foe.assigned_move = _sure_hit(MoveData.get_move("Bonk"))
	var pound := _sure_hit(MoveData.get_move("Pound"))
	var presenter := RecordingPresenter.new()

	await thumps.execute_combat_sequence(foe, pound, presenter)

	assert_eq(_strikers(presenter), ["thumps", "thumps", "foe"] as Array[String])
	assert_eq(pound.current_uses, pound.max_uses - 1, "one use for the whole swing")


func test_a_counter_is_a_volley_too() -> void:
	_open_grid(2)
	var attacker := _scene_unit("attacker", Enums.UnitFaction.PLAYER, 0)
	var thumps := _scene_unit("thumps", Enums.UnitFaction.ENEMY, 1)
	thumps.assigned_move = _sure_hit(MoveData.get_move("Pound"))
	var presenter := RecordingPresenter.new()

	await attacker.execute_combat_sequence(thumps, _sure_hit(MoveData.get_move("Bonk")), presenter)

	assert_eq(_strikers(presenter), ["attacker", "thumps", "thumps"] as Array[String])


func test_the_volley_stops_when_the_target_falls() -> void:
	_open_grid(2)
	var thumps := _scene_unit("thumps", Enums.UnitFaction.ENEMY, 0)
	var foe := _scene_unit("foe", Enums.UnitFaction.PLAYER, 1)
	foe.current_hp = 1
	var presenter := RecordingPresenter.new()

	await thumps.execute_combat_sequence(foe, _sure_hit(MoveData.get_move("Maul")), presenter)

	assert_eq(presenter.count("strike"), 1)
	assert_eq(presenter.count("death"), 1)


func test_each_hit_rolls_its_own_secondary() -> void:
	_open_grid(2)
	var thumps := _scene_unit("thumps", Enums.UnitFaction.ENEMY, 0)
	var foe := _scene_unit("foe", Enums.UnitFaction.PLAYER, 1)
	var maul := _sure_hit(MoveData.get_move("Maul"))
	maul.status_effect_chance = 1.0
	maul.status_effect_stacks = 1

	await thumps._execute_volley(foe, maul, true, RecordingPresenter.new())

	assert_eq(StatusEffectSystem.get_effect_stacks(foe, "SUBVERSION"), 3, "a stack from each of three hits")


func test_a_speed_bonus_swing_rolls_no_secondaries() -> void:
	_open_grid(2)
	var thumps := _scene_unit("thumps", Enums.UnitFaction.ENEMY, 0)
	var foe := _scene_unit("foe", Enums.UnitFaction.PLAYER, 1)
	var maul := _sure_hit(MoveData.get_move("Maul"))
	maul.status_effect_chance = 1.0

	await thumps._execute_volley(foe, maul, false, RecordingPresenter.new())

	assert_eq(StatusEffectSystem.get_effect_stacks(foe, "SUBVERSION"), 0)


func test_every_hit_rolls_to_hit() -> void:
	_open_grid(2)
	var thumps := _scene_unit("thumps", Enums.UnitFaction.ENEMY, 0)
	var foe := _scene_unit("foe", Enums.UnitFaction.PLAYER, 1)
	var pound := MoveData.get_move("Pound")
	pound.accuracy = -500
	var presenter := RecordingPresenter.new()

	var landed: bool = await thumps._execute_volley(foe, pound, true, presenter)

	assert_false(landed)
	assert_eq(presenter.count("miss"), 2, "two swings, two misses")
