## Pathfinder: terrain costing more than 1 costs 1 less, never below 1. Read in
## GridManager._scaled_tile_cost, so ranges, routes and path costs all agree.
## Costs here are in GridManager's scaled space (x MOVEMENT_SCALE).
extends GutTest


func _tile(terrain: String) -> Tile:
	var tile := Tile.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	add_child_autofree(tile)
	tile.terrain_type_name = terrain
	return tile


func _walker(passives: Array = []) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	unit.current_hp = 20
	return unit


func _cost(terrain: String, walker: TestFakeUnit) -> int:
	return GridManager._scaled_tile_cost(_tile(terrain), "", walker)


func test_sand_costs_him_one_less() -> void:
	assert_eq(_cost("Sand", _walker()), 2 * GridManager.MOVEMENT_SCALE, "precondition: sand costs 2")
	assert_eq(_cost("Sand", _walker(["Pathfinder"])), 1 * GridManager.MOVEMENT_SCALE)


func test_open_ground_is_unchanged() -> void:
	assert_eq(_cost("Plains", _walker(["Pathfinder"])), 1 * GridManager.MOVEMENT_SCALE)


func test_roads_stay_cheap() -> void:
	assert_eq(_cost("Road", _walker(["Pathfinder"])), _cost("Road", _walker()),
			"relief applies to rough ground only; it never makes a road dearer")


func test_registry_resolves_pathfinder() -> void:
	assert_true(PassiveRegistry.get_handler("Pathfinder") is PathfinderPassive)
