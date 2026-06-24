## Phase 2: Jury Rig — heals orthogonally-adjacent robo-type allies 10% of their
## max HP at turn start. Robo = primary OR secondary type. Non-robo / non-adjacent
## allies are skipped; no overheal.
extends GutTest


func _unit(grid_x: int, grid_y: int, primary: Enums.ElementalType, current_hp: int = 50,
		secondary: Enums.ElementalType = Enums.ElementalType.NONE, passives: Array = []) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	var data := CharacterData.new()
	data.base_max_hp = 100
	data.primary_type = primary
	data.secondary_type = secondary
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	unit.current_hp = current_hp
	var tile := Tile.new()
	autofree(tile)
	tile.grid_x = grid_x
	tile.grid_y = grid_y
	unit.current_tile = tile
	return unit


func _heal_expected(ally: Unit) -> int:
	return maxi(1, int(floor(ally.character_data.max_hp * JuryRigPassive.HEAL_PCT_OF_MAX_HP)))


func test_heals_adjacent_robo_ally() -> void:
	var rigger := _unit(0, 0, Enums.ElementalType.SIMPLE, 50, Enums.ElementalType.NONE, ["Jury Rig"])
	var robo := _unit(1, 0, Enums.ElementalType.ROBO, 50)
	var allies: Array[Unit] = [rigger, robo]
	JuryRigPassive.new().on_turn_start(rigger, allies)
	assert_eq(robo.current_hp, 50 + _heal_expected(robo), "adjacent robo ally healed")


func test_secondary_robo_type_counts() -> void:
	var rigger := _unit(0, 0, Enums.ElementalType.SIMPLE, 50, Enums.ElementalType.NONE, ["Jury Rig"])
	var robo := _unit(1, 0, Enums.ElementalType.FIRE, 50, Enums.ElementalType.ROBO)
	var allies: Array[Unit] = [rigger, robo]
	JuryRigPassive.new().on_turn_start(rigger, allies)
	assert_eq(robo.current_hp, 50 + _heal_expected(robo), "secondary Robo type also qualifies")


func test_does_not_heal_non_robo_ally() -> void:
	var rigger := _unit(0, 0, Enums.ElementalType.SIMPLE, 50, Enums.ElementalType.NONE, ["Jury Rig"])
	var ally := _unit(1, 0, Enums.ElementalType.PLANT, 50)
	var allies: Array[Unit] = [rigger, ally]
	JuryRigPassive.new().on_turn_start(rigger, allies)
	assert_eq(ally.current_hp, 50, "non-robo ally untouched")


func test_does_not_heal_distant_robo_ally() -> void:
	var rigger := _unit(0, 0, Enums.ElementalType.SIMPLE, 50, Enums.ElementalType.NONE, ["Jury Rig"])
	var robo := _unit(3, 0, Enums.ElementalType.ROBO, 50)  # 3 tiles away
	var allies: Array[Unit] = [rigger, robo]
	JuryRigPassive.new().on_turn_start(rigger, allies)
	assert_eq(robo.current_hp, 50, "out-of-range robo ally untouched")


func test_diagonal_is_not_adjacent() -> void:
	var rigger := _unit(0, 0, Enums.ElementalType.SIMPLE, 50, Enums.ElementalType.NONE, ["Jury Rig"])
	var robo := _unit(1, 1, Enums.ElementalType.ROBO, 50)  # diagonal
	var allies: Array[Unit] = [rigger, robo]
	JuryRigPassive.new().on_turn_start(rigger, allies)
	assert_eq(robo.current_hp, 50, "diagonal is not orthogonally adjacent")


func test_no_overheal() -> void:
	var rigger := _unit(0, 0, Enums.ElementalType.SIMPLE, 50, Enums.ElementalType.NONE, ["Jury Rig"])
	var robo := _unit(1, 0, Enums.ElementalType.ROBO, 50)
	robo.current_hp = robo.character_data.max_hp  # full
	var allies: Array[Unit] = [rigger, robo]
	JuryRigPassive.new().on_turn_start(rigger, allies)
	assert_eq(robo.current_hp, robo.character_data.max_hp, "no overheal")


func test_registry_resolves_jury_rig() -> void:
	assert_true(PassiveRegistry.get_handler("Jury Rig") is JuryRigPassive)
