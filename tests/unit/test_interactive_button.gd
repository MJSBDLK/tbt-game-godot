## InteractiveButton — the border vocabulary's state math and contracts
## (ui-style-guide.md §14). The animation numbers here are LOCKED design
## decisions, not implementation details: if one of these fails, either the
## spec changed on purpose (update style guide + mockup + here together) or
## the vocabulary regressed.
extends GutTest


func after_each() -> void:
	Settings.ui_motion_enabled = true


# =============================================================================
# Backlight: 2/15 s, exactly 4 discrete shades, both directions
# =============================================================================

func test_backlight_starts_at_from_and_ends_at_target() -> void:
	assert_eq(InteractiveButton.backlight_level_at(0.0, 0.0, 1.0), 0.0)
	assert_eq(InteractiveButton.backlight_level_at(
			InteractiveButton.BACKLIGHT_DURATION_SECONDS, 0.0, 1.0), 1.0)


func test_backlight_fade_is_exactly_four_discrete_shades() -> void:
	var seen: Dictionary = {}
	var samples: int = 200
	for i: int in samples:
		var elapsed: float = InteractiveButton.BACKLIGHT_DURATION_SECONDS * float(i) / samples
		seen[InteractiveButton.backlight_level_at(elapsed, 0.0, 1.0)] = true
	assert_eq(seen.keys().size(), InteractiveButton.BACKLIGHT_STEPS,
			"a stepped palette ramp, not a glide: %s" % [seen.keys()])


func test_backlight_fades_down_as_well_as_up() -> void:
	var halfway: float = InteractiveButton.backlight_level_at(
			InteractiveButton.BACKLIGHT_DURATION_SECONDS * 0.6, 1.0, 0.0)
	assert_between(halfway, 0.01, 0.99, "un-focusing steps back down, not snaps")


# =============================================================================
# Brackets: exactly two positions, 1.25 Hz
# =============================================================================

func test_brackets_have_exactly_two_positions_per_cycle() -> void:
	assert_false(InteractiveButton.brackets_out_at(0.0), "cycle starts parked (in)")
	assert_false(InteractiveButton.brackets_out_at(0.39))
	assert_true(InteractiveButton.brackets_out_at(0.4), "snaps out at half cycle")
	assert_true(InteractiveButton.brackets_out_at(0.79))
	assert_false(InteractiveButton.brackets_out_at(0.8), "0.8s cycle = 1.25 Hz")


# =============================================================================
# Call-to-action rings: spawn 6px out, land ON the border, integer steps
# =============================================================================

func test_cta_ring_spawns_out_and_lands_on_the_border() -> void:
	assert_eq(InteractiveButton.cta_ring_inset_at(0.0),
			InteractiveButton.CTA_SPAWN_INSET_PIXELS)
	assert_eq(InteractiveButton.cta_ring_inset_at(0.999), 0, "lands on the border")


func test_cta_ring_converges_in_whole_pixel_steps() -> void:
	var previous: int = InteractiveButton.cta_ring_inset_at(0.0)
	for i: int in range(1, 100):
		var inset: int = InteractiveButton.cta_ring_inset_at(float(i) / 100.0)
		assert_true(inset <= previous, "motion is toward the button, never away")
		assert_true(previous - inset <= 1, "one integer pixel at a time")
		previous = inset


# =============================================================================
# Disabled: pressing is a question — denied fires, pressed does not
# =============================================================================

func test_pressing_a_disabled_button_emits_denied() -> void:
	var button := InteractiveButton.new()
	button.disabled = true
	add_child_autofree(button)
	watch_signals(button)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	button._gui_input(press)
	assert_signal_emitted(button, "denied")
	assert_signal_not_emitted(button, "pressed")


func test_pressing_an_enabled_button_does_not_emit_denied() -> void:
	var button := InteractiveButton.new()
	add_child_autofree(button)
	watch_signals(button)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	button._gui_input(press)
	assert_signal_not_emitted(button, "denied")


# =============================================================================
# Scarcity: at most ONE call to action on screen (last wins, loudly)
# =============================================================================

func test_second_call_to_action_steals_from_the_first() -> void:
	var first := InteractiveButton.new()
	var second := InteractiveButton.new()
	add_child_autofree(first)
	add_child_autofree(second)
	first.call_to_action = true
	second.call_to_action = true
	assert_false(first.call_to_action, "scarcity rule: the newer CTA wins")
	assert_true(second.call_to_action)


func test_cta_ownership_clears_when_the_owner_leaves_the_tree() -> void:
	var button := InteractiveButton.new()
	add_child(button)
	button.call_to_action = true
	button.queue_free()
	await wait_frames(2)
	assert_null(InteractiveButton._call_to_action_owner,
			"a freed CTA must not haunt the registry")


# =============================================================================
# Text treatment: optical centering + glyph glow following the tier
# =============================================================================

func test_text_sits_one_pixel_below_true_center() -> void:
	var button := InteractiveButton.new()
	add_child_autofree(button)
	var normal := button.get_theme_stylebox("normal")
	assert_eq(normal.content_margin_top - normal.content_margin_bottom, 2.0,
			"optical centering: menu strings have few descenders, so true center reads high (RQD)")


func test_press_shifts_text_down_exactly_one_pixel() -> void:
	var button := InteractiveButton.new()
	add_child_autofree(button)
	var normal := button.get_theme_stylebox("normal")
	var pressed := button.get_theme_stylebox("pressed")
	assert_eq(pressed.content_margin_top - normal.content_margin_top, 1.0,
			"press response moves text with the chrome — one integer pixel")


func test_text_glow_dims_when_disabled() -> void:
	var button := InteractiveButton.new()
	add_child_autofree(button)
	var shader := button.material as ShaderMaterial
	assert_not_null(shader, "the glyph glow is the menus' visual identity")
	assert_eq(shader.get_shader_parameter("glow_color"), GameColors.TEXT_PRIMARY_GLOW)
	button.disabled = true
	button._process(0.0)  # the disabled watcher lives in _process
	assert_ne(shader.get_shader_parameter("glow_color"), GameColors.TEXT_PRIMARY_GLOW,
			"disabled text must not carry the healthy azure glow")


# =============================================================================
# Reduce motion: colors stay, motion stops — instantly
# =============================================================================

func test_reduce_motion_snaps_the_backlight() -> void:
	Settings.ui_motion_enabled = false
	var button := InteractiveButton.new()
	add_child_autofree(button)
	button._start_backlight_fade(1.0)
	assert_eq(button._current_backlight_level(), 1.0,
			"no fade when motion is off — the state change still lands")


func test_reduce_motion_stops_animation_requests() -> void:
	Settings.ui_motion_enabled = false
	var button := InteractiveButton.new()
	button.selected = true
	add_child_autofree(button)
	assert_false(button._wants_motion(), "parked brackets: no per-frame redraws")


# =============================================================================
# The cursor is a fact about the CURSOR, not an affordance of the item
# =============================================================================

func test_selected_brackets_survive_disabled() -> void:
	# RQD bug 2026-07-30: _draw_chrome used to gate brackets on `not disabled`,
	# so the menu cursor VANISHED whenever it landed on a depleted/locked chip —
	# in-game it read as "my arrow keys stopped working." _brackets_visible()
	# is now the COMPLETE visibility decision; the draw site must stay bare
	# (no extra disabled clause — see the comment there).
	var button := InteractiveButton.new()
	add_child_autofree(button)
	button.disabled = true
	button.selected = true
	assert_true(button._brackets_visible(),
			"the cursor renders on disabled items — brackets are 'you are here', not 'pressable'")
