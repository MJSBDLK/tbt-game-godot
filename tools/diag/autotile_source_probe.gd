## Prints what Godot actually loads for the mountain autotile source: terrain
## set contents, and one tile's terrain, peering bits and custom data read both
## by name and by index. Use when the .tres text and the runtime disagree.
##
##   godot-4 --headless --path . --script tools/diag/autotile_source_probe.gd
@tool
extends SceneTree


const TILESET_PATH := "res://resources/battle_tileset.tres"
const SOURCE_ID := 8
const COORDS := Vector2i(0, 1)


func _init() -> void:
	var tileset: TileSet = load(TILESET_PATH)
	if tileset == null:
		push_error("cannot load tileset")
		quit(1)
		return
	print("terrain sets: ", tileset.get_terrain_sets_count())
	for set_index in range(tileset.get_terrain_sets_count()):
		var names: Array[String] = []
		for i in range(tileset.get_terrains_count(set_index)):
			names.append(tileset.get_terrain_name(set_index, i))
		print("  set %d mode=%d terrains=%s" % [
			set_index, tileset.get_terrain_set_mode(set_index), str(names)])
	print("custom data layers: ", tileset.get_custom_data_layers_count())
	for i in range(tileset.get_custom_data_layers_count()):
		print("  %d: %s (type %d)" % [i, tileset.get_custom_data_layer_name(i),
			tileset.get_custom_data_layer_type(i)])

	var source := tileset.get_source(SOURCE_ID) as TileSetAtlasSource
	print("source %d: name=%s tiles=%d texture=%s" % [
		SOURCE_ID, source.resource_name, source.get_tiles_count(),
		source.texture.resource_path if source.texture else "<null>"])
	var tile_data: TileData = source.get_tile_data(COORDS, 0)
	print("tile %s: terrain_set=%d terrain=%d" % [str(COORDS), tile_data.terrain_set, tile_data.terrain])
	print("  peering top=%d bottom=%d right=%d left=%d" % [
		tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE),
		tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE),
		tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE),
		tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE)])
	print("  is_modifier by name: ", tile_data.get_custom_data("is_modifier"))
	print("  by index 1: ", tile_data.get_custom_data_by_layer_id(1))
	quit(0)
