## Cover: an ally marked COVERED has its single-target attacks land on the
## bodyguard (the status' source) while the bodyguard stands next to it.
## MoveTargeting.resolve_actual_target decides; Unit.execute_combat_sequence
## and the combat preview both call it.
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"


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


func _unit(label: String, faction: Enums.UnitFaction, x: int, y: int = 0, passives: Array = []) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.unit_name = label
	unit.faction = faction
	unit.current_hp = 20
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	var tile := GridManager.get_tile(x, y)
	unit.current_tile = tile
	tile.current_unit = unit
	return unit


func _cover(bodyguard: Unit, ally: Unit) -> void:
	StatusEffectSystem.apply_status_effect(bodyguard, ally, MoveData.get_move("Cover"))


func _attack(attack_range: int = 1) -> Move:
	var move := Move.new()
	move.move_name = "Test Hit"
	move.base_power = 5
	move.attack_range = attack_range
	return move


# =============================================================================
# The redirect
# =============================================================================

func test_an_attack_on_the_covered_ally_lands_on_the_bodyguard() -> void:
	_open_grid(4, 2)
	var squash := _unit("squash", Enums.UnitFaction.PLAYER, 1, 1)
	var ally := _unit("ally", Enums.UnitFaction.PLAYER, 1, 0)
	var foe := _unit("foe", Enums.UnitFaction.ENEMY, 2, 0)
	_cover(squash, ally)
	assert_eq(MoveTargeting.resolve_actual_target(foe, ally, _attack()), squash)


func test_a_bodyguard_pushed_away_covers_nothing() -> void:
	_open_grid(4, 3)
	var squash := _unit("squash", Enums.UnitFaction.PLAYER, 1, 2)
	var ally := _unit("ally", Enums.UnitFaction.PLAYER, 1, 0)
	var foe := _unit("foe", Enums.UnitFaction.ENEMY, 2, 0)
	_cover(squash, ally)
	assert_eq(MoveTargeting.resolve_actual_target(foe, ally, _attack()), ally)


func test_a_fallen_bodyguard_covers_nothing() -> void:
	_open_grid(4, 2)
	var squash := _unit("squash", Enums.UnitFaction.PLAYER, 1, 1)
	var ally := _unit("ally", Enums.UnitFaction.PLAYER, 1, 0)
	var foe := _unit("foe", Enums.UnitFaction.ENEMY, 2, 0)
	_cover(squash, ally)
	squash.current_hp = 0
	squash.is_defeated_flag = true
	assert_null(MoveTargeting.covering_bodyguard(ally))
	assert_eq(MoveTargeting.resolve_actual_target(foe, ally, _attack()), ally)


func test_cover_beats_a_protector_on_the_line() -> void:
	_open_grid(5, 2)
	var squash := _unit("squash", Enums.UnitFaction.PLAYER, 0, 1)
	var ally := _unit("ally", Enums.UnitFaction.PLAYER, 0, 0)
	_unit("protector", Enums.UnitFaction.PLAYER, 2, 0, ["Protector"])
	var archer := _unit("archer", Enums.UnitFaction.ENEMY, 4, 0)
	_cover(squash, ally)
	assert_eq(MoveTargeting.resolve_actual_target(archer, ally, _attack(4)), squash)


func test_help_for_the_covered_ally_still_reaches_it() -> void:
	_open_grid(4, 2)
	var squash := _unit("squash", Enums.UnitFaction.PLAYER, 1, 1)
	var ally := _unit("ally", Enums.UnitFaction.PLAYER, 1, 0)
	var medic := _unit("medic", Enums.UnitFaction.PLAYER, 2, 0)
	_cover(squash, ally)
	assert_eq(MoveTargeting.resolve_actual_target(medic, ally, MoveData.get_move("First Aid")), ally)


func test_cover_wears_off_on_the_users_next_turn() -> void:
	_open_grid(4, 2)
	var squash := _unit("squash", Enums.UnitFaction.PLAYER, 1, 1)
	var ally := _unit("ally", Enums.UnitFaction.PLAYER, 1, 0)
	_cover(squash, ally)
	StatusEffectSystem.process_turn_start_effects(ally)
	assert_eq(StatusEffectSystem.get_effect_stacks(ally, "COVERED"), 0)


# =============================================================================
# One buff slot
# =============================================================================

func test_cover_takes_the_slot_from_another_buff() -> void:
	_open_grid(2, 1)
	var squash := _unit("squash", Enums.UnitFaction.PLAYER, 0)
	var ally := _unit("ally", Enums.UnitFaction.PLAYER, 1)
	StatusEffectSystem.apply_status_effect_by_name(ally, ally, "FORTIFIED", 2)
	assert_true(MoveData.get_move("Cover").has_meaningful_effect_on(ally))
	_cover(squash, ally)
	assert_eq(StatusEffectSystem.get_effect_stacks(ally, "FORTIFIED"), 0)
	assert_eq(StatusEffectSystem.get_effect_stacks(ally, "COVERED"), 1)


func test_brace_greys_out_on_an_ally_holding_another_buff() -> void:
	_open_grid(2, 1)
	var squash := _unit("squash", Enums.UnitFaction.PLAYER, 0)
	var ally := _unit("ally", Enums.UnitFaction.PLAYER, 1)
	_cover(squash, ally)
	assert_false(MoveData.get_move("Brace").has_meaningful_effect_on(ally),
			"Fortified would bounce off the slot Cover holds")


# =============================================================================
# A whole exchange
# =============================================================================

func _scene_unit(json_path: String, faction: Enums.UnitFaction, x: int, y: int) -> Unit:
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	add_child_autofree(unit)
	unit.initialize(GridManager.get_tile(x, y))
	unit.character_data.equipped_passives = []
	return unit


func test_the_bodyguard_takes_the_blow() -> void:
	_open_grid(3, 2)
	var squash := _scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 1, 1)
	var ally := _scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 1, 0)
	var foe := _scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 2, 0)
	squash.assigned_move = null
	_cover(squash, ally)
	foe.character_data.base_strength += 20
	var squash_hp := squash.current_hp
	var ally_hp := ally.current_hp
	var club := MoveData.get_move("Club")
	club.accuracy = 500

	await foe.execute_combat_sequence(ally, club, RecordingPresenter.new())

	assert_eq(ally.current_hp, ally_hp, "the covered ally is untouched")
	assert_lt(squash.current_hp, squash_hp, "the bodyguard took it")
