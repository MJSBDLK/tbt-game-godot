## Registration tool for modifier AUTOTILE sheets — the Webtyler 12×12 sheets
## in art/sprites/tilesets/modifier_autotiles/ (see that folder's README for the
## block layout). Adds one atlas source per sheet, with the 47 body tiles, the
## terrain-set peering bits that make Godot's terrain brush work on the modifier
## layer, and is_modifier custom data.
##
## This is NOT tools/register_modifier_tiles.gd: that one mints single-tile
## sources for one-sprite PNGs at ids 100+. An autotile sheet is one source
## holding 47 tiles, and it lives BELOW 100 with the other autotile sheets so
## the sprite-source invariants (one tile per source, texture in an export dir)
## keep holding.
##
## SOURCE IDS ARE A CONTRACT with every painted map, so each sheet's id is
## written down in SHEETS, never assigned dynamically.
##
## The shadow and spill blocks are NOT tiles: nothing paints them. The runtime
## reads them as texture regions under the body tile — see
## TerrainSpriteRenderer._spawn_autotile_cell.
##
## Run from the project root:
##   godot-4 --headless --path . --script tools/register_autotile_modifier.gd
##
## Safe to re-run: an already-registered sheet is re-validated in place and a
## run that changes nothing leaves the file untouched.
@tool
extends SceneTree


const Registrar = preload("res://tools/register_modifier_tiles.gd")
const TerrainSetup = preload("res://scripts/editor/tileset_terrain_setup.gd")

const TILESET_PATH := "res://resources/battle_tileset.tres"
const TILE_SIZE := 32
const BODY_ROWS := 4
const BODY_COLS := 12
## The hole in the Webtyler 12×4 layout — 47 tiles, not 48.
const EMPTY_CELL := Vector2i(10, 1)

const SHEETS: Array = [
	{
		"source_id": 8,
		"texture": "res://art/sprites/tilesets/modifier_autotiles/mountain_12x12.png",
		"sprite_name": "mountain",
		"terrain_name": "Mountain",
		"terrain_color": Color(0.55, 0.5, 0.45),
	},
]


func _init() -> void:
	quit(_register_all())


## Terrain index of `name` in terrain set 0, appending it when it's new.
## Returns [index, changed].
static func terrain_index_for(tileset: TileSet, name: String, color: Color) -> Array:
	if tileset.get_terrain_sets_count() == 0:
		tileset.add_terrain_set()
		tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	for i in range(tileset.get_terrains_count(0)):
		if tileset.get_terrain_name(0, i) == name:
			return [i, false]
	var index: int = tileset.get_terrains_count(0)
	tileset.add_terrain(0)
	tileset.set_terrain_name(0, index, name)
	tileset.set_terrain_color(0, index, color)
	return [index, true]


func _register_all() -> int:
	var tileset: TileSet = load(TILESET_PATH)
	if tileset == null:
		push_error("register_autotile_modifier: cannot load %s" % TILESET_PATH)
		return 1

	var changed := false
	for sheet: Dictionary in SHEETS:
		var outcome: int = _register_sheet(tileset, sheet)
		if outcome < 0:
			return 1
		changed = changed or outcome > 0

	if not changed:
		print("register_autotile_modifier: %d sheet(s) already registered and current — tileset untouched" % SHEETS.size())
		return 0

	var save_err := ResourceSaver.save(tileset, TILESET_PATH)
	if save_err != OK:
		push_error("register_autotile_modifier: failed to save tileset (err %d)" % save_err)
		return 1
	_restore_uids(TILESET_PATH)
	print("register_autotile_modifier: saved %s" % TILESET_PATH)
	return 0


## Returns 1 when it changed the tileset, 0 when it was already current,
## -1 on a refusal.
func _register_sheet(tileset: TileSet, sheet: Dictionary) -> int:
	var source_id: int = int(sheet["source_id"])
	var texture_path: String = str(sheet["texture"])
	var sprite_name: String = str(sheet["sprite_name"])
	var texture: Texture2D = load(texture_path)
	if texture == null:
		push_error("register_autotile_modifier: cannot load %s" % texture_path)
		return -1

	var changed := false
	var source := tileset.get_source(source_id) as TileSetAtlasSource if tileset.has_source(source_id) else null
	if source == null:
		if tileset.has_source(source_id):
			push_error("register_autotile_modifier: source %d exists but isn't an atlas source — fix the tileset by hand" % source_id)
			return -1
		source = TileSetAtlasSource.new()
		source.texture = texture
		source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		source.resource_name = sprite_name
		tileset.add_source(source, source_id)
		changed = true
		print("  Added source %d: %s" % [source_id, sprite_name])
	else:
		# An id already in use by a different sheet would repaint every cell
		# that references it.
		if source.resource_name != "" and source.resource_name != sprite_name:
			push_error("register_autotile_modifier: source %d is '%s', not '%s' — pick a free id" % [
				source_id, source.resource_name, sprite_name])
			return -1
		if source.resource_name != sprite_name:
			source.resource_name = sprite_name
			changed = true
		if source.texture == null or source.texture.resource_path != texture_path:
			source.texture = texture
			changed = true
		if source.texture_region_size != Vector2i(TILE_SIZE, TILE_SIZE):
			source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
			changed = true

	var terrain: Array = terrain_index_for(tileset, str(sheet["terrain_name"]), sheet["terrain_color"])
	var terrain_index: int = int(terrain[0])
	changed = changed or bool(terrain[1])

	for row in range(BODY_ROWS):
		for col in range(BODY_COLS):
			var coords := Vector2i(col, row)
			if coords == EMPTY_CELL:
				continue
			if not source.has_tile(coords):
				source.create_tile(coords)
				changed = true
			if _apply_tile(source, coords, terrain_index):
				changed = true

	return 1 if changed else 0


## Peering bits (so the terrain brush picks this tile) plus the is_modifier
## flag. Terrain assignment itself lives in data/modifier_terrain.json, keyed by
## the source's resource_name. Returns true when anything changed.
func _apply_tile(source: TileSetAtlasSource, coords: Vector2i, terrain_index: int) -> bool:
	var tile_data: TileData = source.get_tile_data(coords, 0)
	if tile_data == null:
		return false
	var changed := false
	if tile_data.get_custom_data("is_modifier") != true:
		tile_data.set_custom_data("is_modifier", true)
		changed = true
	if tile_data.terrain_set != 0:
		tile_data.terrain_set = 0
		changed = true
	if tile_data.terrain != terrain_index:
		tile_data.terrain = terrain_index
		changed = true
	var bitmask: String = _bitmask_for(coords)
	if bitmask == "":
		return changed
	for bit_index in range(8):
		var neighbor: TileSet.CellNeighbor = TerrainSetup.BIT_TO_NEIGHBOR[bit_index]
		var want: int = terrain_index if bitmask[bit_index] == "1" else -1
		if tile_data.get_terrain_peering_bit(neighbor) != want:
			tile_data.set_terrain_peering_bit(neighbor, want)
			changed = true
	return changed


## The Webtyler layout's peering bitmask for an atlas cell, shared with the
## floor autotiles so both speak one table.
static func _bitmask_for(coords: Vector2i) -> String:
	for entry: Array in TerrainSetup.TILE_PEERING_DATA:
		if int(entry[0]) == coords.x and int(entry[1]) == coords.y:
			return str(entry[2])
	return ""


## Headless saves drop every uid="..." from the .tres; put them back so the
## diff shows only real changes (see register_modifier_tiles._restore_uids).
func _restore_uids(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return
	var restored := Registrar.restore_uids_in_text(text, path, func(p: String) -> String:
		var id: int = ResourceLoader.get_resource_uid(p)
		return ResourceUID.id_to_text(id) if id != ResourceUID.INVALID_ID else "")
	if restored == text:
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("register_autotile_modifier: saved, but couldn't reopen %s to restore uids" % path)
		return
	file.store_string(restored)
	file.close()
