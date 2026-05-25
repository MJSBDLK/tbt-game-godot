## Radiant Dawn–style combat XP formula. Single source of truth for how much
## experience a player unit earns from a combat action.
##
## Formula:
##   internal_level(unit) = level + (tier - 1) * TIER_LEVEL_BOOST
##   base = BASE_HIT_XP, plus KILL_BONUS if the action killed the target
##   raw = base + internal_level(target) - internal_level(attacker)
##   xp = clamp(raw, MIN_XP, MAX_XP)
##
## Healing is a flat HEAL_XP — RD uses a flat rate for staff casts. Will likely
## want to scale by amount-relative-to-target-max later, but match RD now and
## tune from there.
##
## See conversation in [.claude/](.claude/) for design discussion. Tier is
## stubbed at 1 for every character right now (promotion mechanics don't
## exist); the formula already handles it the moment we wire promotion.
class_name CombatXpCalculator


const BASE_HIT_XP: int = 10
const KILL_BONUS: int = 20
const HEAL_XP: int = 10

# Each tier above 1 adds this much to internal-level. RD uses 20 — keeps the
# "promotion = level reset" feeling without making post-promotion units gain
# nothing for a few maps.
const TIER_LEVEL_BOOST: int = 20

# Clamps applied to every grant. MIN_XP is the RD "you did something" floor;
# MAX_XP keeps a giant level gap from one-shotting the bar.
const MIN_XP: int = 1
const MAX_XP: int = 100


## XP for a hit. `killed` should be true when the hit reduced the target to 0
## HP (regardless of who took the killing blow's credit — this caller already
## knows). Both inputs may be null in edge cases (enemies without
## character_data, etc.); caller is expected to guard.
static func compute_combat_xp(attacker: CharacterData, target: CharacterData, killed: bool) -> int:
	if attacker == null or target == null:
		return MIN_XP
	var base: int = BASE_HIT_XP + (KILL_BONUS if killed else 0)
	var diff: int = _internal_level(target) - _internal_level(attacker)
	return clampi(base + diff, MIN_XP, MAX_XP)


## XP for a successful heal cast. Healer and target aren't currently used —
## present so the signature can later read a fraction-of-max-HP scaling rule
## without breaking call sites.
static func compute_heal_xp(_healer: CharacterData, _target: CharacterData) -> int:
	return HEAL_XP


static func _internal_level(data: CharacterData) -> int:
	return data.level + (data.tier - 1) * TIER_LEVEL_BOOST
