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
