## Shaken: when an ally within 3 tiles falls to a hit, the owner is SHOCKED for
## a turn. Either side; same trigger as Grudge.
extends GutTest


func _unit(label: String, faction: Enums.UnitFaction, x: int, passives: Array = []) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.unit_name = label
	unit.faction = faction
	unit.current_hp = 20
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	var tile := Tile.new()
	autofree(tile)
	tile.grid_x = x
	tile.grid_y = 0
	unit.current_tile = tile
	return unit


func test_losing_a_companion_shakes_him() -> void:
	var traveller := _unit("traveller", Enums.UnitFaction.ENEMY, 0, ["Shaken"])
	var fallen := _unit("fallen", Enums.UnitFaction.ENEMY, 3)
	var killer := _unit("killer", Enums.UnitFaction.PLAYER, 4)
	fallen.current_hp = 0
	ShakenPassive.new().on_ally_defeated(traveller, fallen, killer)
	assert_eq(StatusEffectSystem.get_effect_stacks(traveller, "SHOCKED"), 1)


func test_a_loss_far_away_does_not_reach_him() -> void:
	var traveller := _unit("traveller", Enums.UnitFaction.ENEMY, 0, ["Shaken"])
	var fallen := _unit("fallen", Enums.UnitFaction.ENEMY, 4)
	fallen.current_hp = 0
	ShakenPassive.new().on_ally_defeated(traveller, fallen, null)
	assert_eq(StatusEffectSystem.get_effect_stacks(traveller, "SHOCKED"), 0)


func test_it_works_on_the_player_side_too() -> void:
	var recruit := _unit("recruit", Enums.UnitFaction.PLAYER, 0, ["Shaken"])
	var fallen := _unit("fallen", Enums.UnitFaction.PLAYER, 1)
	var killer := _unit("killer", Enums.UnitFaction.ENEMY, 2)
	fallen.current_hp = 0
	ShakenPassive.new().on_ally_defeated(recruit, fallen, killer)
	assert_eq(StatusEffectSystem.get_effect_stacks(recruit, "SHOCKED"), 1)


func test_without_the_passive_nothing_happens() -> void:
	var traveller := _unit("traveller", Enums.UnitFaction.ENEMY, 0)
	var fallen := _unit("fallen", Enums.UnitFaction.ENEMY, 1)
	fallen.current_hp = 0
	ShakenPassive.new().on_ally_defeated(traveller, fallen, null)
	assert_eq(StatusEffectSystem.get_effect_stacks(traveller, "SHOCKED"), 0)


func test_registry_resolves_shaken() -> void:
	assert_true(PassiveRegistry.get_handler("Shaken") is ShakenPassive)
