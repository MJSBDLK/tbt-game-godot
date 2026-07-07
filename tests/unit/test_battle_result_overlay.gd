## Banner-first battle result flow — the overlay half. UIManager plays the bare
## VICTORY/DEFEAT banner and only then calls show_result; the overlay's own job
## is the stats panel sliding down into place (not a whole-screen fade). Pins
## the slide contract: content starts displaced above rest, settles back at
## rest, and hiding resets visibility.
extends GutTest


func _overlay() -> BattleResultOverlay:
	var overlay := BattleResultOverlay.new()
	add_child_autofree(overlay)
	return overlay


func test_show_result_populates_and_starts_the_slide_displaced() -> void:
	var overlay := _overlay()
	overlay.show_result(true, 7, 1, 3, 4, 5)
	assert_true(overlay.visible, "overlay is shown")
	assert_eq(overlay._header_label.text, "VICTORY!", "header reflects the outcome")
	assert_string_contains(overlay._stats_label.text, "Turns: 7", "stats are populated")
	assert_almost_eq(overlay._content.offset_top,
			overlay._content_rest_top - BattleResultOverlay.SLIDE_IN_DISTANCE, 0.001,
			"content starts its slide from above the rest position")


func test_content_settles_at_rest_after_the_slide() -> void:
	var overlay := _overlay()
	overlay.show_result(false, 3, 2, 1, 4, 5)
	await wait_seconds(BattleResultOverlay.SLIDE_IN_DURATION + 0.2)
	assert_almost_eq(overlay._content.offset_top, overlay._content_rest_top, 0.001,
			"content lands exactly at its rest offset")
	assert_almost_eq(overlay._content.modulate.a, 1.0, 0.001, "content fully faded in")


func test_hide_result_hides() -> void:
	var overlay := _overlay()
	overlay.show_result(true, 1, 0, 5, 4, 5)
	overlay.hide_result()
	assert_false(overlay.visible, "hide_result hides the overlay")
