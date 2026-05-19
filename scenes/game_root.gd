## Top-level wrapper for the dual-pipeline rendering architecture.
##
## Three rendering pipelines, each with one explicit scaling rule:
##   1. World renders directly to the root viewport at native window resolution
##      (Camera2D in WorldRoot). Camera.zoom is screen-pixels-per-world-pixel.
##   2. HUD renders into a 640×360 SubViewport (HUDViewport). Its texture is
##      then displayed by HUDDisplay (TextureRect, NEAREST filter, integer
##      scale, centered on root viewport).
##   3. HDLayer is a CanvasLayer at native window resolution for HD textures
##      (line-art portraits). Positioned in native pixel space directly.
##
## InputRouter forwards events from the root viewport into HUDViewport with
## coord remapping so panels receive mouse events at HUD-space positions.
##
## See `.claude/zoom-arch.md` for the architecture rationale.
extends Node


const _REF_WIDTH: int = 640
const _REF_HEIGHT: int = 360


@onready var world_root: Node2D = $WorldRoot
@onready var hud_viewport: SubViewport = $HUDViewport
@onready var hud_layer: CanvasLayer = $HUDLayer
@onready var hud_display: TextureRect = $HUDLayer/HUDDisplay
@onready var hd_layer: CanvasLayer = $HDLayer
@onready var input_router: Node = $InputRouter


func _ready() -> void:
	hud_display.texture = hud_viewport.get_texture()
	_resize_hud_display()
	get_tree().root.size_changed.connect(_resize_hud_display)

	_reparent_ui_autoloads()
	SceneRouter.register_game_root(world_root, hud_viewport, hud_display, hd_layer)
	_dump_diagnostics.call_deferred()


## HUDViewport's design pixel size grows to match the window's aspect ratio at
## the largest integer scale that fits ≥ 640×360. The 640×360 "core" is always
## addressable; corner panels gain extra design pixels at the window edges so
## they can anchor flush against the screen instead of floating inside a
## letterbox. HUDDisplay fills the full window — no black bars.
##
## Examples:
##   1920×1080 → scale=3, HUDViewport=640×360, HUDDisplay=1920×1080
##   1280×800  → scale=2, HUDViewport=640×400, HUDDisplay=1280×800   (Steam Deck)
##   1500×900  → scale=2, HUDViewport=750×450, HUDDisplay=1500×900
##   2560×1080 → scale=3, HUDViewport=853×360, HUDDisplay=2560×1080  (ultrawide)
func _resize_hud_display() -> void:
	var window: Vector2i = DisplayServer.window_get_size()
	var scale_factor: int = _integer_scale_for(window)
	hud_viewport.size = Vector2i(window.x / scale_factor, window.y / scale_factor)
	hud_display.size = Vector2(window)
	hud_display.position = Vector2.ZERO


func _integer_scale_for(window: Vector2i) -> int:
	return maxi(1, mini(window.x / _REF_WIDTH, window.y / _REF_HEIGHT))


# Autoloads default to children of /root. UIManager and VisualFeedbackManager
# both render into HUD design space, so they live inside HUDViewport. Signal
# connections and autoload-singleton lookups survive reparenting; only the
# tree path changes.
func _reparent_ui_autoloads() -> void:
	_reparent_into(UIManager, hud_viewport)
	_reparent_into(VisualFeedbackManager, hud_viewport)


func _reparent_into(node: Node, new_parent: Node) -> void:
	if node == null:
		return
	var current_parent: Node = node.get_parent()
	if current_parent == new_parent:
		return
	# The remove + add must be deferred — /root is mid-tree-mutation while
	# GameRoot is attaching, so direct remove_child() raises "parent node is
	# busy adding/removing children". Deferred calls fire in queued order.
	current_parent.remove_child.call_deferred(node)
	new_parent.add_child.call_deferred(node)


func _dump_diagnostics() -> void:
	var window: Vector2i = DisplayServer.window_get_size()
	var scale_factor: int = _integer_scale_for(window)
	print("[GameRoot] stretch_mode=%s" % ProjectSettings.get_setting("display/window/stretch/mode"))
	print("[GameRoot] window=%s scale=%dx HUDDisplay=(pos=%s size=%s)" % [
		window, scale_factor, hud_display.position, hud_display.size])
	print("[GameRoot] HUDViewport=%s" % hud_viewport.size)
	print("[GameRoot] UIManager parent: %s" % UIManager.get_parent().get_path())
	print("[GameRoot] VisualFeedbackManager parent: %s" % VisualFeedbackManager.get_parent().get_path())
