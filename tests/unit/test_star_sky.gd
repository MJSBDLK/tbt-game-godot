## StarSky is the one consumer of the STAR_* knobs: the night sky follows
## Lawrence's file live. Two copies of those numbers can't read GDScript — the
## shader's own uniform defaults (what the editor previews) and the lab page's
## slider defaults — so both are pinned to the file here.
extends GutTest


const KNOBS_SCRIPT: GDScript = preload("res://scripts/core/art_variables.gd")
const SHADER_PATH := "res://shaders/star_twinkle.gdshader"
const LAB_PATH := "res://data/design/mockups/skybox_twinkle_lab.html"
## shader uniform (and lab slider) → the knob it mirrors
const UNIFORM_KNOBS := {
	"flash_seconds": "STAR_FLASH_SECONDS",
	"hold_seconds": "STAR_HOLD_SECONDS",
	"frame_rate": "STAR_TICKS_PER_SECOND",
	"period_slow_seconds": "STAR_PERIOD_SLOW_SECONDS",
	"period_fast_seconds": "STAR_PERIOD_FAST_SECONDS",
	"period_jitter": "STAR_PERIOD_JITTER",
	"tail_tip_alpha": "STAR_TAIL_TIP_ALPHA",
	"rest_alpha_min": "STAR_REST_ALPHA_MIN",
}

var _saved: Dictionary = {}
var _saved_motion: bool = true


func before_each() -> void:
	for name in DebugConfig.art_knob_names():
		_saved[name] = KNOBS_SCRIPT.get(name)
	_saved_motion = Settings.ui_motion_enabled
	Settings.ui_motion_enabled = true


func after_each() -> void:
	for name in _saved:
		KNOBS_SCRIPT.set(name, _saved[name])
	_saved.clear()
	Settings.ui_motion_enabled = _saved_motion
	DebugConfig.art_knobs_changed.emit()


func _mounted_sky() -> StarSky:
	var sky := StarSky.new()
	sky.texture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	add_child_autofree(sky)
	return sky


func _param(sky: StarSky, name: String) -> float:
	return float((sky.material as ShaderMaterial).get_shader_parameter(name))


func test_the_sky_follows_a_turned_knob() -> void:
	var sky := _mounted_sky()
	assert_eq((sky.material as ShaderMaterial).get_shader_parameter("star_map"), sky.texture,
			"the shader reads the rect's own texture")
	assert_almost_eq(_param(sky, "tail_tip_alpha"), ArtVariables.STAR_TAIL_TIP_ALPHA, 0.001,
			"built from the file")
	DebugConfig.set_art_knob("STAR_TAIL_TIP_ALPHA", 0.5)
	assert_almost_eq(_param(sky, "tail_tip_alpha"), 0.5, 0.001, "re-pushed on the signal")
	DebugConfig.set_art_knob("STAR_PERIOD_FAST_SECONDS", 3)
	assert_almost_eq(_param(sky, "period_fast_seconds"), 3.0, 0.001, "a console '3' lands as 3.0")


func test_motion_off_parks_every_star() -> void:
	var sky := _mounted_sky()
	assert_almost_eq(_param(sky, "twinkle_amount"), 1.0, 0.001)
	Settings.ui_motion_enabled = false
	Settings.changed.emit()
	assert_almost_eq(_param(sky, "twinkle_amount"), 0.0, 0.001, "no tails, no flares, cores at rest")
	Settings.ui_motion_enabled = true
	Settings.changed.emit()
	assert_almost_eq(_param(sky, "twinkle_amount"), 1.0, 0.001)


func test_the_shader_defaults_are_the_file() -> void:
	# The uniform defaults are what the editor shows on a bare material. They
	# must read as the file does, or an inspector preview lies about the game.
	var text := FileAccess.get_file_as_string(SHADER_PATH)
	assert_ne(text, "", "the shader is readable")
	var regex := RegEx.new()
	regex.compile("uniform float (\\w+)[^;=]*= ([0-9.]+);")
	var found: Dictionary = {}
	for hit in regex.search_all(text):
		found[hit.get_string(1)] = float(hit.get_string(2))
	for uniform in UNIFORM_KNOBS:
		assert_true(found.has(uniform), "the shader still declares %s" % uniform)
		if found.has(uniform):
			assert_almost_eq(found[uniform], float(KNOBS_SCRIPT.get(UNIFORM_KNOBS[uniform])), 0.0001,
					"%s's default must equal ArtVariables.%s" % [uniform, UNIFORM_KNOBS[uniform]])


func test_the_lab_sliders_start_at_the_file() -> void:
	# The lab page runs the shader in a browser, so it carries its own copy of
	# the defaults; Lawrence tunes from what the game actually draws.
	var text := FileAccess.get_file_as_string(LAB_PATH)
	assert_ne(text, "", "the lab page is readable")
	var block := RegEx.new()
	block.compile("var DEFAULTS = \\{([^}]*)\\}")
	var defaults := block.search(text)
	assert_not_null(defaults, "the page still has a DEFAULTS block")
	if defaults == null:
		return
	for uniform in UNIFORM_KNOBS:
		var entry := RegEx.new()
		entry.compile("\\b%s: ([0-9.]+)" % uniform)
		var hit := entry.search(defaults.get_string(1))
		assert_not_null(hit, "DEFAULTS names %s" % uniform)
		if hit != null:
			assert_almost_eq(float(hit.get_string(1)), float(KNOBS_SCRIPT.get(UNIFORM_KNOBS[uniform])), 0.0001,
					"the lab's %s must equal ArtVariables.%s" % [uniform, UNIFORM_KNOBS[uniform]])
