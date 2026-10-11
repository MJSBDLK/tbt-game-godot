extends TextureRect
class_name HealthPipBar
## Displays a health pip bar with three visual zones:
## filled (faction color), damage preview (pulsing), and empty.
## Requires a ShaderMaterial using health_pip_bar.gdshader.

## One pip is a row of the art and the gap under it.
const PIP_PITCH: int = 2

@export var health_fill: float = 1.0:
	set(value):
		health_fill = clampf(value, 0.0, 1.0)
		_apply_shader_params()

@export var damage_fill: float = 0.0:
	set(value):
		damage_fill = clampf(value, 0.0, 1.0)
		_apply_shader_params()

@export var filled_color: Color = Color(0.44, 0.65, 0.43, 1.0):
	set(value):
		filled_color = value
		_apply_shader_params()

@export var filled_glow: Color = Color(0.18, 0.31, 0.18, 1.0):
	set(value):
		filled_glow = value
		_apply_shader_params()

@export var damage_color: Color = Color(0.5, 0.5, 0.5, 1.0):
	set(value):
		damage_color = value
		_apply_shader_params()

@export var damage_glow: Color = Color(0.3, 0.3, 0.3, 1.0):
	set(value):
		damage_glow = value
		_apply_shader_params()

@export var pulse_speed: float = 2.0:
	set(value):
		pulse_speed = value
		_apply_shader_params()

@export var inverted: bool = false:
	set(value):
		inverted = value
		_apply_shader_params()


func _ready() -> void:
	if material:
		material = material.duplicate()
		_apply_shader_params()


## `health` lit and a pulsing `band` above it, in HP out of `max_hp`. Any
## health left lights at least one pip: a unit that survives on 1 HP never
## reads as a kill.
func show_hp(health: int, band: int, max_hp: int) -> void:
	assert(texture != null, "HealthPipBar: no pip art to measure a pip by")
	var per_hp := 1.0 / maxf(1.0, float(max_hp))
	var one_pip := float(PIP_PITCH) / float(texture.get_height())
	health_fill = maxf(health * per_hp, one_pip) if health > 0 else 0.0
	damage_fill = maxf(0.0, (health + band) * per_hp - health_fill)


func _apply_shader_params() -> void:
	if material and material is ShaderMaterial:
		material.set_shader_parameter("health_fill", health_fill)
		material.set_shader_parameter("damage_fill", damage_fill)
		material.set_shader_parameter("filled_color", filled_color)
		material.set_shader_parameter("filled_glow", filled_glow)
		material.set_shader_parameter("damage_color", damage_color)
		material.set_shader_parameter("damage_glow", damage_glow)
		material.set_shader_parameter("pulse_speed", pulse_speed)
		material.set_shader_parameter("inverted", inverted)
