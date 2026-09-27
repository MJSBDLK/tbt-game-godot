## The ` console is Lawrence's live path into ArtVariables: a line typed here
## is a knob turned, and `dump` gives the turn back as lines for his file.
## The interpreter is pinned as strings; the toggle as the key it answers.
extends GutTest


var _console: DevConsole = null


func before_each() -> void:
	_console = DevConsole.new()
	add_child_autofree(_console)


func after_each() -> void:
	DebugConfig.reset_art_knobs()


func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	_console._input(event)


## A viewport of our own to push events into and read the handled flag from.
## The root's flag reads true for everything under GUT (its own GUI), so a
## "did this fall through" assert only means something on a SubViewport.
func _stage() -> SubViewport:
	var stage := SubViewport.new()
	stage.size = Vector2i(1280, 720)
	add_child_autofree(stage)
	return stage


func _click_far_away() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(5000, 5000)  # off every Control
	click.global_position = click.position
	return click


func test_hidden_until_the_backtick_and_esc_closes_it() -> void:
	assert_false(_console.visible, "a console over the title screen is a bug")
	_press(KEY_QUOTELEFT)
	assert_true(_console.visible)
	assert_true(_console._prompt.has_focus(), "opens ready to type")
	_press(KEY_ESCAPE)
	assert_false(_console.visible)
	_press(KEY_QUOTELEFT)
	_press(KEY_QUOTELEFT)
	assert_false(_console.visible, "the backtick toggles")


func test_is_open_is_the_gate_and_the_root_covers_the_canvas() -> void:
	# InputRouter, InputManager's hover poll and the camera's key pan all read
	# is_open(); a click anywhere outside the panel must land on the root.
	assert_false(DevConsole.is_open())
	_press(KEY_QUOTELEFT)
	assert_true(DevConsole.is_open())
	await get_tree().process_frame
	assert_eq(_console.size, get_viewport().get_visible_rect().size,
			"the root spans the whole canvas, not just the panel")
	assert_eq(_console.mouse_filter, Control.MOUSE_FILTER_STOP, "and stops the mouse")
	assert_almost_eq(_console.get_node("Panel").size.y, DevConsole.HEIGHT, 0.001,
			"the visible panel is the top strip")
	_press(KEY_ESCAPE)
	assert_false(DevConsole.is_open())


func test_is_open_forgets_a_freed_console() -> void:
	_press(KEY_QUOTELEFT)
	assert_true(DevConsole.is_open())
	_console.free()
	_console = null
	assert_false(DevConsole.is_open(), "no stale gate after the console is gone")


func test_joypad_events_die_at_the_console_while_open() -> void:
	var stage := _stage()
	var console := DevConsole.mount(stage)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	stage.push_input(button)
	assert_false(stage.is_input_handled(), "closed: a pad press goes on to whatever is under")
	console.open()
	stage.push_input(button.duplicate())
	assert_true(stage.is_input_handled(), "open: consumed at the console")


func test_the_router_makes_the_world_deaf_while_the_console_is_open() -> void:
	# The real InputRouter on a stand-in GameRoot: events pushed into the root
	# viewport are forwarded to the HUD, then either fall through to the world
	# or, with the console up, stop at the router — motion included.
	var stage := _stage()  # stands in for the root viewport
	var hud_viewport := SubViewport.new()
	hud_viewport.name = "HUDViewport"
	hud_viewport.size = Vector2i(640, 360)
	stage.add_child(hud_viewport)
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	var hud_display := TextureRect.new()
	hud_display.name = "HUDDisplay"
	hud_display.size = Vector2(1280, 720)
	hud_layer.add_child(hud_display)
	stage.add_child(hud_layer)
	var taps := TapFeedbackLayer.new()
	taps.name = "TapFeedbackLayer"
	stage.add_child(taps)
	var router := InputRouter.new()
	router.name = "InputRouter"
	stage.add_child(router)
	var console := DevConsole.mount(hud_viewport)

	stage.push_input(_click_far_away())
	assert_false(stage.is_input_handled(), "closed: the click falls through to the world")

	console.open()
	stage.push_input(_click_far_away())
	assert_true(stage.is_input_handled(), "open: the router eats it before the world")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(5000, 5000)
	motion.global_position = motion.position
	stage.push_input(motion)
	assert_true(stage.is_input_handled(), "open: motion too, so nothing under the console hovers")


func test_cheats_off_keeps_the_console_shut() -> void:
	var cheats_before := DebugConfig.cheats_enabled
	DebugConfig.cheats_enabled = false
	_press(KEY_QUOTELEFT)
	assert_false(_console.visible)
	DebugConfig.cheats_enabled = cheats_before


func test_a_knob_line_sets_it_and_reads_it_back() -> void:
	assert_eq(_console.execute("shadow_ink_alpha 0.55"), "SHADOW_INK_ALPHA = 0.55",
			"names are case-blind; the reply is the new state")
	assert_almost_eq(ArtVariables.SHADOW_INK_ALPHA, 0.55, 0.001, "the board's knob moved")
	assert_eq(_console.execute("SHADOW_INK_ALPHA"), "SHADOW_INK_ALPHA = 0.55", "a bare name reads")


func test_values_are_read_by_the_knobs_type() -> void:
	_console.execute("shadow_blob off")
	assert_false(ArtVariables.SHADOW_BLOB, "on/off/yes/no/1/0 all read as bool")
	_console.execute("shadow_nudge_y -3")
	assert_almost_eq(ArtVariables.SHADOW_NUDGE_Y, -3.0, 0.001, "an int reads as the float")
	_console.execute("map_edge_fade_color #ff0000")
	assert_eq(ArtVariables.MAP_EDGE_FADE_COLOR, Color.RED, "html color")
	_console.execute("map_edge_fade_color 0 0 1 0.5")
	assert_eq(ArtVariables.MAP_EDGE_FADE_COLOR, Color(0, 0, 1, 0.5), "four floats")
	_console.execute("map_edge_fade_color Color(0, 1, 0, 1)")
	assert_eq(ArtVariables.MAP_EDGE_FADE_COLOR, Color.GREEN, "the file's own syntax")


func test_bad_input_explains_and_changes_nothing() -> void:
	var ink_before: float = ArtVariables.SHADOW_INK_ALPHA
	var reply := _console.execute("shadow_ink_alpha dark")
	assert_string_contains(reply, "can't read 'dark' as a float")
	assert_almost_eq(ArtVariables.SHADOW_INK_ALPHA, ink_before, 0.001)
	assert_string_contains(_console.execute("shadow_blob maybe"), "as a bool")
	assert_string_contains(_console.execute("frobnicate 1"), "unknown: frobnicate")
	assert_eq(_console.execute("   "), "", "an empty line is nothing")


func test_list_names_every_knob_and_flags_the_changed_ones() -> void:
	_console.execute("shadow_squash 0.5")
	var listing := _console.execute("list")
	for knob in DebugConfig.art_knob_names():
		assert_string_contains(listing, knob + "\t", "one tab-separated row per knob")
	assert_string_contains(listing, "SHADOW_SQUASH\t0.5\tfile: 0.25",
			"a changed knob shows what the file still says")
	assert_string_contains(listing, "SHADOW_LENGTH\t1.0\t\n", "an untouched knob has an empty third cell")


func test_dump_is_the_files_syntax_for_what_changed() -> void:
	assert_eq(_console.execute("dump"), "nothing changed from the file")
	_console.execute("shadow_ink_alpha 0.55")
	_console.execute("shadow_blob off")
	var dump := _console.execute("dump")
	assert_string_contains(dump, "static var SHADOW_INK_ALPHA: float = 0.55")
	assert_string_contains(dump, "static var SHADOW_BLOB: bool = false")
	assert_false(dump.contains("SHADOW_LENGTH"), "untouched knobs stay out of the paste")


func test_reset_goes_back_to_the_file() -> void:
	var default_alpha: float = DebugConfig.art_knob_default("SHADOW_INK_ALPHA")
	_console.execute("shadow_ink_alpha 0.55")
	_console.execute("shadow_length 2")
	assert_eq(_console.execute("reset shadow_ink_alpha"),
			"SHADOW_INK_ALPHA = %s" % var_to_str(default_alpha), "one knob")
	assert_almost_eq(ArtVariables.SHADOW_LENGTH, 2.0, 0.001, "the other is still turned")
	assert_eq(_console.execute("reset"), "every knob back to the file")
	assert_almost_eq(ArtVariables.SHADOW_LENGTH, DebugConfig.art_knob_default("SHADOW_LENGTH"), 0.001)


func test_tab_completes_knobs_and_commands() -> void:
	assert_eq(_console.complete("shadow_in"), "SHADOW_INK_ALPHA ", "one match completes, with the space")
	assert_eq(_console.complete("shadow_b"), "SHADOW_BLOB", "two matches: the shared letters")
	assert_eq(_console.complete("du"), "dump ")
	assert_eq(_console.complete("zzz"), "zzz", "no match leaves it")
	assert_eq(_console.complete("shadow_blob 1"), "shadow_blob 1", "only the first word completes")


func test_the_help_names_the_commands() -> void:
	var help := _console.execute("help")
	for command in ["list", "reset", "dump", "clear"]:
		assert_string_contains(help, command)
