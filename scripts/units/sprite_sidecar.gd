## SpriteSidecar — reads the tag exporter's `<strip>.json` next to an idle
## PNG and turns it into the numbers a sprite needs to stand on a point:
## the Sprite2D.offset that puts the authored pivot on the node origin, the
## top of the opaque art (health bars sit above it), and how far the visual
## feet hang below the pivot (cast shadows pivot at the boots — the cast is
## body-centred, see the pivot memory / .claude/todo-archive.md ("Battle animations plan")).
## Extracted from Unit so a CombatPuppet stands exactly like the map unit.
class_name SpriteSidecar
extends RefCounted


## { "offset": Vector2, "art_top": float, "feet_drop": float, "has_pivot": bool }
## `offset` falls back to feet-at-origin (0, -height/2) when there is no
## sidecar, matching the pre-sidecar behaviour.
static func read(sheet_path: String, texture: Texture2D) -> Dictionary:
	var width := float(texture.get_width())
	var height := float(texture.get_height())
	var result := {
		"offset": Vector2(0, -height / 2.0),
		"art_top": 0.0,
		"feet_drop": 0.0,
		"has_pivot": false,
	}
	var sidecar_path: String = sheet_path.trim_suffix(".png") + ".json"
	if not FileAccess.file_exists(sidecar_path):
		return result
	var content := FileAccess.get_file_as_string(sidecar_path)
	if content.is_empty():
		return result
	var parsed: Variant = JSON.parse_string(content)
	if not (parsed is Dictionary) or not parsed.has("pivot"):
		return result
	var pivot: Dictionary = parsed["pivot"]
	var px := float(pivot.get("x", width / 2.0))
	var py := float(pivot.get("y", height))
	if parsed.has("art_bounds"):
		var bounds: Dictionary = parsed["art_bounds"]
		result["art_top"] = float(bounds.get("top", 0))
		# Visual feet = bottom of the opaque art. With the cast's body-centred
		# canvases the pivot is mid-body; the gap is what the shadow needs.
		result["feet_drop"] = maxf(0.0, float(bounds.get("bottom", py)) - py)
	result["offset"] = Vector2(width / 2.0 - px, height / 2.0 - py)
	result["has_pivot"] = true
	return result
