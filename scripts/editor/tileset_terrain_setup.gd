## EditorScript: Rebuilds battle_tileset.tres with all 7 Webtyler tilesets.
##
## HOW TO USE:
## 1. Open this script in the Script Editor
## 2. Run via File > Run (or Ctrl+Shift+X)
##
## WHAT IT DOES:
## - Removes all existing atlas sources from the tileset
## - Creates 7 atlas sources (one per Webtyler tileset image)
## - Creates a terrain set with 7 terrains (one per atlas, for painting)
## - Assigns correct peering bits to all 47 tiles in each atlas
## - Sets custom_data_0 (terrain_type) on every tile
##
## NOTE: This will invalidate any existing painted TileMapLayers that
## reference old source IDs. Maps will need repainting.
@tool
extends EditorScript


# ── Tileset configurations ──────────────────────────────────────────────────
# Each entry: [texture_path, terrain_name, terrain_type, terrain_color, is_modifier]
# - terrain_name: what appears in Godot's terrain painting dropdown
# - terrain_type: the gameplay type stored in custom_data_0 (matches terrain_data.json)
# - is_modifier: whether this is a Tier 2 modifier (custom_data_1)
# Autotile sources: Webtyler-generated 12x4 tilesets with terrain peering bits.
# Each entry: [texture_path, terrain_name, terrain_type, terrain_color, is_modifier]
const AUTOTILE_CONFIGS: Array = [
	["res://art/sprites/tilesets/blue_sand.png",            "Blue Sand / Regolith",        "Sand",  Color(0.4, 0.6, 0.9),  false],
	["res://art/sprites/tilesets/orange_sand.png",          "Orange Sand / Regolith",      "Sand",  Color(0.9, 0.6, 0.3),  false],
	["res://art/sprites/tilesets/black_sand.png",           "Black Sand / Regolith",       "Sand",  Color(0.3, 0.3, 0.3),  false],
	["res://art/sprites/tilesets/orange_purple_sand.png",   "Orange Sand / Purple Sand",   "Sand",  Color(0.7, 0.4, 0.7),  false],
	["res://art/sprites/tilesets/water.png",                "Water / Regolith",            "Water", Color(0.2, 0.4, 0.9),  false],
	["res://art/sprites/tilesets/mountain.png",             "Mountain / Regolith",         "Rock",  Color(0.5, 0.5, 0.5),  false],
	["res://art/sprites/tilesets/road.png",                 "Road / Regolith",             "Road",  Color(0.6, 0.5, 0.4),  false],
]

# Stamp tiles: single 32x32 tiles with no autotiling, placed manually.
# Combined into one atlas (stamp_tiles.png). Each entry is one column.
# Each entry: [col, terrain_type, is_modifier]
# To add more stamp tiles: add the 32x32 sprite to the next column in
# stamp_tiles.png and append an entry here.
const STAMP_TILE_ATLAS := "res://art/sprites/tilesets/stamp_tiles.png"
const STAMP_TILES: Array = [
	[0, "Regolith", false],
	# Future: [1, "Plant", true], [2, "Castle", true], etc.
]


# ── Peering bit data ────────────────────────────────────────────────────────
# Standard Webtyler 12x4 Godot-style tileset layout.
# Each entry: [col, row, bitmask_string] where bits are TL T TR L R BL B BR
# 1 = neighbor is same terrain (foreground), 0 = neighbor is different (background)
# Source: Webtyler bitmask reference (github.com/wareya/webtyler/blob/main/etc/out%20bitmask.png)
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

	# ── Step 1: Remove all existing atlas sources ───────────────────────
	var old_count := tileset.get_source_count()
	var old_ids: Array[int] = []
	for i in range(old_count):
		old_ids.append(tileset.get_source_id(i))
	for source_id in old_ids:
		tileset.remove_source(source_id)
	print("Removed %d old atlas sources" % old_ids.size())

	# ── Step 2: Remove existing terrain sets and recreate ───────────────
	# Clear all terrain sets
	while tileset.get_terrain_sets_count() > 0:
		tileset.remove_terrain_set(0)

	# Create terrain set 0 with Match Corners and Sides mode
	tileset.add_terrain_set()
	tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	print("Created terrain set 0 (Match Corners and Sides)")

	# Create one terrain per autotile config
	for i in range(AUTOTILE_CONFIGS.size()):
		var config: Array = AUTOTILE_CONFIGS[i]
		var terrain_name: String = config[1]
		var terrain_color: Color = config[3]
		tileset.add_terrain(0)
		tileset.set_terrain_name(0, i, terrain_name)
		tileset.set_terrain_color(0, i, terrain_color)
		print("  Created terrain %d: %s" % [i, terrain_name])

	# ── Step 3a: Create autotile atlas sources ──────────────────────────
	for i in range(AUTOTILE_CONFIGS.size()):
		var config: Array = AUTOTILE_CONFIGS[i]
		var texture_path: String = config[0]
		var terrain_name: String = config[1]
		var terrain_type: String = config[2]
		var is_modifier: bool = config[4]

		var texture: Texture2D = load(texture_path)
		if texture == null:
			printerr("Could not load texture: %s" % texture_path)
			continue

		var source := TileSetAtlasSource.new()
		source.texture = texture
		source.texture_region_size = Vector2i(32, 32)
		tileset.add_source(source, i)

		# Create all 47 tiles in the 12x4 Webtyler grid
		for row in range(4):
			for col in range(12):
				if col == 10 and row == 1:
					continue  # Empty cell in Webtyler layout
				source.create_tile(Vector2i(col, row))

		_apply_peering_bits(source, i)
		_apply_custom_data_grid(source, terrain_type, is_modifier, 12, 4)
		print("Added autotile source %d: %s → %s (%d tiles)" % [i, terrain_name, terrain_type, source.get_tiles_count()])

	# ── Step 3b: Create stamp tile atlas source ─────────────────────────
	var stamp_texture: Texture2D = load(STAMP_TILE_ATLAS)
	if stamp_texture == null:
		printerr("Could not load stamp tile atlas: %s" % STAMP_TILE_ATLAS)
	else:
		var stamp_source := TileSetAtlasSource.new()
		stamp_source.texture = stamp_texture
		stamp_source.texture_region_size = Vector2i(32, 32)
		# Use source ID after the autotile sources
		var stamp_source_id := AUTOTILE_CONFIGS.size()
		tileset.add_source(stamp_source, stamp_source_id)

		for entry in STAMP_TILES:
			var col: int = entry[0]
			var terrain_type: String = entry[1]
			var is_modifier: bool = entry[2]
			stamp_source.create_tile(Vector2i(col, 0))
			var tile_data: TileData = stamp_source.get_tile_data(Vector2i(col, 0), 0)
			tile_data.set_custom_data("terrain_type", terrain_type)
			if is_modifier:
				tile_data.set_custom_data("is_modifier", true)

		print("Added stamp tile source %d: %d tiles (no autotiling)" % [stamp_source_id, STAMP_TILES.size()])

	# ── Step 4: Save ────────────────────────────────────────────────────
	ResourceSaver.save(tileset, "res://resources/battle_tileset.tres")
	print("")
	print("Done! Rebuilt battle_tileset.tres:")
	print("  %d autotile sources (terrain painting)" % AUTOTILE_CONFIGS.size())
	print("  1 stamp tile source (manual placement)")
	print("Reload the TileSet editor to see changes.")
	print("NOTE: Existing painted maps will need repainting.")


func _apply_peering_bits(source: TileSetAtlasSource, terrain_index: int) -> void:
	for entry in TILE_PEERING_DATA:
		var col: int = entry[0]
		var row: int = entry[1]
		var bitmask: String = entry[2]
		var coords := Vector2i(col, row)

		if not source.has_tile(coords):
			continue

		var tile_data: TileData = source.get_tile_data(coords, 0)
		if tile_data == null:
			continue

		tile_data.terrain_set = 0
		tile_data.terrain = terrain_index

		for bit_index in range(8):
			var neighbor: TileSet.CellNeighbor = BIT_TO_NEIGHBOR[bit_index]
			if bitmask[bit_index] == "1":
				tile_data.set_terrain_peering_bit(neighbor, terrain_index)
			else:
				tile_data.set_terrain_peering_bit(neighbor, -1)


func _apply_custom_data_grid(source: TileSetAtlasSource, terrain_type: String, is_modifier: bool, cols: int, rows: int) -> void:
	for row in range(rows):
		for col in range(cols):
			if col == 10 and row == 1:
				continue
			var coords := Vector2i(col, row)
			if not source.has_tile(coords):
				continue
			var tile_data: TileData = source.get_tile_data(coords, 0)
			if tile_data == null:
				continue
			tile_data.set_custom_data("terrain_type", terrain_type)
			if is_modifier:
				tile_data.set_custom_data("is_modifier", true)
