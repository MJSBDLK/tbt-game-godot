## Loads the void-lock FX sprite sheets (art/sprites/ui/void_lock_fx/) into
## per-tag SpriteFrames, plus each tag's content bounding box (so callers can
## anchor a sprite at any point of its art — e.g. fizzles anchor at their
## bottom-left origin, not the canvas centre). Sheets are untrimmed, one
## row of `frames` cells `fw×fh` each; built from void_lock_fx_parts.aseprite.
##
## All static + cached; first use loads the manifest once.
class_name VoidLockFxLibrary
extends Object

const DIR: String = "res://art/sprites/ui/void_lock_fx/"
const MANIFEST: String = DIR + "manifest.json"

static var _frames: Dictionary = {}   # tag -> SpriteFrames (animation "default")
static var _bbox: Dictionary = {}     # tag -> Rect2i (content box within a frame)
static var _frame_size: Vector2i = Vector2i(96, 28)
static var _loaded: bool = false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(MANIFEST, FileAccess.READ)
	if file == null:
		push_error("VoidLockFxLibrary: manifest not found at %s" % MANIFEST)
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		push_error("VoidLockFxLibrary: manifest parse failed")
		return
	for tag: String in data:
		var info: Dictionary = data[tag]
		var tex := load(DIR + str(info["file"])) as Texture2D
		if tex == null:
			continue
		var fw: int = int(info["fw"])
		var fh: int = int(info["fh"])
		_frame_size = Vector2i(fw, fh)
		var durations: Array = info["durations"]
		var sf := SpriteFrames.new()
		# 100ms frames → 10 fps; per-frame relative duration stays 1.0.
		sf.set_animation_speed("default", 1000.0 / maxf(1.0, float(durations[0])))
		sf.set_animation_loop("default", false)
		for i: int in int(info["frames"]):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * fw, 0, fw, fh)
			sf.add_frame("default", atlas, 1.0)
		_frames[tag] = sf
		var b: Array = info["bbox"]
		_bbox[tag] = Rect2i(int(b[0]), int(b[1]), int(b[2]), int(b[3]))


## SpriteFrames for a tag (animation "default", non-looping), or null.
static func frames(tag: String) -> SpriteFrames:
	_ensure()
	return _frames.get(tag, null)


## Content bounding box of a tag within its frame (union across the tag's frames).
static func content_bbox(tag: String) -> Rect2i:
	_ensure()
	return _bbox.get(tag, Rect2i(Vector2i.ZERO, _frame_size))


static func frame_size() -> Vector2i:
	_ensure()
	return _frame_size


## All tags whose name starts with `prefix` (e.g. "void fizzle"), sorted.
static func tags_with_prefix(prefix: String) -> Array:
	_ensure()
	var out: Array = []
	for tag: String in _frames:
		if tag.begins_with(prefix):
			out.append(tag)
	out.sort()
	return out
