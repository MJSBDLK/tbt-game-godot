## Combat XP formula. Single source of truth for how much experience a player
## unit earns from any XP-bearing action. Doctrine lives in
## [.claude/mission_objectives.md] "XP Economy"; the derivation and the
## three-formula comparison behind the current shape are in
## [data/design/class-and-promotion.md] §4.
##
## Combat hits — EXPONENTIAL DECAY (adopted 2026-08-05, values PROVISIONAL):
##   base = KILL_BASE_XP if the action killed, else HIT_BASE_XP
##   xp   = max(MIN_XP, round(base * 2 ^ ((target.level - attacker.level) / K)))
## In words: start from the base award, then DOUBLE it for every K levels the
## enemy is above you — or HALVE it for every K levels you are above them.
##
## This replaced the Radiant Dawn difference formula (`base + their_lv -
## your_lv`), which was structurally incapable of a jackpot: its natural
## maximum was 89 XP, under a single level, for the most extreme kill in the
## game. The exponential decays asymptotically AND scales up, which is what
## makes fielding an underlevelled unit pay for itself. At squad mean 25 a
## rookie 15 levels down earns 4x what the carry 15 levels up earns; the
## difference formula paid only 1.5x, which doesn't cover a rookie's real cost
## in kills forgone and injury risk. The funnel has to be worth walking into
## without being told about it.
##
## A level always costs a flat 100 XP (CharacterData.grant_xp) at every level
## in every tier. Catch-up lives ENTIRELY in the award, never in the price.
##
## No ceiling by design. The 1-60 level range bounds the formula on its own
## (the most extreme kill possible, Lv 1 killing Lv 60, tops out near 1200 XP);
## the retired MAX_XP = 100 clamp was a fake limit that never bound anything
## under the old formula either.
##
## Every dial here is PROVISIONAL — the shape is settled, the numbers are a
## starting position awaiting playtest. K is expected to move most: down if
## players don't feel the pull toward rookies, up if the carry stalling reads
## as punishment rather than diminishing returns.
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
## Tier deliberately does NOT appear in this file. It used to, via an
## `internal_level = level + (tier - 1) * 20` indirection borrowed from Fire
## Emblem — a normalization device that exists because FE RESETS a unit's level
## to 1 on promotion. Our scale is continuous 1-60 with no reset, so that term
## double-counted: it would have cut kill XP ~70% at levels 21 and 41, reading
## to the player as an invisible punishment for promoting. Class choice must
## change what a unit does, never how fast it grows. Don't reintroduce it.
class_name CombatXpCalculator


# Two separate base awards, not a base plus a bonus — a kill and a chip hit are
# different actions, and the design doc tunes them as independent dials. The
# 27 : 80 ratio preserves the old 10 : 30 feel.
const HIT_BASE_XP: int = 27
const KILL_BASE_XP: int = 80
const HEAL_XP: int = 10
const SUPPORT_XP: int = 10

# Levels of gap that double (or halve) a combat award. Smaller K = steeper
# funnel toward fielding underlevelled units. THE dial to move first.
const LEVEL_GAP_TO_DOUBLE: float = 15.0

# Survival awards run smaller than hit awards (surviving is passive) and cap
# well under a hit — an on-level enemy pays SURVIVAL_BASE_XP, a scary one
# pays up to the cap, a harmless one decays to the floor.
const SURVIVAL_BASE_XP: int = 5
const SURVIVAL_MAX_XP: int = 15

# The "you did something" floor. Every XP-bearing action pays at least this,
# so overlevelled gains decay toward 1 but never reach zero.
const MIN_XP: int = 1


## XP for a hit. `killed` should be true when the hit reduced the target to 0
## HP (regardless of who took the killing blow's credit — this caller already
## knows). Both inputs may be null in edge cases (enemies without
## character_data, etc.); caller is expected to guard.
static func compute_combat_xp(attacker: CharacterData, target: CharacterData, killed: bool) -> int:
	if attacker == null or target == null:
		return MIN_XP
	var base: int = KILL_BASE_XP if killed else HIT_BASE_XP
	var raw: float = float(base) * _decay_multiplier(target.level, attacker.level)
	return maxi(MIN_XP, int(roundf(raw)))


## 2 ^ (gap / K) — doubles per K levels the target is above the earner, halves
## per K levels below. Shared by every level-scaled award so the curve can only
## be tuned in one place.
static func _decay_multiplier(their_level: int, your_level: int) -> float:
	return pow(2.0, float(their_level - your_level) / LEVEL_GAP_TO_DOUBLE)


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
##
## Deliberately still the DIFFERENCE formula while hits went exponential — not
## an oversight. The exponential exists to make player CHOICES pay (field the
## rookie, pick that target); being attacked is not a choice, so the funnel
## argument doesn't reach here. Combined with a cap at 3x the base, the award
## is too small and too tightly bounded for the formula family to matter.
static func compute_survival_xp(survivor: CharacterData, attacker: CharacterData) -> int:
	if survivor == null or attacker == null:
		return MIN_XP
	var diff: int = attacker.level - survivor.level
	return clampi(SURVIVAL_BASE_XP + diff, MIN_XP, SURVIVAL_MAX_XP)
