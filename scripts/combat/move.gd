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
# Which factions an area_of_effect > 0 move touches, relative to the CASTER
# (JSON: aoeAffects). "enemies" (default) | "allies" | "all". The caster is
# never a victim of their own AoE.
@export var aoe_affects: String = "enemies"
# CombatPredicates name (JSON: immune). Units matching it are passed over by
# this move entirely — AoE gathering skips them, riders skip them. ("brave"
# for Shriek of the Damned; empty = nobody is immune.)
@export var immune_predicate: String = ""

# Animation style hint (JSON key: animationStyle). "auto" derives from
# attack_range (>= 2 reads as ranged); "melee"/"ranged" force the clip family
# regardless of the distance the move is actually used at — e.g. a range-2
# spear thrust that should still look like a stab tags itself "melee".
@export var animation_style: String = "auto"

# Damage
@export var base_power: int = 0
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
@export var element_type: Enums.ElementalType = Enums.ElementalType.NONE

# Base hit chance before stat modifiers. Final hit % is computed in
# DamageCalculator.hit_chance_pct using the RD formula
# (accuracy + 1.5×skill − 1.5×agility + passive modifiers).
# Default 90 matches Fire Emblem's "reliable basic weapon" baseline.
@export var accuracy: int = 90

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

# Conditional-by-target status (Phase 4). Alternative to the flat status fields
# above — the applied effect depends on a predicate evaluated per TARGET.
# Normalized by MoveData from JSON statusEffect.conditional into:
#   { "predicate": String,                       # CombatPredicates name ("brave")
#     "then": { "effect": String (UPPER), "chance": float 0-1,
#               "stacks": int, "replaces": bool },
#     "else": { ...same shape... } }
# Either branch may be {} = "apply nothing to these targets". Empty dict = no
# conditional. Resolved by ConditionalAfflictionEffect in the pipeline.
# (Roar: brave → CHALLENGED, everyone else → SHOCKED.)
@export var status_conditional: Dictionary = {}

# Secondary crit. Crit is NOT a status — it's a one-time damage doubling resolved
# by CritEffect in the combat pipeline. A move's secondary slot holds EITHER a
# status effect OR crit (mutually exclusive). crit_chance > 0 means the secondary
# is crit. When crit_self_target is true (JSON target: "self"), a successful roll
# BANKS a crit on the caster (pending_crit) for their next attack — e.g. Focus,
# Uppercut. Otherwise a successful roll crits THIS hit.
@export var crit_chance: float = 0.0
@export var crit_self_target: bool = false

# On-hit displacement (instant, non-lingering). 0 = no displacement.
# Resolved by DisplacementSystem after damage — its header is the living doc for
# the full schema (subjects, shapes, vectors, contest saves, blocked policies).
@export var displace_distance: int = 0
@export var displace_subject: String = "target"  # target | self | others_in_shape
@export var displace_shape: String = "single"  # single | line(N) | row(N) | ring(N)
@export var displace_vector: String = ""  # away/toward_attacker, away/toward_target, away/toward_point, rotate_cw/ccw
@export var displace_contest_stat: String = ""  # "" = no save; else a CharacterData stat (constitution)
@export var displace_contest_margin: int = 0  # displaced when caster.stat - subject.stat > margin
@export var displace_on_blocked: String = "stop"  # stop | swap | bonus_damage | fall_through | push_chain

# Healing. When true, the move heals the target instead of dealing damage.
# Heal amount = caster.special + base_power (matches the Unity formula for First Aid).
@export var heals: bool = false

# Status effects to remove from the target on hit (e.g. "BLEED" to cure a wound).
# Names match Enums.StatusEffectType keys (case-insensitive — normalized in MoveData).
@export var cleanse_effects: PackedStringArray = PackedStringArray()

# Scheduled effect (Phase 4): something happens N turns AFTER this move hits.
# Normalized by MoveData from JSON onHit.scheduled into:
#   { "effect": String,        # ScheduledEffects handler name ("chain_lightning_strike")
#     "delay": int,            # full turns until it fires (ticks on the CASTER's
#                              #   faction phase start, so victims get exactly
#                              #   `delay` of their own turns to react)
#     "marker": String (UPPER),# status stamped on the victim as the visible
#                              #   telegraph; cleansing it DEFUSES the strike
#     "params": Dictionary }   # handler-specific knobs (power, splashPct, ...)
# Empty dict = nothing scheduled. Applied by ScheduleEffectHandler in the
# pipeline; ticked + fired by ScheduledEffects. (Shriek of the Damned.)
@export var scheduled_effect: Dictionary = {}


## True if this move targets allies (ALLY or ALLY_NOT_SELF). Used by
## InputManager + Unit to flip faction checks during target selection,
## and to skip counter-attacks during combat resolution.
func targets_allies() -> bool:
	return target_type == Enums.TargetType.ALLY or target_type == Enums.TargetType.ALLY_NOT_SELF


## Resolves the animation_style hint to a concrete "melee" or "ranged".
## Drives attack-clip selection: a ranged move fired point-blank should still
## read as a shot, not a sword swing. See Unit.select_styled_attack_clip.
func effective_animation_style() -> String:
	if animation_style == "melee" or animation_style == "ranged":
		return animation_style
	return "ranged" if attack_range >= 2 else "melee"


## The game-wide melee/ranged classification of this move. Animations AND
## gameplay (e.g. Crater's defense split: bonus vs melee, penalty vs ranged)
## read this one source of truth, so it's a property of the MOVE — a Laser
## fired point-blank is still a ranged attack.
func is_ranged_style() -> bool:
	return effective_animation_style() == "ranged"


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

	# Self-cast AoE (Roar, Shriek): the payload lands on OTHER units around the
	# caster, so "meaningful" = at least one victim inside the radius right now.
	# The action menu runs this after movement, so the position is final — a
	# Roar with nobody in earshot greys out instead of burning PP on silence.
	# Off-grid targets (bare test units) can't be position-checked; let them fly.
	if target_type == Enums.TargetType.SELF and area_of_effect > 0:
		if target.current_tile == null:
			return true
		return not MoveTargeting.get_area_victims(target, target.current_tile, self).is_empty()

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


## Give a use back, capped at max_uses. Used by Waste Not (recover PP on kill).
func refund_use() -> void:
	current_uses = mini(max_uses, current_uses + 1)


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
