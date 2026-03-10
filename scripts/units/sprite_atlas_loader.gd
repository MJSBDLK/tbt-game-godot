## Loads Aseprite-exported JSON sprite atlases and creates AtlasTextures.
## Caches loaded atlases so each spritesheet is only parsed once.
##
## Usage:
##   var texture := SpriteAtlasLoader.get_frame_texture(
##       "res://art/sprites/characters/spaceman_sprites.png",
##       "res://art/sprites/characters/spaceman_sprites.json",
##       0)
class_name SpriteAtlasLoader
extends RefCounted


## Cached atlas data: { atlas_json_path: Array[Dictionary] }
## Each entry in the array: { "region": Rect2, "offset": Vector2 }
static var _atlas_cache: Dictionary = {}

## Cached spritesheet textures: { sheet_path: Texture2D }
static var _texture_cache: Dictionary = {}


## Get an AtlasTexture for a specific frame index from an Aseprite spritesheet.
## Returns null if the atlas or frame cannot be loaded.
static func get_frame_texture(sheet_path: String, atlas_path: String, frame_index: int) -> AtlasTexture:
	var frames := _get_or_load_atlas(atlas_path)
	if frames.is_empty():
		return null

	if frame_index < 0 or frame_index >= frames.size():
		push_warning("SpriteAtlasLoader: Frame %d out of range (0-%d) in '%s'" % [
			frame_index, frames.size() - 1, atlas_path])
		return null

	var sheet_texture := _get_or_load_texture(sheet_path)
	if sheet_texture == null:
		return null

	var frame_data: Dictionary = frames[frame_index]
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = sheet_texture
	atlas_texture.region = frame_data["region"]
	return atlas_texture


## Get the trim offset for a specific frame (for correct positioning).
## The offset represents how far the trimmed content is from the center
## of the original source frame.
static func get_frame_offset(atlas_path: String, frame_index: int) -> Vector2:
	var frames := _get_or_load_atlas(atlas_path)
	if frames.is_empty() or frame_index < 0 or frame_index >= frames.size():
		return Vector2.ZERO
	return frames[frame_index]["offset"]


## Parse and cache an Aseprite JSON atlas file.
static func _get_or_load_atlas(atlas_path: String) -> Array:
	if _atlas_cache.has(atlas_path):
		return _atlas_cache[atlas_path]

	var file_content := FileAccess.get_file_as_string(atlas_path)
	if file_content.is_empty():
		push_error("SpriteAtlasLoader: Failed to read atlas '%s'" % atlas_path)
		_atlas_cache[atlas_path] = []
		return []

	var json_result: Variant = JSON.parse_string(file_content)
	if json_result == null or not json_result is Dictionary:
		push_error("SpriteAtlasLoader: Failed to parse atlas '%s'" % atlas_path)
		_atlas_cache[atlas_path] = []
		return []

	var data: Dictionary = json_result
	var frames_dict: Dictionary = data.get("frames", {})

	# Aseprite exports frames as a dictionary keyed by name.
	# Sort by name to get consistent ordering (names end with " 0", " 1", etc.)
	var frame_names: Array = frames_dict.keys()
	frame_names.sort()

	var parsed_frames: Array = []
	for frame_name: Variant in frame_names:
		var frame_info: Dictionary = frames_dict[frame_name]
		var frame_rect: Dictionary = frame_info.get("frame", {})
		var source_size: Dictionary = frame_info.get("sourceSize", {})
		var sprite_source_size: Dictionary = frame_info.get("spriteSourceSize", {})

		# Region in the spritesheet
		var region := Rect2(
			float(frame_rect.get("x", 0)),
			float(frame_rect.get("y", 0)),
			float(frame_rect.get("w", 0)),
			float(frame_rect.get("h", 0))
		)

		# Calculate offset: how the trimmed content is displaced from the
		# center of the original source frame.
		var source_w := float(source_size.get("w", region.size.x))
		var source_h := float(source_size.get("h", region.size.y))
		var trim_x := float(sprite_source_size.get("x", 0))
		var trim_y := float(sprite_source_size.get("y", 0))
		var trim_w := float(sprite_source_size.get("w", region.size.x))
		var trim_h := float(sprite_source_size.get("h", region.size.y))

		# Offset = center of trimmed content relative to center of source canvas
		var offset := Vector2(
			(trim_x + trim_w / 2.0) - source_w / 2.0,
			(trim_y + trim_h / 2.0) - source_h / 2.0
		)

		parsed_frames.append({ "region": region, "offset": offset })

	_atlas_cache[atlas_path] = parsed_frames
	DebugConfig.log_unit_init("SpriteAtlasLoader: Loaded %d frames from '%s'" % [
		parsed_frames.size(), atlas_path])
	return parsed_frames


## Load and cache a spritesheet texture.
static func _get_or_load_texture(sheet_path: String) -> Texture2D:
	if _texture_cache.has(sheet_path):
		return _texture_cache[sheet_path]

	var texture: Texture2D = load(sheet_path) as Texture2D
	if texture == null:
		push_error("SpriteAtlasLoader: Failed to load texture '%s'" % sheet_path)
		return null

	_texture_cache[sheet_path] = texture
	return texture
