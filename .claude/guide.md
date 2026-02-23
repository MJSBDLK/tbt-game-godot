# Agent Guide for TBT-Game (Godot Port)

Quick reference for AI agents working on this codebase.

---

## Current Goal: ALPHA MILESTONE via Godot Port

**READ FIRST**: [alpha.md](alpha.md) and [migration.md](migration.md)

The project is being ported from Unity 6.3 to Godot 4.x with GDScript. The migration plan has 9 phases (0-8). We're porting all existing systems AND building missing Alpha features. The Unity source lives at `../tbt-game/` for reference.

---

## Critical Rules (NEVER Violate)

### 1. Integer Coordinates ONLY
```gdscript
# CORRECT
position = Vector2(tile_x, tile_y)

# WRONG — breaks everything
position = Vector2(tile_x + 0.5, tile_y + 0.5)
```
Reference: `../tbt-game/Assets/Docs/Standards/coordinate-system.md`

### 2. Three-Tier Sprite System
- **Floor Tiles** (Tier 1) = Base terrain properties
- **Terrain Modifiers** (Tier 2) = Gameplay override — **completely replaces** floor properties
- **Pure Decorations** (Tier 3) = Visual only, no gameplay impact

```gdscript
# CORRECT — modifier replaces floor entirely
var properties = modifier_properties if modifier_exists else floor_properties

# WRONG — never combine/add properties
var properties = floor_properties + modifier_properties
```
Reference: `../tbt-game/Assets/Docs/Implementation/three-tier-sprite-system.md`

### 3. Moves, Not Weapons
- Units equip **4 moves** (Pokemon-style, not Fire Emblem weapons)
- Moves have **PP** (limited uses per mission)
- Move type is independent of unit type (Fire unit can use Water moves)
- **No weapon inventory system**

Reference: `../tbt-game/Assets/Docs/Design/character-system.md`

---

## Porting Workflow

### When porting a Unity script:
1. **Read the Unity source** in `../tbt-game/Assets/Scripts/`
2. **Read related design docs** in `../tbt-game/Assets/Docs/`
3. **Check the migration plan** in `.claude/migration.md` for architectural decisions
4. **Write GDScript** following the translation patterns below
5. **Preserve game logic exactly** — formulas, constants, algorithms should be 1:1

### Unity → Godot Translation Cheat Sheet

| Unity C# | Godot GDScript |
|---|---|
| `MonoBehaviour` | `extends Node2D` / `extends Node` / `extends Control` |
| `Start()` / `Awake()` | `_ready()` |
| `Update()` | `_process(delta)` |
| `FixedUpdate()` | `_physics_process(delta)` |
| `OnDestroy()` | `_exit_tree()` |
| `[SerializeField]` | `@export` |
| `[Header("X")]` | `@export_group("X")` |
| `GetComponent<T>()` | `get_node()` or `$ChildName` |
| `FindObjectOfType<T>()` | Autoload singleton or `get_tree().get_first_node_in_group()` |
| `FindObjectsByType<T>()` | `get_tree().get_nodes_in_group()` |
| `Instantiate(prefab)` | `scene.instantiate()` |
| `Destroy(obj)` | `obj.queue_free()` |
| `StartCoroutine()` | `await` + signals or tweens |
| `yield return new WaitForSeconds(t)` | `await get_tree().create_timer(t).timeout` |
| `Vector3` (2D game) | `Vector2` |
| `Mathf.Clamp()` | `clampf()` / `clampi()` |
| `Mathf.RoundToInt()` | `roundi()` |
| `Mathf.Lerp()` | `lerpf()` |
| `Color.Lerp()` | `color.lerp()` |
| `Debug.Log()` | `print()` or `DebugConfig.log_*()` |
| `Debug.LogWarning()` | `push_warning()` |
| `Debug.LogError()` | `push_error()` |
| `ScriptableObject` | `extends Resource` with `class_name` |
| `JsonUtility.FromJson()` | `JSON.parse_string()` |
| `File.ReadAllText()` | `FileAccess.get_file_as_string()` |
| `SceneManager.LoadScene()` | `get_tree().change_scene_to_file()` |
| `SpriteRenderer.color` | `Sprite2D.modulate` |
| `SpriteRenderer.sortingOrder` | `Node2D.z_index` |
| `Canvas` / `RectTransform` | `Control` nodes |
| `Input.GetKeyDown()` | `Input.is_action_just_pressed()` |
| `Camera.ScreenToWorldPoint()` | `get_global_mouse_position()` via Camera2D |
| `BoxCollider2D` (grid click) | Direct coordinate math — no physics needed |
| Singleton via `static Instance` | Autoload node |

### Coroutine → Async Pattern
```gdscript
# Unity coroutine:
# IEnumerator MoveAlongPath() {
#     yield return new WaitForSeconds(0.5f);
#     yield return StartCoroutine(Attack());
# }

# Godot equivalent:
func move_along_path() -> void:
    await get_tree().create_timer(0.5).timeout
    await attack()

# Movement animation:
func animate_to(target: Vector2) -> void:
    var tween := create_tween()
    tween.tween_property(self, "position", target, 0.2)
    await tween.finished
```

---

## Game Design Reference

### Type System
- Units have **dual types** (Primary + Secondary)
- Effectiveness: 2x (super effective), 1x (normal), 0.5x (not very effective)
- Dual types multiply: Fire vs Plant/Cold = 2x * 2x = 4x
- Type chart uses **string-based storage** to prevent corruption on enum reorder

### 8-Stat System
```
HP, Strength, Special, Skill, Agility, Athleticism, Defense, Resistance
```
- Physical moves: Strength vs Defense
- Special moves: Special vs Resistance
- Athleticism: Terrain movement bonus
- Final Stat = Base + Growth Gains + Allocated Stat Ups + Support Bonuses + Passive Bonuses + Status Modifiers

### Combat Formulas
```
base_damage = (move.base_power * attack_stat / 5) - defense_stat
final_damage = base_damage * type_multiplier

attack_count based on Athleticism ratio:
  4x ratio → 4 attacks
  3x ratio → 3 attacks
  2x ratio → 2 attacks
  1x ratio → 1 attack
```

### Combat Sequence
1. Attacker hit 1 (+ status effect application)
2. Defender counter 1 (if eligible, + status effect)
3. Attacker bonus hits (2nd, 3rd, 4th)
4. Defender bonus counters (2nd, 3rd, 4th)

### Terrain Movement
```
if Athleticism > Constitution: terrain_cost - 1 (min 1)
if Athleticism >= 2 * Constitution: terrain_cost - 2 (min 1)
```
Internal scaling: all movement costs * 2 for half-tile precision. `MOVEMENT_SCALE = 2`.

### UI Layout
- Reference: **640x360**
- Layout: 140px left panel | 360x360 center play area | 140px right panel
- Left: Unit info (220px) + Terrain info (140px)
- Right: Action menu + Combat preview
- Integer scaling only (no stretching). Black bars on ultrawide.

### Progression
- Growth rates (RNG stat increases on level up, Fire Emblem style)
- Stat allocation points distributed between missions
- No grinding — stats only grow from story missions
- Class evolution at levels 20, 40

---

## Project Architecture

### Autoload Singletons (registered in project.godot)
These replace Unity's FindObjectOfType singleton pattern:
- `DebugConfig` — Flag-based debug logging
- `TerrainDataManager` — Loads terrain_data.json, movement costs
- `GridManager` — 2D tile array, A* pathfinding, BFS flood-fill
- `GameStateManager` — Input state machine (6 states)
- `InputManager` — Mouse/keyboard/controller input dispatch
- `TurnManager` — Phase cycle, victory/defeat detection
- `ActionMenuManager` — Action menu orchestration
- `TypeChartManager` — Type effectiveness lookups
- `StatusEffectSystem` — Apply/process/remove status effects
- `UIManager` — Panel management, overlays
- `VisualFeedbackManager` — Screen shake, flash, tooltips

### Scene Structure (replaces Unity scene hierarchy)
```
BattleScene (Node2D)
  TileMapLayer (floor, Tier 1)
  TileMapLayer (modifiers, Tier 2)
  TileMapLayer (decorations, Tier 3)
  LogicTiles (Node2D container — auto-created at runtime)
  Units (Node2D container)
    PlayerUnit1, PlayerUnit2, ...
    EnemyUnit1, EnemyUnit2, ...
  Camera2D (with camera_controller.gd)
  CanvasLayer (UI)
```

### Z-Index System
Formula: `z_index = (99 - row_index) * 10 + layer`
- Range: 0-997 (within Godot's -4096..4096 limit)
- Layers: FloorTiles(0), TerrainEffects(1), TerrainModifiers(2), PureDecorations(3), PathIndicators(4), Units(5), UnitEffects(6), UI(7)
- Front rows get higher z_index (render in front)
- Use `ZIndexCalculator.calculate_sorting_order()` — never set z_index manually

### Data Pipeline
- `terrain_data.json` → `TerrainDataManager` (autoload) — terrain movement costs, properties
- `data/characters/*.json` → `CharacterDataLoader` → `CharacterData` (Resource)
- `data/moves/BasicMoveBank.json` → `MoveDatabase` — move definitions
- Type chart → `.tres` Resource file
- All JSON uses Godot's native `JSON.parse_string()` — no custom parsers needed

---

## Common Mistakes to Avoid

### Wrong: Physics for grid input
```gdscript
# DON'T — no Area2D/raycasts needed for grid game
var result = get_world_2d().direct_space_state.intersect_ray(...)
```
```gdscript
# DO — convert mouse position to grid coordinates
var world_pos = get_global_mouse_position()
var grid_x = roundi(world_pos.x / tile_size)
var grid_y = roundi(world_pos.y / tile_size)
var tile = GridManager.get_tile(grid_x, grid_y)
```

### Wrong: Treating modifiers as additive
```gdscript
# DON'T
final_cost = floor_cost + modifier_cost

# DO — modifier REPLACES floor
final_cost = modifier_cost if has_modifier else floor_cost
```

### Wrong: 0.5 offsets
```gdscript
# DON'T
tile.position = Vector2(x + 0.5, y + 0.5)

# DO
tile.position = Vector2(x, y)
```

---

## When Uncertain

- **Game design**: Check `../tbt-game/Assets/Docs/Design/`
- **Implementation details**: Check `../tbt-game/Assets/Docs/Implementation/`
- **Coordinates**: Integer only. Period.
- **Migration approach**: Check `.claude/migration.md`
- **What's done vs pending**: Check `.claude/alpha.md`
- **Godot 4.x API**: Search for "Godot 4.3" documentation. Godot 4 shipped in 2023 and is well-documented.
