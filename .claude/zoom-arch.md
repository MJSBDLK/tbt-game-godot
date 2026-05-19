# Zoom Architecture — Design Doc

**Goal**: support clean sub-1x zoom-out on big maps without sub-pixel rendering, while keeping the HUD at 640×360 design pixels.

**Branch**: `rqd--zoom` (prototype, safe to break things).

---

## The principle

One rule per rendering pipeline. No nested stretch systems fighting each other.

- **World** renders directly to the root viewport at native window resolution. Camera2D's zoom is "screen pixels per world pixel" — always integer.
- **HUD** renders into a 640×360 SubViewport, displayed via a `TextureRect` at integer-scaled size on the root viewport.
- **HD overlays** live on a CanvasLayer at the root viewport, positioned in native pixel space directly.
- **Input** is routed by one dedicated `InputRouter` node, with explicit coord remapping at the boundary.

The "ref space" abstraction (canvas_items stretch) goes away. Every coordinate has one clear coordinate system, named in the variable.

---

## Project settings change

`project.godot`:
```
display/window/stretch/mode = "disabled"    # was "canvas_items"
display/window/stretch/scale_mode = "fractional"  # irrelevant once disabled
```

After this change, the root viewport's `get_visible_rect().size` returns native window pixels (e.g., 1920×1080), not the 640×360 reference space.

---

## GameRoot scene structure

```
GameRoot (Node)
├── WorldRoot (Node2D)
│       — Battle scenes (Node2D roots) load here via SceneRouter.
│       — Camera2D inside the battle scene controls world view.
│       — Renders directly to root viewport at native resolution.
│
├── HUDViewport (SubViewport, size = Vector2i(640, 360), transparent_bg = true)
│   └── (UIManager, VisualFeedbackManager, HUD scenes load here)
│
├── HUDDisplay (TextureRect)
│       — texture = HUDViewport.get_texture()
│       — texture_filter = NEAREST
│       — stretch_mode = STRETCH_SCALE
│       — rect = (640 × N, 360 × N) centered, where N = integer_scale(window)
│       — updated on window size_changed
│
├── HDLayer (CanvasLayer, layer = 100)
│       — HD textures positioned in native pixel space.
│
└── InputRouter (Node)
        — Sees root viewport _input, _unhandled_input.
        — Forwards to HUDViewport / WorldRoot with coord remap.
```

Render order at root viewport (bottom to top):
1. WorldRoot (Node2D content)
2. HUDDisplay (TextureRect of HUDViewport texture)
3. HDLayer (CanvasLayer)

---

## Camera zoom model

User-facing concept: **`zoom_level: int`** = screen pixels per world pixel. Always integer.

```gdscript
class_name CameraController extends Camera2D

@export var min_zoom_level: int = 1          # max zoom-out (1 wp = 1 sp)
@export var max_zoom_level: int = 8          # max zoom-in
var _target_zoom_level: int                  # what user is tweening toward

func _ready():
    _target_zoom_level = _default_zoom_level()
    zoom = Vector2.ONE * _target_zoom_level

func _default_zoom_level() -> int:
    # Match the current visual default — fully zoomed-in on small windows,
    # the same physical sprite size on big windows.
    return _window_integer_scale()  # 2 at 720p, 3 at 1080p, 4 at 1440p, 6 at 4K

func _window_integer_scale() -> int:
    var w := DisplayServer.window_get_size()
    return maxi(1, mini(w.x / 640, w.y / 360))
```

Godot's `Camera2D.zoom` is set directly to `Vector2(zoom_level, zoom_level)`. No float interpolation between integer levels — zoom in/out commands snap, optionally tweened visually.

At zoom_level = monitor's integer scale: visual matches today's default. Player can zoom out below that (zoom_level = 2, 1) to see more world cleanly, or zoom in above (zoom_level = N+1, N+2…) for sprite inspection.

**No sub-pixel rendering, ever.** No reciprocal-snap math. The clean-vs-shimmer problem disappears.

---

## InputRouter contract

One file, one job: take events at the root viewport, decide which pipeline gets them, forward with correct coords.

```gdscript
class_name InputRouter extends Node

@export var hud_viewport: SubViewport
@export var hud_display: TextureRect
@export var world_root: Node2D   # used for "is this a battle scene" query

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton or event is InputEventMouseMotion:
        _route_mouse(event)
    else:
        _route_keyboard_or_other(event)

func _route_mouse(event: InputEvent) -> void:
    var native_pos: Vector2 = event.position
    var hud_pos := _native_to_hud(native_pos)
    if _hud_has_control_at(hud_pos):
        _forward_to_hud(event, hud_pos)
        get_viewport().set_input_as_handled()
        return
    # No HUD panel under cursor: world gets it at native pixels (Camera2D handles
    # the screen→world transform on its own viewport).
    # Nothing to forward — events on the root viewport already reach world content
    # at native coords. We just don't consume them.

func _native_to_hud(p: Vector2) -> Vector2:
    var n: int = _hud_display_integer_scale()
    return (p - hud_display.position) / float(n)

func _hud_has_control_at(hud_pos: Vector2) -> bool:
    # Use HUDViewport.gui_pick_focusable? gui_get_focus_owner? — TBD, will pick
    # the simplest reliable API.
    ...

func _forward_to_hud(event: InputEvent, hud_pos: Vector2) -> void:
    var remapped := event.duplicate()
    remapped.position = hud_pos
    if event is InputEventMouseMotion:
        remapped.relative = event.relative / float(_hud_display_integer_scale())
    hud_viewport.push_input(remapped, true)
```

Keyboard/joypad: forward to HUDViewport if a HUD Control has focus; otherwise let world handle natively.

---

## Per-file change list

| File | Change |
|---|---|
| `project.godot` | `stretch/mode = "disabled"` |
| `scenes/game_root.tscn` | Replace contents per structure above |
| `scenes/game_root.gd` | New structure; size HUDDisplay on resize; reparent autoloads into HUDViewport |
| `scripts/managers/scene_router.gd` | `_swap_scene` routes by root type: `Node2D` → `WorldRoot`, `Control` → `HUDViewport` |
| `scripts/managers/camera_controller.gd` | Integer `zoom_level`, default = window integer scale, snap zoom changes to integer steps |
| `scripts/managers/input_manager.gd` | Remove `SceneRouter.get_game_viewport()` calls; world mouse comes from root viewport's `Camera2D.get_global_mouse_position()` |
| `scripts/ui/ui_manager.gd` | Same; `_get_camera()` finds the camera at root, not in a SubViewport |
| `scripts/ui/hd_portrait_slot.gd` | Mirror coord math: `mirror.global_position = hud_display.position + (slot.global_position * N)`, sized × N |
| `scripts/ui/components/tap_tooltip.gd` | `get_viewport_rect().size` now returns HUDViewport size (640×360) since the tooltip lives in HUDViewport — semantic unchanged but verify |
| `scripts/managers/input_router.gd` | NEW — see contract above |

Autoload reparenting:
- `UIManager` → HUDViewport (renders HUD panels)
- `VisualFeedbackManager` → split: cancel hint stays in HUD-tree (640×360 label), world feedback (damage popups, tweens on Node2D) operates on world objects regardless of manager's tree position. Manager itself lives in HUDViewport for simplicity; damage popups will be added directly to WorldRoot via `WorldRoot.add_child(popup)`.

Scene routing:
- `BattleScene` / map roots (Node2D) → `WorldRoot`
- `StartScreen`, `PrepScreen`, `CampaignCompleteScreen` (Control) → `HUDViewport`

---

## Migration check-list (audited)

- [x] Controls with `anchors_preset = 15` in HUD scenes — work fine inside 640×360 HUDViewport
- [x] `phase_transition_overlay.gd` uses hardcoded `Vector2(640, ...)` — lives in HUDViewport, still correct
- [ ] `camera_controller.gd` lines 137, 198 use `get_viewport_rect().size` — now returns native pixel size (because camera is at root). Bounds math needs updating: `half_view = viewport_size / (2 * zoom_level)` (zoom_level is integer = screen-px-per-world-px; viewport_size is in screen px; half_view is in world units — correct).
- [ ] `tap_tooltip.gd` uses `get_viewport_rect().size` — lives in HUDViewport, returns 640×360 — correct
- [ ] `hd_portrait_slot.gd` — rewrite coord math (explicit × N)
- [ ] `damage_popup` spawn sites — verify added to WorldRoot, not autoload tree

---

## Decisions confirmed by user

- **Default zoom on each monitor** = monitor's integer scale (zoom_level=2 on 1280×800, 3 on 1080p, 4 on 1440p, 6 on 4K). Visual default looks like 640×360 at 1:1 — what's shipping today.
- **Damage popups** live in HUDViewport, with per-frame projection from `target.global_position` → HUD pixel coords. Numbers stay at HUD design size regardless of zoom.
- **Existing options-menu toggle (Smooth vs Integer) is preserved.** Integer = zoom_level snaps to int. Smooth = float Camera2D.zoom (familiar UX, mild shimmer between integer values).

## Decisions I'm taking unless objected to

1. **Camera zoom internally is float** (so Smooth mode works), but the Integer mode snaps to int. Both modes share `min_zoom = 1` / `max_zoom = 8` bounds.
2. **Default zoom = monitor's integer scale.** On a 1080p monitor, the player starts at zoom_level = 3 (each world pixel = 3 screen pixels = current visual default). On Steam Deck (720p effective), zoom_level = 2. On 4K, zoom_level = 6.
3. **Min zoom = 1** (1 sp = 1 wp = pixel-perfect maximum zoom-out). Max zoom = 8.
4. **Damage popups parented to WorldRoot**; cancel hint stays in HUDViewport.
5. **Scene routing by root type** (Node2D → world, Control → HUD). No per-scene flag needed.
6. **InputRouter is one file** with explicit forwarding rules. No `mouse_filter = PASS` tricks.

---

## Order of work

1. Write `input_router.gd` against a stub `game_root.tscn` that has the new structure — verify input forwarding works end-to-end with a hello-world HUD button and a Node2D in WorldRoot.
2. Migrate `game_root.tscn` + `game_root.gd` + `scene_router.gd` to new structure.
3. Update `camera_controller.gd` zoom model.
4. Update `hd_portrait_slot.gd` coord math.
5. Update `input_manager.gd` and `ui_manager.gd` viewport lookups.
6. Smoke test: start screen → prep screen → battle → zoom in/out → hover panels → HD portraits → post-mission report.
7. Per-system audit: damage popups, phase transition, cancel hint, tap tooltip.

Each step is independently testable. Each commit on `rqd--zoom` leaves the game runnable.
