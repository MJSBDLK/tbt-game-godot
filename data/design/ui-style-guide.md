# UI Style Guide

Source of truth for the visual language of TBT Game. Decisions here override defaults
elsewhere.

Status labels:
- **LOCK** — fixed unless the user explicitly reopens it.
- **NEEDS REVIEW** — Lawrence hasn't formed an opinion yet because he needs to see the
  thing in context. The way to unblock is to put a build/mockup in front of him, not
  to brainstorm more options. Don't paralyze on these — pick a reasonable default,
  ship it, surface it for review.
- **TBD** — actually undecided in principle; flag with the user before designing around it.

Distilled from `ui-style-guide-questionnaire.md` (Lawrence + RQD answers, 2026-04 → 2026-05).
The questionnaire stays in the repo as the conversational source; this doc is the rule
sheet.

---

## 1. Resolution & Scaling

- Reference resolution: **640×360**, integer scaling only (2x, 3x, 4x).
- Layout: 140px left panel / 360px center / 140px right panel.
- Steam Deck is the primary handheld target.
- No fractional pixel positioning anywhere in gameplay UI.
- **Exceptions**:
  - High-res portraits render at native resolution and require filtering (probably
    bilinear; other spatial scalers under evaluation).
  - User-facing zoom mode toggle (`integer` vs `nearest neighbor`) is planned.

---

## 2. Color Palette

Use `GameColorPalette` (named families × 11 shades each). The palette is also browsable
via the colors demo scene (F6).

### General rules
- **Always reach for palette colors.** Never hardcode hex values in scripts/scenes.
  If a needed shade doesn't exist, add it to the palette rather than inlining it.
- **Reserved / avoid**: any auto-named family after `Eggplant` (e.g. "GPL Ramp 22").
  `Hay` is named but unused — leave it alone for now.
- Both Lawrence and RQD must be using the named-palette version; if a teammate sees
  raw "GPL Ramp NN" names, they're on the wrong palette file.

### Faction colors

| Faction | Family       |
|---------|--------------|
| Player  | Azure        |
| Enemy   | Red          |
| Neutral | Teal / Green |
| Ally    | Yellow Orange |

### Background & panels
- Default panel bg: `#302d27` @ 85% opacity (`HUD_PANEL_BACKGROUND`).
- All HUD panels (unit preview, terrain preview, combat preview, action menu) use the
  same bg unless explicitly overridden.

---

## 3. Typography

All text in HUD panels uses `GlowLabel` (custom Label with `glow_color`).

### Color pairings
| Use                  | Text                         | Glow                          |
|----------------------|------------------------------|-------------------------------|
| Primary text         | Azure 9 (`#dbf3ff`)          | Azure 5 (`#4c8cbb`)           |
| Secondary text       | YellowOrange 8               | Magenta 4                     |
| Success / buffs      | Green 6                      | Green 3                       |
| Danger / debuffs     | Red 5                        | Red 2                         |
| Status text          | YellowOrange 7 (`#f5cd65`)   | Red 4 (`#8e2518`)             |

Status-specific accents (current set; see §4 for the full per-effect rule):
- Burn = Orange 6 `#c98d47`
- Poison = Purple 6 `#8772ab`
- Buff (generic) = Blue 6 `#6d74a5`
- Debuff (generic) = Magenta 5 `#9e5d9f`
- Status icon background (default): `#40230a`

**NEEDS REVIEW** — pairings aren't finalized. Lawrence will iterate once he sees them
in context.

### Primary vs secondary
No hard rule, but the convention is: **primary** for names/titles/headers; **secondary**
for the supporting info underneath.

### Font sizes
- **Default UI text size: 8px.** Use 8 unless there's a reason not to.
- Hard-floor: 8. In a pinch, text remains legible down to ~5px — use that only when
  squeezed.

### Where to use GlowLabel
**Every label inside a panel is a GlowLabel.** Plain `Label` is reserved for
out-of-panel debug/devtools.

---

## 4. Panel Components

### Move chips
- `ColorRect` with fill shader (`fill_percent`, `fill_color`, `empty_color`).
- Element-typed colors (Fire = Orange, Electric = Yellow, etc.).
- Depleted moves grey out.
- **TBD**: hover/click feedback. Goal — quick shimmer + animated shift on hover, plus a
  click feedback effect. Not yet built.

### Status chips (unit preview panel)
- `ColorRect` + 6×6 icon + abbreviated name + turns-remaining label.
- Up to 4 chips in a `GridContainer`.
- **Per-effect color rule**: each of the 15 status effects gets its own color, generally
  tied to the inflicting element (e.g. Freeze = Cyan, Shocked = Yellow, Void = Eggplant).
  Do **not** group all DoTs / all CC under one shared color.
- **Chip background varies by status type**: a very dark version of the status color, or
  a custom secondary color. The current uniform `#40230a` background is a placeholder.
- Status effects to color (full list, for reference):
  - DoT/damage: Burn, Poison, Bleed, Chain Lightning
  - Movement impair: Rooted, Freeze, Gravity
  - Debuff/weaken: Vulnerable, Wither, Subversion, Shocked
  - Aggro/taunt: Challenged, Bugle
  - Buff: Critical
  - Lockout: Void

### Passive chips
- Same shape as status chips: `ColorRect` + abbreviated name.
- **No icon, no turn timer.** Different color set from status chips.

### On-map status icons (above units)
- 6×6 px icons, max 4 per unit, 2px gap.
- 4×1 pip bar underneath shows remaining turns. **White = filled.** The "dark gray =
  empty" treatment is not implemented and probably not needed — pips just disappear.
- No background/outline currently. Mockup added clutter; revisit only if read against
  certain tiles becomes a problem.

---

## 5. Health Bars

- 11-step color ramp from critical red (0%) to full teal (100%).
- Background tracks a darker version of the same ramp.
- HP text uses a GlowLabel matching the ramp color.
- **Snapped to nearest step** — do not interpolate smoothly between ramp colors. Never
  use a color outside the palette; if a new step is needed, add it to the palette.
- Current bar height/thickness is correct.
- **NEEDS REVIEW**: damage preview zone (gray pulsing section) — Lawrence to eyeball
  in-game and call.

---

## 6. Combat Preview Panel

- Two-column layout (attacker top, defender bottom).
- Shows DMG, HIT, multiplier, element icons.
- Move name + type icon at top.
- **Largely done**, only small tweaks expected from here.

### Multiplier number colors — **LOCK**
- High multiplier → red
- Mid multiplier → yellow
- x0 (immune) → teal
- Note: the *values* are being rebalanced from 2.0/4.0 to ~1.2/1.44 (separate todo);
  the **color tiers do not change** with the rebalance.

---

## 7. Action Menu

- Right panel (140px).
- Default button: Gray 2 bg @ 30%, Gray 7 border. Hover: Gray 3 @ 50%.
- **Disabled / out-of-range handling**:
  - Out-of-range attacks are **hidden**, not shown disabled.
  - Depleted moves are **grayed out** in place.

### Selected/active button — **LOCK (target)**
- Pulsing glow on the border.
- Slow rotational accent shimmer.
- Locked as the goal; reconsider if it reads as noisy in practice.

- **NEEDS REVIEW**: overall satisfaction with the default button look — Lawrence to
  weigh in once he uses it.

---

## 8. Damage Popups

- Text rises from unit position, fades out.
- Color by damage amount: low = primary, mid = warning, high = danger.
- Critical hits get a brightened danger color.
- Background/outline: Gray 1 @ 97.5% opacity (in addition to the standard glow).
- **Heal popups**: green text + a small "green plus" with particle effect (not yet built).
- **NEEDS REVIEW**: standardized popup font size — pick a default and let Lawrence
  react in-game.

---

## 9. Phase Transition Overlay

- CIELAB-luminance-matched colors per faction (text + accent + glow triple).
- **Total banner time: ~3 seconds** as a non-intrusive default. May tighten further —
  it should feel snappy.
- **NEEDS REVIEW**: final treatment sign-off from Lawrence (in-game).

---

## 10. Spacing & Margins

- **No strict golden rules yet — vibes-driven.**
- ~13px panel-internal margin reads well on the unit detail panel, but eats ~20% of a
  small panel's real estate; smaller panels can go tighter.
- **NEEDS REVIEW**: chip-to-chip gap, panel-section gap, hard-floor minimums.
  Eyeball-driven; Lawrence will call values once we have a stable layout in front of him.

---

## 11. Icon Standards

| Icon                   | Size          | Status     |
|------------------------|---------------|------------|
| Elemental type         | 10×10         | Locked     |
| Move type (Phys/Spec/Sup) | 10×10      | Locked     |
| Terrain attribute      | 10×10         | Locked     |
| Status effect          | 6×6           | Locked     |
| Injury                 | 10×10         | Locked     |
| Portrait (large)       | 96×96         | Not final  |
| Portrait (medium)      | 64×64 (TBC)   | Not final  |
| Portrait (small)       | 32×32         | Not final  |

### Filtering
- **Pixel icons**: `TEXTURE_FILTER_NEAREST`, always.
- **High-res portraits**: filtering enabled; final algorithm TBD (probably bilinear,
  other spatial scalers under evaluation).

---

## 12. Things That Bug Lawrence

**NEEDS REVIEW** — Lawrence to flag pain points / bad pairings / redesign-before-alpha
candidates as he plays through builds. Empty for now is expected.

---

## 13. Things NOT to Touch

- Nothing is 100% set in stone — but **icon and font sizes** would be a giant pain to
  redesign around. Treat them as load-bearing.
- **Intentional-looking-arbitrary**: HUD chip borders are 1px, rounded 2. Godot's
  default AA makes this fit the design exactly; nudging it even slightly breaks the
  look. Lawrence can override; nobody else.

---

## Maintenance

- Keep this doc lined up with the questionnaire. When Lawrence answers a TBD, fold the
  decision in here and leave the questionnaire entry as-is for archive.
- Cross-reference from `CLAUDE.md` so agents read this before touching UI work.
