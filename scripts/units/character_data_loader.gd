## Loads character definitions from JSON files and creates CharacterData Resources.
## Usage: CharacterDataLoader.load_character("res://data/characters/spaceman.json")
class_name CharacterDataLoader
extends RefCounted


static func load_character(json_path: String) -> CharacterData:
	var file_content := FileAccess.get_file_as_string(json_path)
	if file_content.is_empty():
		push_error("CharacterDataLoader: Failed to read '%s'" % json_path)
		return null

	var json_result: Variant = JSON.parse_string(file_content)
	if json_result == null or not json_result is Dictionary:
		push_error("CharacterDataLoader: Failed to parse '%s'" % json_path)
		return null

	return _parse_character_json(json_result as Dictionary)


static func _parse_character_json(data: Dictionary) -> CharacterData:
	var character := CharacterData.new()

	# Identity
	character.character_name = data.get("characterName", "Unknown")
	character.primary_type = Enums.string_to_elemental_type(data.get("primaryType", "None"))
	character.secondary_type = Enums.string_to_elemental_type(data.get("secondaryType", "None"))
	character.current_class = _parse_character_class(data.get("currentClass", "Spaceman"))
	character.specialization = _parse_specialization(data.get("specialization", "None"))
	character.level = int(data.get("level", 1))

	# Base stats
	var stats: Dictionary = data.get("baseStats", {})
	character.base_max_hp = int(stats.get("maxHP", 20))
	character.base_strength = int(stats.get("strength", 5))
	character.base_special = int(stats.get("special", 5))
	character.base_skill = int(stats.get("skill", 5))
	character.base_agility = int(stats.get("agility", 5))
	character.base_athleticism = int(stats.get("athleticism", 5))
	character.base_defense = int(stats.get("defense", 5))
	character.base_resistance = int(stats.get("resistance", 5))

	# Growth rates
	var growth: Dictionary = data.get("growthRates", {})
	character.growth_rate_hp = int(growth.get("hp", 50))
	character.growth_rate_strength = int(growth.get("strength", 50))
	character.growth_rate_special = int(growth.get("special", 50))
	character.growth_rate_skill = int(growth.get("skill", 50))
	character.growth_rate_agility = int(growth.get("agility", 50))
	character.growth_rate_athleticism = int(growth.get("athleticism", 50))
	character.growth_rate_defense = int(growth.get("defense", 50))
	character.growth_rate_resistance = int(growth.get("resistance", 50))

	# Physical attributes
	var physical: Dictionary = data.get("physicalAttributes", {})
	character.move_distance = int(physical.get("moveDistance", 3))
	character.constitution = int(physical.get("constitution", 5))
	character.carry = int(physical.get("carry", 8))

	# Move pool (string names for later lookup)
	var move_names: Array = data.get("basePoolMoves", [])
	for move_name: Variant in move_names:
		character.base_pool_moves.append(str(move_name))

	# Passive pool
	var passive_names: Array = data.get("basePoolPassives", [])
	for passive_name: Variant in passive_names:
		character.base_pool_passives.append(str(passive_name))

	# Equip moves from pool (up to 4)
	for i: int in range(mini(move_names.size(), 4)):
		var move := MoveData.get_move(str(move_names[i]))
		if move != null:
			character.equipped_moves.append(move)

	return character


static func _parse_character_class(class_string: String) -> Enums.CharacterClass:
	var upper := class_string.to_upper().replace(" ", "_")
	for key: String in Enums.CharacterClass.keys():
		if key == upper:
			return Enums.CharacterClass[key]
	return Enums.CharacterClass.SPACEMAN


static func _parse_specialization(spec_string: String) -> Enums.Specialization:
	var upper := spec_string.to_upper().replace(" ", "_")
	for key: String in Enums.Specialization.keys():
		if key == upper:
			return Enums.Specialization[key]
	return Enums.Specialization.NONE
