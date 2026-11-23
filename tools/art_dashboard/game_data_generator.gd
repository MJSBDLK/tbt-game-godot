## Art dashboard data generator: writes tools/art_dashboard/game_data.js, the
## game-side facts the dashboard page can't read for itself (a page opened
## from disk can load images and scripts, but not JSON). Re-run after changing
## a character JSON, the move bank, a portrait crop or a sidecar:
##   godot-4 --headless --path . -s tools/art_dashboard/game_data_generator.gd
## tests/unit/test_art_dashboard_data.gd fails while the file is stale.
##
## Per character, keyed by JSON file name (never characterId: saves store the
## JSON paths, so file names are the one stable key):
##   requirements  one per box, id = its COLUMNS id, in box order. Each lists the
##                 candidate files that would satisfy it (the path the JSON
##                 declares, the convention paths) and whether the character's
##                 moves need it. The PAGE decides presence by loading the
##                 candidates, so status is always what's on disk right now.
##   clips         per strip: hit frame and frame timing, sidecar first, the
##                 same precedence as ClipPlayer.resolve_playback.
##   crop          the portrait crop's region on its line art.
##   class         the class it plays as today (currentClass, as a class id).
##   tree          its promotion tree from data/classes/trees/<id>.json, cut
##                 to each slot's class and art (tree_entry).
##   moveset       only when the class it starts as (its tree's base) has a
##                 locked schedule: moveset_entry. The schedule then decides
##                 which boxes its moves need, in place of its JSON's
##                 placeholder move pool.
##   variants      one per class its tree promotes into: the same character
##                 redrawn for that class, with its own full set of boxes
##                 under the file stem <id>_<class>. Moves don't change with
##                 class, so a variant needs what the base needs. Nothing in
##                 the game loads variants yet, so only convention paths count
##                 and none is "declared".
##
## `classes` is the class pool, data/classes/pool/ (ClassTrees): id, name, tier.
## `designs` are trees with no character JSON yet: id, its base class's name,
## the tree and its notes, so the board's Class trees panel can show them. A
## tree or schedule edit makes this file stale, like any other.
##
## Needs mirror UnitAnimationResolver: two reaches (1 tile = melee, 2+ =
## ranged), every attack can hit from 1 tile (targeting is distance <= range),
## Support moves are casts, an animationStyle tag forces the reach. Passives
## that add range are listed in RANGE_PASSIVES.
extends SceneTree


const CHARACTERS_DIRECTORY: String = "res://data/characters/"
const MOVE_BANK_PATH: String = "res://data/moves/basic_move_bank.json"
const PASSIVES_PATH: String = "res://data/passives.json"
## A schedule can name designs the game doesn't have yet; their rows here say
## what they do and, for a move, which clip it will play.
const DESIGN_DOC_PATH: String = "res://data/design/moves-and-passives.md"
## Read as text: the handler scripts need autoloads a headless -s run lacks.
const PASSIVE_REGISTRY_PATH: String = "res://scripts/combat/passive_registry.gd"
const OUTPUT_PATH: String = "res://tools/art_dashboard/game_data.js"
const SPRITE_DIRECTORY: String = "res://art/sprites/characters/"
const LINEART_DIRECTORY: String = "res://art/lineart_fullres/"
## Stands in for an undrawn idle; counts as no idle at all.
const PLACEHOLDER_SPRITE: String = "res://art/sprites/characters/placeholder_unit.png"
## Lawrence numbers a character's idles: idle0 is the default loop, idle1+
## are fidgets nothing plays yet. A plain "idle" tag predates the numbering
## and still counts, so it's never on the rename list.
const IDLE_TAG: String = "idle0"
const UNNUMBERED_IDLE_TAG: String = "idle"

## Passive name → the damage type whose range it extends. Any bonus puts a
## 1-tile move at 2, so only the type matters. The data test fails when a
## passive script gains extra_attack_range without an entry here.
const RANGE_PASSIVES: Dictionary = {
	"Extendo": {"script": "res://scripts/combat/passives/extendo_passive.gd", "damage_type": "Physical"},
}

## The board's boxes, in order. `tier` is the color the box is needed for
## ("extra": shown, never counted); `fallback` is what the game shows while
## it's missing; `min_frames` > 1 means a still doesn't count; `contact`: its
## clip plays to a hit frame (ClipPlayer), so it wants Lawrence's `hit` tag.
const COLUMNS: Array[Dictionary] = [
	{"id": "idle", "label": "Idle", "tier": "orange", "fallback": "nothing: the unit can't appear"},
	{"id": "idle_animation", "label": "Idle anim", "tier": "orange", "fallback": "the still frame", "min_frames": 2},
	{"id": "line_art", "label": "Line art", "tier": "orange", "fallback": "a crop of the sprite's head"},
	{"id": "melee", "label": "Melee", "tier": "yellow", "fallback": "its ranged clip, else a nudge", "contact": true},
	{"id": "ranged", "label": "Ranged", "tier": "yellow", "fallback": "its melee clip, else a nudge", "contact": true},
	{"id": "melee_physical", "label": "Melee phys", "tier": "green", "fallback": "the plain melee clip", "contact": true},
	{"id": "melee_special", "label": "Melee spec", "tier": "green", "fallback": "the plain melee clip", "contact": true},
	{"id": "ranged_physical", "label": "Ranged phys", "tier": "green", "fallback": "the plain ranged clip", "contact": true},
	{"id": "ranged_special", "label": "Ranged spec", "tier": "green", "fallback": "the plain ranged clip", "contact": true},
	{"id": "cast", "label": "Cast", "tier": "green", "fallback": "its melee clip, then ranged", "contact": true},
	{"id": "hurt", "label": "Hurt", "tier": "green", "fallback": "a code-drawn flash or fade"},
	{"id": "dodge", "label": "Dodge", "tier": "green", "fallback": "a code-drawn flash or fade"},
	{"id": "death", "label": "Death", "tier": "green", "fallback": "a code-drawn flash or fade"},
	{"id": "crit_melee", "label": "Crit melee", "tier": "extra", "fallback": "the normal clip: nothing plays crits yet", "contact": true},
	{"id": "crit_ranged", "label": "Crit ranged", "tier": "extra", "fallback": "the normal clip: nothing plays crits yet", "contact": true},
]

const HEADER: String = "// Generated by tools/art_dashboard/game_data_generator.gd. Don't edit;\n// re-run: godot-4 --headless --path . -s tools/art_dashboard/game_data_generator.gd\n"


func _initialize() -> void:
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Can't write %s" % OUTPUT_PATH)
		quit(1)
		return
	file.store_string(render(build_data()))
	file.close()
	print("Wrote %s" % OUTPUT_PATH)
	quit(0)


static func render(data: Dictionary) -> String:
	return HEADER + "window.ART_DASHBOARD_DATA = " + JSON.stringify(data, "\t", true) + ";\n"


static func build_data() -> Dictionary:
	var design := read_design_doc(FileAccess.get_file_as_string(DESIGN_DOC_PATH))
	var moves: Dictionary = design.moves
	moves.merge(read_json(MOVE_BANK_PATH), true)  # the bank wins over a design row
	var passives := passive_catalog(read_json(PASSIVES_PATH), design.passives, coded_passives())
	var unit_trees := ClassTrees.trees()
	var class_pool := ClassTrees.pool()
	var schedules: Dictionary = {}
	for class_id: String in class_pool:
		if class_pool[class_id].has("schedule"):
			schedules[class_id] = moveset_entry(class_id, class_pool[class_id].schedule, moves, passives)
	var characters: Array[Dictionary] = []
	for path: String in character_files():
		var character: Dictionary = read_json(path)
		var character_id := path.get_file().get_basename()
		if not character.is_empty():
			characters.append(character_entry(character_id, character, moves,
					unit_trees.get(character_id, {}), schedules))
	# `convention` tells the page where each box's file goes ({id} = character).
	var columns: Array[Dictionary] = []
	for column: Dictionary in COLUMNS:
		var entry := column.duplicate()
		entry["convention"] = convention_path(column.id, "{id}").trim_prefix("res://")
		columns.append(entry)
	var character_ids := characters.map(func(entry: Dictionary) -> String: return entry.id)
	for entry: Dictionary in characters:
		for variant: Dictionary in entry.variants:
			if character_ids.has(variant.id):
				push_error("Art dashboard: %s's %s variant shares its files with the character %s" % [
						entry.id, variant["class"], variant.id])
	return {"columns": columns, "classes": class_entries(class_pool), "characters": characters,
			"designs": design_entries(unit_trees, character_ids, class_pool)}


## Trees whose unit has no character JSON yet, by id.
static func design_entries(unit_trees: Dictionary, character_ids: Array, class_pool: Dictionary) -> Array[Dictionary]:
	var ids := unit_trees.keys().filter(func(id: String) -> bool: return not character_ids.has(id))
	ids.sort()
	var entries: Array[Dictionary] = []
	for id: String in ids:
		var tree: Dictionary = unit_trees[id]
		var base := str(tree.get("base", ""))
		entries.append({"id": id, "name": str(class_pool.get(base, {}).get("name", id)),
				"tree": tree_entry(tree, ""), "notes": str(tree.get("notes", ""))})
	return entries


## Every pool class, by id.
static func class_entries(class_pool: Dictionary) -> Array[Dictionary]:
	var ids := class_pool.keys()
	ids.sort()
	var entries: Array[Dictionary] = []
	for id: String in ids:
		entries.append({"id": id, "name": str(class_pool[id].name), "tier": int(class_pool[id].tier)})
	return entries


## currentClass the way CharacterDataLoader reads it: "Void Knight" → void_knight.
static func character_class_id(character: Dictionary) -> String:
	var id := str(character.get("currentClass", "Spaceman")).to_lower().replace(" ", "_")
	if not Enums.CharacterClass.has(id.to_upper()):
		push_error("Art dashboard: no class '%s' in Enums.CharacterClass" % id)
	return id


## A unit's tree file (data/classes/README.md) as the board draws it: each
## slot's class ("" = not designed) and how its art gets made. A draft is an
## empty slot here, as it is to the game. No tree file: the class it plays as
## today, nothing designed under it.
static func tree_entry(unit_tree: Dictionary, current_class: String) -> Dictionary:
	if unit_tree.is_empty():
		return {"class": current_class, "promotions": []}
	return {"class": str(unit_tree.get("base", "")), "promotions": (unit_tree.get("promotions", []) as Array).map(
			func(slot: Dictionary) -> Dictionary: return slot_entry(slot))}


static func slot_entry(slot: Dictionary) -> Dictionary:
	var entry := {"class": str(slot.get("class", "")), "art": str(slot.get("art", ""))}
	if slot.has("promotions"):
		entry["promotions"] = (slot.promotions as Array).map(
				func(child: Dictionary) -> Dictionary: return slot_entry(child))
	return entry


## The classes a tree promotes into, each once (a tier-3 class under both
## branches is one variant), tier 2 first. Nothing under an undesigned slot
## counts: no unit can promote through it.
static func tree_promotions(tree: Dictionary) -> Array[String]:
	var found: Array[String] = []
	var frontier: Array = tree.promotions.duplicate()
	while not frontier.is_empty():
		var slot: Dictionary = frontier.pop_front()
		var promotion := str(slot["class"])
		if promotion.is_empty():
			continue
		if not found.has(promotion):
			found.append(promotion)
		frontier.append_array(slot.get("promotions", []))
	return found


## `schedules`: class id → moveset_entry, for the classes that have one.
static func character_entry(character_id: String, character: Dictionary, move_bank: Dictionary,
		unit_tree: Dictionary = {}, schedules: Dictionary = {}) -> Dictionary:
	var result := {
		"id": character_id,
		"name": str(character.get("characterName", character_id)),
		"class": character_class_id(character),
	}
	result["tree"] = tree_entry(unit_tree, result["class"])
	var move_names: Array = character.get("basePoolMoves", [])
	var passive_names: Array = character.get("basePoolPassives", [])
	var moveset: Dictionary = schedules.get(result.tree["class"], {})
	if not moveset.is_empty():
		result["moveset"] = moveset
		move_names = moveset.moves.map(func(move: Dictionary) -> String: return move.name)
		passive_names = moveset.passives.map(func(passive: Dictionary) -> String: return passive.name)
	var kit := kit_for(move_names, passive_names, move_bank)
	result.merge(art_entry(character_id, character, kit))
	# Only the moves carry over: every file a variant has is its own.
	var variants: Array[Dictionary] = []
	for promotion: String in tree_promotions(result["tree"]):
		var variant := {"class": promotion}
		variant.merge(art_entry(character_id + "_" + promotion, {}, kit))
		variants.append(variant)
	result["variants"] = variants
	return result


## The boxes for one set of art (a character, or one of its class variants);
## `kit` (kit_for) says which clips its moves play.
static func art_entry(character_id: String, character: Dictionary, kit: Dictionary) -> Dictionary:
	var declared_clips: Dictionary = {}
	var animations: Dictionary = character.get("animations", {})
	for key: Variant in animations:
		declared_clips[str(key).to_lower()] = str(animations[key].get("path", ""))

	var sprite_path := str(character.get("sprite", {}).get("sheetPath", ""))
	if sprite_path == PLACEHOLDER_SPRITE:
		sprite_path = ""
	var idle_candidates := candidates_for(sprite_path, [convention_path("idle", character_id),
			SPRITE_DIRECTORY + character_id + "/" + UNNUMBERED_IDLE_TAG + ".png"])
	var lineart_candidates := candidates_for(str(character.get("lineartPath", "")),
			[convention_path("line_art", character_id)])

	var requirements: Array[Dictionary] = [
		requirement("idle", true, idle_candidates),
		requirement("idle_animation", true, idle_candidates),
		requirement("line_art", true, lineart_candidates),
	]
	for reach: String in ["melee", "ranged"]:
		requirements.append(requirement(reach, kit.reaches.has(reach),
				clip_candidates(character_id, [reach, reach + "_physical", reach + "_special"], declared_clips)))
	# A plain reach clip covers both kinds, so it stands in for a kind's own
	# clip: the box counts, and says whose clip it's showing.
	for reach: String in ["melee", "ranged"]:
		for kind: String in ["physical", "special"]:
			var pair := reach + "_" + kind
			requirements.append(requirement(pair, kit.pairs.has(pair),
					clip_candidates(character_id, [pair, reach], declared_clips)))
	requirements.append(requirement("cast", kit.casts,
			clip_candidates(character_id, ["cast"], declared_clips)))
	for reaction: String in ["hurt", "dodge", "death"]:
		requirements.append(requirement(reaction, true,
				clip_candidates(character_id, [reaction], declared_clips)))
	for reach: String in ["melee", "ranged"]:
		requirements.append(requirement("crit_" + reach, kit.reaches.has(reach),
				clip_candidates(character_id, ["crit_" + reach], declared_clips)))

	var clips: Dictionary = {}
	for entry: Dictionary in requirements:
		for candidate: Dictionary in entry.candidates:
			if entry.id == "line_art" or clips.has(candidate.path):
				continue
			var timing := clip_timing("res://" + candidate.path, animations)
			if not timing.is_empty():
				clips[candidate.path] = timing

	var result := {"id": character_id, "requirements": requirements, "clips": clips}
	var crop := portrait_crop(character, character_id)
	if not crop.is_empty():
		result["crop"] = crop
	return result


## Which reaches, reach × kind pairs and casts a set of moves uses.
static func kit_for(move_names: Array, passive_names: Array, move_bank: Dictionary) -> Dictionary:
	var extended := extended_types(passive_names)
	var reaches: Dictionary = {}
	var pairs: Dictionary = {}
	var casts := false
	for move_name: Variant in move_names:
		var move: Dictionary = move_bank.get(move_name, {})
		if move.is_empty():
			push_error("Art dashboard: move '%s' is in neither the move bank nor %s" % [move_name, DESIGN_DOC_PATH])
			continue
		var kind := "special" if str(move.get("damageType", "")) == "Special" else "physical"
		for clip: String in move_clips(move, extended):
			if clip == "cast":
				casts = true
			else:
				reaches[clip] = true
				pairs[clip + "_" + kind] = true
	return {"reaches": reaches, "pairs": pairs, "casts": casts}


## The clips one move plays: cast for a Support move; else the reaches it
## attacks from. [] for a move nothing describes.
static func move_clips(move: Dictionary, extended: Array[String]) -> Array[String]:
	if move.is_empty():
		return []
	var damage_type := str(move.get("damageType", ""))
	if damage_type == "Support":
		return ["cast"]
	var style := str(move.get("animationStyle", "")).to_lower()
	if style == "melee" or style == "ranged":
		return [style]
	var attack_range := int(move.get("range", 1)) + (1 if extended.has(damage_type) else 0)
	if attack_range >= 2:
		return ["melee", "ranged"]
	return ["melee"]


## The damage types whose range the passives extend (RANGE_PASSIVES).
static func extended_types(passive_names: Array) -> Array[String]:
	var types: Array[String] = []
	for passive_name: Variant in passive_names:
		if RANGE_PASSIVES.has(passive_name):
			types.append(RANGE_PASSIVES[passive_name].damage_type)
	return types


## A class schedule (data/classes/README.md) as the board lists it: moves,
## then passives, each in learning order with the kit first. A move's `clip`
## is the box it plays (melee, ranged, cast; "" when nothing says); a range-2
## move is "ranged" though it plays melee up close. `built`: the game has it.
static func moveset_entry(class_id: String, schedule: Dictionary, moves: Dictionary,
		passives: Dictionary) -> Dictionary:
	var kit: Dictionary = schedule.get("kit", {})
	var kit_moves: Array = kit.get("moves", [])
	var kit_passives: Array = kit.get("passives", [])
	var passive_names: Array = kit_passives + schedule.get("passives", [])
	var extended := extended_types(passive_names)
	var move_entries: Array[Dictionary] = []
	for move_name: String in kit_moves + schedule.get("moves", []):
		var move: Dictionary = moves.get(move_name, {})
		if move.is_empty():
			push_error("Art dashboard: %s's schedule teaches '%s', which is in neither the move bank nor %s" % [
					class_id, move_name, DESIGN_DOC_PATH])
		var clips := move_clips(move, extended)
		move_entries.append({
			"name": move_name, "kit": kit_moves.has(move_name),
			"built": not move.is_empty() and not move.get("designed", false),
			"clip": "" if clips.is_empty() else ("ranged" if clips.has("ranged") else clips[0]),
			"special": str(move.get("damageType", "")) == "Special",
			"description": str(move.get("description", "")),
		})
	var passive_entries: Array[Dictionary] = []
	for passive_name: String in passive_names:
		var passive: Dictionary = passives.get(passive_name, {})
		if passive.is_empty():
			push_error("Art dashboard: %s's schedule teaches the passive '%s', which is in neither %s nor %s" % [
					class_id, passive_name, PASSIVES_PATH, DESIGN_DOC_PATH])
		passive_entries.append({"name": passive_name, "kit": kit_passives.has(passive_name),
				"built": passive.get("built", false), "description": str(passive.get("description", ""))})
	return {"moves": move_entries, "passives": passive_entries}


## The design doc's rows ("Reading a row" in DESIGN_DOC_PATH) as move-bank-
## shaped moves marked `designed`, and passive name → description. A move
## row's kind is its heading's (`### Gentry/Special`), or Support when the row
## opens with it; its range is its `rN`, else 1. A row that's only a name
## says nothing and is skipped; an indented line continues the row above.
static func read_design_doc(text: String) -> Dictionary:
	var rows: Array[Dictionary] = []
	var row: Dictionary = {}  # the row an indented line would continue
	var part := ""
	var kind := ""
	for line: String in text.split("\n"):
		if line.begins_with("  ") and not row.is_empty() and not line.strip_edges().is_empty():
			row.text += " " + line.strip_edges()
			continue
		row = {}
		if line.begins_with("## "):
			part = line.trim_prefix("## ").strip_edges()
		elif line.begins_with("### "):
			kind = line.get_slice("/", 1).strip_edges()
		elif line.begins_with("+ ") and line.contains(" — "):
			row = {"part": part, "kind": kind, "name": line.trim_prefix("+ ").get_slice(" — ", 0),
					"text": line.substr(line.find(" — ") + 3)}
			rows.append(row)
	var range_pattern := RegEx.create_from_string("\\br(\\d+)\\b")
	var moves: Dictionary = {}
	var passives: Dictionary = {}
	for entry: Dictionary in rows:
		if entry.part == "Moves":
			var found := range_pattern.search(entry.text)
			moves[entry.name] = {"designed": true, "description": entry.text,
					"damageType": "Support" if entry.text.begins_with("Support") else entry.kind,
					"range": int(found.get_string(1)) if found else 1}
		elif entry.part == "Passives":
			passives[entry.name] = entry.text
	return {"moves": moves, "passives": passives}


## Every passive a schedule can name, by name: {description, built}. Built =
## PassiveRegistry has a handler; passives.json's description wins over the
## design doc's.
static func passive_catalog(passive_data: Dictionary, designed: Dictionary, coded: Array[String]) -> Dictionary:
	var catalog: Dictionary = {}
	for passive_name: String in designed:
		catalog[passive_name] = {"description": designed[passive_name], "built": coded.has(passive_name)}
	for passive_name: String in passive_data:
		catalog[passive_name] = {"description": str(passive_data[passive_name].get("description", "")),
				"built": coded.has(passive_name)}
	return catalog


## The passive names PassiveRegistry registers a handler for.
static func coded_passives() -> Array[String]:
	var names: Array[String] = []
	var source := FileAccess.get_file_as_string(PASSIVE_REGISTRY_PATH)
	for found: RegExMatch in RegEx.create_from_string('_handlers\\["([^"]+)"\\] =').search_all(source):
		names.append(found.get_string(1))
	return names


## Tier and min_frames come from the box's COLUMNS entry: one home each.
static func requirement(id: String, needed: bool, candidates: Array[Dictionary]) -> Dictionary:
	var column := column_for(id)
	var entry := {"id": id, "tier": column.tier, "needed": needed, "candidates": candidates}
	if column.has("min_frames"):
		entry["min_frames"] = column.min_frames
	return entry


static func column_for(id: String) -> Dictionary:
	for column: Dictionary in COLUMNS:
		if column.id == id:
			return column
	assert(false, "Art dashboard: no COLUMNS entry for box '%s'" % id)
	return {}


## Where a box's file goes. Sprites: the tag exporter writes tag <tag> of
## <character>.aseprite to <character>/<tag>.png, so the path names both.
static func convention_path(box_id: String, character_id: String) -> String:
	if box_id == "line_art":
		return LINEART_DIRECTORY + character_id + ".png"
	var tag := IDLE_TAG if box_id == "idle" or box_id == "idle_animation" else box_id
	return SPRITE_DIRECTORY + character_id + "/" + tag + ".png"


## Each candidate carries `clip`, the vocabulary key it is; the page calls a
## candidate whose clip isn't the box's own a stand-in.
static func clip_candidates(character_id: String, keys: Array, declared_clips: Dictionary) -> Array[Dictionary]:
	var merged: Array[Dictionary] = []
	for key: String in keys:
		for candidate: Dictionary in candidates_for(str(declared_clips.get(key, "")),
				[convention_path(key, character_id)]):
			candidate["clip"] = key
			var existing := merged.filter(func(other: Dictionary) -> bool: return other.path == candidate.path)
			if existing.is_empty():
				merged.append(candidate)
			else:
				existing[0].declared = existing[0].declared or candidate.declared
				existing[0].convention = existing[0].convention or candidate.convention
	return merged


## The declared path (what the game loads) first, then the convention paths,
## preferred first. Paths are repo-relative so the page can prefix its way to
## the repo root. A declared path off every convention carries `rename_to`
## (the preferred one): the board's rename list.
static func candidates_for(declared_path: String, convention_paths: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not declared_path.is_empty() and not convention_paths.has(declared_path):
		result.append({"path": declared_path.trim_prefix("res://"), "declared": true,
				"convention": false, "rename_to": convention_paths[0].trim_prefix("res://")})
	for path: String in convention_paths:
		result.append({"path": path.trim_prefix("res://"), "declared": path == declared_path, "convention": true})
	return result


## Hit frame, frame durations, fps and (idle) art bounds for a strip. Sidecar
## values win over the JSON entry, as in ClipPlayer; {} when neither exists.
## `hit_marker`: the hit frame is Lawrence's `hit` tag (only the exporter
## writes one into a sidecar), not a frame picked by eye in the JSON.
static func clip_timing(strip_path: String, animations: Dictionary) -> Dictionary:
	var timing: Dictionary = {}
	for key: Variant in animations:
		var entry: Dictionary = animations[key]
		if str(entry.get("path", "")) != strip_path:
			continue
		if entry.has("hit_frame"):
			timing["hit_frame"] = int(entry.hit_frame)
		if entry.has("fps"):
			timing["fps"] = int(entry.fps)
	var sidecar := read_json(strip_path.trim_suffix(".png") + ".json", false)
	if sidecar.has("hit_frame"):
		timing["hit_frame"] = int(sidecar.hit_frame)
		timing["hit_marker"] = true
	if sidecar.has("frame_durations_ms"):
		timing["frame_durations_ms"] = (sidecar.frame_durations_ms as Array).map(
				func(milliseconds: Variant) -> int: return int(milliseconds))
	if sidecar.has("art_bounds"):
		var bounds: Dictionary = sidecar.art_bounds
		timing["art_bounds"] = {"left": int(bounds.left), "top": int(bounds.top),
				"right": int(bounds.right), "bottom": int(bounds.bottom)}
	return timing


## The portrait crop's atlas path and region, read from the .tres text so a
## checkout that was never imported still works. {} when there's no crop.
static func portrait_crop(character: Dictionary, character_id: String) -> Dictionary:
	var crop_path := str(character.get("lineartAtlases", {}).get("portrait", ""))
	if crop_path.is_empty():
		crop_path = LINEART_DIRECTORY + character_id + "_portrait.tres"
	if not FileAccess.file_exists(crop_path):
		return {}
	var text := FileAccess.get_file_as_string(crop_path)
	var atlas := RegEx.create_from_string('ext_resource type="Texture2D"[^\\n]*path="([^"]+)"').search(text)
	var region := RegEx.create_from_string("region = Rect2\\(([-\\d.]+), ([-\\d.]+), ([-\\d.]+), ([-\\d.]+)\\)").search(text)
	if atlas == null or region == null:
		push_error("Art dashboard: can't read the crop in %s" % crop_path)
		return {}
	return {
		"atlas": atlas.get_string(1).trim_prefix("res://"),
		"x": int(float(region.get_string(1))), "y": int(float(region.get_string(2))),
		"width": int(float(region.get_string(3))), "height": int(float(region.get_string(4))),
	}


static func character_files() -> Array[String]:
	var files: Array[String] = []
	for file_name: String in DirAccess.get_files_at(CHARACTERS_DIRECTORY):
		if file_name.ends_with(".json"):
			files.append(CHARACTERS_DIRECTORY + file_name)
	files.sort()
	return files


static func read_json(path: String, required: bool = true) -> Dictionary:
	if not FileAccess.file_exists(path):
		if required:
			push_error("Art dashboard: missing %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("Art dashboard: %s isn't a JSON object" % path)
	return {}
