## Phase 2 slice 5: Ghost migrated to a passes_through_units passive handler,
## dispatched from GridManager._tile_blocks_passage.
extends GutTest


func _unit(faction: Enums.UnitFaction, passives: Array = []) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	unit.faction = faction
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	return unit


func _tile_with(occupant: TestFakeUnit) -> Tile:
	var tile := Tile.new()
	autofree(tile)
	tile.current_unit = occupant
	return tile


# =============================================================================
# Handler + registry
# =============================================================================

func test_ghost_passes_through_units() -> void:
	assert_true(GhostPassive.new().passes_through_units())


func test_base_does_not_pass_through_units() -> void:
	assert_false(CombatEffect.new().passes_through_units(), "default: blocked by units")


func test_registry_resolves_ghost() -> void:
	assert_true(PassiveRegistry.get_handler("Ghost") is GhostPassive)


# =============================================================================
# GridManager._tile_blocks_passage dispatch
# =============================================================================

func test_enemy_tile_blocks_without_ghost() -> void:
	var tile := _tile_with(_unit(Enums.UnitFaction.ENEMY))
	var mover := _unit(Enums.UnitFaction.PLAYER)
	assert_true(GridManager._tile_blocks_passage(tile, mover), "enemy blocks a non-Ghost mover")


func test_enemy_tile_passable_with_ghost() -> void:
	var tile := _tile_with(_unit(Enums.UnitFaction.ENEMY))
	var mover := _unit(Enums.UnitFaction.PLAYER, ["Ghost"])
	assert_false(GridManager._tile_blocks_passage(tile, mover), "Ghost moves through enemies")


func test_ally_tile_always_passable() -> void:
	var tile := _tile_with(_unit(Enums.UnitFaction.PLAYER))
	var mover := _unit(Enums.UnitFaction.PLAYER)
	assert_false(GridManager._tile_blocks_passage(tile, mover), "allies never block")


func test_empty_tile_passable() -> void:
	var tile := Tile.new()
	autofree(tile)
	assert_false(GridManager._tile_blocks_passage(tile, _unit(Enums.UnitFaction.PLAYER)))
