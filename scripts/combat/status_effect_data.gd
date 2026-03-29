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
var abbrev_name: String = ""  # Short display name for HUD chips (≤10 chars)
var icon_path: String = ""  # Path to 6x6 icon in art/sprites/ui/status_effect_icons_6x6_v2/


static func get_default_configs() -> Dictionary:
	var configs: Dictionary = {}

	var burn := StatusEffectData.new()
	burn.effect_type = "BURN"
	burn.abbrev_name = "Burn"
	burn.description = "Reduces strength and deals damage each turn"
	burn.affected_stat = "strength"
	burn.modifier = -3
	burn.duration = 4
	burn.is_dot = true
	burn.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/burn_0000.png"
	configs["BURN"] = burn

	var poison := StatusEffectData.new()
	poison.effect_type = "POISON"
	poison.abbrev_name = "Poison"
	poison.description = "Deals damage each turn"
	poison.affected_stat = ""
	poison.modifier = 0
	poison.duration = 4
	poison.is_dot = true
	poison.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/poison_0000.png"
	configs["POISON"] = poison

	var rooted := StatusEffectData.new()
	rooted.effect_type = "ROOTED"
	rooted.abbrev_name = "Rooted"
	rooted.description = "Cannot move"
	rooted.affected_stat = ""
	rooted.modifier = 0
	rooted.duration = 2
	rooted.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/rooted_0000.png"
	configs["ROOTED"] = rooted

	var freeze := StatusEffectData.new()
	freeze.effect_type = "FREEZE"
	freeze.abbrev_name = "Freeze"
	freeze.description = "Cannot move or act"
	freeze.affected_stat = ""
	freeze.modifier = 0
	freeze.duration = 2
	freeze.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/freeze_0000.png"
	configs["FREEZE"] = freeze

	var gravity := StatusEffectData.new()
	gravity.effect_type = "GRAVITY"
	gravity.abbrev_name = "Gravity"
	gravity.description = "Reduces agility"
	gravity.affected_stat = "agility"
	gravity.modifier = -2
	gravity.duration = 3
	gravity.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/gravity_0000.png"
	configs["GRAVITY"] = gravity

	var void_effect := StatusEffectData.new()
	void_effect.effect_type = "VOID"
	void_effect.abbrev_name = "Void"
	void_effect.description = "Locks a random move per stack"
	void_effect.affected_stat = ""
	void_effect.modifier = 0
	void_effect.duration = 4
	void_effect.stackable = true
	void_effect.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/void_0000.png"
	configs["VOID"] = void_effect

	var subversion := StatusEffectData.new()
	subversion.effect_type = "SUBVERSION"
	subversion.abbrev_name = "Subvert"
	subversion.description = "Reduces defense"
	subversion.affected_stat = "defense"
	subversion.modifier = -4
	subversion.duration = 3
	subversion.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/subversion_0000.png"
	configs["SUBVERSION"] = subversion

	var bleed := StatusEffectData.new()
	bleed.effect_type = "BLEED"
	bleed.abbrev_name = "Bleed"
	bleed.description = "Deals damage each turn"
	bleed.affected_stat = ""
	bleed.modifier = 0
	bleed.duration = 3
	bleed.is_dot = true
	bleed.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/bleed_0000.png"
	configs["BLEED"] = bleed

	var bugle := StatusEffectData.new()
	bugle.effect_type = "BUGLE"
	bugle.abbrev_name = "Bugle"
	bugle.description = "Takes extra damage from heraldic moves"
	bugle.affected_stat = ""
	bugle.modifier = 0
	bugle.duration = 3
	bugle.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/bugle_0000.png"
	configs["BUGLE"] = bugle

	var chain_lightning := StatusEffectData.new()
	chain_lightning.effect_type = "CHAIN_LIGHTNING"
	chain_lightning.abbrev_name = "Chain L."
	chain_lightning.description = "Spreads reduced damage to adjacent units"
	chain_lightning.affected_stat = ""
	chain_lightning.modifier = 0
	chain_lightning.duration = 1
	chain_lightning.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/chain_lightning_0000.png"
	configs["CHAIN_LIGHTNING"] = chain_lightning

	var challenged := StatusEffectData.new()
	challenged.effect_type = "CHALLENGED"
	challenged.abbrev_name = "Chal."
	challenged.description = "Draws aggro, must target challenger if nearby"
	challenged.affected_stat = ""
	challenged.modifier = 0
	challenged.duration = 3
	challenged.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/challenged_0000.png"
	configs["CHALLENGED"] = challenged

	var critical := StatusEffectData.new()
	critical.effect_type = "CRITICAL"
	critical.abbrev_name = "Crit"
	critical.description = "Next attack deals double damage"
	critical.affected_stat = ""
	critical.modifier = 0
	critical.duration = 1
	critical.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/critical_0000.png"
	configs["CRITICAL"] = critical

	var shocked := StatusEffectData.new()
	shocked.effect_type = "SHOCKED"
	shocked.abbrev_name = "Shocked"
	shocked.description = "Reduced accuracy, chance to skip turn"
	shocked.affected_stat = ""
	shocked.modifier = 0
	shocked.duration = 2
	shocked.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/shocked_0000.png"
	configs["SHOCKED"] = shocked

	var vulnerable := StatusEffectData.new()
	vulnerable.effect_type = "VULNERABLE"
	vulnerable.abbrev_name = "Vuln."
	vulnerable.description = "Takes increased damage"
	vulnerable.affected_stat = "defense"
	vulnerable.modifier = -5
	vulnerable.duration = 3
	vulnerable.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/vulnerable_0000.png"
	configs["VULNERABLE"] = vulnerable

	return configs
