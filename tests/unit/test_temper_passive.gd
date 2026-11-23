## Temper: after a miss, the next swing hits 20% harder and is 15 points less
## accurate. The handler reads Unit.missed_last_swing; the tail pins that the
## real hit roll sets and clears it.
extends GutTest


const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"


func _attacker(missed: bool, passives: Array = ["Temper"]) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	unit.missed_last_swing = missed
	return unit


func _ctx(attacker: TestFakeUnit) -> CombatHitContext:
	var ctx := CombatHitContext.new()
	ctx.attacker = attacker
	ctx.move = Move.new()
	ctx.damage = 10
	ctx.accuracy = 80.0
	return ctx


func test_after_a_miss_the_swing_hits_harder() -> void:
	var ctx := _ctx(_attacker(true))
	TemperPassive.new().modify_damage(ctx)
	assert_eq(ctx.damage, 12)


func test_after_a_miss_the_swing_is_wilder() -> void:
	var ctx := _ctx(_attacker(true))
	TemperPassive.new().modify_accuracy(ctx)
	assert_almost_eq(ctx.accuracy, 80.0 - TemperPassive.ACCURACY_PENALTY, 0.001)


func test_after_a_hit_nothing_changes() -> void:
	var ctx := _ctx(_attacker(false))
	TemperPassive.new().modify_damage(ctx)
	TemperPassive.new().modify_accuracy(ctx)
	assert_eq(ctx.damage, 10)
	assert_almost_eq(ctx.accuracy, 80.0, 0.001)


func test_a_miss_without_the_passive_changes_nothing() -> void:
	var ctx := _ctx(_attacker(true, []))
	TemperPassive.new().modify_damage(ctx)
	assert_eq(ctx.damage, 10)


func test_registry_resolves_temper() -> void:
	assert_true(PassiveRegistry.get_handler("Temper") is TemperPassive)


# =============================================================================
# The hit roll keeps the flag
# =============================================================================

func _spawn_unit(json_path: String, faction: Enums.UnitFaction) -> Unit:
	var unit: Unit = (load("res://scenes/battle/unit.tscn") as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	var container := Node2D.new()
	add_child_autofree(container)
	container.add_child(unit)
	var tile := Tile.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	add_child_autofree(tile)
	tile.terrain_type_name = "Plains"
	unit.initialize(tile)
	return unit


func _swing(accuracy: int) -> Move:
	var move := Move.new()
	move.move_name = "Test Swing"
	move.damage_type = Enums.DamageType.PHYSICAL
	move.base_power = 1
	move.accuracy = accuracy
	move.attack_range = 1
	return move


func test_a_miss_sets_the_flag_and_a_hit_clears_it() -> void:
	var attacker := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	var target := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)
	target.current_hp = 999
	await attacker._execute_single_hit(target, _swing(-1000), true)
	assert_true(attacker.missed_last_swing, "a 0% swing misses and remembers it")
	await attacker._execute_single_hit(target, _swing(1000), true)
	assert_false(attacker.missed_last_swing, "the next landed hit settles it")
