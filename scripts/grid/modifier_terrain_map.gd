## Maps modifier SPRITES to terrain types — the join between art (sprite
## names) and gameplay rules (terrain_data.json). Loaded from
## data/modifier_terrain.json.
##
## This is deliberately a separate system from terrain_data.json. See
## data/design/terrain_modifiers_and_decorations.md, "Architecture: terrain
## across three systems", for why. In one line: terrain_data.json says what a
## terrain DOES (many sprites share one terrain); this says which terrain each
## CELL of a sprite IS (per-sprite, per-cell). Two different shapes, two
## different edit cadences.
##
## Static + cached: callable from the build path and from GUT without an
## autoload registration.
class_name ModifierTerrainMap
extends RefCounted


const DATA_PATH := "res://data/modifier_terrain.json"

## How a multi-row modifier sorts against units standing on its body.
##   "interleave" (default): each footprint row sorts at its own depth, so a
##                unit on a back row draws over the rows behind it and behind
##                the rows in front of it (correct 2.5D depth).
##   "solid":     the whole sprite sorts at its southernmost row, so any unit
##                on a covered row reads as standing behind/inside it.
## Only affects sprites with footprint height > 1; 1x1 sprites render the same
## either way. See data/design/terrain_modifiers_and_decorations.md.
const OCCLUDE_INTERLEAVE := "interleave"
const OCCLUDE_SOLID := "solid"
const DEFAULT_OCCLUDE_MODE := OCCLUDE_INTERLEAVE

static var _by_prefix: Dictionary = {}
static var _by_sprite: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(DATA_PATH):
		push_error("ModifierTerrainMap: missing %s" % DATA_PATH)
		return
	var raw := FileAccess.get_file_as_string(DATA_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		push_error("ModifierTerrainMap: %s is not a JSON object" % DATA_PATH)
		return
	load_from_dictionary(parsed)


## Replace the live tables with `data` (the modifier_terrain.json shape:
## {"by_prefix": {...}, "by_sprite": {...}}). Public so tests can stage a
## sprite that doesn't exist on disk and any future hot-reload can push a
## fresh parse in; `reload()` restores the file.
static func load_from_dictionary(data: Dictionary) -> void:
	_loaded = true
	_by_prefix = data["by_prefix"] if data.get("by_prefix") is Dictionary else {}
	_by_sprite = data["by_sprite"] if data.get("by_sprite") is Dictionary else {}


## Force a reload from disk — for tests and any future hot-reload.
static func reload() -> void:
	_loaded = false
	_by_prefix = {}
	_by_sprite = {}
	_ensure_loaded()


## Terrain type for one cell of a sprite. `cell_offset` is (dx, dy) from the
## sprite's anchor (north-west) cell; dy indexes rows north->south. Returns
## "" if the sprite has no mapping (pure decoration / unknown).
static func resolve(sprite_name: String, cell_offset: Vector2i) -> String:
	_ensure_loaded()
	if _by_sprite.has(sprite_name):
		var entry: Dictionary = _by_sprite[sprite_name]
		# Full per-cell control: cells[row][col].
		if entry.has("cells"):
			var cells: Array = entry["cells"]
			if cell_offset.y >= 0 and cell_offset.y < cells.size():
				var row: Array = cells[cell_offset.y]
				if cell_offset.x >= 0 and cell_offset.x < row.size():
					return str(row[cell_offset.x])
		# Whole-row terrain: rows[row].
		if entry.has("rows"):
			var rows: Array = entry["rows"]
			if cell_offset.y >= 0 and cell_offset.y < rows.size():
				return str(rows[cell_offset.y])
	# Fall back to the bulk prefix default (also covers cells a sparse
	# by_sprite entry didn't enumerate).
	return _prefix_match(sprite_name)


## Longest matching prefix wins so specific names ("firetopradish") aren't
## shadowed by shorter ones ("fire"). Returns "" if nothing matches.
static func _prefix_match(sprite_name: String) -> String:
	_ensure_loaded()
	var best := ""
	var best_len := -1
	for prefix: Variant in _by_prefix:
		var p := str(prefix)
		if sprite_name.begins_with(p) and p.length() > best_len:
			best = str(_by_prefix[p])
			best_len = p.length()
	return best


## Render-hint lookup. The exact by_sprite entry wins when it carries the
## key; otherwise the longest matching WILDCARD entry — a by_sprite key
## ending in "*" (e.g. "piperoot_*") — so a whole family can be flagged in
## one line. Wildcard entries carry render hints ONLY; terrain never
## resolves through them (that's what by_prefix is for). Returns null when
## nothing sets the key.
static func _render_hint(sprite_name: String, key: String) -> Variant:
	_ensure_loaded()
	if _by_sprite.has(sprite_name):
		var exact: Dictionary = _by_sprite[sprite_name]
		if exact.has(key):
			return exact[key]
	var best: Variant = null
	var best_len := -1
	for raw_key: Variant in _by_sprite:
		var k := str(raw_key)
		if not k.ends_with("*"):
			continue
		var prefix := k.substr(0, k.length() - 1)
		if sprite_name.begins_with(prefix) and prefix.length() > best_len:
			var entry: Dictionary = _by_sprite[k]
			if entry.has(key):
				best = entry[key]
				best_len = prefix.length()
	return best


## Render-time occlusion mode for a sprite (see the OCCLUDE_* constants).
## Per-sprite via by_sprite[name].occlude (or a wildcard entry); defaults to
## interleave. Any value other than "solid" is treated as interleave so a
## typo fails safe to the correct-depth default rather than the legacy
## block-occlude behavior.
static func occlude_mode(sprite_name: String) -> String:
	var hint: Variant = _render_hint(sprite_name, "occlude")
	if hint != null and str(hint) == OCCLUDE_SOLID:
		return OCCLUDE_SOLID
	return DEFAULT_OCCLUDE_MODE


## True if this sprite has any terrain mapping (i.e. is a gameplay modifier
## rather than a pure decoration). A by_sprite entry only counts when it
## carries terrain (`rows`/`cells`); render-only entries (`occlude`,
## `casts_shadow`) on an unprefixed name leave it a pure decoration.
static func is_modifier(sprite_name: String) -> bool:
	_ensure_loaded()
	if _by_sprite.has(sprite_name):
		var entry: Dictionary = _by_sprite[sprite_name]
		if entry.has("rows") or entry.has("cells"):
			return true
	return _prefix_match(sprite_name) != ""


## Render hint: does this sprite cast a shadow at all? Default true. `false`
## means NO shadow of any kind — the authored `_shadow.png` is skipped and
## nothing is generated — for floor elements (craters, bridges, anything
## lying flat: a hole casts nothing). Set via by_sprite[name].casts_shadow
## or a wildcard entry ("piperoot_*"). Read by TerrainSpriteRenderer.
static func casts_shadow(sprite_name: String) -> bool:
	var hint: Variant = _render_hint(sprite_name, "casts_shadow")
	if hint == null:
		return true
	return bool(hint)
