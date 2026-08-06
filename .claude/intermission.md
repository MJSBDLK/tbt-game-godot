# Intermission — Design Doc

**Status**: drafting 2026-08-03 (RQD design session, screen 2 of the intermission
redesign arc). Supersedes the layout half of [squad_manager.md](squad_manager.md);
that doc's *rules* (squad cap, no-confirmations, edge cases, dependency table)
still stand and are not repeated here.

Parent arc: main menu (shipped, `rqd--main-menu`) → **this** → result → level-up →
bEXP → recruit → campaign-complete.

---

## 1. What the intermission is

The between-mission pause. Fire Emblem's battle prep: everything you can change
about your crew, then deploy. It is **not** the main menu — per the locked "same
stage, two roles" decision, the two share the ship-interior backdrop and the
chrome vocabulary but are separate screens with separate jobs:

| | Main menu | Intermission |
|---|---|---|
| Fiction | out-of-fiction | in-fiction — you are on the ship |
| Job | manage *saves* | manage *crew* |
| Entered from | boot | mission end → recruit → here |
| Leaves to | a save | a mission |

## 2. Shape — a hub, then workspaces

```
  INTERMISSION HUB                    MANAGE UNITS
  (menus venue: bare text)            (HUD venue: glass panels)
  ┌────────────────────────┐          ┌──┬──────┬────────────┐
  │ Manage Units      ★3   │  ──────▶ │  │      │            │
  │ Allocate Bonus EXP 340 │          │  │      │            │
  │ Mission Briefing       │          │  │      │            │
  │ ▛Begin Mission▟        │          │  │      │            │
  │ Save / Options / Quit  │          └──┴──────┴────────────┘
  └────────────────────────┘
```

**Venue rule (new, for the style guide).** The hub is the *menus venue* — bare
glowing text, corner ticks, lit-border default action, no plate (§14). The
workspaces are the *HUD venue* — glass panels, borders, the full button
vocabulary. Reason: bare text needs a quiet ground to read against; dense data
needs a plate to sit on. Same stage, two chrome weights. The backdrop dims
harder under a workspace than under the hub.

### 2a. Hub entries

Order is task order, top to bottom, then the system tail:

| Entry | Sub-line (INFO voice) | Notes |
|---|---|---|
| **Manage Units** | `4/5 deployed · 3 StatUp` | The big one. §3. |
| **Allocate Bonus EXP** | `340` | Deep-links into Manage Units (§3g). Inert at pool 0. |
| **Mission Briefing** | `2 objectives` | §5. |
| **Begin Mission** | — | **Default action** — wears the lit-border box. |
| Save Game / Options / Quit to Menu | — | System tail, visually separated by a gap. |

Sub-lines are live, not decoration: deploy someone, spend a point, buy a level,
and they follow. Deployment reads `deployed/cap`, never a bare count — the cap
is half the information.

**Vocabulary (RQD 2026-08-03):** the resource is a **StatUp**, not an "unspent
stat-up point". Spelled that way wherever there is room for a word (`3 StatUp`,
`3 StatUp to spend`, `no StatUp to spend`). `★N` survives only as the compact
glyph on a roster card, where the word doesn't fit — with the words in its
tooltip.

**Unfinished business is advertised, never enforced.** The StatUp count rides
Manage Units; the banked amount rides the bEXP row. Begin Mission is *never*
blocked or confirmed by unspent resources — that's the squad manager's
no-confirmations rule (§6 of squad_manager.md), and a "are you sure? you have
points left" dialog is exactly the kind of nag this project doesn't ship. The
badge is the nudge.

### 2b. Save Game latches

After a save the entry reads **"Game saved!"** in the success voice and its
border goes unlit, until the player changes something — then it re-arms as
"Save Game". Two locked vocabularies composing instead of a toast: success color
says *it worked*, unlit border says *nothing to press* (§14). The dirty flag is
set by any roster or unit mutation — deploy/bench, move or passive swap, StatUp
allocation, bEXP purchase.

**Save Game stays** (RQD 2026-08-04). Earlier drafts guessed the entry would
arrive pre-latched because "the campaign already autosaves at mission boundaries."
**It does not** (verified 2026-08-04): autosaves are battle-only — `SaveManager`
writes on `player_phase_started` and early-returns when `capture_battle_snapshot()`
is empty, and `CampaignManager` never saves at all. The entry arrives **armed**.

### 2c. Base autosave — TO BUILD (decided 2026-08-04, not yet implemented)

**Current state, for the record: there is NO save of any kind at the mission
boundary.** Autosaves are battle-only — `SaveManager` writes on
`player_phase_started` and early-returns when `capture_battle_snapshot()` is
empty; `CampaignManager` never saves. Today's three rings:

| Ring | Color | Written when |
|---|---|---|
| `KIND_AUTO_BATTLE` | blue | player-phase start, turn ≤ 1 (mission start) |
| `KIND_AUTO_TURN` | yellow | player-phase start, every later turn |
| `KIND_MANUAL` | plain | system-menu Save |

**The gap:** nothing is written between the last turn of mission N and turn 1 of
mission N+1. Quitting from the intermission should leave the newest save as a
mid-battle turn autosave *from the mission just completed* — "Continue" rewinds
into a finished battle and every StatUp, move swap, and bEXP purchase is gone.
(Reads clearly from the code path; wants an in-game repro to confirm.)

**Decision (RQD): a FOURTH ring — base autosaves, separate from battlefield
autosaves, 4 slots, same rotation rule.** Base and battlefield are different
contexts and shouldn't evict each other; folding base saves into the blue
mission-start ring was considered and rejected, since it would make one ring hold
two event types and cost mission-start history.

- Trigger: **entering the intermission.** One trigger is enough — leaving is
  already covered by the next mission's turn-1 write, which captures campaign +
  squad + battle together. No second write on Begin Mission.
- No new machinery: `build_snapshot()` already takes `battle` as optional, which
  is exactly what `write_manual_save()` uses when no battle is running.
- Ring total goes 3 → 4 (12 → 16 slots). `list_saves()` iterates a hardcoded
  `[KIND_AUTO_BATTLE, KIND_AUTO_TURN, KIND_MANUAL]` array — add the new kind
  there or the ring won't appear in the browser.
- **Needs a color.** Only `SAVE_AUTO_TURN` (yellow) and `SAVE_AUTO_BATTLE` (blue)
  exist today; manual renders as plain text. The base ring wants a fourth
  identity in the browser's legend — a Lawrence call, placeholder until then.

### 2d. Manual saves — DECIDED 2026-08-04

**Prompt only when the press would destroy something.**

Today `write_manual_save()` calls `write_autosave(KIND_MANUAL, …)` → `_pick_ring_slot`,
which is *"first empty slot wins; otherwise the oldest is overwritten."* Manual
saves therefore rotate exactly like autosaves, and **the 5th manual save silently
destroys the 1st.** Rotation is right for autosaves — unrequested, so evicting the
oldest is the point — and wrong for manual saves, where the press *is* the intent
to keep that state. A rotating manual ring is a contradiction.

| Situation | Behavior |
|---|---|
| A manual slot is free | Silent write, entry latches to "Game saved!" (§2b intact) |
| All 4 manual slots full | Picker opens: 4 slots with label + age; choosing one overwrites it |
| Picker cancelled | No write, **no latch** — the entry stays armed |

The latch survives for the common case, and the interruption appears exactly when
a real decision exists. Autosave rings are untouched and keep rotating.

**Port notes:** split the oldest-eviction branch out of the manual path —
`find_free_manual_slot() -> String` (returns `""` when full) plus an explicit
`write_manual_save_to(path)`; the caller opens the picker when the lookup comes
back empty. The picker is [SaveBrowserPanel](../scripts/ui/panels/save_browser_panel.gd)
in a second mode: render all 4 manual slots *including empty ones* and emit
`slot_chosen(path)` instead of `save_chosen(path)`. That's a mode flag and a
signal, not a new panel.

## 3. Manage Units — one screen, no modes

> RQD 2026-08-03: *"I want all of the functions in one screen. I don't want
> separate screens for 'assign moves,' 'assign passives,' 'allocate statUps'."*

### 3a. The unifying idea

**Click a slot; the workbench offers what fits in it.** There is no mode toggle,
no tab, no "Editing: Moves | Passives" switch. The lane is *implied by what you
clicked*. This is the whole design and everything else follows from it.

This replaces [equipment_picker.md](equipment_picker.md) §8's explicit edit-mode
toggle. That toggle was a modes-and-verbs design: set the mode, then act. This is
noun-first: touch the thing you want to change. Fewer clicks, nothing to
remember, and it generalizes — stat-ups and bEXP fall into the same interaction
without inventing a third mode.

### 3b. Three permanent columns

```
┌───────────────────────────────────────────────────────────────────┐
│ ◀ Intermission    MISSION 2 OF 3    bEXP 340    SQUAD 4/6         │ top bar
├──────────┬──────────────────────┬─────────────────────────────────┤
│ ⌕ ▲ LVL  │  MAX STELLAR         │  MOVE SLOT 2                    │
│──────────│  Spaceman  Lv 5      │  [type filters] [phys/spc/sup]  │
│ ▪ Ma'am  │  Simple / —          │  ─────────────────────────────  │
│    11    │  ▓▓▓▓▓░░░ 340/100    │  Backhand      Phys  Pow 8  R1  │
│ ▪ Ernst  │                      │  Compressed Air Spc  Pow 6  R2  │
│     5    │  HP  24  +   STR 12+ │  Cyclone ...                    │
│ ▪ Max ◀  │  SPC  8  +   SKL  9+ │  ─────────────────────────────  │
│     5    │  AGL 11  +   ATH  7+ │  BACKHAND                       │
│ ▪ Elf    │  DEF  6  +   RES  5+ │  Physical · Simple · Pow 8 · R1 │
│     5    │  ★3 to spend         │  "A sweeping strike with the    │
│──────────│                      │   mechanical arm."              │
│ BENCH    │  MOVES               │  Effects: —                     │
│ ▫ Robot  │  ▸ Bonk   Laser      │                                 │
│     3    │    Klunk  Uppercut ◀ │                                 │
│ ▫ Gob    │  PASSIVES            │                                 │
│     2    │    Anti-Gravity  [+] │                                 │
│          │  INJURIES  ✚ Sprain  │                                 │
└──────────┴──────────────────────┴─────────────────────────────────┘
   ~110px          ~212px                      ~294px
```

- **Roster rail** — who am I editing. Search, sort, deploy state. §4.
- **Unit sheet** — the unit's *state*. Every editable thing on it is a slot.
- **Workbench** — the pool / allocator / explainer for the selected slot.

The sheet never scrolls away and never changes shape. Switching units keeps the
selected slot kind where possible (click Move 2 on Max, click Ernesto in the
rail → you're on Ernesto's Move 2), so comparing loadouts across the squad is a
single click per unit.

### 3c. Reading beats swapping — detail first, bank second

The workbench reads **top to bottom: detail → swap bar → bank**, not the other
way round. RQD 2026-08-03: *"a player may simply have wanted to know what the
move does, not necessarily swap it out."*

So clicking an equipped slot is an **inspect** action. The move you touched gets
the headline at full size — name, damage/element icons, power, range, its own
copy — and nothing on screen suggests you were about to change anything. The
bank sits below it under a swap bar reading *"equipped — pick one below to swap
it out."*

Picking a bank entry is the second, explicit step. The detail switches to the
**candidate** (you're now reading about the incoming move), and the swap bar
keeps the outgoing one in view with its numbers:

```
replaces  Bonk  Pow 6 R1                         [ Equip ]
```

Clicking the same bank row again drops the candidate and falls back to reading
the equipped move. Live commit on Equip, no Cancel (squad_manager §6).

### 3d. Slot → workbench map

| Slot clicked | Workbench shows |
|---|---|
| Move slot 1–4 | The equipped move's detail, then swap bar, then the filtered bank |
| Passive slot 1–2 | Same shape, passive bank |
| A stat row | What the stat *does*, where it stands against its cap, how many StatUps are already in it, and the same stat across the squad |
| Level / XP row | **bEXP purchase**: this unit's price, the pool, and the price of every other deployed unit |
| An injury chip | Injury detail: real copy, affected stat, severity band |
| Nothing selected | Unit summary: type coverage, equipped list |

The stat panel is the sleeper win. Nothing in the game currently explains what
ATH does — it's attack count, not movement — and this gives that copy a
permanent home the player visits at exactly the moment they care.

Note what the inversion did to the stat lane: the `+`/`−` moved **onto the sheet
row** (§3e), so allocating never requires the workbench at all. The workbench
became the place things are *explained*, and only sometimes the place they're
changed. That's the healthier division.

Bank ordering (alphabetical), filter behavior, and live-commit carry over from
equipment_picker.md §3–§5. What dies is §8's mode toggle, §2's four-column
layout, and its two-click implicit swap.

### 3e. The stat row

```
HP  [−]  24 ··  [+]        AGL  [−]  11 ·  [+]
STR [−]  12 ··  [+]        ATH  [−]   7    [+]
SPC [−]   8     [+]        DEF  [−]   6 ·  [+]
SKL [−]   9 ··· [+]        RES  [−]   5    [+]
```

Label, decrement, value, **StatUp tally**, increment — RQD's spec. The tally is
how many StatUps have already gone into that stat. It isn't decoration: `[−]`
refunds, and without a visible tally there's no way to tell refundable points
from growth rolls (`allocated_*` is already tracked separately from
`growth_gains_*` in `character_data.gd`, so this displays a distinction the data
already makes).

**Nothing in the row stretches** (RQD 2026-08-03: *"a lightyear of negative
space"*). The tally slot is fixed at exactly the pips' width, so `[+]` sits
where the number ends. The row lands at ~77px.

**Tally is stacked, two rows deep**, so ten StatUps cost 13px of width instead
of 40 — RQD's "stack the +s so they look like a #" instinct, taken literally.
A flat run of `+` is the alternative and stays a one-line switch.

Which fixes the left-side awkwardness for free: at 77px the row fits **two
columns of four**, so the leftover space goes to the other four stats instead of
becoming a gutter. Column split matches `StatFingerprint`'s existing convention —
HP/STR/SPC/SKL left, AGL/ATH/DEF/RES right. Saves ~44px of vertical too.

### 3f. Icons, not text tokens

Every type, damage type, and injury renders as its **10×10 icon** from
`art/sprites/ui/`, never a truncated word. Filter chips are 14px squares
(10px icon + border), damage types then elements.

Drawing with the real art immediately caught invented data: there is no Metal,
Wind, or Light type. The real ramp is Simple · Air · Chivalric · Cold · Electric
· Fire · Gentry · Gravity · Heraldic · Occult · Plant · Robo · Void. Missing art
still reserves its 10px so the layout can't lie about the space it needs.

> Open: `move_type_icons_10x10/` has `special_a` … `special_g` — seven candidate
> special icons and nobody has picked one.

### 3g. bEXP lives on the level row

There is **no price to display** — flattened 2026-08-06. A level costs
`SquadManager.BEXP_LEVEL_COST` (100) for everyone at every level; the level-scaled
price tag this section used to describe was deleted, because catch-up belongs in
the combat award and a second rubber band hidden in a shop price is a rule the
player can't see. The pool sits in the top bar and *is* the readout: pool ÷ 100 is
how many levels you have to hand out.

The hub's **Allocate Bonus EXP** entry is a *deep link*, not a second screen: it
opens Manage Units with the level row pre-selected and the rail sorted
**level-ascending**. That sort was carrying the catch-up signal implicitly all
along; with pricing gone it's now the *only* thing pointing at who needs the XP,
which makes it load-bearing rather than a convenience. Keep it.

### 3h. The trace (cursor model only)

RQD 2026-08-03: *"it would be cool if a line appeared, styled like an embedded
wire on PCB, connecting it with the now-highlighted section the user is
interacting with."*

When the player is aiming with a controller or the keyboard, a **board trace**
runs from the slot they've selected to the workbench panel it opened —
orthogonal runs joined by a 45° dogleg, a via pad at each end, 1px in the
primary azure. Diegetically right for a ship, and it makes the causal link
literal.

Rules:

- **Cursor model only** (`InputSource.is_cursor_driven()`). A mouse user just
  clicked the thing; a wire chasing the pointer is noise. This is the same
  one-aim-one-model doctrine the main menu already ships.
- **Every slot kind, not just moves.** The wire is the clearest possible
  statement of this screen's one rule — the workbench is downstream of the slot
  — so it should teach that on stats and the XP row too, not only on swaps.
- It re-routes when the layout does (third column → right-hand routing, bottom
  drawer → downward routing).
- Motion-gated: the slow traveling dash along the trace goes away with the
  reduced-motion / motion-off setting; the static wire stays.

Port note: an `@tool`-free `Control` drawing with `draw_polyline` +
`draw_rect` for the vias, parented above the panels. It needs the slot's and
the panel's rects in a shared coordinate space, which inside HUDViewport means
`get_global_rect()` on both — no HUD↔native projection involved.

## 4. The roster rail — where benching and the browser live

> RQD: *"Stuff that needs to be there but I'm not sure where to put it: benching /
> unbenching units; a unit browser which lets the user sort (asc/desc) by level,
> stats, and ideally a fuzzy search text field."*

**Both are the rail.** They're the same object — a sortable, searchable,
deploy-toggling index — so neither needs a home of its own.

### 4a. The sort key is the readout

A 110px rail cannot show eight stats. It doesn't need to: **sorting by a stat
puts that stat on every card**, right-aligned, in order. Sort by SKL and every
card reads its SKL; sort by level and every card reads its level. One number per
card, always the one you asked for. Scanning and sorting become the same act.

- Sort control cycles the key: `Squad order · Level · Name · HP · STR · SPC ·
  SKL · AGL · ATH · DEF · RES`. Pressing the arrow flips direction.
- **Default key: Squad order, ascending**, deployed-first.

**Why squad order is the default** (RQD 2026-08-03 — it started as an accident
of roster order and is now deliberate): the readout becomes `1, 2, 3…`, which is
the order these people *joined*. It's the only sort key that carries narrative —
the roster doubles as a record of what happened before the campaign started, and
a returning player's first sight is their crew in the order they met them. Every
other key is a tool; this one is also a story. Level-descending is just another
option, and the bEXP deep link deliberately overrides to level-*ascending*.

### 4b. Search

A one-line field at the rail head. Substring (not fuzzy) across name, class, and
elemental type. Substring is enough at roster sizes under ~30 and — more
importantly — it's *predictable*, which is the same reason the bank stays
alphabetized. Revisit fuzzy if a roster ever passes 30.

### 4c. Deploy state

- A pip at the card's left edge: filled = deployed, hollow = benched.
- **Deployed units always sort above the bench line**, whatever the sort key.
  The line is labeled with the cap: `SQUAD 4/6` above, `BENCH` below.
- Toggle: click the pip, or press the bench key with the card focused. One glyph
  wide — the old `→ Bench` text button ate a third of the card and is retired.
- Benched units stay **in the same rail**, dimmed, never on a separate tab. RQD's
  bEXP notes want players not to permanently bench anyone; a hidden bench makes
  forgetting effortless.
- At cap, bench→deploy pips go inert (the existing rule), not silently ignored.

### 4d. Sorting must not move spawn positions

Today deployment order comes from roster order, which decides where units spawn.
**A sortable rail cannot also be the spawn order** — re-sorting to compare AGL
would silently rearrange the battlefield. So: spawn position is decoupled from
rail order and belongs entirely to the Show Map surface (squad_manager.md §7).
Until Show Map ships, spawn order stays whatever `SquadManager` roster order
gives — stable, unaffected by rail sorting.

This is a real behavior change from `prep_screen.gd` and needs a test.

## 5. Mission Briefing

Objectives, from `mission_manifest.json` (already built). **No par-terms
schedule** — RQD 2026-08-03: *"I do like mission briefing, but I don't like
listing the par terms."* No "par 6 / dawdle 12" table, and no HUD countdown ever.

That looked like a live tension with the bEXP amendment ("par bands are a
displayed fact, never a hidden incentive"). **RESOLVED 2026-08-04 (RQD): there is
no collision.** Par time is simply *one of the objectives* — it goes in the list
like any other, no par table, no special casing. Option (a) in substance, but with
a design rule attached that matters more than the display question:

> **Prefer diegetic objectives over turn counters.** As often as possible, an
> optional objective should have an in-fiction reason to exist rather than being
> a second clock bolted onto the first. Canonical example: an enemy courier
> escapes the map on turn 6. The objective reads **"Intercept enemy courier"** —
> *not* "Clear within 6 turns." The deadline is real and identical, but it lives
> in the level design instead of the UI.
>
> RQD: *"I personally don't like ticking clock mechanics. But this subtle change
> doesn't* feel *like a ticking clock."*

Consequences for authoring: `mission_manifest.json` objectives should carry the
diegetic phrasing, and maps should be built so the deadline has an on-board cause
the player can see coming (a unit that flees, a structure that falls, a rising
tide). Two bare turn limits on one map is the smell to avoid — if a map needs a
second time pressure, give it a body.

## 6. Deliberately not in v1

| Deferred | Why |
|---|---|
| Show Map backdrop + spawn reordering | Its own surface (squad_manager §7); the rail work doesn't block it |
| Squad type-coverage row | Top-bar space is spoken for; add once the rest settles |
| Compare table (all units × all stats) | The rail's sort-key readout covers the common case; revisit if RQD misses it |
| Supports / bonds, batch ops | Out of alpha scope (squad_manager §11) |

## 7. Port notes

- `prep_screen.gd` becomes the **hub** — it loses the roster/detail split and
  becomes a menu column reusing `MainMenuEntry` + `MenuStageBackdrop`.
- A new `manage_units_screen.gd` takes the three-column workspace.
- `equipment_picker.gd` (1150 lines) is absorbed: its bank, filters, click-to-swap,
  and detail widget become the workbench's move/passive lane. Its mode toggle and
  its own summary header are dropped (the sheet owns those now).
- The StatUp badge logic moves from the prep card to the rail card (`★N` glyph)
  and the hub entry (worded). `_make_unspent_badge`'s "%d unspent stat-up point"
  tooltip copy changes to the StatUp wording.
- The hub needs a dirty flag for the Save Game latch (§2b) — every mutation path
  in the workspace has to set it, which argues for routing them through one
  `_mark_dirty()` helper rather than sprinkling assignments.
- `MenuStageBackdrop` is reused as-is, with a heavier dim under workspaces.

## 8. Resolved / open questions

**RESOLVED 2026-08-04 (RQD):**

- **Par schedule disclosure** — settled in §5: par is just another objective, and
  objectives should be diegetic rather than bare turn counters.
- **The hub survives.** RQD: *"I like the hub for 'comfy' reasons… there's value
  in showing a mostly empty screen for narrative reasons, even if it's about to
  be filled with stats and move data in a sec anyway."* The one-screen instinct
  loses on purpose — the near-empty hub is doing **pacing** work, giving the
  player a quiet beat between the battle and the spreadsheet. Role compression
  into Manage Units stays the goal ("a laudable goal, so long as it's not
  confusing to the user"), but it compresses *within* the workspace, not by
  eating the hub.
- **bEXP merges into the management screen.** Confirms the deep-link design
  already sketched (§4): pool in the top bar, price tag on the level row, and the
  hub's "Allocate Bonus EXP" entry is a deep link into Manage Units with the level
  row preselected and the rail sorted level-ascending. It is **not** a separate
  screen.

**Still open:**

- Save Game on the hub — redundant with a boundary autosave? (§2b)
- Passive slot count is still class-schedule-dependent (1 or 2). Rendering
  assumes 2 with the second inert when unavailable.

## 9. The pixel budget — measured, not eyeballed

Screen real estate is the whole risk on this screen, so these numbers come from
the actual font metrics (`UndeadPixelLight8` @8px, `UndeadPixelLight11` @11px,
`NotJamPixel5` @5px — `unitsPerEm` 1024, advances read out of `hmtx`), not from
a browser stand-in.

**Horizontal**, 640 total: `4 │ rail 132 │ 4 │ sheet 210 │ 4 │ workbench 282 │ 4`

**Vertical**, 360 total: top bar 16, body padding 8, columns get **336**.

| Element | Needs | Has | Verdict |
|---|---|---|---|
| Rail card name | 69px worst case (`Gravity Captain`) | `rail − 59` | **132px rail required.** At 112 the slot is 53px and `Gravity Captain` (69) and `Healer Goblin` (61) both clip. This is the one thing the eyeball version got wrong. |
| Stat row `HP [−] 24 ·· [+]` | 77px | 97px per column | Fits **two columns of four** with ~20px slack. Nothing stretches. |
| Move slot (2 columns) | 65px (`Compressed Air`) | 78px of text room | Fits. |
| Unit name @11px | 69px | ~162px | Fits. |
| Sheet, stacked | ~193px | 336px | ~143px headroom — enough for the 2nd passive slot, all four injury chips, longer names, and whatever §6 un-defers first. |
| Rail, 6 units + 2 headers | ~168px | 336px | ~20 cards before it scrolls. |
| Detail body copy | 193px longest line | ~268px | Fits without wrapping; wraps gracefully when it doesn't. |
| Filter row, 16 chips @14px | 276px | 268px | **Wraps to two rows.** Fine, but it's a wrap, not a fit — worth knowing before someone adds a 14th element. |

Caveat: borders and padding in the mockup are CSS, not Godot `StyleBox` insets,
so every column width carries ±2px. The claim these numbers support is "the
content fits at 640×360 with real headroom," not "these are the final constants."

---

## Related

- [squad_manager.md](squad_manager.md) — rules, edge cases, dependency table (still authoritative)
- [equipment_picker.md](equipment_picker.md) — bank/swap/filter semantics carried over; §2 layout and §8 mode toggle superseded
- [mission_objectives.md](mission_objectives.md) — par bands + bEXP income the briefing displays
- [ui-style-guide.md](../data/design/ui-style-guide.md) — §14 border vocabulary; the venue rule in §2 above wants a home there
