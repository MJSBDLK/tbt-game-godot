extends GutTest
## Roster-wide data integrity for data/characters/*.json (non-recursive — the
## orphaned alpha/ snapshot is deliberately skipped). Born from the Keener
## rename (2026-08-03): _parse_character_class falls back to SPACEMAN on any
## unknown currentClass string, and sprite/clip paths go stale when art
## folders move — both silently. This sweep turns those into loud failures
## the moment a rename misses a reference (it would have caught bandit.json's
## "Bandit", which shipped as a silent Spaceman).

const _ROSTER_DIRECTORY: String = "res://data/characters"


func test_every_roster_character_loads_coherently() -> void:
	var directory := DirAccess.open(_ROSTER_DIRECTORY)
	assert_not_null(directory, "Roster directory must exist.")
	var swept: int = 0
	for file_name: String in directory.get_files():
		if not file_name.ends_with(".json"):
			continue
		swept += 1
		var path := "%s/%s" % [_ROSTER_DIRECTORY, file_name]
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_true(raw is Dictionary, "%s: not valid JSON" % file_name)
		if not raw is Dictionary:
			continue
		var character := CharacterDataLoader.load_character(path)
		assert_ne(character.character_name, "",
				"%s: characterName is empty" % file_name)

		# The class parser falls back to SPACEMAN without a warning — catch
		# stale currentClass strings by round-tripping to the enum key.
		var expected_key: String = str((raw as Dictionary).get(
				"currentClass", "Spaceman")).to_upper().replace(" ", "_")
		var parsed_key: String = Enums.CharacterClass.keys()[character.current_class]
		assert_eq(parsed_key, expected_key,
				"%s: currentClass '%s' silently fell back to %s" % [
					file_name, (raw as Dictionary).get("currentClass", ""), parsed_key])

		if character.sprite_sheet_path != "":
			assert_true(ResourceLoader.exists(character.sprite_sheet_path),
					"%s: sheetPath '%s' missing on disk" % [
						file_name, character.sprite_sheet_path])
		if character.sprite_atlas_path != "":
			assert_true(FileAccess.file_exists(character.sprite_atlas_path),
					"%s: atlasPath '%s' missing on disk" % [
						file_name, character.sprite_atlas_path])
		for clip_name: Variant in character.attack_animations.keys():
			var clip: Variant = character.attack_animations[clip_name]
			if clip is Dictionary:
				var clip_path: String = str((clip as Dictionary).get("path", ""))
				assert_true(ResourceLoader.exists(clip_path),
						"%s: clip '%s' path '%s' missing on disk" % [
							file_name, clip_name, clip_path])
	assert_gt(swept, 20, "The sweep should see the whole roster, not a stub dir.")
