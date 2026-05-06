## Runtime data container for an equipped move (Pokemon-style).
## Each unit gets its own Move instances so PP tracking is per-unit.
## Combat execution is Phase 3 — this is data structure only.
class_name Move
extends Resource


# Identity
@export var move_name: String = ""
@export var abbrev_name: String = ""
@export var move_id: String = ""
@export var description: String = ""

# Targeting
@export var attack_range: int = 1
@export var area_of_effect: int = 0
@export var target_type: Enums.TargetType = Enums.TargetType.SINGLE

# Damage
@export var base_power: int = 0
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
@export var element_type: Enums.ElementalType = Enums.ElementalType.NONE

# PP system (limited uses per mission)
@export var max_uses: int = 30
var current_uses: int = 0

# Status effect (data only, not executed until Phase 3)
@export var status_effect_type: Enums.StatusEffectType = Enums.StatusEffectType.NONE
@export var status_effect_chance: float = 0.0
# Number of stacks applied on a successful proc. 0 = use the effect's default_apply_stacks.
@export var status_effect_stacks: int = 0
# If true, this move's status effect bypasses the same-category-immunity rule and overwrites
# any existing buff (if effect is a buff) or debuff (if effect is a debuff).
@export var status_effect_replaces: bool = false
# If true, the status effect applies to the caster instead of the move's target.
# This is how rider buffs work — a damage move that buffs the user on hit.
@export var status_effect_self_target: bool = false

# On-hit displacement (instant, non-lingering). 0 = no displacement.
# Resolved by DisplacementSystem after damage. Save formula: target fails when
# the chosen dc_source on the hit exceeds target.<displace_save_stat>.
@export var displace_distance: int = 0
@export var displace_vector: String = ""  # away_from_attacker, toward_attacker, attacker_facing, from_aoe_center
@export var displace_save_stat: String = ""  # CharacterData property name (constitution, athleticism, ...)
@export var displace_save_dc_source: String = ""  # damage, base_power
@export var displace_on_blocked: String = "stop"  # stop, bonus_damage, swap, fall_through

# Escape hatch for complex on-hit effects that can't be expressed declaratively
# (e.g. gravity orbits). Path to a script with a static resolve(caster, target, move, damage) method.
# Not yet wired — DisplacementSystem will warn if set.
@export var on_hit_script: String = ""

# Healing. When true, the move heals the target instead of dealing damage.
# Heal amount = caster.special + base_power (matches the Unity formula for First Aid).
@export var heals: bool = false

# Status effects to remove from the target on hit (e.g. "BLEED" to cure a wound).
# Names match Enums.StatusEffectType keys (case-insensitive — normalized in MoveData).
@export var cleanse_effects: PackedStringArray = PackedStringArray()


## Hit chance % (0-100). Placeholder until an accuracy stat lands on Move
## or CharacterData. Currently every move is deterministic — returns 100. The
## combat preview reads this so the displayed Hit% matches reality without the
## panel having to assume.
func hit_chance_pct() -> int:
	return 100


## True if this move targets allies (ALLY or ALLY_NOT_SELF). Used by
## InputManager + Unit to flip faction checks during target selection,
## and to skip counter-attacks during combat resolution.
func targets_allies() -> bool:
	return target_type == Enums.TargetType.ALLY or target_type == Enums.TargetType.ALLY_NOT_SELF


## Returns true if this move would have a meaningful effect on `target`.
## Drives both the action menu's "should this chip appear" decision and the
## in-targeting valid-tile filter, so users never see a move that lights up
## no tiles (or a highlighted tile that does nothing).
##
## Damage moves: always meaningful against any valid target (faction filter
## already handled upstream). Heals require the target to be below max HP.
## Cleanse-only moves require the target to actually carry one of the cleanse
## effects. Buff-only moves require the target not to be at max stacks of the
## buff already.
func has_meaningful_effect_on(target: Unit) -> bool:
	if target == null:
		return false

	# Heal: target must be missing at least 1 HP.
	if heals:
		if target.character_data != null and target.current_hp >= target.character_data.max_hp:
			return false

	# Determine if this move has any "primary" effect besides the status/cleanse.
	# A move with base_power > 0 deals damage; heals deal healing. Either counts
	# as a primary effect that always lands. If neither is true, the move's only
	# job is the status/cleanse, and we filter on that being applicable.
	var has_primary_effect: bool = base_power > 0 or heals

	# Cleanse-only: require at least one of the listed effects to be active.
	if not has_primary_effect and not cleanse_effects.is_empty():
		var any_cleanse_applicable: bool = false
		for effect_name: String in cleanse_effects:
			if _target_has_status_effect(target, effect_name):
				any_cleanse_applicable = true
				break
		if not any_cleanse_applicable:
			return false

	# Buff/debuff-only: skip targets already at max stacks of this effect.
	# Self-targeted status (rider buffs on damage moves) is filtered by the
	# has_primary_effect check above, so don't double-process here.
	if not has_primary_effect and status_effect_type != Enums.StatusEffectType.NONE \
			and not status_effect_self_target:
		if _target_at_max_stacks_of(target, status_effect_type):
			return false

	return true


func _target_has_status_effect(target: Unit, effect_name: String) -> bool:
	var effects: Array = target.active_status_effects
	var normalized := effect_name.to_upper()
	for effect: StatusEffect in effects:
		if effect.effect_type_name.to_upper() == normalized:
			return true
	return false


func _target_at_max_stacks_of(target: Unit, effect_type: Enums.StatusEffectType) -> bool:
	var configs: Dictionary = StatusEffectData.get_default_configs()
	var effect_name: String = Enums.StatusEffectType.keys()[effect_type]
	var config: StatusEffectData = configs.get(effect_name, null)
	if config == null:
		return false  # Unknown config — let it fly
	for effect: StatusEffect in target.active_status_effects:
		if effect.effect_type_name.to_upper() == effect_name.to_upper():
			return effect.stacks >= config.max_stacks
	return false  # Target doesn't have the effect — applying it is meaningful


static var EMPTY: Move:
	get:
		var move := Move.new()
		move.move_name = "—"
		move.abbrev_name = "—"
		move.move_id = "empty"
		move.description = "No move equipped."
		move.max_uses = 0
		move.current_uses = 0
		return move


func _init() -> void:
	current_uses = max_uses


func reset_uses() -> void:
	current_uses = max_uses


func has_uses_remaining() -> bool:
	return current_uses > 0


func consume_use() -> void:
	current_uses = maxi(0, current_uses - 1)


## PP tier calculation matching Unity's formula.
## Lower power = more uses, higher power = fewer uses.
static func calculate_max_uses_from_power(power: int) -> int:
	if power <= 3:
		return 30
	elif power <= 7:
		return 15
	elif power <= 11:
		return 8
	else:
		return 5
