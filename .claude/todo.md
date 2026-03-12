# Todo

## Art Pipeline
- [ ] Figure out how normal maps work with the Aseprite -> Aseprite Wizard -> Godot workflow
- [ ] Understand how timing on frames works within the Aseprite -> Aseprite Wizard -> Godot workflow
- [x] The palette ColorPicker currently doesn't support alpha - must fix

## Misc
- [x] Color code the map health bars according to faction
- [x] Fix the color and alpha values of the ColorRect in the combat preview panel
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

### Status Effect Icons
**Phase 1 — mockup first**: Design one icon (pick the one which requires the most detail first) displayed next to the health bar above a unit.
Units are 32–48px tall; the health bar is added programmatically and has no fixed size.
This mockup establishes icon size and layout.

**Phase 2 — full set** (once size is confirmed): One icon per status effect:
  BLEED, BUGLE, BURN, CHAIN_LIGHTNING, CHALLENGED, CRITICAL,
  FREEZE, GRAVITY, POISON, ROOTED, SHOCKED, SUBVERSION, VOID, VULNERABLE, WITHER
- Match the elemental type theme where applicable (BURN=fire, FREEZE=cold, SHOCKED=electric, etc.)
- Save to: `art/sprites/ui/status_icons/` using snake_case filenames (e.g. `bleed.png`, `chain_lightning.png`)

