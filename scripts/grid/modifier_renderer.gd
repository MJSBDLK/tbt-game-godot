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
		# Unit._update_z_index): row 0 = southernmost = highest z. A modifier
		# sorts by its SOUTHERN footprint edge so a multi-cell building
		# occludes units standing behind (north of) its body, while units in
		# front (south) render above it.
		var row_index: int = front_row_index(cell.y, footprint.y, grid_offset_y)
		var modifier_z: int = ZIndexCalculator.calculate_sorting_order(
				row_index, grid_height, ZIndexCalculator.ZIndexLayer.TERRAIN_MODIFIERS)
		var shadow_z: int = ZIndexCalculator.calculate_sorting_order(
				row_index, grid_height, ZIndexCalculator.ZIndexLayer.TERRAIN_EFFECTS)

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
				add_child(shadow_sprite)
				_sprites.append(shadow_sprite)

		var sprite := Sprite2D.new()
		sprite.texture = source.texture
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = visual_center
		sprite.z_index = modifier_z
		sprite.z_as_relative = false
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
