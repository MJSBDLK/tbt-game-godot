## Every shipped character's animation table is sound: clip keys come from
## the vocabulary, every strip exists and divides evenly into its frame
## count, no legacy use_when survives, and every override points at a clip
## the character actually has. Fallbacks (PROCEDURAL) are allowed — this is
## a "no broken references" net, not an art-completeness gate (that report
## is tools/diag/animation_coverage_probe.gd).
extends GutTest


const CHARACTERS_DIRECTORY: String = "res://data/characters/"


func _character_files() -> Array[String]:
	var files: Array[String] = []
	var directory := DirAccess.open(CHARACTERS_DIRECTORY)
	assert_not_null(directory, "characters directory opens")
	if directory == null:
		return files
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			files.append(CHARACTERS_DIRECTORY + file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	files.sort()
	return files


func test_every_clip_table_is_sound() -> void:
	var swept := 0
	var with_clips := 0
	for path: String in _character_files():
		var character := CharacterDataLoader.load_character(path)
		if character == null:
			continue
		swept += 1
		if not character.attack_animations.is_empty():
			with_clips += 1
		for key: Variant in character.attack_animations.keys():
			var clip_key := str(key)
			var clip: Dictionary = character.attack_animations[key]
			assert_has(UnitAnimationResolver.VOCABULARY, clip_key,
					"%s: clip key '%s' is not in the vocabulary" % [character.character_id, clip_key])
			assert_false(clip.has("use_when"),
					"%s: clip '%s' still carries a legacy use_when" % [character.character_id, clip_key])
			var strip_path := str(clip.get("path", ""))
			assert_true(ResourceLoader.exists(strip_path),
					"%s: clip '%s' strip missing: %s" % [character.character_id, clip_key, strip_path])
			var frames := int(clip.get("frames", 0))
			assert_gt(frames, 0, "%s: clip '%s' declares no frames" % [character.character_id, clip_key])
			if frames > 0 and ResourceLoader.exists(strip_path):
				var texture: Texture2D = load(strip_path) as Texture2D
				assert_not_null(texture, "%s: clip '%s' strip fails to load" % [character.character_id, clip_key])
				if texture != null:
					assert_eq(texture.get_width() % frames, 0,
							"%s: clip '%s' strip width %d is not a multiple of %d frames" % [
								character.character_id, clip_key, texture.get_width(), frames])
		for override_key: Variant in character.animation_overrides.keys():
			var target := str(character.animation_overrides[override_key])
			assert_true(character.attack_animations.has(target),
					"%s: override '%s' → '%s' names a clip the character lacks" % [
						character.character_id, override_key, target])
			var key_text := str(override_key)
			assert_true(key_text.begins_with("move:") or UnitAnimationResolver.CHAINS.has(key_text),
					"%s: override key '%s' is neither an intent nor move:<name>" % [
						character.character_id, key_text])
	assert_gt(swept, 20, "the sweep saw the whole roster")
	assert_gt(with_clips, 0, "at least the migrated four carry clips")


func test_the_migrated_four_resolve_to_real_strips() -> void:
	# The Phase 1 migration renamed meleeside/shootside/melee_long into the
	# vocabulary. Pin what each of the four plays for a plain swing and a shot.
	var expectations := {
		"spaceman": { "melee_physical": "melee", "ranged_physical": "ranged" },
		"keener": { "melee_physical": "melee", "ranged_special": "ranged" },
		"ernesto": { "melee_physical": "melee", "ranged_physical": "ranged_physical" },
		"grasker": { "melee_physical": "melee", "ranged_physical": "melee" },
	}
	for character_id: String in expectations.keys():
		var character := CharacterDataLoader.load_character(CHARACTERS_DIRECTORY + character_id + ".json")
		assert_not_null(character, character_id)
		if character == null:
			continue
		for intent: String in expectations[character_id].keys():
			assert_eq(UnitAnimationResolver.resolve_for(character, null, intent),
					expectations[character_id][intent], "%s / %s" % [character_id, intent])


func test_ernesto_thrusts_at_range_and_jabs_adjacent() -> void:
	# RQD's first eyeball (2026-09-07): Laser resolved to the jab at every
	# distance — reach came from the move and the chain crossed reach before
	# trying the same reach's other kind. Real JSON, real moves.
	var ernesto := CharacterDataLoader.load_character(CHARACTERS_DIRECTORY + "ernesto.json")
	assert_not_null(ernesto)
	if ernesto == null:
		return
	for move_name: String in ["Laser", "Sidearm", "Compressed Air"]:
		var move: Move = MoveData.get_move(move_name)
		assert_not_null(move, move_name)
		if move == null:
			continue
		assert_eq(UnitAnimationResolver.resolve_for(ernesto, move, UnitAnimationResolver.attack_intent(move, 2)),
				"ranged_physical", "%s at range → the long thrust" % move_name)
		assert_eq(UnitAnimationResolver.resolve_for(ernesto, move, UnitAnimationResolver.attack_intent(move, 1)),
				"melee", "%s point-blank → the jab" % move_name)
