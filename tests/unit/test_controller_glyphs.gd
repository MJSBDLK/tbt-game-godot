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


## Style is a live audition knob — pin it so these tests pass under either
## shipped default.
func before_each() -> void:
	HintBarCommands.joy_glyph_style = HintBarCommands.JoyGlyphStyle.HARDWARE


func after_each() -> void:
	HintBarCommands.joy_glyph_style = HintBarCommands.JoyGlyphStyle.HARDWARE


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
	# Button-format sprites are exactly 12 tall (the bar row is 14); width
	# varies by silhouette — circles 11 (odd, so a 5-wide letter centers
	# exactly — RQD 2026-09-02), bumpers 15, START/SELECT pills wider still
	# (the chip-expands-to-fit rule).
	for label: String in HintBarCommands.JOY_GLYPH_SPRITES_BY_LABEL:
		var sprite_name := String(HintBarCommands.JOY_GLYPH_SPRITES_BY_LABEL[label])
		var path := HintBarCommands.JOY_GLYPH_SPRITE_DIRECTORY + sprite_name + ".png"
		assert_true(ResourceLoader.exists(path),
				"'%s' maps to missing sprite %s — rerun tools/godot/generate_controller_glyphs.gd" % [label, path])
		var texture: Texture2D = load(path)
		assert_eq(texture.get_height(), 12, "%s height" % sprite_name)
		assert_true(texture.get_width() >= 11, "%s width < 11" % sprite_name)


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


func test_color_identities_cover_faces_and_nothing_else() -> void:
	# Xbox + Steam Deck letters and PS shapes carry identities; Switch and
	# every non-face button stay neutral.
	for label: String in ["A", "B", "X", "Y"]:
		assert_false(HintBarCommands.joy_glyph_identity(label, HintBarCommands.JoySkin.XBOX).is_empty(),
				"%s should be a colored skittle on Xbox" % label)
		assert_eq(HintBarCommands.joy_glyph_identity(label, HintBarCommands.JoySkin.XBOX),
				HintBarCommands.joy_glyph_identity(label, HintBarCommands.JoySkin.STEAM_DECK),
				"Deck shares the Xbox identity (monochrome-hardware veto pending)")
		assert_true(HintBarCommands.joy_glyph_identity(label, HintBarCommands.JoySkin.NINTENDO).is_empty(),
				"Switch buttons are black — no identities")
	for label: String in ["Cross", "Circle", "Square", "Triangle"]:
		assert_false(HintBarCommands.joy_glyph_identity(label, HintBarCommands.JoySkin.PLAYSTATION).is_empty())
	for label: String in ["LB", "R3", "Menu", "D-Up"]:
		for skin: HintBarCommands.JoySkin in HintBarCommands.JoySkin.values():
			assert_true(HintBarCommands.joy_glyph_identity(label, skin).is_empty(),
					"'%s' is not a face button" % label)


func test_xbox_colors_the_skittle_and_ps_colors_the_mark() -> void:
	var xbox := HintBarCommands.joy_glyph_identity("A", HintBarCommands.JoySkin.XBOX)
	assert_true(xbox.has("form_glow"), "Xbox: the colored FORM wears the glow")
	assert_false(xbox.has("char_glow"), "Xbox: the dark letter is glowless")
	var playstation := HintBarCommands.joy_glyph_identity("Cross", HintBarCommands.JoySkin.PLAYSTATION)
	assert_true(playstation.has("char_glow"), "PS: the colored MARK wears the glow")
	assert_false(playstation.has("form_glow"), "PS: the dark plastic is glowless")


func test_ink_style_moves_the_color_into_the_glyph() -> void:
	# The alternative styling (RQD 2026-09-04): identity in the character with
	# its glow, on the translucent Eggshell plate.
	var ink := HintBarCommands.joy_glyph_identity("A", HintBarCommands.JoySkin.XBOX,
			HintBarCommands.JoyGlyphStyle.INK)
	assert_eq(ink.char, GameColorPalette.get_color("Green", 6), "INK: the letter is green")
	assert_true(ink.has("char_glow"), "INK: the colored letter wears the glow")
	assert_false(ink.has("form_glow"), "INK: the plate is glowless")
	assert_eq(ink.form, HintBarCommands.joy_glyph_ink_plate())
	assert_almost_eq(ink.form.a, HintBarCommands.INK_PLATE_ALPHA, 0.001,
			"plate is semitransparent")
	# PS in INK keeps its mark colors — only the plastic swaps for the plate.
	var cross := HintBarCommands.joy_glyph_identity("Cross", HintBarCommands.JoySkin.PLAYSTATION,
			HintBarCommands.JoyGlyphStyle.INK)
	assert_eq(cross.form, HintBarCommands.joy_glyph_ink_plate())
	assert_eq(cross.char, GameColorPalette.get_color("Azure", 6))
	# Switch stays identity-less in both styles.
	assert_true(HintBarCommands.joy_glyph_identity("A", HintBarCommands.JoySkin.NINTENDO,
			HintBarCommands.JoyGlyphStyle.INK).is_empty())


func test_style_knob_switches_the_live_recipe() -> void:
	HintBarCommands.joy_glyph_style = HintBarCommands.JoyGlyphStyle.INK
	var live := HintBarCommands.joy_glyph_identity("Y", HintBarCommands.JoySkin.XBOX)
	assert_true(live.has("char_glow"), "default-arg calls follow the knob")
	HintBarCommands.joy_glyph_style = HintBarCommands.JoyGlyphStyle.HARDWARE
	assert_true(HintBarCommands.joy_glyph_identity("Y", HintBarCommands.JoySkin.XBOX).has("form_glow"))


func test_every_familied_label_has_form_line_and_char_layers() -> void:
	# Since the INK style plates EVERY button, layers exist for the whole
	# vocabulary, not just faces — form + line + char, all 1px halo-padded.
	for label: String in ["A", "B", "X", "Y", "Cross", "Circle", "Square", "Triangle",
			"LB", "R1", "L", "R3", "L4", "P2", "Menu", "View", "+", "-"]:
		var layers := HintBarCommands.joy_glyph_layer_textures(label)
		assert_false(layers.is_empty(), "'%s' needs split layers" % label)
		for key: String in ["form", "line", "char"]:
			assert_eq((layers[key] as Texture2D).get_height(), 14,
					"'%s' %s is 12 + 1px halo padding each side" % [label, key])
	assert_true(HintBarCommands.joy_glyph_layer_textures("D-Up").is_empty(),
			"the d-pad has no family — it falls back to the merged sprite")


func test_ink_recipe_plates_every_button_and_hardware_only_faces() -> void:
	# HARDWARE: neutral buttons render the merged sprite (empty recipe).
	assert_true(HintBarCommands.joy_glyph_recipe("LB", HintBarCommands.JoySkin.XBOX,
			HintBarCommands.JoyGlyphStyle.HARDWARE).is_empty())
	# INK: the same button gets the plate + mid-gray outline + text-voice char.
	var ink := HintBarCommands.joy_glyph_recipe("LB", HintBarCommands.JoySkin.XBOX,
			HintBarCommands.JoyGlyphStyle.INK)
	assert_eq(ink.form, HintBarCommands.joy_glyph_ink_plate())
	assert_eq(ink.line, GameColorPalette.get_color(
			HintBarCommands.INK_OUTLINE_RAMP, HintBarCommands.INK_OUTLINE_INDEX))
	assert_eq(ink.char, GameColors.TEXT_PRIMARY, "identity-less glyphs speak the text voice")
	# INK with an identity: the glyph keeps its color, the plate/outline match.
	var letter := HintBarCommands.joy_glyph_recipe("A", HintBarCommands.JoySkin.XBOX,
			HintBarCommands.JoyGlyphStyle.INK)
	assert_eq(letter.char, GameColorPalette.get_color("Green", 6))
	assert_true(letter.has("line"), "identity buttons wear the outline too")


func test_text_only_list_never_overlaps_the_sprite_map() -> void:
	var overlap: Array[String] = []
	for label: String in HintBarCommands.JOY_GLYPH_TEXT_ONLY_LABELS:
		if HintBarCommands.JOY_GLYPH_SPRITES_BY_LABEL.has(label):
			overlap.append(label)
	assert_eq(overlap, [] as Array[String], "labels on both lists — pick one")
