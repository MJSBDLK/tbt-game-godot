## EditorScript: Assigns terrain peering bits to all tiles in an atlas source.
##
## HOW TO USE:
## 1. Open battle_tileset.tres in the TileSet editor
## 2. Make sure the Terrain Set (index 0) exists with mode "Match Corners and Sides"
## 3. Make sure at least one Terrain exists within it (e.g., "Plains" at index 0)
## 4. Run this script: Project > Tools > Run (or Ctrl+Shift+X)
##
## WHAT IT DOES:
## All 7 Webtyler tilesets (384x128, 12x4 grid of 32x32 tiles) use the same
## foreground/background edge pattern. This script assigns the correct terrain
## peering bits to every tile so that Godot's terrain painting auto-picks the
## right edge/corner/fill tile.
##
## The peering data comes from Webtyler's own bitmask reference image
## (github.com/wareya/webtyler/blob/main/etc/out%20bitmask.png).
@tool
extends EditorScript


# Peering bit data for the standard Webtyler 12x4 Godot-style tileset layout.
# Each entry: [col, row, bitmask_string] where bits are TL T TR L R BL B BR
# 1 = neighbor is same terrain (foreground), 0 = neighbor is different (background)
# Source: Webtyler bitmask reference (etc/out bitmask.png)
const TILE_PEERING_DATA: Array = [
	# Row 0
	[0, 0, "00000010"],
	[1, 0, "00001010"],
	[2, 0, "00011010"],
	[3, 0, "00010010"],
	[4, 0, "11011010"],
	[5, 0, "00011011"],
	[6, 0, "00011110"],
	[7, 0, "01111010"],
	[8, 0, "00001011"],
	[9, 0, "01011111"],
	[10, 0, "00011111"],
	[11, 0, "00010110"],
	# Row 1
	[0, 1, "01000010"],
	[1, 1, "01001010"],
	[2, 1, "01011010"],
	[3, 1, "01010010"],
	[4, 1, "01001011"],
	[5, 1, "01111111"],
	[6, 1, "11011111"],
	[7, 1, "01010110"],
	[8, 1, "01101011"],
	[9, 1, "01111110"],
	# (10, 1) is empty — skipped
	[11, 1, "11011110"],
	# Row 2
	[0, 2, "01000000"],
	[1, 2, "01001000"],
	[2, 2, "01011000"],
	[3, 2, "01010000"],
	[4, 2, "01101010"],
	[5, 2, "11111011"],
	[6, 2, "11111110"],
	[7, 2, "11010010"],
	[8, 2, "01111011"],
	[9, 2, "11111111"],
	[10, 2, "11011011"],
	[11, 2, "11010110"],
	# Row 3
	[0, 3, "00000000"],
	[1, 3, "00001000"],
	[2, 3, "00011000"],
	[3, 3, "00010000"],
	[4, 3, "01011110"],
	[5, 3, "01111000"],
	[6, 3, "11011000"],
	[7, 3, "01011011"],
	[8, 3, "01101000"],
	[9, 3, "11111000"],
	[10, 3, "11111010"],
	[11, 3, "11010000"],
]

# Mapping from bitmask position to Godot's CellNeighbor enum.
# Bitmask order: TL T TR L R BL B BR
const BIT_TO_NEIGHBOR: Array = [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,      # bit 0 = TL
	TileSet.CELL_NEIGHBOR_TOP_SIDE,              # bit 1 = T
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,      # bit 2 = TR
	TileSet.CELL_NEIGHBOR_LEFT_SIDE,             # bit 3 = L
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE,            # bit 4 = R
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,    # bit 5 = BL
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,           # bit 6 = B
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,   # bit 7 = BR
]


func _run() -> void:
	var tileset: TileSet = load("res://resources/battle_tileset.tres")
	if tileset == null:
		printerr("Could not load battle_tileset.tres")
		return

	var terrain_set := 0
	var terrain_id := 0

	# Create terrain set if it doesn't exist
	if tileset.get_terrain_sets_count() == 0:
		tileset.add_terrain_set()
		print("Created terrain set 0")
	tileset.set_terrain_set_mode(terrain_set, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)

	# Create terrain within the set if it doesn't exist
	if tileset.get_terrains_count(terrain_set) == 0:
		tileset.add_terrain(terrain_set)
		print("Created terrain 0 in terrain set 0")
	tileset.set_terrain_name(terrain_set, terrain_id, "Plains")
	tileset.set_terrain_color(terrain_set, terrain_id, Color(0.8, 0.5, 0.2))  # Orange

	# Apply peering bits to every atlas source in the tileset
	var source_count := tileset.get_source_count()
	for source_index in range(source_count):
		var source_id := tileset.get_source_id(source_index)
		var source := tileset.get_source(source_id) as TileSetAtlasSource
		if source == null:
			continue

		var atlas_size := source.get_atlas_grid_size()
		# Only process multi-tile atlases (skip single-tile placeholders)
		if atlas_size.x <= 1 and atlas_size.y <= 1:
			print("  Skipping source %d (single tile, likely placeholder)" % source_id)
			continue

		print("Processing source %d: %dx%d grid" % [source_id, atlas_size.x, atlas_size.y])
		_apply_peering_bits(source, terrain_set, terrain_id)

	# Save the resource
	ResourceSaver.save(tileset, "res://resources/battle_tileset.tres")
	print("Done! Terrain peering bits saved to battle_tileset.tres")
	print("Reload the TileSet editor to see changes.")


func _apply_peering_bits(source: TileSetAtlasSource, terrain_set: int, terrain_id: int) -> void:
	var tiles_set := 0

	for entry in TILE_PEERING_DATA:
		var col: int = entry[0]
		var row: int = entry[1]
		var bitmask: String = entry[2]
		var coords := Vector2i(col, row)

		# Check the tile exists in this atlas
		if not source.has_tile(coords):
			# Try to create it (some tiles may not be auto-created)
			print("  Tile %s not found, skipping" % str(coords))
			continue

		var tile_data: TileData = source.get_tile_data(coords, 0)
		if tile_data == null:
			continue

		# Set this tile as belonging to the terrain set and terrain
		tile_data.terrain_set = terrain_set
		tile_data.terrain = terrain_id

		# Set each peering bit
		for bit_index in range(8):
			var neighbor: TileSet.CellNeighbor = BIT_TO_NEIGHBOR[bit_index]
			if bitmask[bit_index] == "1":
				tile_data.set_terrain_peering_bit(neighbor, terrain_id)
			else:
				tile_data.set_terrain_peering_bit(neighbor, -1)

		tiles_set += 1

	print("  Set peering bits on %d tiles" % tiles_set)
