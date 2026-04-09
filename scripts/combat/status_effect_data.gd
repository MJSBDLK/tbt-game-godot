## Template configuration for status effect types.
## All effects use a unified stack model — there is no separate "duration" field.
## Stacks tick down according to tick_trigger. Effect persists while stacks > 0.
class_name StatusEffectData
extends RefCounted


var effect_type: String = ""
var category: Enums.EffectCategory = Enums.EffectCategory.DEBUFF
var description: String = ""

# Stat effect (% of unmodified stat per stack). 0 if not a stat-affecting effect.
# Stat name uses CharacterData field names: "strength", "defense", "agility", etc.
var affected_stat: String = ""
var pct_per_stack: float = 0.0  # e.g. -10.0 for -10% per stack

# Damage-over-time. dot_damage_per_stack > 0 means the effect ticks DoT each tick.
# Currently the runtime caches the damage value at apply time using caster level.
var dot_damage_per_stack: int = 0  # 0 = not a DoT

# Heal-over-time. hot_heal_per_stack > 0 means the effect heals on each tick.
# Mutually exclusive with dot_damage_per_stack.
var hot_heal_per_stack: int = 0  # 0 = not a HoT

# Stack behavior
var max_stacks: int = 4
var default_apply_stacks: int = 1  # how many stacks a "generic" application adds
var tick_trigger: String = "turn_start"  # "turn_start" | "turn_end" | "on_attack"

# Display
var abbrev_name: String = ""  # Short display name for HUD chips (≤10 chars)
var icon_path: String = ""    # Path to 6x6 icon in art/sprites/ui/status_effect_icons_6x6_v2/


static func get_default_configs() -> Dictionary:
	var configs: Dictionary = {}

	# =========================================================================
	# BUFFS
	# =========================================================================

	var bellows := StatusEffectData.new()
	bellows.effect_type = "BELLOWS"
	bellows.category = Enums.EffectCategory.BUFF
	bellows.abbrev_name = "Bellows"
	bellows.description = "Fire moves deal +25% damage per stack. Gained when a unit with the Bellows passive takes air-type attack damage."
	bellows.max_stacks = 4
	bellows.default_apply_stacks = 1
	bellows.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/bellows_0000.png"
	configs["BELLOWS"] = bellows

	var critical := StatusEffectData.new()
	critical.effect_type = "CRITICAL"
	critical.category = Enums.EffectCategory.BUFF
	critical.abbrev_name = "Crit"
	critical.description = "Next attack deals double damage."
	critical.max_stacks = 1
	critical.default_apply_stacks = 1
	critical.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/critical_0000.png"
	configs["CRITICAL"] = critical

	var rallied := StatusEffectData.new()
	rallied.effect_type = "RALLIED"
	rallied.category = Enums.EffectCategory.BUFF
	rallied.abbrev_name = "Rallied"
	rallied.description = "Increases strength."
	rallied.affected_stat = "strength"
	rallied.pct_per_stack = 10.0
	rallied.max_stacks = 4
	rallied.default_apply_stacks = 4
	rallied.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/rallied_0000.png"
	configs["RALLIED"] = rallied

	var fortified := StatusEffectData.new()
	fortified.effect_type = "FORTIFIED"
	fortified.category = Enums.EffectCategory.BUFF
	fortified.abbrev_name = "Fortify"
	fortified.description = "Increases defense."
	fortified.affected_stat = "defense"
	fortified.pct_per_stack = 10.0
	fortified.max_stacks = 4
	fortified.default_apply_stacks = 4
	fortified.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/fortified_0000.png"
	configs["FORTIFIED"] = fortified

	var hasted := StatusEffectData.new()
	hasted.effect_type = "HASTED"
	hasted.category = Enums.EffectCategory.BUFF
	hasted.abbrev_name = "Hasted"
	hasted.description = "Increases agility."
	hasted.affected_stat = "agility"
	hasted.pct_per_stack = 10.0
	hasted.max_stacks = 4
	hasted.default_apply_stacks = 4
	hasted.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/hasted_0000.png"
	configs["HASTED"] = hasted

	var focused := StatusEffectData.new()
	focused.effect_type = "FOCUSED"
	focused.category = Enums.EffectCategory.BUFF
	focused.abbrev_name = "Focus"
	focused.description = "Increases skill (accuracy)."
	focused.affected_stat = "skill"
	focused.pct_per_stack = 10.0
	focused.max_stacks = 4
	focused.default_apply_stacks = 4
	focused.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/focused_0000.png"
	configs["FOCUSED"] = focused

	var regen := StatusEffectData.new()
	regen.effect_type = "REGEN"
	regen.category = Enums.EffectCategory.BUFF
	regen.abbrev_name = "Regen"
	regen.description = "Heals each turn."
	regen.hot_heal_per_stack = 1  # placeholder; runtime recomputes from caster level
	regen.max_stacks = 4
	regen.default_apply_stacks = 4
	regen.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/regen_0000.png"
	configs["REGEN"] = regen

	# =========================================================================
	# DEBUFFS
	# =========================================================================

	var burn := StatusEffectData.new()
	burn.effect_type = "BURN"
	burn.category = Enums.EffectCategory.DEBUFF
	burn.abbrev_name = "Burn"
	burn.description = "Reduces strength and deals damage each turn."
	burn.affected_stat = "strength"
	burn.pct_per_stack = -10.0
	burn.dot_damage_per_stack = 1  # placeholder; runtime recomputes from caster level
	burn.max_stacks = 4
	burn.default_apply_stacks = 4
	burn.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/burn_0000.png"
	configs["BURN"] = burn

	var poison := StatusEffectData.new()
	poison.effect_type = "POISON"
	poison.category = Enums.EffectCategory.DEBUFF
	poison.abbrev_name = "Poison"
	poison.description = "Deals damage each turn."
	poison.dot_damage_per_stack = 1
	poison.max_stacks = 4
	poison.default_apply_stacks = 4
	poison.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/poison_0000.png"
	configs["POISON"] = poison

	var bleed := StatusEffectData.new()
	bleed.effect_type = "BLEED"
	bleed.category = Enums.EffectCategory.DEBUFF
	bleed.abbrev_name = "Bleed"
	bleed.description = "Deals damage each turn."
	bleed.dot_damage_per_stack = 1
	bleed.max_stacks = 3
	bleed.default_apply_stacks = 3
	bleed.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/bleed_0000.png"
	configs["BLEED"] = bleed

	var rooted := StatusEffectData.new()
	rooted.effect_type = "ROOTED"
	rooted.category = Enums.EffectCategory.DEBUFF
	rooted.abbrev_name = "Rooted"
	rooted.description = "Cannot move."
	rooted.max_stacks = 2
	rooted.default_apply_stacks = 2
	rooted.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/rooted_0000.png"
	configs["ROOTED"] = rooted

	var freeze := StatusEffectData.new()
	freeze.effect_type = "FREEZE"
	freeze.category = Enums.EffectCategory.DEBUFF
	freeze.abbrev_name = "Freeze"
	freeze.description = "Cannot move or act."
	freeze.max_stacks = 2
	freeze.default_apply_stacks = 2
	freeze.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/freeze_0000.png"
	configs["FREEZE"] = freeze

	var gravity := StatusEffectData.new()
	gravity.effect_type = "GRAVITY"
	gravity.category = Enums.EffectCategory.DEBUFF
	gravity.abbrev_name = "Gravity"
	gravity.description = "Reduces agility."
	gravity.affected_stat = "agility"
	gravity.pct_per_stack = -10.0
	gravity.max_stacks = 3
	gravity.default_apply_stacks = 3
	gravity.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/gravity_0000.png"
	configs["GRAVITY"] = gravity

	var void_effect := StatusEffectData.new()
	void_effect.effect_type = "VOID"
	void_effect.category = Enums.EffectCategory.DEBUFF
	void_effect.abbrev_name = "Void"
	void_effect.description = "Locks a random move per stack."
	void_effect.max_stacks = 4
	void_effect.default_apply_stacks = 1
	void_effect.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/void_0000.png"
	configs["VOID"] = void_effect

	var subversion := StatusEffectData.new()
	subversion.effect_type = "SUBVERSION"
	subversion.category = Enums.EffectCategory.DEBUFF
	subversion.abbrev_name = "Subvert"
	subversion.description = "Reduces defense."
	subversion.affected_stat = "defense"
	subversion.pct_per_stack = -10.0
	subversion.max_stacks = 3
	subversion.default_apply_stacks = 3
	subversion.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/subversion_0000.png"
	configs["SUBVERSION"] = subversion

	var vulnerable := StatusEffectData.new()
	vulnerable.effect_type = "VULNERABLE"
	vulnerable.category = Enums.EffectCategory.DEBUFF
	vulnerable.abbrev_name = "Vuln."
	vulnerable.description = "Reduces resistance to special attacks."
	vulnerable.affected_stat = "resistance"
	vulnerable.pct_per_stack = -10.0
	vulnerable.max_stacks = 3
	vulnerable.default_apply_stacks = 3
	vulnerable.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/vulnerable_0000.png"
	configs["VULNERABLE"] = vulnerable

	var shocked := StatusEffectData.new()
	shocked.effect_type = "SHOCKED"
	shocked.category = Enums.EffectCategory.DEBUFF
	shocked.abbrev_name = "Shocked"
	shocked.description = "Reduces accuracy and may cause skipped turns."
	shocked.affected_stat = "skill"
	shocked.pct_per_stack = -10.0
	shocked.max_stacks = 2
	shocked.default_apply_stacks = 2
	shocked.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/shocked_0000.png"
	configs["SHOCKED"] = shocked

	var bugle := StatusEffectData.new()
	bugle.effect_type = "BUGLE"
	bugle.category = Enums.EffectCategory.DEBUFF
	bugle.abbrev_name = "Bugle"
	bugle.description = "Takes extra damage from heraldic moves."
	bugle.max_stacks = 3
	bugle.default_apply_stacks = 3
	bugle.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/bugle_0000.png"
	configs["BUGLE"] = bugle

	var chain_lightning := StatusEffectData.new()
	chain_lightning.effect_type = "CHAIN_LIGHTNING"
	chain_lightning.category = Enums.EffectCategory.DEBUFF
	chain_lightning.abbrev_name = "Chain L."
	chain_lightning.description = "Spreads reduced damage to adjacent units."
	chain_lightning.max_stacks = 1
	chain_lightning.default_apply_stacks = 1
	chain_lightning.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/chain_lightning_0000.png"
	configs["CHAIN_LIGHTNING"] = chain_lightning

	var challenged := StatusEffectData.new()
	challenged.effect_type = "CHALLENGED"
	challenged.category = Enums.EffectCategory.DEBUFF
	challenged.abbrev_name = "Chal."
	challenged.description = "Draws aggro, must target challenger if nearby."
	challenged.max_stacks = 3
	challenged.default_apply_stacks = 3
	challenged.icon_path = "res://art/sprites/ui/status_effect_icons_6x6_v2/challenged_0000.png"
	configs["CHALLENGED"] = challenged

	return configs
