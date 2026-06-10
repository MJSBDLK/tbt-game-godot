## Tests for TerrainDataManager's unknown-terrain fallback: impassable +
## one dedup'd warning, instead of the old silently-walkable behavior.
extends GutTest


func test_unknown_terrain_is_impassable() -> void:
	assert_false(TerrainDataManager.can_unit_walk_on_terrain("BogusTypeForTest"),
			"Unknown terrain types must be impassable, not silently walkable")


func test_known_terrain_still_walkable() -> void:
	assert_true(TerrainDataManager.can_unit_walk_on_terrain("Plains"),
			"Plains stays walkable — the unknown-type fallback must not affect known types")


func test_known_impassable_terrain_unaffected() -> void:
	# StoneEdifice is walkable: {default: false} per terrain_data.json.
	assert_false(TerrainDataManager.can_unit_walk_on_terrain("StoneEdifice"),
			"StoneEdifice impassable by data, not by fallback")
	# But Air... no Air override on StoneEdifice — stays false for all.
	assert_false(TerrainDataManager.can_unit_walk_on_terrain("StoneEdifice", "Air"))


func test_volcano_air_passage() -> void:
	assert_false(TerrainDataManager.can_unit_walk_on_terrain("Volcano"),
			"Volcano impassable to grounded units")
	assert_true(TerrainDataManager.can_unit_walk_on_terrain("Volcano", "Air"),
			"Volcano passable to Air units")
