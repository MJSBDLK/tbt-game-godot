# Class & Promotion System

**Status: design doc, nothing implemented.** The `Enums.CharacterClass` list exists;
everything else described here is unbuilt. Written 2026-08-05 from an RQD design
session.

This doc is the source of truth for the class/tier/promotion system. It
**supersedes** the scattered class references in
[character-system.md](character-system.md) — specifically its "class evolution
paths" language, "Retention on Reclass," and the `Class Level 2/3: choose +10% /
−10%` specialization model, which describes a different promotion design than the
one below. Those sections should be pruned when this lands.

Markers: **[DECIDED]** RQD call · **[RECOMMENDED]** proposal awaiting RQD ·
**[OPEN]** genuinely undecided.

---

## 1. The level scale

**[DECIDED] Levels run 1–60, continuously. Tiers are bands on that one scale:**

| Tier | Levels |
|---|---|
| 1 (base class) | 1–20 |
| 2 (first promotion) | 21–40 |
| 3 (second promotion) | 41–60 |

**[DECIDED] Promotion does NOT reset level.** A unit that promotes at 21 is level
21, not level 1. This is a deliberate divergence from Fire Emblem, where classing
up resets to level 1 and the game needs an "internal level" concept to compare
across tiers.

**[DECIDED] Promotion is forced** at the tier boundary. An eligibility variant —
stay in the lower-tier class past 20, become *eligible* to promote from 21 — was
considered and **tabled**, but may be revisited.

**[OPEN]** Whether level 0 exists. Current thinking is no. Not load-bearing.

### Why the continuous scale matters mechanically

Because level is continuous and never resets, **level is directly comparable
across the entire roster** with no normalization. A level-35 unit and a level-12
unit can be compared by subtraction. That property is what lets the XP formula
stay simple (§4), and it's lost the moment anything else gets folded into the
comparison.

---

## 2. Promotion is a choice

**[DECIDED] At each tier boundary the player picks a class**, and classes are not
uniform upgrades. Each carries a package:

- Stat modifiers — **which may be negative**
- Access to passives
- Elemental typing (potentially changing the unit's type-chart position)
- Presumably: growth-rate changes, stat caps, move-pool access

**[DECIDED] Some classes trade raw stats for utility** — a net stat *penalty* in
exchange for strong passives or a valuable typing.

### The consequence that drives everything else

**Stat total stops being a proxy for unit power.** A stat-penalty class with a
great typing and two strong passives can beat a stat-jump class outright. Any
system that tries to measure "how strong is this unit" from its numbers will be
measuring the wrong quantity.

This is why level — not stats, not tier — is the only sound key for the XP
economy (§4).

---

## 3. What exists today

Enum only. [Enums.CharacterClass](../../scripts/core/enums.gd):

- **Tier 1 (15):** Spaceman, Mercenary, Squire, Noble, Engineer, Pirate, Fighter,
  Enigma, Skulk, Duelist, Mage, Heavy, Grunt, Keener, Bandit
- **Tier 2 (3):** Jetpack, Hardcase, Knight
- **Tier 3 (3):** EVA, Topdog, Void Knight

Absent: class data of any kind (no `data/classes/`), the `CLASS_INFO` table that
[character_data.gd:295](../../scripts/units/character_data.gd#L295) already
gestures at for stat caps, any promotion trigger or eligibility check, and the
class-choice screen.

`CharacterData.tier` exists as a stored `@export` defaulting to 1, and is
currently stubbed at 1 for every character.

### Content scope, stated plainly

**3 tier-2 classes for 15 tier-1 classes.** If each base class wants 2–3
promotion options, that's roughly **30–45 classes** to author across tiers 2 and
3 — each needing stat mods, granted passives, typing, growths, caps, a name, and
eventually art. This is the largest unscoped content commitment in the project.

**[OPEN]** Does every tier-1 class get its own promotion set, or do several base
classes share a promotion pool? Sharing is the obvious lever if 30–45 is too many.

---

## 4. Interaction with the XP economy

Doctrine lives in [.claude/mission_objectives.md](../../.claude/mission_objectives.md)
"XP Economy"; this section covers only what the class system changes.

### [DECIDED] A level always costs 100 XP

Flat, at every level, in every tier. Catch-up comes from scaling **XP gain**, never
the XP requirement and never a purchase price.

### [RECOMMENDED] Delete `TIER_LEVEL_BOOST`

[CombatXpCalculator](../../scripts/combat/combat_xp_calculator.gd) currently
computes `internal_level = level + (tier − 1) × 20` and keys the differential off
it. That construct exists **because FE resets level on promotion** — it's a
normalization device for a discontinuous scale.

Under a continuous scale it is redundant, and applying it double-counts. With
`raw = base + target_internal − attacker_internal`, clamped to [1, 100], and a
kill worth `BASE_HIT_XP + KILL_BONUS = 30`:

| Attacker | Internal | vs a Lv 20 enemy | Kill XP |
|---|---|---|---|
| Lv 20, tier 1 | 20 | 30 + 20 − 20 | **30** |
| Lv 21, tier 2 | 41 | 30 + 20 − 41 | **9** |

A single level-up cuts kill XP by 70% at an arbitrary threshold, and again at 41.
The player would experience promotion as an invisible punishment.

**Under a continuous scale, `internal_level` should simply be `level`.** Remove
`TIER_LEVEL_BOOST` and the `_internal_level()` indirection with it. It is
currently dormant (tier is stubbed at 1 everywhere), so this is safe to do at any
time — but it **must** happen before tier is ever derived from level, or the cliff
goes live.

Also prune the stale intent comment at
[character_data.gd:30](../../scripts/units/character_data.gd#L30) — *"so promoting
effectively bumps your XP cost"* — which describes FE's model, not this one.

### [RECOMMENDED] Build choice must never affect XP rate

A stated rule, not an emergent accident: **class choice changes what a unit does,
never how fast it grows.**

If the stat-penalty utility class also leveled faster as implicit compensation,
players would optimize for the leveling quirk rather than for what the class
actually does — and it would be a hidden rule, which this project's XP doctrine
explicitly rejects ("the FERD sin was hiding it").

Keeping XP keyed purely to level makes promotion a **pure build decision**.

### [RECOMMENDED] No separate diminishing-returns system

The continuous scale already produces smooth diminishing returns through the
differential, with no thresholds and nothing to teach:

| Attacker vs a Lv 20 enemy | Kill XP |
|---|---|
| Lv 10 | 40 |
| Lv 20 | 30 |
| Lv 30 | 20 |
| Lv 40 | 10 |
| Lv 50 | 1 (floor) |

It also yields a **soft level cap for free**: flat 100 XP/level plus awards
decaying to the `MIN_XP` floor means a far-overleveled unit needs ~100 actions per
level and effectively stops climbing. The wall's position is tunable via `MIN_XP`,
`BASE_HIT_XP`, and `KILL_BONUS` — no new system required.

A tier-based XP requirement (the "tier 2 needs 150 XP" idea) was considered and
**rejected** as inelegant and unnecessary given the above.

---

## 5. The supersquad problem

**The design goal:** don't incentivize building a small invincible squad of a
handful of units while the rest of the roster rots on the bench.

**[RECOMMENDED] The class system is the answer — not the XP curve.**

XP diminishing returns is a weak lever here. Concentration stays optimal whenever
deployment slots < roster and per-map XP is finite; slowing the leveling just
slows the supersquad, it doesn't make spreading *better*. It taxes the symptom.

What actually breaks a supersquad is **being unable to field the same eight**, or
**that eight losing**. Three systems push that way, two of them already shipped:

| Lever | Status | Mechanism |
|---|---|---|
| Injury attrition | shipped | Injuries persist, occupy slots, recover over N battles; overflow is permadeath. Running the same squad forces bench time. |
| Differential XP gain | shipped | Underleveled units earn multiples of what the carry earns. |
| **Class + type diversity** | **unbuilt** | Classes carry typings and passives; eight identical juggernauts have coverage holes a composed six doesn't. |

The third is the real answer, because it makes narrow squads **lose fights**
rather than merely level slowly — and it turns the counter into encounter and map
design rather than spreadsheet friction.

**[OPEN]** Injury tuning is the dial that decides how much rotation pressure
actually exists. Rare injuries or short recoveries mean weak pressure. Measurable
in the 2-mission playtest loop.

**[OPEN]** Deployment-slot growth over the campaign as a fourth lever — more slots
later means needing more leveled units. More direct and more legible than any XP
math, and it generates narrative.

---

## 6. Open questions

- **Promotion sets** — per base class, or shared pools? (§3; drives the 30–45
  content number.)
- **Reclassing** — can a unit change class *within* a tier after promoting, or is
  the pick permanent? `character-system.md` assumed reclassing was possible and
  that passives are retained across it; that predates this design and needs a
  ruling.
- **Stat caps per class**, and what happens when a promotion's stat modifiers
  would push a unit past a cap.
- **The class-choice screen.** Promotion at 21 and 41 is the biggest choice moment
  in the progression loop — a dopamine beat in the same family as the level-up
  screen, and deserving the same "not a text dump" budget. Where does it live in
  the post-mission chain, and does it interrupt or queue?
- **Do enemies promote?** Auto-leveled enemies currently get levels but no class
  progression; a level-45 enemy implies tier 3.
- **Stat-penalty class legibility** — how does the UI communicate "this class is
  worse on paper but better in play" at the moment of choosing?
- **Eligibility variant** (tabled): promote-when-you-choose from 21 rather than
  forced. If it ever returns, note that any tier-linked XP rule would immediately
  become a trap — delaying promotion would be mathematically optimal. Another
  reason §4's "level is the only key" matters.
