# Unity → Godot Migration Plan

**Status**: Phase 1 Complete, Phase 2 Next
**Last Updated**: 2026-02-22
**Unity Source**: `../tbt-game-unity/`

---

## Overview

Porting ~110 C# scripts (~50k lines) from Unity 6.3 to Godot 4.x with GDScript. New repo at `../tbt-game-godot/`. Includes all existing systems plus missing Alpha features.

---

## Phase Status

| Phase | Description | Status | Commit |
|-------|-------------|--------|--------|
| **0** | Project scaffolding | **COMPLETE** | `da1fb32` |
| **1** | Grid & Tile system | **COMPLETE** | — |
| **2** | Unit system & movement | **NEXT** | — |
| 3 | Combat & type system | pending | — |
| 4 | Game state, input, turns | pending | — |
| 5 | UI system | pending | — |
| 6 | Map pipeline & authoring | pending | — |
| 7 | Missing Alpha features | pending | — |
| 8 | Polish & Steam Deck | pending | — |

### Phase Dependency Graph
```
Phase 0 (Scaffolding)  ✅
    │
Phase 1 (Grid + Tiles)  ✅
    │
Phase 2 (Units + Movement) ← NEXT
    │
    ├── Phase 3 (Combat) ←──┐
    │                        ├── can parallel
    └── Phase 5 (UI) ←──────┘
            │
        Phase 4 (State + Input + Turns) ← needs both 3 and 5
            │
        Phase 6 (Maps + Authoring)
            │
        Phase 7 (Missing Alpha Features)
            │
        Phase 8 (Polish + Steam Deck)
```

---

## Phase 0: Project Scaffolding — COMPLETE

Created:
- `project.godot` — 640x360, canvas_items stretch, nearest filter, input map
- `scripts/core/debug_config.gd` — Autoload, flag-based logging
- `scripts/core/enums.gd` — All game enums (`class_name Enums`)
- `scripts/core/z_index_calculator.gd` — Row-based z-index for Godot range
- `scripts/core/game_color_palette.gd` — GPL palette file loader
- `scripts/core/game_colors.gd` — Semantic color constants
- `art/colors/SpacemanColorPalette_v1.41.gpl` — Artist's palette (copied)

---

## Phase 1: Grid & Tile System — COMPLETE

**Effort**: Medium | **Depends on**: Phase 0

### Key Architectural Decision: Tilemap Pipeline Redesign

Unity's approach was a 1253-line `TilemapToGameObjectSync` using reflection hacks to convert painted tilemaps to logic GameObjects. **This is NOT ported.** Instead:

- Godot `TileMapLayer` with custom data layers (`terrain_type: String`, `is_modifier: bool`)
- Two layers: floor (Tier 1) + modifiers (Tier 2)
- New `tilemap_grid_builder.gd` reads TileMapLayer at runtime → creates Tile nodes
- Three-tier rule preserved: modifier at (x,y) completely replaces floor properties
- Much cleaner than Unity's approach

### Files to Port/Create

| Unity Source | Godot Target | Notes |
|---|---|---|
| `TerrainDataStructures.cs` + `TerrainDataManager.cs` | `scripts/grid/terrain_data_manager.gd` (Autoload) | JSON via `JSON.parse_string()` |
| `Tile.cs` (375 lines) | `scripts/grid/tile.gd` + `scenes/battle/tile.tscn` | Node2D + Sprite2D. No Area2D. |
| `GridManagerV2.cs` (950 lines) | `scripts/grid/grid_manager.gd` (Autoload) | A* and BFS port 1:1 |
| `PathNode.cs` | `scripts/grid/path_node.gd` | Data class |
| `GridZIndexHandler.cs` | `scripts/grid/grid_z_index_handler.gd` | Sets node.z_index |
| *(new)* | `scripts/grid/tilemap_grid_builder.gd` | Reads TileMapLayer → Tile nodes |

**Copy**: `terrain_data.json` from `../tbt-game/Assets/StreamingAssets/` to `data/`

**Editor tool**: `z_index_inspector.gd` (@tool) — decode z_index values in inspector

**Verify**: Paint tilemap in editor, run, see grid with z-ordering. `GridManager.get_tile(x, y)` works.

### Completed Files
- `scripts/grid/terrain_data_manager.gd` — Autoload, JSON parser, unit-type-conditional lookups
- `scripts/grid/tile.gd` + `scenes/battle/tile.tscn` — Node2D tile with terrain property queries
- `scripts/grid/grid_manager.gd` — Autoload, Dictionary-based grid, BFS movement range, A* pathfinding
- `scripts/grid/path_node.gd` — A* data class
- `scripts/grid/grid_z_index_handler.gd` — Row-based z_index management
- `scripts/grid/tilemap_grid_builder.gd` — Reads TileMapLayer at runtime, spawns Tile nodes, three-tier rule
- `scripts/editor/z_index_inspector.gd` — @tool EditorScript for decoding z_index
- `data/terrain_data.json` — Copied from Unity project

### Still Needs (Editor Setup by User)
- TileSet with custom data layer `terrain_type` (String)
- TileMapLayer nodes painted in test_scene.tscn
- Tile sprite assigned in tile.tscn

---

## Phase 2: Unit System & Movement

**Effort**: Large | **Depends on**: Phase 1

| Unity Source | Godot Target |
|---|---|
| `CharacterData.cs` (510 lines) | `scripts/units/character_data.gd` (Resource) |
| `CharacterDataLoader.cs` + `CharacterDataJson.cs` | `scripts/units/character_data_loader.gd` |
| `Unit.cs` (1617 lines) | `scripts/units/unit.gd` + `scenes/battle/unit.tscn` |
| `Waypoint.cs` | `scripts/units/waypoint.gd` |
| `PathVisualizer.cs` | `scripts/units/path_visualizer.gd` |
| `Move.cs` | `scripts/combat/move.gd` (Resource) |
| `MoveData.cs` + `MoveDataJson.cs` | `scripts/combat/move_data.gd` |

Key pattern: All Unity coroutines → `await` + `create_tween()`

**Verify**: Place units, click to select, see movement range, waypoints, animated movement.

---

## Phase 3: Combat & Type System

**Effort**: Medium | **Depends on**: Phase 2 | **Can parallel with Phase 5**

| Unity Source | Godot Target |
|---|---|
| `TypeChart.cs` | `scripts/combat/type_chart.gd` (Resource) |
| `TypeChartManager.cs` | `scripts/combat/type_chart_manager.gd` (Autoload) |
| `StatusEffectSystem.cs` (555 lines) | `scripts/combat/status_effect_system.gd` (Autoload) |
| `StatusEffectConfig.cs` + `StatusEffectDatabase.cs` | `scripts/combat/status_effect_data.gd` |
| `MoveDatabase_V2.cs` | `scripts/combat/move_database.gd` |
| `DamagePopup.cs` | `scripts/ui/damage_popup.gd` + scene |
| `SimpleAttackEffects.cs` | `scripts/combat/attack_effects.gd` |

**Editor tools**: `type_chart_editor.gd`, `move_database_inspector.gd`, `move_data_editor.gd`

**Verify**: Attack deals correct damage with type multiplier, multi-hit plays, counter-attacks fire.

---

## Phase 4: Game State, Input & Turn Loop

**Effort**: Medium | **Depends on**: Phase 3 + Phase 5

| Unity Source | Godot Target |
|---|---|
| `GameState.cs` | `scripts/managers/game_state_manager.gd` (Autoload) |
| `InputManager.cs` (662 lines) | `scripts/managers/input_manager.gd` (Autoload) |
| `TurnManager.cs` (627 lines) | `scripts/managers/turn_manager.gd` (Autoload) |
| `EnemyAI.cs` (279 lines) | `scripts/combat/enemy_ai.gd` |
| `ActionMenuManager.cs` + `ActionMenu.cs` | `scripts/managers/action_menu_manager.gd` + scene |
| `CameraController.cs` (360 lines) | `scripts/managers/camera_controller.gd` (Camera2D) |
| `GameInitializer.cs` | `scripts/managers/game_initializer.gd` |

**Verify**: Full battle loop — select unit → move → attack → enemy phase → victory/defeat.

---

## Phase 5: UI System

**Effort**: Medium | **Depends on**: Phase 2 | **Can parallel with Phase 3**

Godot UI layout (replaces Unity Canvas):
```
CanvasLayer
  Control (full screen)
    HBoxContainer (140-360-140)
      PanelContainer (left, min_width=140)
      Control (center, expand_fill)
      PanelContainer (right, min_width=140)
    OverlayContainer (full screen, hidden)
```

Pixel-perfect rendering is FREE in Godot — `canvas_items` stretch + nearest filter. No custom renderer needed.

| Unity Source | Godot Target |
|---|---|
| `UIManager.cs` (490 lines) | `scripts/ui/ui_manager.gd` (Autoload) + scene |
| `UnitInfoPanel.cs` | `scripts/ui/panels/unit_info_panel.gd` + scene |
| `TerrainInfoPanel.cs` | `scripts/ui/panels/terrain_info_panel.gd` + scene |
| `CombatPreviewPanel.cs` | `scripts/ui/panels/combat_preview_panel.gd` + scene |
| `PhaseTransitionOverlay` | `scripts/ui/overlays/phase_transition_overlay.gd` |
| `BattleResultOverlay` | `scripts/ui/overlays/battle_result_overlay.gd` |
| `VisualFeedbackManager.cs` | `scripts/ui/visual_feedback_manager.gd` (Autoload) |
| `FontManager.cs` | Theme resource — no script needed |

---

## Phase 6: Map Pipeline & Level Authoring

**Effort**: Medium | **Depends on**: Phase 4

- TileSet resource with custom data layers for terrain types
- Map scene template (TileMapLayers + Units + Camera + UI)
- Decoration system (third TileMapLayer or scatter script)
- First test map: 10x10, mixed terrain, 2 player + 3 enemy units

**Editor tools**: `tilemap_setup_wizard.gd`, `decoration_placer_editor.gd`

---

## Phase 7: Missing Alpha Features (New Development)

**Effort**: Large | **Depends on**: Phase 6

These were never built in Unity — fresh GDScript:

| Feature | Notes |
|---|---|
| Victory/defeat screens | Stats: turns, damage, units lost |
| Map select screen | 4 maps at levels 5/20/40/60 |
| Preparation screen | Squad, moves, passives, stat distribution |
| Stat allocation UI | +/- per stat, caps, points counter |
| Enemy auto-leveling | Simulate growth rolls to target level |
| Passive system | Real PassiveData with bonuses |
| Move database (20+) | 2-3 per element type minimum |
| Type effectiveness feedback | "Super Effective!" flash |
| Status effect indicators | Icons, turn countdown |

---

## Phase 8: Polish & Steam Deck

**Effort**: Medium | **Depends on**: Phase 7

- Controller support (D-pad cursor, A/B/X/Y)
- Scene flow (menu → select → prep → battle → result → loop)
- Save/load between sessions
- Audio hook stubs
- 60fps at 1280x800 (Steam Deck)

---

## Editor Tools Summary

| Tool | Port? | Phase |
|---|---|---|
| GridManagerV2Editor | Yes (@tool) | 1 |
| ZIndexInspector | Yes (@tool) | 1 |
| UnitPlacementHelper | Yes (@tool) | 2 |
| TypeChartEditor | Yes (@tool) | 3 |
| MoveDatabase_V2_Inspector | Yes (@tool) | 3 |
| MoveDataEditor | Yes (@tool) | 3 |
| DecorationPlacerEditor | Yes (@tool) | 6 |
| TilemapSetupWizard | Redesign (@tool) | 6 |
| CombatPreviewPanelEditor | Yes (@tool) | 5 |
| ColorPaletteCreator | Skip | — Godot native |
| ColorPaletteEditor | Skip | — use .tres |
| PixelPerfectUISetup | Skip | — Godot native |
| TilesetImporter | Skip | — Godot TileSet editor |
| ResetSortingOrders | Skip | — trivial in Godot |
| AutoFixVSCode | Skip | — not applicable |
| PrefabCreator | Skip | — Unity bug workaround |
| LevelDesignTools | Skip | — empty stub |
| MoveDataListPropertyDrawer | Skip | — empty stub |

---

## Non-Negotiable Constraints

- **Integer coordinates** — (0,0), (1,0), (2,0)... NO 0.5 offsets
- **640x360 reference** — Integer scaling (2x, 3x, 4x)
- **Three-tier system** — Modifiers COMPLETELY REPLACE floor properties
- **Moves, not weapons** — Pokemon-style, 4 equipped
- **8-stat system** — HP, Str, Spc, Skl, Agi, Ath, Def, Res
- **Steam Deck primary target**
- **MOVEMENT_SCALE = 2** — Internal half-tile precision
