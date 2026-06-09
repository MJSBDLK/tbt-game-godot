# TBT Game — Godot 4.x Port

**Tactical Battle RPG** (Pokemon meets Fire Emblem) being ported from Unity 6.3 to Godot 4.x with GDScript.

**Unity source project**: `../tbt-game/` — reference for porting but never modify it.

## Current Focus

This project is an **active port** from Unity. See `.claude/migration.md` for the full phased migration plan and current progress. See `.claude/alpha.md` for the Alpha milestone goals.

**Before starting any task**: Check `.claude/migration.md` to see which phase we're in and what's next.

## Critical Rules

Read `.claude/guide.md` for the full agent guide. These rules are non-negotiable:

1. **Integer coordinates only** — Tiles at (0,0), (1,0), (2,0). NEVER use 0.5 offsets.
2. **Three-tier sprite system** — Modifiers COMPLETELY REPLACE floor properties. Never additive.
3. **Moves, not weapons** — Units equip 4 moves (Pokemon-style). No weapon inventory.
4. **640x360 reference resolution** — Integer scaling only (2x, 3x, 4x). Steam Deck primary target.
5. **No abbreviated variable names** — `player_health` not `plyr_hlth`.

## Code Style

- GDScript, not C#
- snake_case for variables/functions, PascalCase for class_name only
- Use signals for decoupling, not direct node references where possible
- Use `await` + `create_tween()` for animations (replaces Unity coroutines)
- Use `class_name` for globally-accessible types
- Autoload singletons for managers (replaces Unity's FindObjectOfType pattern)
- Prefer `@export` over hardcoded values
- Full variable names, no abbreviations

## Project Structure

```
res://
  scripts/core/       # enums.gd, debug_config.gd, z_index_calculator.gd, game_colors.gd
  scripts/grid/       # tile.gd, grid_manager.gd, terrain_data_manager.gd
  scripts/units/      # unit.gd, character_data.gd, path_visualizer.gd
  scripts/combat/     # move.gd, type_chart.gd, status_effects.gd, enemy_ai.gd
  scripts/managers/   # turn_manager.gd, input_manager.gd, game_state_manager.gd
  scripts/ui/         # ui_manager.gd, panels/, overlays/
  scripts/editor/     # @tool scripts
  scenes/             # .tscn files
  resources/          # .tres files (type chart, character data)
  data/               # JSON (terrain_data.json, characters/, moves/)
  art/                # sprites, tilesets, UI assets
  fonts/
```

## Autoloads

`DebugConfig`, `SceneRouter`, `TerrainDataManager`, `GridManager`, `GameStateManager`, `InputManager`, `TurnManager`, `ActionMenuManager`, `TypeChartManager`, `StatusEffectSystem`, `UIManager`, `VisualFeedbackManager`

## Rendering Architecture

Dual-pipeline rendering with project stretch mode set to **disabled**. Three
render targets, each with one explicit scaling rule. See
[.claude/zoom-arch.md](.claude/zoom-arch.md) for the full rationale.

- **World** renders directly to the root viewport at native window resolution.
  `Camera2D.zoom` = screen pixels per world pixel. At `zoom = N`, each world
  pixel takes N screen pixels — always an integer multiple for crisp rendering.
  Default zoom on first load = monitor's integer scale (3 on 1080p, 2 on Steam
  Deck, 4 on 1440p, 6 on 4K) — visually matches the 640×360 reference at 1:1.
- **HUD** renders into a `HUDViewport` SubViewport sized `window / integer_scale`
  (≥640×360, grows on either axis at non-standard window aspects). Displayed
  via `HUDDisplay` (TextureRect, NEAREST filter, fills window — no letterbox).
  Panels use Control anchors to stick to corners/centers; the canvas grows with
  the window so anchored panels visually hug actual screen edges.
- **HDLayer** is a CanvasLayer at the root viewport (native pixel space) for
  HD overlays like line-art portraits.
- **InputRouter** forwards root-viewport events into HUDViewport with coord
  remap. Events the HUD consumes are blocked at root so the world doesn't
  also react.

Key API rules:

- `SceneRouter.change_scene_to(path)` for scene transitions — **not**
  `get_tree().change_scene_to_file()`. Scenes route by root type: Node2D/Node3D
  → WorldRoot (rendered with camera), Control → HUDViewport (640×360 design
  canvas).
- `SceneRouter.get_world_camera()` to find the active Camera2D. It lives at the
  root viewport now; UIManager and other HUD-side code can't reach it via
  `get_viewport().get_camera_2d()` because their viewport is HUDViewport.
- `SceneRouter.get_hud_display()` + `get_hud_scale()` for HUD↔native pixel coord
  math (used by HDPortraitSlot and anything projecting world→HUD positions).
- [HDPortraitSlot](scripts/ui/hd_portrait_slot.gd) reserves space inside the
  pixel UI for an HD texture. The slot's mirror in HDLayer is positioned via
  explicit `hud_display.position + slot.global_position × hud_scale` projection,
  not the old "same coord space" assumption.
- `UIManager` and `VisualFeedbackManager` are reparented into HUDViewport at
  startup by GameRoot. Access them through the autoload singleton name
  (`UIManager.foo()`), never via `get_node("/root/UIManager")` — the path no
  longer resolves.
- HD assets (large textures rendered into HDLayer) should have
  `mipmaps/generate=true` in their .import file to avoid aliasing on bilinear
  downscale.

UI authoring rule: **use Control anchors, don't hardcode positions to 640×360**.
The HUD canvas grows wider/taller than 640×360 when the window aspect doesn't
match the reference. Panels with `anchors_preset = 15` fill the canvas
correctly. Panels with fixed positions (e.g., `Vector2(640, ...)`) won't span
the full HUD on non-1080p monitors.

## Key Reference Files

When porting a system, read the Unity source first:
- Grid: `../tbt-game/Assets/Scripts/Grid/GridManagerV2.cs`
- Units: `../tbt-game/Assets/Scripts/Units/Unit.cs`
- Combat: `../tbt-game/Assets/Scripts/Units/Unit.cs` (lines 874-1615)
- Turns: `../tbt-game/Assets/Scripts/Managers/TurnManager.cs`
- UI: `../tbt-game/Assets/Scripts/UI/UIManager.cs`
- Design docs: `../tbt-game/Assets/Docs/`

## UI Style

Before any UI work, read [data/design/ui-style-guide.md](data/design/ui-style-guide.md). It's the
source of truth for palette use, typography, panel components, icon sizes, and the
TBD/LOCK status of every visual decision. Don't hardcode hex values — reach for
`GameColorPalette`. Don't introduce non-integer pixel sizing in gameplay UI.

## Terrain Modifiers & Decorations

Before touching the modifier/decoration sprite pipeline, layer architecture,
shadow rendering, or tile registration, read
[data/design/terrain_modifiers_and_decorations.md](data/design/terrain_modifiers_and_decorations.md).
Source of truth for Lawrence's `.aseprite` authoring conventions, the
TileMapLayer semantics (paint-layer determines gameplay vs. visual-only), and
the runtime shadow renderer.
