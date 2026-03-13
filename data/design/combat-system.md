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

### Art Style
- **Pixel art** for all combat animations (not fullres)
- Consistent with game's overall visual style

### Animation Frames Per Unit

#### Attack Animations (2 frames each)
| Frame | Description |
|-------|-------------|
| Ready | Wind-up pose (e.g., pulling hand back to punch) |
| Attack | Strike pose (e.g., punching forward) |

#### Attack Types
- **Physical**: Close-range melee attacks
- **Ranged**: Projectile/distance attacks
- *(May bifurcate further into melee vs ranged later)*

#### Directional Sets (per attack type)
Each attack type needs three directional variants:
- **Up**: Attacking northward
- **Side**: Attacking east/west (mirrored for opposite direction)
- **Down**: Attacking southward

#### Special Frames
| Frame | Description |
|-------|-------------|
| Dodge | Single frame, unit evading an attack |

#### Hit Reaction (No Dedicated Frame)
- **Primary**: Alpha blink (flash transparent/opaque)
- **Enhanced**: Horizontal stripe blink (scanline effect, like retro invincibility frames)
- Uses existing sprite, no separate flinch art needed

#### Death Animation
- Currently: Fade out (alpha)
- Future: May add dedicated death animation frames

### Particle Effects

#### Origin Points
- Each sprite defines a **particle origin point** (e.g., fist, weapon tip)
- Stored as metadata on the sprite/animation

#### Effect Travel
- Particles interpolate from **origin point** → **defender's center of mass**
- Applies to both physical (impact) and ranged (projectile trail) attacks

### Critical Hit Effects
- Same animation as normal attack
- **Exaggerated camera shake**
- **Enhanced SFX**
- Larger/more intense particle effects

### Miss Behavior
- Attacker **fully animates** (Ready → Attack)
- "Attack hit" particle effect **does not play**
- Defender plays **Dodge frame**
- "Dodge!" or "Miss!" popup displays

### Multi-Hit Animation
- Full animation cycle (Ready → Attack) plays **for each hit**
- Example: 3x attack = 3 complete Ready → Attack sequences
- Hit reaction blink on defender after each successful hit

### Counter-Attack Animation
- Defender simply plays their own attack animation
- No special transition effect needed
- Uses same directional logic based on positions

### UI Feedback
- **Dodge popup**: Text popup when attack misses ("Dodge!" or "Miss!")
- **Damage popup**: Existing system shows damage numbers

---

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
