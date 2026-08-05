# Mission Objectives & World-Clock Design

## Context

Tactical-RPG missions need pacing pressure to stop players from turtling, but explicit turn timers are universally resented. This doc captures the design rules for how we incentivize forward momentum *intrinsically* — via diegetic world events that escalate over turns — and how bonus XP (bEXP) rewards should be structured so they align with, rather than fight against, normal combat XP.

## Core Design Principle

**Failure states escalate the challenge; they do not terminate it.**

The world's clock changes the *terms of the fight*. It does not declare a winner. The player always retains agency — the costs just climb. This is the Fire Emblem thief-chase pattern generalized:

- Miss the chest? The thief runs for the map edge with it. Dedicate units to chase, or eat the loss.
- NPC not rescued yet? They take damage and retreat toward worse ground, not instant death.
- Supply cache not grabbed? Enemy drone picks it up and flees — chase or lose the cache.

Binary "do it in N turns or game over" mechanics are banned. Every world-clock objective must have a graceful-degradation path where the player can still engage, even if the reward or stakes have shifted.

## bEXP Rules

**bEXP is awarded for completing objectives and for coarse end-of-mission turn bands — never per-kill, never as a per-turn drain.**

*(Amended 2026-08-03 by RQD — the original "never for turn count" rule is
relaxed. The FE Radiant Dawn sin wasn't rewarding speed, it was HIDING the
reward: players learned about speed-bEXP from the wiki. Coarse par bands,
displayed up front, keep the incentive without the trap.)*

Income lines per mission:
- **Above par** — finished at or under the map's `par_turns`: the larger bonus.
- **No dawdling** — finished under the map's `dawdle_turns` (generous — roughly
  2× par): the "gimme" bonus. Everyone playing normally gets this.
- **Explicit objectives** — save the NPC, destroy the courier, grab the cache.
  Typical values 100–250 each, 0–2 optional per mission.

Rules that survive the amendment unchanged:
- Normal combat XP from kills stays unconditional — grind reinforcements all
  you want, no bEXP penalty. The RD trap (in-moment incentive opposing the
  meta incentive) stays sidestepped because kills never subtract anything.
- Par is **displayed before and during the mission** (mission info / objective
  readout) — a fact the player can plan around, never a secret and never a
  ticking HUD countdown.
- Awards are granted once, at mission end, as itemized lines on the result
  screen. No formula ever drains a pool as turns pass.
- Ignoring objectives is valid play; it just doesn't earn bEXP. No punishment,
  only opportunity cost.

## Objective Patterns (Catalogue)

### Allied NPCs in peril
- An NPC is on the map, threatened by nearby enemies.
- Gradual damage / forced retreat / being surrounded over turns — no instant death.
- Rescue window is long but gets harder each turn (lower HP, more enemies nearby).
- Lore fit: peaceful protagonists defending a bystander. Aligns with non-aggressor party.
- **bEXP award**: rescue success = bonus. NPC perishes = 0 bonus, no mission fail.

### Environmental pressure (hazards that encroach)
- Storm, flood, reactor meltdown, atmosphere breach, radiation zone, etc.
- Tiles become hazardous or impassable as turns progress, squeezing the play area.
- Failure mode is gradual attrition — damage taken from hazards — not sudden loss.
- Forces commit-vs-retreat decisions rather than timer pressure.
- Lore fit: broad — works for nearly any setting with a plausible hazard.
- **Atmosphere breach** (sci-fi): hull/biodome tear, tiles near the breach become unsurvivable over time. Good visual/audio drama.
- **bEXP award**: typically paired with an escape or rescue objective — not a standalone bEXP target.

### Couriers / intel runners
- Enemy unit carrying intel/schematics/a distress call, moving toward a map edge.
- Each turn it advances one tile toward the exit.
- If it escapes, player loses *that specific reward* (bEXP, intel item, favorable next-mission conditions) — mission continues.
- Escalation: closer to the edge = calls for escort, gains speed, becomes harder to catch.
- Lore fit: defensive framing — preventing future harm, not unprovoked aggression. Good for non-aggressive protagonists.
- **bEXP award**: courier destroyed before escape.

### Loot bots / supply drones (non-luddite factions only)
- Mechanical units carrying resources, mostly passive but scheduled to leave on turn N.
- Same chase-dynamic as couriers.
- Lore fit: only applicable against factions that use automation — explicitly excludes luddite enemies.
- **bEXP award**: loot bot destroyed.

### Thief-pattern supply caches
- Cache sits on a tile; player can grab it directly.
- If not grabbed by turn N, enemy supply drone picks it up and flees toward map edge.
- Player can still chase the drone and recover the cache.
- If the drone escapes with it: long-term consequence (enemy faction better-equipped next mission) rather than in-mission failure.
- Lore fit: broad.
- **bEXP award**: cache recovered (directly or via chase).

### Escape missions
- Primary objective: get party to an extraction tile within the mission.
- *Not a turn timer* — lingering is self-punishing because environmental pressure or ramping reinforcements make staying XP-negative.
- Player leaves when it's economically rational, not when forced.
- **bEXP award**: typically a flat award for successful extraction; may be modified by "no casualties" or similar sub-conditions.

### Reinforcement waves (context, not an objective itself)
- Enemies spawn on turn thresholds — creates pressure, fills the map.
- Must be designed so that *past a certain point, fighting them is no longer XP-positive* (damage taken exceeds XP gained).
- This makes the narrative pressure ("they're calling for backup") match the mechanical pressure ("it's not worth staying") without an explicit timer.
- Lore fit: broad — any enemy faction with communication/coordination.

## Anti-Patterns (Do Not Implement)

- Explicit turn counters on the HUD (e.g. "12 turns remaining"). Par shown as
  a static fact in mission info is fine; a ticking countdown is not.
- Mission-fail conditions tied purely to turn count.
- bEXP formulas that subtract from a pool each turn. (End-of-mission par
  BANDS are allowed per the 2026-08-03 amendment; continuous per-turn decay
  is still banned.)
- Objectives that vanish without a chase/escalation path.
- Punishing kills or combat engagement in any form.
- Hidden incentives. If speed pays, the player is told so before turn 1.

## XP Economy (locked 2026-08-03, RQD design session)

Combat XP and bEXP are one economy; the code is the source of truth
([combat_xp_calculator.gd](../scripts/combat/combat_xp_calculator.gd) header),
this is the doctrine:

- **Combat XP**: RD differential formula, flat 100 XP/level. The differential
  IS the rubber band — underleveled units level ~4× faster in the same
  mission. Overleveled gains decay to the 1-XP floor.
- **Support casts** (buff/cleanse) pay a flat heal-sized award, gated on the
  cast having a meaningful effect. PP limits farming.
- **Survival XP**: the FIRST time each enemy engages a unit per battle, the
  defender earns a small level-diff-scaled award (dodge or tank — surviving
  is the lesson). Repeat engagements from the same enemy pay nothing, so
  stalling next to a harmless enemy pays ~1 XP once, then zero forever.
- **bEXP spending**: pooled, player-allocated, **flat — 100 bEXP buys one level
  for anyone** (amended 2026-08-05, see below).

### Amendment 2026-08-05 — bEXP is a flat pool

The clause above previously read: *"A level costs `100 × unit_level ÷
squad_max_level` (clean-rounded, floor 25) — the player sees a price tag per
unit, never the formula."* That was recorded here as locked on 2026-08-03; RQD
reports it was explored but never ratified, and on review it contradicts the
position it was meant to implement.

**Why it's wrong.** RQD's original note argued *against* higher XP requirements
for higher-level units — "keep it at 100/unit and scale EXP gain differently."
A scaled bEXP price re-introduces exactly that, denominated in bEXP instead of
XP: the carry needs 90 per level where a rookie needs 25. Same rule, different
currency. It also hides a formula from the player, which is the FERD sin this
economy was written to avoid.

**The corrected doctrine:**

- **A level costs 100 XP, flat**, at every level and in every tier.
- **bEXP is a simple pool of spendable XP.** 100 bEXP = one level, for anyone.
- **All catch-up lives in XP *gain*** — the RD differential formula — never in
  the requirement and never in a purchase price.
- **Class/build choice never affects XP rate.** See
  [class-and-promotion.md](../data/design/class-and-promotion.md) §4.

**Why flat bEXP doesn't create a supersquad.** The concern: since the
differential decays an overleveled unit's combat gains to the floor, bEXP becomes
their only growth path, so a player would pour it there and widen the spread.
That assumes concentration is the winning play. It isn't — injury attrition
forces rotation, so a deep competent bench is required, and bEXP is the budget
for raising it. Flat pricing makes that legible: *"three levels, that's 300, I
have 450."* The anti-supersquad work is done by class/type diversity and injury
attrition, not by XP math ([class-and-promotion.md](../data/design/class-and-promotion.md) §5).

**Code consequences (not yet applied):** delete `SquadManager.bexp_level_cost`
and its `BEXP_BASE_LEVEL_COST` / `BEXP_MIN_LEVEL_COST` / `BEXP_COST_STEP`
constants; `buy_bexp_level` charges a flat 100. The BonusXpPanel header's "SPEND
MODEL (reworked 2026-08-03)" note needs rewriting to match.

## Open Questions

- **Objective definition format**: JSON blob per map? Dedicated `Objective` resource class? Needs a design pass before implementation.
- **UI display**: Objective checklist on the battle HUD (persistent? collapsible? only shown on map open?). See battle_result_overlay scope — objective status also appears there.
- **Multi-objective missions**: How many per map? My gut says 1 primary (beat the mission) + 0–2 optional world-clock bEXP objectives.
- **bEXP economy**: How much bEXP buys what? Needs to shake out alongside the XP/level-up system.
- **Escalation telegraphing**: how does the player know a courier is faster now, or a storm is about to engulf a tile? Visual affordances (particles, sprite variations) vs. UI text.

## Related Docs

- [alpha.md](alpha.md) — Alpha milestone scope
- [todo.md](todo.md) — §1 "Battle result V2" pulls from this doc's objective model
