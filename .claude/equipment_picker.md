# Equipment Picker — Design Doc

The pre-mission interface for editing a unit's **equipped moves** (4 slots) and **equipped passives** (1–2 slots). Opened from the per-unit detail panel on the squad manager when the player clicks a move slot or passive slot.

Lives in [.claude/squad_manager.md §4](squad_manager.md) — that doc is the parent; this is the focused design for the swap interaction.

---

## 1. Guiding principle

**Everything that informs move or passive selection is on-screen at once, in the most compact-readable form.** No "click to expand," no "open popup to compare," no scrolling away to read a stat. The player can browse the bank with full peripheral awareness of what the unit already has and how it'll perform.

Things that fit that bar (must be visible during selection):
- Equipped moves (4) — what's already there
- Equipped passives (1–2) — synergy potential
- Unit's stats — STR / SPC / SKL drive move output; AGL / DEF / RES drive defensive trades
- Primary / secondary type — STAB matters
- Active injuries — modify stats and may shift move priorities
- The bank, with filters — where the work happens
- Detail of the currently-highlighted move/passive — full description and stats

## 2. Layout — integrated into the squad manager screen

The picker is **not a popup**. It's the right-side content of the squad manager when a unit is in "edit moves" or "edit passives" mode. The collapsed unit list (squad_manager.md §8) stays on the far left so the player can switch which unit they're equipping with one click.

```
┌──────┬─────────────────────────────────────────────────────────────┐
│      │  MAX STELLAR  Lv 1  Simple / —  Spaceman      Injuries: —  │  ← summary
│ MAX  │  HP 21  STR 6  SPC 5  SKL 3  AGL 5  ATH 5  DEF 3  RES 4    │     header
│ [pt] │                                                             │
│ Sim  │  EQUIPPED MOVES        MOVE BANK            DETAIL          │
│ Spcm │  ▶ Bonk                [type filters ▾]    BACKHAND          │
│ HP21 │    Laser               [movetype ▾]        Phys / Simple    │
├──────┤    Klunk                                    Pow 8 / Rng 1    │
│ ERN  │    Uppercut            Backhand                              │
│ [pt] │                        Bonk                "A sweeping       │
│ HP28 │  EQUIPPED PASSIVES     Compressed Air       strike with the  │
├──────┤    AntiGrav            Cyclone              mechanical arm." │
│ MAA  │                        Feint                                 │
│ [pt] │                        Klunk                Effects: —       │
│ HP35 │                        Lance                                 │
│      │                        Megaton Punch                         │
│      │                        Sidearm                               │
│      │                        Uppercut                              │
└──────┴─────────────────────────────────────────────────────────────┘
                                                            [ Done ]
```

**The summary header at the top** is the persistent context — name, level, types, class, full stat row, injuries. It never scrolls or hides. The player can always see the numbers driving their choice.

**The equipped column splits top/bottom**: 4 move slots on top, 1–2 passive slots below. **Both are always visible** even when editing the other — so when you're picking moves, your equipped passives are still readable (and clickable to preview their description in the right column). The active section (whichever you're editing) is the only one whose slots accept swaps; the inactive section is read-only / preview-only.

**The bank column (center)** shows whichever pool you're editing — moves while in move-edit mode, passives in passive-edit mode. Filter icons live above it.

**The detail column (right)** shows whichever item was last clicked — equipped move, equipped passive, or bank entry. So clicking your equipped Bellows passive while editing moves loads Bellows' description in the detail column, then clicking a Fire move shows that move's description.

### Edit mode toggle

A small toggle near the top — **Editing: [Moves] | Passives** — flips which equipped section is interactive and which bank shows. Cheap context switch; the rest of the screen stays put.

### Commit semantics

Per the squad manager's "no confirmations" rule, every swap commits live to the unit's CharacterData. **No Cancel button.** "Done" really means "back out to the unit list view" — there's nothing to confirm because the changes are already saved. If the player wants to revert, they have to manually swap back. (This matches the squad manager's seamless feel; you don't say "Apply" when you toggle a unit to Bench.)

### Cramped-screen fallback strategy

The "everything visible at once" principle is aspirational — at 640×360 reference (or 1280×720 actual), fitting summary + 4 move slots + 2 passive slots + ~12 bank rows + filters + detail column might compress text below readability. We need to plan the fallback before we hit the wall.

**Build the layout with section visibility as a parameter from day one** so we can iterate without restructuring. Three escalating fallbacks, in order of how aggressively they break the principle:

| Tier | Trigger | What changes |
|---|---|---|
| **0 (default)** | All sections fit comfortably | Full layout as drawn — equipped moves + passives both expanded, bank, detail |
| **1 (auto-compress inactive)** | Cramped — typical for 640×360 | The **inactive equipped section** (passives while editing moves) collapses to a single-line summary: `Passives: AntiGrav` (or chips). Click the line to expand it temporarily, or it expands when you switch edit mode. |
| **2 (single-section equipped)** | Still too cramped | Only the **active equipped section** is shown. Inactive section hidden entirely; a button or the edit-mode toggle reveals it. Loses some peripheral awareness but bank gets full vertical room. |

Pick tier based on actual perceived cramping during build — likely we land on Tier 1 by default since it preserves "you can still read your passive while picking moves" while reclaiming most of the vertical space.

Each section gets an **explicit collapsed/expanded state** in code so we can A/B them. User-toggleable expand/collapse chevrons are also worth considering (especially if power users want to override the default tier for their personal flow).

## 3. Selection model — click-to-swap

Operates on the **active equipped section** (moves while in move-edit mode, passives in passive-edit mode) and the **bank**. The inactive equipped section (e.g. passives while editing moves) is preview-only — clicking shows description in the detail column, but doesn't initiate a swap.

The interaction is two-step:

1. **First click** in the active equipped section *or* the bank: selects/highlights that entry. Description loads in the right column.
2. **Second click**:
   - In the *same* column: change selection (clears prior highlight, highlights new).
   - In the *other* column (active equipped ↔ bank): **swap the two** between equipped and bank. Selection clears. Live commit.

**Clicking the inactive (preview-only) section** loads its description in the detail column without affecting selection state for swaps. So if you're mid-edit (one slot highlighted) and click your equipped passive to read it, the highlight on the active slot stays — your next click in the bank still does the swap.

Edge cases:
- Click an equipped slot, then click a bank entry → bank entry replaces equipped slot, displaced item returns to bank.
- Click a bank entry, then click an equipped slot → same outcome (commutative).
- Click an equipped slot when no slot is selected → highlight; the next click in the bank swaps in. (No way to "remove without replacing" — every equipped slot must be filled. If we want optional empty slots, that's a future feature.)

**Why click-to-swap rather than drag-and-drop:**
- Works identically across mouse, touch, and controller.
- Drag adds a touch-vs-tap-vs-long-press disambiguation problem on mobile.
- Visually clearer for the user — highlight makes the "now pick where to put it" intent obvious.

## 4. Bank ordering — alphabetized

Bank stays alphabetical regardless of swap history. Reason: when scrolling looking for a specific move, predictable position matters more than "the move I just used is at the top."

The trade-off: swapping a move out then changing your mind requires re-finding it in the alphabetical list. We accept that cost — the alpha movepool is small (≤20 per unit), and filters (§5) reduce it further.

> *Could revisit*: a "Recent" pinned section at the top of the bank if the alphabetical list ever exceeds ~30 items.

## 5. Filters

A row of icons above the bank column, always visible:

- **Elemental type icons** (8+ from `Enums.ElementalType` excluding NONE/OBSIDIAN): toggle each on/off to filter the bank to moves of that type. Multi-select OR semantics — selecting Fire and Cold shows moves of *either* type.
- **Move type icons** (3 from `Enums.DamageType` for displayed purposes — Physical / Special / Support): toggle each on/off. Multi-select OR.

Cross-filter is AND — selected types AND selected movetypes both apply. With nothing selected, all moves show.

Filter state persists for the duration of the picker session — closing and reopening resets to "all on." Passive bank (when in passive-edit mode) reuses the same filter row but only the elemental-type half is meaningful — passive filters by movetype don't apply.

## 6. Fuzzy search — stretch goal, deferred

A text field above the filter row. Typing filters the bank (prefix or substring match) across:
- move name
- abbreviated name
- elemental type name
- damage type name (physical / special / support)
- secondary effect names (afflictions, boosts, etc. once the data is structured for searchability)

**Justification for deferral**: alpha movepools are ≤20 moves per unit. Filters cover the common case. Fuzzy search is the right thing for a Pokémon Showdown–scale collection (hundreds of moves), not for what we have. **Re-evaluate once a unit's bank exceeds ~30 moves**.

## 7. Detail column — reuse from unit detail panel

The right column is a **read-only move/passive display widget** lifted from the unit detail panel's existing rows. Same component, just rendered into a different container.

What it shows for a move:
- Move name (large)
- Type icon + damage type icon
- Power, range, AOE, uses
- Description text
- Secondary effects (if any) — apply chance, affliction/boost name, magnitude

For a passive: name, abbreviated name, full description text. Less to show, same widget with hidden fields.

The detail column updates on **any click in any equipped or bank section** — even the read-only passive section while editing moves. This is critical for the "everything visible" principle: the player can read their passive's effects without leaving move-edit mode.

## 8. Passive editing — shared picker, mode toggle

Passives don't have their own picker. The same screen handles both via the **edit mode toggle** at the top:

- **Editing: Moves** — equipped moves slots interactive; equipped passives preview-only; bank = movepool
- **Editing: Passives** — equipped passives interactive; equipped moves preview-only; bank = passive pool

Switching modes is one click — the equipped sections don't move, only the bank content and which slots accept clicks change. This way a player can flip back and forth checking synergies without losing context.

Passive count: 1 or 2 slots depending on class progression (TBD when class schedule lands).

## 9. Input affordances per device

| Action | M&K | Touch | Controller |
|---|---|---|---|
| Highlight | Click | Tap | A button while focused |
| Swap | Click in other column | Tap in other column | A button on second target |
| Switch edit mode | Click toggle | Tap toggle | Bumper or shoulder |
| Toggle filter | Click filter icon | Tap filter icon | Hold a face button to enter filter sub-mode |
| Switch focused unit | Click unit in left strip | Tap unit | D-pad / stick on left strip |
| Back to squad list view | Esc / Done button | Done button | B button |

Focus model on controller: D-pad / left stick navigates between sections and within the current section. **Bumpers (LB/RB) jump between sections** to avoid row-by-row navigation across boundaries.

## 10. Edge cases

- **Bank is empty** (unit has no movepool other than its 4 equipped): bank column shows "No other moves available." Equipped slots can't be swapped — all clicks just preview.
- **Equipping a move already equipped**: can't happen — bank only shows moves *not* currently equipped.
- **Class progression unlocks**: when a unit hits a level that unlocks a new move (per the unported class schedule), it appears in the bank automatically. No "claim" step needed.
- **Switching focused unit mid-edit**: drops any selection highlight, brings up the new unit's loadout. Live commits already saved on the prior unit, so no data loss.

## 11. Build order

| Step | Description |
|---|---|
| **1** | Component skeleton: integrated layout in squad manager right side. Summary header, split equipped (moves top, passives bottom), bank, detail. Placeholder data. **Build each section with a `collapsed: bool` parameter** so tier 1/2 fallbacks (§2 cramped-screen strategy) are a one-line change later. |
| **2** | Selection model: highlight on click, swap on cross-column click within active section, live commit. Inactive section preview-only. |
| **3** | Real data wiring: pull equipped/bank from CharacterData. Alphabetize the bank. |
| **4** | Detail column: lift the move/passive display widget from unit detail panel. |
| **5** | Edit mode toggle: Moves ↔ Passives, switching which section is active and which bank shows. |
| **5a** | **Cramping check** — playtest at 640×360. Pick a fallback tier (0 / 1 / 2). If we're at tier 1, wire the auto-collapse trigger into the edit-mode toggle. |
| **6** | Filters: type + movetype icon row, AND across categories, OR within category. |
| **7** | Polish: keyboard nav, controller focus, touch ergonomics. |
| **8** | *Stretch*: fuzzy search field. Defer until movepool sizes warrant it. |

Steps 1–5 are the MVP that ships with squad manager step C+D (now combined since the picker handles both move and passive editing in one screen). Filters land in step 6.

---

## Related

- [squad_manager.md](squad_manager.md) — parent design doc; the picker is opened from the per-unit detail panel
- [unit detail panel](../scripts/ui/panels/unit_detail_panel/) — reused for the right-column move display
- Existing data: 39 moves in `data/moves/basic_move_bank.json`, passives in `data/passives.json`
