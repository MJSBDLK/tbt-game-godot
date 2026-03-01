extends Label
class_name GlowLabel

@export var glow_color: Color = Color.WHITE:
	set(value):
		glow_color = value
		_apply_glow_color()

var _glow_material_path: String = "res://resources/hud_glow.tres"

func _ready() -> void:
	if material:
		material = material.duplicate()
		_apply_glow_color()

func _apply_glow_color() -> void:
	if material and material is ShaderMaterial:
		material.set_shader_parameter("glow_color", glow_color)
