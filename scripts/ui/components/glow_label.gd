extends Label
class_name GlowLabel

@export var glow_color: Color = Color.WHITE:
	set(value):
		glow_color = value
		_apply_glow_color()

var _glow_material_path: String = "res://resources/hud_glow.tres"


## Code-built glow text in one call: body color + its orthogonal-glow partner
## (always pass one of GameColors' TEXT_*/TEXT_*_GLOW pairs — the voices are a
## locked set, ui-style-guide §2). Every screen was hand-assembling this
## five-line recipe; the factory keeps the material/duplicate dance in one
## place.
static func styled(text_value: String, font: FontFile, font_size: int,
		color: Color, glow: Color) -> GlowLabel:
	var label := GlowLabel.new()
	label.text = text_value
	# Duplicate BEFORE the glow_color setter runs — the setter writes a shader
	# parameter, and writing it on the shared .tres would bleed this label's
	# color into every glow user in the project.
	label.material = (load("res://resources/hud_glow.tres") as Material).duplicate()
	label.glow_color = glow
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _ready() -> void:
	if material:
		material = material.duplicate()
		_apply_glow_color()

func _apply_glow_color() -> void:
	if material and material is ShaderMaterial:
		material.set_shader_parameter("glow_color", glow_color)
