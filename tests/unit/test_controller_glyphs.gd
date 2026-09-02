extends GutTest
## Pins the controller glyph sprite system (the drawn chips replacing the
## hint bar's "[A]" text scaffold — brief:
## data/design/art-requests/controller-glyphs.html).
##
## The contract: every label joy_button_label can emit, on every skin, either
## has a generated sprite or is on the deliberate text-only list. A label
## falling through BOTH lists is an authoring gap this test catches before a
## playtester sees "[Cross]" in brackets.

## Every JoyButton the label function speaks for.
const LABELED_BUTTONS: Array[JoyButton] = [
	JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y,
	JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
	JOY_BUTTON_START, JOY_BUTTON_BACK,
	JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK,
	JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN,
	JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
]


func test_every_skin_label_resolves_to_sprite_or_deliberate_text() -> void:
	for skin: HintBarCommands.JoySkin in HintBarCommands.JoySkin.values():
		for button: JoyButton in LABELED_BUTTONS:
			var label := HintBarCommands.joy_button_label(button, skin)
			if label.is_empty():
				continue
			var mapped := HintBarCommands.JOY_GLYPH_SPRITES_BY_LABEL.has(label)
			var text_only := label in HintBarCommands.JOY_GLYPH_TEXT_ONLY_LABELS
			assert_true(mapped or text_only,
					"label '%s' (%s / button %d) has no sprite and is not on the text-only list" % [
						label, HintBarCommands.JoySkin.keys()[skin], button])


func test_every_mapped_sprite_exists_at_10x10() -> void:
	for label: String in HintBarCommands.JOY_GLYPH_SPRITES_BY_LABEL:
		var sprite_name := String(HintBarCommands.JOY_GLYPH_SPRITES_BY_LABEL[label])
		var path := HintBarCommands.JOY_GLYPH_SPRITE_DIRECTORY + sprite_name + ".png"
		assert_true(ResourceLoader.exists(path),
				"'%s' maps to missing sprite %s — rerun tools/godot/generate_controller_glyphs.gd" % [label, path])
		var texture: Texture2D = load(path)
		assert_eq(texture.get_width(), 10, "%s width" % sprite_name)
		assert_eq(texture.get_height(), 10, "%s height" % sprite_name)


func test_texture_lookup_falls_back_to_null_for_text_labels() -> void:
	assert_not_null(HintBarCommands.joy_glyph_texture("A"))
	assert_not_null(HintBarCommands.joy_glyph_texture("Cross"))
	assert_null(HintBarCommands.joy_glyph_texture("Options"),
			"PS Options is words on the pad — deliberately text")
	assert_null(HintBarCommands.joy_glyph_texture("Esc"),
			"keyboard labels never get chips")


func test_text_only_list_never_overlaps_the_sprite_map() -> void:
	for label: String in HintBarCommands.JOY_GLYPH_TEXT_ONLY_LABELS:
		assert_false(HintBarCommands.JOY_GLYPH_SPRITES_BY_LABEL.has(label),
				"'%s' is on both lists — pick one" % label)
