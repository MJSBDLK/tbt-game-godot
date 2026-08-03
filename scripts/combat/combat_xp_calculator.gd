## Radiant Dawn–style combat XP formula. Single source of truth for how much
## experience a player unit earns from any XP-bearing action. Doctrine lives
## in [.claude/mission_objectives.md] "XP Economy" (locked 2026-08-03).
##
## Combat hits:
##   internal_level(unit) = level + (tier - 1) * TIER_LEVEL_BOOST
##   base = BASE_HIT_XP, plus KILL_BONUS if the action killed the target
##   raw = base + internal_level(target) - internal_level(attacker)
##   xp = clamp(raw, MIN_XP, MAX_XP)
## The differential IS the rubber band: underleveled units earn multiples of
## what the squad's carry earns from the same enemy, while a level always
## costs a flat 100 (CharacterData.grant_xp) — overleveled gains decay to
## the MIN_XP floor with no extra rule.
##
## Healing is a flat HEAL_XP — RD uses a flat rate for staff casts. Will likely
## want to scale by amount-relative-to-target-max later, but match RD now and
## tune from there. Non-heal support casts (buffs, cleanses, Roar) pay the
## same flat rate ONCE PER CAST — participation without requiring harm's way.
## No-op casts can't reach execution (has_meaningful_effect_on gates
## targeting), so a cast that runs is a cast that mattered.
##
## Survival XP (2026-08-03): the FIRST time each enemy engages a unit per
## battle, the defender earns a small level-diff-scaled award — the
## healer-survives-the-hit and back-to-back-dodge moments finally pay.
## Tank or dodge, surviving is the lesson; repeat engagements from the same
## enemy teach nothing (Unit tracks sources), so parking a unit next to a
## harmless enemy pays ~MIN_XP once and then zero forever. North star:
## never incentivize stalling.
##
## Tier is stubbed at 1 for every character right now (promotion mechanics
## don't exist); the formula already handles it the moment we wire promotion.
class_name CombatXpCalculator


const BASE_HIT_XP: int = 10
const KILL_BONUS: int = 20
const HEAL_XP: int = 10
const SUPPORT_XP: int = 10

# Survival awards run smaller than hit awards (surviving is passive) and cap
# well under a hit — an on-level enemy pays SURVIVAL_BASE_XP, a scary one
# pays up to the cap, a harmless one decays to the floor.
const SURVIVAL_BASE_XP: int = 5
const SURVIVAL_MAX_XP: int = 15

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


## XP for a non-heal support cast (buff, cleanse, shout). Flat, once per
## cast regardless of how many AoE victims it reached — a 5-victim Roar is
## one cast, not five. Caster/move unused for now; present for later scaling.
static func compute_support_xp(_caster: CharacterData, _move: Move) -> int:
	return SUPPORT_XP


## XP for surviving an enemy's engagement (tank or dodge — both count).
## Scaled by how scary the attacker is relative to the survivor: an
## above-level enemy pays more, a harmless one decays to the MIN_XP floor.
static func compute_survival_xp(survivor: CharacterData, attacker: CharacterData) -> int:
	if survivor == null or attacker == null:
		return MIN_XP
	var diff: int = _internal_level(attacker) - _internal_level(survivor)
	return clampi(SURVIVAL_BASE_XP + diff, MIN_XP, SURVIVAL_MAX_XP)


static func _internal_level(data: CharacterData) -> int:
	return data.level + (data.tier - 1) * TIER_LEVEL_BOOST
