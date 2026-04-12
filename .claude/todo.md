## For Lawrence (Art!)
- [ ] 

# Meeting 20260412
- [x] RQD - have move type icons (phys/spec/supp) wired up to show Lawrence
- [x] RQD - add move type color pairings to the color demo panel - use full and half full move chips
- [x] RQD - figure out what we were using those status colors for (removed — unused, will revisit when Lawrence mocks up status tick particles)
- [x] LOD - move preview animated arrow (see the FreePixelEffect resource from the Unity project)
- [x] LOD - waypoint indicator for move preview
- [ ] Go over style guide with Lawrence
- [x] Check out the colors demo
- [ ] Check out the options menu - any options you can think of?
- [ ] LOD - I need a bunch more icons: buffs 6x6, injuries 10x10? (Let's discuss how injuries should look, and we may discard injuries for the alpha)

# Meeting 20260419
- [ ] LOD - push move preview beacons small/large, red/blue
- [ ] RQD - speed up unit movement by like 3x or so
- [ ] 

# RQD Todo by 20260412
- [ ] Mock up updated unit detail panel (1 buff slot + 1 debuff slot + injury 2x2 grid with 2-slot stacking)
- [ ] Create test_map_02 (or a "next mission" button) so we can playtest injury persistence across missions
- [ ] Add `"id"` field to character JSONs (spaceman.json, ernesto.json, maam.json) — works without it but cleaner with
- [ ] Send Lawrence the buff icon request: Rallied, Fortified, Hasted, Focused, Regen (6x6, matching status_effect_icons_6x6_v2 style) + the missing Bellows icon
- [ ] Discuss injury icon style with Lawrence — 6x6 matching status icons, or larger? 20 injuries to cover eventually but only need a few for alpha
- [ ] Playtest buff/debuff system: toggle `testing_status_effects = true` in debug_config.gd, verify slot enforcement + pip bars + detail panel work in-game

# Todo
- [x] Merge Lawrence's branch
- [x] RQD - orthogonal shader portrait border
- [x] Status icons are stretched in the unit detail panel
- [x] Start adding tooltips
- [ ] We forgot to add the injury system!
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
- [ ] UI style guide doc
- [x] Speed up the overlay fading out once the text is off the screen
- [ ] battle result overlays
- [x] Clicking on an enemy unit brings up the unit preview panel for that unit (good) but then to make it go away you need to click on a friendly unit (bad) - tapping anywhere on the map should make it go away.
- [ ] Cancel/confirm input hints
- [x] Add a "pause" menu (it's turn-based, the game is always paused) and Options menu. What else goes in the pause menu? How is it accessed on touchscreen?
- [ ] Options menu
- [ ] Add a toggle for "nearest neighbor scaling" vs. "only allow integer scaled zoom levels" (and come up with a concise way of saying that, like zoom mode: nearest neighbor/integer)
- [ ] Add support for icons in text boxes
- [ ] Add tooltip mode hotkey
- [ ] Make sure tooltip mode hotkey does not disrupt the touchscreen flow

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
