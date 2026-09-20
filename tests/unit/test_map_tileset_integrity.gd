## Every painted modifier/decoration cell in every map must reference a
## tile that exists in battle_tileset.tres — the source id AND the atlas
## coords. This is the regression net under the tile registration tool: if
## registration ever renumbers or moves a source, a map's cells go dangling
## (or worse, point at a different sprite) and this is where it shows.
##
## Also pins the registration invariants the runtime relies on: every sprite
## source's resource_name matches its PNG basename (the renderer and the
## terrain map resolve by that name), and its texture lives in one of the
## export directories the registration tool scans.
extends GutTest


const Registrar = preload("res://tools/register_modifier_tiles.gd")

const MAPS_DIR := "res://scenes/battle/maps/"
const TILESET_PATH := "res://resources/battle_tileset.tres"
const SPRITE_SOURCE_ID_BASE := 100
const SPRITE_LAYERS := ["ModifierTileLayer", "DecorationTileLayer"]


func _map_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(MAPS_DIR)
	assert_not_null(dir, "maps dir opens")
	if dir == null:
		return paths
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".tscn"):
			paths.append(MAPS_DIR + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths


func test_every_painted_sprite_cell_resolves_to_a_registered_tile() -> void:
	var tileset: TileSet = load(TILESET_PATH)
	assert_not_null(tileset, "tileset loads")
	var maps := _map_paths()
	assert_gt(maps.size(), 0, "at least one map to check")
	var checked_cells: int = 0
	for map_path in maps:
		var packed: PackedScene = load(map_path)
		assert_not_null(packed, "%s loads" % map_path)
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		var builder: Node = root.find_child("TilemapBuilder", true, false)
		assert_not_null(builder, "%s has a TilemapBuilder" % map_path)
		if builder != null:
			for layer_name: String in SPRITE_LAYERS:
				var layer := builder.get_node_or_null(layer_name) as TileMapLayer
				if layer == null:
					continue
				for cell: Vector2i in layer.get_used_cells():
					checked_cells += 1
					var source_id: int = layer.get_cell_source_id(cell)
					var coords: Vector2i = layer.get_cell_atlas_coords(cell)
					var where := "%s %s cell %s" % [map_path.get_file(), layer_name, str(cell)]
					assert_true(tileset.has_source(source_id),
							"%s: source id %d exists in the tileset" % [where, source_id])
					if not tileset.has_source(source_id):
						continue
					var source := tileset.get_source(source_id) as TileSetAtlasSource
					assert_not_null(source, "%s: source %d is an atlas source" % [where, source_id])
					if source == null:
						continue
					assert_true(source.has_tile(coords),
							"%s: source %d ('%s') has a tile at atlas %s" % [
								where, source_id, source.resource_name, str(coords)])
		root.free()
	# Sanity: the suite is actually looking at something.
	assert_gt(checked_cells, 0, "some sprite cells were checked")


func test_sprite_sources_are_named_after_their_png() -> void:
	var tileset: TileSet = load(TILESET_PATH)
	assert_not_null(tileset, "tileset loads")
	var export_dirs := Registrar.export_dirs()
	var sprite_sources: int = 0
	for i in range(tileset.get_source_count()):
		var source_id: int = tileset.get_source_id(i)
		if source_id < SPRITE_SOURCE_ID_BASE:
			continue
		var source := tileset.get_source(source_id) as TileSetAtlasSource
		assert_not_null(source, "source %d is an atlas source" % source_id)
		if source == null or source.texture == null:
			continue
		sprite_sources += 1
		var texture_path: String = source.texture.resource_path
		assert_true(export_dirs.has(texture_path.get_base_dir() + "/"),
				"source %d texture lives in an export dir (%s)" % [source_id, texture_path])
		assert_eq(source.resource_name, texture_path.get_file().get_basename(),
				"source %d resource_name matches its PNG basename" % source_id)
		assert_eq(source.get_tiles_count(), 1,
				"source %d ('%s') holds exactly one tile (the footprint)" % [source_id, source.resource_name])
	assert_gt(sprite_sources, 0, "sprite sources are registered")


func test_every_exported_sprite_is_registered() -> void:
	# A PNG on disk with no tileset source is a sprite Lawrence can't paint —
	# the registration tool hasn't been run since the export.
	var tileset: TileSet = load(TILESET_PATH)
	assert_not_null(tileset, "tileset loads")
	var registered: Dictionary = {}
	for i in range(tileset.get_source_count()):
		var source_id: int = tileset.get_source_id(i)
		if source_id < SPRITE_SOURCE_ID_BASE:
			continue
		var source := tileset.get_source(source_id) as TileSetAtlasSource
		if source != null:
			registered[source.resource_name] = source.texture.resource_path if source.texture != null else ""
	var found: Dictionary = Registrar.find_sprite_paths()
	assert_eq(found["duplicates"], [], "no sprite name is exported into two folders")
	var sprite_paths: Dictionary = found["paths"]
	assert_gt(sprite_paths.size(), 0, "exported sprites found on disk")
	for name: Variant in sprite_paths:
		assert_true(registered.has(name),
				"'%s' is exported but not registered — run tools/register_modifier_tiles.gd" % name)
		if registered.has(name):
			assert_eq(registered[name], sprite_paths[name],
					"'%s' is registered against the PNG it was exported to" % name)
