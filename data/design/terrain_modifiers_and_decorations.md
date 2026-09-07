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

## Architecture: terrain across three systems

If you open `terrain_data.json`, `modifier_terrain.json`, and the tileset
cold and think "three systems for terrain? why not one?" — this section is
for you. The split is deliberate. Each file answers a different question,
is keyed differently, and changes for a different reason:

| System | File(s) | Answers | Keyed by | Edited when |
|---|---|---|---|---|
| **Terrain rules** | `data/terrain_data.json` | "What does terrain X *do*?" walk/cost/def/avoid/immunity, per unit type | terrain_type name | you rebalance gameplay |
| **Sprite → terrain map** | `data/modifier_terrain.json` | "Which terrain does each *cell* of this sprite get?" | sprite name (prefix or exact, per-cell rows) | art ships / a sprite is reclassified |
| **Paintable tiles** | `resources/battle_tileset.tres` + `tools/register_modifier_tiles.gd` | "How is this sprite *painted and rendered*?" source, footprint, anchor | tile source | new art arrives |

Why they can't collapse into one file:

1. **Reuse (many-to-one).** A dozen plant sprites (`bulbforest_*`,
   `darkforest_*`, `shelltree_*`, `piperoot_*`) all point at one `Plant`
   rule set. If rules lived per-sprite, retuning "Plant move cost" would
   mean editing twelve entries. `terrain_data.json` is a normalized lookup
   table: define once, reference many.
2. **Different editors, different cadences.** Rules change when the
   *designer* rebalances. The sprite map changes when the *artist* ships or
   we recategorize. Tile registration changes mechanically when *new art*
   arrives. Fusing them means every art drop risks touching balance numbers
   and vice-versa.
3. **Different shapes.** Rules are per-type (one entry per terrain). The map
   is per-sprite-per-cell (rows inside a footprint). Tiles are
   per-atlas-source. One schema holding all three makes all three awkward.

**The join, at runtime:** for each modifier cell —
`sprite name → (modifier_terrain.json) → terrain_type → (terrain_data.json)
→ gameplay`. Two chained lookups. The map is the join table between art and
rules. The builder ([tilemap_grid_builder.gd](../../scripts/grid/tilemap_grid_builder.gd))
does this during scene build via
[ModifierTerrainMap](../../scripts/grid/modifier_terrain_map.gd).

**One asymmetry to know:** *floor* terrains carry their `terrain_type`
baked into the tileset's custom_data (they're simple per-atlas-cell
autotiles — Sand, Water, Road). Only *modifiers* route through
`modifier_terrain.json`, because they need per-cell-within-footprint
resolution (a 2×2 castle is `Wall` on top, `Castle` below) and live-editable
assignment. Different mechanisms because they're genuinely different shapes
— not an oversight.

**Practical consequence:** the registration tool only *mints paintable
tiles*. It does not assign terrain. So you re-run it only when new sprites
arrive; retuning which terrain a sprite maps to is a `modifier_terrain.json`
edit + battle reload, no re-registration.

### `modifier_terrain.json` resolution order

For a sprite painted at a cell, terrain for footprint offset `(dx, dy)`
(dy = rows north→south from the anchor) resolves as:

1. `by_sprite[name].cells[dy][dx]` — full per-cell control (rarely needed)
2. `by_sprite[name].rows[dy]` — whole-row terrain (the castle case)
3. `by_prefix` longest-matching prefix — the bulk default
4. no match → not a gameplay modifier (pure decoration)

Example — the 2×2 castle:
```json
"by_sprite": { "castle_a": { "rows": ["Wall", "Castle"] } }
```
Top row (both cells) → `Wall` (impassable except fliers); bottom row →
`Castle` (walkable, defensive bonus). A flier can perch on the keep; ground
units must take the gate.

**Render hints** also live in `by_sprite` entries and apply on either paint
layer (they're keyed by sprite name, and the renderer is the same):

- `occlude`: `"interleave"` (default) or `"solid"` — how a multi-row
  sprite sorts against units standing on its body.
- `casts_shadow`: default `true` — whether the runtime *generates* a cast
  shadow when the sprite ships no authored `_shadow.png`. The craters and
  the bridge are `false` (a hole casts nothing). Authored shadows always
  render regardless.

An entry holding only render hints does **not** make an unprefixed sprite a
gameplay modifier — `is_modifier` needs `rows`/`cells` or a prefix match.

## Layer architecture

A map scene has these TileMapLayers under `TilemapBuilder`. Board z is
`(99 − row) × 10 + slot` with row 0 = the southernmost row (see
`scripts/core/z_index_calculator.gd`), so the **row dominates** and the slot
only orders things *within* a row. Slots, bottom to top:

| Layer | z slot | Purpose |
|---|---|---|
| `TerrainTileLayer` (Floor) | `FLOOR_TILES` (0) | Base terrain. Always populated. Defines default tile properties (movement cost, defense, etc). Rendered by the TileMapLayer itself. |
| Foot tracks (runtime-only) | `FOOT_TRACKS` (1) | Walk trails. See [foot_tracks.md](foot_tracks.md). |
| Terrain effects (runtime-only) | `TERRAIN_EFFECTS` (2) | Unit cast shadows (`UnitShadow`). Terrain-sprite shadows drop here only when `TerrainSpriteRenderer.SHADOWS_ABOVE_MODIFIERS` is off. |
| `ModifierTileLayer` (Modifiers) | `TERRAIN_MODIFIERS` (3) | Tiles painted here **completely replace** the floor's gameplay properties (per `terrain_data.json`). Hidden at runtime; drawn by a `TerrainSpriteRenderer` overlay. |
| `DecorationTileLayer` (Decorations) | `TERRAIN_MODIFIERS` (3) | Same sprite library, **no gameplay effect**. Hidden at runtime; drawn by its own `TerrainSpriteRenderer`, added to the tree *after* the modifier one, so on a shared cell the decoration draws on top (tree order at equal z). |
| Terrain-sprite shadows (runtime-only) | `TERRAIN_SHADOWS` (4) | Authored or generated shadows of *both* layers' sprites, one slot above the bodies so a shadow falls onto its east neighbor. |
| `SpawnTileLayer` (metadata) | n/a | Marks spawn points and map boundaries. Hidden at runtime. |

The same tile (e.g. a tree sprite) can land on either modifier or
decoration layer, and **renders identically** on both — full PNG with
overhang, per-row interleaving, shadow:
- **Modifier layer**: gameplay rules apply (the unit standing on it gets
  the terrain's defense bonus, movement cost, etc).
- **Decoration layer**: no gameplay effect, purely visual flavor.

The paint layer decides gameplay, never looks. (Before 2026-09-07 the
decoration layer was a bare TileMapLayer at a flat z: it drew only the
central 32×32 atlas chunk, cast nothing, and never occluded a unit behind
it. Lawrence's test map has more cells on the decoration layer than the
modifier layer, nearly all of them 96×96 trees — that's what the shared
renderer fixed.)

## Asset authoring conventions

### For Lawrence — how to organize a `.aseprite` file

This works exactly like the existing character-sprite workflow you already
use ("Export Tags as PNGs" from the right-click menu). One `.aseprite`
file can hold one sprite or many — the **tag** is the identity:

- One tag = one stampable sprite. The tag name becomes the file name on
  export (e.g., a tag called `crater_small` exports as `crater_small.png`).
- A tag's frames are the sprite's animation. A single-frame tag = a static
  sprite (most modifiers/decorations probably). Multi-frame tags export as
  a horizontal strip of frames — same as character animations.
- All tags in the file share the same layer structure and the same pivot
  (the existing plugin treats pivot as file-wide, one slice covers all
  tags).
- Per-frame durations from the `.aseprite` header are captured into the
  sidecar JSON, so animations preserve your pacing.

**Naming tags**: snake_case + an authoritative `_WxH` dimension suffix
marking the gameplay footprint in tile cells. The suffix gets stripped
when the file is exported (so the output PNG is `<basename>.png`, no
suffix).

Examples:
- `crater_small_1x1` → `crater_small.png`, footprint 1×1
- `arch_a_2x1`       → `arch_a.png`,       footprint 2×1
- `castle_a_2x2`     → `castle_a.png`,     footprint 2×2
- `building_b_3x2`   → `building_b.png`,   footprint 3×2

The plugin sanitizes any non-alphanumerics in the basename (lowercases,
replaces with underscores). The dimension suffix is what makes a tag a
*terrain sprite* vs a *character sprite* — see "Character sprites" below.

**Reserved tag names — don't use these for sprites**: the plugin treats
any tag named exactly `hit`, or starting with `hit_`, or ending with
`_hit`, as a *frame marker* (used to pin impact frames on combat
animations), not a sprite. Marker tags don't export as PNGs. For
terrain modifiers/decorations this convention won't conflict with normal
sprite names, but worth knowing if you ever want a sprite called
"shockwave_hit" — it would silently get skipped.

Both workflows are supported and equivalent:
- **One sprite per file** (e.g. `crater_small.aseprite` with one tag).
- **Many sprites per file** (e.g. `decorations_and_modifiers.aseprite`
  with N tags). This is the more efficient option when sprites are
  related or share a layer/palette setup.

### For Lawrence — shadow layer

If a sprite has a shadow, draw the shadow on a dedicated layer in the
`.aseprite`. The plugin will identify the shadow layer via two checks
(name first, content second):

1. **Layer name** — any layer named exactly `shadow` (case-insensitive)
   or with a `_shadow` suffix (case-insensitive) is treated as the
   shadow layer. Examples: `Shadow`, `shadow`, `crater_shadow`,
   `tree_canopy_shadow`. This is the unambiguous case.
2. **Content scan fallback** — if no layer name matches, the plugin
   scans each layer and treats any layer whose non-transparent pixels
   are all pure black at ~40% opacity (Lawrence's convention) as the
   shadow.

Why both: the name check is bulletproof but requires Lawrence to follow
the naming. The content scan is a safety net so a layer that LOOKS like
a shadow but is named "Shadows Cast" or "darken" still gets caught.

The `_shadow` suffix is also the escape hatch for animated shadows where
some frames have no shadow content (an empty frame within an animated
shadow strip would fail content detection). Marking the layer explicitly
with `_shadow` tells the plugin "trust me, this is a shadow."

If a tag has no shadow content (i.e. the shadow layer is empty for that
tag's frames), no shadow file is emitted for that tag.

### For Lawrence — gameplay footprint vs. visual extent

The game runs on a 32×32 grid. The **footprint** is the gameplay
rectangle — the cells that block movement, accept damage modifiers,
etc. It's **the `_WxH` suffix on the tag name**, full stop, and
extends 16px on each axis from the pivot per cell (so a `_1x1` is the
32×32 square centered on the pivot).

The **visual** (the actual cropped PNG) usually exceeds the footprint —
a tree with footprint `_1x1` typically has a canopy that extends well
above its trunk. The plugin preserves this overhang and the runtime
renderer draws the full visual at the tile's position, so overhanging
trees, wide arches, and tall buildings all show correctly.

Concretely, for a tag marked `_WxH`:
- The PNG dimensions are the smallest **`W + 2k` × `H + 2j`** cells
  (for non-negative integer k, j) large enough to contain the visual
  content centered on the pivot.
- The gameplay footprint is the central `W × H` chunk of the PNG.
- The surrounding cells of overhang are visual-only and don't affect
  gameplay.

For a 1×1 footprint, valid PNG widths are 32, 96, 160, … (footprint
plus an odd number of overhang cells per axis). For a 2×2 footprint,
valid widths are 64, 128, 192, … In both cases the gameplay area lands
on cell-aligned atlas coordinates so the tileset registration can
place the tile cleanly without partial-cell math.

If Lawrence wants to limit a sprite's overhang, he can simply trim
content in the source `.aseprite` — anything outside the bbox of the
visible pixels doesn't contribute to PNG dimensions.

### Character sprites (no dimension suffix)

Tags without the `_WxH` suffix are treated as character animations —
the existing character workflow (idle, melee, etc.) keeps using
bbox-derived sizing without footprint handling. So `idle` and
`melee_long` continue to work exactly as they did before this system
landed.

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
PNGs**. Same menu item we already use for character sprites — same
plugin, extended for shadow handling.

The existing plugin already handles: tag parsing, per-tag PNG output
(with frame-strip stitching for animated tags), pivot capture from
slices, per-frame duration capture, sidecar JSON emission with merging
(hand-authored sidecar fields survive re-export).

The terrain-modifier work adds three things to the same flow:
1. Shadow layer detection + separation into a paired `_shadow.png`.
2. Footprint declaration in the sidecar, sourced from the tag-name
   `_WxH` suffix (authoritative — overrides any computed value).
3. Pivot-centered crop: the cropped PNG is the smallest cell-aligned
   rect containing all visual content centered on the pivot, with
   dimensions `footprint + 2k cells` per axis (overhang preserved).

For each tag in the file, the plugin produces these outputs in a sibling
folder named after the `.aseprite` file:

- `<tag>.png` — the main sprite art, with any shadow layer **hidden**
  during export so the shadow isn't baked in
- `<tag>_shadow.png` — the shadow layer only, if a shadow layer exists
  and has content for this tag (omitted if the shadow layer is empty for
  this tag's frames)
- `<tag>.json` — sidecar metadata, merging with any existing sidecar so
  hand-authored fields (e.g. `art_bounds` from healthbar bootstrapping)
  survive re-export:

For tags with a `_WxH` dimension suffix, the output dimensions are
the smallest cell-aligned rect that (a) contains all visual content
(main + shadow union), (b) is centered on the source pivot, and
(c) has dimensions `W + 2k` × `H + 2j` cells. This keeps the gameplay
area (the central `W × H` chunk) on cell-aligned atlas coordinates
when the tileset registration places the atlas tile. The output PNG
basename has the suffix stripped (so `arch_a_2x1` exports as
`arch_a.png`).

For tags without the suffix (character animations), the main + shadow
strips are **trimmed
to a shared bounding rect** computed across both layers + all frames of
the tag, then **padded to the nearest 32-pixel multiple** on each axis
(bottom-aligned, so the bottom row of the output PNG corresponds to the
gameplay tile row). This means a tag whose content is 19×40 pixels lands
as a 32×64 PNG (1×2 cells). Footprint in the sidecar is derived from
the padded dimensions unless an explicit `footprint` slice is present.
  ```json
  {
    "pivot": { "x": <int>, "y": <int> },   // existing — from slice or canvas center
    "frame_durations_ms": [...],           // existing — per-frame durations
    "footprint": [<w>, <h>],               // new — tile cells
    "shadow_path": "<tag>_shadow.png"      // new — null/absent if no shadow
  }
  ```

For animated tags (multiple frames), the main PNG is a horizontal strip
of frames (existing plugin convention). If a shadow exists for the tag,
`<tag>_shadow.png` is a parallel strip with the same number of frames so
frame-to-frame alignment is preserved at render time.

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

After export, sprites get registered as tiles in `battle_tileset.tres` by
the registration tool — never by hand:

```
godot-4 --headless --path . --script tools/register_modifier_tiles.gd
```

It walks the export folder, reads each sidecar for the footprint, and
mints one `TileSetAtlasSource` per main PNG (the `_shadow.png` files are
runtime-only). Per source: `resource_name` = the sprite name (the PNG
basename — this is the key every runtime lookup uses), the atlas tile at
the centered footprint cell(s), `is_modifier = true` in custom data, and a
`texture_origin` nudge on multi-cell tiles so painting looks right in the
editor. It does **not** assign terrain — that's `modifier_terrain.json`.

**Source ids are stable.** Painted cells reference `(source_id,
atlas_coords)`, so a sprite keeps the id it was first registered under
forever; new sprites append above the highest id in use, in sorted-name
order. The tool refuses to save if any existing id would change hands, and
a run that changes nothing leaves the file untouched. (The original tool
re-minted every source in sorted order on each run, which would have
silently repainted every map the first time a new sprite sorted before an
existing one.) `tests/unit/test_map_tileset_integrity.gd` walks every
map's modifier + decoration cells and asserts each one still resolves.

If a PNG is re-exported at a **different size**, its atlas tile moves and
the tool warns loudly: every painted cell of that sprite needs repainting.
Same-size re-exports are free.

## Runtime rendering: `TerrainSpriteRenderer`

[terrain_sprite_renderer.gd](../../scripts/grid/terrain_sprite_renderer.gd)
is the single overlay for **both** paint layers; its header is the living
doc. `TilemapGridBuilder` spawns one per layer after the grid bounds are
final (modifier first, decoration second). Each renderer hides its
TileMapLayer and, per painted cell, spawns:

1. **The shadow**, first, so it sits behind everything else at that
   position. Resolution order:
   - **Authored**: `<source_texture>_shadow.png` next to the source PNG
     (what the exporter emits when the `.aseprite` has a shadow layer).
     Played verbatim, centered on the sprite like the body.
   - **Generated**: otherwise, unless `casts_shadow: false` in
     `modifier_terrain.json` or `DebugConfig.terrain_generated_shadows`
     is off, `generate_cast_shadow` rasterizes the sprite's own pixels
     into a cast — the same rigid 90° tip-over + squash `UnitShadow` uses
     for units (it literally calls `UnitShadow.project_silhouette`), so
     the board has one sun. Feet line = one past the art's lowest opaque
     row; pixels landing under the caster's own silhouette are erased,
     mirroring the exporter's masking; the 40% ink
     (`GameColors.CAST_SHADOW_INK`) is baked in. Cached once per texture.
     The dials are `GENERATED_SMOOSH_*` on the renderer, currently
     aliased to UnitShadow's — Lawrence's authored shelltree cast measured
     ~0.85 of sprite height vs the units' 1.0, so if generated terrain
     shadows read long, that's the knob to split.
2. **The body**: the full PNG (overhang included) centered on the
   footprint. Multi-row sprites split into one strip per footprint row
   ("interleave", the default) so a unit on a back row draws in front of
   the rows behind it; `occlude: "solid"` opts back to a single sprite.

Z per sprite: bodies at `TERRAIN_MODIFIERS` of their (south) row, shadows
at `TERRAIN_SHADOWS` — one slot up — while `SHADOWS_ABOVE_MODIFIERS` is
true, so a shadow spills onto the east neighbor's body but never tints its
own caster (masked) and is covered by anything one row south. Flip the
const to drop shadows under every body (`TERRAIN_EFFECTS`). All sprites use
`texture_filter = NEAREST`, absolute z, integer world positions, and share
one out-of-bounds fade material (`shaders/modifier_oob_fade.gdshader`) so
overhang past the map edge darkens with the floor.

> **Units cast shadows too** — generated, not authored: `UnitShadow`
> (`scripts/units/unit_shadow.gd`) rasterizes the unit's live frame onto the
> ground on the world pixel grid, speaking this section's visual language
> exactly (cast right, squat, 40% black = `GameColors.CAST_SHADOW_INK` —
> decoded from the baked `_shadow.png` decoration art). If the decoration
> shadow look ever changes, retune UnitShadow's knobs in the same pass —
> the generated terrain shadows follow automatically.

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
- **Editor preview** — the renderer is runtime-only, so in the editor
  Lawrence sees the cropped 32×32 atlas chunk with no overhang or shadow
  on either layer and has to F5 to see the real map. A `@tool` preview
  (the renderer refreshing on the layer's `changed` signal inside the
  editor) would make map painting paint-and-see.
- **Animated terrain sprites** — the exporter emits multi-frame tags as
  horizontal strips and records `frame_durations_ms`, but the renderer
  draws the whole texture as one static sprite. First animated asset
  decides the runtime shape.
- ~~Decoration-layer shadows~~ — done 2026-09-07 (shared renderer).
- ~~Tile auto-registration utility~~ — done (`tools/register_modifier_tiles.gd`).
- ~~`stamp_tiles.png`~~ — it *is* registered (source 7: the spawn +
  boundary stamps).

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
