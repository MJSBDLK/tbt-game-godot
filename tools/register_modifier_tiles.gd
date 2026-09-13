## Registration tool: walks the exported modifier/decoration sprites at
## SOURCE_DIR and makes sure every main PNG is a TileSetAtlasSource in the
## target TileSet. Reads the sidecar JSON to size multi-cell tiles.
##
## SOURCE IDS ARE STABLE. Painted cells in every map .tscn reference tiles
## by (source_id, atlas_coords), so a source id is a contract with the maps:
## a sprite keeps the id it was first registered under, forever. New sprites
## get fresh ids ABOVE everything already in use, in sorted-name order.
## Nothing is ever renumbered — the pre-2026-09 version of this tool wiped
## all sources >= 100 and re-minted them in sorted order, which meant adding
## `bush_a` would shift `castle_a` and every later sprite by one and silently
## repaint every map. plan_source_ids is the pure planner; the drift assert
## at the end refuses to save if any previously registered id changed hands.
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
##
## Safe to re-run at any time: already-registered sprites are re-validated in
## place (custom data, editor anchor); only a sprite whose PNG dimensions
## changed gets its atlas tile rebuilt, with a loud warning because painted
## cells of that sprite need repainting. A run that changes nothing doesn't
## touch the file. A run that does save also re-inserts the `uid="..."`
## attributes ResourceSaver drops outside the editor (restore_uids_in_text),
## so the diff shows only real changes.
@tool
extends SceneTree


const SOURCE_DIR := "res://art/sprites/decorations/decorations_and_modifiers/"
const TILESET_PATH := "res://resources/battle_tileset.tres"
const MODIFIER_SOURCE_ID_BASE := 100
const TILE_SIZE := 32


func _init() -> void:
	var exit_code := _register_all()
	quit(exit_code)


## Pure planner: which source id does each sprite get?
##   existing — sprite name -> source id already in the tileset (>= base_id)
##   names    — sprite names found on disk
##   base_id  — first id to use when the tileset has none yet
## Every name in `existing` keeps its id. New names are appended above the
## highest id in use (or at base_id), in sorted order so a batch of new
## sprites registers deterministically. Returns:
##   {"ids": {name: id}, "stale": [names registered but no longer on disk]}
## Stale sources are reported, never removed — removing one would orphan any
## cells painted with it; that's a human decision.
static func plan_source_ids(existing: Dictionary, names: Array, base_id: int) -> Dictionary:
	var ids: Dictionary = {}
	var next_id: int = base_id
	for name: Variant in existing:
		var id: int = int(existing[name])
		ids[str(name)] = id
		next_id = maxi(next_id, id + 1)
	var sorted_names: Array = names.duplicate()
	sorted_names.sort()
	for name: Variant in sorted_names:
		var n := str(name)
		if ids.has(n):
			continue
		ids[n] = next_id
		next_id += 1
	var stale: Array = []
	for name: Variant in existing:
		if not names.has(str(name)):
			stale.append(str(name))
	stale.sort()
	return {"ids": ids, "stale": stale}


## Pure: atlas cell of the gameplay footprint inside an exported PNG. The tag
## exporter centers the footprint in a `footprint + 2k` cell canvas, so the
## footprint's north-west cell is the half-overhang offset on each axis.
static func atlas_position_for(tex_size: Vector2i, footprint: Vector2i, tile_size: int) -> Vector2i:
	@warning_ignore("integer_division")
	var cells_x: int = tex_size.x / tile_size
	@warning_ignore("integer_division")
	var cells_y: int = tex_size.y / tile_size
	@warning_ignore("integer_division")
	return Vector2i((cells_x - footprint.x) / 2, (cells_y - footprint.y) / 2)


## Strip ".png" from an exported filename. Pure, so the name<->file contract
## that the drift assert relies on is pinned in one place.
static func sprite_name_from_filename(filename: String) -> String:
	return filename.substr(0, filename.length() - 4)


func _register_all() -> int:
	var tileset: TileSet = load(TILESET_PATH)
	if tileset == null:
		push_error("register_modifier_tiles: cannot load %s" % TILESET_PATH)
		return 1

	var dir := DirAccess.open(SOURCE_DIR)
	if dir == null:
		push_error("register_modifier_tiles: cannot open %s" % SOURCE_DIR)
		return 1

	var names: Array = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".png") and not entry.ends_with("_shadow.png"):
			# The paired _shadow.png is runtime-only, never a tile.
			names.append(sprite_name_from_filename(entry))
		entry = dir.get_next()
	dir.list_dir_end()

	# Existing sprite sources, keyed by resource_name (== sprite name == PNG
	# basename; the tool sets that on every source it mints). Sources below
	# MODIFIER_SOURCE_ID_BASE are the project's autotile/stamp sheets — never
	# touched.
	var existing: Dictionary = {}
	for i in range(tileset.get_source_count()):
		var src_id: int = tileset.get_source_id(i)
		if src_id < MODIFIER_SOURCE_ID_BASE:
			continue
		var src := tileset.get_source(src_id) as TileSetAtlasSource
		if src == null:
			continue
		var name: String = src.resource_name
		if name == "" and src.texture != null:
			name = sprite_name_from_filename(src.texture.resource_path.get_file())
		if name == "":
			push_warning("register_modifier_tiles: source %d has no name and no texture — leaving it alone" % src_id)
			continue
		if existing.has(name):
			push_error("register_modifier_tiles: sprite '%s' is registered twice (ids %d and %d) — fix the tileset by hand" % [
				name, int(existing[name]), src_id])
			return 1
		existing[name] = src_id

	var plan: Dictionary = plan_source_ids(existing, names, MODIFIER_SOURCE_ID_BASE)
	var ids: Dictionary = plan["ids"]
	for stale_name: Variant in plan["stale"]:
		push_warning("register_modifier_tiles: '%s' (id %d) is registered but has no PNG on disk — kept so painted cells don't orphan; delete by hand if it's really gone" % [
			str(stale_name), int(existing[stale_name])])

	var added: int = 0
	var kept: int = 0
	var rebuilt: int = 0
	var changed: bool = false
	names.sort()
	for name: Variant in names:
		var sprite_name := str(name)
		var png_path: String = SOURCE_DIR + sprite_name + ".png"
		var tex: Texture2D = load(png_path)
		if tex == null:
			push_error("register_modifier_tiles: cannot load %s" % png_path)
			return 1
		var footprint: Vector2i = _read_footprint(SOURCE_DIR + sprite_name + ".json")
		var source_id: int = int(ids[sprite_name])
		var is_new: bool = not existing.has(sprite_name)

		var source: TileSetAtlasSource
		if is_new:
			source = TileSetAtlasSource.new()
			source.texture = tex
			source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
			source.resource_name = sprite_name  # the TileSet editor's source label
			# Register FIRST so TileData.set_custom_data can resolve the
			# layer-name lookup through the parent tileset; on a detached
			# source it silently no-ops.
			tileset.add_source(source, source_id)
			changed = true
		else:
			source = tileset.get_source(source_id) as TileSetAtlasSource
			if source.resource_name != sprite_name:
				source.resource_name = sprite_name
				changed = true
			if source.texture == null or source.texture.resource_path != png_path:
				source.texture = tex
				changed = true
			if source.texture_region_size != Vector2i(TILE_SIZE, TILE_SIZE):
				source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
				changed = true

		var atlas_pos: Vector2i = atlas_position_for(Vector2i(tex.get_size()), footprint, TILE_SIZE)
		var outcome: String = _ensure_tile(source, atlas_pos, footprint, sprite_name)
		if outcome != "kept":
			changed = true
		if outcome == "rebuilt":
			rebuilt += 1
		if _apply_tile_config(source, atlas_pos, footprint):
			changed = true

		if is_new:
			added += 1
			print("  Added: %s (footprint %dx%d, id %d)" % [sprite_name, footprint.x, footprint.y, source_id])
		else:
			kept += 1

	# Drift assert: every id that was registered before this run still names
	# the same sprite. If this ever fires the tool has a bug — do NOT save.
	for name: Variant in existing:
		var old_id: int = int(existing[name])
		var src := tileset.get_source(old_id) as TileSetAtlasSource if tileset.has_source(old_id) else null
		if src == null or src.resource_name != str(name):
			push_error("register_modifier_tiles: SOURCE ID DRIFT — id %d was '%s', now '%s'. Refusing to save." % [
				old_id, str(name), src.resource_name if src != null else "<missing>"])
			return 1

	if not changed:
		print("register_modifier_tiles: %d sprites already registered and current, %d stale — tileset untouched" % [
			kept, plan["stale"].size()])
		return 0

	var save_err := ResourceSaver.save(tileset, TILESET_PATH)
	if save_err != OK:
		push_error("register_modifier_tiles: failed to save tileset (err %d)" % save_err)
		return 1
	_restore_uids(TILESET_PATH)
	print("register_modifier_tiles: %d added, %d kept, %d atlas tiles rebuilt, %d stale — saved %s" % [
		added, kept, rebuilt, plan["stale"].size(), TILESET_PATH])
	return 0


## ResourceSaver outside the editor can't look up UIDs (the id readers are
## editor-only), so a headless save drops every `uid="..."` from the .tres.
## Godot copes (it falls back to the path) but every map load then warns
## "invalid UID" until the editor happens to re-save the tileset, and the
## diff is 40 lines of noise hiding the real change. The loader's UID cache
## IS available headless, so put them back.
func _restore_uids(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return
	var restored := restore_uids_in_text(text, path, func(p: String) -> String:
		var id: int = ResourceLoader.get_resource_uid(p)
		return ResourceUID.id_to_text(id) if id != ResourceUID.INVALID_ID else "")
	if restored == text:
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("register_modifier_tiles: saved, but couldn't reopen %s to restore uids" % path)
		return
	f.store_string(restored)
	f.close()


## Pure text transform (see _restore_uids): re-insert `uid="..."` on the
## `[gd_resource ...]` header (the resource's own uid, from `self_path`) and
## on every `[ext_resource ...]` line that lacks one, in Godot's canonical
## attribute order (`type`, `uid`, `path`, `id`). `uid_for_path` maps a
## res:// path to its "uid://..." text, or "" when unknown — unknown paths
## are left alone. Lines that already carry a uid are untouched.
static func restore_uids_in_text(text: String, self_path: String, uid_for_path: Callable) -> String:
	var lines := text.split("\n")
	for i in range(lines.size()):
		var line: String = lines[i]
		if line.contains(" uid=\""):
			continue
		if line.begins_with("[gd_resource "):
			var uid: String = uid_for_path.call(self_path)
			if uid != "":
				lines[i] = line.trim_suffix("]") + " uid=\"%s\"]" % uid
		elif line.begins_with("[ext_resource "):
			var path_start := line.find(" path=\"")
			if path_start < 0:
				continue
			var path_value_start := path_start + " path=\"".length()
			var path_end := line.find("\"", path_value_start)
			if path_end < 0:
				continue
			var res_path := line.substr(path_value_start, path_end - path_value_start)
			var uid: String = uid_for_path.call(res_path)
			if uid == "":
				continue
			lines[i] = line.substr(0, path_start) + " uid=\"%s\"" % uid + line.substr(path_start)
	return "\n".join(lines)


## Footprint in tile cells from the sidecar; 1x1 when absent.
func _read_footprint(sidecar_path: String) -> Vector2i:
	if not FileAccess.file_exists(sidecar_path):
		return Vector2i.ONE
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(sidecar_path))
	if parsed is Dictionary and (parsed as Dictionary).has("footprint"):
		var fp: Array = parsed["footprint"]
		if fp.size() == 2:
			return Vector2i(int(fp[0]), int(fp[1]))
	return Vector2i.ONE


## Make the source's ONLY tile the footprint at `atlas_pos`. Returns "kept"
## when it already was, "created" for a fresh source, "rebuilt" when the
## existing tile(s) had to be replaced — which means the PNG's dimensions
## changed since registration, and every painted cell of this sprite now
## points at atlas coords that may no longer exist. Loud on purpose.
func _ensure_tile(source: TileSetAtlasSource, atlas_pos: Vector2i, footprint: Vector2i,
		sprite_name: String) -> String:
	var count: int = source.get_tiles_count()
	if count == 1:
		var current: Vector2i = source.get_tile_id(0)
		if current == atlas_pos and source.get_tile_size_in_atlas(current) == footprint:
			return "kept"
	if count == 0:
		source.create_tile(atlas_pos, footprint)
		return "created"
	var old_coords: Array[Vector2i] = []
	for i in range(count):
		old_coords.append(source.get_tile_id(i))
	for coords in old_coords:
		source.remove_tile(coords)
	source.create_tile(atlas_pos, footprint)
	push_warning("register_modifier_tiles: '%s' atlas tile moved %s -> %s (footprint %dx%d) — REPAINT every cell of this sprite in every map" % [
		sprite_name, str(old_coords), str(atlas_pos), footprint.x, footprint.y])
	return "rebuilt"


## Per-tile config, idempotent: the is_modifier flag (terrain assignment
## lives in modifier_terrain.json, NOT here) and the editor-preview anchor
## for multi-cell tiles. Godot draws a tile's texture centered on the
## painted cell; our convention is "painted cell = NW corner, expands
## east/south", so shift the editor texture down-right by half a cell per
## extra footprint cell (positive texture_origin moves it up-left, hence the
## negation). Runtime visuals don't use this — TerrainSpriteRenderer places
## its own sprites — it only makes painting look right in the editor.
## Returns true when anything was actually changed.
func _apply_tile_config(source: TileSetAtlasSource, atlas_pos: Vector2i, footprint: Vector2i) -> bool:
	var tile_data: TileData = source.get_tile_data(atlas_pos, 0)
	if tile_data == null:
		return false
	var changed := false
	if tile_data.get_custom_data("is_modifier") != true:
		tile_data.set_custom_data("is_modifier", true)
		changed = true
	var origin := Vector2i.ZERO
	if footprint != Vector2i.ONE:
		@warning_ignore("integer_division")
		origin = -Vector2i(
				(footprint.x - 1) * TILE_SIZE / 2,
				(footprint.y - 1) * TILE_SIZE / 2)
	if tile_data.texture_origin != origin:
		tile_data.texture_origin = origin
		changed = true
	return changed
