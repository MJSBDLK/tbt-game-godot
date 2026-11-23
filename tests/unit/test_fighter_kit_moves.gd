## The Fighter kit's new moves (Squash), read from the real move bank: Elbows,
## Arm Twist, Toss, Shake Down, Staredown and Cover. Cover's redirect and the
## Challenged binding have their own files (test_cover, test_challenged_binding).
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"


func before_each() -> void:
	GridManager.clear_grid()


func after_all() -> void:
	GridManager.clear_grid()


# =============================================================================
# HELPERS
# =============================================================================

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


func _board_unit(label: String, faction: Enums.UnitFaction, x: int, y: int = 0) -> Unit:
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


func _scene_unit(json_path: String, faction: Enums.UnitFaction, x: int, y: int = 0) -> Unit:
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	add_child_autofree(unit)
	unit.initialize(GridManager.get_tile(x, y))
	unit.character_data.equipped_passives = []
	return unit


func _hit_context(attacker: Node2D, defender: Node2D, move: Move, first_hit: bool = true) -> CombatHitContext:
	var ctx := CombatHitContext.new()
	ctx.attacker = attacker
	ctx.defender = defender
	ctx.move = move
	ctx.apply_status = first_hit
	return ctx


func _final_cell(plan: DisplacementSystem.DisplacePlan, unit: Unit) -> Vector2i:
	var mover: Dictionary = plan.mover_for(unit)
	if mover.is_empty():
		return Vector2i(-999, -999)
	var tile: Tile = (mover.path as Array[Tile]).back()
	return Vector2i(tile.grid_x, tile.grid_y)


func _sure_hit(move: Move) -> Move:
	move.accuracy = 500
	return move


# =============================================================================
# Parsed shapes
# =============================================================================

func test_elbows_hits_around_the_user() -> void:
	var elbows := MoveData.get_move("Elbows")
	assert_eq([elbows.target_type, elbows.area_of_effect, elbows.attack_range],
			[Enums.TargetType.SELF, 1, 0])
	assert_eq([elbows.damage_type, elbows.base_power], [Enums.DamageType.PHYSICAL, 3])
	assert_eq(elbows.aoe_affects, "enemies")


func test_arm_twist_roots_both() -> void:
	var arm_twist := MoveData.get_move("Arm Twist")
	assert_eq(arm_twist.status_effect_type, Enums.StatusEffectType.ROOTED)
	assert_almost_eq(arm_twist.status_effect_chance, 1.0, 0.001)
	assert_eq(arm_twist.self_rider, {"effect": "ROOTED", "stacks": 1})


func test_toss_throws_over_the_user() -> void:
	var toss := MoveData.get_move("Toss")
	assert_eq([toss.displace_distance, toss.displace_vector, toss.displace_on_blocked],
			[2, "toward_attacker", "fall_through"])
	assert_eq(toss.displace_contest_stat, "", "no save: a throw isn't a shove")


func test_shake_down_steals_the_buff_slot() -> void:
	var shake_down := MoveData.get_move("Shake Down")
	assert_eq(Array(shake_down.steal_slots), ["BUFF"])
	assert_eq(shake_down.base_power, 4)


func test_staredown_is_a_support_cast_at_a_foe() -> void:
	var staredown := MoveData.get_move("Staredown")
	assert_eq([staredown.damage_type, staredown.target_type, staredown.attack_range],
			[Enums.DamageType.SUPPORT, Enums.TargetType.SINGLE, 2])
	assert_eq(staredown.status_effect_type, Enums.StatusEffectType.CHALLENGED)
	assert_false(staredown.targets_allies())


func test_cover_guards_someone_else() -> void:
	var cover := MoveData.get_move("Cover")
	assert_eq([cover.target_type, cover.attack_range], [Enums.TargetType.ALLY_NOT_SELF, 1])
	assert_eq(cover.status_effect_type, Enums.StatusEffectType.COVERED)
	assert_true(cover.status_effect_replaces, "Cover takes the ally's buff slot")


# =============================================================================
# Arm Twist: the user's own rider
# =============================================================================

func test_arm_twist_roots_the_user_on_the_first_hit() -> void:
	var user := _board_unit_off_grid("user")
	var target := _board_unit_off_grid("target")
	var arm_twist := MoveData.get_move("Arm Twist")
	var effects := CombatEffectPipeline.gather(_hit_context(user, target, arm_twist))
	assert_true(effects.any(func(effect: CombatEffect) -> bool: return effect is SelfRiderEffect))
	await CombatEffectPipeline.run_on_hit(_hit_context(user, target, arm_twist), effects)
	assert_eq(StatusEffectSystem.get_effect_stacks(user, "ROOTED"), 1)
	assert_eq(StatusEffectSystem.get_effect_stacks(target, "ROOTED"), 1)


func test_arm_twist_bonus_hits_add_nothing_to_the_user() -> void:
	var user := _board_unit_off_grid("user")
	var target := _board_unit_off_grid("target")
	SelfRiderEffect.new().on_hit(_hit_context(user, target, MoveData.get_move("Arm Twist"), false))
	assert_eq(StatusEffectSystem.get_effect_stacks(user, "ROOTED"), 0)


func _board_unit_off_grid(label: String) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.unit_name = label
	unit.current_hp = 20
	unit.character_data = CharacterData.new()
	return unit


# =============================================================================
# Shake Down: the buff moves to the user
# =============================================================================

func test_shake_down_pockets_the_targets_buff() -> void:
	var user := _board_unit_off_grid("user")
	var target := _board_unit_off_grid("target")
	StatusEffectSystem.apply_status_effect_by_name(target, target, "FORTIFIED", 2)
	StealEffect.new().on_hit(_hit_context(user, target, MoveData.get_move("Shake Down")))
	assert_eq(StatusEffectSystem.get_effect_stacks(target, "FORTIFIED"), 0)
	assert_eq(StatusEffectSystem.get_effect_stacks(user, "FORTIFIED"), 2, "stacks and all")


func test_shake_down_replaces_the_users_own_buff() -> void:
	var user := _board_unit_off_grid("user")
	var target := _board_unit_off_grid("target")
	StatusEffectSystem.apply_status_effect_by_name(user, user, "HASTED", 1)
	StatusEffectSystem.apply_status_effect_by_name(target, target, "FORTIFIED", 2)
	StealEffect.new().on_hit(_hit_context(user, target, MoveData.get_move("Shake Down")))
	assert_eq(StatusEffectSystem.get_effect_stacks(user, "HASTED"), 0)
	assert_eq(StatusEffectSystem.get_effect_stacks(user, "FORTIFIED"), 2)


func test_shake_down_leaves_debuffs_where_they_are() -> void:
	var user := _board_unit_off_grid("user")
	var target := _board_unit_off_grid("target")
	StatusEffectSystem.apply_status_effect_by_name(user, target, "ROOTED", 1)
	StealEffect.new().on_hit(_hit_context(user, target, MoveData.get_move("Shake Down")))
	assert_eq(StatusEffectSystem.get_effect_stacks(target, "ROOTED"), 1)
	assert_eq(StatusEffectSystem.get_effect_stacks(user, "ROOTED"), 0)


# =============================================================================
# Toss on the board
# =============================================================================

func test_toss_lands_the_target_behind_the_user() -> void:
	_open_grid(4, 1)
	var squash := _board_unit("squash", Enums.UnitFaction.PLAYER, 1)
	var foe := _board_unit("foe", Enums.UnitFaction.ENEMY, 2)
	var plan := DisplacementSystem.build_plan(squash, foe, MoveData.get_move("Toss"))
	assert_eq(_final_cell(plan, foe), Vector2i(0, 0))
	assert_true(plan.mover_for(squash).is_empty(), "the user stays put")


func test_toss_with_a_friend_behind_the_user_goes_nowhere() -> void:
	_open_grid(4, 1)
	_board_unit("friend", Enums.UnitFaction.PLAYER, 0)
	var squash := _board_unit("squash", Enums.UnitFaction.PLAYER, 1)
	var foe := _board_unit("foe", Enums.UnitFaction.ENEMY, 2)
	var plan := DisplacementSystem.build_plan(squash, foe, MoveData.get_move("Toss"))
	assert_true(plan.mover_for(foe).is_empty(), "nowhere to land, so no throw")


# =============================================================================
# Elbows: who it reaches
# =============================================================================

func test_elbows_reaches_adjacent_foes_only() -> void:
	_open_grid(5, 3)
	var squash := _board_unit("squash", Enums.UnitFaction.PLAYER, 2, 1)
	var left := _board_unit("left", Enums.UnitFaction.ENEMY, 1, 1)
	var above := _board_unit("above", Enums.UnitFaction.ENEMY, 2, 2)
	_board_unit("far", Enums.UnitFaction.ENEMY, 4, 1)
	_board_unit("friend", Enums.UnitFaction.PLAYER, 3, 1)
	var victims := MoveTargeting.get_area_victims(squash, squash.current_tile, MoveData.get_move("Elbows"))
	assert_eq_deep(victims, [left, above] as Array[Unit])


func test_elbows_greys_out_with_nobody_close() -> void:
	_open_grid(5, 1)
	var squash := _board_unit("squash", Enums.UnitFaction.PLAYER, 0)
	_board_unit("far", Enums.UnitFaction.ENEMY, 2)
	var elbows := MoveData.get_move("Elbows")
	assert_false(elbows.has_meaningful_effect_on(squash))
	_board_unit("close", Enums.UnitFaction.ENEMY, 1)
	assert_true(elbows.has_meaningful_effect_on(squash))


# =============================================================================
# On the board, whole casts
# =============================================================================

func test_elbows_hits_every_neighbor_without_a_counter() -> void:
	_open_grid(3, 1)
	var squash := _scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 1)
	var left := _scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 0)
	var right := _scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 2)
	squash.character_data.base_strength += 20
	for foe: Unit in [left, right]:
		foe.character_data.base_max_hp += 80
		foe.current_hp = foe.character_data.max_hp
	var left_hp := left.current_hp
	var right_hp := right.current_hp
	var squash_hp := squash.current_hp
	var experience_before := squash.character_data.experience
	var elbows := _sure_hit(MoveData.get_move("Elbows"))
	var uses_before := elbows.current_uses
	var presenter := RecordingPresenter.new()

	await squash.execute_combat_sequence(squash, elbows, presenter)

	assert_lt(left.current_hp, left_hp, "the left neighbor took an elbow")
	assert_lt(right.current_hp, right_hp, "the right neighbor took an elbow")
	assert_eq(squash.current_hp, squash_hp, "nobody counters a self-cast")
	assert_eq(presenter.count("cast"), 1, "no swing at himself")
	assert_eq(elbows.current_uses, uses_before - 1, "one use for the whole cast")
	assert_gt(squash.character_data.experience, experience_before, "combat XP per victim")


func test_staredown_lands_without_a_fight() -> void:
	_open_grid(3, 1)
	var squash := _scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0)
	var foe := _scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1)
	var counter_move := MoveData.get_move("Club")
	foe.assigned_move = counter_move
	var squash_hp := squash.current_hp
	var foe_hp := foe.current_hp
	var presenter := RecordingPresenter.new()

	await squash.execute_combat_sequence(foe, MoveData.get_move("Staredown"), presenter)

	assert_eq(MoveTargeting.active_challenger(foe), squash)
	assert_eq(StatusEffectSystem.get_effect_stacks(foe, "CHALLENGED"), 3, "two turns bound")
	assert_eq([squash.current_hp, foe.current_hp], [squash_hp, foe_hp], "no damage either way")
	assert_eq(counter_move.current_uses, counter_move.max_uses, "no counter")


func test_staredown_never_opens_the_battle_scene() -> void:
	_open_grid(2, 1)
	var squash := _scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0)
	var foe := _scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1)
	assert_false(CombatPresenter.scene_allowed(squash, foe, MoveData.get_move("Staredown")))


func test_cover_marks_the_ally_with_the_user_as_bodyguard() -> void:
	_open_grid(3, 1)
	var squash := _scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0)
	var ally := _scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 1)
	await squash.execute_combat_sequence(ally, MoveData.get_move("Cover"), RecordingPresenter.new())
	assert_eq(StatusEffectSystem.get_effect_stacks(ally, "COVERED"), 1)
	assert_eq(MoveTargeting.covering_bodyguard(ally), squash)
