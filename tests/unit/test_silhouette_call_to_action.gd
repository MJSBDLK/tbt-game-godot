## SilhouetteCallToAction — the §14 CTA rings cut to a unit's outline, played
## by the End Turn warning. Pins the ring geometry (Chebyshev rings = the
## button ring's rect inset, for any shape), the facing flip, one effect per
## sprite, and the burst timing (passes, rest, repeat) on Lawrence's knobs.
extends GutTest


var _seconds_before: float = 0.5


func before_each() -> void:
	_seconds_before = ArtVariables.UNIT_CALL_TO_ACTION_SECONDS


func after_each() -> void:
	DebugConfig.set_art_knob("UNIT_CALL_TO_ACTION_SECONDS", _seconds_before)


func _art(size: Vector2i, opaque: Rect2i) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill_rect(opaque, Color.WHITE)
	return image


func _sprite(art: Image) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(art)
	add_child_autofree(sprite)
	return sprite


func test_a_square_grows_square_rings() -> void:
	# A 3×3 block: ring d is the (3 + 2d)-wide square around it, 8 + 8d pixels.
	var rings := SilhouetteCallToAction.rings_for(_art(Vector2i(5, 5), Rect2i(1, 1, 3, 3)), 3)
	assert_eq(rings.size(), 4, "the edge plus three steps out")
	assert_eq(rings[0].size(), 8, "the edge: the block's rim, not its centre")
	assert_false(rings[0].has(Vector2(2, 2)))
	assert_eq(rings[1].size(), 16)
	assert_eq(rings[2].size(), 24)
	assert_eq(rings[3].size(), 32)
	assert_true(rings[3].has(Vector2(-2, -2)), "rings reach past the frame's own edge")
	assert_true(rings[1].has(Vector2(0, 0)), "diagonal neighbours are one step (Chebyshev)")


func test_rings_never_overlap_and_stay_off_the_art() -> void:
	# An L — a concave notch the rings have to fill.
	var art := _art(Vector2i(6, 6), Rect2i(1, 1, 1, 4))
	art.fill_rect(Rect2i(1, 4, 4, 1), Color.WHITE)
	var rings := SilhouetteCallToAction.rings_for(art, 2)
	var seen: Dictionary = {}
	for inset: int in rings.size():
		for pixel: Vector2 in rings[inset]:
			assert_false(seen.has(pixel), "%s is in one ring only" % pixel)
			seen[pixel] = true
			var inside: bool = pixel.x >= 0 and pixel.y >= 0 and pixel.x < 6 and pixel.y < 6
			var opaque: bool = inside and art.get_pixelv(Vector2i(pixel)).a > 0.5
			assert_eq(opaque, inset == 0, "only the edge ring sits on the art (%s)" % pixel)


func test_play_on_hangs_one_pass_under_the_sprite() -> void:
	var sprite := _sprite(_art(Vector2i(4, 4), Rect2i(1, 1, 2, 2)))
	var effect := SilhouetteCallToAction.play_on(sprite)
	assert_not_null(effect)
	assert_eq(effect.get_parent(), sprite, "rides the sprite: its transform, above its pixels")
	assert_eq(effect._origin, sprite.get_rect().position, "the frame's corner, centred or not")
	SilhouetteCallToAction.play_on(sprite)
	var passes: int = 0
	for child: Node in sprite.get_children():
		if child is SilhouetteCallToAction and not child.is_queued_for_deletion():
			passes += 1
	assert_eq(passes, 1, "a second warning restarts the pass, never stacks one")


func test_a_flipped_sprite_flips_its_rings() -> void:
	# One opaque pixel at the left edge; facing flipped, it's at the right.
	var art := _art(Vector2i(4, 1), Rect2i(0, 0, 1, 1))
	var sprite := _sprite(art)
	sprite.flip_h = true
	var effect := SilhouetteCallToAction.play_on(sprite)
	assert_eq(effect._rings[0], PackedVector2Array([Vector2(3, 0)]))


func test_no_art_to_read_means_no_pass() -> void:
	assert_null(SilhouetteCallToAction.play_on(null))
	var bare := Sprite2D.new()
	add_child_autofree(bare)
	assert_null(SilhouetteCallToAction.play_on(bare), "no texture, nothing to trace")


func _phases(elapsed: float, stagger: float = 0.5, rest: float = 1.0) -> Array:
	return Array(SilhouetteCallToAction.pass_phases_at(elapsed, 0.5, 3, stagger, rest))


func _assert_phases(actual: Array, expected: Array, note: String) -> void:
	assert_eq(actual.size(), expected.size(), "%s: %s rings in flight" % [note, expected.size()])
	for index: int in mini(actual.size(), expected.size()):
		assert_almost_eq(float(actual[index]), float(expected[index]), 0.001, note)


func test_each_pass_starts_halfway_through_the_last() -> void:
	# Each pass starts halfway through the one before (STAGGER 0.5).
	# Three 0.5 s passes, 0.25 s apart: the set runs
	# 1.0 s, then the 1.0 s rest, so a cycle is 2.0 s.
	_assert_phases(_phases(0.0), [0.0], "the first pass starts at once")
	_assert_phases(_phases(0.3), [0.6, 0.1], "the second is closing in behind it")
	_assert_phases(_phases(0.6), [0.7, 0.2], "first landed; second and third in flight")
	_assert_phases(_phases(0.9), [0.8], "the third lands alone")
	_assert_phases(_phases(1.2), [], "resting")
	_assert_phases(_phases(2.0), [0.0], "the next set")


func test_a_tighter_stagger_puts_three_rings_in_flight() -> void:
	_assert_phases(_phases(0.4, 0.33), [0.8, 0.47, 0.14], "all three at once")


func test_a_full_stagger_runs_them_back_to_back() -> void:
	_assert_phases(_phases(0.6, 1.0), [0.2], "one at a time — the second pass only")
	_assert_phases(_phases(1.6, 1.0), [], "the rest counts from the last pass's end")


func test_dials_that_leave_no_pass_draw_nothing() -> void:
	assert_true(SilhouetteCallToAction.pass_phases_at(0.1, 0.5, 0, 0.5, 1.0).is_empty(), "zero passes")
	assert_true(SilhouetteCallToAction.pass_phases_at(0.1, 0.0, 3, 0.5, 1.0).is_empty(), "zero length")


func test_it_keeps_going_until_its_owner_frees_it() -> void:
	DebugConfig.set_art_knob("UNIT_CALL_TO_ACTION_SECONDS", 0.02)
	var sprite := _sprite(_art(Vector2i(4, 4), Rect2i(1, 1, 2, 2)))
	var effect := SilhouetteCallToAction.play_on(sprite)
	# Wall-clock ticks drive it (the button vocabulary's clock) — wait on that
	# clock, not a timer: headless frame deltas drift from it.
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 200:
		await get_tree().process_frame
	assert_true(is_instance_valid(effect), "many cycles later it is still running")
