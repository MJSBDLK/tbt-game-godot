## A Control that reserves space inside a pixel-art UI panel for an HD texture
## (typically a character line-art portrait) rendered at native window
## resolution by the HD overlay layer.
##
## How it works:
##   - This slot lives in HUDViewport (640×360 design canvas). It contributes
##     to layout exactly like an empty Control of its size.
##   - On _ready, it asks SceneRouter for the root-level HDLayer CanvasLayer
##     and spawns a mirror TextureRect there.
##   - Every time this slot moves or resizes (or its texture changes, or the
##     window is resized), the mirror is updated to overlay the same on-screen
##     rectangle. HUD lives at 640×360; HDLayer renders in native pixels — so
##     we project through HUDDisplay's on-screen rect (position + integer
##     scale) to compute the mirror's native-pixel rect. See `_native_rect_for_slot()`.
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

## Optional ShaderMaterial applied to the HD mirror itself — directly tints
## the line art's pixels. When null, the mirror renders the line art with no
## shader. Use this only when you want the shader to be clipped to the line
## art's silhouette (it will).
@export var projection_material: ShaderMaterial = null:
	set(value):
		projection_material = value
		# Route through _apply_effects_state so a reassignment (e.g. a portrait
		# rebinding via character_portrait) can't smuggle the tracking shader
		# back onto the mirror while effects are toggled off.
		if _mirror != null and is_instance_valid(_mirror):
			_apply_effects_state()

## Optional ShaderMaterial applied to a SEPARATE overlay ColorRect drawn in
## HDLayer above the mirror — covers the full slot rect uniformly, so the
## shader runs on every pixel of the portrait area (both opaque and
## transparent line-art regions). This is the right slot for "glass surface
## over the portrait" effects. The overlay's base color is `overlay_color`.
@export var overlay_material: ShaderMaterial = null:
	set(value):
		overlay_material = value
		if _overlay != null:
			_overlay.material = value
		elif value != null:
			_ensure_overlay()

## Base color of the overlay ColorRect. The shader sees this as `COLOR`, so
## use a semi-transparent dark tone (alpha ≲ 0.3) — the alpha lets the line
## art behind show through, and the shader can mix/tint from there.
@export var overlay_color: Color = Color(0.1, 0.1, 0.1, 0.3):
	set(value):
		overlay_color = value
		if _overlay != null:
			_overlay.color = value


var _mirror: TextureRect = null
# Cached so we know to free the right mirror on scene change even if SceneRouter's
# hd_layer reference somehow shifts mid-session.
var _mirror_parent: CanvasLayer = null
# Overlay ColorRect drawn above the mirror in HDLayer. Created on demand
# when `overlay_material` is set so slots that don't need an overlay don't
# pay for an extra node.
var _overlay: ColorRect = null


func _ready() -> void:
	# Receive left-clicks to toggle the debug portrait-effects bypass
	# (gated by DebugConfig.cheats_enabled). MOUSE_FILTER_PASS lets the
	# click also propagate to the portrait's parent in case other UI
	# wants it (e.g. opening unit detail panel) — we don't consume it.
	mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_gui_input)
	# Live-react to either input that gates the effects: the dev bypass flag
	# (left-click cheat) and the player-facing Settings toggle (Options → Portrait
	# FX). Both re-apply through the same path, keeping every slot in sync.
	DebugConfig.debug_portrait_effects_changed.connect(_apply_effects_state)
	Settings.changed.connect(_apply_effects_state)

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
	# Honor the current effects state (Settings + debug bypass) on first paint.
	_apply_effects_state()


func _on_gui_input(event: InputEvent) -> void:
	if not DebugConfig.cheats_enabled:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			DebugConfig.debug_portrait_effects_disabled = \
					not DebugConfig.debug_portrait_effects_disabled
			DebugConfig.debug_portrait_effects_changed.emit()


## True when the HD portrait shaders should be skipped — either the player
## turned them off in Options (Settings.portrait_effects_enabled) or a dev
## left-clicked to bypass them (DebugConfig, session-only override).
func _effects_disabled() -> bool:
	return not Settings.portrait_effects_enabled or DebugConfig.debug_portrait_effects_disabled


## Applies the current effects state to this slot's mirror + overlay. When
## effects are disabled:
##   • Mirror's material is cleared (no tracking shader) so the line art
##     renders untouched.
##   • Overlay is hidden so its glass-effect ColorRect doesn't composite
##     over the line art at all.
## When effects are re-enabled, the original materials and visibility are
## restored from the slot's exports (which are untouched by this method).
func _apply_effects_state() -> void:
	var disabled: bool = _effects_disabled()
	if _mirror != null and is_instance_valid(_mirror):
		_mirror.material = null if disabled else projection_material
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = not disabled and is_visible_in_tree()


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
		# GameRoot hasn't registered yet (the first scene's _ready can run
		# before GameRoot wires SceneRouter; headless tests never wire it).
		# Wait for the registration signal. This used to call_deferred itself:
		# a deferred call that re-defers runs again inside the SAME flush, so
		# with no HDLayer ever coming it spun until "Message queue out of
		# memory" and crashed the test runner (found 2026-09-07 when the
		# combat scene bound HD portraits under GUT).
		_wait_for_game_root()
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
	# Respect the effects toggle: a mirror (re)created while effects are off must
	# start without the tracking shader. _apply_effects_state at the end of
	# _ready also covers this, but a deferred/standalone _ensure_mirror might run
	# after that, so set the correct material up front.
	_mirror.material = null if _effects_disabled() else projection_material
	hd_layer.add_child(_mirror)
	# When the window resizes, HUDDisplay's on-screen position + integer scale
	# change. The slot's local rect doesn't move (it's in HUDViewport's fixed
	# 640×360 canvas), so NOTIFICATION_TRANSFORM_CHANGED won't fire — listen to
	# HUDDisplay.resized directly.
	var hud_display: TextureRect = SceneRouter.get_hud_display()
	if hud_display != null and not hud_display.item_rect_changed.is_connected(_sync_mirror_geometry):
		hud_display.item_rect_changed.connect(_sync_mirror_geometry)
	# Overlay (if configured) gets added AFTER the mirror so it draws on top
	# of the line art. Order matters — HDLayer renders its children in tree
	# order, so the overlay needs to come second.
	_ensure_overlay()
	_sync_mirror_geometry()
	_sync_mirror_visibility()




func _ensure_overlay() -> void:
	if overlay_material == null:
		return
	if _overlay != null and is_instance_valid(_overlay):
		return
	var hd_layer: CanvasLayer = SceneRouter.get_hd_layer()
	if hd_layer == null:
		# Same wait as _ensure_mirror — the registration handler builds both.
		_wait_for_game_root()
		return
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = overlay_color
	_overlay.material = overlay_material
	hd_layer.add_child(_overlay)
	_sync_overlay_geometry()
	_sync_mirror_visibility()


## One connection per slot, however many callers asked; a slot that left the
## tree before registration builds nothing.
func _wait_for_game_root() -> void:
	if not SceneRouter.game_root_registered.is_connected(_on_game_root_registered):
		SceneRouter.game_root_registered.connect(_on_game_root_registered, CONNECT_ONE_SHOT)


func _on_game_root_registered() -> void:
	if not is_inside_tree():
		return
	_ensure_mirror()  # builds the overlay too, in draw order
	_apply_effects_state()


func _sync_mirror_geometry() -> void:
	# The slot lives in HUDViewport's 640×360 design canvas; the mirror lives
	# in HDLayer at the root viewport's native pixel resolution. Project the
	# slot's HUD-space rect through HUDDisplay (which gives us the on-screen
	# origin + integer scale) into native pixels.
	var rect: Rect2 = _native_rect_for_slot()
	if _mirror != null and is_instance_valid(_mirror):
		_mirror.position = rect.position
		_mirror.size = rect.size
	_sync_overlay_geometry()


func _sync_overlay_geometry() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	var rect: Rect2 = _native_rect_for_slot()
	_overlay.position = rect.position
	_overlay.size = rect.size


func _native_rect_for_slot() -> Rect2:
	var hud_display: TextureRect = SceneRouter.get_hud_display()
	if hud_display == null:
		return Rect2(global_position, size)
	var scale_factor: float = float(SceneRouter.get_hud_scale())
	var native_pos: Vector2 = hud_display.position + global_position * scale_factor
	var native_size: Vector2 = size * scale_factor
	return Rect2(native_pos, native_size)


func _sync_mirror_visibility() -> void:
	var visible_in_tree: bool = is_visible_in_tree()
	if _mirror != null and is_instance_valid(_mirror):
		_mirror.visible = visible_in_tree
	if _overlay != null and is_instance_valid(_overlay):
		# Honor the effects state here too — when effects are disabled, the
		# overlay stays hidden regardless of slot visibility.
		_overlay.visible = visible_in_tree and not _effects_disabled()


func _refresh_mirror_texture() -> void:
	if _mirror == null or not is_instance_valid(_mirror):
		return
	_mirror.texture = hd_texture


func _destroy_mirror() -> void:
	if _mirror != null and is_instance_valid(_mirror):
		_mirror.queue_free()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_mirror = null
	_overlay = null
	_mirror_parent = null
