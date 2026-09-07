## Draws every painted cell of ONE terrain-sprite paint layer
## (ModifierTileLayer or DecorationTileLayer) as full-PNG Sprite2D overlays,
## so visual overhang (canopy above a trunk, roof above a house base, wings of
## an arch past a single cell) extends correctly past the gameplay tile. The
## tilemap layer itself only renders the gameplay-area chunk of the atlas;
## this overlay hides the layer and draws the full visual in its place.
##
## ONE sprite library, TWO paint layers. The same tile can be painted on
## either layer — the layer decides gameplay (modifier cells REPLACE floor
## terrain; decoration cells do nothing), never looks. TilemapGridBuilder
## spawns one of these per layer and both render identically: same z band,
## same per-row strips, same shadows. The decoration renderer is added to the
## tree AFTER the modifier one, so a decoration painted on the same cell as a
## modifier (a bush on a crater) draws over it by tree order at equal z.
##
## Z (ZIndexCalculator): board z = (99 − row) × 10 + slot, rows front-row-zero
## (row 0 = southernmost = highest z; see Unit._update_z_index). Bodies sit in
## the TERRAIN_MODIFIERS slot of their SOUTHERN footprint row (or, in
## "interleave" mode, one strip per row at that row's slot — see
## compute_row_strips). Shadows go one slot above the body
## (TERRAIN_SHADOWS) when SHADOWS_ABOVE_MODIFIERS, so a shadow spills onto
## the east neighbor's body; the caster itself stays clean because the
## exporter erased shadow pixels under the caster's own silhouette. Anything
## on a more-southern row (+10 per row) covers both. Units in the same row
## (UNITS slot) draw over everything terrain.
##
## EDITOR PREVIEW: this script is @tool. TilemapGridBuilder (also @tool)
## spawns unowned preview renderers while a map scene is open in the editor,
## so Lawrence paints and sees the real thing — overhang, shadows, per-row
## sorting — instead of the cropped 32×32 atlas chunk and an F5 round trip.
## In the editor the renderer keeps the TileMapLayer visible (the overlay
## covers its chunk pixel-for-pixel, and painting needs the layer shown),
## skips the out-of-bounds fade (no GridManager), derives the front row from
## the floor layer's southernmost painted cell (what GridManager would do),
## and polls the layer's tile data every few frames to refresh after a
## paint stroke. Unowned nodes are never saved into the .tscn, so the
## runtime never sees them.
##
## Shadows, in order: (1) the authored `<sprite>_shadow.png` next to the
## source texture, when Lawrence drew one — played verbatim; (2) otherwise a
## GENERATED cast of the sprite's own pixels (generate_cast_shadow, built on
## UnitShadow.project_silhouette so terrain and units share one sun), unless
## the sprite opts out in modifier_terrain.json (`casts_shadow: false` —
## craters, the bridge: flat ground features cast nothing) or
## DebugConfig.terrain_generated_shadows is off. Authored always wins; the
## generator is the fallback for art that hasn't had its shadow pass yet.
@tool
class_name TerrainSpriteRenderer
extends Node2D


## TileMapLayer whose cells drive the overlay sprites. Resolved at _ready.
@export var layer_path: NodePath = ^"../ModifierTileLayer"

## Editor preview only: the floor layer that defines the map's southernmost
## row (front row zero). At runtime GridManager owns that number.
@export var floor_layer_path: NodePath = ^"../TerrainTileLayer"

## Editor preview only: how often (in frames) to check the layer for paint
## changes. A PackedByteArray hash of ~50 cells is microseconds.
const EDITOR_POLL_FRAMES: int = 10

# EXPERIMENT (issue: "shadows protrude against elements to the right"):
# when true, shadows render one z-slot ABOVE same-row bodies instead of
# below all of them (TERRAIN_EFFECTS). Combined with the export-time masking
# (shadow pixels under the caster's own silhouette are erased), this makes a
# shadow spill onto the east-neighbor sprite's pixels — reading as the
# shadow falling ON the neighbor — while the caster itself stays unshaded.
# Southern neighbors (lower row index, +10 z band) still cover the shadow.
# Flip to false to restore shadows-under-everything.
const SHADOWS_ABOVE_MODIFIERS := true

const _OOB_FADE_SHADER: Shader = preload("res://shaders/modifier_oob_fade.gdshader")

## Generated-shadow dials. Shared with UnitShadow so the board has ONE sun:
## the same rigid 90° tip-over (canvas-up → screen-right) and the same
## squash. If generated terrain shadows read longer than Lawrence's authored
## ones (his shelltree cast measured ~0.85 of sprite height against the
## units' 1.0), split these off and dial them separately.
const GENERATED_SMOOSH_X: float = UnitShadow.SHADOW_SMOOSH_X
const GENERATED_SMOOSH_Y: float = UnitShadow.SHADOW_SMOOSH_Y
const GENERATED_SHEAR: float = UnitShadow.SHADOW_SHEAR
## Flat vertical nudge for the generated smear, in pixels, positive =
## down-screen. UnitShadow carries −2 for boots; terrain art's feet line is
## its lowest opaque row, which already IS the ground. 0 = none.
const GENERATED_OFFSET_Y: float = 0.0

# Generated shadows are pure functions of (texture, dials) — cached across
# renderers so each sprite rasterizes once per session. Values are
# {"texture": ImageTexture, "anchor": Vector2} or {} when nothing casts.
static var _generated_cache: Dictionary = {}

# Grid height arg to ZIndexCalculator is ignored by the formula (per the
# existing implementation), but pass something sane.
const _GRID_HEIGHT_FOR_Z: int = 100

var _layer: TileMapLayer = null
var _sprites: Array[Sprite2D] = []
var _editor_poll_countdown: int = 0
var _editor_last_hash: int = 0


func _ready() -> void:
	_layer = get_node_or_null(layer_path) as TileMapLayer
	if _layer == null:
		push_error("TerrainSpriteRenderer: couldn't resolve layer_path: %s" % layer_path)
		return
	set_process(Engine.is_editor_hint())
	refresh()


## Editor only (set_process is off at runtime): re-render when the layer's
## painted data changed since the last look.
func _process(_delta: float) -> void:
	if _layer == null:
		return
	_editor_poll_countdown -= 1
	if _editor_poll_countdown > 0:
		return
	_editor_poll_countdown = EDITOR_POLL_FRAMES
	var current_hash: int = hash(_layer.tile_map_data)
	if current_hash != _editor_last_hash:
		refresh()


## Front-row-zero offset for z math. Runtime: GridManager's, set by the
## builder before we spawn. Editor: derived the same way the builder does
## it — the floor layer's southernmost painted cell is row 0 — so the
## preview sorts like the game will.
func _grid_offset_y() -> int:
	if not Engine.is_editor_hint():
		return GridManager.grid_offset_y
	var floor_layer := get_node_or_null(floor_layer_path) as TileMapLayer
	var reference: TileMapLayer = floor_layer if floor_layer != null else _layer
	return editor_grid_offset_y(reference.get_used_cells())


## Pure: the offset that makes the southernmost (max tilemap y) painted cell
## row 0, matching TilemapGridBuilder's `set_grid_bounds(..., -max_y, ...)`.
static func editor_grid_offset_y(cells: Array[Vector2i]) -> int:
	if cells.is_empty():
		return 0
	var max_y: int = cells[0].y
	for cell in cells:
		max_y = maxi(max_y, cell.y)
	return -max_y


## Drop every spawned sprite and rebuild from the current layer state. Call
## after editing the layer at runtime.
func refresh() -> void:
	_clear_sprites()
	if _layer == null:
		return
	var tile_set := _layer.tile_set
	if tile_set == null:
		return
	var tile_size: Vector2i = tile_set.tile_size
	var in_editor: bool = Engine.is_editor_hint()
	var grid_offset_y: int = _grid_offset_y()
	if in_editor:
		_editor_last_hash = hash(_layer.tile_map_data)

	# Out-of-bounds fade: darken overlay pixels past the map edge with the
	# same function the floor vignette uses, so overhang doesn't glow at full
	# brightness over the faded border. One shared material — the params are
	# identical for every sprite. Editor preview: no GridManager, no fade.
	var fade_material: ShaderMaterial = null
	if not in_editor:
		var map_rect: Rect2 = GridManager.get_map_world_rect()
		fade_material = ShaderMaterial.new()
		fade_material.shader = _OOB_FADE_SHADER
		fade_material.set_shader_parameter("map_min", map_rect.position)
		fade_material.set_shader_parameter("map_max", map_rect.end)
	# Generated-shadow gate: a dev kill switch at runtime; always on in the
	# editor preview (no DebugConfig there).
	var generated_enabled: bool = true if in_editor else DebugConfig.terrain_generated_shadows

	for cell: Vector2i in _layer.get_used_cells():
		var source_id: int = _layer.get_cell_source_id(cell)
		if source_id < 0:
			continue
		if not tile_set.has_source(source_id):
			# A dangling reference: the tileset no longer has this source.
			# Registration renumbered (it shouldn't — see
			# tools/register_modifier_tiles.gd) or the tileset was edited by
			# hand. Loud, because the cell renders as nothing.
			push_warning("TerrainSpriteRenderer: %s cell %s references source %d which isn't in the tileset — repaint it or re-run tools/register_modifier_tiles.gd" % [
				_layer.name, str(cell), source_id])
			continue
		var source := tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null or source.texture == null:
			continue
		var atlas_coords: Vector2i = _layer.get_cell_atlas_coords(cell)
		if not source.has_tile(atlas_coords):
			push_warning("TerrainSpriteRenderer: %s cell %s references atlas %s of '%s' which has no tile there (PNG re-exported at a new size?) — repaint it" % [
				_layer.name, str(cell), str(atlas_coords), source.resource_name])
			continue
		var footprint: Vector2i = source.get_tile_size_in_atlas(atlas_coords)

		# Cell center for the painted cell; for multi-cell tiles the visual
		# anchor is the center of the footprint rectangle (offset by half a
		# cell per extra footprint cell on each axis). Painted cell is the
		# footprint's north-west anchor; it expands east and south.
		var cell_center: Vector2 = _layer.map_to_local(cell)
		var visual_center := cell_center + Vector2(
				float(footprint.x - 1) * float(tile_size.x) / 2.0,
				float(footprint.y - 1) * float(tile_size.y) / 2.0)

		# The SOUTHERN footprint row drives the shadow and the "solid"
		# occlusion mode; "interleave" sorts each row independently below.
		var south_row_index: int = front_row_index(cell.y, footprint.y, grid_offset_y)

		# Sprite name = the atlas source's resource_name (set by the
		# registration tool from the PNG basename). Keys every per-sprite
		# hint in modifier_terrain.json, so hints apply on either layer.
		var sprite_name: String = source.resource_name

		# Spawn the shadow first so it sits behind everything else added at
		# the same world position. Authored wins; generated is the fallback.
		var shadow_path: String = _shadow_path_for(source.texture.resource_path)
		if shadow_path != "" and ResourceLoader.exists(shadow_path):
			var shadow_tex: Texture2D = load(shadow_path)
			if shadow_tex != null:
				var shadow_sprite := Sprite2D.new()
				shadow_sprite.texture = shadow_tex
				shadow_sprite.centered = true
				shadow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				shadow_sprite.position = visual_center
				shadow_sprite.z_index = shadow_z(south_row_index)
				shadow_sprite.z_as_relative = false
				shadow_sprite.material = fade_material
				add_child(shadow_sprite)
				_sprites.append(shadow_sprite)
		elif generated_enabled and ModifierTerrainMap.casts_shadow(sprite_name):
			var generated: Dictionary = _generated_shadow_for(source.texture)
			if not generated.is_empty():
				var shadow_sprite := Sprite2D.new()
				shadow_sprite.texture = generated["texture"]
				shadow_sprite.centered = false
				shadow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				shadow_sprite.position = visual_center + generated["anchor"]
				shadow_sprite.z_index = shadow_z(south_row_index)
				shadow_sprite.z_as_relative = false
				shadow_sprite.material = fade_material
				add_child(shadow_sprite)
				_sprites.append(shadow_sprite)

		# Occlusion mode. Multi-row sprites default to per-row strips so a
		# unit on a back row interleaves correctly; a sprite can opt back to
		# the single-sprite "solid" block via modifier_terrain.json's
		# `occlude`.
		var mode: String = ModifierTerrainMap.occlude_mode(sprite_name)
		if footprint.y > 1 and mode != ModifierTerrainMap.OCCLUDE_SOLID:
			var tex_size: Vector2i = Vector2i(source.texture.get_size())
			var strips: Array[Dictionary] = compute_row_strips(
					tex_size, footprint, tile_size, cell.y, grid_offset_y)
			for strip: Dictionary in strips:
				var strip_sprite := Sprite2D.new()
				strip_sprite.texture = source.texture
				strip_sprite.centered = false
				strip_sprite.region_enabled = true
				strip_sprite.region_rect = strip["region_rect"]
				strip_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				strip_sprite.position = visual_center + strip["offset"]
				strip_sprite.z_index = body_z(strip["row_index"])
				strip_sprite.z_as_relative = false
				strip_sprite.material = fade_material
				add_child(strip_sprite)
				_sprites.append(strip_sprite)
		else:
			var sprite := Sprite2D.new()
			sprite.texture = source.texture
			sprite.centered = true
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = visual_center
			sprite.z_index = body_z(south_row_index)
			sprite.z_as_relative = false
			sprite.material = fade_material
			add_child(sprite)
			_sprites.append(sprite)

	# Hide the tilemap layer so it doesn't double-render the gameplay-area
	# chunk underneath the overlay. The Tile nodes (invisible gameplay state)
	# don't depend on the layer's visibility. In the editor the layer stays
	# visible — painting needs it — and the overlay simply covers its chunk.
	if not in_editor:
		_layer.visible = false


## Sprites spawned by the last refresh (tests / diagnostics).
func get_spawned_sprites() -> Array[Sprite2D]:
	return _sprites


func _clear_sprites() -> void:
	for s in _sprites:
		s.queue_free()
	_sprites.clear()


## Convention: `<source>.png` is paired with `<source>_shadow.png` in the
## same directory. Returns "" for non-PNG inputs.
static func _shadow_path_for(texture_path: String) -> String:
	if not texture_path.ends_with(".png"):
		return ""
	return texture_path.substr(0, texture_path.length() - 4) + "_shadow.png"


## Cached generated shadow for a source texture (see generate_cast_shadow):
## {"texture": ImageTexture, "anchor": Vector2} or {} when nothing casts /
## the texture's pixels can't be read back.
static func _generated_shadow_for(texture: Texture2D) -> Dictionary:
	var key := "%s|%.3f|%.3f|%.3f|%.1f" % [texture.get_rid(),
			GENERATED_SMOOSH_X, GENERATED_SMOOSH_Y, GENERATED_SHEAR, GENERATED_OFFSET_Y]
	if _generated_cache.has(key):
		return _generated_cache[key]
	var result: Dictionary = {}
	var image: Image = UnitShadow._readable_sheet(texture)
	if image != null:
		var cast := generate_cast_shadow(image,
				GENERATED_SMOOSH_X, GENERATED_SMOOSH_Y, GENERATED_SHEAR, GENERATED_OFFSET_Y)
		if not cast.is_empty():
			result = {
				"texture": ImageTexture.create_from_image(cast["image"]),
				"anchor": cast["anchor"],
			}
	_generated_cache[key] = result
	return result


## Cast a terrain sprite's own pixels onto the ground the way UnitShadow does
## for units — the fallback for sprites Lawrence hasn't drawn a shadow for.
## Pure: takes the sprite's RGBA image and the dials, returns
##   {"image": Image — the smear, ink baked in (GameColors.CAST_SHADOW_INK),
##    "anchor": Vector2 — the image's top-left relative to the sprite's
##              visual center (a centered Sprite2D's origin)}
## or {} when nothing casts.
##
## The feet line is one past the art's lowest opaque row (terrain art is
## drawn standing on the ground, unlike body-centered character canvases);
## horizontally the pivot is the canvas center. UnitShadow.project_silhouette
## does the turn + squash + shear. Then, mirroring the exporter's
## _mask_shadow_by_object, every smear pixel that lands under the caster's
## own opaque pixels is erased — that's what lets the shadow sit one z slot
## ABOVE bodies (falling onto the east neighbor) without tinting its caster.
## The ink is baked rather than applied as modulate so the result is right
## under any material, and each pixel is set exactly once so the smear can
## never self-darken.
static func generate_cast_shadow(sprite: Image, smoosh_x: float, smoosh_y: float,
		shear: float, offset_y: float) -> Dictionary:
	if sprite == null:
		return {}
	var width: int = sprite.get_width()
	var height: int = sprite.get_height()
	var feet_row: int = -1
	for y in range(height - 1, -1, -1):
		for x in range(width):
			if sprite.get_pixel(x, y).a > UnitShadow.ALPHA_SOLID_THRESHOLD:
				feet_row = y + 1
				break
		if feet_row >= 0:
			break
	if feet_row < 0:
		return {}
	var pivot := Vector2(float(width) / 2.0, float(feet_row))
	var projected: Dictionary = UnitShadow.project_silhouette(
			sprite, pivot, smoosh_x, smoosh_y, shear, 0.0)
	if projected.is_empty():
		return {}
	var image: Image = projected["image"]
	var feet_anchor: Vector2 = projected["anchor"]
	# Where the smear's top-left lands in the sprite's own pixel space, draw
	# nudge included — the same frame the self-mask reads the caster in.
	var origin := Vector2(pivot.x + feet_anchor.x, pivot.y + feet_anchor.y + offset_y).round()
	var ink: Color = GameColors.CAST_SHADOW_INK
	var clear := Color(0.0, 0.0, 0.0, 0.0)
	for py in range(image.get_height()):
		for px in range(image.get_width()):
			if image.get_pixel(px, py).a <= 0.0:
				continue
			var sx: int = int(origin.x) + px
			var sy: int = int(origin.y) + py
			var under_caster: bool = sx >= 0 and sx < width and sy >= 0 and sy < height \
					and sprite.get_pixel(sx, sy).a > UnitShadow.ALPHA_SOLID_THRESHOLD
			image.set_pixel(px, py, clear if under_caster else ink)
	# A centered Sprite2D puts sprite pixel (0,0) at local (-w/2, -h/2).
	var anchor := origin - Vector2(float(width) / 2.0, float(height) / 2.0)
	return {"image": image, "anchor": anchor}


## Absolute z for a sprite body sorting at `row_index` (front-row-zero).
## Same band on both paint layers — decoration-over-modifier on a shared
## cell is tree order, not z.
static func body_z(row_index: int) -> int:
	return ZIndexCalculator.calculate_sorting_order(
			row_index, _GRID_HEIGHT_FOR_Z, ZIndexCalculator.ZIndexLayer.TERRAIN_MODIFIERS)


## Absolute z for a sprite's shadow sorting at `row_index`: one slot above
## the body (TERRAIN_SHADOWS) so it falls onto east neighbors, or down in
## TERRAIN_EFFECTS under every body when the experiment is off.
static func shadow_z(row_index: int) -> int:
	if SHADOWS_ABOVE_MODIFIERS:
		return ZIndexCalculator.calculate_sorting_order(
				row_index, _GRID_HEIGHT_FOR_Z, ZIndexCalculator.ZIndexLayer.TERRAIN_SHADOWS)
	return ZIndexCalculator.calculate_sorting_order(
			row_index, _GRID_HEIGHT_FOR_Z, ZIndexCalculator.ZIndexLayer.TERRAIN_EFFECTS)


## Converts a sprite's anchor cell + footprint into the project's
## front-row-zero row index (the convention Unit._update_z_index and the
## tile GridZIndexHandlers use): row = grid_y - grid_offset_y, where
## grid_y = -cell_y (tilemap Y-down → game grid Y-up) and the sprite sorts
## by its southernmost footprint row (anchor_cell_y + footprint_y - 1).
static func front_row_index(anchor_cell_y: int, footprint_y: int, grid_offset_y: int) -> int:
	var south_cell_y: int = anchor_cell_y + footprint_y - 1
	return -south_cell_y - grid_offset_y


## Splits a multi-row sprite texture into one horizontal strip per footprint
## row so each row can sort at its own depth ("interleave" mode). Returns one
## Dictionary per row (north→south) with:
##   region_rect: Rect2 — the slice of the texture for this row
##   offset:      Vector2 — top-left of that slice relative to the sprite's
##                visual_center (add visual_center to get world position; the
##                strip Sprite2D uses centered = false)
##   row_index:   int — front-row-zero index for ZIndexCalculator
##
## Invariant the strips preserve: ALL vertical overhang (towers, canopy) lives
## in the NORTH (top) strip and therefore sorts at the top footprint row. Since
## overhang only extends north and anything north of the top row is further
## back, the top strip always out-sorts a unit standing in those cells — so a
## tall sprite still occludes everything behind it, exactly as the single
## sprite did. Assumes overhang extends north only (true for our assets); any
## south-extending overhang would belong to the bottom strip and is not split
## out here.
##
## Pure/static so it's unit-testable without a scene tree or real texture.
static func compute_row_strips(tex_size: Vector2i, footprint: Vector2i,
		tile_size: Vector2i, anchor_cell_y: int, grid_offset_y: int) -> Array[Dictionary]:
	var strips: Array[Dictionary] = []
	var rows: int = footprint.y
	var tile_h: int = tile_size.y
	var tex_w: float = float(tex_size.x)
	var tex_h: float = float(tex_size.y)
	# The footprint occupies the central `rows * tile_h` band of the texture;
	# the crop is symmetric around the pivot, so the overhang splits evenly and
	# the footprint's top edge sits `overhang_top` pixels down from the texture
	# top.
	var overhang_top: float = (tex_h - float(rows * tile_h)) / 2.0
	for row: int in range(rows):
		var band_top: float = overhang_top + float(row * tile_h)
		var band_bottom: float = band_top + float(tile_h)
		if row == 0:
			band_top = 0.0  # north strip swallows all top overhang
		if row == rows - 1:
			band_bottom = tex_h  # south strip swallows any bottom margin
		var region := Rect2(0.0, band_top, tex_w, band_bottom - band_top)
		var offset := Vector2(-tex_w / 2.0, -tex_h / 2.0 + band_top)
		strips.append({
			"region_rect": region,
			"offset": offset,
			"row_index": front_row_index(anchor_cell_y + row, 1, grid_offset_y),
		})
	return strips
