## For Lawrence (Art!)
- [ ] 

# Meeting 20260412
- [x] RQD - have move type icons (phys/spec/supp) wired up to show Lawrence
- [x] RQD - add move type color pairings to the color demo panel - use full and half full move chips
- [x] RQD - figure out what we were using those status colors for (removed — unused, will revisit when Lawrence mocks up status tick particles)
- [ ] 
- [ ] LOD - move preview animated arrow (see the FreePixelEffect resource from the Unity project)
- [ ] LOD - waypoint indicator for move preview
- [ ] Go over style guide with Lawrence
- [x] Check out the colors demo
- [ ] Check out the options menu - any options you can think of?
- [ ] LOD - I need a bunch more icons: buffs 6x6, injuries 10x10? (Let's discuss how injuries should look, and we may discard injuries for the alpha)

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

## Buff/Debuff System
Split the single `active_status_effects` array into separate buff/debuff systems with independent caps (max 4 each).

### Data Layer
- [ ] Add `EffectCategory` enum to enums.gd: `BUFF, DEBUFF`
- [ ] Add `category: Enums.EffectCategory` field to `StatusEffectData`
- [ ] Tag each existing config in `StatusEffectData.get_default_configs()`:
  - DEBUFF: BLEED, BURN, BUGLE, CHAIN_LIGHTNING, CHALLENGED, FREEZE, GRAVITY, POISON, ROOTED, SHOCKED, SUBVERSION, VOID, VULNERABLE, WITHER
  - BUFF: BELLOWS, CRITICAL
- [ ] Add `category` field to `StatusEffect` runtime class (copied from config on creation)

### Unit Storage
- [ ] Add `active_buffs: Array[StatusEffect]` to Unit (alongside existing `active_status_effects`)
- [ ] Rename `active_status_effects` → `active_debuffs` (grep + replace across codebase)
- [ ] Both arrays capped at 4

### StatusEffectSystem Changes
- [ ] `apply_status_effect_by_name()` — route to correct array based on config category
- [ ] Cap enforcement: when 5th buff/debuff tries to apply, decide behavior (reject? replace oldest?)
  - **Decision needed**: overflow policy — ask during implementation
- [ ] `process_turn_start_effects()` — iterate both arrays
- [ ] `_recalculate_stat_modifiers()` — iterate both arrays
- [ ] `can_unit_move()` / `can_unit_act()` — only checks debuffs (optimization, but keeps it correct)
- [ ] `remove_status_effect()` / `clear_all_effects()` — handle both arrays
- [ ] `is_move_locked()` — debuffs only (VOID is a debuff)
- [ ] `get_effect_stacks()` — check correct array based on effect name → config category
- [ ] `check_passive_triggers_on_hit()` — applies to buff array (BELLOWS is a buff)

### DamageCalculator
- [ ] `calculate_damage()` BELLOWS lookup — no change needed (already queries by effect name via `get_effect_stacks`)

### UI
- [ ] Status HUD on units: show buff icons separately from debuff icons (left/right or color-coded)
- [ ] Unit detail / character sheet panels: separate buff and debuff sections
- [ ] Combat preview: indicate if buffs/debuffs are in play

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
