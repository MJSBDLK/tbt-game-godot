## Renders each painted ModifierTileLayer cell as a full-PNG Sprite2D
## overlay, so visual overhang (canopy above a tree trunk, roof above a
## house base, wings of an arch past a single cell) extends correctly past
## the gameplay tile. The tilemap layer itself only renders the gameplay-
## area chunk; this overlay covers it with the full visual.
##
## Z-ordering uses ZIndexCalculator so units in front (lower row index =
## further south = higher screen Y) render above modifiers, and modifier
## overhang naturally occludes anything to its north.
##
## Shadows are spawned as separate Sprite2D nodes on a z-tier below
## the modifier (TERRAIN_EFFECTS), sharing the same world position so
## main and shadow stay aligned per the plugin's same-rect crop.
class_name ModifierRenderer
extends Node2D


## TileMapLayer whose cells drive the overlay sprites. Resolved at _ready.
@export var modifier_layer_path: NodePath = ^"../ModifierTileLayer"

# EXPERIMENT (issue: "shadows protrude against elements to the right"):
# when true, shadows render one z-slot ABOVE same-row modifiers instead of
# below all of them (TERRAIN_EFFECTS). Combined with the export-time masking
# (shadow pixels under the caster's own silhouette are erased), this makes a
# shadow spill onto the east-neighbor modifier's pixels — reading as the
# shadow falling ON the neighbor — while the caster itself stays unshaded.
# Southern neighbors (lower row index, +10 z band) still cover the shadow.
# Flip to false to restore shadows-under-everything.
const SHADOWS_ABOVE_MODIFIERS := true

const _OOB_FADE_SHADER: Shader = preload("res://shaders/modifier_oob_fade.gdshader")

var _modifier_layer: TileMapLayer = null
var _sprites: Array[Sprite2D] = []


func _ready() -> void:
	_modifier_layer = get_node_or_null(modifier_layer_path) as TileMapLayer
	if _modifier_layer == null:
		push_error("ModifierRenderer: couldn't resolve modifier_layer_path: %s" % modifier_layer_path)
		return
	refresh()


## Drop every spawned sprite and rebuild from the current ModifierTileLayer
## state. Call after editing the layer at runtime.
func refresh() -> void:
	_clear_sprites()
	if _modifier_layer == null:
		return
	var tile_set := _modifier_layer.tile_set
	if tile_set == null:
		return
	var tile_size: Vector2i = tile_set.tile_size
	# Grid height arg to ZIndexCalculator is ignored by the formula
	# (per the existing implementation), but pass something sane.
	var grid_height: int = 100
	var grid_offset_y: int = GridManager.grid_offset_y

	# Out-of-bounds fade: darken overlay pixels past the map edge with the
	# same function the floor vignette uses, so modifier overhang doesn't
	# glow at full brightness over the faded border. One shared material —
	# the params are identical for every sprite.
	var map_rect: Rect2 = GridManager.get_map_world_rect()
	var fade_material := ShaderMaterial.new()
	fade_material.shader = _OOB_FADE_SHADER
	fade_material.set_shader_parameter("map_min", map_rect.position)
	fade_material.set_shader_parameter("map_max", map_rect.end)

	for cell: Vector2i in _modifier_layer.get_used_cells():
		var source_id: int = _modifier_layer.get_cell_source_id(cell)
		if source_id < 0:
			continue
		var source := tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null or source.texture == null:
			continue
		var atlas_coords: Vector2i = _modifier_layer.get_cell_atlas_coords(cell)
		var footprint: Vector2i = source.get_tile_size_in_atlas(atlas_coords)

		# Cell center for the painted cell; for multi-cell tiles the visual
		# anchor is the center of the footprint rectangle (offset by half a
		# cell per extra footprint cell on each axis). Painted cell is the
		# footprint's north-west anchor; it expands east and south.
		var cell_center: Vector2 = _modifier_layer.map_to_local(cell)
		var visual_center := cell_center + Vector2(
				float(footprint.x - 1) * float(tile_size.x) / 2.0,
				float(footprint.y - 1) * float(tile_size.y) / 2.0)

		# Row index follows the project's front-row-zero convention (same as
		# Unit._update_z_index): row 0 = southernmost = highest z. The SOUTHERN
		# footprint row drives the shadow and the legacy "solid" occlusion mode.
		# In the default "interleave" mode each row is sorted independently below
		# (see compute_row_strips), so a unit standing on a back row isn't
		# swallowed by the whole sprite.
		var south_row_index: int = front_row_index(cell.y, footprint.y, grid_offset_y)
		var south_modifier_z: int = ZIndexCalculator.calculate_sorting_order(
				south_row_index, grid_height, ZIndexCalculator.ZIndexLayer.TERRAIN_MODIFIERS)
		var shadow_z: int
		if SHADOWS_ABOVE_MODIFIERS:
			# One slot above same-row modifiers (slot 3 in the row's z band) —
			# spills over east neighbors; export-time masking keeps the caster
			# itself unshaded. See the const's doc comment.
			shadow_z = south_modifier_z + 1
		else:
			shadow_z = ZIndexCalculator.calculate_sorting_order(
					south_row_index, grid_height, ZIndexCalculator.ZIndexLayer.TERRAIN_EFFECTS)

		# Spawn shadow first so it sits behind everything else added at the
		# same world position. The shadow PNG file lives next to the source
		# texture with a `_shadow` suffix; if it's missing we skip silently.
		var shadow_path: String = _shadow_path_for(source.texture.resource_path)
		if shadow_path != "" and ResourceLoader.exists(shadow_path):
			var shadow_tex: Texture2D = load(shadow_path)
			if shadow_tex != null:
				var shadow_sprite := Sprite2D.new()
				shadow_sprite.texture = shadow_tex
				shadow_sprite.centered = true
				shadow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				shadow_sprite.position = visual_center
				shadow_sprite.z_index = shadow_z
				shadow_sprite.z_as_relative = false
				shadow_sprite.material = fade_material
				add_child(shadow_sprite)
				_sprites.append(shadow_sprite)

		# Occlusion mode. Multi-row sprites default to per-row strips so a unit
		# on a back row interleaves correctly; a sprite can opt back to the
		# single-sprite "solid" block via modifier_terrain.json's `occlude`.
		var sprite_name: String = source.resource_name
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
				strip_sprite.z_index = ZIndexCalculator.calculate_sorting_order(
						strip["row_index"], grid_height,
						ZIndexCalculator.ZIndexLayer.TERRAIN_MODIFIERS)
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
			sprite.z_index = south_modifier_z
			sprite.z_as_relative = false
			sprite.material = fade_material
			add_child(sprite)
			_sprites.append(sprite)

	# Hide the tilemap layer so it doesn't double-render the gameplay-area
	# chunk underneath the overlay. The Tile nodes (invisible gameplay state)
	# don't depend on the layer's visibility.
	_modifier_layer.visible = false


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


## Converts a modifier's anchor cell + footprint into the project's
## front-row-zero row index (the convention Unit._update_z_index and the
## tile GridZIndexHandlers use): row = grid_y - grid_offset_y, where
## grid_y = -cell_y (tilemap Y-down → game grid Y-up) and the modifier
## sorts by its southernmost footprint row (anchor_cell_y + footprint_y - 1).
static func front_row_index(anchor_cell_y: int, footprint_y: int, grid_offset_y: int) -> int:
	var south_cell_y: int = anchor_cell_y + footprint_y - 1
	return -south_cell_y - grid_offset_y


## Splits a multi-row modifier texture into one horizontal strip per footprint
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
## tall modifier still occludes everything behind it, exactly as the single
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
