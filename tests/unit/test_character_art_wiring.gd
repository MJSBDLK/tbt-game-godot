## Every character JSON's art and pool wiring resolves on disk. The failure
## this pins is silent in a build: a bad path just falls through to the
## pixel portrait or an empty workbench slot, and nobody notices until a
## panel looks wrong. Portrait atlases must crop THEIR OWN sheet inside its
## bounds, and every referenced sheet's import must generate mipmaps
## (CLAUDE.md: HD textures alias on the HDLayer downscale without them).
extends GutTest

const CHARACTERS_DIR: String = "res://data/characters"


func _character_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir: DirAccess = DirAccess.open(CHARACTERS_DIR)
	assert_not_null(dir, "character folder opens")
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			paths.append(CHARACTERS_DIR + "/" + file_name)
	paths.sort()
	return paths


func test_there_are_characters_to_check() -> void:
	assert_gt(_character_paths().size(), 30)


func test_sprite_and_portrait_paths_exist() -> void:
	for path: String in _character_paths():
		var character: CharacterData = CharacterDataLoader.load_character(path)
		assert_not_null(character, path)
		if character.sprite_atlas_path == "":
			assert_true(ResourceLoader.exists(character.sprite_sheet_path),
					"%s sprite sheet: %s" % [path, character.sprite_sheet_path])
		else:
			assert_true(ResourceLoader.exists(character.sprite_atlas_path),
					"%s sprite atlas: %s" % [path, character.sprite_atlas_path])
		if character.portrait_path != "":
			assert_true(ResourceLoader.exists(character.portrait_path),
					"%s portrait: %s" % [path, character.portrait_path])
		if character.lineart_path != "":
			assert_true(ResourceLoader.exists(character.lineart_path),
					"%s line art: %s" % [path, character.lineart_path])


func test_portrait_atlases_crop_their_own_sheet_inside_its_bounds() -> void:
	var atlases_seen: int = 0
	for path: String in _character_paths():
		var character: CharacterData = CharacterDataLoader.load_character(path)
		for region_name: String in character.lineart_atlases:
			var atlas_path: String = str(character.lineart_atlases[region_name])
			assert_true(ResourceLoader.exists(atlas_path), "%s atlas: %s" % [path, atlas_path])
			var atlas: AtlasTexture = load(atlas_path) as AtlasTexture
			assert_not_null(atlas, "%s is an AtlasTexture" % atlas_path)
			if atlas == null or atlas.atlas == null:
				continue
			assert_eq(atlas.atlas.resource_path, character.lineart_path,
					"%s crops the character's own line art" % atlas_path)
			var sheet_bounds := Rect2(Vector2.ZERO, atlas.atlas.get_size())
			assert_true(sheet_bounds.encloses(atlas.region),
					"%s region %s inside %s" % [atlas_path, atlas.region, sheet_bounds])
			assert_gt(atlas.region.size.x, 0.0, "%s has a width" % atlas_path)
			atlases_seen += 1
	assert_gt(atlases_seen, 0, "at least one character has an HD portrait")


func test_referenced_line_art_imports_generate_mipmaps() -> void:
	for path: String in _character_paths():
		var character: CharacterData = CharacterDataLoader.load_character(path)
		if character.lineart_path == "" or not character.lineart_path.ends_with(".png"):
			continue
		var import_text: String = FileAccess.get_file_as_string(character.lineart_path + ".import")
		assert_string_contains(import_text, "mipmaps/generate=true",
				"%s: flip mipmaps/generate in the .import" % character.lineart_path)


func test_pool_names_exist_in_the_move_bank_and_passive_table() -> void:
	var move_names: Array[String] = MoveData.get_move_names()
	for path: String in _character_paths():
		var character: CharacterData = CharacterDataLoader.load_character(path)
		for move_name: String in character.base_pool_moves:
			assert_has(move_names, move_name, "%s pool move" % path)
		for passive_name: String in character.base_pool_passives:
			assert_not_null(PassiveData.get_passive(passive_name), "%s pool passive %s" % [path, passive_name])


func test_portrait_crops_are_square() -> void:
	# The portrait boxes are square; a wide crop floats in them with a band
	# underneath. The crew file hugs whatever shape it gets, so square costs
	# nothing there.
	var crops_seen: int = 0
	for path: String in _character_paths():
		var character: CharacterData = CharacterDataLoader.load_character(path)
		if not character.lineart_atlases.has("portrait"):
			continue
		var atlas: AtlasTexture = load(str(character.lineart_atlases["portrait"])) as AtlasTexture
		assert_not_null(atlas, path)
		if atlas == null:
			continue
		assert_eq(atlas.region.size.x, atlas.region.size.y, "%s portrait crop is square" % path)
		crops_seen += 1
	assert_gt(crops_seen, 0)
