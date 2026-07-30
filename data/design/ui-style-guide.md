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
- Row contents (Lawrence review 2026-07-19): element icon, then **damage-type icon**
  (`move_type_icons_10x10` — trial slot beside the element on the LEFT, revert clause
  "if it's ugly we'll move it back"), move name, uses pinned to the right edge.
- **Range + target scheme go on-chip** (kept for new-player value) but range must sit
  SEPARATED from uses — two number pairs side by side misread. Representation —
  **LOCK (RQD 2026-07-19): scheme + digits.** A 10×10 faction-colored glyph
  (`TargetSchemeGlyph`, runtime-drawn until Lawrence authors sprites: crosshair =
  single, plus-cluster = blast; bone = hostile, teal = friendly — mark the unusual,
  not the usual) plus a "1-N" range band in the **mini 5px font** (NotJamPixel5,
  bottom-aligned — LOCK, RQD 2026-07-19: annotation, not stat; the size split keeps
  range from pairing with uses' digits). A fixed-width name column keeps the
  scheme/range columns aligned down the menu. Reach strip = runner-up, kept in the
  mockup for reference.
- **Glyph growth is an explicit option (RQD 2026-07-19)**: little X marks inside the
  footprint may designate the damaged cells (which also notates donuts: footprint
  minus epicenter). An X needs a ≥3×3 px cell — at 2×2 cells degrade to center
  dots — so an X-marked diameter-3 blast is ~11 px and diameter-5 is ~19 px. When
  fidelity needs it, the glyph outgrows 10×10 and the CHIP EXPANDS to fit: wider
  first, then the two-line layout. The grid preview stays the truth for anything
  the glyph abbreviates.
- **Glyph ink contrast (revised twice 2026-07-26, same-day passes)**: the chip
  shader draws the glyph ink as **ONE color** — the faction's standard cut
  (bone Eggshell 8 / teal Teal 6) unless EITHER side's RESTING body is too
  close to read (< 1.5:1), in which case the whole glyph goes **"all the way
  to white" = index 10 of the ELEMENT's own ramp** (Lawrence's spec) — the
  same ramp the backlight climbs and the shadow descends, so every color on
  a chip derives from one ramp. Only a light FILL can trigger it (standard
  and ramp-10 both clear every empty by ≥2.9:1). Two rejected shapes on the
  record: dark cut per side (Lawrence: "weird when the dividing line runs
  through it", a 9.2:1 mid-glyph seam; recover 9dd28fc) and bleach per side
  (RQD: "center of the target brighter than the edges" — banding across the
  crosshair's disjoint cells; recover 65f9118). Legibility over light fills
  rides the glyph's dark ramp shadow (Gray 10 vs its Gray 5 shadow ≈ 3.9:1).
  Awaiting Lawrence's eyes on Piston/Dynamo in the F6 gallery; revisit when
  real scheme sprites land.
- **Glyph shadow — LOCK (Lawrence 2026-07-20, depth 2026-07-26)**: the shadow is
  the occluded body color pushed down its own ramp, never a black overlay, split
  per pixel across the usage divider (rendered in the chip's fill shader). Depth
  matches the HTML mockup's pop: **~30% of the body's luminance**. Ramp steps
  aren't perceptually uniform, so that's **2 steps on the fill / 1 on the empty**
  (per-element depth column in `GameColors._MOVE_CHIP_RAMPS`; Gray's dense top
  gives ROBO a 3). Off-the-bottom clamps to the ramp floor — Obsidian's empty IS
  Blue 0, so its shadow vanishes there: you can't darken black. Rest and full
  backlight are exact GPL entries (eyedropper-safe); mid-fade interpolates, same
  as the body.
- Full move details live in the **long-press tooltip** (§14 "Detail tooltips") — the
  chip is a mnemonic, not the spec sheet.
- Depleted moves grey out (folds into the §14 disabled tier at action-menu adoption).
- Hover/click feedback: **built** — the §14 vocabulary via `MoveChipButton`
  (ramp-step backlight, snapping cursor brackets, assigned border-ramp orbit,
  press response, deny).

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
- **ADOPTED into §14 (2026-07-19, Lawrence: "cramped but organized")**: the action
  menu, system menu, and options Close button are real `InteractiveButton` /
  `MoveChipButton` components — the hand-rolled styles (and the Gray 2/3 line
  below) are gone. Focus is the menu cursor (opens on the first item); the "> "
  assigned prefix became parked brackets, which then became the **orbit**
  (marker hunt revival, in-engine trial 2026-07-26 — see §14 "Assigned
  marker"); deny surfaces via `DenyTooltip`. The
  system menu's End Turn dropped its magenta accent (magenta = special damage);
  its CTA stays unwired because TurnManager auto-ends the phase when all units
  have acted. Options toggle pills stay hand-rolled — the vocabulary has no
  toggle/segmented design yet (future §14 extension).
- ~~Default button: Gray 2 bg @ 30%, Gray 7 border. Hover: Gray 3 @ 50%.~~
- **Disabled / out-of-range handling**:
  - Out-of-range attacks are **hidden**, not shown disabled.
  - Depleted moves are **grayed out** in place (press-for-why since adoption).

### Selected/active button — superseded by §14
- Was locked as "pulsing border glow + slow rotational shimmer, reconsider if it
  reads as noisy" — the reconsider clause fired in the border-vocabulary mockup
  review (Lawrence, 2026-07-08: too smooth/busy for the pixel style).
- Current lead treatment: **bracket corner ticks** — see §14 for the full state
  vocabulary, alternates, and the open final pick.
- Hover treatment is likewise governed by §14 (backlight), not the Gray 3 line above.

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

## 14. Interactivity Affordance — Border Vocabulary

Live mockup: `data/design/mockups/border-vocabulary.html` (open in any browser;
sliders tune every rate). Decisions dated 2026-07-15 unless noted. Mockup hex values
are placeholders to be mapped onto `GameColorPalette` ramps at build time.

**The contract — LOCK (RQD)**: a lit border means "you can press this"; unlit means
furniture. Text glow (GlowLabel) is typography and carries NO interactivity meaning —
the affordance channel is the border/background only. Motion carries meaning by
*category*: none = normal, converging = "the game suggests this next," traveling =
"you are here."

**Scarcity rules — LOCK**: at most ONE call to action and ONE selection on screen, so
at most two things ever animate at once. Attention order (squint test):
disabled < static < idle < selected < call to action.

### States
- **Static** (panels, labels): flat dark border, never moves.
- **Interactive idle**: steady lit border (azure family). Never pulses — the light
  alone carries the contract.
- **Focus/hover** — **NEEDS REVIEW (Lawrence)**: backlight — button background lifts
  toward the azure glow over **2/15 s (~8 frames)** in **4 discrete shades** (stepped
  palette ramp, both directions); border brightens. Replaces the shine sweep Lawrence
  flagged as too hifi; ¼ s tried and felt too slow (RQD 2026-07-15). On touch this state barely exists; press response does the
  work. On controller this is the traveling focus.
- **Disabled**: darkest tier, steady; pressing it surfaces the reason (tap-for-why).
  Gameplay-level rules stay per §7 (out-of-range hidden, depleted grayed).
- **Selected** — **LOCKED direction (RQD 2026-07-15; Lawrence to final-confirm)**:
  **bracket corner ticks** — hot-white, grown from the border's own corners, snap
  between exactly 2 positions (in / 1 game px out, no easing) at **1.25 Hz**. The
  button itself does NOT recolor: purple was retired from selection semantics
  ("kill your darlings") — the shape is the whole signal, which also means it
  survives reduce-motion as parked white ticks. Runner-up kept in the mockup:
  *marquee orbit* — two diametrically opposed highlights traveling the border at a
  FIXED px/s (default 50), azure ramp so tails melt into the lit border; ramp
  **LOCKED**: core = step = **3 game px** (footprint 3/9/15/21 — bands read too
  obviously above 3). Retired: whole-button magenta recolor, quiet (color-only),
  orbit-once (both depended on the recolor). **Revival (RQD 2026-07-26)**: the
  orbit is no longer a selection candidate — it returned as the **assigned
  marker** on move chips, now built in-engine (see "Assigned marker" below;
  mockup's marker hunt holds the static runner-ups).
- **Magenta/purple accent — job found, de facto (2026-07-19): SPECIAL damage.**
  The shipped `special_d` move-type icon is a magenta sparkle, and the
  phys/spec/support trio now rides on move chips as well as the detail panel,
  equipment picker, and combat preview — making magenta the color of special
  damage. Semantic, never a state, so it can't collide with selection or the
  amber CTA monopoly. Still do NOT reuse it for selection or call to action.
- **Call to action**: converging rings — spawn dim a few game px out, shrink onto the
  border, which catches the light as they land. Motion *toward* = "come here";
  in-place pulse is explicitly rejected (reads as selected/idle).
- **Press response — LOCK**: 1 game px downward shift + brightness flash. No scaling,
  ever (integer pixel grid). Pairs with the input-layer tap ring.

### Assigned marker — IN-ENGINE TRIAL (RQD 2026-07-26; Lawrence to eyeball)
The assigned move wears the **orbit**: two diametrically opposed highlights
traveling the chip's border ring at **50 px/s** (`ORBIT_SPEED_PX_PER_SECOND`,
the tinker knob), each a white core with shade steps down the **border's own
ramp — Gray 10/9/8/7**, tail landing exactly on the skin border's code color
(Gray 7). That's the selection-era melt-into-the-frame trick transplanted:
azure tails melted into the lit azure border, gray tails melt into the gray
frame. (Recolored 2026-07-29 from the first bone Eggshell cut, which matched
the *mockup's* warm `#7a766b` border — the engine's border was never warm.
Note the RENDERED border is body-tinted: the shader's edge blend mixes the
1px ring with the fill/empty beneath it, so it reads dual-shade on screen;
the orbit melts to the border's *code* color, accepted.) Locked geometry
carries over from the selection-era marquee: core = step = **3 game px**.
Not azure — that's interactivity's color, and assignment is a *fact*, so the
marker rides the depleted grey tier unchanged and ignores `disabled`.
**Parked brackets RETIRED with this**: brackets mean only "you are here,"
and the cursor landing on the assigned chip snaps brackets over a
still-running orbit (two motions composing — judge in the F6 gallery:
F. Lance live, Spark depleted). Venues (2026-07-29): **action menu + unit
preview readout** — the old display-venue ban existed because parked
brackets read as "selected" there, which the orbit can't; an armed move is
public info anyway (combat preview reads `defender.assigned_move`). The
**detail panel opts out** — it inspects the roster, it doesn't arm moves.
Reduce-motion parks both highlights at their
spawn points (two static dashes on opposite edges). Static runner-up
candidates (edge bar / underline / pip) stay in the mockup's marker hunt if
the orbit muddles in practice. Corner geometry: radius-2 pixel ring, one
diagonal pixel per corner; the 21px tail wraps corners and floods the short
edges — flagged for the eyeball, not pre-judged.

### Detail tooltips — CORE, LOCK (RQD + Lawrence 2026-07-19)
One gesture across every input opens "tell me more" on a move chip (and later,
anything with a detail body): **long press (touch) = right click (mouse) =
Back or R3 (controller — playtest which)**. Content = the move detail panel's
data, with explanations. This is what lets the chip stay a mnemonic — the
tooltip is the spec sheet, so nobody is *required* to navigate menus to play.
- Long-press duration: Settings slider, **200–1000 ms in 50 ms steps, default
  200 ms**. The 200 ms floor is a softlock guard: below a hold the player can
  reliably execute, ordinary taps start reading as long-presses and pressing
  becomes impossible.
- Distinct from press-for-why (deny): deny answers "why not," this answers
  "what is it." Same styled-tooltip visual family.
- **BUILT 2026-07-21** as `MoveTooltip` + chip/panel wiring. Every trigger is a
  HOLD — the card lives while the hold lives, release dismisses. One card on
  screen; opening it clears any deny (and vice versa). Card = full name in the
  element's chip text scheme + PWR/ACC/RNG/USES (detail-pane formats) +
  targeting in words + secondary effect + description.
- Per venue ("don't confuse the player", RQD 2026-07-21):
  - **Action menu**: all three inputs. A matured touch hold CANCELS the
    in-flight press, so releasing after a peek never casts. Works on disabled
    chips (a depleted move's spec is exactly what you want to read); a quick
    tap on one still denies.
  - **Unit preview**: touch long-press ONLY. Chips are display-only and
    mouse-transparent — mouse/grid-cursor over the panel hovers the tiles
    beneath, which flips the panel to the far side (the existing info-panel
    dodge IS the M&K/controller answer). Touch presses on chips are consumed
    so the tap-through doesn't dismiss the panel mid-hold.
  - **Unit detail**: no-op (`peek_enabled = false`) — the detail pane beside
    the chips is the card's content, live and larger.
- Controller mapping: `tooltip_peek` = Back AND R3 for now; playtest culls.

### Sound
Crispy, RE1 / OG Deus Ex direction — sharp attack, dead-fast decay, mid-band.
Mockup synth blips are placeholder shapes (hover ~2.4 kHz / 25 ms tick; press ~900 Hz
+ noise transient; deny = low double-knock). Direction approved; real samples are
Lawrence's.

### Implementation rules
- One global clock (autoload tween or shared shader `time` uniform) drives all border
  animation — the UI breathes as one, and reduce-motion is a single kill switch
  (`Settings.ui_motion_enabled`; every state keeps its color, loses its motion).
- All motion is stepped/quantized to game pixels or discrete shades — nothing glides.
- Marquee = perimeter-distance shader (or dashed Line2D loop); backlight = StyleBox
  bg-color tween quantized to 4 steps.

---

## Maintenance

- Keep this doc lined up with the questionnaire. When Lawrence answers a TBD, fold the
  decision in here and leave the questionnaire entry as-is for archive.
- Cross-reference from `CLAUDE.md` so agents read this before touching UI work.
