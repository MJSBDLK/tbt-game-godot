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
## Every move name in the bank, sorted — for pickers (the combat sandbox).
static func get_move_names() -> Array[String]:
	if not _is_loaded:
		load_move_bank()
	var names: Array[String] = []
	for key: Variant in _move_database.keys():
		names.append(str(key))
	names.sort()
	return names


static func get_move(move_name: String) -> Move:
	if not _is_loaded:
		load_move_bank()
	if _move_database.has(move_name):
		var move: Move = _move_database[move_name].duplicate() as Move
		move.current_uses = move.max_uses  # duplicate() skips non-exported vars
		return move
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
	move.accuracy = int(data.get("accuracy", 90))
	move.animation_style = String(data.get("animationStyle", "auto")).to_lower()
	move.animation_clip = String(data.get("animationClip", "")).to_lower()

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
		"SUPPORT":
			move.damage_type = Enums.DamageType.SUPPORT
		_:
			move.damage_type = Enums.DamageType.PHYSICAL

	var target_string: String = data.get("targetType", "Single")
	match target_string.to_upper():
		"SELF":
			move.target_type = Enums.TargetType.SELF
		"AOE":
			move.target_type = Enums.TargetType.AOE
		"ALLY":
			move.target_type = Enums.TargetType.ALLY
		"ALLYNOTSELF":
			move.target_type = Enums.TargetType.ALLY_NOT_SELF
		_:
			move.target_type = Enums.TargetType.SINGLE

	# Heal flag (formula: caster.special + base_power, applied in Unit._execute_single_hit)
	move.heals = bool(data.get("heal", false))

	# AoE faction filter + move-wide immunity predicate (see Move field docs).
	move.aoe_affects = String(data.get("aoeAffects", "enemies")).to_lower()
	move.immune_predicate = String(data.get("immune", "")).to_lower()

	# On-hit instant effects (displacement, cleanse). Non-lingering, post-damage.
	# Displacement schema is documented in displacement_system.gd's header.
	var on_hit_data: Variant = data.get("onHit", null)
	if on_hit_data is Dictionary:
		var displace_data: Variant = on_hit_data.get("displace", null)
		if displace_data is Dictionary:
			move.displace_distance = int(displace_data.get("distance", 0))
			move.displace_subject = String(displace_data.get("subject", "target"))
			move.displace_shape = String(displace_data.get("shape", "single"))
			move.displace_vector = String(displace_data.get("vector", "away_from_attacker"))
			move.displace_on_blocked = String(displace_data.get("on_blocked", "stop"))
			var save_data: Variant = displace_data.get("save", null)
			if save_data is Dictionary:
				move.displace_contest_stat = String(save_data.get("contest", "constitution"))
				move.displace_contest_margin = int(save_data.get("margin", 0))
		var cleanse_data: Variant = on_hit_data.get("cleanse", null)
		if cleanse_data is Array:
			var cleansed: PackedStringArray = PackedStringArray()
			for entry: Variant in cleanse_data:
				cleansed.append(String(entry).to_upper())
			move.cleanse_effects = cleansed
		var scheduled_data: Variant = on_hit_data.get("scheduled", null)
		if scheduled_data is Dictionary:
			# Everything that isn't schema plumbing rides through as a handler
			# param, so new knobs don't need a parser change.
			var params: Dictionary = {}
			for key: Variant in scheduled_data.keys():
				if String(key) not in ["effect", "delay", "marker", "stacks"]:
					params[String(key)] = scheduled_data[key]
			move.scheduled_effect = {
				"effect": String(scheduled_data.get("effect", "")),
				"delay": maxi(1, int(scheduled_data.get("delay", 1))),
				"marker": String(scheduled_data.get("marker", "")).to_upper(),
				"stacks": int(scheduled_data.get("stacks", 0)),
				"params": params,
			}

	# Status effect / crit (the single secondary slot — mutually exclusive).
	var status_data: Variant = data.get("statusEffect", null)
	if status_data is Dictionary and status_data.has("conditional"):
		# Conditional-by-target branch (Phase 4): which effect lands depends on
		# a per-target predicate. Mutually exclusive with the flat form below.
		var conditional: Variant = status_data.get("conditional")
		if conditional is Dictionary:
			move.status_conditional = {
				"predicate": String(conditional.get("predicate", "")).to_lower(),
				"then": _parse_conditional_branch(conditional.get("then", null)),
				"else": _parse_conditional_branch(conditional.get("else", null)),
			}
	elif status_data is Dictionary:
		var effect_name: String = status_data.get("effect", "")
		var effect_upper: String = effect_name.to_upper()
		var status_target: String = String(status_data.get("target", "target")).to_lower()
		if effect_upper == "CRIT" or effect_upper == "CRITICAL":
			# Crit is resolved as a damage event in the pipeline, not a status.
			# target: "self" banks a crit for the next attack (Focus, Uppercut);
			# otherwise the roll crits this hit.
			move.crit_chance = float(status_data.get("chance", 0.0))
			move.crit_self_target = status_target == "self"
		else:
			move.status_effect_chance = float(status_data.get("chance", 0.0))
			move.status_effect_type = _parse_status_effect(effect_name)
			move.status_effect_stacks = int(status_data.get("stacks", 0))
			move.status_effect_replaces = bool(status_data.get("replaces", false))
			move.status_effect_self_target = status_target == "self"

	return move


## One arm of a conditional statusEffect. {} in the JSON (or an absent arm)
## means "these targets get nothing" — a legal way to author e.g. "brave units
## are simply unaffected." Effect names are validated at apply time by
## StatusEffectSystem (unknown → logged error, no crash).
static func _parse_conditional_branch(branch_data: Variant) -> Dictionary:
	if not branch_data is Dictionary or (branch_data as Dictionary).is_empty():
		return {}
	var branch: Dictionary = branch_data
	return {
		"effect": String(branch.get("effect", "")).to_upper(),
		"chance": float(branch.get("chance", 1.0)),
		"stacks": int(branch.get("stacks", 0)),
		"replaces": bool(branch.get("replaces", false)),
	}


static func _parse_status_effect(effect_name: String) -> Enums.StatusEffectType:
	var upper := effect_name.to_upper()
	for key: String in Enums.StatusEffectType.keys():
		if key == upper:
			return Enums.StatusEffectType[key]
	return Enums.StatusEffectType.NONE
