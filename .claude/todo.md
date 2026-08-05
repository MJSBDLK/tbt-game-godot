# TBT Game — Open Work

Everything still to do. **Completed work + its shipped-notes live in
[todo-archive.md](todo-archive.md)** — check there before re-litigating a decision;
most "why does it work this way" answers are in an old shipped-note.

**How this is ordered:** §1 is what actually gates Alpha. §2–4 are the three
recurring blockers that kept getting filed as separate one-off tickets. §5+ is
everything else, roughly by how soon it matters.

**Status markers:** `[ ]` not started · `[~]` partially done, detail inline ·
`[?]` status unknown, needs a look.

---

## 1. Alpha blockers

- [ ] **Squad / prep + between-mission level-up screen.** *(The single biggest
  open item — flagged PRIORITY twice, in two different sections, for months.)*
  Pick squad, equip moves (~330 in the bank), equip passives, distribute stat
  allocation points. One screen does double duty: initial prep AND the
  between-mission level-up display (XP gained, stat-up rolls, new moves/passives
  unlocked). Build initial prep first; the level-up overlay reuses most of the
  same widgets. See [equipment_picker.md](equipment_picker.md) and
  [squad_manager.md](squad_manager.md).
  - Related design note: the level-up moment is a *dopamine beat*, not a text
    dump — budget polish from day one.
### Subtasks
  - [ ] For the bEXP allocation system, I think we should have buttons:
    [-10][-1][+1][+10][99][100]
    May want +/- 5 in there. Probably not to start. What do you think?
    Need a clear pool total to see what we're spending from
    - **Unblocked 2026-08-05.** These buttons need a flat pool to act on, and
      that's now the doctrine (below). Once `bexp_level_cost` is gone, they
      spend from a flat pool at 100/level and the pool total is the readout.
      ±5 agreed as probably-not-to-start.

  - [ ] **Flatten bEXP to a simple pool** — doctrine amended 2026-08-05
    ([mission_objectives.md](mission_objectives.md) "XP Economy"). The shipped
    price-tag model (`100 × level ÷ squad_max`, floor 25) re-introduced
    "higher level = harder to level" in bEXP currency, which RQD had explicitly
    argued against; it was recorded as locked but never ratified. Delete
    `SquadManager.bexp_level_cost` + its three constants, charge a flat 100 in
    `buy_bexp_level`, rewrite the BonusXpPanel "SPEND MODEL" header note.

  - [ ] **Delete `TIER_LEVEL_BOOST`** ([combat_xp_calculator.gd](../scripts/combat/combat_xp_calculator.gd)).
    `internal_level = level + (tier−1)×20` is a normalization device for FE's
    reset-on-promotion; our level scale is continuous 1–60, so it double-counts
    and would crater kill XP by 70% at levels 21 and 41. **Dormant today** (tier
    is stubbed at 1 everywhere) so it's safe to remove any time — but it MUST go
    before tier is ever derived from level. Prune the stale intent comment at
    `character_data.gd:30` too. Rationale in
    [class-and-promotion.md](../data/design/class-and-promotion.md) §4.


- [ ] **Battle result V2.** V1 shipped (BattleResultPanel: turns-vs-par, itemized
  bEXP income, kills/losses/injuries). Remaining scope: runtime objective
  **tracking** (couriers/NPCs — the award side is already ready in MissionCatalog)
  + per-unit combat stats. See [mission_objectives.md](mission_objectives.md).
  - [ ] Delete the dormant `battle_result_overlay.tscn` once its slide-in
    animation is either adopted or given up on.

- [~] **Give all characters at least 9 moves and 9 passives.** Content pass.
  Gated in practice by the move-distribution bug in §6.

---

## 2. "What can I click?" — the interactivity problem

Eight separate tickets across the old file were all this one problem. Playtesters
cannot tell interactible from non-interactible. §14 of the
[ui-style-guide](../data/design/ui-style-guide.md) already **locks the vocabulary**
(lit border = pressable; converging rings = call to action, max one on screen;
bracket corner ticks = selected) and `InteractiveButton` implements all five
states — so this is now an **adoption** problem, not a design problem, except
where noted.

- [ ] **Intermission screens: interactive buttons must read as interactive.**
  Direct playtest feedback. The intermission screens are getting a full redesign
  anyway (see [intermission.md](intermission.md)) — fold this in. Open design
  question specific to this venue: the art direction is *a projection against
  glass*, so what does interactible-vs-not look like in that idiom?

- [ ] **The combat preview panel looks interactible and isn't.** Confuses new
  players. Working idea from the original ticket: non-interactible surfaces get
  dull/dark borders, interactible ones get a border glow. Should just be §14's
  lit-border rule applied to a read-only panel — verify that reads correctly.

- [ ] **Audit every UI surface against §14.** The catch-all version of the two
  above. Where the vocabulary isn't adopted yet, adopt it; where §14 has no
  answer for a venue, extend it.

- [ ] **Display-mode chip look.** Pick from the mockup's three candidates
  (borderless / ramp-step-down / compact) for preview + other read-only venues.
  This is the chip-level half of the same question.

- [ ] **Two-line chip + power.** Decide if/when chips grow a second line (power in
  the damage-type color) — ties into the density-crisis section of the mockup.

- [ ] **Locked moves need a visual.** A literal lock with chain links? A "void"
  effect for void-locked moves specifically? Strikethrough text? (Void lock
  already has its own FX — see §4 — this is about locked-ness in general.)

- [ ] **Rework the unit detail panel to use the move styleboxes from the preview
  panel.** Consistency win, and folds the detail panel into the same vocabulary.

- [ ] **Step indicator: a text box naming the step you're in.** New playtesters
  struggle to tell "pick where to move" from "select a move" from "select a
  target." Should be an Options toggle experienced players can turn off.
  *(Nobody failed at "select a unit" — that step is intuitive enough to skip.)*

- [ ] **In-game legend / glossary.** Lawrence: "is there anywhere you can see what
  all these icons mean?" Tooltip mode helps but a real glossary probably earns its
  keep.

---

## 3. Playtest & eyeball queue

**Built, tested, headless-green — needs human eyes in a running game.** This is
the cheapest-value-per-minute list in the file: it's all verification, no
construction. Several items have been sitting here through multiple shipped
features.

### Needs RQD in-game
- [ ] **bEXP / post-battle economy.** Full 2-mission loop, then tune par values.
  Every number is a named dial.
- [ ] **Phase 4 (Roar / Shriek).** Callout pacing on strike day, mark icon
  legibility, flourish pulse. Tuning guesses to confirm: Shriek strike 6 /
  2-stack marks / AoE 5 / PP 3; Roar AoE 2 / PP 8; CHALLENGED = hard target lock
  for its 3-turn tick-down; chain arcs faction-blind at Chebyshev-1 reach;
  support casts award no XP; Steady's existence + its cleanse list.
- [ ] **Blood Mage shadow fix.** Fixed 2026-08-03 (atlas-path characters never set
  `_art_feet_drop`, so shadows cast from the waist). Verify in-game, then **delete
  `image.png`, `image-1.png`, `image-2.png`, `image-3.png` from `.claude/`.**
- [~] **Threat-overlay static/scanline treatment.** Trial shipped 2026-07-30 —
  glass static + scanlines now ride every grid overlay. Defaults deliberately
  visible for the eyeball. Awaiting RQD + Lawrence verdict and tuning.
- [ ] **Grid live-paint on chip focus.** Intent colors (red damaging / green
  healing / blue neither) over the green movement tint, static intensity, and
  whether the preview readout's chips deserve the same on hover.
- [ ] **Void lock FX.** In-game GPU eyeball. Then: the icon→void-glyph swap, and
  whether detail-panel tablets need true desaturation.
- [ ] **Crit feedback.** "CRIT!" popup + hit flash are wired; not headless-testable.
- [ ] **Save system leftovers.** Yellow 7 / Azure 7 ramp-step eyeball; mid-battle
  browser-load scene-swap (the one path headless can't cover); Steam Deck path
  check; KIND_MANUAL slot management polish (overwrite/delete); save-browser
  visual pass (functionality-first scaffold, Lawrence styling later).
- [ ] **Controller peek button.** `tooltip_peek` is mapped to BOTH Back and R3 —
  playtest and cull one.
- [~] **STAB.** Mechanic shipped (1.2× `STAB_MULTIPLIER`). Open: in-game eyeball,
  and whether STAB deserves its own callout/badge beyond just a bigger number.

### Needs Lawrence in-game (F6 gallery)
- [~] **Unit cast shadows.** Override knob is character JSON
  `sprite.shadowBlobRadius` (0 = casts no blob); global taste = the `SHADOW_*`
  consts. Double/triple-darkening between units is pre-approved.
- [~] **Assigned ≠ selected marker (marquee orbit).** In-engine, Gray 10/9/8/7 on
  the chip's border ring, 50 px/s (`ORBIT_SPEED_PX_PER_SECOND` is the tinker
  knob), core = step = 3. Wants eyes on: F. Lance (live orbit), Spark (orbit over
  the depleted grey tier), tail wrap on short edges. Static fallbacks (edge bar /
  underline / pip) still live in the mockup's marker hunt.
- [~] **Glyph ink.** Dark-cut flip vetoed, per-side bleach vetoed → now UNIFORM
  bleach (whole glyph to index 10 of the element's own ramp when the fill is too
  close; shadow carries legibility). Wants eyes on Piston + Dynamo. Revisit again
  when real scheme sprites land — multi-color art can't value-shift like a
  generated glyph.

---

## 4. Blocked on Lawrence (art requests)

Nothing here is code-blocked; all have placeholders shipping today.

### Icons
- [ ] 10×10 **"Swap"** icon (like 🔁, but straighter arrows).
- [ ] Tiny **melee** and **ranged** glyphs (~5px tall, inline beside a 5px-font
  number). The terrain preview's split defense cell (Crater: bonus vs melee,
  penalty vs ranged) is rendering `M1.2` / `R0.8` with letter prefixes until
  these land.
- [ ] **Range icons**: range 1, range 2, range 1-2, range 2-3, range 3+.
  *(Any others needed here?)*
- [ ] **Buff icons**: Rallied, Fortified, Hasted, Focused, Regen — plus the
  long-missing **Bellows**.
- [ ] A **broken-link / denied glyph** to sit beside the OUT OF RANGE callout, so
  the meaning isn't carried entirely by 5px type.
- [ ] **Monster** and **Beast** type icons (both types shipped 2026-07-06; missing
  icons hide gracefully and chip colors fall back to the Gray ramp until a
  palette is picked).

### Systems needing a style pass
- [ ] **ThreatOverlayRenderer visuals.** The renderer exists but is placeholder
  tint, and per-enemy pins render identically to the whole-army zone — they need
  a distinct style so it's clear *what* is being shown. Also wants an on-screen
  clear-all button for touch (needs a home + a design).
- [ ] **Displacement diagram atoms** (not per-move art): mini tile cell (~8px),
  faction-tintable unit pip, ghost pip, arrow segment + head, impact star, spin
  arc. See §7 for what gets built from them.
- [ ] **Displacement preview micro-sprites** (optional polish): a tileable dash
  strip for the Line2D arrows + a 5px arrowhead. Ghost tint/pacing taste pass —
  all const-tunable in the renderer.
- [ ] **Per-clip authored unit shadows.** The exporter already emits
  `<tag>_shadow.png` strips and the runtime plays them verbatim when present.
  Deferred until Lawrence authors the first one.
- [ ] **Grunt pivot non-compliance** — Lawrence redesigning the sprite.

### LOD work list
- [ ] Stylized arrows showing displacement.
- [ ] More terrain modifiers and decorations.
- [ ] More animations.

**If bored:** new line art · new characters · new jungle biome terrain (see
concept art) · ice desert biome terrain.

---

## 5. Combat pipeline — remaining phases

Phases 0, 1, 3, and 4 are **shipped** (see [todo-archive.md](todo-archive.md)).
The living architecture map is the header of
[scripts/combat/combat_effect.gd](../scripts/combat/combat_effect.gd) — that's the
source of truth, not this checklist.

### Phase 2 — Passives (substantively complete)
All migrations + Reckless, Extendo, Protector, and the shared grid-geometry
foundation shipped. What's left is **deliberate deferral, not loose ends**:

- [ ] **Zone Control** — deferred + reframed. The stat-aura spec is dropped (it
  was a fourth `passive_bonus_*` aura with no identity). Zone Control is now a
  Songs-of-Conquest **zone of control**: an enemy that moves within this unit's
  attack range triggers an immediate **free attack** (no counter, no use cost — a
  reaction variant of `Unit.execute_combat_sequence`). `data/passives.json`
  already describes it this way. **Blocked on** the threat-overlay visuals below
  as its telegraph — it's unfair without one. Needs order-of-operations calls:
  trigger on enter/within/leave? stop-on-hit or continue? one-per-turn or
  per-move?

- [~] **Threat-overlay system.** Alpha-worthy on its own — an FE-style danger zone
  helps planning against *every* enemy, not just ZC.
  - [x] **Model** — `ThreatCalculator`, pure, tested.
  - [ ] **View** — `ThreatOverlayRenderer` on its OWN layer. Exists as placeholder
    tint; needs Lawrence's style split (see §4).
  - [~] **Controller** — both toggles shipped (V = show-all/clear-all;
    preview-panel chip = additive per-enemy pins). Remaining is the visuals half,
    plus the "try it both ways" hover-to-preview variant + its Options toggle.

- [ ] GUT coverage per remaining handler.
- [ ] **Batch-testing guide** — how to load specific move/passive sets in-game to
  eyeball passives efficiently (Extendo reach, Protector body-block + preview, the
  aura passives). Was explicitly deferred until Phase 2 closed; it's close enough
  now.

### Phase 1 follow-up
- [ ] **Banked-crit indicator.** Repurpose the freed-up `critical_0000.png` as an
  on-unit indicator that a unit is carrying a banked `pending_crit`. Because
  `pending_crit` isn't a status, this needs surfacing separately from
  `active_status_effects`. *(RQD liked this. Confirmed not built.)*

### Phase 3 follow-up
- [~] **Author the remaining displacement moves.** The engine supports all of them
  today; they just need authoring. **Stampede** and **Razor Wing**
  (charge = `subject:self` + `toward_target` + `fall_through`, landing past the
  target), and **Roar-knockback**.
- [ ] **Keep the callout convention inviolate:** OUT OF RANGE always floats over
  the unit that LOST its attack.

---

## 6. Bugs

**Two save-loss defects, both decided 2026-08-04 — design in
[intermission.md](intermission.md) §2c/§2d. These are live in the current build,
independent of the intermission redesign.**

- [ ] **No autosave at the mission boundary → intermission work is lost.**
  Autosaves are battle-only (`SaveManager` writes on `player_phase_started`, and
  early-returns when `capture_battle_snapshot()` is empty); `CampaignManager`
  never saves. So nothing is written between the last turn of mission N and turn 1
  of mission N+1 — quit from the intermission and "Continue" should rewind into
  the battle you *already finished*, discarding every StatUp, move swap, and bEXP
  purchase. **Fix: autosave on ENTERING the intermission** (leaving is already
  covered by the next mission's turn-1 write). `build_snapshot()` already takes
  `battle` as optional, so this is a trigger, not new machinery. Open sub-call:
  which ring — recommendation is to widen the existing blue ring from
  "battle-start" to "mission boundary" rather than mint a fourth color.
  **Wants an in-game repro first** — this reads from the code path, unconfirmed.

- [ ] **The 5th manual save silently destroys the 1st.** `write_manual_save()`
  routes through `_pick_ring_slot` ("first empty wins, else overwrite oldest"), so
  manual saves rotate exactly like autosaves. Rotation is correct for autosaves
  (unrequested) and wrong for manual saves (the press *is* the intent to keep it).
  **Fix: prompt only when the press would destroy** — silent write while a slot is
  free, picker when all 4 are full, no write and no latch on cancel. Split
  `find_free_manual_slot()` + `write_manual_save_to(path)` out of the eviction
  path; the picker is `SaveBrowserPanel` in a second mode (render empty slots,
  emit `slot_chosen`). Autosave rings unchanged.

- [ ] **Move distribution in the demo is wonky.** Characters get moves far too
  powerful at level 5; this is what makes the Ogre feel broken. *Deliberately
  parked until the move bank is much wider.*
- [ ] **Tile seams at certain zoom levels + camera positions.** Hard to reproduce.
  The seam z-indexes at roughly the enemy-sprite level; it's a vertical line of
  subpixel resolution when the camera isn't centered. **Needs a screenshot.**
- [ ] **Decorations layer lacks the modifier layer's sprite handling** — image is
  cropped, no shadows.
- [ ] **The move preview doesn't animate properly when a unit retreads its path.**
- [ ] **Console errors on load.** Believed to be from Godot editor extensions no
  longer in use — verify, then delete the addon or fix the scripts:
  ```
  res://addons/codeandweb.texturepacker/texturepacker_import_spritesheet.gd:54
      Parse Error: Not all code paths return a value.
  res://scenes/debug/game_colors_demo.gd:197
      Parse Error: Cannot find member "STATUS_TEXT" / "STATUS_TEXT_GLOW" in base "GameColors".
  res://scripts/ui/panels/terrain_info_panel_test.gd:54
      Parse Error: Cannot find member "TEXT_WARNING" in base "GameColors".
  ```
  *(The latter two are stale references to renamed `GameColors` members — cheap fixes.)*
- [ ] **Font size 5: the numeral "8" is very hard to read.** Replacement sprite is
  already drawn — open question is how best to implement it. Note the replacement's
  bottom pixel drops below the baseline, like g/j/p/q/y.
- [ ] **Preview panels don't reposition on touchscreen.** They swap sides correctly
  under M&K when the cursor nears an edge; touchscreen has no cursor but the
  occlusion problem is presumed to remain. Needs an actual touch device to confirm.

---

## 7. Design calls needed (RQD)

Each of these is blocked on a decision, not on work.

- [ ] **Esc / pause menu outside battle.** The battle system menu is reachable in
  the intermission screens, where "End Turn" is meaningless. We probably *do* want
  Options reachable everywhere. Options: **(a)** context-aware system menu that
  drops End Turn/battle items outside battle, **(b)** a bare Options-only popup on
  Esc in non-battle screens, **(c)** suppress Esc entirely there.
  **Recommendation: (a)** — one menu, items gated by `GameStateManager` state.

- [ ] **Mid-battle stat-up moment?** Mid-battle level-ups currently only refresh
  the level label + health bar; the full celebration is deferred to end-of-mission
  (working as designed, `unit.gd _award_combat_xp`). Do we also want an FE-style
  mid-battle stat-up beat? That's new design, not a bug fix.

- [ ] **Corruption misfire chip.** Show a `⚠ XX% misfire` indicator on the combat
  preview when the attacker has Corruption, so the player decides with full info.
  The number is already computable — `character_data.friendly_fire_chance_pct`
  (10% Minor / 20% Major per injury, summed, capped at 100). Needs a visual pass:
  a chip near the hit% area, or a banner across the preview? **RQD to mock up.**

- [ ] **Find magenta/purple a new job.** Retired from selection, but it pops too
  well in the menus to waste — rare/special actions? story choices? limit-break
  moves? **Rule: do NOT reuse it for selection or call-to-action.**

- [ ] **Elemental type icons on the map take too much screen real estate.** The
  option is genuinely useful but too costly at current density. Needs a better
  solution than on/off.

- [ ] **Target-type + range icon on move buttons.** We should show target type and
  range wherever a move button appears, alongside elemental type and move type.
  Ties into the locked target-scheme color language (target type = color, epicenter
  visually distinct). Depends on §4's range icons.

- [?] **Cancel/confirm input hints.** Status unknown — check whether this shipped.

---

## 8. Not started

- [ ] **CLASS & PROMOTION SYSTEM** — design doc written 2026-08-05
  ([class-and-promotion.md](../data/design/class-and-promotion.md)), nothing
  implemented. **This is the largest unscoped commitment in the project**, and by
  RQD's own framing it's load-bearing twice over: it's the progression spine
  (promotion at levels 21 and 41 is the biggest choice moment in the loop) *and*
  it's the actual answer to the supersquad problem, since class-carried typings
  and passives are what make a narrow squad lose fights.
  - Today it is **enum-only**: 15 tier-1 classes, 3 tier-2, 3 tier-3. No class
    data, no `data/classes/`, no `CLASS_INFO` table, no promotion trigger, no
    class-choice screen.
  - **Content scope: ~30–45 classes** to author if each base class gets 2–3
    promotion options — each needing stat mods, granted passives, typing,
    growths, caps, a name, and eventually art. The obvious lever if that's too
    many is shared promotion pools across base classes (open question in the doc).
  - **Not alpha-blocking**: alpha units start at levels 1/5/11 over two missions,
    so nobody reaches 21. But it should be scoped before it surprises us.
  - Open questions live in the doc §6 — reclassing, stat caps, whether enemies
    promote, and how the UI communicates a class that's worse on paper but better
    in play.

- [ ] **Generated displacement diagrams.** A schematic renderer drawing an
  Into-the-Breach-style vignette straight from the declarative displace params:
  3–5 mini tiles, caster/target pips, arrow with distance notches, ghost pip at
  the destination; impact star for slams, arc-over for `fall_through`, crossed
  arrows for swap, spin arc for rotations. **Generated = zero per-move art, new
  moves get diagrams free, can never drift from behavior.** Lives in the unit
  detail panel's move description area first, same widget reused in the
  hold-to-peek tooltip. Cheaply animatable (pip slides A→B, loops). Build with
  programmer art first. Optional cheaper layer: five 10×10 displacement-family
  badges (push/pull/self/spin/swap) for move chips, same slot logic as the
  damage-type icon.
- [ ] **M&K menu hotkeys.** 1–4 for moves, then QERFZXCV for non-moves. Hide them
  when controller or touchscreen input is detected (`InputSource` already tracks
  this).
- [ ] **Tooltips: controller focus-navigation mode.** Dark Souls pattern — hotkey
  grabs focus on tooltip-bearing icons, stick navigates, `focus_entered` shows the
  themed popup, B/Back releases. *The board half is complete* (free cursor +
  constrained attack cursor both shipped); this is the **menu half** only.
- [ ] **Icons inside text boxes.** Needs full elementalType / boost / affliction /
  injury icon sets. *(Anything else?)*
- [ ] **Visual feedback for EVERY passive that triggers.** Currently silent.
- [ ] **Visual feedback when boosts and afflictions clear.**
- [ ] **Void lock FX density** — tune frequency/extent for larger styleboxes.
- [ ] **Combat preview: indicate buffs/debuffs in play.** Partly self-solving —
  combat numbers pull from effective stats automatically once the panel reads
  `character_data.strength` etc.
- [ ] **Preview path on hover.** On controller/M&K, show the preview path while
  hovering the next node in the planned path.
- [ ] **Options menu tabs.** It's cluttered. Gameplay / Video / Audio — anything
  else yet?
- [ ] **Split `StatusEffectType` into `AfflictType` + `BoostType`.** Significant
  rewiring across the game logic, but there's no real alternative: units need to
  carry a boost and an affliction simultaneously.

---

## 9. Post-alpha / deferred

- [~] **Touchscreen UX: preview panels occlude tappable tiles.** Options: (a) don't
  show the preview panel during action planning — separate "select for action"
  from "inspect"; (b) auto-pan/zoom to keep the unit's eligible range visible
  beside the panel; (c) long-press to peek through; (d) panel fades + becomes
  tap-transparent after a moment. **Needs real hardware to decide.**
  - **Primary: GrapheneOS phone** — daily driver for touch iteration. Enable
    Developer Options + USB debugging, use Godot's One-Click Deploy (Project →
    Install Android Build Template once, then the phone icon in the toolbar). No
    Play Protect, so dev-signed APKs install without nags — actually easier than
    stock Android.
  - **Secondary: old Android tablet** — larger screen, closer to Steam Deck aspect
    ratio; good for layout/form-factor validation. Any Android 6+.
  - **Final: Steam Deck** — real target hardware. Remote debug via
    `--remote-debug tcp://<dev-ip>:6007`, or install the Godot editor directly on
    the Deck in desktop mode. Bring in once touch UX stabilizes on phone.
  - Skip iPhone — needs Mac + Xcode + Apple Dev account and gives nothing Android
    can't for touch UX.
- [ ] **Optimize controls for touchscreen** (the general version of the above).
- [ ] **Test at 90 / 120 / 144 / 240 fps.** (`Settings.max_fps` + the FPS Cap
  slider already ship.)
- [ ] **ALLY/NEUTRAL faction spawn wiring.** `desert_prince.json`, `mystic.json`,
  and `battle_chicken.json` exist but nothing spawns them — `RECRUIT_POOL` is
  player-only and `enemy_spawn_pool` is enemy-only. **Needs design first:**
  (a) where do allies come from — mission-scripted, pooled like recruits, or
  hand-placed in the map `.tscn`? (b) neutral behavior — wandering, hostile-to-all,
  or passive decoration? (c) authoring surface — `.tscn` placement vs programmatic
  spawn. Then plumb through `TurnManager` and the AI so non-PLAYER/non-ENEMY
  factions get turns and decisions.
- [ ] **Ally-target support moves** (e.g. Rally). Combat selection doesn't support
  ally-target yet; defer until a move needs it.
- [ ] **Unit "I'm injured, I gotta fall back" barks** on first injury. **Needs a
  dialogue system first.**
- [ ] **Art pipeline: normal maps** through Aseprite → Aseprite Wizard → Godot.
- [ ] **Art pipeline: frame timing** through the same workflow.

---

## 10. Stretch goals

- [ ] Sync movement beacons to music BPM. (Constants are already isolated in
  `path_visualizer.gd`: `FRAME_DURATION_MS` / `TILE_DELAY_MS` / `CYCLE_PAUSE_MS`.)
