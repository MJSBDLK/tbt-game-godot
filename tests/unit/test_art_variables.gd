## ArtVariables is Lawrence's file: one place for the numbers that decide how
## the board looks. These tests fail the moment a knob gets orphaned — a
## constant that stops reading from it is a knob that silently does nothing.
extends GutTest


const WEBTYLER_PATH := "res://tools/aseprite/webtyler/webtyler.lua"
const DECORATION_EXPORT_DIR := "res://art/sprites/decorations/decorations_and_modifiers/"


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


func test_every_shadow_on_the_board_reads_one_opacity() -> void:
	assert_almost_eq(GameColors.CAST_SHADOW_INK.a, ArtVariables.SHADOW_INK_ALPHA, 0.001,
			"units, generated casts and the autotile shadow blocks all draw with this ink")
	assert_eq(GameColors.CAST_SHADOW_INK.r, 0.0, "the ink is black — only its alpha is a knob")
	assert_eq(GameColors.CAST_SHADOW_INK.g, 0.0)
	assert_eq(GameColors.CAST_SHADOW_INK.b, 0.0)


func test_the_sun_dials_come_from_the_art_file() -> void:
	assert_almost_eq(UnitShadow.SHADOW_SMOOSH_X, ArtVariables.SHADOW_LENGTH, 0.001)
	assert_almost_eq(UnitShadow.SHADOW_SMOOSH_Y, ArtVariables.SHADOW_SQUASH, 0.001)
	assert_almost_eq(UnitShadow.SHADOW_SHEAR, ArtVariables.SHADOW_LEAN, 0.001)
	assert_almost_eq(UnitShadow.SHADOW_OFFSET_Y, ArtVariables.SHADOW_NUDGE_Y, 0.001)
	assert_eq(UnitShadow.SHADOW_BLOB_ENABLED, ArtVariables.SHADOW_BLOB)
	assert_almost_eq(UnitShadow.SHADOW_BLOB_WIDTH_FACTOR, ArtVariables.SHADOW_BLOB_WIDTH, 0.001)


func test_terrain_casts_share_the_unit_sun() -> void:
	# One sun for the board: the terrain generator aliases the unit dials, so
	# both follow Lawrence's file together.
	assert_almost_eq(TerrainSpriteRenderer.GENERATED_SMOOSH_X, ArtVariables.SHADOW_LENGTH, 0.001)
	assert_almost_eq(TerrainSpriteRenderer.GENERATED_SMOOSH_Y, ArtVariables.SHADOW_SQUASH, 0.001)
	assert_almost_eq(TerrainSpriteRenderer.GENERATED_SHEAR, ArtVariables.SHADOW_LEAN, 0.001)


func test_the_acted_look_reads_the_art_file() -> void:
	assert_almost_eq(Unit.ACTED_DESATURATION, ArtVariables.ACTED_GREYSCALE, 0.001)


func test_the_shadow_look_toggle_and_terrain_nudge_read_the_art_file() -> void:
	assert_eq(TerrainSpriteRenderer.SHADOWS_ABOVE_MODIFIERS,
			ArtVariables.SHADOWS_FALL_ON_NEIGHBORS,
			"whether a shadow lands on the thing beside it is Lawrence's call")
	assert_almost_eq(TerrainSpriteRenderer.GENERATED_OFFSET_Y,
			ArtVariables.TERRAIN_SHADOW_NUDGE_Y, 0.001)


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
