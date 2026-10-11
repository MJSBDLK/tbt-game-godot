## The twinkling night sky: Lawrence's skybox_twinkle layer drawn through
## shaders/star_twinkle.gdshader. Every dial the shader takes is an
## ArtVariables STAR_* knob, pushed here at build and again whenever the
## console turns one; Settings.ui_motion_enabled off parks every star.
## Draws transparent outside the stars — whoever mounts this paints
## GameColors.NIGHT_SKY underneath.
class_name StarSky
extends TextureRect


const SHADER: Shader = preload("res://shaders/star_twinkle.gdshader")

## Off over a painted sky (the combat backdrop): the painting already shows
## every star at rest, so only the flashes draw. On where nothing painted is
## underneath (the menu stage today, the demo) and STAR_REST_ALPHA_MIN applies.
var draws_resting_stars: bool = true:
	set(value):
		draws_resting_stars = value
		if material != null:
			refresh()


## A material carrying the file's current dials, for probes and the demo
## scene that draw the sky without this node.
static func build_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	push_knobs(material)
	return material


## Every STAR_* dial, the star colour and the motion setting onto the material.
static func push_knobs(material: ShaderMaterial) -> void:
	material.set_shader_parameter("star_color", GameColors.STAR_TWINKLE)
	material.set_shader_parameter("step_seconds", ArtVariables.STAR_STEP_SECONDS)
	material.set_shader_parameter("hold_seconds", ArtVariables.STAR_HOLD_SECONDS)
	material.set_shader_parameter("dim_hold_seconds", ArtVariables.STAR_DIM_HOLD_SECONDS)
	material.set_shader_parameter("period_slow_seconds", ArtVariables.STAR_PERIOD_SLOW_SECONDS)
	material.set_shader_parameter("period_fast_seconds", ArtVariables.STAR_PERIOD_FAST_SECONDS)
	material.set_shader_parameter("period_jitter", ArtVariables.STAR_PERIOD_JITTER)
	material.set_shader_parameter("tail_tip_alpha", ArtVariables.STAR_TAIL_TIP_ALPHA)
	material.set_shader_parameter("rest_alpha_min", ArtVariables.STAR_REST_ALPHA_MIN)
	material.set_shader_parameter("twinkle_amount", 1.0 if Settings.ui_motion_enabled else 0.0)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = build_material()
	refresh()
	set_star_map(texture)
	DebugConfig.art_knobs_changed.connect(refresh)
	Settings.changed.connect(refresh)


## The painted layer, drawn by the rect AND read by the shader (see the
## star_map uniform). Setting `texture` alone leaves the shader blind.
func set_star_map(map: Texture2D) -> void:
	texture = map
	if material != null:
		(material as ShaderMaterial).set_shader_parameter("star_map", map)


func refresh() -> void:
	push_knobs(material as ShaderMaterial)
	(material as ShaderMaterial).set_shader_parameter("rest_core_amount", 1.0 if draws_resting_stars else 0.0)
