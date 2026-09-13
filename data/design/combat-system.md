# Combat System Design Document

## Overview
Combat follows a Fire Emblem-style exchange system where attacker and defender trade blows, with multi-attack potential based on the Athleticism stat differential.

---

## Move Assignment

### Terminology
- **Assign**: Select a move to be active for attacks and counter-attacks
- Units always have one move assigned (or none if all moves exhausted)

### Assignment Rules
- After moving, if a unit does not attack, they can **assign** a move
- Attacking automatically assigns the used move
- Assigned move persists until:
  - Player selects a different move
  - Move runs out of uses (edge case handling TBD via playtesting)
- PP (uses) consumed only when the move is actually used

### Out-of-Uses Edge Cases (TBD)
When assigned move runs out during opponent's turn:
- **Option A**: Don't reduce uses during opponent's turn
- **Option B**: Allow 0-use moves if unit ended turn with >0 uses
- **Option C**: Auto-assign next available move
- **Option D**: Revert to basic attack

*Decision deferred to playtesting.*

---

## Combat Flow

### Attack Pattern
1. **Attacker's first strike** (assigned move)
2. **Defender's counter-attack** (their assigned move, if in range)
3. **Bonus attacks** from Athleticism differential (attacker, then defender)

### Multi-Attack System
Based on Athleticism stat ratio between attacker and defender:

| Ratio | Attacks |
|-------|---------|
| < 2x  | 1 attack |
| >= 2x | 2 attacks |
| >= 3x | 3 attacks |
| >= 4x | 4 attacks (maximum) |

**Example**: Unit A (Athleticism 24) vs Unit B (Athleticism 8)
- Ratio: 24/8 = 3x
- Unit A attacks 3 times

### Counter-Attack Rules
- Defender uses their **assigned move** to counter
- Counter only occurs if assigned move's **range allows it**
  - Melee move vs ranged attacker = no counter
  - Ranged move vs adjacent attacker = may counter (move range permitting)
- If no move assigned or assigned move can't reach = no counter
- Defender can also get bonus attacks from Athleticism differential

### AoE and Counter-Attacks (TBD)
Whether AoE effects apply during counter-attacks is undecided.
*Decision deferred to playtesting.*

---

## Combat Preview Panel

### Purpose
Show anticipated combat outcome before committing to attack. Should be clearer than Fire Emblem's sometimes-confusing display.

### Required Information

#### Damage Display
```
[Attacker Name]          [Defender Name]
12 dmg x2                8 dmg x1
```
- Damage per hit
- Number of attacks as multiplier

#### HP Preview
Visual bar showing:
- Current HP (full bar)
- Projected HP after combat (shortened bar)
- "Damage taken" segment (difference, highlighted in red)

#### Hit Chance
- Displayed as percentage
- Factors in Skill stat and evasion

#### Critical Hit (conditional)
- Only displayed if crit chance > 0%
- Shows "Crit: X%"

#### Type Effectiveness (conditional)
- Only displayed if not 1x (normal)
- Shows multiplier: "2x Effective", "½x Effective", "4x Effective", etc.
- Applies to both attacker and defender independently

### Layout Concept
```
┌─────────────────────────────────────┐
│  [Attacker]        vs    [Defender] │
│  ════════════            ══════════ │
│  Fire Slash              Ice Punch  │
│  12 dmg x2               8 dmg x1   │
│  2x Effective                       │
│                                     │
│  HP: ████████░░  →  ████░░░░░░      │
│      32/40           16/40          │
│                                     │
│  Hit: 95%            Hit: 78%       │
│  Crit: 5%                           │
└─────────────────────────────────────┘
```

---

## Damage Calculation

### Current Formula (from character-system.md)
```
Attack Stat = Physical moves use Strength, Special moves use Special
Defense Stat = Physical moves vs Defense, Special moves vs Resistance
Base Damage = (Move Power × Attack Stat ÷ 5) - Defense Stat
Final Damage = Base Damage × Type Effectiveness × Other Modifiers
Minimum Damage = 1 (always deal at least 1 damage)
```

### Type Effectiveness Multipliers
- 4x: Double super effective (rare, dual-type weakness)
- 2x: Super effective
- 1x: Normal
- ½x: Not very effective
- ¼x: Double resistance (rare, dual-type resistance)

---

## Combat Animations

**Where the truth lives:** the class headers are the living documentation.
`scripts/combat/presenter/combat_presenter.gd` is the map of the whole system
(beats, rules, the three presenters); `scripts/units/unit_animation_resolver.gd`
owns clip selection; `scripts/combat/scene/combat_scene.gd` owns the stage.
This section is the player-facing description and the rules art is drawn
against. (Landed 2026-09-09 from `rqd--battle-animations`; the plan's decision
log is preserved in `.claude/todo-archive.md`, "Battle animations plan".)

### The combat scene (Fire Emblem 7 style)
- Every **offensive, single-target** exchange cuts to a side-view stage: the
  map dims, sky and floor bands (Lawrence's backdrop when present), the two
  combatants as puppets at **3× sprite scale**, a playback HUD per side.
- The **player's unit stands on the right**; the left puppet mirrors everything
  it plays. All attack clips are authored **side view, left-facing** — no
  up/down variants, ever.
- Friendly casts (heals, buffs, self-casts, ally targets) and AoE stay on the
  map, for pace.
- Options → "Battle Anims": **Scene** (default) / **Player** (scene on the
  player's turn only) / **Map** (the in-place presentation). Any press skips —
  timing only, never results.
- 250 ms settle after the wipe-in and before the wipe-out. Dev flag
  `DebugConfig.combat_scene_step_pauses` parks the stage at both until a press.

### Spacing follows the map
- Puppets stand **32 sprite px apart per tile of map distance** (tiles are
  32×32), symmetric about the stage centre, **capped at 4 tiles (128 px)**.
  Distance is Manhattan, the gameplay range metric — a diagonal neighbour is
  two tiles away. No panning or zoom.
- A flat tile strip under the pair shows the tiles, one per map tile, until
  the backdrop carries that job.
- Clips are drawn for tile reach: a jab meets an adjacent target; Ernesto's
  thrust reaches ~58 px, two tiles. Never space by sprite size.

### Playback HUD (per side)
Portrait (HD line art or pixel), name, level, the unit's types; HP bar with
the **projected loss of the upcoming strike** as a pulsing band (a hit spends
it, a miss clears it); the move row — element and damage-type icons, name,
PP, hit %, type multiplier — the defender's row reads "—" until it counters;
one buff and one debuff chip, live (a status landing mid-exchange repaints the
chip and floats its name over the puppet). The forecast for the whole exchange
stays on the combat preview panel; the scene is **playback only**.

### Clip vocabulary and selection
- Clip keys are Aseprite tag names: `idle` (required), `melee`, `ranged`;
  optional refinements `melee_physical`, `melee_special`, `ranged_physical`,
  `ranged_special`; reactions `dodge`, `hurt`, `death`; `cast`; `crit_melee`,
  `crit_ranged`.
- **Intent = reach × kind.** Reach: melee when the target is adjacent, ranged
  from two tiles (a move's `animationStyle` tag forces it; the move's own
  range stands in when no target is known). Kind: physical / special from the
  damage type; support moves are `cast`.
- **Chains, same reach first**: `melee_special → melee → melee_physical →
  ranged_special → ranged → ranged_physical → any attack → procedural`. An
  archer forced into melee shoots point-blank; a brawler swings at range;
  every character is playable with `idle` alone (procedural lunge, flash,
  fade).
- **Overrides**: character × move (`animationOverrides["move:<name>"]`) >
  the move's `animationClip` (visual only) > character × intent > chain.
- Hit frame from the sidecar's `hit` marker; authored frame durations are
  honoured; hitlag scales with impact weight.

### Beats of an exchange
open → callouts (BELLOWS, CRIT!) → strike to contact → hitlag → release,
impact (flash + stage shake) → damage → counter … bonus hits … → death →
close. **Displacement**: the tile moves at once (counters read the new
range), the puppets re-space on stage, and the map slide replays after the
wipe-out — units never teleport under the stage. A miss is a swing, a dodge
hop and "MISS". A follow-up the range re-check refuses says "OUT OF RANGE".

### On the map
Map mode, bare units and non-offensive casts use the in-place presentation:
the side clip mirrored for horizontal and diagonal attacks, a boop nudge for
due-vertical ones, camera shake, popups on the map.

### Art asks
Sprites: `data/design/character-asset-checklist.md`. Backdrop:
`art/backdrops/combat_test/README.md` and the template beside it.

## Implementation Phases

### Phase 1: Core Combat Refactor ✅
- [x] Add `assignedMove` field to Unit
- [x] Implement move assignment flow (Wait → Assign menu)
- [x] Update action menu to support assign option

### Phase 2: Counter-Attack System ✅
- [x] Implement defender counter-attack logic
- [x] Add range checking for counter eligibility
- [x] Handle assigned move for AI units

### Phase 3: Multi-Attack System ✅
- [x] Calculate attack count from Athleticism ratio
- [x] Implement attack sequence (attacker → defender → bonus)
- [x] Cap at 4 attacks maximum

### Phase 4: Combat Preview ✅
- [x] Create CombatPreviewPanel UI component
- [x] Calculate and display projected damage
- [x] Show HP bars with damage preview
- [x] Display hit/crit chances
- [x] Show type effectiveness

### Phase 5: Animation Integration
- [ ] Create animation data structure (origin points, directional sets)
- [ ] Implement Ready → Attack frame sequencing
- [ ] Add directional animation selection based on attacker/defender positions
- [ ] Integrate particle system with origin point → target interpolation
- [ ] Implement dodge animation and popup
- [ ] Sequence multi-hit animations with proper pacing
- [ ] Delay SetActed() until combat sequence completes

### Phase 6: Edge Cases & Polish
- [ ] Handle out-of-uses scenarios
- [ ] AoE counter-attack decision
- [ ] Passive ability overrides

---

## Open Questions

### Combat Mechanics
1. **Out-of-uses behavior**: Which option feels best in playtesting?
2. **AoE counters**: Should AoE effects trigger on counter-attacks?
3. **Preview accuracy**: How to handle RNG in preview (show expected value? range?)

---

## Related Documents
- [Character System](character-system.md) - Stats and progression
- [Move System](../MoveSystem_README.md) - Move data and types
