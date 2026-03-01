# Unity → Godot Migration Plan

**Status**: Phase 6 Complete, Phase 7 Next
**Last Updated**: 2026-02-25 (Phase 7 renumbered; old 7→8, old 8→9)
**Unity Source**: `../tbt-game-unity/`

---

## Overview

Porting ~110 C# scripts (~50k lines) from Unity 6.3 to Godot 4.x with GDScript. New repo at `../tbt-game-godot/`. Includes all existing systems plus missing Alpha features.

---

## Phase Status

| Phase | Description | Status | Commit |
|-------|-------------|--------|--------|
| **0** | Project scaffolding | **COMPLETE** | `da1fb32` |
| **1** | Grid & Tile system | **COMPLETE** | `406a8b4` |
| **2** | Unit system & movement | **COMPLETE** | `b202efa` |
| **3** | Combat & type system | **COMPLETE** | `ebf9f43` |
| **4** | Game state, input, turns | **COMPLETE** | — |
| **5** | UI system | **COMPLETE** | — |
| **6** | Map pipeline & authoring | **COMPLETE** | — |
| 7 | Visual identity & HUD | **NEXT** | — |
| 8 | Missing Alpha features | pending | — |
| 9 | Polish & Steam Deck | pending | — |

### Phase Dependency Graph
```
Phase 0 (Scaffolding)  ✅
    │
Phase 1 (Grid + Tiles)  ✅
    │
Phase 2 (Units + Movement)  ✅
    │
    ├── Phase 3 (Combat)  ✅
    │                        ├── can parallel
    └── Phase 5 (UI) ←──────┘  ✅
            │
        Phase 4 (State + Input + Turns)  ✅
            │
        Phase 6 (Maps + Authoring)  ✅
            │
        Phase 7 (Visual Identity & HUD) ← NEXT
            │
        Phase 8 (Missing Alpha Features)
            │
        Phase 9 (Polish + Steam Deck)
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

## Phase 2: Unit System & Movement — COMPLETE

**Effort**: Large | **Depends on**: Phase 1

### Completed Files
- `scripts/units/character_data.gd` — 8-stat Resource with computed properties, status_modifier_* fields
- `scripts/units/character_data_loader.gd` — JSON loader for character definitions
- `scripts/units/unit.gd` + `scenes/battle/unit.tscn` — Node2D unit with faction colors, health bar, selection pulse
- `scripts/units/waypoint.gd` — Waypoint data class
- `scripts/units/path_visualizer.gd` — Path arrow visualization (needs arrow sprite — TODO)
- `scripts/combat/move.gd` — Move Resource with PP, range, damage type, status effect
- `scripts/combat/move_data.gd` — JSON loader for move bank
- `data/characters/spaceman.json` — Test player character
- `data/moves/basic_move_bank.json` — Bonk, Zap, Flame Strike, Vine Lash
- `scripts/test/phase2_test_driver.gd` — Unit spawn + movement test

---

## Phase 3: Combat & Type System — COMPLETE

**Effort**: Medium | **Depends on**: Phase 2 | **Can parallel with Phase 5**

### Completed Files
- `data/type_chart.json` — 22 type matchups (string-based keys)
- `scripts/combat/type_chart.gd` — TypeChart Resource with string-key effectiveness cache
- `scripts/combat/type_chart_manager.gd` — Autoload, dual-type combined effectiveness
- `scripts/combat/status_effect.gd` — StatusEffect RefCounted data class
- `scripts/combat/status_effect_data.gd` — Template configs for 7 effects (burn, poison, rooted, freeze, gravity, void, subversion)
- `scripts/combat/status_effect_system.gd` — Autoload, apply/process/remove effects, DoT, stat modifiers
- `scripts/combat/damage_calculator.gd` — Static damage formula, multi-hit (athleticism ratio), counter-attack eligibility
- `scripts/ui/damage_popup.gd` + `scenes/ui/damage_popup.tscn` — Pop-scale + rise + fade with effectiveness colors
- `data/characters/fire_warrior.json` — Test enemy character (Fire type, high athleticism)
- `scripts/test/phase3_test_driver.gd` — Full combat test (select, assign move, attack, status effects, type chart)
- Modified: `unit.gd` (combat sequences, defeat handling), `game_colors.gd` (effectiveness colors)

### Not Ported (deferred)
- `SimpleAttackEffects.cs` → deferred to Phase 7 (placeholder stub animations used)
- Editor tools (`type_chart_editor`, `move_database_inspector`, `move_data_editor`) → deferred to Phase 6

### Known TODOs
- Path arrow sprite needed — Artist Lawrence to design, placeholder upward arrow with rotation + 0.5 alpha in meantime
- Attack animations are stub delays (0.15s physical, 0.25s special) — real effects in Phase 7

---

## Phase 4: Game State, Input & Turn Loop — COMPLETE

**Effort**: Medium | **Depends on**: Phase 3 + Phase 5

### Completed Files
- `scripts/managers/game_state_manager.gd` — Autoload, InputState state machine with enter/exit hooks
- `scripts/managers/input_manager.gd` — Autoload, central click/key routing per game state
- `scripts/managers/turn_manager.gd` — Autoload, player/enemy phase cycle, victory/defeat, phase overlay
- `scripts/managers/action_menu_manager.gd` — Autoload, code-built action menu (moves, assign, wait, cancel)
- `scripts/combat/enemy_ai.gd` — EnemyAI node, target scoring + move-toward + attack, 3 behavior types
- `scripts/managers/camera_controller.gd` — CameraController on Camera2D, WASD/scroll/drag, smooth lerp
- `scripts/managers/battle_scene.gd` — Scene root, unit spawning, turn loop initialization
- Modified: `unit.gd` (get_usable_moves, faction-specific acted colors), `game_colors.gd` (blue/red faction colors)
- Renamed: `test_scene.tscn` → `battle_scene.tscn`

### Not Ported (deferred)
- `GameInitializer.cs` — Replaced by battle_scene.gd (hardcoded spawning, Phase 6 handles map-driven spawning)
- Full ActionMenu UI — dev-quality code-built menu used; Phase 5 builds the real one

---

## Phase 5: UI System — COMPLETE

**Effort**: Medium | **Depends on**: Phase 2 | **Can parallel with Phase 3**

Replaced dev-quality code-built UI (BattleHUD, ActionMenuManager UI, TurnManager overlays) with a proper pixel-perfect UI system using scenes, code-built Theme, and pixel fonts.

### Architecture
```
UIManager (CanvasLayer layer 10, Autoload)
  MainLayout (Control, full_rect, MOUSE_FILTER_IGNORE)
    LeftPanel (VBoxContainer, anchored left, 140px)
      UnitInfoPanel (.tscn, 140×220)
      TerrainInfoPanel (.tscn, 140×140)
    CenterArea (Control, expand_fill, MOUSE_FILTER_IGNORE)
    RightPanel (VBoxContainer, anchored right, 140px)
      ActionMenuPanel (.tscn, dynamic height)
      CombatPreviewPanel (.tscn, fills remaining space)
  OverlayLayer (CanvasLayer layer 11)
    PhaseTransitionOverlay (.tscn)
    BattleResultOverlay (.tscn)

VisualFeedbackManager (Node, Autoload)
  — pulse/flash effects on units, cancel hint
```

### Completed Files — Created
- `scripts/ui/ui_manager.gd` — Autoload, CanvasLayer layer 10, builds 140-360-140 layout, loads pixel fonts at runtime with `FontFile.new()`, code-built Theme, panel lifecycle API
- `scripts/ui/panels/unit_info_panel.gd` + `scenes/ui/panels/unit_info_panel.tscn` — PDA-styled panel: unit name, HP bar, stats grid, move, status effects
- `scripts/ui/panels/terrain_info_panel.gd` + `scenes/ui/panels/terrain_info_panel.tscn` — PDA-styled panel: terrain name, move cost (color-coded), defense modifier
- `scripts/ui/panels/action_menu_panel.gd` + `scenes/ui/panels/action_menu_panel.tscn` — Dynamic button menu with signals, main menu + assign submenu modes
- `scripts/ui/panels/combat_preview_panel.gd` + `scenes/ui/panels/combat_preview_panel.tscn` — NEW: attacker/defender preview with DMG/HIT/counter using DamageCalculator
- `scripts/ui/overlays/phase_transition_overlay.gd` + `scenes/ui/overlays/phase_transition_overlay.tscn` — Async fade in/hold/fade out phase banner
- `scripts/ui/overlays/battle_result_overlay.gd` + `scenes/ui/overlays/battle_result_overlay.tscn` — Victory/defeat stats + Continue button
- `scripts/ui/visual_feedback_manager.gd` — Autoload, pulse/flash/cancel hint effects

### Completed Files — Modified
- `project.godot` — Added UIManager + VisualFeedbackManager autoloads
- `scripts/managers/input_manager.gd` — Replaced `_get_battle_hud()` → `_get_ui_manager()`, added combat preview on attack targeting hover
- `scripts/managers/action_menu_manager.gd` — Removed code-built UI, delegates visuals to UIManager/ActionMenuPanel, connects panel signals
- `scripts/managers/turn_manager.gd` — Removed code-built overlay, delegates to UIManager for phase transitions and battle results
- `scripts/managers/battle_scene.gd` — Removed BattleHUD creation

### Completed Files — Deleted
- `scripts/ui/battle_hud.gd` — Replaced by UIManager + UnitInfoPanel + TerrainInfoPanel

### Key Decisions
- **Font loading**: Runtime `FontFile.new()` with raw byte data, not import pipeline — guarantees pixel-perfect rendering
- **Theme**: Built in code within UIManager (not .tres) for full control over pixel font sizes
- **Panel separation**: UI rendering in panel scripts, business logic stays in manager autoloads
- **Combat preview**: Real-time DamageCalculator integration during attack targeting hover

---

## Phase 6: Map Pipeline & Level Authoring — COMPLETE

**Effort**: Medium | **Depends on**: Phase 4

### Architecture

Each map = a `.tscn` scene (painted terrain) + a `.json` file (spawn data & metadata):
```
scenes/battle/maps/test_map_01.tscn    ← painted TileMapLayers
data/maps/test_map_01.json             ← unit spawns, metadata
```

Map scene node hierarchy:
```
MapRoot (Node2D) [battle_scene.gd, @export map_data_path]
  TilemapBuilder (Node2D) [tilemap_grid_builder.gd]
    TerrainTileLayer (TileMapLayer)     ← Tier 1 floor
    ModifierTileLayer (TileMapLayer)    ← Tier 2 modifiers (replace floor)
    DecorationTileLayer (TileMapLayer)  ← Tier 3 visual-only (stays visible)
  Camera2D [camera_controller.gd]
```

### Completed Files — Created
- `art/sprites/terrain/terrain_*.png` (8 files) — 32x32 colored placeholder sprites with 1px border
- `scripts/grid/map_data_loader.gd` — Static JSON loader for map definitions (MapData, SpawnData inner classes)
- `data/maps/test_map_01.json` — First test map: "Training Grounds", 10x10, 2 player + 3 enemy spawns
- `scenes/battle/maps/test_map_01.tscn` — Painted terrain: Plains dominant, Plant/Castle modifiers, Water/Rock/Desert/Road variety
- `scripts/editor/tilemap_setup_wizard.gd` — @tool EditorScript to create new map scenes with correct hierarchy + stub JSON

### Completed Files — Modified
- `resources/battle_tileset.tres` — Added `is_modifier` bool layer, 8 terrain atlas sources (Plains, Plant, Water, Castle, Rock, Road, Desert, Bridge)
- `scripts/managers/battle_scene.gd` — `@export map_data_path`, JSON-driven spawning via MapDataLoader, fallback to hardcoded spawns
- `scripts/grid/tilemap_grid_builder.gd` — Added `decoration_layer_path` export, Tier 3 decoration layer stays visible at runtime
- `project.godot` — Main scene updated to `res://scenes/battle/maps/test_map_01.tscn`

### Key Decisions
- **Map = scene + JSON**: Scene has painted tiles (visual), JSON has spawn data (logic). Easy to duplicate for new maps.
- **Three-tier TileMapLayers**: Floor (always), Modifier (replaces floor properties), Decoration (visual-only, no Tile nodes)
- **MapDataLoader mirrors CharacterDataLoader**: Same static load pattern, inner data classes, error handling
- **Backward compatible**: battle_scene.gd falls back to hardcoded spawns if `map_data_path` is empty
- **Editor wizard**: Creates new map with correct hierarchy in one click

---

## Phase 7: Visual Identity & HUD — NEXT

**Effort**: Medium | **Depends on**: Phase 6

Establish the game's visual style before building new screens in Phase 8, so everything is built in the correct style from the start.

| Area | Work |
|---|---|
| HUD panels | Apply Artist Lawrence's designs to UnitInfoPanel, TerrainInfoPanel, ActionMenuPanel, CombatPreviewPanel |
| Phase/result overlays | Style phase transition and victory/defeat overlays |
| Terrain sprites | Replace colored placeholders with real art (or improved placeholders) |
| Unit sprites | Replace colored rectangles with character art (or improved placeholders) |
| Damage popups & feedback | Style numbers, "Super Effective!" flash, effectiveness colors |
| Status effect indicators | Icons above units, turn countdown display |
| Cancel/confirm hints | Visual style for input hints |
| UI style guide | Document colors, fonts, spacing, panel patterns for Phase 8 consistency |

---

## Phase 8: Missing Alpha Features (New Development)

**Effort**: Large | **Depends on**: Phase 7

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

---

## Phase 9: Polish & Steam Deck

**Effort**: Medium | **Depends on**: Phase 8

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
