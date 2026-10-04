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


func test_declared_convention_path_is_one_candidate() -> void:
	var candidates := Generator.candidates_for("res://art/a/idle.png", "res://art/a/idle.png")
	assert_eq(candidates, [{"path": "art/a/idle.png", "declared": true, "convention": true}])


func test_every_strip_splits_into_square_frames() -> void:
	var checked := 0
	for character: Dictionary in Generator.build_data().characters:
		for requirement: Dictionary in character.requirements:
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
