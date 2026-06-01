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

In **rpgmaker** mode the preview also stamps the seamless interior tile (the
"NESW full tile" — the square straddling the centre of the 2×3 reference) as a
**3×3 grid** below the autotile output, so you can eyeball whether the interior
tiles without visible seams.

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
