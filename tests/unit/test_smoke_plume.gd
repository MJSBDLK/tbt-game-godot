## SmokePlume is the one consumer of the SMOKE_* knobs: painted smoke follows
## Lawrence's file live. The shader's own uniform defaults (what the editor
## previews) can't read GDScript, so they're pinned to the file here.
extends GutTest


const KNOBS_SCRIPT: GDScript = preload("res://scripts/core/art_variables.gd")
const SHADER_PATH := "res://shaders/smoke_plume.gdshader"
## shader uniform → the knob it mirrors
const UNIFORM_KNOBS := {
	"step_seconds": "SMOKE_STEP_SECONDS",
	"rise_speed": "SMOKE_RISE_SPEED",
	"drift_speed": "SMOKE_DRIFT_SPEED",
	"patch_size": "SMOKE_PATCH_SIZE",
	"breakup": "SMOKE_BREAKUP",
	"thickness": "SMOKE_THICKNESS",
	"thick_steps": "SMOKE_THICK_STEPS",
}

var _saved: Dictionary = {}
var _saved_motion: bool = true


func before_each() -> void:
	for knob in DebugConfig.art_knob_names():
		_saved[knob] = KNOBS_SCRIPT.get(knob)
	_saved_motion = Settings.ui_motion_enabled
	Settings.ui_motion_enabled = true


func after_each() -> void:
	for knob in _saved:
		KNOBS_SCRIPT.set(knob, _saved[knob])
	_saved.clear()
	Settings.ui_motion_enabled = _saved_motion
	DebugConfig.art_knobs_changed.emit()


func _mounted_smoke() -> SmokePlume:
	var smoke := SmokePlume.new()
	smoke.texture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	add_child_autofree(smoke)
	return smoke


func _param(smoke: SmokePlume, name: String) -> float:
	return float((smoke.material as ShaderMaterial).get_shader_parameter(name))


func test_the_smoke_follows_a_turned_knob() -> void:
	var smoke := _mounted_smoke()
	assert_eq((smoke.material as ShaderMaterial).get_shader_parameter("smoke_map"), smoke.texture,
			"the shader reads the rect's own texture")
	assert_almost_eq(_param(smoke, "breakup"), ArtVariables.SMOKE_BREAKUP, 0.001, "built from the file")
	DebugConfig.set_art_knob("SMOKE_BREAKUP", 0.5)
	assert_almost_eq(_param(smoke, "breakup"), 0.5, 0.001, "re-pushed on the signal")
	DebugConfig.set_art_knob("SMOKE_THICK_STEPS", 2)
	assert_almost_eq(_param(smoke, "thick_steps"), 2.0, 0.001, "a whole number of ramp steps")


func test_motion_off_shows_the_painting_as_painted() -> void:
	var smoke := _mounted_smoke()
	assert_almost_eq(_param(smoke, "motion_amount"), 1.0, 0.001)
	Settings.ui_motion_enabled = false
	Settings.changed.emit()
	assert_almost_eq(_param(smoke, "motion_amount"), 0.0, 0.001, "no breakup, no thick patches")


func test_the_shader_defaults_are_the_file() -> void:
	var text := FileAccess.get_file_as_string(SHADER_PATH)
	assert_ne(text, "", "the shader is readable")
	var regex := RegEx.new()
	regex.compile("uniform float (\\w+)[^;=]*= (-?[0-9.]+);")
	var found: Dictionary = {}
	for hit in regex.search_all(text):
		found[hit.get_string(1)] = float(hit.get_string(2))
	for uniform: String in UNIFORM_KNOBS:
		assert_true(found.has(uniform), "the shader still declares %s" % uniform)
		if found.has(uniform):
			assert_almost_eq(found[uniform], float(KNOBS_SCRIPT.get(UNIFORM_KNOBS[uniform])), 0.0001,
					"%s's default must equal ArtVariables.%s" % [uniform, UNIFORM_KNOBS[uniform]])


func test_a_backdrop_layer_named_smoke_drifts() -> void:
	assert_true(CombatBackdrop.is_smoke("volcano_smoke"))
	assert_true(CombatBackdrop.is_smoke("smoke_left"))
	assert_false(CombatBackdrop.is_smoke("smokestack"), "a whole word only")
	assert_false(CombatBackdrop.is_smoke("volcano"))
	var backdrop := CombatBackdrop.new()
	add_child_autofree(backdrop)
	var plumes := 0
	for art: TextureRect in backdrop.floor_layers():
		var smoky := CombatBackdrop.is_smoke(CombatBackdrop.layer_name(art.name))
		assert_eq(art is SmokePlume, smoky, "%s draws through SmokePlume only if it's smoke" % art.name)
		if smoky:
			plumes += 1
	assert_gt(plumes, 0, "the regolith has its volcano smoke")
