## A Control that reserves space inside a pixel-art UI panel for an HD texture
## (typically a character line-art portrait) rendered at native window
## resolution by the HD overlay layer.
##
## How it works:
##   - This slot lives in the SubViewport-hosted pixel UI tree. It contributes
##     to layout exactly like an empty Control of its size.
##   - On _ready, it asks SceneRouter for the root-level HDLayer CanvasLayer
##     and spawns a mirror TextureRect there.
##   - Every time this slot moves or resizes (or its texture changes), the
##     mirror is updated to overlay the same screen-space rectangle. Both the
##     SubViewport contents and the HDLayer use the project's 640x360
##     reference coordinate system (the canvas_items stretch transform applies
##     uniformly), so we can copy global_rect directly with no scaling math.
##   - The pixel-side slot stays invisible by default; only the HD mirror is
##     rendered. The slot reappears as a magenta debug rect when
##     `show_debug_rect` is enabled in the inspector.
##
## Why a mirror instead of just putting the TextureRect in HDLayer directly:
## by tracking a pixel-UI slot, the HD portrait participates in normal Container
## layout, theme spacing, panel scrolling, animations, and tween transforms —
## so authors compose UI as they always have and the HD asset "just follows."
class_name HDPortraitSlot
extends Control


## The HD texture (e.g. a line-art portrait) to render at native resolution
## above this slot's rectangle. Setting null hides the mirror.
@export var hd_texture: Texture2D = null:
	set(value):
		hd_texture = value
		_refresh_mirror_texture()

## How the texture fits the slot — passed through to the mirror TextureRect's
## `stretch_mode`. Defaults to KEEP_ASPECT_CENTERED so portraits don't squash
## when the slot's aspect ratio doesn't match the source.
@export var stretch_mode: TextureRect.StretchMode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
	set(value):
		stretch_mode = value
		if _mirror != null:
			_mirror.stretch_mode = value

## Bilinear with mipmaps is the right default for HD art being downscaled
## from a much larger source. The mirror's filter is what determines whether
## the texture rasterises crisply or fuzzily at native res.
@export var texture_filter_override: CanvasItem.TextureFilter = \
		CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
	set(value):
		texture_filter_override = value
		if _mirror != null:
			_mirror.texture_filter = value

## When true, the slot draws a translucent magenta rectangle in its own pixel-UI
## space so you can confirm placement during layout work. The HD mirror is
## unaffected.
@export var show_debug_rect: bool = false:
	set(value):
		show_debug_rect = value
		queue_redraw()

## Optional ShaderMaterial applied to the HD mirror — e.g. the projection /
## hologram effect at `res://resources/hd_portrait_projection.tres`. When
## null, the mirror renders the line art with no shader. Swappable per slot
## so different panels can use different treatments (or none).
@export var projection_material: ShaderMaterial = null:
	set(value):
		projection_material = value
		if _mirror != null:
			_mirror.material = value


var _mirror: TextureRect = null
# Cached so we know to free the right mirror on scene change even if SceneRouter's
# hd_layer reference somehow shifts mid-session.
var _mirror_parent: CanvasLayer = null


func _ready() -> void:
	# `item_rect_changed` covers position/size changes on this slot itself
	# (theme reflow, anchor recalculation, container layout, etc.).
	item_rect_changed.connect(_sync_mirror_geometry)
	# But it does NOT fire when an ancestor's transform changes (e.g. when
	# UIManager flips _left_panel's anchors to slide the preview panel to
	# the other side of the screen). The slot's `global_position` shifts,
	# but its own local rect doesn't, so item_rect_changed stays silent and
	# the mirror gets stuck at its previous screen-space location.
	# Opting into transform notifications fixes that — NOTIFICATION_TRANSFORM_CHANGED
	# fires whenever the global transform changes, including via ancestor moves.
	set_notify_transform(true)
	visibility_changed.connect(_sync_mirror_visibility)
	tree_exiting.connect(_destroy_mirror)
	_ensure_mirror()
	_sync_mirror_geometry()
	_sync_mirror_visibility()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_sync_mirror_geometry()


func _draw() -> void:
	if show_debug_rect:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.0, 1.0, 0.25), true)


func _ensure_mirror() -> void:
	if _mirror != null and is_instance_valid(_mirror):
		return
	var hd_layer: CanvasLayer = SceneRouter.get_hd_layer()
	if hd_layer == null:
		# GameRoot hasn't registered yet — defer one frame and try again. This
		# happens when the slot is part of the first scene loaded into the
		# SubViewport: that scene's _ready can run before GameRoot finishes
		# wiring SceneRouter.
		call_deferred("_ensure_mirror")
		return
	_mirror_parent = hd_layer
	_mirror = TextureRect.new()
	_mirror.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mirror.texture_filter = texture_filter_override
	_mirror.stretch_mode = stretch_mode
	# Without EXPAND_IGNORE_SIZE, TextureRect's minimum_size is the texture's
	# native pixel size — a 3024×4032 line art would clamp the mirror to the
	# whole HD texture even when we explicitly assign `size = (37, 37)`. The
	# slot's job is to dictate the rect; the texture must obey, not the other
	# way around.
	_mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mirror.texture = hd_texture
	_mirror.material = projection_material
	hd_layer.add_child(_mirror)
	_sync_mirror_geometry()
	_sync_mirror_visibility()




func _sync_mirror_geometry() -> void:
	if _mirror == null or not is_instance_valid(_mirror):
		return
	# Both this Control (inside the SubViewport) and the mirror (inside the
	# root HDLayer) live in the same 640x360 reference coordinate space, so
	# global_position/size map 1:1 without any extra transformation.
	_mirror.position = global_position
	_mirror.size = size


func _sync_mirror_visibility() -> void:
	if _mirror == null or not is_instance_valid(_mirror):
		return
	_mirror.visible = is_visible_in_tree()


func _refresh_mirror_texture() -> void:
	if _mirror == null or not is_instance_valid(_mirror):
		return
	_mirror.texture = hd_texture


func _destroy_mirror() -> void:
	if _mirror != null and is_instance_valid(_mirror):
		_mirror.queue_free()
	_mirror = null
	_mirror_parent = null
