## Loner: +25% agility (rounded down, at least 1) while no ally is within 2
## tiles. A stat aura, dispatched from PassiveEffectsSystem.recompute.
extends GutTest


func _make_unit(grid_x: int, agility: int = 20, passives: Array = []) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	var data := CharacterData.new()
	data.base_agility = agility
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	unit.current_hp = 100
	var tile := Tile.new()
	autofree(tile)
	tile.grid_x = grid_x
	tile.grid_y = 0
	unit.current_tile = tile
	return unit


func test_alone_he_is_quicker() -> void:
	var traveller := _make_unit(0, 20, ["Loner"])
	LonerPassive.new().apply_stat_aura(traveller, [traveller])
	assert_eq(traveller.character_data.passive_bonus_agility, 5, "25% of 20")


func test_company_within_two_tiles_cancels_it() -> void:
	var traveller := _make_unit(0, 20, ["Loner"])
	LonerPassive.new().apply_stat_aura(traveller, [traveller, _make_unit(2)])
	assert_eq(traveller.character_data.passive_bonus_agility, 0)


func test_company_three_tiles_off_is_still_alone() -> void:
	var traveller := _make_unit(0, 20, ["Loner"])
	LonerPassive.new().apply_stat_aura(traveller, [traveller, _make_unit(3)])
	assert_eq(traveller.character_data.passive_bonus_agility, 5)


func test_it_rounds_down_like_a_status_buff() -> void:
	assert_eq(LonerPassive.bonus_for(_make_unit(0, 7).character_data), 1, "25% of 7 is 1.75")
	assert_eq(LonerPassive.bonus_for(_make_unit(0, 2).character_data), 1, "never less than 1")


func test_it_grows_with_the_stat() -> void:
	assert_eq(LonerPassive.bonus_for(_make_unit(0, 40).character_data), 10)


func test_recompute_dispatches_it_through_the_registry() -> void:
	var traveller := _make_unit(0, 20, ["Loner"])
	var units: Array[Unit] = [traveller]
	PassiveEffectsSystem.recompute_faction(units)
	assert_eq(traveller.character_data.passive_bonus_agility, 5)
