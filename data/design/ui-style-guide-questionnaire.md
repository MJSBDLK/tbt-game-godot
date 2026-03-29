# UI Style Guide Questionnaire for Lawrence

We need a proper UI style guide doc. You've been making visual decisions hands-on (panel styling, health ramp, icons, chip colors, damage popups, etc.) and it's time to write them down so they're consistent and referenceable.

For each section, give me your bullet points -- what the rules are, what to avoid, and anything that's still TBD. I've pre-filled what I think the answers are based on your existing work. Correct anything wrong and fill in the gaps.

---

## 1. Resolution & Scaling

- 640x360 reference resolution, integer scaling only (2x, 3x, 4x)
- 140px left / 360px center / 140px right panel layout
- Steam Deck is primary handheld target
- No fractional pixel positioning anywhere
- **Q: Any exceptions to the integer-only rule? Subpixel rendering for text?**
    - [RQD]: highres portraits will be rendered in high definition and actually need some kind of filtering, probably bilinear but I want to test some other spatial scaling algos
    - [RQD]: a (zoom mode: integer/nearest neighbor) is planned.
---

## 2. Color Palette

We have GameColorPalette with named color families (Azure, Red, Green, etc.) at 10 shades each.
*We also have a colors demo. Preview the scene with F6 to check it out.*

### General rules
- **Q: When should we reach for palette colors vs. hardcoded hex?**
- [RQD]: always reach for palette colors
- **Q: Are there any palette families we should avoid or that are reserved?**
- [LOD]: 

### Faction colors
- Player: Blue (`Azure` family)
- Enemy: Red (`Red` family)
- Neutral: Green
- Ally: Yellow
- **Q: Need a ramp name for neutral/ally**
- [LOD]: 

### Background & Panels
- Panel bg: `#302d27` @ 85% opacity (`HUD_PANEL_BACKGROUND`)
- **Q: Same bg for all HUD panels (unit preview, terrain preview, combat preview, action menu)?**
- [RQD]: Yes unless specified otherwise
- **Q: Any panels that should use a different opacity or tint?**
- [RQD]: no unless specified otherwise

---

## 3. Typography

Currently using GlowLabel (custom Label with glow_color property).

### Text color pairings
- Primary text: Azure 9 (`#dbf3ff`) + Azure 5 glow (`#4c8cbb`)
- Secondary text: YellowOrange 8 + Magenta 4 glow
- Success (buffs): Green 6 + Green 3 glow
- Danger (debuffs): Red 5 + Red 2 glow
- Status text: YellowOrange 7 `#f5cd65` (`STATUS_TEXT`) + Red 4 `#8e2518` glow (`STATUS_TEXT_GLOW`)
- Status-specific colors:
  - Burn = Orange 6 `#c98d47`
  - Poison = Purple 6 `#8772ab`
  - Buff = Blue 6 `#6d74a5`
  - Debuff = Magenta 5 `#9e5d9f`
- Status icon background: `#40230a`
- **Q: Are these pairings finalized?**
- [LOD]: 
- **Q: When should we use secondary text color vs. primary?**
- [LOD]: 
- **Q: Should every Label in HUD panels be a GlowLabel, or only specific ones?**
- [RQD]: Everything in a PANEL should be a GlowLabel.

### Font sizes
- **Q: What are the standard font sizes? (title, body, small/chip text, numbers)**
- [RQD]: 8 for UI text. There are exceptions but assume 8 unless we have a reason to go with something else.
- **Q: Any size that should never go below a minimum?**
- [RQD]: we should avoid going below 8, but the text is legible down to ~5px and we can use that in a pinch.

---

## 4. Panel Components

### Move Chips
- ColorRect with fill shader (fill_percent, fill_color, empty_color)
- Element-typed colors (Fire=Orange, Electric=Yellow, etc.)
- Depleted moves grey out
- **Q: Anything to add here? Border treatment? Hover state?**
- [RQD]: Yes, I would love feedback on mouseover. Probably a quick shimmer and some kind of animated shift
- [RQD]: We should probably have click feedback as well.

### Status Chips (Unit Preview Panel)
- ColorRect with icon (6x6), abbreviated name label, turns remaining label
- Up to 4 chips in a GridContainer
- Currently we have 4 status color categories: Burn (Orange 6 `#c98d47`), Poison (Purple 6 `#8772ab`), Buff (Blue 6 `#6d74a5`), Debuff (Magenta 5 `#9e5d9f`)
- But there are 15 status effects total. Many map naturally to elemental types:
  - DoT/damage: Burn, Poison, Bleed, Chain Lightning
  - Movement impair: Rooted, Freeze, Gravity
  - Debuff/weaken: Vulnerable, Wither, Subversion, Shocked
  - Aggro/taunt: Challenged, Bugle
  - Buff: Critical
  - Lockout: Void
- **Q: Should each status effect get its own color (tied to the element that inflicts it, e.g. Freeze=Cyan, Shocked=Yellow, Void=Eggplant)? Or group by category (all DoTs share one color, all CC shares another)?**
- [LOD]:
- **Q: Should status chip background color vary by status type/category, or stay uniform (#40230a for all)?**
- [LOD]:

### Passive Chips
- ColorRect with abbreviated name label
- Up to 4 chips in a GridContainer
- **Q: Same styling as status chips but without icon? Or different treatment?**
- [RQD]: They have different colors, otherwise they look like status chips with no icon and no turn timer.

### Status Effect Icons (On-Map, above units)
- 6x6 pixel icons, max 4 per unit, 2px gap
- 4x1 pip bar underneath showing remaining turns (white=filled, dark gray=empty)
- **Q: Happy with the pip bar treatment, or want to iterate?**
- [RQD]: The dark gray empty is not implemented and probably not needed
- **Q: Any background/outline on the on-map icons?**
- [RQD]: We tried mocking this up but it adds visual clutter. It might help read status icons against certain tiles, so we may revisit this.

---

## 5. Health Bars

- 11-step color ramp from critical red (0%) to full teal (100%)
- Background color tracks a darker version of the same ramp
- GlowLabel health text matches ramp color
- Currently snapped to nearest step (no smooth interpolation)
- **Q: Keep snapped, or switch to smooth interpolation?**
- [RQD]: Keep snapped. We should never use colors outside the palette. We can add colors, but we don't want o hardcode any hex values.
- **Q: Health bar height/thickness -- is the current size right?**
- [RQD]: yes
- **Q: Damage preview zone (gray pulsing section) -- finalized?**
- [LOD]:  

---

## 6. Combat Preview Panel

Based on your mockup draft:
- Two-column layout (attacker top, defender bottom)
- Shows DMG, HIT, multiplier, element icons
- Move name + type icon at top
- **Q: What's finalized here vs. still draft?**
- [RQD]: This is basically done at this point, only small tweaks from here
- **Q: Multiplier number colors (x4=red, x2=yellow, x0=teal) -- locked in?**
- [LOD]: 

---

## 7. Action Menu

- Right panel (140px)
- Button styling: Gray 2 bg @ 30%, Gray 7 border, hover = Gray 3 @ 50%
- **Q: Satisfied with the current button look?**
- [LOD]: 
- **Q: Selected/active button state?**
- [LOD]: 
- **Q: Should disabled actions (no usage, out of range) look different from hidden?**
- [RQD]: We currently hide attacks which are out of range, and gray out depleted moves
- [LOD]: 

---

## 8. Damage Popups

- Text rises from unit position, fades out
- Color based on damage amount (low=primary, mid=warning, high=danger)
- Critical hits get brightened danger color
- **Q: Font size for popups?**
- [LOD]:
- **Q: Any outline/shadow on popup text, or just glow?**
- [RQD]: Gray1 at 97.5% opacity
- **Q: Heal popups -- green? Different animation?**
- [RQD]: Green, and we probably want a lil "green + sign" with particle effect 

---

## 9. Phase Transition Overlay

- CIELAB luminance-matched colors per faction
- Text + accent + glow triple per faction
- **Q: Current treatment finalized?**
- [LOD]: 
- **Q: Animation timing -- how long should the banner hold?**
- [RQD]: We might fine tune this. It needs to be snappy. I find a total time of 3s is non-intrusive, but we may speed it up further

---

## 10. Spacing & Margins

- **Q: Standard margin inside panels? (currently varies)**
- [RQD]: I'm inclined to just use vibes here; 13px seems about right on the detail panel but there goes 20% of your panel real estate on a small panel
- [LOD]: 
- **Q: Gap between chips in a row?**
- [LOD]: 
- **Q: Gap between panel sections (e.g., HP bar to moves list)?**
- [LOD]: 
- **Q: Any golden rules like "always 2px gap" or "4px minimum margin"?**
- [LOD]: 

---

## 11. Icon Standards

Current icon sizes:
- Elemental type icons: 10x10
- Status effect icons: 6x6
- Portraits: ?
- **Q: Are these sizes locked?**
- [RQD]: type icons, status effect icons, terrain attribute icons: pretty much.
  for portraits, it's a different story. We have 96x96, 32x32, and I think 64x64 (correct me if I'm wrong) portraits? These aren't set in stone yet.
- **Q: Move type icons (Physical/Special/Support) -- what size?**
- [RQD]: 10x10. Probably set in stone.
- **Q: Should all icons use TEXTURE_FILTER_NEAREST?**
- [RQD]: Icons yes, portraits no.
  Wew haven't decided on what filtering algo to use on highres portraits. Probably bilinear but I want to test other spatial scalers.

---

## 12. Things That Bug You

- **Q: Anything in the current UI that doesn't look right?**
- [LOD]: 
- **Q: Any component you want to redesign before Alpha?**
- [LOD]: 
- **Q: Color pairings that feel off?**
- [LOD]: 

---

## 13. Things NOT to Touch

- **Q: Anything that's "done" and should not be messed with?**
- [RQD]: At this point I think nothing is 100% set in stone. The icon and font sizes would be a giant pain to redesign around, though.
- [LOD]: 
- **Q: Any visual decisions you've made that might seem arbitrary but are intentional?**
- [RQD]: The border around HUD chips using 1px, rounded 2: Godot's default AA behavior makes this fit perfectly within our design; change them even a little and I don't like the look. Lawrence can override this decision, obviously
- [LOD]: 