## Close Ranks: +2 defense while an ally stands on one of the four neighboring
## tiles. A stat aura, dispatched from PassiveEffectsSystem.recompute.
extends GutTest


func _make_unit(grid_x: int, grid_y: int, passives: Array = []) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	unit.current_hp = 100
	var tile := Tile.new()
	autofree(tile)
	tile.grid_x = grid_x
	tile.grid_y = grid_y
	unit.current_tile = tile
	return unit


func test_an_ally_alongside_adds_defense() -> void:
	var unit := _make_unit(0, 0, ["Close Ranks"])
	var ally := _make_unit(0, 1)
	CloseRanksPassive.new().apply_stat_aura(unit, [unit, ally])
	assert_eq(unit.character_data.passive_bonus_defense, CloseRanksPassive.BONUS)


func test_a_diagonal_ally_is_not_alongside() -> void:
	var unit := _make_unit(0, 0, ["Close Ranks"])
	var ally := _make_unit(1, 1)
	CloseRanksPassive.new().apply_stat_aura(unit, [unit, ally])
	assert_eq(unit.character_data.passive_bonus_defense, 0, "Manhattan 2 is a gap in the line")


func test_more_allies_do_not_stack() -> void:
	var unit := _make_unit(0, 0, ["Close Ranks"])
	var units: Array[Unit] = [unit, _make_unit(1, 0), _make_unit(-1, 0), _make_unit(0, 1)]
	CloseRanksPassive.new().apply_stat_aura(unit, units)
	assert_eq(unit.character_data.passive_bonus_defense, CloseRanksPassive.BONUS)


func test_a_fallen_ally_holds_no_line() -> void:
	var unit := _make_unit(0, 0, ["Close Ranks"])
	var ally := _make_unit(1, 0)
	ally.current_hp = 0
	CloseRanksPassive.new().apply_stat_aura(unit, [unit, ally])
	assert_eq(unit.character_data.passive_bonus_defense, 0)


func test_recompute_dispatches_it_through_the_registry() -> void:
	var unit := _make_unit(0, 0, ["Close Ranks"])
	var units: Array[Unit] = [unit, _make_unit(1, 0)]
	PassiveEffectsSystem.recompute_faction(units)
	assert_eq(unit.character_data.passive_bonus_defense, CloseRanksPassive.BONUS)
