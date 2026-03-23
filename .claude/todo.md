# Todo
- [ ] Style the action menu panel
- [x] Style the combat preview panel
- [x] Phase transition
- [ ] battle result overlays
- [ ] Terrain sprites (replace colored placeholders with real art)
- [ ] Unit sprites (replace colored rectangles)
- [ ] Damage popups & effectiveness feedback styling
- [ ] Status effect indicators on units (icons + turn countdown)
- [ ] Cancel/confirm input hints
- [ ] UI style guide doc


## Art Pipeline
- [ ] Figure out how normal maps work with the Aseprite -> Aseprite Wizard -> Godot workflow
- [ ] Understand how timing on frames works within the Aseprite -> Aseprite Wizard -> Godot workflow

## Misc
- [ ] Optimize controls for touchscreen

## For Lawrence (Art!)

All art targets 640x360 reference resolution
Panel background: #302d27 @ 85% opacity. See `art/reference/combat_preview_panel_draft.png` for style reference.

### Phase Transition Overlay
- Full-screen banner that slides in when a new phase starts
- Two variants: **Player Phase** (blue, `#4c8cbb`) and **Enemy Phase** (red, matching enemy faction color)
- Text reads "PLAYER PHASE" / "ENEMY PHASE" in large pixel font
- Save to: `art/sprites/ui/overlays/phase_transition_player.png` and `phase_transition_enemy.png`
- Suggested size: 360×40px banner (centered vertically), or full 640×360 with dark vignette

### Battle Result Overlay
- Full 640×360 screen
- Two variants: **Victory** and **Defeat**
- Should have room for stat readout (turns taken, units lost, enemies defeated) — see `scenes/ui/overlays/battle_result_overlay.tscn` for text node layout
- Save to: `art/sprites/ui/overlays/battle_result_victory.png` and `battle_result_defeat.png`

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
