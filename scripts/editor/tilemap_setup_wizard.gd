## @tool EditorScript to create a new map scene with the correct node hierarchy.
## Run from Editor → Script → Run in Godot.
##
## Creates:
## 1. A new map scene in res://scenes/battle/maps/<map_name>.tscn
## 2. A stub JSON file in res://data/maps/<map_name>.json
##
## After running, open the scene, paint tiles on the TileMapLayers, and edit the JSON.
@tool
extends EditorScript


func _run() -> void:
	var map_name := "new_map"  # Change this before running

	var scene_dir := "res://scenes/battle/maps/"
	var data_dir := "res://data/maps/"
	var scene_path := scene_dir + map_name + ".tscn"
	var json_path := data_dir + map_name + ".json"

	# Verify directories exist
	if not DirAccess.dir_exists_absolute(scene_dir):
		DirAccess.make_dir_recursive_absolute(scene_dir)
	if not DirAccess.dir_exists_absolute(data_dir):
		DirAccess.make_dir_recursive_absolute(data_dir)

	# Check for existing files
	if FileAccess.file_exists(scene_path):
		printerr("TilemapSetupWizard: Scene already exists at '%s'" % scene_path)
		return
	if FileAccess.file_exists(json_path):
		printerr("TilemapSetupWizard: JSON already exists at '%s'" % json_path)
		return

	# Build the scene tree
	var root := Node2D.new()
	root.name = map_name.to_pascal_case()

	var battle_scene_script := load("res://scripts/managers/battle_scene.gd")
	if battle_scene_script != null:
		root.set_script(battle_scene_script)
		root.set("map_data_path", json_path)

	# TilemapBuilder
	var tilemap_builder := Node2D.new()
	tilemap_builder.name = "TilemapBuilder"
	var builder_script := load("res://scripts/grid/tilemap_grid_builder.gd")
	if builder_script != null:
		tilemap_builder.set_script(builder_script)
	root.add_child(tilemap_builder)
	tilemap_builder.owner = root

	# TileSet
	var tileset := load("res://resources/battle_tileset.tres") as TileSet

	# TerrainTileLayer
	var terrain_layer := TileMapLayer.new()
	terrain_layer.name = "TerrainTileLayer"
	if tileset != null:
		terrain_layer.tile_set = tileset
	tilemap_builder.add_child(terrain_layer)
	terrain_layer.owner = root

	# ModifierTileLayer
	var modifier_layer := TileMapLayer.new()
	modifier_layer.name = "ModifierTileLayer"
	if tileset != null:
		modifier_layer.tile_set = tileset
	tilemap_builder.add_child(modifier_layer)
	modifier_layer.owner = root

	# DecorationTileLayer
	var decoration_layer := TileMapLayer.new()
	decoration_layer.name = "DecorationTileLayer"
	if tileset != null:
		decoration_layer.tile_set = tileset
	tilemap_builder.add_child(decoration_layer)
	decoration_layer.owner = root

	# SpawnTileLayer
	var spawn_layer := TileMapLayer.new()
	spawn_layer.name = "SpawnTileLayer"
	if tileset != null:
		spawn_layer.tile_set = tileset
	tilemap_builder.add_child(spawn_layer)
	spawn_layer.owner = root

	# Camera2D
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	var camera_script := load("res://scripts/managers/camera_controller.gd")
	if camera_script != null:
		camera.set_script(camera_script)
	root.add_child(camera)
	camera.owner = root

	# Save scene
	var packed_scene := PackedScene.new()
	packed_scene.pack(root)
	var save_result := ResourceSaver.save(packed_scene, scene_path)
	if save_result != OK:
		printerr("TilemapSetupWizard: Failed to save scene (error %d)" % save_result)
		root.queue_free()
		return

	root.queue_free()

	# Create stub JSON
	var json_content := {
		"map_name": map_name.replace("_", " ").capitalize(),
		"map_id": map_name,
		"description": "New map — edit this description",
		"scene_path": scene_path,
		"grid_width": 10,
		"grid_height": 10,
		"recommended_level": 5,
		"player_spawns": [
			{
				"grid_x": 1,
				"grid_y": 2,
				"character_json_path": "res://data/characters/spaceman.json",
				"faction": "player"
			}
		],
		"enemy_spawns": [
			{
				"grid_x": 8,
				"grid_y": 2,
				"character_json_path": "res://data/characters/grunt.json",
				"faction": "enemy",
				"ai_behavior": "aggressive"
			}
		]
	}

	var json_string := JSON.stringify(json_content, "\t")
	var json_file := FileAccess.open(json_path, FileAccess.WRITE)
	if json_file != null:
		json_file.store_string(json_string)
		json_file.close()
	else:
		printerr("TilemapSetupWizard: Failed to write JSON at '%s'" % json_path)
		return

	print("=== TilemapSetupWizard: Map created! ===")
	print("Scene: %s" % scene_path)
	print("JSON:  %s" % json_path)
	print("")
	print("Next steps:")
	print("  1. Open the scene in the editor")
	print("  2. Paint terrain on TerrainTileLayer (Tier 1 floor)")
	print("  3. Paint modifiers on ModifierTileLayer (Tier 2, replaces floor)")
	print("  4. Paint decorations on DecorationTileLayer (Tier 3, visual-only)")
	print("  5. Paint spawn points on SpawnTileLayer (blue P = player, red E = enemy)")
	print("  6. Run the scene to test")
