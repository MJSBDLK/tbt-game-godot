extends ColorRect
class_name GlowColorRect

@export var glow_color: Color = Color.WHITE:
	set(value):
		glow_color = value
		_apply_glow_color()

## When true, renders a 1px border (colored by self_modulate) inset by 1px,
## with glow extending 1px on both sides (3px total).
@export var border_mode: bool = false

func _ready() -> void:
	if material:
		material = material.duplicate()
		(material as ShaderMaterial).set_shader_parameter("solid_rect", true)
		if border_mode:
			(material as ShaderMaterial).set_shader_parameter("border_mode", true)
		_apply_glow_color()
		_update_rect_size()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_rect_size()

func _apply_glow_color() -> void:
	if material and material is ShaderMaterial:
		material.set_shader_parameter("glow_color", glow_color)

func _update_rect_size() -> void:
	if material and material is ShaderMaterial:
		material.set_shader_parameter("rect_size", size)
