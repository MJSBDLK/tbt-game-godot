# Alpha Milestone (Godot Port)

**Status**: In Progress — Migration Phase 0 Complete
**Last Updated**: 2026-02-22

---

## Alpha Goal

Create a **fully playable single battle experience** where players can:

1. **Select a level** (5, 20, 40, or 60) from the map select screen
2. **Auto-level all player units** with movepool/passive unlocks and stat allocation points
3. **Enter preparation screen** to customize squad (moves, passives, stat distribution)
4. **Enter battle** with enemies auto-leveled to appropriate difficulty
5. **Complete a full battle** with all core features functional
6. **See victory or defeat screen** with battle stats
7. **Return to map select** to play again

---

## Migration Progress

The Alpha milestone is being achieved through the Godot port. Each migration phase brings us closer.

| Phase | Description | Status | Alpha Systems Delivered |
|-------|-------------|--------|------------------------|
| 0 | Project scaffolding | **COMPLETE** | Enums, debug config, z-index, colors |
| 1 | Grid & Tile system | PENDING | Tilemap, pathfinding, terrain data |
| 2 | Unit system & movement | PENDING | Unit nodes, waypoints, health bars |
| 3 | Combat & type system | PENDING | Damage calc, multi-hit, status effects |
| 4 | Game state, input, turns | PENDING | Full battle loop, enemy AI |
| 5 | UI system | PENDING | Panels, overlays, combat preview |
| 6 | Map pipeline & authoring | PENDING | TileSet workflow, test maps |
| 7 | Missing Alpha features | PENDING | Map select, prep screen, passives, auto-leveling |
| 8 | Polish & Steam Deck | PENDING | Controller support, save/load, performance |

**Full migration plan**: [migration.md](migration.md)

---

## Alpha Components

### Already Ported (from Unity)
- [x] Enums for all game systems (elemental types, status effects, classes, etc.)
- [x] Debug logging system (flag-based, per-system)
- [x] Z-index calculator (row-based sorting adapted for Godot)
- [x] Color palette system (GPL file loader + semantic game colors)

### Needs Porting (exists in Unity)
- [ ] Grid system with A* pathfinding and BFS flood-fill
- [ ] Tile system with terrain data from JSON
- [ ] Unit system with waypoint-based movement
- [ ] CharacterData (8 stats, growth rates, stat allocation)
- [ ] Combat system (multi-hit, type effectiveness, counter-attacks)
- [ ] Status effect system (apply, process, remove)
- [ ] Turn manager (player phase → enemy phase cycle)
- [ ] Enemy AI (aggressive/tactical/defensive behaviors)
- [ ] Input manager (state-based dispatch)
- [ ] Action menu system
- [ ] UI layout (640x360, three-panel)
- [ ] Combat preview panel
- [ ] Phase transition overlays
- [ ] Type chart with visual matrix editor

### Needs Building Fresh (never existed in Unity)
- [ ] **Map select screen** — Level selection (5/20/40/60), mission preview
- [ ] **Preparation screen** — Squad selection, move/passive equip, stat distribution
- [ ] **Stat allocation UI** — +/- per stat, available points counter, caps
- [ ] **Enemy auto-leveling** — Simulate growth rolls to target level
- [ ] **Passive system** — Real PassiveData with stat bonuses and conditions
- [ ] **Move database population** — 20+ moves, 2-3 per element minimum
- [ ] **Victory/defeat screens** — Battle stats (turns, damage, units lost)
- [ ] **Type effectiveness feedback** — "Super Effective!" flash, color-coded numbers
- [ ] **Status effect visual indicators** — Icons above units, turn countdown

---

## Alpha Phases

### Phase A: Foundation (Battle Feel)
**Delivered by**: Migration Phases 1-4

- [ ] Grid renders with correct z-indexing
- [ ] Units move along paths with animation
- [ ] Combat plays multi-hit sequences with damage popups
- [ ] Type effectiveness calculated correctly
- [ ] Status effects apply and resolve
- [ ] Enemy AI takes intelligent turns
- [ ] Victory/defeat detected and displayed
- [ ] Full turn loop: player → enemy → repeat

**Done when**: A battle feels satisfying from start to finish with clear feedback.

### Phase B: Progression Systems
**Delivered by**: Migration Phase 7 (partial)

- [ ] Move database populated with 20+ moves
- [ ] Passive system designed and implemented
- [ ] Passive database with 10+ entries
- [ ] Stat allocation UI functional
- [ ] Auto-leveling system connected

**Done when**: Units have meaningful customization options.

### Phase C: Pre-Battle Experience
**Delivered by**: Migration Phase 7 (partial)

- [ ] Preparation screen with squad selection
- [ ] Move assignment interface
- [ ] Passive assignment interface
- [ ] Stat distribution interface

**Done when**: Preparation screen is functional and intuitive.

### Phase D: Battle Selection
**Delivered by**: Migration Phase 7 (partial)

- [ ] Map select screen with level selection
- [ ] At least 2 test maps
- [ ] Full flow: map select → preparation → battle → result → map select

**Done when**: Complete game loop works seamlessly.

### Phase E: Polish
**Delivered by**: Migration Phase 8

- [ ] Controller/keyboard input on Steam Deck
- [ ] Balance tuning
- [ ] Bug fixes
- [ ] Performance at 60fps on Steam Deck

**Done when**: Alpha build is stable enough for external testing.

---

## Testing Checklist

### Core Battle Loop
- [ ] Can complete a battle from start to victory
- [ ] Can complete a battle from start to defeat
- [ ] Enemy AI acts intelligently
- [ ] Type effectiveness calculates correctly
- [ ] Status effects apply and resolve properly
- [ ] Turn transitions are smooth
- [ ] Victory/defeat screens display correctly

### Leveling & Customization
- [ ] Auto-level to 5/20/40/60 works correctly
- [ ] Move pools populate correctly at each level
- [ ] Stat allocation respects caps
- [ ] Passives apply stat bonuses correctly

### Preparation Screen
- [ ] Move assignment/unassignment works
- [ ] Passive assignment/unassignment works
- [ ] Stat allocation interface functions
- [ ] Squad selection respects map limits

### Map Select
- [ ] Level selection buttons work
- [ ] Mission information displays correctly
- [ ] Full loop: select → prepare → battle → result → select

### Performance
- [ ] 60fps on Steam Deck (1280x800)
- [ ] No crashes or softlocks
- [ ] Integer-scaled pixel-perfect rendering
