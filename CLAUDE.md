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

`DebugConfig`, `TerrainDataManager`, `GridManager`, `GameStateManager`, `InputManager`, `TurnManager`, `ActionMenuManager`, `TypeChartManager`, `StatusEffectSystem`, `UIManager`, `VisualFeedbackManager`

## Key Reference Files

When porting a system, read the Unity source first:
- Grid: `../tbt-game/Assets/Scripts/Grid/GridManagerV2.cs`
- Units: `../tbt-game/Assets/Scripts/Units/Unit.cs`
- Combat: `../tbt-game/Assets/Scripts/Units/Unit.cs` (lines 874-1615)
- Turns: `../tbt-game/Assets/Scripts/Managers/TurnManager.cs`
- UI: `../tbt-game/Assets/Scripts/UI/UIManager.cs`
- Design docs: `../tbt-game/Assets/Docs/`
