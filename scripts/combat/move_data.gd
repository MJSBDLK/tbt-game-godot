## Loads move definitions from JSON and creates Move Resources.
## Usage: MoveData.get_move("Bonk") -> Move (fresh copy with own PP tracking)
class_name MoveData
extends RefCounted


static var _move_database: Dictionary = {}  # String -> Move
static var _is_loaded: bool = false


static func load_move_bank(json_path: String = "res://data/moves/basic_move_bank.json") -> void:
	var file_content := FileAccess.get_file_as_string(json_path)
	if file_content.is_empty():
		push_error("MoveData: Failed to read '%s'" % json_path)
		return

	var json_result: Variant = JSON.parse_string(file_content)
	if json_result == null or not json_result is Dictionary:
		push_error("MoveData: Failed to parse '%s'" % json_path)
		return

	var data: Dictionary = json_result
	_move_database.clear()

	for move_name: String in data.keys():
		var entry: Dictionary = data[move_name]
		var move := _parse_move_entry(move_name, entry)
		_move_database[move_name] = move

	_is_loaded = true
	print("MoveData: Loaded %d moves from '%s'" % [_move_database.size(), json_path])


## Returns a fresh duplicate of the named move (per-unit PP tracking).
static func get_move(move_name: String) -> Move:
	if not _is_loaded:
		load_move_bank()
	if _move_database.has(move_name):
		return _move_database[move_name].duplicate() as Move
	push_warning("MoveData: Unknown move '%s'" % move_name)
	return null


static func _parse_move_entry(move_name: String, data: Dictionary) -> Move:
	var move := Move.new()
	move.move_name = move_name
	move.abbrev_name = data.get("abbrevName", move_name)
	move.move_id = data.get("moveId", move_name.to_lower().replace(" ", "_"))
	move.description = data.get("description", "")
	move.attack_range = int(data.get("range", 1))
	move.area_of_effect = int(data.get("areaOfEffect", 0))
	move.base_power = int(data.get("basePower", 0))

	# PP from power tier + optional offset
	var base_pp := Move.calculate_max_uses_from_power(move.base_power)
	var pp_offset: int = int(data.get("usagesOffset", 0))
	move.max_uses = clampi(base_pp + pp_offset, 1, 99)
	move.current_uses = move.max_uses

	# Parse enums from strings
	var element_string: String = data.get("elementType", "None")
	move.element_type = Enums.string_to_elemental_type(element_string)

	var damage_string: String = data.get("damageType", "Physical")
	match damage_string.to_upper():
		"SPECIAL":
			move.damage_type = Enums.DamageType.SPECIAL
		_:
			move.damage_type = Enums.DamageType.PHYSICAL

	var target_string: String = data.get("targetType", "Single")
	match target_string.to_upper():
		"SELF":
			move.target_type = Enums.TargetType.SELF
		"AOE":
			move.target_type = Enums.TargetType.AOE
		_:
			move.target_type = Enums.TargetType.SINGLE

	# Status effect (data only)
	var status_data: Variant = data.get("statusEffect", null)
	if status_data is Dictionary:
		var effect_name: String = status_data.get("effect", "")
		move.status_effect_chance = float(status_data.get("chance", 0.0))
		move.status_effect_type = _parse_status_effect(effect_name)

	return move


static func _parse_status_effect(effect_name: String) -> Enums.StatusEffectType:
	var upper := effect_name.to_upper()
	for key: String in Enums.StatusEffectType.keys():
		if key == upper:
			return Enums.StatusEffectType[key]
	return Enums.StatusEffectType.NONE
