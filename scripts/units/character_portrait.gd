## Resolves a character's UI portrait. If `portrait_path` is set on the
## character, returns that texture directly. Otherwise derives a placeholder
## by cropping the top 32×32 of the character's idle sprite — handy while
## real portrait art doesn't exist yet.
##
## "Top 32×32" actually means "32×32 starting at the first non-transparent
## row," so canvases with whitespace above the head still produce a head-shot
## instead of an empty square. Atlas-trimmed Aseprite frames have no
## whitespace, so the scan no-ops for those (the trim already removed it).
##
## Results are cached by character_id so re-querying from multiple panels
## doesn't re-scan the spritesheet.
class_name CharacterPortrait
extends RefCounted


const _TARGET_SIZE: int = 32

# Last-resort portrait when neither portrait_path nor the sprite-crop heuristic
# produce something. The sprite crop is preferred because it at least carries
# the character's silhouette/colors; this is the fallback when there's no
# sprite either (extremely rare — usually means broken character data).
const _DEFAULT_PORTRAIT_PATH: String = "res://art/portraits/default_portrait.png"

# Glass-surface effect material applied as an HD-layer overlay above each
# portrait — gives the line art a "projection on glass" look without
# tinting the line art itself. Handles tint, gradient, top highlight,
# scanlines, every-Nth scanline accent, JPEG-style static, and dark-dot
# flicker all in one pass.
const _PORTRAIT_OVERLAY_MATERIAL: ShaderMaterial = preload("res://resources/glass_panel.tres")

# VHS-tracking-error material applied to the HD mirror itself. Cannot live
# on the overlay because tracking distortion requires re-sampling the line
# art at displaced UVs (the overlay can only modulate color/alpha on top
# of the line art). Defaults to off (tracking_strength = 0); tune up in
# inspector when you want the effect visible.
const _PORTRAIT_TRACKING_MATERIAL: ShaderMaterial = preload("res://resources/hd_portrait_tracking.tres")

# Two caches because the two paths can produce different textures for the same
# character — keep them separate so squad cards never accidentally serve up a
# full painted portrait, and the detail panel never serves up a sprite crop
# when a real portrait was available.
# character_id -> Texture2D
static var _cache_portrait_or_sprite: Dictionary = {}
static var _cache_sprite_only: Dictionary = {}


## Binds a portrait to an existing TextureRect, preferring HD line art when
## available. Drop-in replacement for `texture_rect.texture = get_for(...)`
## that adds opt-in HD rendering via HDPortraitSlot.
##
## Resolution order for the HD texture:
##   1. `character.lineart_atlases[region_name]` — an AtlasTexture .tres
##      that crops the source line art to a specific framing (e.g. headshot).
##   2. `character.lineart_path` — the full line-art image, used when no
##      region-specific atlas is defined.
##   3. Pixel portrait fallback (`get_for`) when neither is set.
##
## When an HD texture is found, an HDPortraitSlot child is added under
## `texture_rect` (or reused if already there) and the pixel `.texture` is
## cleared so the HD overlay renders alone. The slot inherits the TextureRect's
## rect via full-rect anchors, so the HD mirror in HDLayer ends up exactly
## where the pixel portrait would have been.
##
## `region_name` defaults to "portrait" because that's what most consumers
## want; pass a different name (e.g. "thumbnail") if the slot wants a
## different crop.
static func bind_to_texture_rect(texture_rect: TextureRect, character: CharacterData, region_name: String = "portrait") -> void:
	if texture_rect == null:
		return
	if character == null:
		texture_rect.texture = null
		_remove_hd_slot(texture_rect)
		return

	var hd_texture: Texture2D = _resolve_hd_texture(character, region_name)

	if hd_texture != null:
		var slot: HDPortraitSlot = _ensure_hd_slot(texture_rect)
		slot.hd_texture = hd_texture
		# Glass overlay above the HD line art — handles tint, gradient,
		# scanlines, static, dark-dot flicker, all in one pass.
		slot.overlay_material = _PORTRAIT_OVERLAY_MATERIAL
		# VHS-tracking distortion on the mirror itself — required because
		# distortion needs to re-sample the line art at displaced UVs.
		slot.projection_material = _PORTRAIT_TRACKING_MATERIAL
		# Clearing the pixel texture means transparent edges of the line art
		# don't reveal the painted portrait underneath. The slot covers the
		# TextureRect's rect via PRESET_FULL_RECT, so visually nothing is lost.
		texture_rect.texture = null
	else:
		_remove_hd_slot(texture_rect)
		texture_rect.texture = get_for(character)


## Whether bind_to_texture_rect would find HD line art for this character.
## Callers that want a DIFFERENT fallback than the pixel portrait (the
## workbench's static-noise NO DATA screen) branch on this first.
static func has_hd_art(character: CharacterData, region_name: String = "portrait") -> bool:
	return character != null and _resolve_hd_texture(character, region_name) != null


static func _resolve_hd_texture(character: CharacterData, region_name: String) -> Texture2D:
	# Prefer the region-specific atlas — it pre-crops the source PNG to the
	# framing we want (head-shot vs full body, etc.).
	if region_name != "" and character.lineart_atlases.has(region_name):
		var atlas_path: String = str(character.lineart_atlases[region_name])
		if not atlas_path.is_empty() and ResourceLoader.exists(atlas_path):
			return load(atlas_path) as Texture2D
	# Fall back to the full line-art image (whole picture).
	if not character.lineart_path.is_empty() and ResourceLoader.exists(character.lineart_path):
		return load(character.lineart_path) as Texture2D
	return null


static func _ensure_hd_slot(parent: Control) -> HDPortraitSlot:
	const SLOT_NAME: String = "_HDPortraitSlot"
	var existing: HDPortraitSlot = parent.get_node_or_null(SLOT_NAME) as HDPortraitSlot
	if existing != null:
		return existing
	var slot := HDPortraitSlot.new()
	slot.name = SLOT_NAME
	slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The slot's _ready() sets mouse_filter = PASS so it can receive
	# left-clicks for the debug effects-toggle (DebugConfig.cheats_enabled).
	# Don't override that here.
	parent.add_child(slot)
	return slot


static func _remove_hd_slot(parent: Control) -> void:
	const SLOT_NAME: String = "_HDPortraitSlot"
	var existing: HDPortraitSlot = parent.get_node_or_null(SLOT_NAME) as HDPortraitSlot
	if existing != null:
		existing.queue_free()


## Default lookup: prefers the character's painted portrait, falls back to a
## crop of the idle sprite if no portrait is set. Used by the unit preview
## and detail panels — wherever a "real" portrait is the goal.
static func get_for(character: CharacterData) -> Texture2D:
	if character == null:
		return null

	var cache_key: String = character.character_id
	if cache_key != "" and _cache_portrait_or_sprite.has(cache_key):
		return _cache_portrait_or_sprite[cache_key]

	var texture: Texture2D = _resolve(character)
	if cache_key != "" and texture != null:
		_cache_portrait_or_sprite[cache_key] = texture
	return texture


## Sprite-only lookup: always returns a crop of the idle sprite, ignoring
## portrait_path. Used by squad prep cards where the sprite-top crop reads
## better at small sizes than a downscaled painted portrait.
static func get_sprite_crop_for(character: CharacterData) -> Texture2D:
	if character == null:
		return null

	var cache_key: String = character.character_id
	if cache_key != "" and _cache_sprite_only.has(cache_key):
		return _cache_sprite_only[cache_key]

	var texture: Texture2D = _derive_from_sprite(character)
	if cache_key != "" and texture != null:
		_cache_sprite_only[cache_key] = texture
	return texture


static func _resolve(character: CharacterData) -> Texture2D:
	if not character.portrait_path.is_empty() and ResourceLoader.exists(character.portrait_path):
		return load(character.portrait_path) as Texture2D
	var sprite_crop: Texture2D = _derive_from_sprite(character)
	if sprite_crop != null:
		return sprite_crop
	if ResourceLoader.exists(_DEFAULT_PORTRAIT_PATH):
		return load(_DEFAULT_PORTRAIT_PATH) as Texture2D
	return null


static func _derive_from_sprite(character: CharacterData) -> Texture2D:
	if character.sprite_sheet_path.is_empty():
		return null

	var sheet_texture: Texture2D = load(character.sprite_sheet_path) as Texture2D
	if sheet_texture == null:
		return null
	var image: Image = sheet_texture.get_image()
	if image == null:
		return null

	var frame_rect: Rect2i = _resolve_frame_rect(character, image)
	if frame_rect.size.x <= 0 or frame_rect.size.y <= 0:
		return null

	# Skip transparent rows above the actual sprite content. Aseprite-trimmed
	# atlas frames already start at the first opaque row, so this is a no-op
	# in that case; for raw idle PNGs it's the whole point of the scan.
	var first_opaque_y: int = _find_first_opaque_row(image, frame_rect)
	if first_opaque_y < 0:
		return null

	var available_height: int = frame_rect.position.y + frame_rect.size.y - first_opaque_y
	var crop_height: int = mini(_TARGET_SIZE, available_height)
	var crop_width: int = mini(_TARGET_SIZE, frame_rect.size.x)
	# Center horizontally so a sprite narrower than 32 doesn't lean to one side.
	var crop_x: int = frame_rect.position.x + (frame_rect.size.x - crop_width) / 2

	var portrait := AtlasTexture.new()
	portrait.atlas = sheet_texture
	portrait.region = Rect2(crop_x, first_opaque_y, crop_width, crop_height)
	return portrait


static func _resolve_frame_rect(character: CharacterData, image: Image) -> Rect2i:
	# Atlas-less PNGs are single-frame — the whole image is the idle frame.
	if character.sprite_atlas_path.is_empty():
		return Rect2i(0, 0, image.get_width(), image.get_height())

	var frame_tex: AtlasTexture = SpriteAtlasLoader.get_frame_texture(
		character.sprite_sheet_path,
		character.sprite_atlas_path,
		character.sprite_frame_index)
	if frame_tex == null:
		return Rect2i(0, 0, 0, 0)
	var region: Rect2 = frame_tex.region
	return Rect2i(int(region.position.x), int(region.position.y),
		int(region.size.x), int(region.size.y))


static func _find_first_opaque_row(image: Image, frame_rect: Rect2i) -> int:
	var x_start: int = maxi(0, frame_rect.position.x)
	var x_end: int = mini(image.get_width(), frame_rect.position.x + frame_rect.size.x)
	var y_start: int = maxi(0, frame_rect.position.y)
	var y_end: int = mini(image.get_height(), frame_rect.position.y + frame_rect.size.y)
	for y: int in range(y_start, y_end):
		for x: int in range(x_start, x_end):
			if image.get_pixel(x, y).a > 0.0:
				return y
	return -1
