## One-shot registration tool: walks the exported modifier/decoration sprites
## at SOURCE_DIR and adds a TileSetAtlasSource per main PNG to the target
## TileSet. Reads the sidecar JSON to size multi-cell tiles. Idempotent —
## sources whose texture path is already registered are skipped.
##
## This tool ONLY mints paintable tiles (texture, footprint sizing, editor
## anchoring). It does NOT assign terrain — that lives in
## data/modifier_terrain.json and is resolved at scene build by
## tilemap_grid_builder via ModifierTerrainMap. So re-run this ONLY when new
## sprites arrive; retuning terrain assignments is a JSON edit + battle reload,
## no re-registration needed. See
## data/design/terrain_modifiers_and_decorations.md, "Architecture: terrain
## across three systems".
##
## Run from the project root via:
##   godot-4 --headless --path . --script tools/register_modifier_tiles.gd
@tool
extends SceneTree


const SOURCE_DIR := "res://art/sprites/decorations/decorations_and_modifiers/"
const TILESET_PATH := "res://resources/battle_tileset.tres"
const MODIFIER_SOURCE_ID_BASE := 100
const TILE_SIZE := 32


func _init() -> void:
	var exit_code := _register_all()
	quit(exit_code)


func _register_all() -> int:
	var tileset: TileSet = load(TILESET_PATH)
	if tileset == null:
		push_error("register_modifier_tiles: cannot load %s" % TILESET_PATH)
		return 1

	var dir := DirAccess.open(SOURCE_DIR)
	if dir == null:
		push_error("register_modifier_tiles: cannot open %s" % SOURCE_DIR)
		return 1

	var png_names: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".png") and not entry.ends_with(".import"):
			# Skip the paired _shadow.png — those are runtime-only, not tiles.
			if not entry.ends_with("_shadow.png"):
				png_names.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	png_names.sort()

	# Wipe any pre-existing modifier sources so we re-register from scratch
	# (gives the custom-data refresh below something to apply to). Sources
	# below MODIFIER_SOURCE_ID_BASE are the project's existing autotile
	# sheets — never touch those.
	var modifier_source_ids: Array[int] = []
	for i in range(tileset.get_source_count()):
		var src_id: int = tileset.get_source_id(i)
		if src_id >= MODIFIER_SOURCE_ID_BASE:
			modifier_source_ids.append(src_id)
	for src_id in modifier_source_ids:
		tileset.remove_source(src_id)
	if not modifier_source_ids.is_empty():
		print("register_modifier_tiles: cleared %d pre-existing modifier sources" % modifier_source_ids.size())

	var next_id: int = MODIFIER_SOURCE_ID_BASE
	var added: int = 0
	var skipped: int = 0

	for filename in png_names:
		var basename := filename.substr(0, filename.length() - 4)  # strip ".png"
		var png_path: String = SOURCE_DIR + filename

		var tex: Texture2D = load(png_path)
		if tex == null:
			push_error("register_modifier_tiles: cannot load %s" % png_path)
			continue

		var footprint := Vector2i(1, 1)
		var shadow_path: String = ""
		var sidecar_path: String = SOURCE_DIR + basename + ".json"
		if FileAccess.file_exists(sidecar_path):
			var sidecar_raw := FileAccess.get_file_as_string(sidecar_path)
			var sidecar_data: Variant = JSON.parse_string(sidecar_raw)
			if sidecar_data is Dictionary:
				var d: Dictionary = sidecar_data
				if d.has("footprint"):
					var fp: Array = d["footprint"]
					if fp.size() == 2:
						footprint = Vector2i(int(fp[0]), int(fp[1]))
				if d.has("shadow_path"):
					shadow_path = str(d["shadow_path"])

		var source := TileSetAtlasSource.new()
		source.texture = tex
		source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		source.resource_name = basename  # shows up as the source label in the TileSet editor

		# Place the atlas tile at the CENTER cell(s) of the source so the
		# tilemap renders the gameplay area (centered on the pivot), not the
		# top-left of the PNG. The plugin emits cropped PNGs with the
		# footprint as the central footprint×32 chunk of the texture; the
		# surrounding cells are visual overhang (rendered by the runtime
		# Sprite2D overlay).
		var png_cells_x: int = tex.get_width() / TILE_SIZE
		var png_cells_y: int = tex.get_height() / TILE_SIZE
		var atlas_pos := Vector2i(
				(png_cells_x - footprint.x) / 2,
				(png_cells_y - footprint.y) / 2)
		source.create_tile(atlas_pos, footprint)

		# Register the source in the tileset FIRST so TileData's set_custom_data
		# can resolve the layer-name lookup (which walks back through the source's
		# parent tileset). Setting custom data on a detached TileData silently
		# no-ops.
		tileset.add_source(source, next_id)
		var tile_data: TileData = source.get_tile_data(atlas_pos, 0)
		if tile_data != null:
			# is_modifier (custom_data_1) is a self-describing flag; terrain
			# assignment lives in data/modifier_terrain.json, NOT here.
			tile_data.set_custom_data("is_modifier", true)
			# Godot draws a tile's texture centered on the painted cell. For
			# multi-cell tiles our anchor convention is "painted cell = NW
			# corner, expands east/south", so shift the editor-preview texture
			# down-right by half a cell per extra footprint cell. Positive
			# texture_origin moves the texture up-left, hence the negation.
			# Runtime visuals don't use this (ModifierRenderer positions its
			# own sprites); this is purely so painting looks right in-editor.
			if footprint != Vector2i.ONE:
				tile_data.texture_origin = -Vector2i(
						(footprint.x - 1) * TILE_SIZE / 2,
						(footprint.y - 1) * TILE_SIZE / 2)

		var shadow_note: String = ", +shadow" if shadow_path != "" else ""
		print("  Added: %s (footprint %dx%d, id %d%s)" % [
			basename, footprint.x, footprint.y, next_id, shadow_note])
		next_id += 1
		added += 1

	if added > 0:
		var save_err := ResourceSaver.save(tileset, TILESET_PATH)
		if save_err != OK:
			push_error("register_modifier_tiles: failed to save tileset (err %d)" % save_err)
			return 1
		print("register_modifier_tiles: added %d new sources, %d already registered, saved %s" % [
			added, skipped, TILESET_PATH])
	else:
		print("register_modifier_tiles: no new tiles to register (%d already registered)" % skipped)
	return 0
