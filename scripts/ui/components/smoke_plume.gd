## Painted smoke, alive: a layer whose pixels are the smoke at rest, drawn
## through shaders/smoke_plume.gdshader, which runs thick and thin patches
## through it as it drifts. Every dial is an ArtVariables SMOKE_* knob, pushed
## at build and again whenever the console turns one; Settings.ui_motion_enabled
## off shows the painting as painted.
class_name SmokePlume
extends TextureRect


const SHADER: Shader = preload("res://shaders/smoke_plume.gdshader")


## A material carrying the file's current dials, for probes and tests that
## draw smoke without this node.
static func build_material() -> ShaderMaterial:
	var smoke_material := ShaderMaterial.new()
	smoke_material.shader = SHADER
	push_knobs(smoke_material)
	return smoke_material


## Every SMOKE_* dial and the motion setting onto the material.
static func push_knobs(smoke_material: ShaderMaterial) -> void:
	smoke_material.set_shader_parameter("step_seconds", ArtVariables.SMOKE_STEP_SECONDS)
	smoke_material.set_shader_parameter("rise_speed", ArtVariables.SMOKE_RISE_SPEED)
	smoke_material.set_shader_parameter("drift_speed", ArtVariables.SMOKE_DRIFT_SPEED)
	smoke_material.set_shader_parameter("patch_size", ArtVariables.SMOKE_PATCH_SIZE)
	smoke_material.set_shader_parameter("breakup", ArtVariables.SMOKE_BREAKUP)
	smoke_material.set_shader_parameter("thickness", ArtVariables.SMOKE_THICKNESS)
	smoke_material.set_shader_parameter("thick_steps", float(ArtVariables.SMOKE_THICK_STEPS))
	smoke_material.set_shader_parameter("motion_amount", 1.0 if Settings.ui_motion_enabled else 0.0)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = build_material()
	set_smoke_map(texture)
	DebugConfig.art_knobs_changed.connect(refresh)
	Settings.changed.connect(refresh)


## The painted layer, drawn by the rect AND read by the shader (the smoke_map
## uniform). Setting `texture` alone leaves the shader blind.
func set_smoke_map(map: Texture2D) -> void:
	texture = map
	if material != null:
		(material as ShaderMaterial).set_shader_parameter("smoke_map", map)


func refresh() -> void:
	push_knobs(material as ShaderMaterial)
