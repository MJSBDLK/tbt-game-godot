## Replaces `get_tree().change_scene_to_file()` for the SubViewport-flip
## architecture introduced for HD portrait rendering.
##
## In the old single-viewport setup, the root viewport itself rendered at
## 640x360 and Godot's stretch system upscaled it to the window. Scene
## transitions worked by replacing the whole tree (`get_tree().change_scene_to_file`).
##
## With HD line art we need *two* render targets: a 640x360 SubViewport for
## the pixel-art game/UI (nearest filter, integer scale) and a native-resolution
## CanvasLayer for HD overlays (bilinear filter). The main scene is now
## `GameRoot.tscn`, which hosts both layers and persists across scene changes.
## "Changing scene" now means replacing the current child of the SubViewport,
## not replacing the whole tree.
##
## Registered as Autoload "SceneRouter".
extends Node


## Emitted after `change_scene_to(path)` finishes parenting the new scene and
## freeing the old one. Listeners can rely on `get_current_scene()` returning
## the new root by the time this fires.
signal scene_changed(new_scene: Node)


const _START_SCENE_PATH: String = "res://scenes/ui/start_screen.tscn"


# Wired up by GameRoot._ready() when the wrapper scene loads. Kept as plain
# references rather than fetched on demand so an in-flight scene change doesn't
# race with `get_game_viewport()` callers (the references stay valid for the
# lifetime of GameRoot, which is the whole app session).
var _game_viewport: SubViewport = null
var _hd_layer: CanvasLayer = null
var _current_scene: Node = null


## Called by GameRoot once during startup. Passing the nodes in (rather than
## scanning the tree) keeps SceneRouter agnostic of GameRoot's internal layout.
func register_game_root(game_viewport: SubViewport, hd_layer: CanvasLayer) -> void:
	_game_viewport = game_viewport
	_hd_layer = hd_layer
	if _current_scene == null:
		_load_initial_scene()


## The SubViewport that hosts the pixel-art game tree. Autoloads that need
## camera/mouse/input data for the game world should query this rather than
## `get_viewport()` — autoloads are children of the root viewport, which is
## now native-resolution and has no game camera.
func get_game_viewport() -> SubViewport:
	return _game_viewport


## The CanvasLayer at the root viewport (native resolution) where HD textures
## (portraits, line art, cinematic overlays) should be rendered. Returns null
## before GameRoot has registered.
func get_hd_layer() -> CanvasLayer:
	return _hd_layer


## The currently-active "scene" — the direct child of the game viewport.
## Equivalent to `get_tree().get_current_scene()` under the old architecture.
func get_current_scene() -> Node:
	return _current_scene


## Drop-in replacement for `get_tree().change_scene_to_file(path)`. Frees the
## previous scene and instances the new one as a child of the game viewport.
## Defers the swap a frame so callers can finish their current execution
## (mirrors the original API's behavior).
func change_scene_to(path: String) -> void:
	call_deferred("_swap_scene", path)


func _swap_scene(path: String) -> void:
	if _game_viewport == null:
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

	_game_viewport.add_child(new_scene)
	_current_scene = new_scene
	scene_changed.emit(new_scene)


func _load_initial_scene() -> void:
	# GameRoot is the project's main scene now, so we load the *real* first scene
	# (start_screen) into the SubViewport as soon as the wrapper is ready.
	change_scene_to(_START_SCENE_PATH)
