## Side-by-side test for the SubViewport-flip + HD overlay architecture.
##
## Left column: an ordinary TextureRect with the 64x64 painted portrait at
## nearest filter — what shipping units look like today. It renders inside
## the 640x360 SubViewport, so it gets nearest-upscaled with the rest of the
## pixel UI.
##
## Right column: an HDPortraitSlot that reserves a 128x128 pixel-UI rect and
## asks the root-level HDLayer to overlay the 3024x4032 line art at native
## window resolution with bilinear-mipmap filtering. The slot itself is
## invisible; only the HD mirror is rendered. Both columns end up at the
## same on-screen size so they're easy to compare side-by-side.
##
## To run: open this scene and F6, OR run the project (GameRoot will load
## start_screen by default — set run/main_scene temporarily or use the
## SceneRouter from a debug command to load this scene).
extends Control


@onready var diagnostics: Label = $Diagnostics


func _ready() -> void:
	_refresh_diagnostics()
	get_viewport().size_changed.connect(_refresh_diagnostics)


func _refresh_diagnostics() -> void:
	var stretch_mode: String = str(
		ProjectSettings.get_setting("display/window/stretch/mode", "?"))
	var ref_w: int = int(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	var ref_h: int = int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	var local_viewport: Viewport = get_viewport()
	var window_size: Vector2i = get_window().size
	diagnostics.text = "stretch=%s  reference=%dx%d  subviewport=%dx%d  window=%dx%d" % [
		stretch_mode, ref_w, ref_h,
		int(local_viewport.get_visible_rect().size.x),
		int(local_viewport.get_visible_rect().size.y),
		window_size.x, window_size.y]
