## The Grunt kit's new moves, read from the real move bank: Prod, Swarm (and
## the Bugle damage it sets up), Press, Brace and Haul.
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()


func after_all() -> void:
	GridManager.clear_grid()


func _fake(passives: Array = []) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	data.base_strength = 10
	data.base_defense = 2
	unit.character_data = data
	unit.current_hp = 20
	return unit


# =============================================================================
# Parsed shapes
# =============================================================================

func test_prod_reaches_two_tiles_for_little_power() -> void:
	var prod := MoveData.get_move("Prod")
	assert_eq([prod.attack_range, prod.base_power, prod.accuracy], [2, 3, 85])
	assert_eq(prod.damage_type, Enums.DamageType.PHYSICAL)


func test_swarm_marks_with_bugle() -> void:
	var swarm := MoveData.get_move("Swarm")
	assert_eq(swarm.element_type, Enums.ElementalType.HERALDIC)
	assert_eq(swarm.status_effect_type, Enums.StatusEffectType.BUGLE)
	assert_almost_eq(swarm.status_effect_chance, 0.5, 0.001)


func test_press_shoves_one_tile_with_a_save() -> void:
	var press := MoveData.get_move("Press")
	assert_eq([press.displace_distance, press.displace_vector], [1, "away_from_attacker"])
	assert_eq(press.displace_contest_stat, "constitution")


func test_brace_is_a_buff_for_someone_else() -> void:
	var brace := MoveData.get_move("Brace")
	assert_eq(brace.target_type, Enums.TargetType.ALLY_NOT_SELF)
	assert_eq(brace.status_effect_type, Enums.StatusEffectType.FORTIFIED)
	assert_false(brace.status_effect_self_target, "the ally gets it, not the caster")


func test_haul_pulls_an_ally_with_no_save() -> void:
	var haul := MoveData.get_move("Haul")
	assert_eq(haul.target_type, Enums.TargetType.ALLY_NOT_SELF)
	assert_eq([haul.displace_vector, haul.displace_on_blocked], ["toward_attacker", "push_chain"])
	assert_eq(haul.displace_contest_stat, "", "a willing ally doesn't resist")


# =============================================================================
# Bugle: +1 from Heraldic hits
# =============================================================================

func test_bugle_adds_damage_to_heraldic_hits() -> void:
	var attacker := _fake()
	var defender := _fake()
	var swarm := MoveData.get_move("Swarm")
	var before := DamageCalculator.calculate_damage(attacker, defender, swarm)
	StatusEffectSystem.apply_status_effect_by_name(null, defender, "BUGLE")
	assert_eq(DamageCalculator.calculate_damage(attacker, defender, swarm),
			before + DamageCalculator.BUGLE_BONUS_DAMAGE)


func test_bugle_leaves_other_elements_alone() -> void:
	var attacker := _fake()
	var defender := _fake()
	var prod := MoveData.get_move("Prod")
	var before := DamageCalculator.calculate_damage(attacker, defender, prod)
	StatusEffectSystem.apply_status_effect_by_name(null, defender, "BUGLE")
	assert_eq(DamageCalculator.calculate_damage(attacker, defender, prod), before)


# =============================================================================
# Brace lands on the ally
# =============================================================================

func test_brace_fortifies_the_ally_not_the_caster() -> void:
	var caster := _fake()
	var ally := _fake()
	StatusEffectSystem.apply_status_effect(caster, ally, MoveData.get_move("Brace"))
	assert_eq(StatusEffectSystem.get_effect_stacks(ally, "FORTIFIED"), 2)
	assert_eq(StatusEffectSystem.get_effect_stacks(caster, "FORTIFIED"), 0)


# =============================================================================
# Haul on the board
# =============================================================================

func _open_row(length: int) -> void:
	for x: int in range(length):
		var tile := Tile.new()
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		tile.add_child(sprite)
		add_child_autofree(tile)
		tile.grid_x = x
		tile.grid_y = 0
		tile.terrain_type_name = "Plains"
		GridManager.register_tile(tile)


func _board_unit(label: String, x: int) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.unit_name = label
	unit.current_hp = 20
	unit.character_data = CharacterData.new()
	var tile := GridManager.get_tile(x, 0)
	unit.current_tile = tile
	tile.current_unit = unit
	return unit


func _final_x(plan: DisplacementSystem.DisplacePlan, unit: Unit) -> int:
	var mover: Dictionary = plan.mover_for(unit)
	if mover.is_empty():
		return -999
	return ((mover.path as Array[Tile]).back() as Tile).grid_x


func test_haul_pulls_a_distant_ally_alongside() -> void:
	_open_row(4)
	var grunt := _board_unit("grunt", 0)
	var ally := _board_unit("ally", 2)
	var plan := DisplacementSystem.build_plan(grunt, ally, MoveData.get_move("Haul"))
	assert_eq(_final_x(plan, ally), 1)
	assert_true(plan.mover_for(grunt).is_empty(), "the grunt stays put")


func test_haul_drags_an_ally_alongside_back_a_step() -> void:
	_open_row(4)
	var grunt := _board_unit("grunt", 1)
	var ally := _board_unit("ally", 2)
	var plan := DisplacementSystem.build_plan(grunt, ally, MoveData.get_move("Haul"))
	assert_eq(_final_x(plan, grunt), 0, "the grunt backs up a step")
	assert_eq(_final_x(plan, ally), 1, "and the ally comes with him")


func test_haul_with_his_back_to_a_wall_moves_nobody() -> void:
	_open_row(4)
	var grunt := _board_unit("grunt", 0)
	var ally := _board_unit("ally", 1)
	var plan := DisplacementSystem.build_plan(grunt, ally, MoveData.get_move("Haul"))
	assert_true(plan.mover_for(grunt).is_empty() and plan.mover_for(ally).is_empty(),
			"the map edge jams the drag")
