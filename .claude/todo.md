# [ ] Meeting 20260603
## [ ] RQD
- [ ] How hard would it be to make a crater (terrain modifier) grant a defensive bonus against melee attacks and a penalty against ranged attacks?
## [ ] LOD
- [ ] 

# [ ] Meeting 20260531
## [x] RQD
- [x] Import all of Lawrence's new character sprites at res://art/sprites/characters/
  - [x] Auto-bootstrapped pivots (bbox bottom-center) for the new batch; ernesto/max/occult got non-trivial pivots from transparent padding. Will need real pivots once LOD wires them in.
  - [x] Authored 21 new character JSONs (berzerker, buglers, knight, etc.) with archetype stat templates; updated 9 existing JSONs to point at the new per-char idle.png. New player chars added to RECRUIT_POOL, new enemies to enemy_spawn_pool. desert_prince/mystic/battle_chicken JSONs exist but have no ALLY/NEUTRAL spawn pool yet — TODO when that wiring lands.
  - [x] Try implementing the animations for units that have them (ernesto melee/meleelong, grasker melee, max meleeside/shootside, occult meleeside/shootside)
- [x] Pivots: Lawrence is placing the pivots at the center of his canvas - if it's 64x64, pivot is at [32,32]. If it's 128x128, pivot is at [64,64]
- [x] port Libresprite extension over to Aseprite for 2x3s
### [x] Factions:
 bandit — currently enemy
 grunt — currently enemy
 ernesto — currently player
 grasker — currently enemy
 ma'am — currently player
 napdog (napdawg) — enemy
 ogre — currently enemy
 ogre_squire — currently enemy [SHOULD BE PLAYER]
 elf_pirate — [player]
 gravity_captain — [player]
New sprites — faction needed:
 berzerker — [enemy]
 bugler_chivalric — [enemy]
 bugler_gentry — [enemy]
 desert_prince — [ally]
 desert_sniper —[player]
 flamethrower_phoenix — [enemy]
 healer_goblin — [player]
 healer_plant — [player]
 ice_archer — [enemy]
 knight — [enemy]
 mystic — [ally]
 pierre — [enemy]
 plant_cultist — [player]
 plant_urchin — [enemy]
 pyro — [enemy]
 robot — [player]
 squash — [enemy]
 thumps — [enemy]
 traveller — [enemy]
 battle_chicken — [meutral]
 max — [player]
 occult — [enemy]
## LOD
- [x] **Pivot workflow**: future .aseprite files need a slice with pivot set to the character's feet. The tag-exporter plugin already emits a JSON sidecar when it finds one; without it, we fall back to bbox-bottom which is wrong for any sprite with padding (ernesto, max, occult visibly off). One slice per .aseprite, name doesn't matter, just toggle the pivot checkbox and drag to feet.
  - **Convention (and the exporter's no-slice fallback)**: pivot at canvas center. Each character's canvas is expanded so the feet land at center — 96×96 canvas → pivot at (48, 48); 128×128 → (64, 64). Sprites authored this way get correct pivots without needing a slice.
  - **Older sprites without expanded canvases** (e.g. grunt) need to be brought into compliance: open in Aseprite, Canvas → Resize so the feet end up at center, re-export through the plugin. Don't hand-tune the sidecar — it gets overwritten on next export.
- [x] **Exporter: preserve pivot through trim**. Today [addons/aseprite_tag_exporter/context_menu.gd](../addons/aseprite_tag_exporter/context_menu.gd) skips `--trim` entirely whenever a pivot exists, because trimming shifts canvas-space pivot coords. Result: PNGs ship canvas-sized (Lawrence's expanded canvases are mostly empty padding). Better: run `--trim`, then subtract the trim offset from `pivot.x/y` in the sidecar so the pivot stays on the same pixel. Aseprite emits trim deltas via `--data` JSON output (`frames[].spriteSourceSize`), or we can diff bbox pre/post. Net effect: same on-screen pivot, smaller PNGs.

# [ ] Meeting 20260524
## RQD
 - [ ] intermission screens - interactive buttons must be obviously interactive
 - [ ] bEXP screen
 - [ ] remove "*1" from character panel on the left when all statUps are allocated
 - [ ] Give all characters at least 9 moves and 9 passives
 - [ ] add level next to enemy (and friendly?) health bars
 - [ ] RQD - keep working on intermission screens
## LOD
- [ ] Spend some time organizing your art folder with the game project
- [ ] LOD - Get me the new character sprites that fit properly on the map
 (Berserker, healers, ice archer, etc)
### [ ] LOD - options if you get bored
 - [ ] new line art and/or
 - [ ] new characters and/or
 - [ ] new jungle biome terrain (see concept art)
 - [ ] ice desert biome terrain

# [x] Meeting 20260517
## LOD
## RQD
- [x] LOD - push existing line art portraits
- [x] RQD - fix crashes in mission progression
- [x] RQD - implement line art portraits

# [ ] Meeting 20260510
- [x] RQD - 10x10 hypoesthesia icon (random crop of static_noise.png, wired in InjuryDatabase)
- [x] RQD - pull and implement the injury icons (all 16 icons wired in InjuryDatabase via icon_path; "crystallization" spelling synced)
- [x] RQD - surface InjuryData.icon_path in the unit detail panel injury 2x2 grid (icons load but aren't drawn yet — on-map indicator NOT needed; injuries belong in the detail panel only, not above the unit)
- [x] RQD - separate bandit and grunt: bandit.json created (Gentry, skirmisher stats: hi AGL/SKL, lower HP/DEF, Impetuous passive, moves: Bonk/Backstab/Feint/Sidearm/Uppercut). grunt.json repointed to grunt/idle.png. SpriteAtlasLoader path bypassed in unit.gd for atlas-less single-PNG sprites. Bandit added to battle_scene enemy_spawn_pool (2x weight, same as grunt).
- [x] RQD - implement preview beacons + animations (path_visualizer rewritten to spawn per-tile Sprite2D nodes with AtlasTexture; cascading wave plays sequence [idle, mid, dipped, mid, idle] at 125ms/frame, 500ms inter-tile stagger, 500ms inter-cycle pause; blue strip for player faction, red for enemy; no rotation. Flags deferred — will revisit if beacons aren't clear enough.)
- [x] (playtest tuning) Beacon timing constants in path_visualizer.gd — FRAME_DURATION_MS=125, TILE_DELAY_MS=500, CYCLE_PAUSE_MS=500. Stretch goal: sync to music BPM.
- [x] RQD - finalize style guide and feed to Claude (questionnaire distilled into data/design/ui-style-guide.md, referenced from CLAUDE.md, all LOD-blank items marked TBD; questionnaire kept as conversational source)
- [x] RQD - rebalance type effectiveness multipliers from 2.0/4.0 → ~1.2/1.44 (single TYPE_COEFFICIENT in type_chart.gd; JSON now stores stage strings "vulnerable"/"resist"/"immune"; vocab is defender-framed Vulnerable/Resist; type chart editor + combat preview + demos updated; old "Vulnerable" status renamed to Exposed to free the word; data/design/character-system.md doc synced)
- [x] (polish) Animated hypoesthesia icon: canvas_item shader scrolling static_noise.png UVs inside the injury slot (shaders/injury_static.gdshader + resources/injury_static.tres, applied in unit_detail_panel._set_injury_panel when injury_id == "hypoesthesia")

# [x] Meeting 20260412
- [x] RQD - have move type icons (phys/spec/supp) wired up to show Lawrence
- [x] RQD - add move type color pairings to the color demo panel - use full and half full move chips
- [x] RQD - figure out what we were using those status colors for (removed — unused, will revisit when Lawrence mocks up status tick particles)
- [x] LOD - move preview animated arrow (see the FreePixelEffect resource from the Unity project)
- [x] LOD - waypoint indicator for move preview
- [x] Go over style guide with Lawrence
- [x] Check out the colors demo
- [x] Check out the options menu - any options you can think of?
- [x] LOD - I need a bunch more icons: buffs 6x6, injuries 10x10? (Let's discuss how injuries should look, and we may discard injuries for the alpha)
- [x] Elemental Type matchup chart

# [x] Meeting 20260426
- [x] LOD - push move preview beacons small/large, red/blue
- [x] LOD - any questions on style guide?
- [x] LOD - I need a bunch more icons: buffs 6x6, injuries 10x10? (Let's discuss how injuries should look, and we may discard injuries for the alpha)
- [x] RQD - speed up unit movement by like 3x or so
- [x] RQD - attempt pixellation filter for hypoesthesia injury
- [x] RQD - what colors should buffs and injuries be in the HUD?
- [x] RQD - Aseprite plugin - eyedropper that copies hex value to clipboard


# [x] RQD Todo by 20260412
- [x] Mock up updated unit detail panel (1 buff slot + 1 debuff slot + injury 2x2 grid with 2-slot stacking)
- [x] Create test_map_02 (or a "next mission" button) so we can playtest injury persistence across missions
- [x] Add `"id"` field to character JSONs (spaceman.json, ernesto.json, maam.json) — works without it but cleaner with
- [x] Send Lawrence the buff icon request: Rallied, Fortified, Hasted, Focused, Regen (6x6, matching status_effect_icons_6x6_v2 style) + the missing Bellows icon
- [x] Discuss injury icon style with Lawrence — 6x6 matching status icons, or larger? 20 injuries to cover eventually but only need a few for alpha
- [x] Playtest buff/debuff system: toggle `testing_status_effects = true` in debug_config.gd, verify slot enforcement + pip bars + detail panel work in-game

# [ ] Week 20260510

**Goal: close the alpha game loop as a 2-mission mini-campaign.** Pick start level → prep → mission 1 → result → between-mission level-up + prep → mission 2 → result → back to start. Two missions exercises persistence, leveling-between-fights, and the squad management loop without overinvesting in content. Maps are cheap to iterate; campaign infrastructure is not.

- [x] **1. 2-mission mini-campaign skeleton.** Campaign-state singleton holding `{current_mission_index, squad, start_level}`. Start screen with start-level picker (5/20/40/60) → "Begin Campaign" → mission 1 → between-mission flow → mission 2 → end-of-campaign result. Mission content can be the existing test maps for now.
- [x] **2. Auto-leveling system.** Simulate growth rolls to target level for both player units and enemies. Used to set campaign **starting** state; subsequent levels come from actually fighting. Reuse Unity's CharacterData growth logic (`../tbt-game/Assets/Scripts/Units/CharacterData.cs`).
- [ ] **3. Squad/prep + between-mission level-up screen** (user-flagged PRIORITY). Pick squad, equip moves (~330 already in bank), equip passives, distribute stat allocation points. Same screen handles both initial prep AND between-mission level-up display (XP gained, stat-up rolls, new moves/passives unlocked).
- [ ] **4. Rebuild battle result overlay with proper routing.** Current overlay is placeholder. Mid-campaign → between-mission screen. End-of-campaign → start screen. Per-unit stats + objective/bEXP scope from [mission_objectives.md](mission_objectives.md) is V2 — V1 just needs correct routing + existing turns/units-lost/enemies-defeated.
- [ ] **5. Programmer art for 5 enemy types.** Without it every battle looks like ogre + ernesto. Lowest-effort variety win once #1–4 are working.

**Notes:**
- Item 1 is the riskiest — campaign-state persistence + scene routing is new infra. Build it stub-first (mission_index increment, route between scenes) before any UI polish.
- Item 2 lands before 3 — prep needs leveled units to render stat allocation.
- Item 3 is doing double duty (initial prep + between-mission level-up). Build initial prep first; the level-up overlay reuses most of the same widgets.
- Injury persistence across missions is already supported (per shipped buff/debuff system) — campaign mode finally exercises it.
- Defer the open todos below this section (touchscreen UX, controller tooltips, fps testing, options-menu volumes) until the loop closes — they don't gate alpha.
- Lawrence-blocked items can't be parallelized; if blocked on art, skip ahead to the next code item.


# [ ] Art Needed (Lawrence)
- [ ] A 10x10 "Swap" icon (like 🔁, kinda, straighter arrows)
- [ ] 
## [ ] Range Icons
- [ ] Icon for range: 1
- [ ] Icon for range: 2
- [ ] Icon for range: 1-2
- [ ] Icon for range: 2-3
- [ ] Icon for range: 3+
- [ ] ANY OTHER ICONS WE NEED HERE?

# [ ] BUGZ/Issues
- [x] Zooming in and mousing around outside the window still changes the terrain preview
- [x] unit preview panel and terrain preview panel don't move to the left side of the screen (and presumably vice versa) when the cursor is on that side (no cursor in touchscreen mode but it's clearly still a problem)
- [ ] (see above) we need to test the above in touchscreen mode - I'm assuming it's still a problem (working great in M&K). 
- [x] I can't select the unit I want! He's clearly standing on the mountain but it doesn't detect the unit there??
- [ ] units have the wrong portraits.
- [x] Enemies can move on top of my units
- [x] Injuries (not exactly a bug, just a problem): if you're fighting a tough enemy, e.g. a boss, and you lose a bunch of units, they all end up taking the same injury. Not sure if this is worth fixing. We might just give bosses like that a passive that prevents using the same move repeatedly.
- [x] Tall units have their health bar hidden if they're in the top row
- [x] It's kinda hard to see the enemy unit detail panel - some combination of clicking repeatedly seems to do it but it's unintuitive and often 
- [x] Hypoesthesia Effect - NN scaling is yielding boxes which are 1x1, 2x1, 1x2 and 2x2 - what's causing this?
- [x] The Ogre killed Ernesto and he got grayed out but didn't die. It was also the first time I'd seen a counterattack from a unit, which is interesting. We need to nerf the Ogre's athleticism but I'm leaving it for now to reproduce the bug.
- [x] When selecting a target to attack, if you mouse over an ineligible target, it still displays the combat preview panel. It should display nothing.
- [x] Units display class "Spaceman lv. 1" in the unit detail panel - should display their real class and level. Root cause: `_find_label_in_row(class_row)` assumed a `HBoxContainer/MarginContainer/Label` shape (matches the externally-instanced UnitNameAndTypes row), but ClassNameAndLevel is a plain HBoxContainer with `MarginContainer2/GlowLabel` directly. Lookup returned null, the `if _class_label:` guard skipped silently, and the scene's editor placeholder "SPACEMAN Lv.1" was left on screen for every unit. Switched the lookup to `class_row.find_child("GlowLabel", true, false)` which doesn't depend on the wrapper structure.
- [x] In the victory screen, the terrain preview panel still displays. Should be disabled on a victory/defeat state. (ui_manager.show_battle_result now does belt-and-suspenders teardown of all map panels in addition to the state-changed handler)
- [x] Unit movement range seems to be doubled. Root cause: grid_manager.MOVEMENT_SCALE doubled `max_movement_range` but per-tile costs were left raw (1 for Grass, ceili(0.5)=1 for Road). Fix: route all four per-tile cost lookups through new `_scaled_tile_cost()` helper. Side benefit: Road's 0.5 penalty now actually halves cost (was rounding up to 1).
- [ ] losing at level 1 still lets you proceed to level 2. Maybe we want this? Let's discuss.
- [x] the enemy's move selection isn't clear during the enemy phase (two signals added in [enemy_ai.gd](../scripts/combat/enemy_ai.gd): (a) brief 1.0→1.15→1.0 sprite-scale pulse on the active enemy at start of its turn — fits inside think_delay so AI doesn't visibly stall; (b) move-name callout floats above the attacker right before the swing, colored by move's elemental type via get_move_chip_foreground. attack_delay gives the player a beat to read it. Reuses damage_popup infrastructure via new DamagePopup.initialize_callout / Unit.spawn_text_callout.)
- [ ] the ogre is still absurdly overpowered
- [ ] Ernesto's backhand move is weirdly powerful
- [x] moves don't seem to actually make any accuracy checks. I have never seen a move miss in my weeks of testing. **Wired 2026-06-03**: RD-adapted formula `clamp(0, 100, move.accuracy + 1.5×skill − 1.5×agility + passive_bonuses)` lives in [DamageCalculator.hit_chance_pct](../scripts/combat/damage_calculator.gd). Default `accuracy = 90` on Move; configurable per move in JSON. Combat rolls in [unit._execute_single_hit](../scripts/units/unit.gd) — miss plays the swing + spawns a "MISS" callout, no damage/flash/status. Passives wired: **Reliable** (+50 attacker accuracy) and **Low Profile** (+25 defender avoid against ranged moves). Stubs in place for Impulsive / Flippant / Zone Control. Combat preview + detail panel now read real hit% instead of hardcoded 100%.
- [ ] Move distribution in the demo is wonky. Characters are getting moves which are way too powerful at level 5. This is contributing to the ogre problem
- [x] If a unit has no corresponding portrait, let's use default_portrait.png (lands as last-resort fallback in character_portrait._resolve — order is portrait_path → sprite-crop head → default_portrait.png. Recruit picker now always renders a portrait slot too, so sprite-less characters still show something.)
- [ ] Grunt sprite has its pivot set way too low
- [ ] Something is fucky about damage calculation in general - it doesn't feel right
- [ ] Design: we need healers.
- [x] The player can be offered multiple of the same character if they reduce the pool to <3 (closed as no-repro 2026-06-02. Code path is sound: `RECRUIT_POOL` in [start_screen.gd](../scripts/ui/start_screen.gd) has no duplicate entries, and [campaign_manager._pick_recruit_candidates](../scripts/managers/campaign_manager.gd) filters against `_recruited_paths` before shuffling, then picks `mini(count, available.size())` unique entries. Algorithmically can't dupe. Reopen if it actually happens with concrete repro.)
- [ ] when an attack is more west/east than north/south, display the west/east animation (but make it easy to toggle this change off)
- [x] The different types of Buglers don't need their type explicitly in their name - their typing tells me this (renamed bugler_chivalric and bugler_gentry character names to just "Bugler")
- [x] Passives "Maximum" and "Stellar" should have very narrow distribution - just Max at this point. (stripped from all 29 character JSONs except spaceman.json — both had been copy-pasted from a template into every character's basePoolPassives)
- [x] When choosing a new recruit in the intermission screen, the portraits should display fullres line art if available (see unit detail panel for how this works) with a fallback to the sprites (latter bit is working). Root cause: bind_to_texture_rect was already promoting to HD identically across all panels, but most recruit-pool JSONs had no `lineartPath`/`lineartAtlases` set, so the HD path returned null and fell back to the pixel pipeline. Also: elf_pirate had a hi-res image (921×921) stored under `portraitPath` and was being NN-downscaled inside HUDViewport. Wired lineartPath/lineartAtlases for grasker, gravity_captain, ogre_squire, ogre, and elf_pirate. Remaining recruit-pool characters (desert_sniper, healer_*, plant_cultist, robot) have no line art assets yet — Lawrence-blocked.
- [ ] **Distortion shader toggle (HD portraits)**: VHS-tracking distortion (`hd_portrait_tracking.tres`) is applied to every HD line-art portrait unconditionally. Add a user-facing options toggle. The infrastructure already exists — `DebugConfig.debug_portrait_effects_disabled` flips it at runtime via [HDPortraitSlot._apply_debug_effects_state](../scripts/ui/hd_portrait_slot.gd) — needs an options-menu checkbox bound to the same flag (or a new persisted setting). See [project_shader_quality_setting memory](../../.claude/projects/-home-mjsbdlk-Documents-Projects-tbt-game-godot/memory/project_shader_quality_setting.md) for why this was deferred (accessibility-options pass), but it keeps coming up so worth its own item.
- [ ] bEXP GUI needs a complete rework - just prompt me to get this started.
- [x] Damage calculation feels... off. Let's audit the formulae and find out why. **Audit done 2026-06-02** ([damage-audit-2026-06-02.md](../data/design/damage-audit-2026-06-02.md)) — three structural issues with the old `(power × atk ÷ 5) - def` formula explained the symptoms. **RD damage formula ported 2026-06-03**: damage is now `(atk + might) - def`. Multi-hit reverted to original 2×/3×/4× ratio after playtest — kept intentionally as a "Brave weapon"-style power spike. Min-damage stays at 1; move base_powers untouched (deferred to playtest — moves currently feel a bit too strong but the scaling itself feels right).
- [ ] Capricious ability needs to apply to counterattacks too - it should equip a different move after every combat. (Not between counterattacks if it couterattacks more than once.) This means that it will use different moves if attacked repeatedly.
- [x] First aid - if used on self, in the combat preview panel, it shows as being used on a non-existent target. Should apply to self. Relatedly, if used on an ally, the target's health pips should be the color of that unit's faction. Currently they're red like the enemy, but if it's a friendly they should display as blue. **Fixed 2026-06-03**: self-cast now collapses the bottom half entirely (defender section + bottom HP pip hidden); the heal projection rides on the top bar instead. HP pip colors are applied dynamically per faction via a new `_apply_pip_faction_color` helper in [combat_preview_panel.gd](../scripts/ui/panels/combat_preview_panel.gd) (player/ally/neutral/enemy palette constants). The scene's static red-on-bottom default no longer leaks through for ally heals.
- [ ] Pathing is broken if you draw a path that crosses itself. We may need to actually implement those flag markers. (LMK if that's too ambiguous - we flagged those as a "implement if necessary" earlier. I think it's probably necessary.)
- [ ] Ghost ability doesn't work (still routes around enemy units needlessly)
- [ ] Movement range seems like it has an "off by one" error for the move range preview - it says some tiles at the edge of the movement range are reachable, but when I click them I'm not allowed to move. I'm assuming this is because of a disagreement in how rounding works between the movement flood-fill algo and the preview. Not certain but let's start there.
- [ ] Most moves need their base accuracy lowered
- [ ] 

# TEST THESE MECHANICS
- [ ] STAB + visual feedback
- [ ] Unit sprites should not capture mousedown events (you click tiles, not units)

# Todo
- [x] Merge Lawrence's branch
- [x] RQD - orthogonal shader portrait border
- [x] Status icons are stretched in the unit detail panel
- [x] Start adding tooltips
- [x] We forgot to add the injury system!
- [x] Style the action menu panel
- [x] Style the combat preview panel
- [x] Phase transition
- [x] Terrain sprites (replace colored placeholders with real art)
- [x] Unit sprites (replace colored rectangles)
- [x] Damage popups & effectiveness feedback styling
  - [x] Hitlag (both units freeze on impact, scaled by damage, 0.25s ceiling)
  - [x] Hit flash (white flash on defender after hitlag, duration scaled by damage)
  - [x] Screenshake (kicks in as hitlag releases, intensity scaled by damage)
- [x] Status effect indicators on units (icons + turn countdown)
- [x] UI style guide doc (data/design/ui-style-guide.md, referenced from CLAUDE.md)
- [x] Speed up the overlay fading out once the text is off the screen
- [ ] battle result overlays (scope brainstormed; see [mission_objectives.md](mission_objectives.md) for the objective/bEXP model this hooks into)
- [x] Clicking on an enemy unit brings up the unit preview panel for that unit (good) but then to make it go away you need to click on a friendly unit (bad) - tapping anywhere on the map should make it go away.
- [?] Cancel/confirm input hints
- [x] Add a "pause" menu (it's turn-based, the game is always paused) and Options menu. What else goes in the pause menu? How is it accessed on touchscreen?
- [x] Options menu
- [x] Add a toggle for "nearest neighbor scaling" vs. "only allow integer scaled zoom levels" (and come up with a concise way of saying that, like zoom mode: nearest neighbor/integer)
- [ ] Tooltips: controller focus-navigation mode (Dark Souls pattern — hotkey grabs focus on tooltip-bearing icons, stick navigates, focus_entered shows themed popup, B/Back releases). Click-to-show already works on M&K and touch via TapTooltip; controller is the remaining gap.
- [ ] Touchscreen UX: preview panels occlude tiles the user might want to tap. Decide between (a) don't show preview panel during action planning — separate "select for action" from "inspect", (b) auto-pan/zoom camera to keep the unit's eligible range visible beside the panel, (c) long-press to peek-through, (d) panel fades + becomes tap-transparent after a moment
  - **Test device plan (real touch required — desktop `emulate_touch_from_mouse` is single-finger only, can't emulate multi-touch or pressure):**
    - **Primary: GrapheneOS phone** — daily-driver for touch iteration. Enable Developer Options + USB debugging, use Godot's One-Click Deploy (Project → Install Android Build Template once, then phone icon in toolbar). GrapheneOS has no Play Protect so dev-signed APKs install without nags; actually *easier* than stock Android.
    - **Secondary: old Android tablet** — larger screen closer to Steam Deck aspect ratio; useful for layout/form-factor validation. Any Android 6+ works.
    - **Final: Steam Deck** — real target hardware. Remote debug via `--remote-debug tcp://<dev-ip>:6007` or install Godot editor directly on Deck in desktop mode. Bring in once touch UX stabilizes on phone.
    - Skip iPhone — needs Mac + Xcode + Apple Dev account, and gives nothing Android can't for touch UX.
- [ ] Test game running at 90, 120, 144, 240 fps
- [ ] Add lock_framerate option with a slider and max 1000 Hz (I guess, I'm assuming it won't reach anywhere near that)
- [ ] PRIORITY: Create in-between mission squad management screen.
- [x] programmer art for 5 enemy types
- [ ] When controlling using M+K it would be nice if the menus had hotkeys. Probably 1-4 for moves, then QERFZXCV for non-moves? Have them disappear if we detect controller or touchscreen input
- [ ] Autosave on every turn?
- [ ] Add support for icons in text boxes - need full elementalType, boost, affliction, injury icon sets (anything else?)
- [ ] Tap/click feedback particle — one-shot particle effect at every input position (tap, click, controller A-button), fires whether or not the input hit something interactible. Kills the "dead input" feeling. FE Heroes-style; single GPUParticles2D or shader-driven ring at world/screen position.
- [ ] Have Ma'am start at lv 11, Max at lv 1, Ernesto at lv 5 (we'll need to playtest all of that of course)
- [ ] Something I'm noticing is that copying the 2x/4x/0.5x/0.25x system from Pokémon isn't working great in a TBS. Super effective moves are just devastating. We might try using a different multiplier: 2/3 for ineffective and 3/2 for super effective. I think this would mean 4/9x for double resisted moves and 2.25x for double weakness. We should do this: pick a coefficient in one place and change it as needed.
- [ ] It would be useful to see units' typing and level with the additional info HUD (the one that shows their active boost/afflictions)
- [ ] Unit "I'm injured I gotta fall back" monologue on injury the first time it happens
- [ ] Create a template for a checklist for each character which includes everything we need for each character - 92x92 portrait, 32x32 portrait, idle animation, attack_physical_adjacent_north, attack_special_ranged_east, growth rates, base stats, just everything. Then we need to develop a file hierarchy.
- [ ] Did we add STAB mechanics? Should be a 1.2x multiplier
- [ ] Rework detail panel to use the move styleboxes we used in the preview panel
- [ ] It's unclear to the user what's clickable in the UI and what's not - we need to apply some kind of visual design that makes it clear what is and what isn't interactible.
- [ ] The move preview doesn't animate properly when the unit retreads its path
- [ ] **ALLY/NEUTRAL faction spawn wiring** (post-alpha — alpha doesn't need allies or neutrals). [data/characters/desert_prince.json](../data/characters/desert_prince.json), [mystic.json](../data/characters/mystic.json), and [battle_chicken.json](../data/characters/battle_chicken.json) exist but no infrastructure spawns them. Currently `RECRUIT_POOL` is player-only and `enemy_spawn_pool` is enemy-only — there's no equivalent for `Enums.UnitFaction.ALLY` or `NEUTRAL`. Needs design first: (a) where allies come from — mission-scripted, pooled like recruits, or hand-placed in the map .tscn? (b) neutral behavior — wandering / hostile-to-all / passive decoration? (c) authoring surface — .tscn placement vs programmatic spawn. Then plumb through `TurnManager` and AI so non-PLAYER/non-ENEMY factions get turns and decisions.
- [ ] On controller/M&K, the preview path should display while hovering the next node in the planned path.
- [ ] Bringing up the unit preview panel on an enemy should display their attack range on the map (pause before implementing this - should this be on a different hotkey?)
- [ ] 

# Stretch Goals
- [ ] Sync beacons to music BPM

---

## Buff/Debuff System (shipped 2026-04-09)
- [x] Unified stack/percentage model — every effect uses stacks (no separate `duration`); stat effects are % of unmodified stat
- [x] 1 buff slot + 1 debuff slot per unit, with same-category immunity (and `replaces` override flag on moves)
- [x] 5 new buffs added: Rallied (+STR), Fortified (+DEF), Hasted (+AGL), Focused (+SKL), Regen (HoT)
- [x] 6 weak moves got self-target buff riders (Compressed Air, Uppercut, Feint, Sidearm, Laser, March)
- [x] 4 dedicated Support moves added: Fortify, Bloom, Focus, Battle Cry
- [x] UI updated: detail panel, in-world indicator, preview panel all show 1 buff + 1 debuff
- [ ] **Icon requests pending from Lawrence**: Rallied, Fortified, Hasted, Focused, Regen, plus the long-missing Bellows
- [ ] Combat preview: indicate buffs/debuffs in play (deferred — combat numbers will pull from effective stats automatically once the panel reads `character_data.strength` etc.)
- [ ] Ally-target support moves (e.g. Rally) — combat selection doesn't yet support ally-target; defer until needed

# Options Menu
- [ ] Master Volume - default 0.8
- [ ] SFX Volume - default 0.8
- [ ] Music Volume - default 0.8

---

## Art Pipeline
- [ ] Figure out how normal maps work with the Aseprite -> Aseprite Wizard -> Godot workflow
- [ ] Understand how timing on frames works within the Aseprite -> Aseprite Wizard -> Godot workflow

## Misc
- [ ] Optimize controls for touchscreen

### MoveType
+ [x] Physical (probably just repurpose that fist)
+ [x] Special (Pokémon uses a ripple for this, ours just needs to distill 'nonphysical attack')
+ [x] Support - a move that helps your team, maybe just a green plus or something?

### Terrain Attributes
+ [x] Movement cost — boot/footprint
+ [x] Defense modifier — shield
+ [x] Avoid modifier — dodging figure
+ [x] Attack multiplier — sword / crosshair

### Health bar background glow
