**Reminder** We should be trying to get to alpha.
+ fix essential bugs
+ additional features need a good reason to be added at this point
	- there will be time to add them later
+ prioritize the highest leverage items that get us to alpha
+ done items move to [todo-archive.md](todo-archive.md): grep it, don't read it

# Meeting Todo
- [ ] Rebelle 7 needs to start working
- [ ] Victory screen mockup
- [ ] Defeat screen animation
- [ ] Wednesday with Lawrence: the regolith backdrop. Applies once
  `rqd--regolith-backdrop` reaches lod--main.
	- Layers follow the map now. A layer named after a map piece (`crater`,
	  `shelltree`, `piperoot`, `firetopradish`, `volcano`, `mountain`) or a
	  floor material (`orange_sand`, `blue_sand`, `water`) shows only when one
	  is within two steps of a fighter. Other names (`ground_regolith`,
	  `hill_left`) always show. Full rule: art/backdrops/combat_test/README.md.
	- Renames in combat_regolith.aseprite: `raddish` → `firetopradish`,
	  `volvano` → `volcano_…`, `volacano_smoke` → `volcano_smoke`, `rivers` →
	  `water`; `sand_orange` → `orange_sand` if it's for orange sand only;
	  `sand_blue` → `blue_sand` when he un-hides it. Unrenamed, they show in
	  every fight.
	- Smoke: renamed `volcano_smoke`, it shows only with the volcanoes (if a
	  volcano layer ever gets `_left`/`_right`, the smoke takes the same).
	  We animate it in code (the 9/28 smoke-shader item), so it stays on its
	  own layer. He paints smoke the way he does now; he can tune the motion
	  live with the `smoke_*` dials in the ` console.
	- `_left` / `_right` now mean "near the fighter on that side". His
	  `crater_left` and `crater_right` each span most of the canvas: one
	  crater per side, probably.
	- Stars: paint the sky as it looks at rest; a twinkle dot only adds the
	  flash on top (the rule for every sky). Done for him: every star on
	  skybox_stars is now its center dot, at his luminance; his original is
	  kept hidden as "stars mockup — do not export".
	- Don't open combat_regolith.aseprite until this branch reaches
	  lod--main: the branch changed it, and Aseprite files can't merge.
	- Re-copy tools/aseprite/export_combat_backdrop.lua into his Aseprite
	  scripts folder. The first run asks to trust it: it deletes files left by
	  renamed layers.
- [ ] 

# Meeting 20260928 Todo
- [ ] If Lawrence includes a glow layer in any sprite, we should apply our (new) glow shader
- [ ] 

# Resp

# Claude
Things Claude found while working on something else that need doing — not
asked for, not yet acted on. RQD triages (promote, answer, or strike);
Claude deletes an entry once it's fixed or moved into a real section.
Observations with nothing to do go in "Claude FYI" below.
- [ ] Twinkle lab: the published artifact
  (https://claude.ai/artifact/6KnNAarmzsRbTbwdXvD9FE) still runs the pre-fix
  shader; republish it before sending Lawrence the link. The three presets
  (RQD / Lawrence / geometric middle) aren't built yet; values in Claude's memory.
- [ ] VisualFeedbackManager is down to the hit flash (rqd--alpha-bugs deleted
  its dead pulse/flash/cancel-hint code), and the flash's tween no longer
  needs a node. Make it a static function and drop the autoload, plus
  GameRoot's reparenting of it and the CLAUDE.md mentions.
- [ ] Art board spec, the cast row (tools/art_dashboard/README.md): your old row
  said "nothing, use particles on map"; the code plays the melee clip
  (Ernesto/Keener/Spaceman/Grasker swing for Focus today). Which is right?
- [ ] Dead art references, found by the art-name survey:
  `editor/tileset_terrain_setup.gd:30-36` wants `tilesets/*_12x4.png` (moved to
  `12x4_terrains/`); `ui_manager.gd:805+` loads 8 missing `hud_panel_*.png`
  (8 warnings every headless run); `menu_stage_backdrop.gd:32-33` points at a
  missing `art/backgrounds/`. Also `scripts/editor/aseprite_tag_exporter.gd`
  is an unreferenced older copy of the tag-exporter plugin: delete it?
- [ ] 

# Claude FYI
Observations with no action item: worth knowing, nothing to do. No
checkboxes. RQD deletes an entry once read; if one grows an action, it moves
up to # Claude.

# BUGZ
- [ ] There's no visual feedback on the map for the Protector passive. Let's talk about this one because it will be easy to confuse the player.

# Lawrence playtest feedback
- [ ] When it's time to implement tutorials, the sexy robot will appear over the screen, explaining the intermission functions, with CTA effect over whatever's being explained, and the tutorialized element being the only interactible element on-screen.
	- [ ] I think I want a brief cutscene in the beginning, then to plonk the player into a very simple first battle, tutorialize the basic mechanics, and then tutorialize the intermission screen. We may not even introduce the iontermission screen until 3-4 missions in, once the mechanics are suf
	ficiently tutorialized - it's just a lot to take in for a new player.
- [ ] 

# Quick Fixes

# Characters
- [ ] Goblin Healer
	Base class: Herbalist (Monster)
	├2A: Apothecary (Monster/Plant)
	|	├3A: Plague Doc (Monster)
	|	└3B: Distiller (Monster/Plant)
	└2B: Sawbones (Monster/Simple)
		├3C: Chirurgeon (Monster/Simple)
		└3D: Thaumaturge (Monster/Occult)

- [ ] Plant Cultist
	Base class: Cultist (Occult)
	├2A: Botanist (Occult/Plant)
	|	├3A: Sage (Occult/Plant)
	|	└3B: Harvester (Occult/Plant)
	└2B: Creeper (Occult/Plant)
		├3C: Abomination (Occult/Plant)
		└3D: Topiary (Plant)

- [ ] Plant Healer
	Base Class: Bulb (Plant)
	├2A: Cactus (Plant)
	|	├3A: Pyracantha (Plant/Fire)
	|	└3B: Snowdrop (Plant/Cold)
	└2B: Taproot (Plant)
		├3C: Samara (Plant/Air)
		└3D: Mandrake (Plant)
	2B Taproot = the bulky storage-root class ("Tuber" fit; RQD found the
	word ugly).
	Moves + passives for this tree (Vines, Sunflower, Whirlicopter, Pod,
	Turgor, Stolon, Clover) live in data/design/moves-and-passives.md with
	the rest of the wishlist. Creeper is taken (Cultist 2B); "Host" is a
	good name held in reserve.

- [ ] Base Class: Thief (Simple)
	├2A: Assassin (Simple)
	|	├3A: Hitman (Simple)
	|	└3B: Fixer (Gentry)
	└2B: Kleptomaniac (Simple)
		├3C: Highwayman (Chivalric)
		└3D: Infiltrator (Simple/Robo)	
	Homeless on purpose: a design from Lawrence's new line-art batch
	(art/lineart_fullres/assassin.png, finished, unwired; no idle sprite
	yet, player-character status undecided). The classes sound
	fun enough that the player should probably get his hands on them.

- [ ] Whirlicopter — Plant move, Samara's signature, late game, 2–3 uses:
	repositions the user 3 tiles in one direction, healing the tiles
	beneath (units on them, or a healing plant terrain status — ties to
	Pod). New move shape: self-displace along a line. "OP as fuck" by
	design. Waits on promotion (tier 3) and maybe terrain statuses.

- [ ] Squash
	- What elemental type is he?
	- Base Class: [???]
		├2A: 
		|	├3A: 
		|	└3B: 
		└2B: 
			├3C: 
			└3D: 	

- [ ] 

# Todo
- [ ] We should go through the unit tests and remove the ones which are simply there to pass.
	-> Anything testing somthing that has regressed should stay
	-> Anything that's hard to catch in-game should stay
	-> It's possible there are zero such tests, but please review anyway.
- [ ] Mouse commands that bypass the InputMap. Keys, pad and the wheel all go
  through actions (project.godot), but three mouse commands check the
  physical button: right-click = back on the board
  (`InputManager._handle_right_click`), middle-drag = camera pan
  (CameraController), right-hold = move peek (MoveChipButton). A rebind
  screen couldn't reach them, and the hint bar can't name a rebound one.
  Fix: an action each (`ui_cancel` may already fit right-click). Left-click
  as "press the thing under the pointer" stays raw — that's what a pointer
  is, same as Godot's own Button. Blocks nothing until a rebind screen exists.
  RQD: matters a lot for Steam Input (it remaps actions, not raw buttons).
- [ ] We should have fullres line art for the Keener enemy - name is either "cultist" or "blood mage," not to be confused with the plant cultist.
- [ ] SPRY follow-up: Corporate have a more sophisticated SPRY workflow - would be very interested to pull any ideas from it which are applicable to our project. Should be ready to go by 9/14 - check back in after that.
- [ ] I noticed the enemy AI will often move and not attack - definitely not a bug.
- [ ] In spite of the above, default difficulty is substantially too high - this is fine for now because I've done minimal tuning of the difficulty, but we should discuss how to tune this without simply overleveling the player. The game should *feel* like an even playing field, or even slightly oppressive - we want to keep the player in that zone of proximal development, and never feel like they're coasting. Force them to learn, but make the on-raamp really gradual. Shouldn't feel like a tutorial either, though.
  - [ ] We should discuss dynamic difficulty scaling, as well. This would be especially easy to implement near-imperceptibly in our game
- [ ] Note on AI in general - this needs a complete rework. I want the AI to be smart. We're not there yet - I want to get the systems in a good place first. But this is a high priority task, when the time comes.
- [ ] Victory screen popping up needs more dopamine - discuss
  (Mockup session, HTML first.)
- [ ] Mix the audio so every bus sounds right at 80% — the default for all
  three volume sliders (already true in code; a settings.cfg that saved
  another value keeps it).
- [ ] Renderer on Bazzite / SteamOS (gamescope): make sure it plays nice.
  Probed on RQD's laptop (240 Hz, NVIDIA, Wayland session), cap 300:
  Godot's default X11 driver runs through XWayland — no mailbox (falls back
  to plain VSync, 240 fps), VSync off works (301). `--display-driver wayland`:
  mailbox works (301, no tearing), VSync off is refused (tearing not allowed).
  To decide / check:
  - Prefer native Wayland on Linux (project setting
    `display/display_server/driver.linuxbsd`)? It's the no-tearing world RQD
    wants; Godot's Wayland driver is the younger one.
  - What gamescope (Deck gaming mode, Bazzite) offers: present modes, the
    refresh rate Godot reads, the Deck's 40–60 / 90 Hz modes.
  - A mode the system refuses is detectable (`window_get_vsync_mode` reports
    the fallback a frame later). The Options pane could say "not on this
    system" instead of Higher? / VSync Off silently doing nothing.

- [ ] Terrain sprite footprints: every sprite except `castle_a` exports with a
  1×1 footprint, the 160×96 buildings and the 96×96 bridge included, so
  gameplay treats each as one cell. Intended? If not, Lawrence suffixes the
  tags (`_3x2`) and re-exports; the registration tool warns when an atlas
  tile moves. (Context: the terrain-stack notes in the archive.)
- [ ] `casts_shadow: false` in modifier_terrain.json: which floor-level
  decorations cast no shadow at all is RQD's list to fill, one line per
  sprite or family (`"piperoot_*"`).
- [ ] Eyeball the editor preview (terrain sprites drawn on an open map): does
  it fight the tile cursor or the selection highlight?

# Combat scene — follow-ups
- [ ] **Lawrence: reaction clips** — `dodge`, `hurt`, `death` (side view,
  left-facing, tag names from the vocabulary); then `cast`; crit variants
  last. Procedural stand-ins (hop, flash, fade) play until then.
- [ ] Procedural projectile for ranged clips (needs an `fx_origin` slice from
  Lawrence — muzzle / fist / wand tip).
- [ ] Terrain tile strip: draw each puppet's REAL tile terrain under it
  (defense bonus for free) instead of the flat palette tiles.
- [ ] Enemy-phase pacing (the scene on the enemy's turn may want to run faster).
- [ ] "Combat scene" tab on the battle-HUD mockup artifact for Lawrence's HUD
  pass (contents locked — D7 rounds 3–4 in the archive).
- [ ] Mirrored right-facing idles on the left puppet — art fix (RQD: "we'll
  likely fix it later").
- [ ] Spin-off (mobile arc, NOT this feature): touch has no attack forecast
  before the tap that attacks — the preview panel is hover-driven. Fix is
  tap-to-preview then tap-again-to-attack (the marker double-press pattern).

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

**Status markers:** `[ ]` open · `[u]` worked on, unfinished · `[~]` Claude
finished it · `[x]` done. Both `[~]` and `[x]` move to
[todo-archive.md](todo-archive.md) at the next sweep; anything wrong comes back
as a bug.

## Live links

- **Art board** — `tools/art_dashboard/index.html`, opened from disk: Lawrence's
  checklist of every character's art. What each box needs: that folder's README.
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
  The bar itself has since been built and RQD-approved; the mockup is one round
  behind it.

---

## Lawrence meeting 2026-08-05 — shadow system

*(bEXP screen notes and the displacement items from this meeting are DONE —
see the mockup and §6. These three are the remainder.)*

- [ ] **Shadow system should accommodate `SMOOSH_X` above 1.0.** The drop shadow
  probably shouldn't distort on the X axis at all — a cast shadow stretches along
  its throw direction, and X-squash reads as the sprite being squeezed rather
  than the light moving. Currently `SMOOSH_X` is locked at 1.0 by RQD eyeball,
  so this is about making >1.0 *possible* and deciding whether X should be a
  dial at all.
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

- [u] **Give all characters at least 9 moves and 9 passives.** Content pass.
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

---

## 4. Blocked on Lawrence (art requests)

Nothing here is code-blocked; all have placeholders shipping today.

### Icons
*(Everything in this subsection + the controller glyph sets is compiled in the
**controller glyph brief** — see Live links up top. Hand Lawrence that URL.)*
- [ ] 10×10 **"Swap"** icon (like 🔁, but straighter arrows).
- [ ] Tiny **melee** and **ranged** glyphs (~5px tall, inline beside a 5px-font
  number). The terrain preview's split defense cell (Crater: bonus vs melee,
  penalty vs ranged) is rendering `M1.2` / `R0.8` with letter prefixes until
  these land.
- [ ] **Range icons**: range 1, range 2, range 1-2, range 2-3, range 3+.
  *(Any others needed here?)*
- [ ] **Buff icons**: Rallied, Fortified, Hasted, Focused, Regen — plus the
  long-missing **Bellows**. (Fortified / Hasted / Regen have PLACEHOLDERS as
  of 2026-09-10 — `tools/art/placeholder_status_icon.gd`, same-name
  replacement; the missing-art resource error is gone but the art is still
  Lawrence's.)
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
- [ ] **Ink pass on the 9/7 paper roughs.** Renamed and wired as placeholder
  portraits: keener, flamethrower_phoenix, robot, squash, thumps. They're
  marked in `tools/art_dashboard/placeholders.js`, so the board shows them
  but doesn't count them. `bugler.png` and `pirate_boss` aren't wired: no
  character matches them yet. All are opaque page photos, 4–15 MB. A
  transparent re-export to the same file name replaces each one.
- [ ] **Sprites for the new characters** once their kits settle: swordsman,
  gentry prince, wooly beast, tipsy goblin (all on the 16px
  `placeholder_unit` today), then the three NPCs and the Thief.

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
- [u] **Author the remaining displacement moves.** The engine supports all of them
  today; they just need authoring. **Stampede** and **Razor Wing**
  (charge = `subject:self` + `toward_target` + `fall_through`, landing past the
  target), and **Roar-knockback**.
- [ ] **Keep the callout convention inviolate:** OUT OF RANGE always floats over
  the unit that LOST its attack.

---

## 6. Bugs
- [ ] The mountain tiles - is it possible to make these as terrain modifier tiles, while also keeping their dynamic shadows?
- [ ] We can't paint tilesets on the modifier/decoration layers. We were hoping to include some auto-tileable modifier/decos which could take advantage of the dynamic shadows system. How would we go about designing that?

- [ ] **Move distribution in the demo is wonky.** Characters get moves far too
  powerful at level 5; this is what makes the Ogre feel broken. *Deliberately
  parked until the move bank is much wider.*
- [ ] **Tile seams at certain zoom levels + camera positions.** Hard to reproduce.
  The seam z-indexes at roughly the enemy-sprite level; it's a vertical line of
  subpixel resolution when the camera isn't centered. **Needs a screenshot.**
- [ ] **The move preview doesn't animate properly when a unit retreads its path.**
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

---

## 8. Not started

- [ ] **STAB presentation redesign + a damage-calc tooltip system** (RQD
  2026-09-11, after seeing the x1.20 readout: "a simple multiplier isn't
  clear enough — back to the drawing board"). The yellow multiplier stays, but
  it can't carry the *why* on its own.
  - **Idea 1 — show the MATCH, not just the number.** When STAB applies, the
    unit's elemental type icon and the move's elemental type icon on the
    combat preview both light up together — the §14 traveling-border orbit
    (the assigned-marker recipe) or a shimmer — reading as "THESE MATCH,"
    alongside the yellow multiplier. Needs a §14 ruling: the orbit currently
    means *assigned*; a shimmer would be a new motion category, and the
    scarcity rules cap animating things at two on screen. Decide which
    channel, then mock it on the battle-HUD artifact before building.
  - **Idea 2 — a tooltip system for the whole damage calculation.** Every
    factor that modifies damage gets an explanation on demand: base (stat +
    power − def), type effectiveness (with the two type icons and the stage
    colour), STAB (matching icons), Bellows stacks, terrain on either side,
    Reckless, crit, hit chance. Colour-coded to the same tiers the panel
    uses, icons inline where a factor has one, so the tooltip *is* the
    legend. Rides the existing hold-to-peek contract (§14 detail tooltips:
    long press = right click = Back/R3). Presentation must be on point —
    this is the "what can I click / what does this mean" answer for the
    combat preview, which today looks interactible and isn't (§2).
  - Related: the in-game legend / glossary ask in §2, the "combat preview:
    indicate buffs/debuffs in play" item below, and the corruption misfire
    chip in §7 — all of them are "explain the number" and should share one
    tooltip surface rather than each growing a badge.
  - Until then the shipped reading is colour-only: yellow x1.2 = STAB on a
    neutral matchup, orange x1.2 = a type edge without STAB
    (`CombatPreviewPanel.displayed_multiplier`).

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
- [ ] **Split `StatusEffectType` into `AfflictType` + `BoostType`.** Significant
  rewiring across the game logic, but there's no real alternative: units need to
  carry a boost and an affliction simultaneously.

---

## 9. Post-alpha / deferred

- [u] **Touchscreen UX: preview panels occlude tappable tiles.** Options: (a) don't
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
