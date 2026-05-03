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

**bEXP is awarded exclusively for completing objectives — never for turn count, never for kills.**

This sidesteps the FE Radiant Dawn trap where killing reinforcements felt like XP gain but was actually bEXP loss, because the player's in-moment incentive ("kill things → XP") directly opposed the meta incentive ("finish fast → bEXP").

Under the objective-only rule:
- Normal combat XP from kills stays unconditional — grind reinforcements all you want, no bEXP penalty.
- bEXP attaches to specific accomplishments: save the NPC, destroy the courier, grab the cache.
- Ignoring objectives is valid play; it just doesn't earn bEXP. No punishment, only opportunity cost.
- "Fast play" emerges naturally because objectives are time-pressured by the world, not because the player is racing a meta-clock.

Each map defines its own objective → bEXP award table. Typical bEXP values: 100–250 per objective, with 1–3 objectives per mission.

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

- Explicit turn counters on the HUD (e.g. "12 turns remaining").
- Mission-fail conditions tied purely to turn count.
- bEXP formulas that subtract from a pool each turn.
- Objectives that vanish without a chase/escalation path.
- Punishing kills or combat engagement in any form.

## Open Questions

- **Objective definition format**: JSON blob per map? Dedicated `Objective` resource class? Needs a design pass before implementation.
- **UI display**: Objective checklist on the battle HUD (persistent? collapsible? only shown on map open?). See battle_result_overlay scope — objective status also appears there.
- **Multi-objective missions**: How many per map? My gut says 1 primary (beat the mission) + 0–2 optional world-clock bEXP objectives.
- **bEXP economy**: How much bEXP buys what? Needs to shake out alongside the XP/level-up system.
- **Escalation telegraphing**: how does the player know a courier is faster now, or a storm is about to engulf a tile? Visual affordances (particles, sprite variations) vs. UI text.

## Related Docs

- [alpha.md](alpha.md) — Alpha milestone scope
- [todo.md](todo.md) — battle_result_overlay entry pulls from this doc's objective model
