# Squad Manager — Design Doc

**Status**: drafting (2026-04-28). Several open questions, called out inline.

---

## 1. Purpose

A pre-mission screen where the player manages their squad: swap equipped moves and passives, distribute stat-up points, grant bonus XP (bEXP), review injuries, and choose who deploys. Once a mission starts, the squad is **locked in** — no mid-mission swaps.

> *Future possibility: a "home base" tile on the map that lets units swap moves mid-mission. Out of scope for now.*

This screen is the **prep screen** (the existing `prep_screen.gd` is its skeleton). They are the same thing — squad manager = prep screen, just renaming for clarity.

## 2. When it's shown

- After "Begin Campaign" (start screen → squad manager → mission 1)
- Between every mission (post-mission report → recruit picker → squad manager → mission N)
- The Fire Emblem battle-prep model: pause, prepare, deploy.

## 3. Layout & navigation

Single screen, three regions:

```
┌──────────────────────────────────────────────────────┐
│  Mission N of M     [ Show Map ]   Type Coverage:  │  ← top bar
│                                    🜂🜄🜁⚡⚙️🜃        │
├─────────────────┬────────────────────────────────────┤
│                 │                                    │
│   SQUAD (4)     │       Per-Unit Detail              │  ← main
│   [Max  Lv1] ── │       (the unit-detail-panel-ish   │     area
│   [Erny Lv5] ◀  │       view of the selected unit,   │
│   [Maam Lv11]   │       in EDIT mode — stat-up       │
│                 │       buttons, swap-move buttons,  │
│   BENCH (1)     │       swap-passive buttons,        │
│   [Bloodmage L5]│       injury icons, etc.)          │
│                 │                                    │
├─────────────────┴────────────────────────────────────┤
│                                  [ Begin Mission ] │  ← bottom
└──────────────────────────────────────────────────────┘
```

**Two named lists**: "Squad" (deploying) and "Bench" (not deploying). Move between them via:
- **Mouse & keyboard**: right-click a unit to swap its list. Or drag-and-drop.
- **Touchscreen**: long-press a unit and drag, or single-tap to select + tap a destination.
- **Controller**: a face button (proposed Y/Triangle) toggles the focused unit's list. D-pad / left-stick navigates focus.

**Selecting a unit** (left-click / tap / A button) populates the per-unit detail panel on the right.

> **Open questions** (layout):
> - Master-detail vs. tabs vs. side-by-side per-unit? The proposal above is master-detail (list on left, focused detail on right). Confirm?
> - Where does the concise list view (§9) live? Toggle button? Separate screen? Sidebar?

## 4. Per-unit info & editing

This panel **reuses the unit detail panel** with an "edit mode" flag. Edit mode adds:

- **Move slots (4)** — click an equipped move to swap. Pops up a chooser of available moves (from the character's `basePoolMoves` minus already-equipped). Same for unlocked-via-class-progression moves once that schedule lands.
- **Passive slots (1-2)** — same pattern.
- **Stat-up buttons** — one `+` per stat next to the stat row. Available pool of points displayed. Clicking spends one point. Cap: `DEFAULT_STAT_CAPS` from `character_data.gd`.
- **Bonus XP grant** — slider or `+/-` to shift bEXP from a campaign pool onto this character. *(Blocked: bEXP economy not yet implemented.)*

Things that are **shown but not edited** in this panel:
- Portrait, name, class, level, type(s)
- 8 stats (with stat-up bonuses applied)
- Injuries (with same 6×6 icon styling as in-battle, plus tooltips)
- XP-to-next-level bar
- *Not shown*: afflictions, boosts (those only exist mid-battle)

**Move/passive editing** is rich enough to deserve its own design — see [equipment_picker.md](equipment_picker.md). Three-column layout (equipped / bank / detail), click-to-swap selection, alphabetized bank, type+movetype filters, optional fuzzy search.

> **Open question** (per-unit edit, blocked):
> - Bonus XP UX once the economy exists: slider? text input?

## 5. Squad-level info

Top bar:
- **Mission N of M** (read from CampaignManager)
- **Show Map** toggle — see §5a below
- **Type coverage** — see §5b below

### 5a. Backdrop: concept art / war tent + Show Map toggle

The default backdrop is **concept art for the next mission** (Fire Emblem's "war tent" framing — a comfy narrative pause). The **Show Map** toggle removes the concept art and reveals the actual mission map underneath, so the player can plan deployment with terrain visible. Toggle is non-modal — the player can keep editing the squad with either backdrop active.

### 5b. Type coverage display

Computed from the **squad's combined active movepool** (union of every deployed unit's equipped moves). For each elemental type defenders could have, we figure out the best matchup the squad can get against that type, bucketing into:

- **Super effective** — squad has at least one move that's super-effective against this type
- **Normal** — best matchup is neutral
- **Resist** — best matchup is resisted
- **Immune** — best matchup is no-effect

Layout: **one row per coverage level**, label on the left, type icons that fall in that level on the right. Hide the **Immune** row if empty (rare); other rows always visible (an empty "Super" row is meaningful info — "we can't hit anything super-effectively").

Same component can render either per-unit (single unit's movepool) or whole-squad (union). For now we display whole-squad in the top bar; per-unit version may show up in the per-unit detail panel later.

## 6. Squad/bench mechanic

- Default state: every alive roster member is in **Squad**, none on Bench.
- Hard cap: **Squad size ≤ map's player spawn tile count**. Adding a unit to the Squad when full requires removing one (or swap is blocked).
- **No confirmations** — every move/swap commits immediately. The screen state is the truth; Begin Mission just deploys what's there.
- **Injured units may be deployed**, but it's usually a bad idea. No warning dialog — players learn by doing.
- **All-bench is invalid** — Begin Mission disabled if Squad is empty (already implemented in step B).

## 7. Spawn position reordering

Players want to choose *where* on the map their units start. Without this, the spawn order is determined by something arbitrary (current behavior: roster registration order in SquadManager).

**Three options ruled out:**
- Disallow reordering → annoys players.
- Deterministic-but-fixed ordering → players game-restart for trial-and-error favorable arrangements.
- Random → players game-restart for favorable rolls.

**Chosen approach**: on-map click-to-swap. With **Show Map** toggled on (§5a), the player sees their units on actual spawn tiles. Click one unit, click another → swap their positions. Long-press / right-click / face-button (controller) → opens that unit's detail panel.

This means the prep flow naturally has two modes:
- **Concept-art backdrop**: focus on equipping moves/passives, allocating stats
- **Show-Map backdrop**: focus on positioning units on the actual battlefield

Both modes share the same Squad/Bench list and per-unit detail panel — Show Map just changes the backdrop and lets the user click on tiles.

> **Implementation challenge**: making click-to-swap feel right across M&K, touch, and controller. Each input method has different affordances for "select then act":
> - **M&K**: click selects (highlight), click on second unit swaps. Hover preview shows what the swap would look like.
> - **Touch**: tap selects, second tap on a different unit swaps. Maybe a "selected" outline so the user knows they're mid-swap.
> - **Controller**: D-pad/stick navigates a cursor across spawn tiles. A button picks up / drops the unit.
>
> Long-press (or contextual button) opens the unit detail panel without entering swap mode. Need consistent affordance across input methods.

## 8. Concise list view

A master-detail compression of the squad. The roster shows as a list (or grid) of full-width unit cards, but **selecting one collapses the list cells into a narrow strip** while the right side expands to show that unit's full editing surface.

```
# No selection — full cards in a grid/list:
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ MAX STELLAR     │  │ ERNESTO         │  │ MA'AM           │
│ [portrait]      │  │ [portrait]      │  │ [portrait]      │
│ Simple Spaceman │  │ Simple Engineer │  │ Simple Skulk    │
│ Lv 1            │  │ Lv 5            │  │ Lv 11           │
│ HP 21 STR 6     │  │ HP 28 STR 12    │  │ HP 35 STR 8     │
│ SPC 5 SKL 3     │  │ SPC 5 SKL 10    │  │ SPC 9 SKL 17    │
│ ...             │  │ ...             │  │ ...             │
└─────────────────┘  └─────────────────┘  └─────────────────┘

# After selecting Max Stellar:
┌──────┬───────────────────────────────────────────────────┐
│ MAX  │  MAX STELLAR — Lv 1  Simple Spaceman              │
│ [pt] │  [full per-unit detail panel — moves, passives,   │
│ Sim  │   stats, injuries, edit buttons, type coverage]   │
│ Spcm │                                                   │
│ HP21 │                                                   │
├──────┤                                                   │
│ ERN  │                                                   │
│ [pt] │                                                   │
│ Sim  │                                                   │
│ Engn │                                                   │
│ HP28 │                                                   │
├──────┤                                                   │
│ MAA  │                                                   │
│ ...  │                                                   │
└──────┴───────────────────────────────────────────────────┘
```

The narrow strip shows just enough to identify the unit: portrait thumbnail, name (abbreviated if needed), type, class, and a one-line stat readout. Clicking another card in the strip switches focus — no Back button needed.

This is the primary layout for the squad manager. The "no selection" state above is the entry point; selecting a unit transitions into edit mode.

## 9. Edge cases & rules

- **Squad < spawn tiles**: allowed. Empty tiles stay empty in the mission. Unit positions on map come from the player's order in the Squad list.
- **Squad > spawn tiles**: not allowed. Squad cap = mission's player spawn tile count; UI prevents adding past it.
- **All units injured**: still allowed to deploy them; injuries apply their stat penalties as usual.
- **Roster change mid-prep** (e.g. permadeath happens between battle end and prep screen reload): roster shrinks; if the previous deployment selection referenced a now-permadead unit, that ID is dropped. Handled by the `_get_deployed_roster` filter — already correct.
- **First-time campaign start**: default deployment = full roster, capped at spawn tile count. If `roster.size() > spawn_tiles`, the overflow goes to Bench by default and the player can swap.

## 10. Dependencies & blockers

| Squad manager feature | Depends on (not yet built) |
|---|---|
| Stat-up allocation | Class progression schedule (Unity's `LevelUpReward` array — what reward is granted at each level per class). Without this, `available_stat_ups` is always zero. **Workaround for alpha**: ship the UI but the +/- buttons are no-ops since the pool is empty. |
| Move pool growth | Same class progression schedule (which moves unlock at which class levels). For alpha: only `basePoolMoves` are equippable. |
| Passive pool growth | Same. For alpha: only `basePoolPassives`. |
| Bonus XP grant | bEXP economy — `mission_objectives.md`. Until objectives are built, no bEXP is earned. **Workaround**: hide the bEXP UI until the economy lands. |
| Roster persistence between game sessions | Save/load. Out of scope for alpha. |
| Type coverage display | Existing elemental type icons (already shipped). No blocker. |
| Show map backdrop | Battle scene loadable in preview mode (no input, just rendering). Some refactor needed. |

## 11. Out of scope for alpha

- Supports / bond relationships
- Recruit-refusal flow ("the new recruit doesn't want to join your party")
- Batch operations across multiple units
- Advanced filtering / sorting
- Save/load roster state
- Mid-mission "home base" swap tile

## 12. Build order

| Step | Status | Description |
|---|---|---|
| **A** | ✅ done | Skeleton: roster grid, Begin Mission button. Renders all roster members. |
| **B** | ✅ done | Squad / Bench toggle. Default all in Squad, click to bench (currently uses `modulate.a` dimming, not a true two-list layout). |
| **B.5** | TODO | Refactor B into the proper two-list layout ("Squad" / "Bench" headers + drag/right-click). Adds polish without new mechanics. |
| **C** | TODO | Per-unit detail panel in edit mode: move-slot swap UI. Reuses unit detail panel with edit-mode flag. |
| **D** | TODO | Per-unit detail panel: passive-slot swap UI. |
| **E** | TODO | Concise list view (toggle from card view). |
| **F** | TODO | Type coverage display in top bar. |
| **G** | TODO | Spawn position reordering (drag in Squad list, then controller swap-with-neighbor). |
| **H** | TODO | Show Map backdrop button. |
| **I** | blocked | Stat-up allocation UI (blocked on class progression schedule). |
| **J** | blocked | Bonus XP grant (blocked on bEXP economy). |

Steps E–H are independently shippable polish that doesn't depend on missing systems. I, J wait for their backing systems.

## 13. Open questions to resolve before C–H

- ~~Move/passive swap UX~~ — resolved, see [equipment_picker.md](equipment_picker.md). Three-column picker, click-to-swap, alphabetized bank, type+movetype filters.
- **Concise list view collapse model** — progressive (width-based) vs. user-toggled per column. *Need confirmation.*
- ~~Spawn reordering~~ — resolved. On-map click-to-swap with Show Map toggle. UX challenge: making it feel right across all 3 input methods (see §7).
- ~~Type coverage display~~ — resolved. 4-level rows (Super / Normal / Resist / Immune), populated from squad's union movepool, hide Immune row if empty.
- ~~Show Map~~ — resolved. Concept-art backdrop by default, toggle to reveal map underneath. Non-modal — keep editing while either is showing.

Remaining design unknowns are mostly inside [equipment_picker.md](equipment_picker.md) and around the bonus-XP UI (blocked on bEXP economy).

---

## Related

- [alpha.md](alpha.md) — Alpha milestone scope
- [todo.md](todo.md) — alpha item #3 references this doc
- [mission_objectives.md](mission_objectives.md) — bEXP economy that grants the bonus XP feature
- [equipment_picker.md](equipment_picker.md) — move/passive swap UX (§4)
- Existing impl: [prep_screen.gd](../scripts/ui/prep_screen.gd), [campaign_manager.gd](../scripts/managers/campaign_manager.gd)