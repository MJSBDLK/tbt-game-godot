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

Markers: **[DECIDED]** RQD call · **[PROVISIONAL]** adopted as the working
answer, expected to move once it's been played · **[RECOMMENDED]** proposal
awaiting RQD · **[OPEN]** genuinely undecided.

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

### [DECIDED] Delete `TIER_LEVEL_BOOST`

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

### [DECIDED] No separate diminishing-returns system

A tier-based XP requirement (the "tier 2 needs 150 XP" idea) is **rejected** —
inelegant, and unnecessary because the award formula already decays. Diminishing
returns live in XP *gain*, and nowhere else.

### [PROVISIONAL] The award formula and its dials

> **Locked in as the working answer 2026-08-05. The proof is in the playtest** —
> every number below is a named dial expected to move, `k` most of all. What's
> settled is the *shape*; the values are a starting position, not a result.

**The formula, in plain words:** start from a base award, then double it for every
`k` levels the enemy is above you — or halve it for every `k` levels you're above
them.

```
xp = base × 2 ^ ((their_level − your_level) / k)
```

| Dial | Starting value | Meaning |
|---|---|---|
| `base` (kill) | 80 | An even fight pays this |
| `base` (hit, no kill) | ~27 | Same ratio to the kill award as today's 10 : 30 |
| `k` | 15 | Levels of gap that double (or halve) the award |
| floor | 1 | "You did something" |
| ceiling | none | Naturally bounded — see below |

**Why exponential and not the difference formula it replaces.** Three families
were compared (difference `base + their_lv − your_lv`, ratio
`base × their_lv ÷ your_lv`, and exponential). All three pay the base for an even
fight at any level, so none of them differ on on-level pacing. They differ
entirely in off-level behavior:

- **Difference** decays linearly and floors hard — a great wall against
  overlevelling, but it structurally *cannot* jackpot. Its natural maximum is 89
  XP for the single most extreme kill in the game, under one level.
- **Ratio** jackpots absurdly (a Lv 1 killing a Lv 60 earns 18 levels) and never
  stalls — an overlevelled unit still gains a level every ~10 kills forever,
  deleting the soft cap.
- **Exponential** does both: a tunable jackpot, and true asymptotic decay.

**The deciding argument was the funnel** (§5). At squad mean 25 with base 80:

| Your level | Difference | **Exponential k=15** |
|---:|---:|---:|
| 10 (rookie) | 95 | **160** |
| 25 (on par) | 80 | 80 |
| 40 (carry) | 65 | **40** |

A rookie is riskier to field, gets fewer kills, and may take an injury. The
difference formula's **1.5× premium doesn't cover that**; exponential's **4×**
does, and the player works it out in one mission without being told. RQD's
requirement was that bringing underlevelled units should be the *fun* way to play,
not a nudged one — that requires the steeper curve.

**No ceiling is safe here.** Because levels stop at 60, the formula is bounded by
the level range itself: the most extreme kill possible (Lv 1 kills Lv 60) tops out
around 1200 XP. An arbitrary clamp like `[1, 1000]` would be a fake limit doing
nothing the range doesn't already do. `MAX_XP = 100` should go — under the old
difference formula it never bound anyway (natural max 89).

### [PROVISIONAL] Pacing target

**~20 levels per 10 missions, for *every* unit in the squad** — conditional on the
player using bEXP well and bringing underlevelled units. That's the *skilled*
pace, not the floor; the gap between naive and skilled play is where the funnel
lives.

Two consequences fall out of it:

- **The campaign is ~30 missions** to traverse Lv 1 → 60 at 2 levels/mission. The
  tier bands land near missions 10 and 20 — roughly one tier per act. The pace
  target and the level bands (§1) were set independently and happen to agree.
- **The income split.** At 8 deployed and 12 enemies (~1.5 kills/unit), base 80
  yields ~1.5 levels/mission from combat, leaving ~0.5 levels for bEXP to close —
  about **400 pooled bEXP per mission**, roughly 2× current income. That makes
  bEXP about a quarter of progression: enough that ignoring it visibly costs you,
  without making combat feel unrewarding.

### What the playtest has to answer

The values above are guesses with arithmetic behind them, not measurements. Watch:

- **Actual levels/unit/mission** vs the 2.0 target — the whole model rests on
  ~1.5 kills per deployed unit, which is an estimate.
- **Does the funnel actually pull?** Do players bring rookies without being told?
  If not, `k` comes down (steeper premium).
- **Does the carry stall too hard?** k=15 means a Lv 40 unit at squad mean 25
  earns half the base. If that reads as punishment rather than diminishing
  returns, `k` goes up.
- **Is the jackpot fun or silly?** A Lv 1 landing a boss kill gains ~4.5 levels at
  k=15. Watch whether that feels like a triumph or an exploit.
- **bEXP's share** — if 400/mission feels like the pool is doing the work, shift
  income back toward combat by raising `base`.

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
| Level-gap XP scaling | shipped (formula changing, §4) | Underlevelled units earn multiples of what the carry earns — 4× at the k=15 starting value. |
| **Class + type diversity** | **unbuilt** | Classes carry typings and passives; eight identical juggernauts have coverage holes a composed six doesn't. |

The third is the real answer, because it makes narrow squads **lose fights**
rather than merely level slowly — and it turns the counter into encounter and map
design rather than spreadsheet friction.

### Enemy levels scale to the whole roster, not the deployed squad

`CampaignManager.pick_enemy_level` draws a Gaussian centered on the mean level of
`SquadManager.get_active_roster()` — **every roster member, benched or not**.

This turns out to help the funnel, and it's worth not "fixing" by accident.
Benching rookies doesn't raise enemy levels, because they still drag the mean
down. So a player who hoards low-level units and fields only carries faces
low-level enemies *and* earns almost nothing from them (a Lv 40 carry against Lv
15 enemies is deep in the decay). The only way to convert a low squad mean into
progression is to deploy the units who benefit from it. Switching this to
deployed-squad mean would invert the incentive — benching would raise enemy levels
and pay the carry *more*.

**[OPEN]** Mild exploit: hoarding unlevelled recruits suppresses enemy levels
campaign-wide, trading progression for easy maps. Self-limiting, but worth
watching in playtest.

**[OPEN]** Injury tuning is the dial that decides how much rotation pressure
actually exists. Rare injuries or short recoveries mean weak pressure. Measurable
in the 2-mission playtest loop.

**[OPEN]** Deployment-slot growth over the campaign as a fourth lever — more slots
later means needing more leveled units. More direct and more legible than any XP
math, and it generates narrative.

---

## 7. StatUp allocation

**[PROVISIONAL — RQD 2026-08-05, "needs playtesting, not set in stone"]**

- **Each pip is +10%** of the stat's `level_stat` (base + growth).
- **4 pips maximum per stat** → **+40%** ceiling on any one stat.
- **10 pips total at L60** (one every 6th level).
- Percentage is computed against `level_stat`, **not** the running total, and
  **rounded once on the final sum**. That matters: `round(7 × 0.40) = 3` but
  `4 × round(7 × 0.10) = 4`, so per-press rounding would silently inflate every
  low stat. Points are the stored state; the displayed stat is derived.

### The engine does not do this yet

[stat_allocation.gd](../../scripts/units/stat_allocation.gd) ships:

| | Spec | Code |
|---|---|---|
| Mode | percentage | `MODE = Mode.FLAT` — the percentage branch exists but is off |
| Per pip | +10% | `PCT_PER_POINT = 0.0625` (6.25%) |
| Max per stat | +40% | +25% |
| Per-stat cap | 4 | `PER_STAT_CAP = 4` ✓ |
| Pool at L60 | 10 | `POOL_AT_MAX_LEVEL = 10` ✓ |

The revamp is a mode flip plus one constant, but it is **not** a no-op: FLAT
gives every stat +1 per point (HP +2 via `HP_FLAT_PER_POINT`), so switching
changes every unit's allocated stats. Existing saves store *points*, not the
derived values, so they re-derive correctly — that's the payoff of the
serialize-facts-not-objects rule.

### Why percentage, and the concern that comes with it

RQD's worry: **most characters will want to dump pips into DEF and RES.**
Percentage was chosen partly to blunt that, and it does — but it's worth being
precise about *how*, because it isn't the obvious way.

Percentage doesn't make DEF less attractive. It makes DEF **scale with the unit
already investing in it**:

| Unit | DEF | +40% | flat +4 would give |
|---|---:|---:|---:|
| glass cannon | 3 | **4** (+1) | 7 (+4) |
| mid | 8 | **11** (+3) | 12 (+4) |
| tank | 20 | **28** (+8) | 24 (+4) |

Under flat, four pips would **more than double** a glass cannon's DEF — every
unit could buy their way out of being fragile, and archetypes collapse toward the
middle. Percentage preserves the spread: the tank gets tankier, the mage stays
made of paper. **That's the real win, and it's an identity argument rather than a
balance one.**

The dumping concern therefore survives — percentage doesn't stop a *tank* from
maxing DEF, it makes it better. Two things to watch in playtest:

- **DEF/RES vs the damage formula.** Damage is `(atk + might) − def`, so DEF
  subtracts linearly and every point is permanently worth one damage on every
  incoming hit. Offense competes for the same pips but only pays when attacking.
- **ATH may quietly beat both.** Multi-hit is a **ratio cliff** — 2×/3×/4× the
  defender's ATH gives 2/3/4 hits
  ([damage_calculator.gd](../../scripts/combat/damage_calculator.gd)
  `calculate_attack_count`). +40% ATH is worth nothing most of the time and
  *doubles your damage* when it tips you over 2.0×. A threshold that steep tends
  to dominate allocation advice once players find it.

Kept as-is for now per RQD; both are tuning questions, not design ones.

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
