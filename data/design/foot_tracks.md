# Foot Tracks — System Design (V1)

Footprint trails left by units as they walk. Alpha sprites (no background)
that overlay the terrain on a dedicated layer, matched to the tile's terrain,
and stacked where paths cross. Lawrence delivers the art; this doc is the
contract for the importer, the renderer, and the unit hookup.

Source-of-truth status: this doc + the implementation. If they drift, fix the
doc. Sibling system:
[terrain_modifiers_and_decorations.md](terrain_modifiers_and_decorations.md)
— read it for the layer/z-index/shadow conventions this reuses.

> **Naming.** The system is **foot_tracks** throughout (code, assets, this
> doc). The word "footprint" is already taken — it means the W×H *gameplay
> rectangle* of a modifier tile ([tile.gd](../../scripts/grid/tile.gd),
> [modifier_renderer.gd](../../scripts/grid/modifier_renderer.gd)). Don't
> overload it.

---

## What it is

- A unit walking a path leaves directional foot-track sprites on the tiles it
  crossed. The trail reflects the **path actually walked**, including weird
  detours and self-crossings.
- Tracks **only** appear on a tile whose terrain has a matching track variant
  (regolith tracks on regolith). A tile whose effective terrain has no variant
  (rock, water, …) gets nothing.
- Where multiple traversals cross a tile (same unit self-crossing, or a later
  unit), tracks **stack** up to a max depth (start with **4**).
- Level designers can **hand-stamp** tracks in the editor (e.g. a trail leading
  to a unit's start tile).

## Art authoring — `foot_tracks.aseprite`

One `.aseprite` bundle. **Each tag = one terrain variant**, named
`foot_tracks_<variant>` (`foot_tracks_regolith`, `foot_tracks_snow`, …); the
`foot_tracks_` prefix is stripped on export. Each variant is a **single frame**
in one shared canvas (currently 160×160 = 5×5 cells). A variant's frame holds a
fixed 32×32 grid of directional cells anchored at the **top-left**, laid out
left-to-right, top-to-bottom; the spare 5th row/column (bottom-right) is "extra
room" for future directions. The importer slices by the fixed map below, not by
content (verified against the shipped art — occupancy matches exactly):

```
        col0    col1    col2    col3
row0     E       S       W       N
row1     SE      WE      WS      ·
row2     SN      ·       NS      ·
row3     EN      EW      NW      ·
```

**Direction semantics** (sprites are direction-agnostic — one sprite serves
both traversal senses):

| Cells | Meaning | Count |
|---|---|---|
| `E S W N` | **Endpoint** — unit started here and left that way, or entered from that side and stopped | 4 cardinals |
| `SE WS EN NW` | **Corner** — entered one side, turned out another. `SE`={S,E}, `WS`={W,S}, `EN`={E,N}, `NW`={N,W} | 4 corners |
| `SN`/`NS` | **Straight N–S** pass-through — two interchangeable variants | 2 |
| `WE`/`EW` | **Straight E–W** pass-through — two interchangeable variants | 2 |

The straight pairs are doubled on purpose: a unit walking 2+ tiles in a line
**alternates or randomizes** between the two so a corridor doesn't read as a
repeating texture (see *Unit hookup*). Corners and cardinals have a single
sprite each.

**Future (design now so it's not painful later):**
- **Animation** — per-tag (per-variant). Adds a frame axis: extra columns in
  the exported atlas. The importer's sidecar carries `frame_durations_ms`
  exactly as the character/modifier exporter already does.
- **Shadow** — a dedicated `Shadow` layer, detected by the existing
  name/content rules ([context_menu.gd `_detect_shadow_layer`](../../addons/aseprite_tag_exporter/context_menu.gd))
  and emitted as a paired `_shadow` atlas. Reuse that code; don't reinvent it.

## Importer

A **second context-menu action** ("Export Foot Tracks") in the existing addon
— **not** an extension of "Export Tags as PNGs". The tag exporter is built
around content-bbox trimming; foot tracks need fixed-grid slicing, the
opposite. The two share plumbing, not the export function.

**Reused verbatim** (static helpers in
[context_menu.gd](../../addons/aseprite_tag_exporter/context_menu.gd)):
`_parse_tags` (variants = tags), `_get_aseprite_command`, the untrimmed
full-canvas `--save-as {frame0000}.png` CLI pass, `_cleanup_temp`,
`_blit_with_offset`/`Image.blit_rect`, and (for future shadows) `_parse_layers`
+ `_detect_shadow_layer`.

**New code:** the fixed-grid slicer. Variant name = tag name with the
`foot_tracks_` prefix stripped (`foot_tracks_regolith` → `regolith`). For each
variant, load its (single, untrimmed) frame and copy the named 32×32 cells per
the grid map above.

**Hard rule: never trim.** Trimming destroys grid alignment. Always export the
full canvas and slice by fixed cell offsets.

**CLI quirk (project memory):** `--tag` / `--list-tags` are broken in our
Aseprite build. Don't filter by tag at the CLI — do the untrimmed full-canvas
export and isolate each variant's frame range in GDScript, same workaround the
tag exporter already uses.

**Output** — sibling folder named after the file (matches existing
convention), one atlas + sidecar per variant:

```
art/sprites/decorations/foot_tracks.aseprite
art/sprites/decorations/foot_tracks/
    regolith.png      # atlas: the variant's frame as-is (5×5 grid), NEAREST
    regolith.json     # {"cell_size":32,"cells":{"E":[0,0],...,"NW":[2,3]}}
    snow.png
    snow.json
```

(The folder is the file's sibling, named after it — the existing exporter
convention. After the `foot_tracks.aseprite` rename follow-up it lands under
`art/sprites/decorations/`; once the asset itself moves, output moves with it.)

One atlas-per-variant (not 12 PNGs per variant) because it feeds **both** sinks
from one texture: a `TileSetAtlasSource` for the stamp layer, and `AtlasTexture`
regions at runtime — exactly how the beacon strip is consumed in
[path_visualizer.gd](../../scripts/units/path_visualizer.gd). The sidecar's
`cells` map is the single source of direction→atlas-coord for registration and
runtime. (`frame_durations_ms` / `shadow_path` are reserved for the future
animation / shadow extensions.)

## Terrain matching

The variant for a tile is chosen by the tile's **effective** terrain —
`tile.terrain_type_name` ([tile.gd:13](../../scripts/grid/tile.gd#L13)), which
already reflects a modifier override under the three-tier rule. So:
`Regolith` floor → `regolith` variant; `Sand`-on-`Regolith` → `sand` variant
(and if no `sand` variant exists yet, no tracks). A miss renders **nothing,
silently** — a missing variant for water/lava is normal, not the modifier
"unknown → impassable + warning" case.

Lookup is **case-insensitive** (tags are lowercase, terrain keys are PascalCase
— `regolith` → `Regolith`), plus an **explicit override map** for the cases
where a variant doesn't 1:1 a terrain name. That map is needed today:
`Regolith` matches by name, but **`snow` matches no terrain** — the only
`Snow` in [terrain_data.json](../../data/terrain_data.json) is a *status
effect*, not a terrain. The snowy terrains are `PolarIce` / `Tundra` / `Taiga`
/ `ColdDesert`, so `snow`'s targets must be declared (one variant may map to
several terrains). Until that's set, `snow` simply renders nothing — building
isn't blocked.

## Z-index

Add a dedicated slot in
[ZIndexCalculator.ZIndexLayer](../../scripts/core/z_index_calculator.gd),
inserted **between `FLOOR_TILES` and `TERRAIN_EFFECTS`** so a modifier's cast
shadow draws over the tracks beneath it:

```
FLOOR_TILES = 0
FOOT_TRACKS = 1   # new
TERRAIN_EFFECTS = 2
TERRAIN_MODIFIERS = 3
PURE_DECORATIONS = 4
PATH_INDICATORS = 5
UNITS = 6
UNIT_EFFECTS = 7
UI = 8
```

Change list (everything else references the enum *by name* and updates
automatically):
1. The enum (above).
2. `decode_z_index` match table — add `FootTracks`, renumber.
3. Stale comment at [battle_scene.gd:174](../../scripts/managers/battle_scene.gd#L174)
   (`ZIndexLayer.UNITS = 5` → 6).

No `.tscn` changes (no scene hardcodes tile-layer z). This consumes the
penultimate enum slot (`9` remains free); a future mid-stack layer would force
widening the formula's `*10`.

> Do **not** use the calculator's `fine` parameter for intra-cell stacking —
> it's accepted, clamped, then dropped by the formula, and there's no bit room
> for it. Stacking order is handled by sprite draw order instead (below).

## Rendering — `FootTrackRenderer`

Implemented as [FootTrackRenderer](../../scripts/foot_tracks/foot_track_renderer.gd),
a `Node2D` at the world root (created by BattleScene) owning per-cell `Sprite2D`
overlays. Each sprite uses `texture_filter = NEAREST`, `z_as_relative = false`,
and absolute per-row z via `ZIndexCalculator.calculate_sorting_order(row, _,
FOOT_TRACKS)` with `row = tile.grid_y − GridManager.grid_offset_y`.

- **One sprite per track.** A track = one (cell, variant, direction) instance.
- **Stacking.** Multiple tracks in a cell are siblings at the same z; later-
  added draws on top → newest-on-top automatically, no z math. A **per-cell
  depth stack** (`_cell_stacks`) enforces the cap (`max_depth`, default 4);
  when full, the **oldest** is dropped (`pop_front` + `queue_free`). A runtime
  assert guards the invariant.
- **Persistence (tunable).** `Persistence` enum exported; V1 wires only
  `WHOLE_BATTLE` (`FADE_AFTER_TURNS` / `CLEAR_EACH_TURN` are reserved knobs that
  need turn signals). Keeping tracks as individual sprites (not a baked texture)
  is what makes a tunable persistence possible; `clear_all()` drops them all.
- **Performance.** All tracks read from a few per-variant atlases → 2D draw-call
  batching applies. Worst case (full map × depth 4) is a few thousand trivial
  sprites — fine on Steam Deck. Revisit (MultiMeshInstance2D per variant) only
  if profiling ever says so.

## Stamp tiles (editor authoring)

Designers paint seed tracks on a `TileMapLayer` named **`FootTrackTileLayer`**
in the map scene (depth-1 only — a tilemap holds one tile per cell). At scene
load BattleScene finds that layer and calls
`FootTrackRenderer.ingest_seed_layer`, which turns each painted cell into a
depth-1 track the runtime then stacks onto.

Ingestion is registration-light: the **source texture's filename is the
variant** (`regolith.png` → `regolith`) and the **painted atlas coord is the
direction** (reverse-looked-up via the sidecar `cells` map). No separate
source→variant table is needed — just paint from the variant's atlas.

The one **manual editor step** (V1, same as the modifier system): register each
variant atlas as a `TileSetAtlasSource` and create its 12 directional tiles so
the layer is paintable. A Phase-2 utility could read the sidecars and do this
automatically. Runtime tracks stack onto seeded cells up to the depth cap (no
de-dup in V1 — re-walking a seeded cell just adds another track).

## Unit hookup

Tracks are laid from the **committed** path at
`execute_planned_movement` → `_move_along_path`
([unit.gd:289](../../scripts/units/unit.gd#L289),
[unit.gd:347](../../scripts/units/unit.gd#L347)) — not the preview path.

**Track sequence = `[start_tile] + walked_path`.** `find_path` excludes the
start tile, so prepend `current_tile` (pre-move) to give the first tile its
exit-only cardinal. Build the path with the beacon's **duplicate-preserving**
construction ([path_visualizer.gd:50-57](../../scripts/units/path_visualizer.gd#L50-L57))
so self-crossings yield stacked tracks in walked order.

**Direction per tile** from grid-coord deltas:
- `entry = cur − prev` (null at the start tile), `exit = next − cur` (null at
  the final tile).
- One side null → **endpoint** cardinal (`N`/`E`/`S`/`W`).
- Perpendicular entry/exit → **corner** (`{N,E}`→`EN`, `{N,W}`→`NW`,
  `{S,E}`→`SE`, `{S,W}`→`WS`).
- Colinear → **straight**: N–S → `SN`/`NS`, E–W → `WE`/`EW`. Pick the variant
  by the **alternate / randomize toggle** (config flag). `alternate` toggles
  along the run (deterministic, zero RNG); `randomize` draws from a **dedicated
  cosmetic `RandomNumberGenerator`** — never the gameplay RNG, or it perturbs
  crit/AI sequences.

**Wiring (implemented):** `Unit` captures the walk (`[start_tile] +
full_path`) into `_pending_track_tiles` during `execute_planned_movement`, but
emits `path_traversed(unit, tiles)` only from **`set_acted()`** — the move's
commit point (both factions route through it). `cancel_movement()` drops the
stash. So a *tentative* move that the player undoes with Escape lays no tracks;
tracks appear when the action is committed. BattleScene connects each unit to
`FootTrackRenderer` via `register_battle_units`, mirroring `PassiveEffectsSystem`.

Laying per-tile in sync with the tween (tracks appearing underfoot as you walk)
is deferred — and would be revisited by the ghost-unit refactor below, which
makes commit-time laying look natural (real unit + tracks both appear on
commit).

## Testing

Shipped with both (per project policy):
- **Unit tests** (GUT, `tests/unit/`):
  [test_foot_track_directions.gd](../../tests/unit/test_foot_track_directions.gd)
  (path→label: endpoints, corners, both straight variants, self-crossing,
  U-turn collapse) and
  [test_foot_track_library.gd](../../tests/unit/test_foot_track_library.gd)
  (terrain→variant: name-match, miss, override, override-to-missing, precedence).
- **Integration test**:
  [test_foot_track_renderer.gd](../../tests/unit/test_foot_track_renderer.gd)
  drives `lay_path`/`ingest_seed_layer` against the real loaded library — sprite
  count, terrain-skip, single-tile no-op, depth cap, seed ingest.
- **Runtime assert**: the per-cell depth-cap invariant in `_spawn_at`.

## Open items / follow-ups

- **Legacy asset cleanup** — the new source is
  `art/sprites/decorations/foot_tracks.aseprite` (exports to `…/foot_tracks/`).
  The old `footprints.aseprite` is superseded and can be removed. Optionally
  relocate the source to `art/sprites/foot_tracks/` (the importer names the
  output folder after the file). Art-owned — coordinate with Lawrence.
- **Tile registration** — V1 manual (like modifiers): register each variant
  atlas as a `TileSetAtlasSource` with its 12 directional tiles so the
  `FootTrackTileLayer` is paintable. A Phase-2 utility could auto-register from
  the sidecars.
- **Animation** and **shadow** support — deferred; the importer/atlas/sidecar
  shapes above are designed to absorb them without a rewrite.
- **Depth cap + persistence values** — 4 and "whole battle" are starting
  points; both are playtest knobs.
- **Ghost-unit move preview (significant refactor)** — instead of physically
  moving the unit on plan and snapping it back on cancel, have a translucent
  "ghost" (candidate: the projection effect) preview the path; the real unit
  only walks on commit. Would supersede the current tentative-move/`set_acted`
  track timing (commit-time laying becomes the natural, synced moment) and
  remove the snap-back entirely. Scoped as its own task.
- **`snow` → terrain mapping** — which terrain(s) the `snow` variant covers
  (`PolarIce` / `Tundra` / `Taiga` / `ColdDesert`, or a new `Snow` terrain).
  Lawrence/design call; fills the override map in
  [foot_track_terrain.json](../../data/foot_track_terrain.json). `regolith`
  already matches by name. (The `snow` atlas already ships; it renders nothing
  until mapped.)

## Implementation map

| Piece | File |
|---|---|
| Importer action | [context_menu.gd](../../addons/aseprite_tag_exporter/context_menu.gd) — `_export_foot_tracks*`, `FOOT_TRACK_CELLS` |
| z-index slot | [z_index_calculator.gd](../../scripts/core/z_index_calculator.gd) — `FOOT_TRACKS` |
| Direction logic | [foot_track_directions.gd](../../scripts/foot_tracks/foot_track_directions.gd) |
| Variant/terrain + atlas | [foot_track_library.gd](../../scripts/foot_tracks/foot_track_library.gd) |
| Renderer + seed ingest | [foot_track_renderer.gd](../../scripts/foot_tracks/foot_track_renderer.gd) |
| Override map | [foot_track_terrain.json](../../data/foot_track_terrain.json) |
| Movement signal | [unit.gd](../../scripts/units/unit.gd) — `path_traversed` |
| Scene wiring | [battle_scene.gd](../../scripts/managers/battle_scene.gd) |
| Variant assets | `art/sprites/decorations/foot_tracks/{regolith,snow}.{png,json}` |
