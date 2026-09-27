# Webtyler Autotile Plugin for Aseprite/Libresprite

Port of [wareya's Webtyler](https://wareya.github.io/webtyler/) for generating autotile previews directly in Aseprite.

## Installation

### Aseprite
1. Go to **Edit → Preferences → Extensions**
2. Click **Add Extension**
3. Select the `webtyler.aseprite-extension` file
4. Restart Aseprite

### Libresprite
1. Extract the zip contents to your Libresprite scripts folder:
   - **Windows**: `%APPDATA%\Libresprite\scripts\webtyler\`
   - **Linux**: `~/.config/libresprite/scripts/webtyler/`
   - **macOS**: `~/Library/Application Support/Libresprite/scripts/webtyler/`
2. Restart Libresprite

## Usage

1. Open your tileset sprite in Aseprite
2. **Sprite → Webtyler Settings** to configure:
   - **Input Format**: Select your tileset layout (minitiles, 3x3, 4x4, rpgmaker, etc.)
   - **Tile Size**: Set your tile dimensions (default 16x16)
   - **Offsets**: For non-centered tile borders (usually leave at 0)
3. Run **Sprite → Webtyler Refresh Preview** (or bind a hotkey — see below) to generate/refresh the preview
   - A new sprite window opens with the 12×4 Godot-format autotile output

Webtyler reads the **full visible composite** of your source sprite, so you can
split the tileset across as many layers as you like (e.g. line art over a fill
layer). Hiding a layer removes it from the input; showing it brings it back.
Tilemap layers are rasterized automatically, so they work as input too.

## Supported Input Formats

| Format | Description | Input Size |
|--------|-------------|------------|
| minitiles | 5 subtiles: empty, horizontal, vertical, corner, fill | 5×1 tiles |
| basic | Just empty + fill tiles | 2×1 tiles |
| basicborder | Empty + fill with wrapping border | 2×1 tiles |
| basicfullborder | Empty + fill + corner border | 3×1 tiles |
| basiclongborder | Simpler border variant | 2×1 tiles |
| 3x3 | Standard 3×3 autotile | 3×3 tiles |
| 4x4 | Full 4×4 blob tileset | 4×4 tiles |
| 3x3plus | 3×3 with inner corner tile | 4×3 tiles |
| 4x4plus | 4×4 with inner corner override | 5×4 tiles |
| 5x3 | Extended format | 5×3 tiles |
| rpgmaker | RPG Maker MV/MZ A2 format | 2×3 tiles |

## Output

The preview generates a **12×4 tile** output in Godot's autotile format, which can be used directly or converted for other engines.

**Sprite → Webtyler Export Tileset** writes that block to a PNG: the top-left
12×4 tiles, or 12×12 when the frame carries shadow blocks (see below). The
dialog prefills `<tag>_12x4.png` / `<tag>_12x12.png` beside the source file, matching
the shipped tilesets in `art/sprites/tilesets/`.

In **rpgmaker** mode the preview also stamps the seamless interior tile (the
"NESW full tile" — the square straddling the centre of the 2×3 reference) as a
**3×3 grid** below the autotile output, so you can eyeball whether the interior
tiles without visible seams.

### Shadows and the overflow column (rpgmaker)

Shadows are exported as their own blocks rather than baked into the tiles, so
the game can draw them over whatever floor and modifiers sit in the neighboring
cells. Two layer names carry roles:

| Layer | Role |
|-------|------|
| `bg` | Reference ground. Never exported; it's only what "darker than the ground" is measured against. |
| `shadows` | The shadow, painted in whatever shade reads well over `bg`. Exported as a two-color mask: flat black where it darkens the ground, transparent elsewhere. |
| anything else | The tile art. |

Only the shadow's SHAPE is exported. The game draws it at the board's one
shadow opacity — the same value unit shadows use — so every shadow moves
together from one number, and the shade Lawrence paints with is his own choice.

Shadow that should fall past a tile's east edge, into the next cell, goes in a
**third template column**, making the template 3×3 tiles. Paint it as a
continuation of the 2×2 block's right edge; it follows the block's half-tile
rows (at 32px): y 32–47 is the top cap (nothing to the north), y 48–79 the
middle, y 80–95 the bottom cap (nothing to the south). The column beside the
inner-corners tile (2,0) is never read — that tile can't sit at an east edge.

The output then stacks three 12×4 blocks: the body at rows 0–3, each tile's own
shadow at rows 4–7, and its east spill at rows 8–11, the spill filled only for
the 13 tiles open to the east. Shadow is erased where it lands on the caster's
own art, the way the tag exporter masks decoration shadows — so shading ON the
rock is part of the tile art, painted where it belongs, not something the
shadow layer can bleed onto. The sample scene draws the blocks the way the game
will — shadow over its own cell, spill into the east neighbor, all over a
ground fill — and is 13 tiles wide so its last column spills too.
**Webtyler Export Tileset** writes the top-left 12×12 tiles; a frame with no
shadow exports the plain 12×4 body.

`overflow_probe.lua` checks the pipeline headlessly against the real mountain
template (usage in its header).

### Animation

If your source has multiple **timeline frames** (e.g. animated water/lava, each
frame a full tileset), the preview becomes multi-frame too: every source frame
is autotiled into the matching preview frame and frame durations are copied over,
so the preview plays back the animated autotile. A single-frame source behaves
exactly as before.

Two options help when working with animation (both in the Webtyler dialog):

- **Follow source frame** — when you switch to the preview, it snaps to the
  frame you were editing in the source. (Aseprite's active frame is global, so
  it follows on tab-switch rather than live, which avoids focus flicker.)
- **Show source** — stamps the raw source tileset to the right of the output in
  the same preview document, so pressing play shows input and output animating
  together in one window.
- **Lock to tag** — when your file holds several tagged resources, the preview
  uses only the **tag containing the currently-selected frame** instead of the
  whole timeline. Selecting a frame in a different tag rebuilds the preview for
  that tag. Untagged frames fall back to the whole timeline.

## Hotkey

No default hotkey is registered (F10 conflicts with Aseprite's Color Curves).
Bind one yourself:

1. **Edit → Keyboard Shortcuts**
2. Search for `Webtyler Refresh Preview`
3. Click the empty shortcut column and press your desired key combo

The refresh command works with the settings dialog closed.

## Credits

- Original Webtyler web tool by [wareya](https://github.com/wareya/webtyler)
- Aseprite plugin port
