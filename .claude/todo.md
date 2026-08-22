# Ideas
- [x] 1. XP gain on map: When a unit gains XP on the map, we should have an XP bar fade in (quickly) right above/below their health bar (yellow fill, black bg), fill with a filling sound effect, and then fade back out (slowly) (Done 2026-08-21: `Unit._build_xp_bar` — 24×2 yellow-on-black under `HealthBar`, 1px BENEATH the health bar (RQD: beneath reads more natural; `XP_BAR_OFFSET_Y` = -4 tries above). `_flush_xp_feedback` fires `_play_xp_bar(before, after, levels)` alongside the "+N XP" callout: fade in 0.1s → sweep (0.45s per full bar; a level wrap fills to full, flashes Yellow 8, restarts from 0) → hold 0.5s → fade out 0.6s; reduce-motion parks at the landing fraction. `xp_bar_fill_segments` is the pure sweep plan. SFX `audio/ui/xp_fill.wav` — placeholder rising tick train from generate_ui_sfx.gd, Lawrence replaces same-name. While there: `CharacterData.XP_PER_LEVEL` now owns the 100 that grant_xp / sheet / bEXP / unit sheet each hardcoded. 9 tests in test_combat_xp.gd. EYEBALL: the bar's bottom row kisses the top pixel of tall sprites' art for the ~1.7s it shows — fine in a static render; judge in motion.)
- [ ] 2. The enemy pyro is outrageously powerful - needs a nerf to Spc
  - [ ] 2A. upon review, the spc stat is indeed too high, but I unknowingly activated the enemy's "bellows" ability, which obliterated me on the next hit. We should have visual feedback when bellows activates, and when an attack bootsted by bellows fires, as well.
  - [ ] 2B. Also we should warn the player if they're about to use an attack that triggers bellows, with a pulsing alert, maybe. This requires thoughtful design and can't be a simple add, because we'll want to add this feature for other moves as well. Needs to be a whole system. Let's triage this todo (2B) and keep it for later - I think it's great for the presentation but not high leverage in getting us to alpha.
- [x] 3. In the pause menu, we should move "close" to the top, right under "end turn" and above "options," and make that the default selection on controller (Done 2026-08-21: SystemMenuPanel order is END TURN, Close, Options, Save, Load, Main Menu, Quit; the cursor-model default landing AND the quiet-open "first nav press summons the cursor" target are both Close now — a stray controller A-A used to end the turn. 3 tests in test_system_menu_panel.gd.)
- [ ] 4. Since we added the arrow + phantom effect for displacement moves, should we use the same system when previewing a move with the move beacons?
  - [ ] 4A. need to decide if we hold off on actually moving the unit (just show the static/fuzzy phantom preview) to the spot before committing an action - would be a departure from current design but more accurate. We should solve the problem both ways and playtest both, and see what players prefer/find less confusing.

# Meeting Notes 2026/08/16
## RQD
- [x] For the non-interactible HUDs, remove all beep-boop buttons (Done 2026-08-16: the rivet-button tabs were baked into `panel_border_tall.png` — the unit preview's frame. New `panel_border_tall_plain.png` = the same frame with the two tabs removed (built from Lawrence's `panel_border_small.png` rows; a pixel diff vs the tall art shows ONLY the tab regions differ), unit_preview_panel.tscn points at it; the rivet original stays on disk. The STATIC-tier self_modulate dimming on unit preview + combat preview is reverted per the note below — both frames now match the terrain preview at full brightness. The system menu / unit detail panel (interactive) keep their buttons.)
	- dimming the display did not work well
- [x] Add a "main menu" option alongside "quit" (Done 2026-08-16: SystemMenuPanel "Main Menu" sits right before Quit → `UIManager._on_system_menu_main_menu` closes the menu (unwinds PAUSED → DEFAULT) and routes to the start screen; BattleScene._exit_tree clears the grid as on a mid-battle load. No confirm, same as Quit and the hub's Quit to Menu — the turn autosave bounds the loss. NOTE pre-existing: New Campaign after returning mid-session reuses the leveled roster (start_campaign never rebuilds it) — same gap the hub's Quit to Menu had.)
- [x] BUG: When you deselect down to 1 squad member, the "deselect squad member" button appears deselected even though the last unit is selected (Fixed 2026-08-16: the last deployed pip went `disabled`, and disabled pips draw hollow = "benched". Root fix below made the inert rule unnecessary; `REASON_LAST_DEPLOYED` is gone.)
	- [x] We should actually allow the player to deselect all units (squad size 0/X) but then don't let them start the mission (Done 2026-08-16: `CampaignManager.has_deployment()` splits UNSET ("deploy everyone" legacy fallback for F6/ad-hoc battles) from a CHOSEN EMPTY selection (a real 0/N). Saved as `deployment_chosen` (legacy saves without it: empty = unset). `RosterRail.resolved_deployment(..., chosen)` keeps a chosen empty selection empty instead of re-seeding it on hub arrival; BattleScene honors chosen selections verbatim. Hub: Begin Mission goes inert at 0/N with sub-line "deploy at least one unit"; the summoned cursor skips it. BONUS FIX found while verifying: MainMenuEntry only built its sub label when sub_text was non-empty at _ready, so NONE of the hub's live sub-lines ("4/5 deployed", the bEXP number, Save latch) had ever rendered — sub_text is a live setter now. intermission.md §4c updated.)
### Unit detail panel
- [x] The background on the unit detail panel is lighter than the rest of the menus for some reason (Fixed 2026-08-16: the scene root had no stylebox, so it fell back to Godot's default panel — 0.1 gray @ 60% — instead of `HUD_PANEL_BACKGROUND`. `_apply_panel_background()` in unit_detail_panel.gd now stamps the shared menu tint, radius 5 like the system/options/action menus.)
- [x] Unit detail panel: injury borders are appearing when there's no injury in that slot (Fixed 2026-08-16: empty placeholders keep their footprint — a lone Minor stays Minor-sized — but draw no border; the selection pass used to re-stamp 1px on every injury panel, empties included. Placeholders also no longer take the selection on click.)
- [x] On the selection border for the passives, I'd like 1px rounded corners, antialiased (Done 2026-08-16: `UnitSheet.SLOT_CORNER_RADIUS = 1` on the shared slot chrome — normal+hover — so the Manage Units sheet rows match; Godot only feathers a StyleBoxFlat once it has a radius. Eyeball: straight edges stay crisp, corner pixel ~50% blend.)
- [x] "Range" is incorrectly only showing max range, not min range (Fixed 2026-08-16: detail sheet now uses `MoveChipButton.range_text` — "1-3", "1" at melee, "--" for self-target — same helper as the chip band and the peek tooltip. NB: there is no min-range mechanic in the engine yet; every move reaches 1..N.)


# Resp

# More ideas
- [ ] Longer ranged moves should carray an accuracy penalty for striking further away. For example, the sidearm can hit units 3 spaces away, but I'd like for it to be optimal at 2, and a risky shot (~50% accuracy for an average unit targeting an average agility enemy) at 3 spaces. We may want to reconsider allowing it to shoot 1 space, as well.
- [ ] **Correction (2026-08-11): those icons don't exist.** Full sweep of
    art/sprites/ui/: elemental, move-type (dmg), injury, status-effect, and
    buff icon sets — nothing for Pow/Range/AOE/Uses. Closest is
    `infinity_7x4/9x6.png` (for infinite uses). Needs a Lawrence ask: four
    ~10×10 glyphs; the tap-tooltip pattern already exists (TapTooltip).
    Text labels stay until the art lands.


# TBT Game — Open Work

Everything still to do. **Completed work + its shipped-notes live in
[todo-archive.md](todo-archive.md)** — check there before re-litigating a decision;
most "why does it work this way" answers are in an old shipped-note.

**How this is ordered:** §1 is what actually gates Alpha. §2–4 are the three
recurring blockers that kept getting filed as separate one-off tickets. §5+ is
everything else, roughly by how soon it matters.

**Status markers:** `[ ]` not started · `[~]` partially done, detail inline ·
`[?]` status unknown, needs a look.

## Live links

- **Intermission UI mockup** — <https://claude.ai/code/artifact/c4001371-950b-4d7e-8dc2-6fd619f787bb>
  Screens 1–2 of 7, interactive. Source of truth is
  [data/design/mockups/intermission-ui-mockup.html](../data/design/mockups/intermission-ui-mockup.html)
  in this repo; the URL is a republish of that file, so **edit the file and
  republish to the same URL** rather than starting a new artifact. Design
  rationale per round lives in the notes column of the page itself.
  - Still undecided in there: **2b vs 2c** (bEXP inside Manage Units vs its own
    screen), the **button set** (symmetric amounts vs named jumps), and whether
    **bEXP should reach benched units**.
- **Battle HUD mockup** — <https://claude.ai/code/artifact/d13f16f7-a4a2-47e2-9cbe-9b2e5c1107cd>
  In-battle widgets, one tab per widget; only the **hint / command bar** so far
  (round 1, 2026-08-16). Source7 on
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

- [x] **Displacement arrows rendered under terrain modifiers and units**
  (Lawrence 2026-08-05) — **FIXED same day.** Root cause worth remembering: board
  z is `(99 − row) × 10 + layer`, spanning 0..998, so the **row term dominates**
  and the 0–8 layer enum only orders *within* a row. The renderer used a flat
  `z_index = 2`, commented "one slot above the move-range paint, still under
  units" — reasoning in layer-enum terms while setting an absolute z. That
  cleared only the back row's floor tiles; everything in front buried it. Now
  1000, above the board max (998) and the flat vignette (4), because a targeting
  preview has to be legible over whatever it crosses. Ghosts ride the same node
  deliberately. Pinned by three tests in test_displacement_preview.gd that assert
  the *invariant* (outranks any board z, outranks a front-row unit) rather than
  the magic number.
- [x] **Displacement arrows too thin** — `ARROW_WIDTH` 1.0 → 2.0, guarded by a
  test so it can't silently revert.

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

- [~] **Hint / command bar — BUILT, RQD-approved on mouse 2026-08-21** (branch
  `rqd--guidance-interface`, 11 commits d09f9a0..528b9c4; `HintBar` +
  `HintBarCommands` in `scripts/ui/components/`; tests `test_hint_bar*.gd`).
  Bottom corners + glass, glyphs from the live InputMap, touch = real buttons,
  waypoints taught one click at a time (Plot path → Add stop), planning step
  wears the new NOTICE border, `Settings.move_confirm_mode` Auto/Marker/Button
  playtest toggle, `Settings.show_control_hints`, X/LB controller bindings.
  **Unseen so far:** controller glyphs on a real pad; touch rendering
  (`DebugConfig.debug_force_touch_hints` on desktop, or the phone build).
  **Remaining, in order:** (1) pad + touch eyeball; (2) Lawrence's visual pass
  — sprite borders for the glass, glyph chips instead of `[A]` text,
  InteractiveButton for touch buttons, NOTICE ramp step (Magenta 4–6);
  (3) Android export setup → sideload on RQD's GrapheneOS phone; safe-area
  insets then; (4) playtest verdict on Marker vs Button → delete the loser;
  (5) squash-merge to rqd--main once proven. Mockup artifact is one round
  behind (no NOTICE / toggle row) — refresh when Lawrence's pass starts.

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
- [ ] **Proofread all AI-generated text.** Go through every AI-generated
  description, flavor text, blurb, tooltip, etc. (moves, passives, characters,
  classes, terrain, injuries) and proofread it — voice, accuracy against the
  actual mechanic, typos.
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
- [ ] **size 5 font** - replace the letter "B" and numeral "8" with custom characters

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
