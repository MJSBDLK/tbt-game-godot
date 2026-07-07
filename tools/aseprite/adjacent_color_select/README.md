# Adjacent Color Select

Aseprite extension. Selects every pixel of a **target** color, but only where it
sits next to a **neighbor** color — the outline/shading pixels of one color that
border another.

## Usage

`Edit ▸ Adjacent Color Select…` opens the dialog. Bind a keyboard shortcut to it
via `Edit ▸ Keyboard Shortcuts` (search "Adjacent Color Select") for one-key
access — there is no default hotkey.

On open, the two swatches are **pre-seeded from the current foreground (target)
and background (neighbor) colors**.

1. **Target** — the color whose pixels get selected.
2. **Neighbor** — a target pixel is only selected if at least one adjacent pixel
   is this color.
3. Optional toggles:
   - **Include diagonals** — 8-way adjacency instead of the default 4-way.
   - **Use all visible layers (flattened)** — sample a composite of every visible
     layer instead of just the active cel's image.
4. Click **Select**. The status line reports how many pixels were selected.

### Fast picking

Click a swatch → the active tool switches to the **Eyedropper** → click a pixel
on the canvas → the swatch fills with that color. No color-popup detour.

If tool-switching isn't available on your build, the status line will instead
tell you to **Alt+click** the canvas (the eyedropper modifier), which works with
any tool. The **← FG** buttons load the current foreground color into a swatch.

Matching is **exact** in RGBA (no tolerance). If nothing matches, the current
selection is left untouched. Works in RGB, Grayscale, and Indexed color modes.

## Build / install

```bash
./build.sh
```

Produces a version-stamped `adjacent_color_select_v<x>_<y>_<z>.aseprite-extension`
and, if the extension is already installed, syncs
`~/.config/aseprite/extensions/adjacent_color_select/` in place.

First-time install: in Aseprite, `Edit ▸ Preferences ▸ Extensions ▸ Add
Extension`, pick the built `.aseprite-extension` file, then restart Aseprite.
Bump `version` in `package.json` before rebuilding so the archive name reflects
the new build.
