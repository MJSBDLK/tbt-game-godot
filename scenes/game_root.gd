## Top-level wrapper for the SubViewport-flip rendering architecture.
##
## Most of the game renders into the 640x360 `GameViewport` SubViewport hosted
## by `PixelLayer`, which is displayed with nearest-filter integer scaling.
## HD textures (line-art portraits, etc.) are added under `HDLayer` instead, so
## they rasterise at the actual window pixel density with bilinear filtering.
##
## See SceneRouter for the API the rest of the codebase uses to load scenes
## into the SubViewport and query the game viewport / HD layer.
extends Node


@onready var pixel_layer: SubViewportContainer = $PixelLayer
@onready var game_viewport: SubViewport = $PixelLayer/GameViewport
@onready var hd_layer: CanvasLayer = $HDLayer


func _ready() -> void:
	# Pin the SubViewportContainer size to the project's reference resolution.
	# It already gets 640x360 from anchors_preset=15 under canvas_items stretch
	# (the root viewport's "visible rect" reports reference units, not native
	# pixels), but pinning removes any ambiguity if the project ever changes
	# stretch mode again.
	var reference_size := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width", 640),
		ProjectSettings.get_setting("display/window/size/viewport_height", 360))
	pixel_layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pixel_layer.position = Vector2.ZERO
	pixel_layer.size = reference_size
	# Don't set game_viewport.size directly — stretch=true on the container owns
	# that and refuses manual overrides.

	# Reparenting and the initial scene load both have to happen *after* the
	# current frame's tree mutation settles. Defer them; deferred calls fire
	# in the order they were queued, so reparent finishes before SceneRouter
	# loads the start scene into the (now-correctly-populated) viewport.
	_reparent_ui_autoloads()
	SceneRouter.register_game_root(game_viewport, hd_layer)
	_dump_diagnostics.call_deferred()


func _dump_diagnostics() -> void:
	# One-shot diagnostic. Prints to godot.log so we can confirm the setup at
	# runtime. Remove once the rendering pipeline is verified stable.
	var ui_manager_node: Node = get_node_or_null("/root/UIManager")
	var ui_manager_parent: String = (
		"<missing>" if ui_manager_node == null
		else ui_manager_node.get_parent().get_path() as String)
	var visual_feedback_node: Node = get_node_or_null("/root/VisualFeedbackManager")
	var visual_feedback_parent: String = (
		"<missing>" if visual_feedback_node == null
		else visual_feedback_node.get_parent().get_path() as String)
	# UIManager was reparented in _reparent_ui_autoloads, so /root/UIManager
	# may now be null. Look up via the autoload singleton instead.
	if ui_manager_node == null:
		ui_manager_parent = str(UIManager.get_parent().get_path())
	if visual_feedback_node == null:
		visual_feedback_parent = str(VisualFeedbackManager.get_parent().get_path())
	print("[GameRoot] stretch_mode=%s, scale=%s" % [
		ProjectSettings.get_setting("display/window/stretch/mode"),
		ProjectSettings.get_setting("display/window/stretch/scale_mode")])
	print("[GameRoot] root viewport size=%s" % get_viewport().get_visible_rect().size)
	print("[GameRoot] PixelLayer size=%s (CanvasItem space)" % pixel_layer.size)
	print("[GameRoot] GameViewport size=%s (pixels)" % game_viewport.size)
	print("[GameRoot] UIManager parent: %s" % ui_manager_parent)
	print("[GameRoot] VisualFeedbackManager parent: %s" % visual_feedback_parent)


# Autoloads are children of /root by default. Anything that builds visible
# CanvasItems in its _ready() (UIManager, VisualFeedbackManager via its inner
# CanvasLayer) needs to live *inside* the SubViewport so its render goes
# through the 640x360 pixel-art framebuffer instead of the native-resolution
# root viewport. Signal connections and the autoload singleton lookup survive
# reparenting; only the node's tree path changes.
func _reparent_ui_autoloads() -> void:
	_reparent_into_game_viewport("/root/UIManager")
	_reparent_into_game_viewport("/root/VisualFeedbackManager")


func _reparent_into_game_viewport(autoload_path: String) -> void:
	var node: Node = get_node_or_null(autoload_path)
	if node == null:
		push_warning("GameRoot: could not reparent %s (not found)" % autoload_path)
		return
	var current_parent: Node = node.get_parent()
	if current_parent == game_viewport:
		return
	# The remove + add must be deferred: at the time _ready() runs, /root is
	# still mid-tree-mutation finishing GameRoot's own attach, so direct
	# remove_child() raises "parent node is busy adding/removing children".
	# Deferred calls fire after the current frame settles, in queued order, so
	# the remove completes before the add.
	current_parent.remove_child.call_deferred(node)
	game_viewport.add_child.call_deferred(node)
