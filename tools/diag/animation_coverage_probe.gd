## Animation coverage report — the asset queue for the combat scene. Run
## from the project root (headless is fine, it only loads textures):
##   godot-4 --headless --path . -s tools/diag/animation_coverage_probe.gd
## For every character JSON, prints one row per intent with the clip key
## UnitAnimationResolver picks, or "-" for PROCEDURAL (boop / pulse / flash /
## fade). A row is what the player SEES. Also validates every declared strip
## (exists, width divides by frames) and every override, and exits 1 on a
## broken reference — the same net as tests/unit/test_animation_coverage.gd,
## readable at a glance.
##
## Reading the table: a character whose attack columns all say "-" has only
## an idle; one whose ranged_* columns repeat its melee clip swings at
## range (fine — the fallback chain at work); dodge/hurt/death are always
## "-" until Lawrence draws reaction clips. See .claude/todo-archive.md ("Battle animations plan")
## §7 for the priority order.
##
## -s gotchas (same as the other probes here): autoload names are NOT
## identifiers at main-script compile time, and naming a class_name whose
## script touches an autoload (CharacterDataLoader → InjurySystem) compiles
## it too early and poisons it for the run. So: settle a few frames, then
## load the scripts by PATH and call through them.
extends SceneTree


const CHARACTERS_DIRECTORY: String = "res://data/characters/"
const LOADER_PATH: String = "res://scripts/units/character_data_loader.gd"
const RESOLVER_PATH: String = "res://scripts/units/unit_animation_resolver.gd"
const INTENTS: Array[String] = [
	"melee_physical", "melee_special", "ranged_physical", "ranged_special",
	"cast", "dodge", "hurt", "death",
]
const COLUMN_WIDTH: int = 16
const SETTLE_FRAMES: int = 10


func _initialize() -> void:
	_run()


func _run() -> void:
	for i in SETTLE_FRAMES:
		await process_frame
	var loader: GDScript = load(LOADER_PATH)
	var resolver: GDScript = load(RESOLVER_PATH)
	var resolver_constants: Dictionary = resolver.get_script_constant_map()
	var vocabulary: Array = resolver_constants["VOCABULARY"]
	var procedural: String = resolver_constants["PROCEDURAL"]

	var files: Array[String] = _character_files()
	var broken := 0
	var clip_less := 0
	var header := "%-22s" % "character"
	for intent: String in INTENTS:
		header += ("%-" + str(COLUMN_WIDTH) + "s") % intent
	print(header)
	print("-".repeat(header.length()))
	for path: String in files:
		var character: Resource = loader.load_character(path)
		if character == null:
			print("%-22s (failed to load)" % path.get_file())
			broken += 1
			continue
		var clips: Dictionary = character.get("attack_animations")
		var overrides: Dictionary = character.get("animation_overrides")
		var character_id: String = str(character.get("character_id"))
		var row := "%-22s" % character_id
		for intent: String in INTENTS:
			var key: String = resolver.resolve(clips, overrides, null, intent, character_id)
			row += ("%-" + str(COLUMN_WIDTH) + "s") % (key if key != procedural else "-")
		print(row)
		if clips.is_empty():
			clip_less += 1
		broken += _validate(character_id, clips, overrides, vocabulary)
	print("")
	print("%d characters, %d with no attack clips at all, %d broken references." % [
			files.size(), clip_less, broken])
	quit(1 if broken > 0 else 0)


## Existence + geometry of every declared strip, and every override target;
## prints each problem, returns the count.
func _validate(character_id: String, clips: Dictionary, overrides: Dictionary,
		vocabulary: Array) -> int:
	var problems := 0
	for key: Variant in clips.keys():
		var clip: Dictionary = clips[key]
		var strip_path := str(clip.get("path", ""))
		var frames := int(clip.get("frames", 0))
		if not vocabulary.has(str(key)):
			print("  !! %s: clip key '%s' is not in the vocabulary" % [character_id, key])
			problems += 1
		if not ResourceLoader.exists(strip_path):
			print("  !! %s: clip '%s' strip missing: %s" % [character_id, key, strip_path])
			problems += 1
			continue
		if frames <= 0:
			print("  !! %s: clip '%s' declares no frames" % [character_id, key])
			problems += 1
			continue
		var texture: Texture2D = load(strip_path) as Texture2D
		if texture == null:
			print("  !! %s: clip '%s' strip fails to load" % [character_id, key])
			problems += 1
		elif texture.get_width() % frames != 0:
			print("  !! %s: clip '%s' width %d is not a multiple of %d frames" % [
					character_id, key, texture.get_width(), frames])
			problems += 1
	for override_key: Variant in overrides.keys():
		var target := str(overrides[override_key])
		if not clips.has(target):
			print("  !! %s: override '%s' → '%s' names a clip the character lacks" % [
					character_id, override_key, target])
			problems += 1
	return problems


func _character_files() -> Array[String]:
	var files: Array[String] = []
	var directory := DirAccess.open(CHARACTERS_DIRECTORY)
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
