## Drop-in replacement for `get_tree().change_scene_to_file()` under the
## dual-pipeline rendering architecture.
##
## Scenes are routed to their natural viewport by root-node type:
##   - Node2D / Node3D roots → WorldRoot (rendered to root viewport at native
##     resolution, controlled by Camera2D).
##   - Control roots         → HUDViewport (rendered at 640×360, displayed via
##     HUDDisplay).
##
## "Changing scene" means replacing the current child of the appropriate
## render target, not replacing the whole tree.
##
## Registered as Autoload "SceneRouter".
extends Node


## Emitted after `change_scene_to(path)` finishes parenting the new scene and
## freeing the old one. Listeners can rely on `get_current_scene()` returning
## the new root by the time this fires.
signal scene_changed(new_scene: Node)


const _START_SCENE_PATH: String = "res://scenes/ui/start_screen.tscn"


# Wired up by GameRoot._ready() when the wrapper scene loads. Kept as plain
# references so an in-flight scene change doesn't race with viewport-getter
# callers — the references stay valid for the lifetime of GameRoot (the whole
# app session).
var _world_root: Node2D = null
var _hud_viewport: SubViewport = null
var _hud_display: TextureRect = null
var _hd_layer: CanvasLayer = null
var _current_scene: Node = null


## Called by GameRoot once during startup. Passing nodes in (rather than
## scanning the tree) keeps SceneRouter agnostic of GameRoot's internal layout.
func register_game_root(world_root: Node2D, hud_viewport: SubViewport, hud_display: TextureRect, hd_layer: CanvasLayer) -> void:
	_world_root = world_root
	_hud_viewport = hud_viewport
	_hud_display = hud_display
	_hd_layer = hd_layer
	if _current_scene == null:
		_load_initial_scene()


## The Node2D that hosts world content (battle scenes, camera, units, tiles).
## Code that needs to add Node2Ds to the world (damage popups in world-space,
## one-off VFX) should parent them here.
func get_world_root() -> Node2D:
	return _world_root


## The SubViewport that hosts the 640×360 HUD (UIManager, panels, full-screen
## HUD scenes). Use for adding HUD-space Controls outside of UIManager.
func get_hud_viewport() -> SubViewport:
	return _hud_viewport


## The TextureRect that projects HUDViewport's render onto the root viewport
## (filling the window). Code that needs to convert HUD coords to native pixel
## coords (HD overlays, world↔HUD projection for damage popups) reads position
## + size from this.
func get_hud_display() -> TextureRect:
	return _hud_display


## The integer scale factor between HUD design pixels and native window pixels.
## HUDViewport renders at `window_size / hud_scale`; HUDDisplay shows that at
## `window_size` via nearest-filter integer scaling.
func get_hud_scale() -> int:
	if _hud_viewport == null or _hud_viewport.size.x == 0:
		return 1
	return int(_hud_display.size.x) / int(_hud_viewport.size.x)


## The CanvasLayer at the root viewport (native resolution) where HD textures
## (portraits, line art) should be rendered.
func get_hd_layer() -> CanvasLayer:
	return _hd_layer


## The active world Camera2D. Lives in the root viewport (WorldRoot's tree).
## Callers that need to project world coords to/from screen pixels should
## query this helper rather than rooting around in viewport hierarchies.
func get_world_camera() -> Camera2D:
	if _world_root == null:
		return null
	var root_viewport: Viewport = _world_root.get_viewport()
	if root_viewport == null:
		return null
	return root_viewport.get_camera_2d()


## The currently-active "scene" — the direct child of whichever render target
## currently owns it.
func get_current_scene() -> Node:
	return _current_scene


## Drop-in replacement for `get_tree().change_scene_to_file(path)`. Frees the
## previous scene and instances the new one into the appropriate render target.
func change_scene_to(path: String) -> void:
	call_deferred("_swap_scene", path)


func _swap_scene(path: String) -> void:
	if _world_root == null or _hud_viewport == null:
		push_error("SceneRouter.change_scene_to: GameRoot has not registered yet")
		return

	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("SceneRouter.change_scene_to: failed to load %s" % path)
		return

	var new_scene: Node = packed.instantiate()
	if _current_scene != null:
		_current_scene.queue_free()
		_current_scene = null

	var target: Node = _target_for(new_scene)
	target.add_child(new_scene)
	_current_scene = new_scene
	scene_changed.emit(new_scene)


## Picks the render target for a scene by root type. Node2D/Node3D content
## lives in the world (so Camera2D can transform it); Control content lives
## in HUDViewport (so it uses the 640×360 design canvas).
func _target_for(scene_root: Node) -> Node:
	if scene_root is Control:
		return _hud_viewport
	return _world_root


func _load_initial_scene() -> void:
	change_scene_to(_resolve_initial_scene())


## The scene to boot into: a dev override if one is set and loadable
## (`--map=` command-line arg, then DebugConfig.dev_launch_scene), otherwise the
## start screen. Routing still goes through change_scene_to, so a battle map
## launched this way gets the normal GameRoot/camera/HUD setup.
func _resolve_initial_scene() -> String:
	var token := _dev_launch_token()
	if token.is_empty():
		return _START_SCENE_PATH
	var path := resolve_scene_path(token)
	if not ResourceLoader.exists(path):
		push_warning("SceneRouter: dev launch scene '%s' (from '%s') not found — using start screen" % [path, token])
		return _START_SCENE_PATH
	print("SceneRouter: dev launch → %s" % path)
	return path


## Raw dev-launch token: the `--map=` command-line arg (after `--`) if present,
## else DebugConfig.dev_launch_scene, else "" (normal start-screen flow).
func _dev_launch_token() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			return arg.substr("--map=".length())
	if not DebugConfig.dev_launch_scene.is_empty():
		return DebugConfig.dev_launch_scene
	return ""


## Expands a dev-launch token to a res:// scene path. Accepts a full res:// path,
## a project-relative path (contains "/"), or a bare battle-map name (expands to
## res://scenes/battle/maps/<name>.tscn, adding .tscn if missing). Pure +
## testable; returns "" for an empty token.
static func resolve_scene_path(token: String) -> String:
	var trimmed := token.strip_edges()
	if trimmed.is_empty():
		return ""
	if trimmed.begins_with("res://"):
		return trimmed
	if trimmed.contains("/"):
		return "res://" + trimmed
	if not trimmed.ends_with(".tscn"):
		trimmed += ".tscn"
	return "res://scenes/battle/maps/" + trimmed
