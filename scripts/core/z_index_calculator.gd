## Universal z-indexing system for grid-based rendering.
## Adapted from Unity's sorting order system to fit Godot's z_index range (-4096..4096).
##
## Formula: z_index = (99 - row_index) * 10 + layer
## Front rows (index 0) get highest z_index, back rows (index 99) get lowest.
## Set z_as_relative = false on the root battle node so children use absolute z_index.
class_name ZIndexCalculator


## Layer offsets for same-row sorting.
## Updated for THREE-TIER SPRITE SYSTEM architecture.
enum ZIndexLayer {
	## TIER 1: Floor Tiles (base terrain)
	FLOOR_TILES = 0,
	## Terrain effects on floor (fire, rain, status effects on ground)
	TERRAIN_EFFECTS = 1,
	## TIER 2: Terrain Modifiers (gameplay-affecting: trees, rocks, walls)
	TERRAIN_MODIFIERS = 2,
	## TIER 3: Pure Decorations (visual-only: flowers, grass tufts)
	PURE_DECORATIONS = 3,
	## Movement arrows, range indicators
	PATH_INDICATORS = 4,
	## Characters, enemies
	UNITS = 5,
	## Status icons above units
	UNIT_EFFECTS = 6,
	## Health bars, floating text
	UI = 7,
}


## Calculate z_index using the adapted formula.
## Row 0 (front) = highest z_index, Row 99 (back) = lowest.
## [param row_index] Grid row index (0-99, where 0 = front row)
## [param grid_height] Total height of the grid (for validation)
## [param layer] Type of object being sorted
## [param fine] Fine adjustment (0-9) for granular control
static func calculate_sorting_order(row_index: int, _grid_height: int, layer: ZIndexLayer, fine: int = 0) -> int:
	# Validate and clamp row index to 0-99 range
	if row_index < 0:
		row_index = 0
	elif row_index >= 100:
		row_index = 99

	# Validate and clamp fine adjustment to 0-9 range
	fine = clampi(fine, 0, 9)

	# Adapted formula for Godot's z_index range (-4096..4096)
	# (99 - row) * 10 gives 0-990, layer adds 0-7, fine adds via separate channel
	# Total range: 0 to 997 — well within Godot's limits
	var z: int = (99 - row_index) * 10 + int(layer)

	return z


## Calculate z_index from world position (for dynamic objects like units).
static func calculate_sorting_order_from_position(world_position: Vector2, layer: ZIndexLayer, fine: int = 0) -> int:
	var row_index: int = roundi(world_position.y)
	return calculate_sorting_order(row_index, 100, layer, fine)


## Decode an existing z_index back to its components for debugging.
static func decode_z_index(z: int) -> String:
	if z < 0:
		return "Underground layer (z_index: %d)" % z

	var layer_value: int = z % 10
	@warning_ignore("integer_division")
	var row_component: int = (z - layer_value) / 10
	var row_index: int = 99 - row_component

	var layer_name: String = "Unknown"
	# Check if it's a valid ZIndexLayer value
	match layer_value:
		0: layer_name = "FloorTiles"
		1: layer_name = "TerrainEffects"
		2: layer_name = "TerrainModifiers"
		3: layer_name = "PureDecorations"
		4: layer_name = "PathIndicators"
		5: layer_name = "Units"
		6: layer_name = "UnitEffects"
		7: layer_name = "UI"

	return "Row %d, Layer %s -> %d" % [row_index, layer_name, z]


## Debug method to test occlusion scenarios.
static func debug_occlusion_scenario(scenario_name: String, grid_height: int = 100) -> void:
	print("=== %s (Godot Z-Index System) ===" % scenario_name)

	# Test front vs back row occlusion
	var front_row_unit := calculate_sorting_order(0, grid_height, ZIndexLayer.UNITS)
	var back_row_unit := calculate_sorting_order(99, grid_height, ZIndexLayer.UNITS)

	print("Front row unit (Row 0): %d" % front_row_unit)
	print("Back row unit (Row 99): %d" % back_row_unit)
	print("Front unit occludes back unit: %s" % str(front_row_unit > back_row_unit))

	# Test same-row layer sorting
	var same_floor := calculate_sorting_order(5, grid_height, ZIndexLayer.FLOOR_TILES)
	var same_decoration := calculate_sorting_order(5, grid_height, ZIndexLayer.PURE_DECORATIONS)
	var same_unit := calculate_sorting_order(5, grid_height, ZIndexLayer.UNITS)

	print("Row 5 - Floor: %d, Decoration: %d, Unit: %d" % [same_floor, same_decoration, same_unit])
	print("Layer sorting (Unit > Decoration > Floor): %s" % str(same_unit > same_decoration and same_decoration > same_floor))

	# Test decoding
	print("Decode %d: %s" % [same_unit, decode_z_index(same_unit)])
