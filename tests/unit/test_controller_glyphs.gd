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
	JOY_BUTTON_PADDLE1, JOY_BUTTON_PADDLE2,
	JOY_BUTTON_PADDLE3, JOY_BUTTON_PADDLE4,
]


func test_deck_and_elite_grip_labels_cover_all_four_paddles() -> void:
	# The Deck names its grips L4/R4 (upper) and L5/R5 (lower); Elite pads say
	# P1..P4. Each set must be four DISTINCT sprite-backed labels — a collision
	# means the SDL position mapping got edited half-way.
	for skin: HintBarCommands.JoySkin in [HintBarCommands.JoySkin.STEAM_DECK, HintBarCommands.JoySkin.XBOX]:
		var labels: Array[String] = []
		for button: JoyButton in [JOY_BUTTON_PADDLE1, JOY_BUTTON_PADDLE2,
				JOY_BUTTON_PADDLE3, JOY_BUTTON_PADDLE4]:
			var label := HintBarCommands.joy_button_label(button, skin)
			assert_false(label.is_empty(), "paddle %d unlabeled on %s" % [
					button, HintBarCommands.JoySkin.keys()[skin]])
			assert_false(label in labels, "duplicate paddle label '%s'" % label)
			assert_not_null(HintBarCommands.joy_glyph_texture(label),
					"paddle label '%s' has no sprite" % label)
			labels.append(label)


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


func test_every_mapped_sprite_exists_at_bar_height() -> void:
	# Button-format sprites are exactly 12 tall (the bar row is 14) and at
	# least 12 wide — width varies by silhouette (bumpers 15, START/SELECT
	# pills wider still; the chip-expands-to-fit rule).
	for label: String in HintBarCommands.JOY_GLYPH_SPRITES_BY_LABEL:
		var sprite_name := String(HintBarCommands.JOY_GLYPH_SPRITES_BY_LABEL[label])
		var path := HintBarCommands.JOY_GLYPH_SPRITE_DIRECTORY + sprite_name + ".png"
		assert_true(ResourceLoader.exists(path),
				"'%s' maps to missing sprite %s — rerun tools/godot/generate_controller_glyphs.gd" % [label, path])
		var texture: Texture2D = load(path)
		assert_eq(texture.get_height(), 12, "%s height" % sprite_name)
		assert_true(texture.get_width() >= 12, "%s width < 12" % sprite_name)


func test_start_and_select_speak_retro_universal_on_every_wordy_skin() -> void:
	# Xbox/Steam Menu+View and PS Options+Share all land on the same
	# START/SELECT pills — the millennial-era words, not the hardware icons.
	for label: String in ["Menu", "Options"]:
		assert_eq(String(HintBarCommands.JOY_GLYPH_SPRITES_BY_LABEL[label]), "label_start")
	for label: String in ["View", "Share"]:
		assert_eq(String(HintBarCommands.JOY_GLYPH_SPRITES_BY_LABEL[label]), "label_select")


func test_texture_lookup_falls_back_to_null_for_text_labels() -> void:
	assert_not_null(HintBarCommands.joy_glyph_texture("A"))
	assert_not_null(HintBarCommands.joy_glyph_texture("Cross"))
	assert_not_null(HintBarCommands.joy_glyph_texture("Options"),
			"Options rides the START pill now")
	assert_null(HintBarCommands.joy_glyph_texture("Esc"),
			"keyboard labels never get chips")


func test_text_only_list_never_overlaps_the_sprite_map() -> void:
	var overlap: Array[String] = []
	for label: String in HintBarCommands.JOY_GLYPH_TEXT_ONLY_LABELS:
		if HintBarCommands.JOY_GLYPH_SPRITES_BY_LABEL.has(label):
			overlap.append(label)
	assert_eq(overlap, [] as Array[String], "labels on both lists — pick one")
