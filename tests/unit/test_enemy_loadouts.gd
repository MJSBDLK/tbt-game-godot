## Balance guards for the enemy pool's opening loadouts (RQD 2026-08-21, todo
## #2). A character's first four pool moves / passives are what auto-equips
## (CharacterDataLoader), so "what's in the opening four" IS the level-1 enemy.
##
## What drove these: the mage template (Pyro, Keener, Phoenix Pirate — and
## Plant Cultist, same sheet, not in today's pool) shipped Spc 9 / 70% growth
## AND auto-equipped an 11-power range-2 special (Blaze / Dark Energy). At
## level 1 vs Res 3 that's (9+11-3) x1.2 STAB = 20, x1.25 with one Bellows
## stack = 26, against 13-22 HP player units. The ruling: Spc 9→7, growth
## 70→55 ("70% growth on a standard enemy is just too high"), and the 11-power
## move out of the opening four. These pin that ruling so a data regen or a
## copy-paste from another sheet can't quietly undo it — move the dials
## deliberately, with a note here.
extends GutTest


const MAGE_TEMPLATE_ENEMIES: Array[String] = [
	"res://data/characters/pyro.json",
	"res://data/characters/keener.json",
	"res://data/characters/flamethrower_phoenix.json",
	"res://data/characters/plant_cultist.json",
]
const SPECIAL_CEILING: int = 7
const SPECIAL_GROWTH_CEILING: int = 55
const OPENING_POWER_CEILING: int = 10
const OPENING_SLOTS: int = 4


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "%s parses" % path)
	return parsed if parsed is Dictionary else {}


func test_mage_template_enemies_keep_the_trimmed_special_line() -> void:
	for path: String in MAGE_TEMPLATE_ENEMIES:
		var data := _json(path)
		assert_lte(int(data["baseStats"]["special"]), SPECIAL_CEILING,
				"%s: Spc trimmed (was 9)" % path.get_file())
		assert_lte(int(data["growthRates"]["special"]), SPECIAL_GROWTH_CEILING,
				"%s: Spc growth trimmed (was 70)" % path.get_file())


func test_no_mage_template_enemy_opens_with_an_eleven_power_move() -> void:
	for path: String in MAGE_TEMPLATE_ENEMIES:
		var data := _json(path)
		var pool: Array = data["basePoolMoves"]
		for index: int in mini(pool.size(), OPENING_SLOTS):
			var move := MoveData.get_move(str(pool[index]))
			assert_not_null(move, "%s: '%s' exists in the move bank" % [path.get_file(), pool[index]])
			if move != null:
				assert_lte(move.base_power, OPENING_POWER_CEILING,
						"%s: '%s' (power %d) is too hot for the opening four" % [
							path.get_file(), move.move_name, move.base_power])


func test_the_opening_four_is_what_actually_equips() -> void:
	# The guard above only means something while the loader equips the first
	# four pool moves verbatim. If that rule changes, so must the guard.
	var pyro := CharacterDataLoader.load_character("res://data/characters/pyro.json")
	assert_not_null(pyro)
	assert_eq(pyro.equipped_moves.size(), OPENING_SLOTS)
	for index: int in OPENING_SLOTS:
		assert_eq(pyro.equipped_moves[index].move_name, pyro.base_pool_moves[index],
				"slot %d equips pool entry %d" % [index, index])
	var names: Array[String] = []
	for move: Move in pyro.equipped_moves:
		names.append(move.move_name)
	assert_does_not_have(names, "Blaze", "Blaze waits for a later unlock / the prep screen")
