## Loads passive definitions from data/passives.json. Static cache shared by
## any UI that wants to render passive descriptions (equipment picker, unit
## detail panel, etc.).
##
## Passives are simpler than Moves — for now they're just `{abbrev_name,
## description}`. Effects are applied elsewhere (StatusEffectSystem,
## EnemyAI, etc.) keyed by name.
class_name PassiveData
extends RefCounted


static var _passive_database: Dictionary = {}  # String -> {abbrev_name, description}
static var _is_loaded: bool = false


static func _ensure_loaded() -> void:
	if _is_loaded:
		return
	var file_content := FileAccess.get_file_as_string("res://data/passives.json")
	if file_content.is_empty():
		push_error("PassiveData: Failed to read passives.json")
		_is_loaded = true
		return
	var parsed: Variant = JSON.parse_string(file_content)
	if not parsed is Dictionary:
		push_error("PassiveData: Failed to parse passives.json")
		_is_loaded = true
		return
	var data: Dictionary = parsed
	for passive_name: String in data.keys():
		var entry: Dictionary = data[passive_name]
		_passive_database[passive_name] = {
			"abbrev_name": String(entry.get("abbrevName", passive_name)),
			"description": String(entry.get("description", "")),
		}
	_is_loaded = true


## Returns `{abbrev_name, description}` or null if the name is unknown.
static func get_passive(passive_name: String) -> Variant:
	_ensure_loaded()
	return _passive_database.get(passive_name, null)


## Best-effort description; returns empty string if the passive is unknown.
static func get_description(passive_name: String) -> String:
	var entry: Variant = get_passive(passive_name)
	if entry is Dictionary:
		return entry.get("description", "")
	return ""
