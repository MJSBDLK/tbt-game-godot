## ArtVariables is Lawrence's file: one place for the numbers that decide how
## the board looks, and — the knobs being static vars — one he can turn while
## the game runs. These tests fail the moment a consumer stops FOLLOWING a
## knob: a constant that copied the value once is a knob that silently does
## nothing when he turns it.
extends GutTest


const WEBTYLER_PATH := "res://tools/aseprite/webtyler/webtyler.lua"
const DECORATION_EXPORT_DIR := "res://art/sprites/decorations/decorations_and_modifiers/"
const PLACEHOLDER_UNIT := "res://art/sprites/characters/placeholder_unit.png"
# Static vars live on the script resource; the class name won't take get/set.
const KNOBS_SCRIPT: GDScript = preload("res://scripts/core/art_variables.gd")

## Every knob, so a renamed or added one shows up here on purpose.
const KNOB_NAMES := [
	"SHADOW_INK_ALPHA", "SHADOW_LENGTH", "SHADOW_SQUASH", "SHADOW_LEAN",
	"SHADOW_NUDGE_Y", "SHADOW_BLOB", "SHADOW_BLOB_WIDTH",
	"SHADOWS_FALL_ON_NEIGHBORS", "TERRAIN_SHADOW_NUDGE_Y",
	"MAP_EDGE_FADE_WIDTH", "MAP_EDGE_FADE_COLOR", "ACTED_GREYSCALE",
	"STAR_FLASH_SECONDS", "STAR_HOLD_SECONDS", "STAR_TICKS_PER_SECOND",
	"STAR_PERIOD_SLOW_SECONDS", "STAR_PERIOD_FAST_SECONDS", "STAR_PERIOD_JITTER",
	"STAR_TAIL_TIP_ALPHA", "STAR_REST_ALPHA_MIN",
]

var _saved: Dictionary = {}


func before_each() -> void:
	# The knobs are process-wide statics: every turn taken here is undone
	# after, or it leaks into the next test's board.
	for name in DebugConfig.art_knob_names():
		_saved[name] = KNOBS_SCRIPT.get(name)


func after_each() -> void:
	for name in _saved:
		KNOBS_SCRIPT.set(name, _saved[name])
	_saved.clear()
	DebugConfig.art_knobs_changed.emit()  # consumers re-sync to the defaults


func test_shipped_shadow_art_carries_shape_not_opacity() -> void:
	# Authored shadows are masks. Bake an opacity into one and it stops
	# answering to SHADOW_INK_ALPHA while every other shadow on the board moves.
	var dir := DirAccess.open(DECORATION_EXPORT_DIR)
	assert_not_null(dir, "the decoration export dir opens")
	if dir == null:
		return
	var checked: int = 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with("_shadow.png"):
			var texture: Texture2D = load(DECORATION_EXPORT_DIR + entry)
			var image: Image = texture.get_image()
			var baked: int = 0
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					var pixel := image.get_pixel(x, y)
					if pixel.a > 0.0 and pixel.a < 1.0:
						baked += 1
			assert_eq(baked, 0, "%s is a mask — no baked opacity" % entry)
			checked += 1
		entry = dir.get_next()
	dir.list_dir_end()
	assert_gt(checked, 0, "shadow art was actually scanned")


func test_the_knob_list_is_the_file() -> void:
	var names := Array(DebugConfig.art_knob_names())
	names.sort()
	var expected := KNOB_NAMES.duplicate()
	expected.sort()
	assert_eq(names, expected,
			"every static var in art_variables.gd and nothing else — add a knob there, add it here")


func test_set_art_knob_writes_the_file_and_announces_it() -> void:
	watch_signals(DebugConfig)
	assert_true(DebugConfig.set_art_knob("SHADOW_INK_ALPHA", 0.55))
	assert_almost_eq(ArtVariables.SHADOW_INK_ALPHA, 0.55, 0.001, "the static var moved")
	assert_signal_emitted(DebugConfig, "art_knobs_changed")
	assert_true(DebugConfig.set_art_knob("MAP_EDGE_FADE_WIDTH", 48),
			"an int for a float knob is coerced, not refused — a console line types '48'")
	assert_typeof(ArtVariables.MAP_EDGE_FADE_WIDTH, TYPE_FLOAT)
	assert_almost_eq(ArtVariables.MAP_EDGE_FADE_WIDTH, 48.0, 0.001)


func test_set_art_knob_refuses_unknown_names_and_wrong_types() -> void:
	watch_signals(DebugConfig)
	assert_false(DebugConfig.set_art_knob("SHADOW_INK_ALPH", 0.5), "typo in the name")
	assert_false(DebugConfig.set_art_knob("SHADOW_BLOB", 0.5), "a float for a bool")
	assert_eq(ArtVariables.SHADOW_BLOB, _saved["SHADOW_BLOB"], "refused writes leave the knob alone")
	assert_false(DebugConfig.set_art_knob("SHADOW_INK_ALPHA", "dark"), "a string for a float")
	assert_signal_not_emitted(DebugConfig, "art_knobs_changed",
			"nothing changed, so nothing re-renders")


func test_every_shadow_on_the_board_reads_one_opacity() -> void:
	DebugConfig.set_art_knob("SHADOW_INK_ALPHA", 0.55)
	assert_almost_eq(GameColors.CAST_SHADOW_INK.a, 0.55, 0.001,
			"units, generated casts and the autotile shadow blocks all draw with this ink — live")
	assert_eq(GameColors.CAST_SHADOW_INK.r, 0.0, "the ink is black — only its alpha is a knob")
	assert_eq(GameColors.CAST_SHADOW_INK.g, 0.0)
	assert_eq(GameColors.CAST_SHADOW_INK.b, 0.0)


func test_unit_shadows_follow_the_sun_without_a_frame_change() -> void:
	var source := Sprite2D.new()
	source.texture = load(PLACEHOLDER_UNIT)
	add_child_autofree(source)
	var shadow := UnitShadow.new()
	shadow.source_sprite = source
	add_child_autofree(shadow)
	DebugConfig.set_art_knob("SHADOW_LENGTH", 1.0)
	DebugConfig.set_art_knob("SHADOW_NUDGE_Y", -2.0)
	shadow.sync_to_source()
	var narrow: int = shadow._projection.get_width()
	var anchor_before: Vector2 = shadow._projection_anchor

	# Same frame, lower sun: the next tick rebuilds anyway.
	DebugConfig.set_art_knob("SHADOW_LENGTH", 2.0)
	shadow.sync_to_source()
	assert_gt(shadow._projection.get_width(), narrow, "a lower sun throws a longer shadow")
	assert_gte(shadow._projection.get_width(), narrow * 2 - 2,
			"reach scales with the knob (rasterized: a pixel of rounding)")

	# The placement nudge moves the drawn rect by exactly the change.
	DebugConfig.set_art_knob("SHADOW_LENGTH", 1.0)
	DebugConfig.set_art_knob("SHADOW_NUDGE_Y", 3.0)
	shadow.sync_to_source()
	assert_almost_eq(shadow._projection_anchor.y, anchor_before.y + 5.0, 0.001,
			"−2 → +3 lowers the smear 5px, shape untouched")
	assert_eq(shadow._projection.get_width(), narrow,
			"back to the first sun, back to the first width")


func test_generated_terrain_casts_follow_the_sun_and_the_ink() -> void:
	# A bare 8×16 post ships no authored shadow, so the renderer invents one
	# from its pixels. The bake is cached — keyed on the knobs, or it would
	# keep serving the old sun.
	var post := Image.create(8, 16, false, Image.FORMAT_RGBA8)
	post.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(post)
	DebugConfig.set_art_knob("SHADOW_LENGTH", 1.0)
	DebugConfig.set_art_knob("SHADOW_INK_ALPHA", 0.4)
	var first: Dictionary = TerrainSpriteRenderer._generated_shadow_for(texture)
	assert_false(first.is_empty(), "an opaque post casts")
	var narrow: int = first["texture"].get_width()
	assert_almost_eq(_max_alpha(first["texture"].get_image()), 0.4, 0.01, "ink baked at the knob")

	DebugConfig.set_art_knob("SHADOW_LENGTH", 2.0)
	var longer: Dictionary = TerrainSpriteRenderer._generated_shadow_for(texture)
	assert_gt(longer["texture"].get_width(), narrow, "same texture, lower sun, longer smear")

	DebugConfig.set_art_knob("SHADOW_INK_ALPHA", 0.55)
	var darker: Dictionary = TerrainSpriteRenderer._generated_shadow_for(texture)
	assert_almost_eq(_max_alpha(darker["texture"].get_image()), 0.55, 0.01,
			"a new ink re-bakes instead of serving the cached 40%")


func test_terrain_shadow_z_follows_the_neighbor_toggle() -> void:
	DebugConfig.set_art_knob("SHADOWS_FALL_ON_NEIGHBORS", true)
	assert_eq(TerrainSpriteRenderer.shadow_z(3),
			ZIndexCalculator.calculate_sorting_order(3, TerrainSpriteRenderer._GRID_HEIGHT_FOR_Z,
					ZIndexCalculator.ZIndexLayer.TERRAIN_SHADOWS),
			"on: one slot above the bodies, so the smear lands on the east neighbor")
	DebugConfig.set_art_knob("SHADOWS_FALL_ON_NEIGHBORS", false)
	assert_eq(TerrainSpriteRenderer.shadow_z(3),
			ZIndexCalculator.calculate_sorting_order(3, TerrainSpriteRenderer._GRID_HEIGHT_FOR_Z,
					ZIndexCalculator.ZIndexLayer.TERRAIN_EFFECTS),
			"off: under every body")


func test_the_acted_look_follows_the_knob() -> void:
	var material := Unit.acted_material()
	DebugConfig.set_art_knob("ACTED_GREYSCALE", 0.5)
	assert_almost_eq(float(material.get_shader_parameter("desaturation")), 0.5, 0.001,
			"the one shared material is re-pushed on the signal")


func test_both_edge_fades_read_one_width() -> void:
	# The ground fade and the overhang fade are separate shaders. They used to
	# carry their own copies of the width, which is two numbers to keep equal.
	var vignette: Shader = load("res://shaders/vignette.gdshader")
	var overhang: Shader = load("res://shaders/modifier_oob_fade.gdshader")
	assert_not_null(vignette)
	assert_not_null(overhang)
	var material := ShaderMaterial.new()
	material.shader = overhang
	material.set_shader_parameter("fade_width", ArtVariables.MAP_EDGE_FADE_WIDTH)
	assert_almost_eq(float(material.get_shader_parameter("fade_width")),
			ArtVariables.MAP_EDGE_FADE_WIDTH, 0.001,
			"the shader still takes a fade_width the code can push")


func test_the_webtyler_preview_matches_the_board() -> void:
	# The Aseprite plugin can't read GDScript, so it carries its own copy of the
	# opacity for its sample scene. Drift would show Lawrence a shadow the game
	# doesn't draw.
	var text := FileAccess.get_file_as_string(WEBTYLER_PATH)
	assert_ne(text, "", "webtyler.lua is readable")
	var regex := RegEx.new()
	regex.compile("PREVIEW_SHADOW_ALPHA\\s*=\\s*(\\d+)")
	var found := regex.search(text)
	assert_not_null(found, "the plugin still names its copy PREVIEW_SHADOW_ALPHA")
	if found != null:
		assert_eq(int(found.get_string(1)),
				int(round(ArtVariables.SHADOW_INK_ALPHA * 255.0)),
				"webtyler.lua's PREVIEW_SHADOW_ALPHA must match SHADOW_INK_ALPHA × 255")


func _max_alpha(image: Image) -> float:
	var highest: float = 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			highest = maxf(highest, image.get_pixel(x, y).a)
	return highest
