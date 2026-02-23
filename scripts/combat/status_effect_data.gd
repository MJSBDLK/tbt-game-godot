## Template configuration for status effect types.
## Defines default properties (stat affected, modifier, duration, stackability).
class_name StatusEffectData
extends RefCounted


var effect_type: String = ""
var description: String = ""
var affected_stat: String = ""
var modifier: int = 0
var duration: int = 0
var stackable: bool = false
var is_dot: bool = false  # Damage-over-time


static func get_default_configs() -> Dictionary:
	var configs: Dictionary = {}

	var burn := StatusEffectData.new()
	burn.effect_type = "BURN"
	burn.description = "Reduces strength and deals damage each turn"
	burn.affected_stat = "strength"
	burn.modifier = -3
	burn.duration = 4
	burn.is_dot = true
	configs["BURN"] = burn

	var poison := StatusEffectData.new()
	poison.effect_type = "POISON"
	poison.description = "Deals damage each turn"
	poison.affected_stat = ""
	poison.modifier = 0
	poison.duration = 4
	poison.is_dot = true
	configs["POISON"] = poison

	var rooted := StatusEffectData.new()
	rooted.effect_type = "ROOTED"
	rooted.description = "Cannot move"
	rooted.affected_stat = ""
	rooted.modifier = 0
	rooted.duration = 2
	configs["ROOTED"] = rooted

	var freeze := StatusEffectData.new()
	freeze.effect_type = "FREEZE"
	freeze.description = "Cannot move or act"
	freeze.affected_stat = ""
	freeze.modifier = 0
	freeze.duration = 2
	configs["FREEZE"] = freeze

	var gravity := StatusEffectData.new()
	gravity.effect_type = "GRAVITY"
	gravity.description = "Reduces agility"
	gravity.affected_stat = "agility"
	gravity.modifier = -2
	gravity.duration = 3
	configs["GRAVITY"] = gravity

	var void_effect := StatusEffectData.new()
	void_effect.effect_type = "VOID"
	void_effect.description = "Locks a random move per stack"
	void_effect.affected_stat = ""
	void_effect.modifier = 0
	void_effect.duration = 4
	void_effect.stackable = true
	configs["VOID"] = void_effect

	var subversion := StatusEffectData.new()
	subversion.effect_type = "SUBVERSION"
	subversion.description = "Reduces defense"
	subversion.affected_stat = "defense"
	subversion.modifier = -4
	subversion.duration = 3
	configs["SUBVERSION"] = subversion

	return configs
