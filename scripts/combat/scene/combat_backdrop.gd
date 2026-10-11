## CombatBackdrop — the combat stage's painted backdrop, from the folder
## tools/aseprite/export_combat_backdrop.lua writes: the sky, its twinkling
## stars (StarSky), then the floor layers in the painter's order
## (floor/NN_<layer>.png, bottom first). Every file is one canvas, anchored
## where CombatScene.backdrop_position says. A layer with "smoke" in its name
## drifts (SmokePlume).
##
## The fight's surroundings pick the floor layers. A layer named after
## scenery (Tile.scenery: a map piece family like "crater" or "shelltree", or
## a floor material like "orange_sand" or "water") shows only when that
## scenery stands within SCENERY_REACH steps of a fighter. A "_left" or
## "_right" ending answers to the fighter on that side of the stage only. Any
## other name ("ground_regolith", "hill_back_left") always shows.
class_name CombatBackdrop
extends Control


const DIRECTORY: String = "res://art/backdrops/combat_regolith/"
const SKY_FILE: String = "sky.png"
const TWINKLE_FILE: String = "sky_twinkle.png"
const FLOOR_FOLDER: String = "floor/"
const SCENERY_REACH: int = 2  # steps without diagonals, the range rule
const MAP_TILESET: String = "res://resources/battle_tileset.tres"  # what floors can be

static var _scenery_names: Dictionary = {}
var _floor_layers: Array[TextureRect] = []


func _init() -> void:
	name = "Backdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paths: Array[String] = [DIRECTORY + SKY_FILE, DIRECTORY + TWINKLE_FILE]
	for file_name: String in floor_files(DIRECTORY + FLOOR_FOLDER):
		paths.append(DIRECTORY + FLOOR_FOLDER + file_name)
	var canvas_size := Vector2.ZERO
	for path: String in paths:
		if not ResourceLoader.exists(path):
			continue
		var art := _layer_node(path)
		art.name = path.get_file().get_basename()
		art.texture = load(path) as Texture2D
		# One canvas, one anchor: a layer of another size is a bad export.
		assert(canvas_size == Vector2.ZERO or art.texture.get_size() == canvas_size,
				"%s isn't the backdrop's canvas size" % path)
		canvas_size = art.texture.get_size()
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)
		if path.contains("/" + FLOOR_FOLDER):
			_floor_layers.append(art)


## The node a layer draws through: the star map twinkles, smoke drifts, the
## rest is a plain picture.
static func _layer_node(path: String) -> TextureRect:
	if path.ends_with(TWINKLE_FILE):
		var stars := StarSky.new()
		stars.draws_resting_stars = false  # the painted sky shows them at rest
		return stars
	if is_smoke(layer_name(path.get_file())):
		return SmokePlume.new()
	return TextureRect.new()


## A layer with the word "smoke" in its name drifts ("volcano_smoke").
static func is_smoke(layer: String) -> bool:
	return layer.split("_").has("smoke")


## The floor layers' files, bottom first: the export numbers them.
static func floor_files(folder: String) -> Array[String]:
	var files: Array[String] = []
	if not DirAccess.dir_exists_absolute(folder):
		return files
	for entry: String in ResourceLoader.list_directory(folder):
		if entry.ends_with(".png"):
			files.append(entry)
	files.sort()
	return files


## A layer's own name: the export's order number and extension dropped
## ("07_crater_left.png" → "crater_left").
static func layer_name(file_name: String) -> String:
	var base := file_name.get_basename()
	var parts := base.split("_", true, 1)
	return parts[1] if parts.size() == 2 and parts[0].is_valid_int() else base


## Whether a floor layer shows. `left` / `right`: the scenery near the
## fighter on each side (scenery_near). `vocabulary`: every scenery name
## (scenery_names). The layer answers to the longest of those its name
## starts with, whole words only ("orange_sand_left" → "orange_sand", not
## "orange"); a name that starts with none always shows.
static func shows(layer: String, left: Dictionary, right: Dictionary, vocabulary: Dictionary) -> bool:
	var subject := ""
	for scenery_name: String in vocabulary:
		if (layer == scenery_name or layer.begins_with(scenery_name + "_")) \
				and scenery_name.length() > subject.length():
			subject = scenery_name
	if subject == "":
		return true
	if layer.ends_with("_left"):
		return left.has(subject)
	if layer.ends_with("_right"):
		return right.has(subject)
	return left.has(subject) or right.has(subject)


## Every name Tile.scenery can carry: the piece families, and what the map
## tileset's floor can paint. Not every terrain in terrain_data.json: no map
## paints "Ground", and ground_regolith must not wait for one.
static func scenery_names() -> Dictionary:
	if _scenery_names.is_empty():
		for family: String in ModifierTerrainMap.families():
			_scenery_names[family] = true
		var tile_set := load(MAP_TILESET) as TileSet
		assert(tile_set != null, "CombatBackdrop: no map tileset at %s" % MAP_TILESET)
		for floor_name: String in TilemapGridBuilder.floor_scenery_names(tile_set):
			_scenery_names[floor_name] = true
	return _scenery_names


## The scenery within SCENERY_REACH steps of `tile`, as a set of names.
static func scenery_near(tile: Tile) -> Dictionary:
	var near: Dictionary = {}
	if tile == null:
		return near
	for dx: int in range(-SCENERY_REACH, SCENERY_REACH + 1):
		var span: int = SCENERY_REACH - absi(dx)
		for dy: int in range(-span, span + 1):
			var other: Tile = GridManager.get_tile(tile.grid_x + dx, tile.grid_y + dy)
			if other != null:
				for scenery_name: String in other.scenery:
					near[scenery_name] = true
	return near


## Show the floor layers the fighters' surroundings call for.
func choose_layers(left_unit: Node2D, right_unit: Node2D) -> void:
	var vocabulary := scenery_names()
	var left := scenery_near(left_unit.get("current_tile") as Tile)
	var right := scenery_near(right_unit.get("current_tile") as Tile)
	for art: TextureRect in _floor_layers:
		art.visible = shows(layer_name(art.name), left, right, vocabulary)


func floor_layers() -> Array[TextureRect]:
	return _floor_layers


## Every layer on the canvas anchor, at the puppets' scale.
func lay_out(top_left: Vector2, scale_factor: int) -> void:
	for child: Node in get_children():
		var art := child as TextureRect
		art.position = top_left
		art.size = art.texture.get_size() * scale_factor
