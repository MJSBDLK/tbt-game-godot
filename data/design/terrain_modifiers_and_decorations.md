# Terrain Modifiers & Decorations — System Design (V1)

This is the design reference for the terrain-modifier/decoration system: how
Lawrence's `.aseprite` source files turn into stampable tiles, how shadows
get rendered, and what each TileMapLayer in a map scene actually means.

Audience: anyone touching the system (Lawrence, RQD, future contributors).
Lawrence-readable parts marked **For Lawrence** below.

Source-of-truth status: this doc + the implementation. If they drift, fix
the doc.

---

## Goals

- Lawrence delivers `.aseprite` files; everything else (PNG export, shadow
  separation, sidecar metadata) is automatic via the editor plugin.
- One combined sprite library — there's no "modifier sprite" vs
  "decoration sprite" at authoring time. The same tile can be painted on
  either layer; the **layer it's painted on** determines its behavior.
- Shadows render automatically beneath modifiers — Lawrence doesn't paint
  them onto the map by hand.
- The system supports multi-cell footprints (2×2 craters) and oversized
  canvases (tall trees that visually extend beyond their gameplay tile).

## Layer architecture

A map scene has these TileMapLayers under `TilemapBuilder`, in z-order
from bottom to top:

| Layer | z-index | Purpose |
|---|---|---|
| `TerrainTileLayer` (Floor) | `FLOOR_TILES` (0) | Base terrain. Always populated. Defines default tile properties (movement cost, defense, etc). |
| **Shadow** (runtime-only, not in scene) | `TERRAIN_EFFECTS` (1) | Auto-spawned `Sprite2D` shadows for modifier tiles. Not painted by hand. |
| `ModifierTileLayer` (Modifiers) | `TERRAIN_MODIFIERS` (2) | Tiles painted here **completely replace** the floor's gameplay properties (per `terrain_data.json`). |
| `DecorationTileLayer` (Decorations) | `PURE_DECORATIONS` (3) | Pure visual overlay — no gameplay effect. |
| `SpawnTileLayer` (metadata) | n/a | Marks spawn points and map boundaries. |

The same tile (e.g. a crater sprite) can land on either modifier or
decoration layer:
- **Modifier layer**: gameplay rules apply (the unit standing on it gets
  the crater's defense bonus, etc).
- **Decoration layer**: no gameplay effect, purely visual flavor.

Z-index per-tile is computed by `ZIndexCalculator` (see
`scripts/core/z_index_calculator.gd`) so same-row sorting works across all
layers consistently.

## Asset authoring conventions

### For Lawrence — how to organize a `.aseprite` file

Each `.aseprite` file can contain many sprites. The **tag** is the
identity:

- One tag = one stampable sprite. The tag name becomes the file name on
  export (e.g., a tag called `crater_small` exports as `crater_small.png`).
- A tag's frames are the sprite's animation. A single-frame tag = a static
  sprite (most modifiers/decorations).
- All tags in the file share the same layer structure.

**Naming tags**: snake_case, descriptive, no spaces. Examples:
`crater_small`, `tree_dead`, `rock_round`, `flowers_yellow`.

### For Lawrence — shadow layer

If a sprite has a shadow, draw the shadow on a dedicated layer in the
`.aseprite`. The layer can be named anything — the plugin detects shadow
layers by content, not by name:

> A shadow layer is identified as any layer whose non-transparent pixels
> are all pure black at ~40% opacity. The export plugin scans for this
> signature.

This means: if Lawrence keeps shadows as pure-black-40%-alpha (which is
the current convention), no naming rule applies. If shadows ever depart
from that signature (colored shadows, different opacity), we'd need to
revisit detection.

If a tag has no shadow content (i.e. the shadow layer is empty for that
tag's frames), no shadow file is emitted for that tag.

### For Lawrence — multi-cell footprints

The game runs on a 32×32 grid. A sprite's footprint (the tiles it
occupies for gameplay) is normally inferred from canvas size:

- 32×32 canvas → 1×1 footprint
- 64×32 canvas → 2×1 footprint
- 64×64 canvas → 2×2 footprint

**Exception — oversized canvas** (sprite visually extends beyond its
footprint, e.g. a tall tree where only the trunk blocks movement): add a
slice named `footprint` covering the gameplay area in the bottom row.
Anything outside the slice is treated as visual overhang and rendered
above floor but doesn't block movement.

Example: a tree with a 32×96 canvas (1 wide, 3 tall) where only the
bottom cell is the trunk:
1. Draw the tree across the full 32×96 canvas
2. Add a slice named `footprint` covering the bottom 32×32
3. Export — the plugin emits the tree with `footprint: [1, 1]` and
   computes the correct visual offset so the tree's base sits on the
   gameplay tile and the canopy extends above

If no `footprint` slice exists, the plugin assumes the full canvas is the
footprint.

### Folder layout

New `.aseprite` source files live under `art/sprites/decorations/`. The
folder name is historical — it covers both modifier and decoration
sprites since the distinction is paint-time, not authoring-time.

A single `.aseprite` may bundle many tags (= many sprites). Lawrence's
current source `decorations_and_modifiers.aseprite` is one of these
bundle files.

The old `art/sprites/terrain_modifiers/` folder (with
`crater_small.png`, `crater_large.png`, `tree_01.png`) is legacy —
those files predate this system and will be either replaced by Lawrence's
new assets or kept as placeholder fallbacks. TBD which.

## Export pipeline

Right-click a `.aseprite` file in the FileSystem dock → **Export Tags as
PNGs**.

For each tag in the file, the plugin produces these outputs in a sibling
folder named after the `.aseprite` file:

- `<tag>.png` — the main sprite art, with any shadow layer **hidden**
  during export so the shadow isn't baked in
- `<tag>_shadow.png` — the shadow layer only, if a shadow layer exists
  and has content for this tag
- `<tag>.json` — sidecar metadata:
  ```json
  {
    "pivot": [x, y],            // pixel coordinates (existing convention)
    "footprint": [w, h],        // tile cells (from slice or canvas / 32)
    "shadow_path": "...",       // "<tag>_shadow.png" or null
    "frame_durations_ms": [...] // for animated tags (existing convention)
  }
  ```

For animated tags (multiple frames), the main PNG is a horizontal strip of
frames (existing plugin convention). If a shadow exists for the tag,
`<tag>_shadow.png` is a parallel strip with the same number of frames.

### Shadow detection

The plugin identifies the shadow layer by scanning pixels (not by layer
name). A layer is treated as a shadow if every non-transparent pixel
matches:
- RGB ≈ (0, 0, 0) within ±5% tolerance (allows for anti-aliased edges)
- Alpha ≈ 0.4 within ±5% tolerance

The scan happens once per `.aseprite` file (using a single tag's frames
to discover the shadow layer name). Once identified, the layer is hidden
or isolated via Aseprite's `--ignore-layer` / `--layer` CLI flags for
the production passes per tag.

If multiple layers match the shadow signature in the same file, the
plugin uses the first match and emits a warning. If no shadow layer is
found, all tags export normally (no `_shadow.png` files).

## Tile registration

After export, sprites get registered as tiles in `battle_tileset.tres`.
For V1 this is a manual editor step (open the tileset, add a new
TileSetAtlasSource pointing at the exported PNG, configure each tile).

Per-tile configuration:
- `custom_data_0` (`terrain_type`) — string matching a key in
  `terrain_data.json` (e.g. `"Crater"`). Required for tiles that should
  carry gameplay properties; can be left empty for pure-decoration tiles.
- `custom_data_1` (`is_modifier`) — boolean, `true` if the tile is
  eligible to be painted on `ModifierTileLayer` for gameplay effect.
- `texture_region_size = (32, 32)` — single-cell tiles use this.
- `set_tile_size_in_atlas` for multi-cell tiles (e.g., `(2, 2)` for a 2×2
  crater).
- `texture_origin` offset for oversized canvas — shifts the visual so
  the footprint aligns to the gameplay tile.

A Phase 2 utility could auto-register tiles by reading the sidecar JSON
and applying the right config. V1 is manual.

## Runtime shadow rendering

Shadows are not painted onto the map. They're spawned at runtime:

1. At scene load, `ShadowRenderer` (lives under TilemapBuilder) iterates
   every used cell on `ModifierTileLayer`.
2. For each modifier tile, the renderer looks up whether the tile has a
   paired shadow. Resolution order:
   - The tile's `custom_data` field `shadow_path` (set during tile
     registration, derived from the sidecar JSON's `shadow_path`).
   - Convention fallback: `<source_texture>_shadow.png` adjacent to the
     source texture.
3. If a shadow exists, a `Sprite2D` is spawned at the cell's world
   position with:
   - Texture: the shadow PNG
   - `texture_filter = NEAREST`
   - `z_index` computed via `ZIndexCalculator.calculate_sorting_order(
     row, grid_height, ZIndexLayer.TERRAIN_EFFECTS)` so shadows render
     above floor and below modifiers, with same-row sorting consistent
     across layers
   - Position offset matching the modifier tile's `texture_origin`

Shadows on `DecorationTileLayer` are not auto-rendered in V1. Decorations
are visual-only and meant to be lightweight; if Lawrence wants a
decoration to cast a shadow, paint it on the modifier layer with a
no-effect `terrain_type`.

## Behavior on unknown tile

When a tile is painted on `ModifierTileLayer` but its `terrain_type`
doesn't match anything in `terrain_data.json`:

- `TerrainDataManager` emits a `push_warning` (once per unique
  unknown name, deduplicated to avoid log spam).
- The underlying `Tile` is marked `is_walkable = false` — impassable.
- Floor properties are NOT used as a fallback (modifiers REPLACE floor
  properties per the three-tier rule).

Rationale: a missing modifier definition is probably a real bug
(e.g. a typo in the tile's custom data, or a tile registered before its
properties were added to JSON). Impassable + warning forces the gap to
get caught quickly during development rather than silently producing
unexpected behavior.

A future `DebugConfig.strict_modifier_validation` flag could harden this
to `push_error` for QA passes. Not needed for V1.

## Phase 2 — known future work

These are out of V1 scope but worth capturing now so they don't get lost:

- **Time-of-day shadow effects** — scale and rotate shadows based on a
  global "sun angle" parameter that varies over a campaign day cycle.
  The `Sprite2D`-based renderer architecture chosen for V1 directly
  supports this (per-sprite transforms), so it's an extension, not a
  rewrite.
- **Editor auto-paint helper** — when painting a modifier tile in the
  editor, automatically place the paired shadow on a dedicated shadow
  layer. V1 uses runtime spawning instead, which doesn't need editor
  tooling but does require a scene reload to see shadows after editing.
- **Decoration-layer shadows** — currently only modifiers get shadows.
  Easy to extend the renderer to scan decoration tiles too if we decide
  they need them.
- **Tile auto-registration utility** — read sidecar JSON and
  programmatically register tiles into the tileset, eliminating the
  manual editor step in tile registration.
- **`stamp_tiles.png`** — currently loaded as an ExtResource in
  `battle_tileset.tres` but never registered as a source. Either
  repurpose for the new modifier source or remove.

## Open questions / verification needed at implementation time

- Exact behavior of Aseprite CLI `--ignore-layer` and `--layer` flags
  when combined with `--tag` filtering. The CLI's `--tag` filter on
  `--sheet` exports is known broken (see project memory); we already
  work around that by stitching frames manually. May need a similar
  workaround for layer filtering if it has the same quirk.
- How animated shadows handle frames where the shadow layer has no
  content (some frames have shadow, some don't). Probably emit a
  transparent frame in the shadow strip to preserve alignment, but
  worth deciding once we hit a real example.
