# Meeting 20260329
- [ ] Go over style guide with Lawrence
- [ ] Any options you can think of?

## For Lawrence (Art!)
- [ ] move preview animated arrow (see the FreePixelEffect resource from the Unity project)
- [ ] waypoint indicator for move preview

# Todo
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
+ [ ] Movement cost — boot/footprint
+ [ ] Defense modifier — shield
+ [ ] Avoid modifier — dodging figure
+ [ ] Attack multiplier — sword / crosshair

### Health bar background glow
