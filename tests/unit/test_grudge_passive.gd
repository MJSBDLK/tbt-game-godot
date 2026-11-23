## Grudge: when an ally within 3 tiles falls to a hit, an enemy-side unit takes
## CHALLENGED from the killer, so EnemyAI goes after them.
extends GutTest


var _saved_players: Array[Unit] = []
var _saved_enemies: Array[Unit] = []


func before_each() -> void:
	GridManager.clear_grid()
	_saved_players = TurnManager._player_units
	_saved_enemies = TurnManager._enemy_units


func after_each() -> void:
	TurnManager._player_units = _saved_players
	TurnManager._enemy_units = _saved_enemies


func after_all() -> void:
	GridManager.clear_grid()


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


func _ai_for(unit: Unit) -> EnemyAI:
	var ai := EnemyAI.new()
	autofree(ai)
	ai._unit = unit
	return ai


func test_a_fallen_ally_turns_the_ai_on_the_killer() -> void:
	var grunt := _unit("grunt", Enums.UnitFaction.ENEMY, 0, ["Grudge"])
	var fallen := _unit("fallen", Enums.UnitFaction.ENEMY, 3)
	var killer := _unit("killer", Enums.UnitFaction.PLAYER, 4)
	fallen.current_hp = 0
	GrudgePassive.new().on_ally_defeated(grunt, fallen, killer)
	assert_eq(_ai_for(grunt)._active_challenger(), killer)


func test_an_ally_falling_far_away_is_not_personal() -> void:
	var grunt := _unit("grunt", Enums.UnitFaction.ENEMY, 0, ["Grudge"])
	var fallen := _unit("fallen", Enums.UnitFaction.ENEMY, 4)
	var killer := _unit("killer", Enums.UnitFaction.PLAYER, 5)
	fallen.current_hp = 0
	GrudgePassive.new().on_ally_defeated(grunt, fallen, killer)
	assert_eq(StatusEffectSystem.get_effect_stacks(grunt, "CHALLENGED"), 0)


func test_a_player_unit_holds_no_grudge() -> void:
	var recruit := _unit("recruit", Enums.UnitFaction.PLAYER, 0, ["Grudge"])
	var fallen := _unit("fallen", Enums.UnitFaction.PLAYER, 1)
	var killer := _unit("killer", Enums.UnitFaction.ENEMY, 2)
	fallen.current_hp = 0
	GrudgePassive.new().on_ally_defeated(recruit, fallen, killer)
	assert_eq(StatusEffectSystem.get_effect_stacks(recruit, "CHALLENGED"), 0,
			"Grudge is enemy-side only")


func test_without_the_passive_nothing_happens() -> void:
	var grunt := _unit("grunt", Enums.UnitFaction.ENEMY, 0)
	var fallen := _unit("fallen", Enums.UnitFaction.ENEMY, 1)
	var killer := _unit("killer", Enums.UnitFaction.PLAYER, 2)
	fallen.current_hp = 0
	GrudgePassive.new().on_ally_defeated(grunt, fallen, killer)
	assert_eq(StatusEffectSystem.get_effect_stacks(grunt, "CHALLENGED"), 0)


func test_the_defeat_notice_reaches_the_fallens_side_only() -> void:
	var grunt := _unit("grunt", Enums.UnitFaction.ENEMY, 0, ["Grudge"])
	var fallen := _unit("fallen", Enums.UnitFaction.ENEMY, 1)
	var killer := _unit("killer", Enums.UnitFaction.PLAYER, 2, ["Grudge"])
	TurnManager._player_units = [killer] as Array[Unit]
	TurnManager._enemy_units = [grunt, fallen] as Array[Unit]
	fallen.current_hp = 0
	PassiveEffectsSystem.notify_defeated_by(fallen, killer)
	assert_eq(_ai_for(grunt)._active_challenger(), killer)
	assert_eq(StatusEffectSystem.get_effect_stacks(killer, "CHALLENGED"), 0)


func test_registry_resolves_grudge() -> void:
	assert_true(PassiveRegistry.get_handler("Grudge") is GrudgePassive)
