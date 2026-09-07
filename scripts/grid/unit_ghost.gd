## UnitGhost — the shared "projection of a unit somewhere it isn't" builder.
## A silhouette clone of the unit's live Sprite2D frame wearing
## shaders/ghost_projection.gdshader (flatten-to-tint + static + tracking), so
## every ghost on the board — a displacement preview's "where the shove puts
## them" (DisplacementPreviewRenderer) and a move plan's "where I'll stand"
## (PathVisualizer) — is the same material and the same read. Extracted
## 2026-08-21 (todo #4) when the second caller arrived; the displacement
## renderer's behavior is unchanged and its tests still pin it.
##
## Anchor rule: ghosts live in SPRITE space. Units anchor mid-body at the cell
## center (pivot convention), so a ghost parked "on a tile" sits at
## tile.global_position + anchor_offset(unit) — the sprite's offset from its
## own tile — and lines up with where the real sprite would stand.
##
## Reduce-motion: the shader's `animate` uniform freezes the static/tracking
## flicker. make_material() reads Settings once; owners that outlive a toggle
## call set_animated() from Settings.changed.
class_name UnitGhost
extends RefCounted


const GHOST_SHADER: Shader = preload("res://shaders/ghost_projection.gdshader")


## One material per owner (a renderer, a path visualizer) — shared by every
## ghost that owner spawns, so a reduce-motion flip updates them all at once.
static func make_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GHOST_SHADER
	set_animated(material, Settings == null or Settings.ui_motion_enabled)
	return material


static func set_animated(material: ShaderMaterial, animated: bool) -> void:
	if material == null:
		return
	material.set_shader_parameter("animate", 1.0 if animated else 0.0)


## Clone the unit's current sprite frame as a ghost. Null when the unit has no
## textured Sprite2D (bare test units). The caller parents and positions it;
## the clone carries the source's frame/region/flip/offset/scale so the
## silhouette matches the live pose pixel for pixel.
static func build(unit: Node2D, material: ShaderMaterial) -> Sprite2D:
	if unit == null:
		return null
	var source: Sprite2D = unit.get_node_or_null("Sprite2D") as Sprite2D
	if source == null or source.texture == null:
		return null
	var ghost := Sprite2D.new()
	ghost.texture = source.texture
	ghost.region_enabled = source.region_enabled
	ghost.region_rect = source.region_rect
	ghost.hframes = source.hframes
	ghost.vframes = source.vframes
	ghost.frame = source.frame
	ghost.offset = source.offset
	ghost.centered = source.centered
	ghost.flip_h = source.flip_h
	ghost.flip_v = source.flip_v
	ghost.scale = source.global_scale
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.material = material
	return ghost


## The sprite's offset from its unit's tile — add to any tile position to park
## a ghost where the unit would stand on that tile.
static func anchor_offset(unit: Node2D) -> Vector2:
	if unit == null:
		return Vector2.ZERO
	var source: Sprite2D = unit.get_node_or_null("Sprite2D") as Sprite2D
	var tile: Tile = unit.get("current_tile") as Tile
	if source == null or tile == null:
		return Vector2.ZERO
	return source.global_position - tile.global_position
