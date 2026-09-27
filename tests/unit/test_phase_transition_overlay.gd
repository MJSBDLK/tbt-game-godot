## The phase banner's star layers must step evenly and keep their speed on any
## display. These tests drive _process at simulated refresh rates and read back
## where the layers land.
extends GutTest

## The round numbers, plus the odd ones real displays run at (a GNOME laptop
## panel offers 89.95, 119.96, 143.96, 164.97; XWayland reports 240 as 239.94).
const REFRESH_RATES: Array[float] = [59.94, 60.0, 75.0, 89.95, 90.0, 100.0, 119.88, 119.96, 120.0,
		143.96, 144.0, 164.97, 165.0, 239.94, 240.0, 360.0]

var overlay: PhaseTransitionOverlay


func before_each() -> void:
	overlay = PhaseTransitionOverlay.new()
	add_child_autofree(overlay)


## Per layer: the pixels it moved on each of `count` refreshes. Frames arrive
## at `actual_rate` when given, while the overlay is told `refresh_rate`.
func _measure(refresh_rate: float, hold_blend: float, jitter: float = 0.0, count: int = 48,
		actual_rate: float = 0.0) -> Array[Array]:
	overlay._start_scroll(refresh_rate)
	overlay._hold_blend = hold_blend
	overlay._is_animating = true
	var random := RandomNumberGenerator.new()
	random.seed = 7
	var frame_seconds: float = 1.0 / (actual_rate if actual_rate > 0.0 else refresh_rate)
	var steps: Array[Array] = [[], [], []]
	var last: Array[int] = [0, 0, 0]
	for refresh: int in range(count):
		overlay._process(frame_seconds * (1.0 + random.randf_range(-jitter, jitter)))
		for layer: int in range(3):
			var position: int = -int(overlay._star_pairs[layer][0].position.x)
			steps[layer].append(posmod(position - last[layer], PhaseTransitionOverlay.TEXTURE_WIDTH))
			last[layer] = position
	return steps


## Shortest repeat of `steps`, up to 16 refreshes; 0 when it never repeats.
func _period(steps: Array) -> int:
	for period: int in range(1, 17):
		var repeats: bool = true
		for index: int in range(steps.size() - period):
			if steps[index] != steps[index + period]:
				repeats = false
				break
		if repeats:
			return period
	return 0


func test_multiples_of_60_keep_the_designed_speeds() -> void:
	for refresh_rate: float in [60.0, 120.0, 240.0]:
		for speed_factor: float in [1.0, PhaseTransitionOverlay.HOLD_SPEED_FACTOR]:
			var steps: Array[float] = PhaseTransitionOverlay.even_layer_steps(
					PhaseTransitionOverlay.STAR_PIXELS_PER_FRAME, speed_factor, refresh_rate)
			for layer: int in range(steps.size()):
				assert_almost_eq(steps[layer] * refresh_rate / 60.0,
						PhaseTransitionOverlay.STAR_PIXELS_PER_FRAME[layer] * speed_factor, 0.000001,
						"%s Hz × %s, layer %d scrolls at its 60 fps design" % [refresh_rate, speed_factor, layer])


func test_every_refresh_rate_scrolls_evenly() -> void:
	for refresh_rate: float in REFRESH_RATES:
		var repeat_limit: int = maxi(1, floori(refresh_rate / 60.0 + 0.05))
		for hold_blend: float in [0.0, 1.0]:
			var measured: Array[Array] = _measure(refresh_rate, hold_blend)
			for layer: int in range(3):
				var steps: Array = measured[layer].slice(2)
				var period: int = _period(steps)
				var context: String = "%s Hz %s, layer %d: %s" % [
						refresh_rate, "hold" if hold_blend == 1.0 else "full", layer, str(steps.slice(0, 12))]
				assert_gt(period, 0, "steps repeat — " + context)
				# One pixel every k refreshes is even however long k is.
				var one_pixel_every_k: bool = steps.max() == 1 and steps.slice(0, period).count(1) == 1
				assert_true(period <= repeat_limit or one_pixel_every_k,
						"uneven steps repeat within a 60 fps frame — " + context)


func test_layers_stay_in_order_and_near_their_design() -> void:
	for refresh_rate: float in REFRESH_RATES:
		for speed_factor: float in [1.0, PhaseTransitionOverlay.HOLD_SPEED_FACTOR]:
			var steps: Array[float] = PhaseTransitionOverlay.even_layer_steps(
					PhaseTransitionOverlay.STAR_PIXELS_PER_FRAME, speed_factor, refresh_rate)
			for layer: int in range(steps.size()):
				var design: float = PhaseTransitionOverlay.STAR_PIXELS_PER_FRAME[layer] * speed_factor * 60.0 / refresh_rate
				var context: String = "%s Hz × %s: %s" % [refresh_rate, speed_factor, str(steps)]
				assert_between(steps[layer] / design, 2.0 / 3.0, 1.5, "layer %d within 1.5× of design — %s" % [layer, context])
				if layer > 0:
					assert_lt(steps[layer], steps[layer - 1], "parallax keeps its order — " + context)


func test_the_layers_are_fitted_together() -> void:
	assert_eq(PhaseTransitionOverlay.even_layer_steps(
			PhaseTransitionOverlay.STAR_PIXELS_PER_FRAME, PhaseTransitionOverlay.HOLD_SPEED_FACTOR, 75.0),
			[3.0, 2.0, 1.0] as Array[float], "75 Hz hold keeps the 3:2:1 parallax")
	assert_eq(PhaseTransitionOverlay.even_layer_steps(
			PhaseTransitionOverlay.STAR_PIXELS_PER_FRAME, 1.0, 90.0),
			[4.0, 3.0, 1.0] as Array[float], "Steam Deck OLED at full speed")


func test_a_wobbly_delta_steps_like_a_steady_one() -> void:
	for refresh_rate: float in [60.0, 144.0]:
		for hold_blend: float in [0.0, 1.0]:
			var steady: Array[Array] = _measure(refresh_rate, hold_blend)
			var wobbly: Array[Array] = _measure(refresh_rate, hold_blend, 0.02)
			assert_eq(wobbly, steady, "±2%% frame time at %s Hz changes no step" % refresh_rate)


func test_a_reported_rate_off_by_a_hair_never_skips_a_step() -> void:
	# Displays misreport slightly: rounded to whole hertz, or synthesized by a
	# compositor. A skipped or doubled step anywhere in ~8 s breaks the repeat.
	for rates: Array in [[143.0, 143.96], [239.94, 240.0], [60.0, 59.94], [90.0, 89.95]]:
		for hold_blend: float in [0.0, 1.0]:
			var measured: Array[Array] = _measure(rates[0], hold_blend, 0.0, 1200, rates[1])
			for layer: int in range(3):
				assert_gt(_period(measured[layer].slice(2)), 0,
						"told %s Hz, shown at %s Hz, %s, layer %d keeps its pattern" % [
						rates[0], rates[1], "hold" if hold_blend == 1.0 else "full", layer])


func test_a_low_frame_rate_keeps_the_speed() -> void:
	# [refresh rate the steps are fitted to, seconds per rendered frame]: every
	# refresh, the game falling behind to every other refresh, a 30 fps cap, and
	# a 144 Hz screen the game only fills at 48 fps.
	for timing: Array in [[60.0, 1.0 / 60.0], [60.0, 2.0 / 60.0], [30.0, 1.0 / 30.0], [144.0, 3.0 / 144.0]]:
		overlay._start_scroll(timing[0])
		overlay._hold_blend = 0.0
		overlay._is_animating = true
		for frame: int in range(roundi(1.0 / timing[1])):
			overlay._process(timing[1])
		for layer: int in range(3):
			assert_eq(-overlay._star_pairs[layer][0].position.x,
					float(overlay._full_speed_steps[layer] * timing[0]),
					"%s Hz fit, a frame every %.1f ms, layer %d covers a second's distance" % [
					timing[0], timing[1] * 1000.0, layer])


func test_a_lower_fps_cap_sets_the_refresh_rate() -> void:
	var saved_cap: int = Engine.max_fps
	Engine.max_fps = 30
	assert_eq(PhaseTransitionOverlay.effective_refresh_rate(), 30.0, "frames reach the screen at the cap")
	Engine.max_fps = 0
	assert_gt(PhaseTransitionOverlay.effective_refresh_rate(), 0.0, "uncapped falls back to a real rate")
	Engine.max_fps = saved_cap
