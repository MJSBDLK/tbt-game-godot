## The Heavy kit's new moves (Thumps), read from the real move bank: Pound,
## Hurl, Maul and Pummel (the volley mechanic is test_multi_hit_moves),
## Tantrum (test_tantrum), and the casts: Lighten and Burden (the glowing
## stones) and Lift.
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"


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


func _board_unit(label: String, faction: Enums.UnitFaction, x: int) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.unit_name = label
	unit.faction = faction
	unit.current_hp = 20
	unit.character_data = CharacterData.new()
	var tile := GridManager.get_tile(x, 0)
	unit.current_tile = tile
	tile.current_unit = unit
	return unit


func _scene_unit(json_path: String, faction: Enums.UnitFaction, x: int) -> Unit:
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	add_child_autofree(unit)
	unit.initialize(GridManager.get_tile(x, 0))
	unit.character_data.equipped_passives = []
	return unit


func _final_cell(plan: DisplacementSystem.DisplacePlan, unit: Unit) -> Vector2i:
	var mover: Dictionary = plan.mover_for(unit)
	if mover.is_empty():
		return Vector2i(-999, -999)
	var tile: Tile = (mover.path as Array[Tile]).back()
	return Vector2i(tile.grid_x, tile.grid_y)


# =============================================================================
# Parsed shapes
# =============================================================================

func test_pound_is_two_hits_that_can_crit() -> void:
	var pound := MoveData.get_move("Pound")
	assert_eq([pound.hits, pound.base_power, pound.accuracy, pound.attack_range], [2, 6, 85, 1])
	assert_almost_eq(pound.crit_chance, 0.1, 0.001)
	assert_false(pound.crit_self_target, "it crits the hit it lands")


func test_hurl_throws_the_hammer() -> void:
	var hurl := MoveData.get_move("Hurl")
	assert_eq([hurl.hits, hurl.base_power, hurl.accuracy, hurl.attack_range], [1, 6, 70, 2])
	assert_eq(hurl.effective_animation_style(), "ranged", "plays the throw clip")


func test_maul_is_three_hits_that_can_subvert() -> void:
	var maul := MoveData.get_move("Maul")
	assert_eq([maul.hits, maul.base_power, maul.accuracy], [3, 6, 80])
	assert_eq(maul.status_effect_type, Enums.StatusEffectType.SUBVERSION)
	assert_almost_eq(maul.status_effect_chance, 0.2, 0.001)


func test_pummel_is_his_heraldic_volley() -> void:
	var pummel := MoveData.get_move("Pummel")
	assert_eq([pummel.hits, pummel.base_power, pummel.accuracy], [3, 5, 80])
	assert_eq(pummel.element_type, Enums.ElementalType.HERALDIC)


func test_the_stones_are_support_casts_with_eight_uses() -> void:
	for move_name: String in ["Lighten", "Burden"]:
		var stone := MoveData.get_move(move_name)
		assert_eq([stone.damage_type, stone.attack_range, stone.max_uses],
				[Enums.DamageType.SUPPORT, 1, 8], move_name)
	assert_eq(MoveData.get_move("Lighten").target_type, Enums.TargetType.ALLY, "a friend or himself")
	assert_eq(Array(MoveData.get_move("Lighten").cleanse_effects), ["DEBUFF"])
	var burden := MoveData.get_move("Burden")
	assert_eq(burden.target_type, Enums.TargetType.SINGLE, "a foe")
	assert_eq([burden.status_effect_type, burden.status_effect_stacks],
			[Enums.StatusEffectType.GRAVITY, 3])


func test_lift_moves_a_friend_over_the_user() -> void:
	var lift := MoveData.get_move("Lift")
	assert_eq([lift.damage_type, lift.target_type], [Enums.DamageType.SUPPORT, Enums.TargetType.ALLY_NOT_SELF])
	assert_eq([lift.displace_distance, lift.displace_vector, lift.displace_on_blocked],
			[2, "toward_attacker", "fall_through"])


# =============================================================================
# Lighten: only where there's a weight to lift
# =============================================================================

func test_lighten_needs_a_debuff_to_clear() -> void:
	_open_grid(2)
	var thumps := _board_unit("thumps", Enums.UnitFaction.PLAYER, 0)
	var friend := _board_unit("friend", Enums.UnitFaction.PLAYER, 1)
	var lighten := MoveData.get_move("Lighten")
	assert_false(lighten.has_meaningful_effect_on(friend), "nothing to clear")
	StatusEffectSystem.apply_status_effect_by_name(thumps, friend, "FORTIFIED", 2)
	assert_false(lighten.has_meaningful_effect_on(friend), "a buff isn't a weight")
	StatusEffectSystem.apply_status_effect_by_name(thumps, friend, "ROOTED", 1)
	assert_true(lighten.has_meaningful_effect_on(friend), "the debuff slot holds something")


func test_lighten_clears_a_friends_debuff() -> void:
	_open_grid(2)
	var thumps := _scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0)
	var friend := _scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 1)
	StatusEffectSystem.apply_status_effect_by_name(thumps, friend, "GRAVITY", 2)
	StatusEffectSystem.apply_status_effect_by_name(thumps, friend, "FORTIFIED", 2)

	await thumps.execute_combat_sequence(friend, MoveData.get_move("Lighten"), RecordingPresenter.new())

	assert_eq(StatusEffectSystem.get_effect_stacks(friend, "GRAVITY"), 0)
	assert_eq(StatusEffectSystem.get_effect_stacks(friend, "FORTIFIED"), 2, "the buff stays")


func test_lighten_works_on_himself() -> void:
	_open_grid(1)
	var thumps := _scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0)
	StatusEffectSystem.apply_status_effect_by_name(thumps, thumps, "ROOTED", 1)
	await thumps.execute_combat_sequence(thumps, MoveData.get_move("Lighten"), RecordingPresenter.new())
	assert_eq(StatusEffectSystem.get_effect_stacks(thumps, "ROOTED"), 0)


# =============================================================================
# Burden: a weight on a foe, no fight
# =============================================================================

func test_burden_weighs_a_foe_down_without_a_fight() -> void:
	_open_grid(2)
	var thumps := _scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0)
	var foe := _scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1)
	var counter_move := MoveData.get_move("Club")
	foe.assigned_move = counter_move
	var hp := [thumps.current_hp, foe.current_hp]

	await thumps.execute_combat_sequence(foe, MoveData.get_move("Burden"), RecordingPresenter.new())

	assert_eq(StatusEffectSystem.get_effect_stacks(foe, "GRAVITY"), 3)
	assert_eq([thumps.current_hp, foe.current_hp], hp, "no damage either way")
	assert_eq(counter_move.current_uses, counter_move.max_uses, "no counter")


func test_burden_never_opens_the_battle_scene() -> void:
	_open_grid(2)
	var thumps := _scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0)
	var foe := _scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1)
	assert_false(CombatPresenter.scene_allowed(thumps, foe, MoveData.get_move("Burden")))


# =============================================================================
# Lift on the board
# =============================================================================

func test_lift_sets_the_friend_down_behind_him() -> void:
	_open_grid(4)
	var thumps := _board_unit("thumps", Enums.UnitFaction.PLAYER, 1)
	var friend := _board_unit("friend", Enums.UnitFaction.PLAYER, 2)
	var plan := DisplacementSystem.build_plan(thumps, friend, MoveData.get_move("Lift"))
	assert_eq(_final_cell(plan, friend), Vector2i(0, 0))
	assert_true(plan.mover_for(thumps).is_empty(), "he stays put")


func test_lift_with_his_back_to_the_edge_goes_nowhere() -> void:
	_open_grid(3)
	var thumps := _board_unit("thumps", Enums.UnitFaction.PLAYER, 0)
	var friend := _board_unit("friend", Enums.UnitFaction.PLAYER, 1)
	var plan := DisplacementSystem.build_plan(thumps, friend, MoveData.get_move("Lift"))
	assert_true(plan.mover_for(friend).is_empty())


func test_a_whole_lift_moves_the_friend() -> void:
	_open_grid(4)
	var thumps := _scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 1)
	var friend := _scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 2)
	await thumps.execute_combat_sequence(friend, MoveData.get_move("Lift"), RecordingPresenter.new())
	assert_eq(friend.current_tile, GridManager.get_tile(0, 0))
