## Renders a pixel-art panel border from 8 chopped pieces (4 corners + 4 edges).
## Corners are placed at the four panel corners. Edges are cropped (not tiled/stretched)
## to fill the gaps between corners, rendered underneath so corners draw on top.
## Attach as a child of any Control and set anchors to Full Rect.
class_name PanelBorderOverlay
extends Control


@export var corner_top_left: Texture2D
@export var corner_top_right: Texture2D
@export var corner_bottom_left: Texture2D
@export var corner_bottom_right: Texture2D
@export var edge_top: Texture2D
@export var edge_right: Texture2D
@export var edge_bottom: Texture2D
@export var edge_left: Texture2D

# Edge clippers (Control with clip_contents=true)
var _top_clipper: Control
var _right_clipper: Control
var _bottom_clipper: Control
var _left_clipper: Control

# Edge textures inside clippers
var _top_edge_rect: TextureRect
var _right_edge_rect: TextureRect
var _bottom_edge_rect: TextureRect
var _left_edge_rect: TextureRect

# Corner textures
var _corner_top_left_rect: TextureRect
var _corner_top_right_rect: TextureRect
var _corner_bottom_left_rect: TextureRect
var _corner_bottom_right_rect: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_nodes()
	_layout_border()
	_build_debug_badge()
	resized.connect(_layout_border)


## Themed debug tag (RQD 2026-07-31): the owning panel's class initials etched
## into the border's top-right corner — reads as a serial marking in
## screenshots, names the misbehaving menu in bug reports ("the brackets bug
## is in AMP"). One switch: DebugConfig.debug_menu_badges (restart to apply,
## like every DebugConfig flag).
func _build_debug_badge() -> void:
	if DebugConfig == null or not DebugConfig.debug_menu_badges:
		return
	var badge := Label.new()
	badge.name = "DebugBadge"
	badge.text = badge_initials(_owner_class_name())
	if UIManager != null and UIManager.font_5px != null:
		badge.add_theme_font_override("font", UIManager.font_5px)
		badge.add_theme_font_size_override("font_size", 5)
	badge.add_theme_color_override("font_color", GameColorPalette.get_color("Gray", 6))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# Tucked onto the border art itself: 2px down, ending 6px shy of the
	# right edge — inside the corner piece, clear of panel content.
	badge.offset_top = 2
	badge.offset_right = -6


func _owner_class_name() -> String:
	var host := get_parent()
	if host == null:
		return ""
	var script: Script = host.get_script()
	if script != null and script.get_global_name() != &"":
		return String(script.get_global_name())
	return host.get_class()


## "ActionMenuPanel" -> "AMP". Uppercase initials are short, unique across
## the current panel roster, and self-derived — a new panel gets a badge for
## free. Pure + static for GUT.
static func badge_initials(from_class_name: String) -> String:
	var initials := ""
	for i: int in from_class_name.length():
		var character := from_class_name[i]
		if character == character.to_upper() and character != character.to_lower():
			initials += character
	if initials == "":
		return from_class_name.left(3).to_upper()
	return initials


func _build_nodes() -> void:
	# Edges first (draw underneath corners)
	_top_clipper = _create_clipper()
	_top_edge_rect = _create_texture_rect(edge_top)
	_top_clipper.add_child(_top_edge_rect)
	add_child(_top_clipper)

	_right_clipper = _create_clipper()
	_right_edge_rect = _create_texture_rect(edge_right)
	_right_clipper.add_child(_right_edge_rect)
	add_child(_right_clipper)

	_bottom_clipper = _create_clipper()
	_bottom_edge_rect = _create_texture_rect(edge_bottom)
	_bottom_clipper.add_child(_bottom_edge_rect)
	add_child(_bottom_clipper)

	_left_clipper = _create_clipper()
	_left_edge_rect = _create_texture_rect(edge_left)
	_left_clipper.add_child(_left_edge_rect)
	add_child(_left_clipper)

	# Corners second (draw on top of edges)
	_corner_top_left_rect = _create_texture_rect(corner_top_left)
	add_child(_corner_top_left_rect)

	_corner_top_right_rect = _create_texture_rect(corner_top_right)
	add_child(_corner_top_right_rect)

	_corner_bottom_left_rect = _create_texture_rect(corner_bottom_left)
	add_child(_corner_bottom_left_rect)

	_corner_bottom_right_rect = _create_texture_rect(corner_bottom_right)
	add_child(_corner_bottom_right_rect)


func _layout_border() -> void:
	var panel_width: float = size.x
	var panel_height: float = size.y

	# Read corner sizes from textures
	var tl_size := _tex_size(corner_top_left)
	var tr_size := _tex_size(corner_top_right)
	var bl_size := _tex_size(corner_bottom_left)
	var br_size := _tex_size(corner_bottom_right)

	# Place corners
	_corner_top_left_rect.position = Vector2(0, 0)
	_corner_top_left_rect.size = tl_size

	_corner_top_right_rect.position = Vector2(panel_width - tr_size.x, 0)
	_corner_top_right_rect.size = tr_size

	_corner_bottom_left_rect.position = Vector2(0, panel_height - bl_size.y)
	_corner_bottom_left_rect.size = bl_size

	_corner_bottom_right_rect.position = Vector2(panel_width - br_size.x, panel_height - br_size.y)
	_corner_bottom_right_rect.size = br_size

	# Place edge clippers and center edge textures within them
	_layout_edge_horizontal(
		_top_clipper, _top_edge_rect, edge_top,
		tl_size.x, 0.0,
		panel_width - tl_size.x - tr_size.x)

	_layout_edge_horizontal(
		_bottom_clipper, _bottom_edge_rect, edge_bottom,
		bl_size.x, panel_height - _tex_size(edge_bottom).y,
		panel_width - bl_size.x - br_size.x)

	_layout_edge_vertical(
		_left_clipper, _left_edge_rect, edge_left,
		0.0, tl_size.y,
		panel_height - tl_size.y - bl_size.y)

	_layout_edge_vertical(
		_right_clipper, _right_edge_rect, edge_right,
		panel_width - _tex_size(edge_right).x, tr_size.y,
		panel_height - tr_size.y - br_size.y)


func _layout_edge_horizontal(clipper: Control, texture_rect: TextureRect,
		texture: Texture2D, x: float, y: float, gap_width: float) -> void:
	if texture == null or gap_width <= 0:
		clipper.visible = false
		return
	clipper.visible = true
	var edge_size := texture.get_size()
	clipper.position = Vector2(x, y)
	clipper.size = Vector2(gap_width, edge_size.y)
	texture_rect.size = edge_size
	texture_rect.position.x = floori((gap_width - edge_size.x) / 2.0)
	texture_rect.position.y = 0


func _layout_edge_vertical(clipper: Control, texture_rect: TextureRect,
		texture: Texture2D, x: float, y: float, gap_height: float) -> void:
	if texture == null or gap_height <= 0:
		clipper.visible = false
		return
	clipper.visible = true
	var edge_size := texture.get_size()
	clipper.position = Vector2(x, y)
	clipper.size = Vector2(edge_size.x, gap_height)
	texture_rect.size = edge_size
	texture_rect.position.x = 0
	texture_rect.position.y = floori((gap_height - edge_size.y) / 2.0)


func _create_clipper() -> Control:
	var clipper := Control.new()
	clipper.clip_contents = true
	clipper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return clipper


func _create_texture_rect(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture:
		rect.size = texture.get_size()
	return rect


func _tex_size(texture: Texture2D) -> Vector2:
	return texture.get_size() if texture else Vector2.ZERO
