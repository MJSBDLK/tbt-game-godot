## Loads foot-track variant atlases + sidecars and resolves which variant (if
## any) applies to a tile's terrain. The resolution rule is a pure static
## function (resolve_variant) so it is unit-testable without textures.
##
## Rule: a tile's effective terrain name maps to a variant by —
##   1. an explicit override (data/foot_track_terrain.json), for terrains whose
##      name doesn't equal a variant (e.g. PolarIce/Tundra -> snow); then
##   2. case-insensitive name match (Regolith -> regolith).
## A miss returns "" — the tile gets no tracks (normal for water/rock and for a
## variant that maps to a terrain not yet shipped).
class_name FootTrackLibrary
extends RefCounted

const DEFAULT_TRACKS_DIR := "res://art/sprites/decorations/foot_tracks/"
const DEFAULT_OVERRIDES_PATH := "res://data/foot_track_terrain.json"

# variant (lowercase) -> { texture: Texture2D, cell_size: int, cells: { dir: Vector2i } }
var _variants: Dictionary = {}
# terrain (lowercase) -> variant (lowercase)
var _overrides: Dictionary = {}


func load_library(tracks_dir: String = DEFAULT_TRACKS_DIR, overrides_path: String = DEFAULT_OVERRIDES_PATH) -> void:
	_variants.clear()
	_overrides.clear()
	_load_overrides(overrides_path)
	_load_variants(tracks_dir)


func _load_overrides(overrides_path: String) -> void:
	if not FileAccess.file_exists(overrides_path):
		return
	var text := FileAccess.get_file_as_string(overrides_path)
	if text.is_empty():
		return
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary and (parsed as Dictionary).has("overrides"):
		var overrides: Dictionary = (parsed as Dictionary)["overrides"]
		for terrain in overrides:
			_overrides[str(terrain).to_lower()] = str(overrides[terrain]).to_lower()


func _load_variants(tracks_dir: String) -> void:
	var dir := DirAccess.open(tracks_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_load_variant(tracks_dir, file_name.get_basename().to_lower())
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_variant(tracks_dir: String, variant: String) -> void:
	var sidecar_path := tracks_dir + variant + ".json"
	var texture_path := tracks_dir + variant + ".png"
	var text := FileAccess.get_file_as_string(sidecar_path)
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if not (parsed is Dictionary):
		push_warning("FootTrackLibrary: bad or missing sidecar for variant '%s'" % variant)
		return
	var sidecar: Dictionary = parsed
	var cells: Dictionary = {}
	if sidecar.has("cells"):
		var raw_cells: Dictionary = sidecar["cells"]
		for dir_name in raw_cells:
			var coord: Array = raw_cells[dir_name]
			if coord.size() == 2:
				cells[str(dir_name)] = Vector2i(int(coord[0]), int(coord[1]))
	var texture: Texture2D = null
	if ResourceLoader.exists(texture_path):
		texture = ResourceLoader.load(texture_path) as Texture2D
	else:
		push_warning("FootTrackLibrary: variant '%s' has no texture at %s" % [variant, texture_path])
	_variants[variant] = {
		"texture": texture,
		"cell_size": int(sidecar.get("cell_size", 32)),
		"cells": cells,
	}


## Variant name for a terrain, or "" if none applies.
func variant_for_terrain(terrain_type_name: String) -> String:
	return resolve_variant(terrain_type_name, _variants.keys(), _overrides)


func has_variant(variant: String) -> bool:
	return _variants.has(variant.to_lower())


func variant_names() -> Array:
	return _variants.keys()


func get_texture(variant: String) -> Texture2D:
	var entry: Variant = _variants.get(variant.to_lower(), null)
	return entry["texture"] if entry != null else null


## Direction label at an atlas cell within a variant, or "" if none — the
## reverse of get_cell_region's coord. Used when ingesting designer-stamped
## seed tiles (the painted atlas coord tells us the direction).
func direction_for_cell(variant: String, coord: Vector2i) -> String:
	var entry: Variant = _variants.get(variant.to_lower(), null)
	if entry == null:
		return ""
	var cells: Dictionary = entry["cells"]
	for dir_name in cells:
		if cells[dir_name] == coord:
			return dir_name
	return ""


## Atlas pixel region for a direction within a variant, or a zero Rect2 when the
## variant or direction is absent.
func get_cell_region(variant: String, direction: String) -> Rect2:
	var entry: Variant = _variants.get(variant.to_lower(), null)
	if entry == null:
		return Rect2()
	var cells: Dictionary = entry["cells"]
	if not cells.has(direction):
		return Rect2()
	var size: int = entry["cell_size"]
	var coord: Vector2i = cells[direction]
	return Rect2(coord.x * size, coord.y * size, size, size)


## PURE resolution rule (testable without textures). `available` is the set of
## known variant names (any case); `overrides` maps terrain -> variant (any
## case). An override wins over name-match; a mapping to an unknown variant
## yields "".
static func resolve_variant(terrain_type_name: String, available: Array, overrides: Dictionary) -> String:
	var key := terrain_type_name.strip_edges().to_lower()
	if key.is_empty():
		return ""
	var available_lower := {}
	for variant_name in available:
		available_lower[str(variant_name).to_lower()] = true
	for terrain in overrides:
		if str(terrain).to_lower() == key:
			var mapped := str(overrides[terrain]).to_lower()
			return mapped if available_lower.has(mapped) else ""
	return key if available_lower.has(key) else ""
