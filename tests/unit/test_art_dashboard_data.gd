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


func test_placeholder_sprite_is_no_idle() -> void:
	var entry := Generator.character_entry("nobody",
			{"sprite": {"sheetPath": Generator.PLACEHOLDER_SPRITE}}, MOVE_BANK)
	var idle: Dictionary = entry.requirements[0]
	assert_eq(idle.id, "idle")
	assert_eq(idle.candidates.size(), 1)
	assert_false(idle.candidates[0].declared, "only the convention path is left to find")


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
	assert_eq(Generator.convention_path("idle_animation", "maam"), "res://art/sprites/characters/maam/idle.png",
			"the idle animation is the idle tag with more frames")
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


func test_no_variant_shares_its_files_with_a_character() -> void:
	var characters: Array = Generator.build_data().characters
	var character_ids: Array = characters.map(func(entry: Dictionary) -> String: return entry.id)
	for entry: Dictionary in characters:
		for variant: Dictionary in entry.variants:
			assert_does_not_have(character_ids, variant.id, "%s's %s variant" % [entry.id, variant["class"]])


func test_declared_convention_path_is_one_candidate() -> void:
	var candidates := Generator.candidates_for("res://art/a/idle.png", "res://art/a/idle.png")
	assert_eq(candidates, [{"path": "art/a/idle.png", "declared": true, "convention": true}])


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
	assert_gt(checked, 0, "found strips to check")


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
