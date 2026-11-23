## Gloat: a crit or a kill by the owner leaves every foe within 2 tiles
## CHALLENGED by it for a turn. Once per hit, even when a crit also kills.
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()


func after_all() -> void:
	GridManager.clear_grid()


func _open_grid(width: int = 6, height: int = 3) -> void:
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


func _unit(label: String, faction: Enums.UnitFaction, cell: Vector2i, passives: Array = []) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.unit_name = label
	unit.faction = faction
	unit.current_hp = 20
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	var tile := GridManager.get_tile(cell.x, cell.y)
	unit.current_tile = tile
	tile.current_unit = unit
	return unit


func _ctx(attacker: Unit, defender: Unit, crit: bool) -> CombatHitContext:
	var ctx := CombatHitContext.new()
	ctx.attacker = attacker
	ctx.defender = defender
	ctx.move = Move.new()
	ctx.is_crit = crit
	return ctx


func _challenged(unit: Unit) -> int:
	return StatusEffectSystem.get_effect_stacks(unit, "CHALLENGED")


func test_a_crit_challenges_every_foe_close_by() -> void:
	_open_grid()
	var squash := _unit("squash", Enums.UnitFaction.PLAYER, Vector2i(2, 1), ["Gloat"])
	var struck := _unit("struck", Enums.UnitFaction.ENEMY, Vector2i(2, 2))
	var watcher := _unit("watcher", Enums.UnitFaction.ENEMY, Vector2i(0, 1))
	var far := _unit("far", Enums.UnitFaction.ENEMY, Vector2i(5, 1))
	var friend := _unit("friend", Enums.UnitFaction.PLAYER, Vector2i(3, 1))
	GloatPassive.new().on_hit(_ctx(squash, struck, true))
	assert_eq([_challenged(struck), _challenged(watcher)], [2, 2], "one turn bound")
	assert_eq([_challenged(far), _challenged(friend)], [0, 0])
	assert_eq(MoveTargeting.active_challenger(watcher), squash)


func test_a_kill_without_a_crit_gloats_too() -> void:
	_open_grid()
	var squash := _unit("squash", Enums.UnitFaction.PLAYER, Vector2i(2, 1), ["Gloat"])
	var fallen := _unit("fallen", Enums.UnitFaction.ENEMY, Vector2i(2, 2))
	var watcher := _unit("watcher", Enums.UnitFaction.ENEMY, Vector2i(0, 1))
	fallen.current_hp = 0
	fallen.is_defeated_flag = true
	GloatPassive.new().on_kill(_ctx(squash, fallen, false))
	assert_eq(_challenged(watcher), 2)
	assert_eq(_challenged(fallen), 0, "nothing for the fallen")


func test_a_killing_crit_gloats_once() -> void:
	_open_grid()
	var squash := _unit("squash", Enums.UnitFaction.PLAYER, Vector2i(2, 1), ["Gloat"])
	var fallen := _unit("fallen", Enums.UnitFaction.ENEMY, Vector2i(2, 2))
	var watcher := _unit("watcher", Enums.UnitFaction.ENEMY, Vector2i(0, 1))
	fallen.current_hp = 0
	fallen.is_defeated_flag = true
	var gloat := GloatPassive.new()
	var ctx := _ctx(squash, fallen, true)
	gloat.on_hit(ctx)
	gloat.on_kill(ctx)
	assert_eq(_challenged(watcher), 2, "not restacked by the kill")


func test_a_plain_hit_is_nothing_to_gloat_about() -> void:
	_open_grid()
	var squash := _unit("squash", Enums.UnitFaction.PLAYER, Vector2i(2, 1), ["Gloat"])
	var struck := _unit("struck", Enums.UnitFaction.ENEMY, Vector2i(2, 2))
	GloatPassive.new().on_hit(_ctx(squash, struck, false))
	assert_eq(_challenged(struck), 0)


func test_being_crit_is_nothing_to_gloat_about() -> void:
	_open_grid()
	var squash := _unit("squash", Enums.UnitFaction.PLAYER, Vector2i(2, 1), ["Gloat"])
	var critter := _unit("critter", Enums.UnitFaction.ENEMY, Vector2i(2, 2))
	GloatPassive.new().on_hit(_ctx(critter, squash, true))
	assert_eq(_challenged(critter), 0)


func test_registry_resolves_gloat() -> void:
	assert_true(PassiveRegistry.get_handler("Gloat") is GloatPassive)
