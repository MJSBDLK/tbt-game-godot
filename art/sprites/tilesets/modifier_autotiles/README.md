# Modifier autotiles

Autotile sheets painted on the **modifier** layer (gameplay terrain) or the
decoration layer, as opposed to the floor sheets in `12x4_terrains/`. Exported
from Webtyler (`tools/aseprite/webtyler/`), source `.aseprite` files live in
`art/sprites/terrain_modifiers/`.

Unlike a floor sheet, these carry **no ground** — transparent everywhere the
art isn't — so they sit over whatever floor is painted underneath, and their
shadows fall on the neighbors rather than being baked into the tile.

## Sheet layout

Each sheet is 12 tiles wide; the blocks stack, 4 rows each:

| Rows | Block | Drawn |
|------|-------|-------|
| 0–3 | Body | The tile art, at its own cell |
| 4–7 | Shadow | The shadow inside the tile's own cell |
| 8–11 | East spill | The part of the shadow that falls into the cell to the east |

The blocks share indices: the shadow for the tile at (x, y) is at (x, y + 4)
and its spill at (x, y + 8). A block is only as populated as the art needs —
the spill block fills only the 13 tiles that are open to the east. Shadow that
would land on the tile's own art is erased, so shading on the rock itself is
painted into the tile art rather than coming from the shadow layer.

A sheet whose art casts no shadow is just the 12×4 body block.

## Naming

`<terrain>_12x12.png` (or `_12x4.png` with no shadows), matching the
`<name>_12x4.png` convention of the floor sheets. Webtyler's **Export
Tileset** prefills the name.

## Authoring

The template is an `rpgmaker` 2×3 reference plus an overflow column, with
named layers deciding what becomes art and what becomes shadow. That side
lives in the Webtyler README (`tools/aseprite/webtyler/`), next to the code
that reads it.
