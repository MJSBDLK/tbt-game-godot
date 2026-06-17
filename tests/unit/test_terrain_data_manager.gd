## Tests for TerrainDataManager's unknown-terrain fallback: impassable +
## one dedup'd warning, instead of the old silently-walkable behavior.
extends GutTest


func test_unknown_terrain_is_impassable() -> void:
	assert_false(TerrainDataManager.can_unit_walk_on_terrain("BogusTypeForTest"),
			"Unknown terrain types must be impassable, not silently walkable")


func test_known_terrain_still_walkable() -> void:
	assert_true(TerrainDataManager.can_unit_walk_on_terrain("Plains"),
			"Plains stays walkable — the unknown-type fallback must not affect known types")


func test_stone_edifice_is_walkable_structure() -> void:
	# StoneEdifice is a walkable structure (castle-gate design: units stand on
	# structure cells, gated per-cell). No per-type overrides, so it's walkable
	# for every type including Air; the data-driven IMPASSABLE path is covered
	# by test_volcano_air_passage / test_wall_impassable_except_fliers.
	assert_true(TerrainDataManager.can_unit_walk_on_terrain("StoneEdifice"),
			"StoneEdifice is walkable (castle-gate structure)")
	assert_true(TerrainDataManager.can_unit_walk_on_terrain("StoneEdifice", "Air"),
			"No per-type override — walkable for all types, Air included")


func test_volcano_air_passage() -> void:
	assert_false(TerrainDataManager.can_unit_walk_on_terrain("Volcano"),
			"Volcano impassable to grounded units")
	assert_true(TerrainDataManager.can_unit_walk_on_terrain("Volcano", "Air"),
			"Volcano passable to Air units")


# =============================================================================
# Unit-type override case normalization
# =============================================================================
# The game queries with raw ElementalType enum keys ("COLD", "AIR") while
# terrain_data.json is authored Title Case ("Cold", "Air"). Regression: the
# match used to be case-sensitive, silently killing every per-type override.

func test_water_walkable_for_cold_and_air_via_uppercase_query() -> void:
	# Exactly what the game passes: Enums.elemental_type_to_string → "COLD".
	assert_false(TerrainDataManager.can_unit_walk_on_terrain("Water"),
			"Water impassable to default types")
	assert_true(TerrainDataManager.can_unit_walk_on_terrain("Water", "COLD"),
			"Water walkable for COLD (uppercase enum-key query)")
	assert_true(TerrainDataManager.can_unit_walk_on_terrain("Water", "AIR"),
			"Water walkable for AIR (uppercase enum-key query)")


func test_override_query_is_case_insensitive() -> void:
	assert_true(TerrainDataManager.can_unit_walk_on_terrain("Water", "Cold"),
			"Title Case query matches")
	assert_true(TerrainDataManager.can_unit_walk_on_terrain("Water", "cold"),
			"lowercase query matches")


# =============================================================================
# New terrain entries from the modifier JSON pass
# =============================================================================

func test_volcanic_plant_boosts_fire_and_plant() -> void:
	assert_true(TerrainDataManager.can_unit_walk_on_terrain("VolcanicPlant"))
	assert_almost_eq(TerrainDataManager.get_attack_multiplier("VolcanicPlant", "FIRE"), 1.2, 0.001)
	assert_almost_eq(TerrainDataManager.get_attack_multiplier("VolcanicPlant", "PLANT"), 1.2, 0.001)
	assert_almost_eq(TerrainDataManager.get_movement_cost("VolcanicPlant", "FIRE"), 1.0, 0.001,
			"Fire units move through volcanic flora freely")
	assert_almost_eq(TerrainDataManager.get_movement_cost("VolcanicPlant"), 2.0, 0.001,
			"Other types pay double")


func test_stone_edifice_medium_defense_bonus() -> void:
	assert_almost_eq(TerrainDataManager.get_defense_multiplier("StoneEdifice"), 1.2, 0.001,
			"StoneEdifice grants a medium defensive bonus to the default type")


func test_wall_impassable_except_fliers() -> void:
	assert_false(TerrainDataManager.can_unit_walk_on_terrain("Wall"),
			"Wall blocks grounded units")
	assert_false(TerrainDataManager.can_unit_walk_on_terrain("Wall", "SIMPLE"),
			"Wall blocks a normal grounded type")
	assert_true(TerrainDataManager.can_unit_walk_on_terrain("Wall", "AIR"),
			"Wall is passable to Air-types (fliers)")
