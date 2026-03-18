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
	resized.connect(_layout_border)


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
