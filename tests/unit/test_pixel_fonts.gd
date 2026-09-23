## The two pixel fonts carry glyphs of our own, drawn into the .ttf files by
## tools/fonts/patch_pixel_glyphs.py. These pin them so a re-download of the
## originals fails loudly instead of quietly bringing the old B and 8 back.
extends GutTest


func _width(font: FontFile, text: String, size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func test_the_5px_b_and_8_are_the_font_width() -> void:
	var font: FontFile = UIManager.font_5px
	assert_not_null(font)
	assert_eq(_width(font, "B", 5), _width(font, "D", 5),
			"B was a 4-wide straggler in a 3-wide font, with an outline that rendered as noise")
	assert_eq(_width(font, "8", 5), _width(font, "0", 5), "same story for 8")


func test_the_8px_font_has_the_preview_arrow() -> void:
	assert_true(UIManager.font_8px.has_char(0x2192),
			"the sheet's `15→17` StatUp preview and its tooltips need → in UndeadPixelLight8")
