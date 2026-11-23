## The art dashboard's generated data stays true to the game: the committed
## game_data.js matches a fresh generation, needs follow the resolver's reach
## and kind rules, and every strip splits into square frames (the page counts
## frames as width ÷ height, live, so a fresh export needs no regeneration).
extends GutTest


const Generator = preload("res://tools/art_dashboard/game_data_generator.gd")
const PASSIVES_DIRECTORY: String = "res://scripts/combat/passives/"

const MOVE_BANK: Dictionary = {
	"Jab": {"damageType": "Physical", "range": 1},
	"Zap": {"damageType": "Special", "range": 2},
	"Mend": {"damageType": "Support", "range": 1},
	"Lob": {"damageType": "Physical", "range": 3, "animationStyle": "melee"},
}


func test_generated_file_is_fresh() -> void:
	var on_disk := FileAccess.get_file_as_string(Generator.OUTPUT_PATH)
	assert_eq(on_disk, Generator.render(Generator.build_data()),
			"game_data.js is stale: run godot-4 --headless --path . -s tools/art_dashboard/game_data_generator.gd")


func test_every_attack_needs_melee_and_range_two_adds_ranged() -> void:
	var kit := Generator.kit_for(["Jab", "Zap"], [], MOVE_BANK)
	assert_eq(kit.reaches.keys(), ["melee", "ranged"])
	assert_true(kit.pairs.has("melee_special"), "a range-2 move still hits from 1 tile")
	assert_true(kit.pairs.has("ranged_special"))
	assert_false(kit.pairs.has("ranged_physical"), "Jab never reaches 2 tiles")
	assert_false(kit.casts)


func test_support_moves_are_casts_not_attacks() -> void:
	var kit := Generator.kit_for(["Mend"], [], MOVE_BANK)
	assert_true(kit.casts)
	assert_true(kit.reaches.is_empty())


func test_animation_style_forces_the_reach() -> void:
	var kit := Generator.kit_for(["Lob"], [], MOVE_BANK)
	assert_eq(kit.reaches.keys(), ["melee"], "a melee-tagged range-3 move never plays a ranged clip")


func test_extendo_pushes_physical_moves_to_ranged() -> void:
	var kit := Generator.kit_for(["Jab", "Zap"], ["Extendo"], MOVE_BANK)
	assert_true(kit.pairs.has("ranged_physical"))


func test_range_passives_table_covers_every_range_passive() -> void:
	var listed: Array = Generator.RANGE_PASSIVES.values().map(
			func(entry: Dictionary) -> String: return entry.script)
	for file_name: String in DirAccess.get_files_at(PASSIVES_DIRECTORY):
		if not file_name.ends_with(".gd"):
			continue
		var path := PASSIVES_DIRECTORY + file_name
		if FileAccess.get_file_as_string(path).contains("func extra_attack_range"):
			assert_has(listed, path, "%s adds range: list it in RANGE_PASSIVES" % file_name)


func test_design_doc_rows_give_a_move_s_kind_range_and_description() -> void:
	var design := Generator.read_design_doc("\n".join([
		"## Moves", "### Gentry/Physical",
		"+ Epée — p6 r1 acc90, a rapier.",
		"+ Flourish",
		"+ Ice Pick — p7, ignores defense.",
		"### Gentry/Special",
		"+ Extort — p5 r2 acc90, a flip of the fingers.",
		"+ Favor — Support r2 ally: gives",
		"  the user's buff away.",
		"## Passives", "### Wanted",
		"+ Studied — hits on a weakness",
		"  can't miss.",
	]))
	assert_eq(design.moves.keys(), ["Epée", "Ice Pick", "Extort", "Favor"], "a bare name says nothing")
	assert_eq(design.moves["Epée"].damageType, "Physical", "the heading's kind")
	assert_eq(design.moves["Ice Pick"].range, 1, "no rN: range 1")
	assert_eq(design.moves["Extort"].damageType, "Special")
	assert_eq(design.moves["Extort"].range, 2)
	assert_eq(design.moves["Favor"].damageType, "Support", "the row opens with Support")
	assert_eq(design.moves["Favor"].description, "Support r2 ally: gives the user's buff away.", "an indented line continues")
	assert_true(design.moves["Favor"].designed)
	assert_eq(design.passives, {"Studied": "hits on a weakness can't miss."})


func test_a_moveset_lists_the_kit_first_with_the_box_each_move_plays() -> void:
	var moves := MOVE_BANK.duplicate()
	moves["Wish"] = {"damageType": "Special", "range": 1, "designed": true, "description": "a wish"}
	var passives := {"Extendo": {"description": "longer reach", "built": true}}
	var schedule := {"kit": {"moves": ["Zap", "Jab"], "passives": ["Extendo"]}, "moves": ["Mend", "Lob", "Wish"],
			"passives": ["Daydream"]}
	var moveset := Generator.moveset_entry("dreamer", schedule, moves, passives)
	assert_push_error("Daydream")
	var clips := {}
	for move: Dictionary in moveset.moves:
		clips[move.name] = move.clip
	assert_eq(clips, {"Zap": "ranged", "Jab": "ranged", "Mend": "cast", "Lob": "melee", "Wish": "melee"},
			"the kit first; Extendo takes Jab to 2 tiles; a melee tag holds Lob")
	assert_eq(moveset.moves.map(func(move: Dictionary) -> bool: return move.kit), [true, true, false, false, false])
	assert_false(moveset.moves[4].built, "Wish is only designed")
	assert_true(moveset.moves[4].special)
	assert_eq(moveset.passives[0], {"name": "Extendo", "kit": true, "built": true, "description": "longer reach"})
	assert_false(moveset.passives[1].built, "nothing knows Daydream")


## The schedule is what the unit will learn, so it decides the boxes; the
## JSON's placeholder pool stops counting.
func test_a_locked_moveset_decides_the_needs() -> void:
	var character := {"currentClass": "Squire", "basePoolMoves": ["Zap"]}
	var schedules := {"squire": Generator.moveset_entry("squire",
			{"kit": {"moves": ["Jab", "Mend"], "passives": []}, "moves": [], "passives": []}, MOVE_BANK, {})}
	var entry := Generator.character_entry("nobody", character, MOVE_BANK, _tree(), schedules)
	assert_eq(entry.moveset, schedules.squire)
	assert_true(_requirement(entry, "cast").needed, "Mend is in the schedule")
	assert_false(_requirement(entry, "ranged").needed, "Zap is only in the placeholder pool")
	assert_false(_requirement(entry.variants[0], "ranged").needed, "a variant learns the same")
	var unscheduled := Generator.character_entry("nobody", character, MOVE_BANK, _tree())
	assert_false(unscheduled.has("moveset"))
	assert_true(_requirement(unscheduled, "ranged").needed, "no schedule: the pool decides")


func test_every_scheduled_move_plays_a_box_and_every_passive_says_what_it_does() -> void:
	var with_moveset := 0
	for character: Dictionary in Generator.build_data().characters:
		if not character.has("moveset"):
			continue
		with_moveset += 1
		for move: Dictionary in character.moveset.moves:
			assert_ne(move.clip, "", "%s's %s: no bank entry or design-doc row says its kind" % [character.id, move.name])
		for passive: Dictionary in character.moveset.passives:
			assert_ne(passive.description, "", "%s's %s" % [character.id, passive.name])
	assert_gt(with_moveset, 0, "some class has a schedule")


## The generator reads PassiveRegistry's source because its handlers can't
## load headless; the real registry has to agree.
func test_coded_passives_are_the_registry_s() -> void:
	var coded := Generator.coded_passives()
	assert_gt(coded.size(), 10)
	for passive_name: String in Generator.read_json(Generator.PASSIVES_PATH):
		assert_eq(coded.has(passive_name), PassiveRegistry.get_handler(passive_name) != null, passive_name)


func test_placeholder_sprite_is_no_idle() -> void:
	var entry := Generator.character_entry("nobody",
			{"sprite": {"sheetPath": Generator.PLACEHOLDER_SPRITE}}, MOVE_BANK)
	var idle: Dictionary = entry.requirements[0]
	assert_eq(idle.id, "idle")
	assert_eq(idle.candidates.size(), 2, "idle0, then a plain idle")
	for candidate: Dictionary in idle.candidates:
		assert_false(candidate.declared, "only the convention paths are left to find")


func test_line_art_is_needed_for_orange() -> void:
	var entry := Generator.character_entry("nobody", {}, MOVE_BANK)
	assert_eq(_requirement(entry, "line_art").tier, "orange")


func test_a_kind_box_lists_its_own_clip_then_the_plain_reach_clip() -> void:
	var entry := Generator.character_entry("nobody", {"basePoolMoves": ["Jab"]}, MOVE_BANK)
	var clips: Array = _requirement(entry, "melee_physical").candidates.map(
			func(candidate: Dictionary) -> String: return candidate.clip)
	assert_eq(clips, ["melee_physical", "melee"], "the plain clip stands in")
	assert_false(_requirement(entry, "melee_special").needed, "Jab is physical")


func test_crits_are_extras_for_the_reaches_the_kit_uses() -> void:
	var entry := Generator.character_entry("nobody", {"basePoolMoves": ["Jab"]}, MOVE_BANK)
	assert_eq(_requirement(entry, "crit_melee").tier, "extra")
	assert_true(_requirement(entry, "crit_melee").needed)
	assert_false(_requirement(entry, "crit_ranged").needed, "Jab never reaches 2 tiles")


func test_convention_paths_name_the_aseprite_file_and_tag() -> void:
	assert_eq(Generator.convention_path("melee_physical", "maam"), "res://art/sprites/characters/maam/melee_physical.png")
	assert_eq(Generator.convention_path("idle", "maam"), "res://art/sprites/characters/maam/idle0.png",
			"idle0 is the default idle; idle1+ are fidgets")
	assert_eq(Generator.convention_path("idle_animation", "maam"), "res://art/sprites/characters/maam/idle0.png",
			"the idle animation is the idle0 tag with more frames")
	assert_eq(Generator.convention_path("line_art", "maam"), "res://art/lineart_fullres/maam.png")


func test_every_column_tells_the_page_where_its_file_goes() -> void:
	for column: Dictionary in Generator.build_data().columns:
		assert_true(str(column.get("convention", "")).contains("{id}"), column.id)


func test_idle_animation_wants_two_frames_from_its_column() -> void:
	var entry := Generator.character_entry("nobody", {}, MOVE_BANK)
	assert_eq(_requirement(entry, "idle_animation").min_frames, 2)
	assert_false(_requirement(entry, "idle").has("min_frames"), "a still counts for the idle box")


## The page looks up one requirement per box by id: a box without one breaks
## the whole board.
func test_every_box_has_one_requirement_of_its_tier() -> void:
	var entry := Generator.character_entry("nobody", {"basePoolMoves": ["Jab", "Zap", "Mend"]}, MOVE_BANK)
	assert_eq(entry.requirements.size(), Generator.COLUMNS.size())
	for column: Dictionary in Generator.COLUMNS:
		assert_eq(_requirement(entry, column.id).tier, column.tier, column.id)


## A tree file as data/classes/README.md has it: Squire into Knight or Page,
## Void Knight under both, and a draft in Page's other slot.
func _tree() -> Dictionary:
	return {
		"base": "squire", "base_types": ["Chivalric"], "notes": "",
		"promotions": [
			{"class": "knight", "types": [], "art": "palette", "promotions": [
				{"class": "void_knight", "types": ["Void"], "art": "redraw"},
				{"class": "banneret", "types": [], "art": "palette"},
			]},
			{"class": "page", "types": [], "art": "palette_layer", "promotions": [
				{"class": "void_knight", "types": [], "art": "redraw"},
				{"class": "", "types": [], "art": "palette", "draft": {"name": "Footpad", "notes": ""}},
			]},
		],
	}


func test_a_character_gets_a_variant_per_class_its_tree_promotes_into() -> void:
	var entry := Generator.character_entry("nobody", {"currentClass": "Squire"}, MOVE_BANK, _tree())
	assert_eq(entry.variants.map(func(variant: Dictionary) -> String: return variant["class"]),
			["knight", "page", "void_knight", "banneret"], "tier 2 first, a class under both branches once, a draft no class")
	for variant: Dictionary in entry.variants:
		assert_eq(variant.id, "nobody_" + variant["class"], "file stem <id>_<class>")


func test_the_board_s_tree_keeps_each_slot_s_class_and_art() -> void:
	var tree := Generator.tree_entry(_tree(), "fighter")
	assert_eq(tree["class"], "squire", "the tree's base, not the class it plays as today")
	assert_eq(tree.promotions[0].promotions[0], {"class": "void_knight", "art": "redraw"}, "typing stays in the file")
	assert_eq(tree.promotions[1].promotions[1], {"class": "", "art": "palette"}, "a draft is an empty slot, as to the game")


func test_no_tree_file_is_today_s_class_with_nothing_designed() -> void:
	var entry := Generator.character_entry("nobody", {"currentClass": "Squire"}, MOVE_BANK)
	assert_eq(entry.tree, {"class": "squire", "promotions": []})
	assert_eq(entry.variants, [])


func test_nothing_under_an_undesigned_slot_is_a_variant() -> void:
	var tree := _tree()
	tree.promotions[0]["class"] = ""
	assert_eq(Generator.tree_promotions(Generator.tree_entry(tree, "squire")), ["page", "void_knight"],
			"no unit promotes into Banneret through an empty slot")


func test_class_names_with_spaces_read_like_the_loader() -> void:
	assert_eq(Generator.character_class_id({"currentClass": "Void Knight"}), "void_knight")


## Moves don't change with class, so neither do the boxes a variant needs.
func test_a_variant_needs_what_its_base_needs() -> void:
	var entry := Generator.character_entry("nobody", {"currentClass": "Squire", "basePoolMoves": ["Jab", "Mend"]},
			MOVE_BANK, _tree())
	assert_false(entry.variants.is_empty(), "the tree promotes")
	for variant: Dictionary in entry.variants:
		for index: int in entry.requirements.size():
			assert_eq(variant.requirements[index].needed, entry.requirements[index].needed,
					"%s %s" % [variant.id, entry.requirements[index].id])


## Nothing in the game loads variants yet: a declared base path must never
## leak into a variant as if it were the variant's own.
func test_variants_only_look_on_their_own_convention_paths() -> void:
	var character := {
		"currentClass": "Squire",
		"sprite": {"sheetPath": "res://art/sprites/characters/old_name/idle.png"},
		"lineartPath": "res://art/lineart_fullres/old_name.png",
	}
	var entry := Generator.character_entry("nobody", character, MOVE_BANK, _tree())
	assert_false(entry.variants.is_empty(), "the tree promotes")
	for variant: Dictionary in entry.variants:
		for requirement: Dictionary in variant.requirements:
			for candidate: Dictionary in requirement.candidates:
				assert_true(candidate.path.contains(variant.id), candidate.path)
				assert_false(candidate.declared, candidate.path)


func test_classes_are_the_pool() -> void:
	var class_pool := ClassTrees.pool()
	var classes: Array = Generator.build_data().classes
	assert_eq(classes.size(), class_pool.size())
	for entry: Dictionary in classes:
		assert_eq(entry.name, class_pool[entry.id].name, entry.id)
		assert_eq(entry.tier, int(class_pool[entry.id].tier), entry.id)


## The board draws a tree from its base class; one missing from the pool draws nothing.
func test_every_character_s_tree_starts_at_a_pool_class() -> void:
	var data := Generator.build_data()
	var class_ids: Array = data.classes.map(func(entry: Dictionary) -> String: return entry.id)
	for character: Dictionary in data.characters:
		assert_has(class_ids, character.tree["class"], character.id)


func test_a_tree_with_no_unit_is_a_design_named_after_its_base_class() -> void:
	var tree := _tree()
	tree["notes"] = "No unit yet."
	var designs := Generator.design_entries({"ernesto": _tree(), "harold": tree}, ["ernesto"],
			{"squire": {"name": "Squire", "tier": 1}})
	assert_eq(designs.size(), 1, "a unit with a character JSON is no design")
	assert_eq(designs[0].id, "harold")
	assert_eq(designs[0].name, "Squire")
	assert_eq(designs[0].tree, Generator.tree_entry(tree, ""))
	assert_eq(designs[0].notes, "No unit yet.")


func test_every_design_starts_at_a_pool_class() -> void:
	var data := Generator.build_data()
	var class_ids: Array = data.classes.map(func(entry: Dictionary) -> String: return entry.id)
	for design: Dictionary in data.designs:
		assert_has(class_ids, design.tree["class"], design.id)


func test_no_variant_shares_its_files_with_a_character() -> void:
	var characters: Array = Generator.build_data().characters
	var character_ids: Array = characters.map(func(entry: Dictionary) -> String: return entry.id)
	for entry: Dictionary in characters:
		for variant: Dictionary in entry.variants:
			assert_does_not_have(character_ids, variant.id, "%s's %s variant" % [entry.id, variant["class"]])


func test_declared_convention_path_is_one_candidate() -> void:
	var candidates := Generator.candidates_for("res://art/a/idle.png", ["res://art/a/idle.png"])
	assert_eq(candidates, [{"path": "art/a/idle.png", "declared": true, "convention": true}])


## A plain idle tag is a convention too: declaring it is no rename, but an
## exported idle0 beside it is the one the board shows.
func test_a_declared_plain_idle_is_not_a_rename() -> void:
	var entry := Generator.character_entry("nobody",
			{"sprite": {"sheetPath": "res://art/sprites/characters/nobody/idle.png"}}, MOVE_BANK)
	var candidates: Array = _requirement(entry, "idle").candidates
	assert_eq(candidates.map(func(candidate: Dictionary) -> String: return candidate.path),
			["art/sprites/characters/nobody/idle0.png", "art/sprites/characters/nobody/idle.png"], "idle0 first")
	assert_eq(candidates.map(func(candidate: Dictionary) -> bool: return candidate.declared), [false, true])
	for candidate: Dictionary in candidates:
		assert_false(candidate.has("rename_to"), candidate.path)


func test_a_declared_idle_off_convention_renames_to_idle0() -> void:
	var entry := Generator.character_entry("nobody",
			{"sprite": {"sheetPath": "res://art/sprites/characters/old_name/idle.png"}}, MOVE_BANK)
	var declared: Dictionary = _requirement(entry, "idle").candidates[0]
	assert_eq(declared.get("rename_to"), "art/sprites/characters/nobody/idle0.png")


func test_every_strip_splits_into_square_frames() -> void:
	var checked := 0
	var art: Array[Dictionary] = []
	for character: Dictionary in Generator.build_data().characters:
		art.append(character)
		art.append_array(character.variants)
	for entry: Dictionary in art:
		for requirement: Dictionary in entry.requirements:
			if requirement.id == "line_art":
				continue
			for candidate: Dictionary in requirement.candidates:
				var size := _png_size("res://" + candidate.path)
				if size == Vector2i.ZERO:
					continue
				checked += 1
				assert_eq(size.x % size.y, 0, "%s is %dx%d: frames must be square" % [
						candidate.path, size.x, size.y])
				# Narrow frames can still divide evenly (six 32x96 = 192x96), so
				# count them against the sidecar's one duration per frame.
				var sidecar := Generator.read_json(("res://" + candidate.path).trim_suffix(".png") + ".json", false)
				var durations: Array = sidecar.get("frame_durations_ms", [])
				if not durations.is_empty():
					assert_eq(size.x, size.y * durations.size(), "%s is %dx%d for %d frames: frames must be square" % [
							candidate.path, size.x, size.y, durations.size()])
	assert_gt(checked, 0, "found strips to check")


func test_contact_boxes_are_the_clips_that_land_a_hit() -> void:
	var contact: Array[String] = []
	for column: Dictionary in Generator.COLUMNS:
		if column.get("contact", false):
			contact.append(column.id)
	assert_eq(contact, ["melee", "ranged", "melee_physical", "melee_special", "ranged_physical",
			"ranged_special", "cast", "crit_melee", "crit_ranged"])


func test_only_lawrence_s_hit_tag_counts_as_a_hit_marker() -> void:
	var folder := "user://art_dashboard_hit_marker_test/"
	DirAccess.make_dir_recursive_absolute(folder)
	var marked := FileAccess.open(folder + "marked.json", FileAccess.WRITE)
	marked.store_string(JSON.stringify({"hit_frame": 2}))
	marked.close()
	var guessed_path := folder + "guessed.png"
	var guessed := Generator.clip_timing(guessed_path, {"melee": {"path": guessed_path, "hit_frame": 4}})
	assert_true(Generator.clip_timing(folder + "marked.png", {}).get("hit_marker", false),
			"the sidecar's hit_frame comes from his tag")
	assert_eq(guessed.get("hit_frame"), 4, "a hit frame picked by eye still plays")
	assert_false(guessed.get("hit_marker", false), "but it isn't his marker, so the board still asks")
	DirAccess.remove_absolute(folder + "marked.json")
	DirAccess.remove_absolute(folder)


## Width and height from the PNG header, big-endian, no import needed.
func _png_size(path: String) -> Vector2i:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Vector2i.ZERO
	var header := file.get_buffer(24)
	if header.size() < 24:
		return Vector2i.ZERO
	var width := (header[16] << 24) | (header[17] << 16) | (header[18] << 8) | header[19]
	var height := (header[20] << 24) | (header[21] << 16) | (header[22] << 8) | header[23]
	return Vector2i(width, height)


func _requirement(entry: Dictionary, id: String) -> Dictionary:
	for requirement: Dictionary in entry.requirements:
		if requirement.id == id:
			return requirement
	fail_test("no requirement %s" % id)
	return {}
