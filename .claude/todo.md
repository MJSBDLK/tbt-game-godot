# Todo

## [x] UI State Machine
- Replace ad-hoc panel visibility management with a proper state machine
- Define transitions: MAP → ACTION_MENU → UNIT_DETAIL → ACTION_MENU, MAP → UNIT_DETAIL → MAP, etc.
- Each state knows which panels are visible and what "back" means
- Eliminates "opened from where?" tracking and prevents spaghetti as more panels are added

## [x] RQD - Test the Importality workflow with the turn transition screens

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

### MoveTYpe
+ [ ] Physical (probably just repurpose that fist)
+ [ ] Special (Pokémon uses a ripple for this, ours just needs to distill 'nonphysical attack')
+ [ ] Support - a move that helps your team, maybe just a green plus or something?

### Status Effect Icons
**Phase 1 — mockup first**: Design one icon (pick the one which requires the most detail first) displayed next to the health bar above a unit.
Units are 32–48px tall; the health bar is added programmatically and has no fixed size.
This mockup establishes icon size and layout.

**Phase 2 — full set** (once size is confirmed): One icon per status effect:
  BLEED, BUGLE, BURN, CHAIN_LIGHTNING, CHALLENGED, CRITICAL,
  FREEZE, GRAVITY, POISON, ROOTED, SHOCKED, SUBVERSION, VOID, VULNERABLE, WITHER
- Match the elemental type theme where applicable (BURN=fire, FREEZE=cold, SHOCKED=electric, etc.)
- Save to: `art/sprites/ui/status_icons/` using snake_case filenames (e.g. `bleed.png`, `chain_lightning.png`)

Status Effect Icon Descriptions — Visual Design Brief

These are status conditions applied to units in combat. Each icon will be small (likely 16x16 or similar) and needs to read clearly at a glance. Where an effect is tied to an elemental type, I've noted the associated colour/theme.

BLEED — Physical damage over time (DoT). The unit is wounded and losing health each turn. Think open wound, dripping blood. No specific element — raw physical trauma. Colour: red.

BUGLE — A Heraldic-type debuff. The unit has been "called out" by a herald's horn, making them take extra damage from Heraldic moves. Think a brass bugle or war horn — regal, medieval-military. Colour: heraldic gold/brass.

BURN — Fire-type DoT. The unit is on fire, losing health and dealing reduced attack damage. Stacks can spread fire. Classic flames. Colour: orange/fire.

CHAIN LIGHTNING — Electric-type. The initial hit arcs to adjacent units at half damage, then to the next ring at quarter damage, cascading until the damage is less than 1. Think a branching bolt of lightning jumping between targets. Colour: electric yellow/blue-white.

CHALLENGED — Chivalric-type. A taunt/aggro effect — the challenger forces enemies to focus on them and prevents targeting weaker allies nearby. Think a thrown gauntlet, a knight's challenge, or a crossed-swords duel symbol. Colour: chivalric steel/silver-blue.

CRITICAL — Not a persistent status, more of a flag on a single attack. This hit deals double damage. Think a bullseye, impact star, or exclamation mark. Needs to feel punchy and immediate. Colour: bright red or white-hot.

FREEZE — Cold-type. Fully immobilized — the unit can't move or act. Encased in ice. Classic ice crystal / snowflake / frozen-over silhouette. Colour: icy blue/cyan.

GRAVITY — Gravity-type. Weighs the unit down, reducing agility (movement speed and dodge). Think a heavy downward force — a downward arrow, a crushing weight, a black-purple gravitational distortion. Colour: deep purple/violet.

POISON — Usually plant-type DoT. Ticking health loss each turn, no stat reduction. Think dripping venom, a skull-and-crossbones, or a bubbling toxic droplet. Colour: sickly green/purple.

ROOTED — Plant (sometimes Gravity) type. The unit can't move but can still act (attack, use abilities). Vines or roots growing up from the ground, pinning feet in place. Colour: earthy green/brown.

SHOCKED — Electric-type. Disrupted nervous system — reduced accuracy and a chance to completely skip their turn (stunned). Think sparks, a jittery/crackling outline, or a dazed star with a lightning motif. Colour: electric yellow.

SUBVERSION — Gentry or Occult-type. A sinister debuff that lowers the target's defense by a third and nearby allies' defense by a quarter. Also nullifies bond bonuses (support buffs from adjacent allies). Think corruption, shadowy tendrils, a cracked shield, or an eye-of-betrayal motif. Colour: dark magenta/shadow purple.

VOID — Void-type. Locks a random move (or passive) per stack, up to 3 stacks. The unit's abilities are being erased or suppressed. Think emptiness, a black hole, redacted/crossed-out symbols, or a glitching distortion. Colour: black with desaturated yellow/green.

VULNERABLE — No specific element. A general debuff that increases all incoming damage. Think a cracked/broken heart, broken armour, or an exposed weak point. Colour: warm orange-red (danger without being elemental). - look up "Slay the Spire vulnerable icon" - that's what I have in mind.

WITHER — Occult-adjacent. A broad stat reduction — the unit is weakened across the board. Think decay, a wilting leaf, crumbling/eroding form, or an hourglass draining away. Colour: ashen grey/dull brown, maybe?