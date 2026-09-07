# Resp

**Answered + BUILT 2026-09-07 on `rqd--terrain-stack`** (3 commits, suite
1096 green; squash-merge once RQD/Lawrence have eyeballed a build):
1. Generated-shadow fallback for terrain sprites — the shadow-meeting item
   below, framed authored-wins / generated-fallback.
2. Decoration layer now renders exactly like the modifier layer — §6.
3. The third thing turned out to be **tile registration reshuffling source
   ids**: `tools/register_modifier_tiles.gd` wiped every source ≥100 and
   re-minted them in sorted-name order, so the first new sprite sorting
   before an existing one (`bush_a` < `castle_a`) would have silently
   repainted every map. Ids are now stable forever, newcomers append, a
   drift assert refuses to save, a no-op run touches nothing, and headless
   saves keep their `uid=`s. `tests/unit/test_map_tileset_integrity.gd`
   walks every map's painted cells against the tileset.
4. **Editor preview** (the map-week ergonomics win): `TilemapGridBuilder` +
   `TerrainSpriteRenderer` are `@tool`. With a map open in the editor,
   unowned `ModifierPreview` / `DecorationPreview` renderers draw the full
   sprites + shadows on both layers and refresh ~10 frames after a paint
   stroke. Verified in a headless editor session (spawn, +2 sprites on
   paint, gone on erase, not written on save). EYEBALL in the real editor:
   does the overlay fight the tile cursor / selection highlight?
Also: `tools/diag/map_shot_probe.gd` screenshots any map from the CLI (the
before/after came from running it in a `git worktree` of the old branch).
Design doc rewritten: data/design/terrain_modifiers_and_decorations.md,
including a new-map checklist (wizard → 4 layers → boundary + P/E stamps →
`data/missions/mission_manifest.json` → F5; `lawrence_test_map` isn't in
the manifest yet).
**RQD build report, same day (all three resolved):**
- *"Terrain shadows look a different opacity/color than unit shadows"* and
  *"building_a darkened as a whole"* — ONE bug, mine: the OOB fade shader's
  "honor modulate" edit sampled the texture a second time (canvas_item
  `COLOR` already holds texture × modulate), squaring every channel — light
  buildings darkened, 40 % shadows became 16 %. The PNGs were byte-identical
  to the unit ink all along. Fixed; `tools/diag/shader_parity_probe.gd`
  renders the four cases and checks parity (run it after any shader edit).
- *"Some decorations need no shadow, floor elements"* — `casts_shadow: false`
  in modifier_terrain.json now means NO shadow of any kind (the authored
  `_shadow.png` is skipped too), and a wildcard key (`"piperoot_*"`) flags a
  family. The editor preview re-reads the JSON on change, so flip a line and
  watch the open map. I couldn't tell from the art WHICH ones RQD means (the
  craters + bridge already have none; everything else reads as an upright
  object on the contact sheet), so the list is RQD's to fill — one line per
  sprite or family.
**Content note for Lawrence:** every sprite except `castle_a` exports with a
1×1 footprint — the 160×96 buildings and the 96×96 bridge included — so
gameplay treats them as one cell (units walk up to / onto a single tile of a
five-cell-wide building). If that's not intended, suffix the tags (`_3x2`)
and re-export; the registration tool warns when an atlas tile moves and
those cells need repainting.

# Battle scene
- [ ] For a minute, the plan was to animate omnidirectional attacks, and I've come to the conclusion that this is simply too colossal an undertaking. We need a Fire Emblem 7 - style battle scene where the units play their attack animations against each other.
  - [ ] There will be, at minimum, melee, ranged, and self "attack" animations. We may also split into physical/special/support animations. Our system must also allow exceptions to any of the standard rules, as well as a fallback for when units have no attack animation. I'll give you an example.
    - say an archer has a passive which lets it hit enemies which are one space away. The archer unit may have no attack animation for "melee," in which case we'd need to gracefully fall back to an animation it does have, in a way that makes sense.
    - that said, we should also be able to override animations, e.g. "when this unit uses its melee special attack, just play the ranged physical aniimation."
  - [ ] Anything I'm forgetting to make this system as robust and intuitive as possible? This seems like it might be prone to turning into a mess of spaghetti code, which I'd really like to avoid.



# More stuff
- [ ] the default camera pan speed is way too low - probably speed up 3-5x
- [x] For the Steam Deck glyphs, we also need L4-5 and R4-5. (Done 2026-09-02 on
  `rqd--controller-glyphs`: rounded-square chips for the Deck grips L4/L5/R4/R5
  AND Xbox Elite paddles P1–P4, labels wired for JOY_BUTTON_PADDLE1..4. CAVEAT:
  the SDL paddle→position mapping (PADDLE1 = upper-left, etc.) is UNVERIFIED on
  real hardware — mash `tools/diag/joypad_probe.gd` on the Deck before anything
  BINDS a paddle; nothing does today.)
  - [x] On mouse, should M4-5 and beyond be "we'll cross that bridge when we get
    to it?" (Answered 2026-09-02: yes for art — but the TEXT tier is already
    crossed: `mouse_button_label` now returns "M4"/"M5", so a future side-button
    binding degrades to "[M4]" in the bar instead of silently dropping the item.)
- [x] "Three lines" and "overlapping squares" always require looking at the
  controller — is there a universal start/select icon for millennial+ gamers?
  (Answered + built 2026-09-02: there is no universal ICON — that era printed
  the WORDS on pill buttons, so the word-pill IS the universal glyph. START and
  SELECT mini-font pills now map from every pad's start/select-position buttons
  (Menu/Options → START, View/Share → SELECT); Switch keeps its printed +/−.
  The hardware-accurate ☰/⧉ sprites stay on disk unmapped for a re-audition.)
  - [ ] Also, "three lines" and "overlapping squares" have always made me look at the controller. Are there icons which universally represent "start" and "select" for us millenial (and older) gamers?
- [ ] Just discovered I can't navigate the unit detail panel with a controller
  - [ ] All the controls bar reads, in this context, is "B for close"
- [ ] Default cursor speed is perfect with the D-pad, too fast on the control stick
  - [ ] For the control stick, I was thinking more of a fairly quick acceleration to medium speed:
    - you can flick the stick repeatedly for navigaint a single tile at a time
    - if you hold the stick, it clicks to the nearest tile, but if you keep holding, it begins moving faster, but at a manageable speed - just like the D-pad (let's expose this variable though, so I can test. Might be an options menu "cursor speed")

# Ideas
- [x] 1. XP gain on map: When a unit gains XP on the map, we should have an XP bar fade in (quickly) right above/below their health bar (yellow fill, black bg), fill with a filling sound effect, and then fade back out (slowly) (Done 2026-08-21: `Unit._build_xp_bar` — 24×2 banana-on-black (YellowOrange 7 `#f5cd65`, the house gold — RQD correction 2026-08-21, was the olive Yellow 7) under `HealthBar`, 1px BENEATH the health bar (RQD: beneath reads more natural; `XP_BAR_OFFSET_Y` = -4 tries above). `_flush_xp_feedback` fires `_play_xp_bar(before, after, levels)` alongside the "+N XP" callout: fade in 0.1s → sweep (0.45s per full bar; a level wrap fills to full, flashes Yellow 8, restarts from 0) → hold 0.5s → fade out 0.6s; reduce-motion parks at the landing fraction. `xp_bar_fill_segments` is the pure sweep plan. SFX `audio/ui/xp_fill.wav` — placeholder rising tick train from generate_ui_sfx.gd, Lawrence replaces same-name. While there: `CharacterData.XP_PER_LEVEL` now owns the 100 that grant_xp / sheet / bEXP / unit sheet each hardcoded. 9 tests in test_combat_xp.gd. EYEBALL: the bar's bottom row kisses the top pixel of tall sprites' art for the ~1.7s it shows — fine in a static render; judge in motion.)
- [x] 2. The enemy pyro is outrageously powerful - needs a nerf to Spc (Done 2026-08-21: the REAL culprit was Blaze (power 11, range 2, special) auto-equipping from the opening four — lvl-1 Pyro vs Res 3: (9+11−3)×1.2 STAB = 20, ×1.25 with one Bellows stack = 26, vs 13–22 HP player units; Capricious rerolls its move each turn so 1-in-4 turns was a Blaze. Pyro's Spc 9/70% was the shared mage template (Keener, Phoenix Pirate identical; Plant Cultist same sheet, not in the pool). RULING: Spc 9→7, growth 70→55 on all four ("70% growth on a standard enemy is just too high"), and the 11-power move (Blaze / Keener's Dark Energy) moved to pool slot 5 so it waits for an unlock. test_enemy_loadouts.gd pins it. NOT touched, flagging: Mystic (8/65, Dark Energy in its opening four, not in the pool) and Squash/Thumps opening with Megaton Punch at power 50 — that's the parked "move distribution is wonky" item.)
  - [x] 2A. upon review, the spc stat is indeed too high, but I unknowingly activated the enemy's "bellows" ability, which obliterated me on the next hit. We should have visual feedback when bellows activates, and when an attack bootsted by bellows fires, as well. (Done 2026-08-21, generic for ALL statuses per RQD: `Unit._on_status_effect_applied` floats the status's abbrev name over the unit — buffs in TEXT_SUCCESS green, debuffs in TEXT_DANGER red (NOT element ink: the AI floats move names in element color), a restack counts up ("BELLOWS ×2"; Burn/Poison land as "×4" because their default application IS 4 stacks), and the 6×6 icon pops (StatusEffectIndicator.pop_icon, reduce-motion parks it). Boosted swing: `DamageCalculator.bellows_multiplier` is now one helper shared by the math and `_execute_single_hit`, which announces "BELLOWS ×1.5" over the attacker pre-swing in fire ink, floors impact weight at 0.6, and tints the target's hit flash warm (apply_hit_flash grew a `tint`). test_status_callouts.gd + bellows tests in test_damage_calculator.gd. Also fixed: apply_hit_flash's finished-lambda dereferenced a freed unit (the "Lambda capture… has_method on null" noise in the displacement tests).)
  - [ ] 2B. Also we should warn the player if they're about to use an attack that triggers bellows, with a pulsing alert, maybe. This requires thoughtful design and can't be a simple add, because we'll want to add this feature for other moves as well. Needs to be a whole system. Let's triage this todo (2B) and keep it for later - I think it's great for the presentation but not high leverage in getting us to alpha. (PARKED 2026-08-21 → filed under §7 design calls as the pre-warn system; the combat preview's damage number already includes the defender's Bellows reaction only AFTER it lands, so today nothing in the UI foreshadows it.)
- [x] 3. In the pause menu, we should move "close" to the top, right under "end turn" and above "options," and make that the default selection on controller (Done 2026-08-21: SystemMenuPanel order is END TURN, Close, Options, Save, Load, Main Menu, Quit; the cursor-model default landing AND the quiet-open "first nav press summons the cursor" target are both Close now — a stray controller A-A used to end the turn. 3 tests in test_system_menu_panel.gd.)
- [~] 4. Since we added the arrow + phantom effect for displacement moves, should we use the same system when previewing a move with the move beacons? (FIRST CUT 2026-08-21 on branch `rqd--move-preview-ghost`, eyeball-gated: the beacons stay the path, and a `UnitGhost` projection (the displacement renderer's silhouette recipe, extracted into scripts/grid/unit_ghost.gd — renderer behavior unchanged) parks on the plan's last waypoint while a PLAYER unit is planning. Same material/shader as the displacement ghosts, absolute z above the board, player-only, freed with the plan. Did NOT replace the beacons with the polyline arrow — the beacons are shipped LOD art and already carry the path. 8 tests in test_path_ghost.gd. Squash-merge once RQD has seen it in a build.)
  (RIDE UPGRADE 2026-08-31, RQD ask, built on `rqd--move-commit-mode`: the ghost now RIDES the plan under motion — walks the tile-center polyline from the origin with the displacement arrow recipe (same ARROW_WIDTH, shared overlay_static material, Azure 7 neutral intent, Polygon2D head riding the tip) drawing behind it, holds `GHOST_HOLD_AT_DESTINATION_SECONDS` at the landing, loops; `GHOST_SPEED_PX_PER_SECOND` = 88 ≈ the displacement loop's 0.18 s/tile — both are the tinker knobs. Every plan edit restarts the ride. Beacons KEPT underneath (still the shipped path language). ARROW DISABLED SAME DAY (RQD: "that's what the beacons were for" — the trail double-marked the path): `RIDE_ARROW_ENABLED = false`, machinery + pure math kept and pinned for a cheap re-audition; the arrow had been retuned to Azure 5 first (the phantom's tint sits at the Azure 7 neighborhood — if re-enabled, keep the two apart). Ghost speed RQD-tuned 88 → 135 world-px/s. Reduce-motion parks at the landing state: ghost on the destination + arrow drawn full (the old parked contract survives as that state). The ACT_THEN_WALK staged ghost never rides — committed plans park. Pure ride math (walk_sample/trail_points/path_length) static + pinned; test_path_ghost.gd rewritten to the riding contract, 12 tests; suite 1040 green. EYEBALL: ride pacing/loop feel, arrow-over-beacon density, tip-over-silhouette read.)
  - [~] 4A. need to decide if we hold off on actually moving the unit (just show the static/fuzzy phantom preview) to the spot before committing an action - would be a departure from current design but more accurate. We should solve the problem both ways and playtest both, and see what players prefer/find less confusing. (UNPARKED after the 2026-08-31 talk — the fog objection resolved in REVERSE: ACT_THEN_WALK is the only commit model a future fog modifier can work with, so building it forecloses nothing; fog itself is filed post-alpha in §9 below with the "clank" interception rule. BUILT 2026-08-31 on THIS branch (`rqd--move-commit-mode`, stacked on the #4 ghost), eyeball-gated: `Settings.move_commit_mode { WALK_THEN_ACT (default, shipped behavior), ACT_THEN_WALK }` — Options row "Move Commit" [Walk|Ghost] beside Move Confirm. ACT_THEN_WALK per the candidate shape: `Unit._stage_deferred_movement` commits LOGIC instantly (occupancy via `_claim_tile_keep_position`, which restores global_position around Tile.set_unit's snap — found by test; movement_completed still fires so auras/threat recompute) while the sprite keeps its origin position AND origin-row z; `PathVisualizer.show_staged_ghost` clears the spent beacons and parks the lone #4 ghost on the destination (anchored BEFORE the claim — anchor_offset measures sprite vs current_tile). Commit paths — `_execute_attack` pre-swing, `_on_wait` pre-set_acted — `await play_deferred_walk()`: sprite replays the captured path, restamping z per row, then the action fires; foot tracks stashed at stage time survive to set_acted (asserts guard both commit sites). Cancel is the honesty win: the sprite never moved, so Escape never teleports. Camera post-move target + UIManager panel side-pick re-anchored on current_tile (identical in WALK_THEN_ACT). Hint bar planning copy goes mode-aware ("…to confirm" / "Confirm path"). Player-only — the AI's walk is its telegraph. 14 tests in test_move_commit_mode.gd; suite 1036 green. EYEBALL: ghost-hold through the action menu, walk-then-strike pacing on commit, whether the deferred walk wants a skip input. Playtest Walk vs Ghost → delete the loser; squash-merge once seen in a build.)

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
  - The three formerly-undecided questions are all RESOLVED by the shipped
    slice 4 (2026-08-13..16, see §1): **2b** wins (the spend panel swaps into
    Manage Units' sheet column — no separate screen), button set = **both**
    (±1/±10 symmetric amounts AND the 99/100 named jumps), and **benched units
    do get bEXP** (the panel binds whichever unit the rail selects, bench
    included). The mockup page is behind the build on all three.
- **Controller glyph brief (Lawrence)** — <https://claude.ai/code/artifact/2d8a96a0-696a-4cfc-9b6a-d11acccf8788>
  Art request compiled 2026-09-02: the button-glyph sprite sets per skin
  (Steam Deck + Xbox share phase 1 — 6 sprites make the hint bar iconic;
  ~29 total for all four skins), sprite spec (10×10, 1-bit, name-by-depiction),
  plus the standing §4 icon asks in an appendix. Source of truth is
  [data/design/art-requests/controller-glyphs.html](../data/design/art-requests/controller-glyphs.html)
  — same edit-the-file-and-republish rule as the mockups.
- **Battle HUD mockup** — <https://claude.ai/code/artifact/d13f16f7-a4a2-47e2-9cbe-9b2e5c1107cd>
  In-battle widgets, one tab per widget; only the **hint / command bar** so far
  (round 1, 2026-08-16). Source of truth is
  [data/design/mockups/battle-hud-mockup.html](../data/design/mockups/battle-hud-mockup.html)
  in this repo — same edit-the-file-and-republish-to-the-same-URL rule as above.
  The bar itself has since been BUILT and RQD-approved on mouse (see §7); the
  mockup is one round behind it.

---

*(§1–3 below + the shadow-meeting notes were accidentally deleted in commit
`faa0b3a` on 2026-08-18 — a mid-line splice while adding the Battle HUD mockup
bullet — and restored 2026-08-31. Two things SHIPPED while the sections were
missing and are marked below: slice 4 / the bEXP spend panel (§1), and the
mid-battle level-up beat (§7).)*

## Lawrence meeting 2026-08-05 — shadow system

*(bEXP screen notes and the displacement items from this meeting are DONE —
see the mockup and §6. These three are the remainder.)*

- [ ] **Shadow system should accommodate `SMOOSH_X` above 1.0.** The drop shadow
  probably shouldn't distort on the X axis at all — a cast shadow stretches along
  its throw direction, and X-squash reads as the sprite being squeezed rather
  than the light moving. Currently `SMOOSH_X` is locked at 1.0 by RQD eyeball,
  so this is about making >1.0 *possible* and deciding whether X should be a
  dial at all.
- [~] **Try the dynamic shadow system on terrain modifiers and decorations.**
  When flipped on, suppress the hand-drawn shadows those sprites ship with —
  the export pipeline already masks shadow pixels under the object's own
  silhouette, so the two systems would otherwise double up. Experiment first;
  this could look wrong or could retire a whole authoring step.
  (BUILT 2026-09-07 on `rqd--terrain-stack`, eyeball-gated, framed the
  OTHER way per the 2026-09-07 talk: the authored `_shadow.png` WINS and the
  generated cast is the FALLBACK for sprites without one.
  `TerrainSpriteRenderer.generate_cast_shadow` runs the sprite's own pixels
  through `UnitShadow.project_silhouette` (one sun for units + terrain),
  feet = lowest opaque row, self-masked like the exporter so it can sit one
  z slot above bodies, ink baked, cached per texture. Opt-out
  `casts_shadow: false` in modifier_terrain.json (the five craters + the
  bridge — flat ground casts nothing); kill switch
  `DebugConfig.terrain_generated_shadows`. NOTE: today every non-flat sprite
  already ships an authored shadow, so nothing on disk exercises the fallback
  yet — the first shadow-less tree Lawrence exports will (a synthetic one is
  pinned in test_terrain_sprite_renderer.gd). The "suppress authored,
  generate everywhere" experiment is a two-line swap in `refresh()` if
  wanted. EYEBALL: generated vs authored cast length — Lawrence's shelltree
  measured ~0.85 of height vs the units' 1.0; `GENERATED_SMOOSH_*` alias
  UnitShadow's dials, split them if the two disagree on screen.)
- [ ] **`unit_cast_shadows` out of debug vars, made the default.** Already
  defaults true in `DebugConfig`, so nothing changes functionally — the ask is
  that it stop being a *dev* flag. Two ways: delete it and rely on the
  per-character override (`sprite.shadowBlobRadius`, 0 = no blob), or move it to
  `Settings` beside `portrait_effects_enabled` / `ui_motion_enabled`.
  **Recommend Settings** — it's a shipped visual feature with a real CPU
  rasterizer cost, which is exactly the kind of thing a Steam Deck player may
  want to turn off. Small, but it needs an Options row + persistence + a test,
  so it's grouped here rather than done inline.

## 1. Alpha blockers

- [~] **Squad / prep + between-mission level-up screen.** *(The single biggest
  open item — flagged PRIORITY twice, in two different sections, for months.)*
  Pick squad, equip moves (~330 in the bank), equip passives, distribute stat
  allocation points. One screen does double duty: initial prep AND the
  between-mission level-up display (XP gained, stat-up rolls, new moves/passives
  unlocked). Build initial prep first; the level-up overlay reuses most of the
  same widgets. See [equipment_picker.md](equipment_picker.md) and
  [squad_manager.md](squad_manager.md).
  - **Porting from the mockup in slices** (design locked in
    [intermission.md](intermission.md), branch `rqd--manage-units`):
    - [x] Slice 1 — intermission hub (2026-08-07).
    - [x] Slice 2 — ManageUnitsScreen scaffold + live roster rail (2026-08-10):
      search / sort-key-as-readout / bench pips, deployment resolved at hub
      arrival and rewritten per pip toggle, always in roster order (§4d — spawn
      positions can't move under rail sorting; tested). bEXP deep link opens
      level-ascending.
    - [x] Slice 3 — sheet + workbench (2026-08-10). UnitSheet: ident, XP row
      (display-only until slice 4), single-column stat block with StatCapBars
      + inline [−]/[+] allocation, move/passive slots, injury chips. UnitWork-
      bench: lane per slot kind — move/passive (detail → swap bar → filtered
      bank, live commit), stat (blurbs + cap position + ACROSS THE SQUAD),
      injury, unit summary. prep_screen.gd and equipment_picker.gd DELETED
      (absorbed; bank/equip semantics pinned in test_unit_workbench.gd).
    - [x] Slice 4 — the bEXP level row (SHIPPED 2026-08-13..16, commits
      e39eccd..369936e + round 5 cf09c2a; discovered-done 2026-08-31 while
      restoring this section — the deletion ate the status update).
      `BexpSpendPanel` swaps into the sheet's column:
      [RESET][-10][-1][+1][+10][99][100][CONFIRM], single-level cap
      (staged + experience ≤ 100), two-segment XP bar (committed gold +
      pulsing staged azure), reveal through the shared `LevelUpStatBlock`,
      holds the +1 view until CONTINUE. The staging layer shipped as pure
      arithmetic inside the panel; `SquadManager.commit_bexp_pour` is the one
      irreversible step (growth rolls inside). Stages persist across rail
      switches — one squad-wide decision, one confirm; leaving discards all.
      The 99 brink parks XP so the next combat action takes the level with
      full growth rolls instead of bEXP's fixed spread.)
  - Related design note: the level-up moment is a *dopamine beat*, not a text
    dump — budget polish from day one.
### Subtasks
  - [x] For the bEXP allocation system, I think we should have buttons:
    [-10][-1][+1][+10][99][100]
    May want +/- 5 in there. Probably not to start. What do you think?
    Need a clear pool total to see what we're spending from
    (RESOLVED by slice 4 above — exactly this row plus RESET/CONFIRM, and the
    staging-layer blocker below was solved by keeping the stage as arithmetic
    in the panel until one CONFIRM.)
    - **Unblocked 2026-08-05, engine ready 2026-08-06.** The pool is flat now,
      so the buttons have something coherent to act on and the pool total is
      the readout. ±5 agreed as probably-not-to-start.
    - **Blocker found on implementation:** the `[-1]` / `[-10]` refunds can't
      wire straight through to `SquadManager.buy_bexp_level` — that commits
      immediately and irreversibly, because the growth rolls happen inside it.
      Refundable pouring needs a **staging layer** holding uncommitted XP until
      the player confirms (which is what the mockup's `u.poured` models — it
      gets away with it by not simulating growths at all). Design that before
      building the row.

  - [x] **Class-based stat caps + the shared cap bar** — DONE 2026-08-06.
    [ClassStatCaps](../scripts/units/class_stat_caps.gd) holds all 21 classes ×
    8 stats plus the global (tier-3) ceiling every bar is scaled against;
    `get_stat_cap()` reads the unit's class. One shared
    [StatCapBar](../scripts/ui/components/stat_cap_bar.gd) draws track + fill +
    bonus and is used by CharacterSheetPanel, UnitDetailPanel and
    EquipmentPicker — it replaced two near-identical hand-rolled bar
    implementations that both scaled against a flat `STAT_DISPLAY_MAX = 60`
    matching no real ceiling, and added the first cap awareness EquipmentPicker
    has ever had.
    - **Live balance change, not just UI:** the old flat caps were unreachable,
      so `is_at_stat_cap()` was permanently false. Class caps bind, which turns
      on growth-roll skipping, bEXP growth concentration, and gives promotion a
      purpose. Cap *numbers* are PROVISIONAL — tests assert the tier ladder and
      archetype shape, never individual values.
    - [ ] **Playtest the low caps.** A Mage starts DEF 5 against a cap of 9 —
      four growth points and its DEF is done, plausibly by level 10. Intended
      shape, but the likeliest thing to feel bad first.
    - [ ] CharacterSheetPanel's HP bar still fills against `get_stat_cap` alone
      (now class-correct) without showing the class-vs-global track. Convert it
      to StatCapBar for consistency, or decide HP reads better as a plain bar.

  - [ ] **bEXP income to ~400 pooled/mission** (≈2× current) so it closes the
    last ~0.5 levels/mission the combat award doesn't. Sized against the pacing
    target below; do it after that's measured, not before.

  - [ ] **Verify the pacing target in play: ~2 levels/unit/mission** for the
    whole squad when the player uses bEXP and fields underlevelled units.
    Implies a ~30-mission campaign for Lv 1→60. Rests on an estimate of **~1.5
    kills per deployed unit — measure this first**, the whole model hangs off it.
    Everything else in the XP economy is now built and tuned to this guess.

  - [x] **Revamp StatAllocation to percentage** — DONE 2026-08-06. `MODE` →
    `PERCENTAGE`, `PCT_PER_POINT` 0.0625 → 0.10 (so 4 pips = +40%, as spec'd).
    Also removed the `max_hp` flat carve-out, which had survived into PERCENTAGE
    mode and would have reintroduced exactly the archetype-flattening the mode
    exists to prevent. Added `tests/unit/test_stat_allocation.gd` (first coverage
    this file has ever had) and a runtime assert on the per-stat cap — it was
    enforced only in `equipment_picker`, nothing in the data model.

  - [x] **Flatten bEXP to a simple pool** — DONE 2026-08-06. `bexp_level_cost`
    and its three constants replaced by `BEXP_LEVEL_COST = 100`. BonusXpPanel
    header note and buy-button tooltip rewritten.

  - [x] **Rework CombatXpCalculator** — DONE 2026-08-06, values PROVISIONAL
    ([class-and-promotion.md](../data/design/class-and-promotion.md) §4).
    `TIER_LEVEL_BOOST` + `_internal_level()` deleted, `MAX_XP` retired, awards on
    `base × 2^(gap/15)` with `HIT_BASE_XP = 27` / `KILL_BASE_XP = 80`. Survival XP
    deliberately left on the difference formula (being attacked isn't a choice, so
    the funnel argument doesn't reach it). Tests assert shape, not dials.
    - **Found on implementation:** `MIN_XP` is unreachable at k=15 — the steepest
      legal decay (Lv 60 farming Lv 1) still pays 5 on a kill. The floor is a
      safety rail, not a live rule, and "the carry stalls" means ~20 kills/level
      rather than zero. If a future `k` makes it bind, that's the signal the
      curve got steep enough to feel like punishment.


- [ ] **Where do objectives actually get DEFINED?** *(Gap found on F5,
  2026-08-07 — there is no authoring system at all.)* `mission_manifest.json`
  has an `objectives: []` key and every map ships it empty; `MissionCatalog`
  reads them for the award side; nothing writes them and nothing tracks them.
  So the whole objective system is currently a shape with no content.
  - Stopgap already in: `MissionCatalog.briefing_objectives()` returns an
    implicit **"Eliminate the enemy"** when a map declares none, so a briefing
    never renders an empty list. Display-only, pays no bEXP — routing the enemy
    is how you win, not a bonus for winning.
  - The real decision, and it's three questions stacked:
    1. **Where does an objective live** — JSON in the manifest (data, easy to
       author, can't reference scene nodes), a Resource per mission (typed,
       inspectable), or on the map scene itself (can point straight at the
       courier node it's about)? The diegetic-objectives doctrine wants
       objectives bound to on-board causes, which argues for the map scene.
    2. **What is an objective made of** — an id, a label, a bEXP amount, and
       *some* completion predicate. The predicate is the hard part: "escort
       NPC to tile", "kill unit X", "survive N turns", "reach tile" are all
       different shapes.
    3. **Who evaluates it at runtime** — nothing does today. Needs a hook on
       the same events battle result already listens to.
  - Blocks: Mission Briefing (§5 of [intermission.md](intermission.md), the hub
    entry is inert until this exists) and the tracking half of Battle Result V2.

- [ ] **Battle result V2.** V1 shipped (BattleResultPanel: turns-vs-par, itemized
  bEXP income, kills/losses/injuries). Remaining scope: runtime objective
  **tracking** (couriers/NPCs — the award side is already ready in MissionCatalog)
  + per-unit combat stats. See [mission_objectives.md](mission_objectives.md).
  Gated on the objective-authoring decision above.
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
*(Everything in this subsection + the controller glyph sets is compiled in the
**controller glyph brief** — see Live links up top. Hand Lawrence that URL.)*
- [~] **Controller button glyphs** — GENERATED IN-HOUSE same day (2026-09-02,
  branch `rqd--controller-glyphs`, eyeball-gated). RQD's call on reading the
  brief: 1-bit meant the palette wasn't load-bearing, so
  `tools/godot/generate_controller_glyphs.gd` emits the FULL set — 40 sprites
  after the same-day revisions (all four skins at once — the phasing in the
  brief collapsed) into `art/sprites/ui/controller_glyphs/`, name-by-depiction.
  BUTTON-FORMAT (RQD same day): each sprite carries its own silhouette —
  letters in 12px circles, shoulder labels on 15-wide bumper pills swept round
  on the correct outer corner, rounded squares for sticks + back grips
  (L4/L5/R4/R5 + Elite P1–P4), the d-pad its own cross — and the bar draws NO
  plate, just a TextureRect modulated to TEXT_PRIMARY. Height 12 is the pinned
  invariant; width is free (chip-expands rule). RETRO START/SELECT (RQD same
  day: ☰/⧉ "always made me look at the controller"): every pad's Menu/Options
  → START word-pill, View/Share → SELECT; Switch keeps +/−; ☰/⧉ sprites kept
  unmapped. Map keys on `joy_button_label`'s output so the skin logic isn't
  duplicated. BREATHING ROOM (RQD same day): letters/digits keep all four
  orthogonals ≥1px clear of the silhouette (diagonals fine) — text and
  silhouette compose on separate layers and the generator ASSERTS the rule
  (circle got flatter shoulders, bumper grew to 15×10, rounded square to
  13 wide, to pass). COLOR IDENTITIES (RQD same day, "Y = yellow skittle"):
  face buttons render SPLIT layers (shared `face_form` disc + per-glyph
  `*_char`, both 1px-padded for halo room) tinted per skin — Xbox/Steam
  color the skittle + dark letter (A Green 6, B Red 5, X Azure 5,
  Y YellowOrange 7; glow = ramp −3, the TEXT_* pairing rule), PS colors the
  MARK on Gray 2 plastic (✕ Azure 6, ○ Red 6, □ RedViolet 6 — pink, not the
  retired magenta — △ Teal 6), Switch stays neutral. Glow rides the runtime
  hud_glow shader (generic TextureRect path — no baked glow layers).
  `joy_glyph_identity` is the one table; missing layer files degrade to the
  merged outline sprite. CIRCLE WENT ODD (RQD same day: letters sat
  off-center, "shrink or widen by 1px"): 12→11 wide, so 5-wide letters and
  the redrawn 5-wide marks center exactly on both axes. TWO STYLES
  (RQD 2026-09-04): `HintBarCommands.joy_glyph_style` — HARDWARE (ships:
  colors where the plastic puts them) vs INK (identity in the glyph + its
  glow, on a semitransparent plate: `INK_PLATE_RAMP/INDEX/ALPHA` knobs,
  Eggshell 1 @ 85%; letter bodies brighten a step for text-on-dark,
  `INK_LETTER_RAMPS`). Static var — flip the default in code or set at
  runtime, bar re-renders at the next boundary; tests pin their own style
  so either default ships. INK ROUND 2 (RQD 2026-09-04, from an in-game
  shot): LB broke the pattern (only faces had layers) → the generator now
  emits form/line/char layers for EVERY button family (`_emit_form_family`:
  face, bumper_left/right, square, start, select — 86 sprites total), INK
  plates the whole bar uniformly, and a NEW OUTLINE LAYER ships in mid-gray
  (`INK_OUTLINE_RAMP`/`INK_OUTLINE_INDEX` = Gray 5, "not subtle, not
  bright"); identity-less glyphs (LB, START…) speak TEXT_PRIMARY + its
  glow. `joy_glyph_recipe` is what the bar paints; HARDWARE is untouched
  (neutrals stay merged-outline). EYEBALL: HARDWARE vs INK verdict (strips
  in .claude/hint_bar_strip_*.png — ink pair rendered on a BRIGHT backdrop
  now), plate alpha/index, outline Gray 5 vs 6, Deck-shares-Xbox-colors
  call, PS disc contrast.
  Lawrence's ask is now a VETO/REDRAW pass — replace a PNG, keep the name,
  nothing else moves. Contact sheet: rerun the generator, it drops
  `.claude/controller_glyphs_contact.png` at 8×. Tests:
  test_controller_glyphs.gd (every skin×button label → sprite or deliberate
  text). EYEBALL: chip-vs-text row height, chip read at 1× on the Deck.
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
- [x] **Decorations layer lacks the modifier layer's sprite handling** — image is
  cropped, no shadows. (FIXED 2026-09-07 on `rqd--terrain-stack`:
  `ModifierRenderer` → `TerrainSpriteRenderer`, one per paint layer, modifier
  spawned first so a decoration on a modifier's cell wins by tree order at
  equal z; `PURE_DECORATIONS` z slot renamed `TERRAIN_SHADOWS` (it was
  already where terrain shadows rendered). It was worse than "cropped": the
  flat z also meant a decoration never occluded a unit behind it. Before/after
  on lawrence_test_map: volcano cones went from flat-topped 32px chunks to
  full cones with lava tips + cast shadows. Lawrence's map has 43 decoration
  cells vs 31 modifier cells, so this was most of what he'd painted.)
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

- [ ] **Pre-warn system for move-triggered enemy passives** (todo 2B, parked
  2026-08-21). "You're about to hand the Pyro a Bellows stack" — a pulsing alert
  on the move chip / in the combat preview when the chosen move would trigger a
  passive on the target (Bellows today; any on-hit reactive passive tomorrow). A
  whole system, not a Bellows special case: needs a registry of "this passive
  reacts to X" predicates the preview can query. Great for the presentation, not
  alpha-gating.
- [ ] **Esc / pause menu outside battle.** The battle system menu is reachable in
  the intermission screens, where "End Turn" is meaningless. We probably *do* want
  Options reachable everywhere. Options: **(a)** context-aware system menu that
  drops End Turn/battle items outside battle, **(b)** a bare Options-only popup on
  Esc in non-battle screens, **(c)** suppress Esc entirely there.
  **Recommendation: (a)** — one menu, items gated by `GameStateManager` state.

- [x] **Mid-battle stat-up moment?** ANSWERED YES + SHIPPED (RQD 2026-08-11,
  round 5 cf09c2a; discovered-done 2026-08-31 while restoring §1 — see the
  note above §1). `LevelUpStatPanel` pops the FE-style reveal mid-battle: the
  battle holds its breath (`Unit._flush_xp_feedback` awaits it), click
  anywhere skips, reduced motion shows everything at once. The reveal
  choreography lives in the shared `LevelUpStatBlock` — the same component
  the bEXP spend panel embeds — so the two celebrations can't drift.

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

- [ ] **Hidden enemy movesets, revealed on use?** (Proposed 2026-08-31 in the
  fog talk — the systemic depth-reclaim after ruling fog out as a mechanic.)
  Enemy move slots render as `?` until the enemy uses the move, then flip
  permanently (battle-scoped or campaign-scoped — TBD). Pokemon-native
  uncertainty in the combat layer instead of the map layer: probing becomes an
  action with information value, inference from class/element becomes a skill.
  Infrastructure half-exists — the AI already floats move names in element ink
  on use, and enemy loadouts already have pools + unlock slots. Needs: RQD
  verdict, the reveal-scope call, and an answer for the combat preview (a
  counter-damage forecast against an unrevealed move would leak the answer —
  show `?` damage? forecast only revealed moves?).

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
  — sprite borders for the glass, InteractiveButton for touch buttons, NOTICE
  ramp step (Magenta 4–6); glyph chips are DONE in-house 2026-09-02 (branch
  `rqd--controller-glyphs`, see §4) — Lawrence's half is just vetoing the
  generated sprites;
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
- [ ] **Fog missions (design filed 2026-08-31 — the 4A talk).** Fog of war as a
  RARE mission modifier (3–4 per campaign, FE-style spice), never systemic.
  Standing doctrine: **full-information board** — systemic uncertainty lives in
  enemy capability (see the hidden-movesets proposal in §7), AI variance, and
  dice, never in map visibility. Only viable under ACT_THEN_WALK commit mode
  (planning is a ghost and reveals nothing; commit is the one irreversible
  act — any revocable-walk model makes fog free to scout).
  - **DECIDED — the "clank" rule (RQD 2026-08-31):** a committed walk that hits
    a hidden enemy STOPS adjacent. No forced combat, no player option — clank,
    stop, both units revealed. A planned attack fizzles through the existing
    inviolate OUT OF RANGE callout convention. The punishment is positional
    (parked beside a revealed threat going into enemy phase) and is naturally
    sized by the injury system (downed = injury; permadeath only on slot
    overflow).
  - **First dial if clank proves too gentle:** forced exchange at a flat damage
    penalty — NOT accuracy (a whiff lottery inside a punishment beat reads as
    dice betrayal) — with no defender counter (both surprised; the walker gets
    the glancing blow, compensating them for being the one ambushed).
  - **REJECTED:** sight-history "preparedness" states (could-see-before-moving
    / never-lost-sight) — a hidden conditional modifying combat math; fails
    the one-rubber-band doctrine.
  - **The actually-hard open parts, in order of pain:** (1) the threat overlay
    goes blind in fog — enemy-phase deletion out of the dark is fog's
    worst-feel failure and needs an answer before this ships anywhere;
    (2) AI vision symmetry — a cheating AI is hateable, and symmetric vision
    means hidden PLAYER units clank enemy walks too (ambush walls — the fun
    half, but real AI work); (3) vision model + reveal rendering + revealed-
    terrain memory + save format; (4) requires TRUE deferred logic (unit
    logically at origin until commit) — the alpha ACT_THEN_WALK is the cheap
    visual variant, so this refactor comes first.

---

## 10. Stretch goals

- [ ] Sync movement beacons to music BPM. (Constants are already isolated in
  `path_visualizer.gd`: `FRAME_DURATION_MS` / `TILE_DELAY_MS` / `CYCLE_PAUSE_MS`.)
