# Spawn Tile Layer System

## Context

Visual, editor-paintable spawn system using a 4th TileMapLayer ("SpawnTileLayer") with stamp tiles.
- **Player spawns**: Blue "P" tiles painted in the editor. Eventually players place units on these via a GUI.
- **Enemy spawns**: Red "E" tiles painted in the editor. Eventually semi-random/procedural based on difficulty (design doc needed later).

## Implementation Status

- [x] **Create spawn tile art** — expanded `stamp_tiles.png` to 96x32 (col 0=Regolith, col 1=Player blue "P", col 2=Enemy red "E")
- [x] **Add spawn tiles to `tileset_terrain_setup.gd`**
  - Added `spawn_faction` custom_data layer (index 2, type String) alongside existing `terrain_type` and `is_modifier`
  - Added spawn stamp tiles to `STAMP_TILES` array: `[1, "", false, "Player"]` and `[2, "", false, "Enemy"]`
  - Updated stamp tile creation to write `spawn_faction` custom_data on spawn tiles
- [x] **Add SpawnTileLayer to `tilemap_grid_builder.gd`**
  - Added `@export var spawn_layer_path: NodePath = ^"SpawnTileLayer"`
  - `get_spawn_points() -> Dictionary` returns `{"Player": Array[Vector2i], "Enemy": Array[Vector2i]}` in game-grid coords (Y-flipped)
  - Spawn layer hidden at runtime (`_spawn_layer.visible = false`)
  - Does NOT modify `_build_grid()` — spawns are read separately by battle_scene
- [x] **Wire spawn points into `battle_scene.gd`**
  - Added `@export var default_player_character` and `default_enemy_character` for tile-based spawns (tiles specify location + faction, not which character)
  - Spawn priority: tile-based spawns > JSON map data > hardcoded fallback
  - Finds TilemapGridBuilder via `_find_grid_builder()` (searches children, then siblings)
- [x] **Update `tilemap_setup_wizard.gd`** — SpawnTileLayer added to generated scene tree
- [x] **Paint spawn tiles on `test_map_01.tscn`**
  - 2 player spawns (grid 1,2 and 1,5) + 3 enemy spawns (grid 7,2 / 8,5 / 7,7)
  - Matching current JSON positions so behavior is identical

## Testing TODO

- [ ] Run `tileset_terrain_setup.gd` editor script (Ctrl+Shift+X) to rebuild tileset with `spawn_faction` custom_data
- [ ] Open `test_map_01.tscn` — verify spawn markers are visible on SpawnTileLayer in editor
- [ ] F5/F6 — spawn tiles hidden at runtime, units spawn at painted positions
- [ ] Verify fallback: remove spawn tiles → should fall back to JSON spawns
- [ ] Verify fallback: remove JSON path → should fall back to hardcoded spawns

## Key Details

- **Y-flip**: `grid_y = -cell.y` (same convention as existing `_build_grid()`)
- **Stamp tile source_id** = `AUTOTILE_CONFIGS.size()` (currently 7, shared with existing stamp tiles)
- **Stamp tile atlas**: `stamp_tiles.png` — single atlas, col 0=Regolith, col 1=Player spawn, col 2=Enemy spawn
- **Custom data layers**: 0=`terrain_type` (String), 1=`is_modifier` (bool), 2=`spawn_faction` (String)

## Files Modified

- `art/sprites/tilesets/stamp_tiles.png` — 32x32 → 96x32 (added player/enemy spawn columns)
- `scripts/editor/tileset_terrain_setup.gd` — `spawn_faction` custom_data layer, spawn stamp entries
- `scripts/grid/tilemap_grid_builder.gd` — `spawn_layer_path` export, `get_spawn_points()` method
- `scripts/managers/battle_scene.gd` — tile-based spawn priority, `default_player/enemy_character` exports
- `scripts/editor/tilemap_setup_wizard.gd` — SpawnTileLayer in generated scenes
- `scenes/battle/maps/test_map_01.tscn` — SpawnTileLayer with painted spawn tiles
