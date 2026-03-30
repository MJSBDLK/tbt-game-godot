@tool
extends ColorRect
class_name MoveChip

@export var fill_color: Color = Color(0.8, 0.3, 0.1, 1.0):
	set(value):
		fill_color = value
		_apply_shader_params()

@export var empty_color: Color = Color(0.3, 0.1, 0.05, 1.0):
	set(value):
		empty_color = value
		_apply_shader_params()

@export var border_color: Color = Color(0.15, 0.15, 0.15, 1.0):
	set(value):
		border_color = value
		_apply_shader_params()

const MAX_FILL: float = 0.929

@export_range(0.0, 1.0) var fill_percent: float = 0.6:
	set(value):
		fill_percent = value
		_apply_shader_params()

@export_range(0.0, 45.0) var skew_angle: float = 45.0:
	set(value):
		skew_angle = value
		_apply_shader_params()

@export_range(0.0, 4.0) var border_px: float = 1.0:
	set(value):
		border_px = value
		_apply_shader_params()

@export_range(0.0, 10.0) var radius_px: float = 3.0:
	set(value):
		radius_px = value
		_apply_shader_params()

var _material_ready: bool = false


func _ready() -> void:
	if material:
		material = material.duplicate()
		_material_ready = true
		_apply_shader_params()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_shader_params()


func _apply_shader_params() -> void:
	if not _material_ready:
		return
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("fill_color", fill_color)
	shader_material.set_shader_parameter("empty_color", empty_color)
	shader_material.set_shader_parameter("border_color", border_color)
	shader_material.set_shader_parameter("fill_percent", fill_percent * MAX_FILL)
	shader_material.set_shader_parameter("skew_angle", skew_angle)
	shader_material.set_shader_parameter("border_px", border_px)
	shader_material.set_shader_parameter("radius_px", radius_px)
	shader_material.set_shader_parameter("rect_size", get_rect().size)
