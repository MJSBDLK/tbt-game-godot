## HintBar — the battle HUD's hint / command bar (scaffold, 2026-08-20). Pins
## the boundary behavior: visible only in a live battle with hints on; the
## rendering follows InputSource.last_device (pairs vs touch buttons); touch
## buttons request the SAME action the key would; state/phase changes
## re-sample; the corner inset is real geometry.
##
## Drives the live autoloads (GameStateManager / InputSource / Settings /
## DebugConfig) and restores every one of them in after_each. Settings is
## poked directly, never through its setter — the setter would write the
## player's real settings file.
extends GutTest


func before_each() -> void:
	InputSource.last_kind = InputSource.Kind.CURSOR
	InputSource.last_device = InputSource.Device.KEYBOARD
	DebugConfig.debug_force_touch_hints = false
	HintBarCommands.joy_skin_override = HintBarCommands.JoySkin.XBOX
	HintBarCommands.joy_glyph_style = HintBarCommands.JoyGlyphStyle.HARDWARE
	Settings.show_control_hints = true
	Settings.move_confirm_mode = Settings.MoveConfirmMode.AUTO
	GameStateManager.change_state(Enums.InputState.DEFAULT)


func after_each() -> void:
	GameStateManager.change_state(Enums.InputState.DEFAULT)
	Settings.show_control_hints = true
	Settings.move_confirm_mode = Settings.MoveConfirmMode.AUTO
	HintBarCommands.joy_skin_override = -1
	HintBarCommands.joy_glyph_style = HintBarCommands.JoyGlyphStyle.HARDWARE
	DebugConfig.debug_force_touch_hints = false
	InputSource.last_device = InputSource.Device.MOUSE
	InputSource.last_kind = InputSource.Kind.POINTER


func _make_bar(in_battle: bool = true) -> HintBar:
	var bar := HintBar.new()
	add_child_autofree(bar)
	bar.battle_active = in_battle
	bar.refresh()
	return bar


func _items(bar: HintBar) -> Array[Node]:
	return bar._items_box.get_children()


# --- visibility ---------------------------------------------------------------

func test_hidden_outside_a_battle() -> void:
	assert_false(_make_bar(false).visible)


func test_visible_in_battle_with_hints_on() -> void:
	assert_true(_make_bar().visible)


func test_setting_off_hides_it() -> void:
	var bar := _make_bar()
	Settings.show_control_hints = false
	bar.refresh()
	assert_false(bar.visible)


func test_a_resumed_save_arms_it_via_the_phase_signal() -> void:
	# TurnManager.resume_battle skips battle_started on purpose and emits only
	# player_phase_started. Found on F5 2026-08-20: bar invisible after Continue.
	var bar := _make_bar(false)
	assert_false(bar.visible)
	bar._on_player_phase_started(3)
	assert_true(bar.visible, "any phase signal means a battle is live")
	assert_eq(_items(bar).size(), 5)


func test_scene_swap_to_a_battle_scene_does_not_disarm() -> void:
	# SceneRouter emits scene_changed AFTER add_child, and BattleScene._ready
	# starts/resumes the battle synchronously inside add_child — the arming
	# signal has already fired. Disarming here hid the bar on every battle
	# entry (F5 2026-08-20).
	var bar := _make_bar(false)
	bar._on_player_phase_started(1)          # fired during add_child
	var battle_scene := BattleScene.new()
	autofree(battle_scene)
	bar._on_scene_changed(battle_scene)      # fired right after
	assert_true(bar.visible, "a battle scene must not disarm the bar")


func test_scene_swap_to_a_non_battle_scene_disarms() -> void:
	var bar := _make_bar()
	var menu := Control.new()
	autofree(menu)
	bar._on_scene_changed(menu)
	assert_false(bar.visible, "main menu / intermission: nothing to hint")


func test_battle_end_hides_it() -> void:
	var bar := _make_bar()
	bar._on_battle_ended(true)
	assert_false(bar.visible)


func test_silent_states_hide_it() -> void:
	var bar := _make_bar()
	GameStateManager.change_state(Enums.InputState.PAUSED)
	assert_false(bar.visible, "the pause menu carries its own affordances")
	GameStateManager.change_state(Enums.InputState.DEFAULT)
	assert_true(bar.visible)


# --- rendering follows the sampled device --------------------------------------

func test_keyboard_renders_glyph_verb_pairs() -> void:
	var bar := _make_bar()
	assert_eq(bar.last_model, HintBarCommands.Model.KEYBOARD_MOUSE)
	var items := _items(bar)
	assert_eq(items.size(), 5)
	assert_eq((items[0].get_node("Glyph") as Label).text, "[LMB]")
	assert_eq((items[0].get_node("Verb") as Label).text, "Select")
	assert_eq((items[4].get_node("Glyph") as Label).text, "[Esc]")
	assert_eq(bar._step_label.text, "Select a unit")


func test_joypad_renders_controller_glyphs() -> void:
	InputSource.last_device = InputSource.Device.JOYPAD
	var bar := _make_bar()
	assert_eq(bar.last_model, HintBarCommands.Model.CONTROLLER)
	# A has an Xbox color identity, so the Glyph renders the SPLIT layers:
	# the shared disc tinted green (the skittle) under the dark letter
	# (test_controller_glyphs.gd pins recipes and layer files).
	var glyph := _items(bar)[0].get_node("Glyph")
	assert_false(glyph is Label, "sprite-backed glyphs never render as text")
	var form := glyph.get_node("Form") as TextureRect
	assert_eq(form.texture.resource_path,
			HintBarCommands.JOY_GLYPH_SPRITE_DIRECTORY + "face_form.png")
	assert_eq(form.modulate, GameColorPalette.get_color("Green", 6), "A is the green skittle")
	assert_not_null(form.material, "the colored skittle wears the glow")
	var character := glyph.get_node("Char") as TextureRect
	assert_eq(character.modulate, GameColorPalette.get_color("Gray", 1), "dark letter on the skittle")
	# LB has no identity — under HARDWARE it stays the single ink-tinted
	# outline sprite.
	var neutral := _items(bar)[3].get_node("Glyph") as TextureRect
	assert_eq(neutral.texture.resource_path,
			HintBarCommands.JOY_GLYPH_SPRITE_DIRECTORY + "label_lb.png")


func test_ink_style_plates_every_button_in_the_bar() -> void:
	# The pattern complaint (RQD 2026-09-04): under INK, LB must not stay a
	# white outline while its neighbors sit on plates — every button renders
	# form + gray Line + char.
	InputSource.last_device = InputSource.Device.JOYPAD
	HintBarCommands.joy_glyph_style = HintBarCommands.JoyGlyphStyle.INK
	var bar := _make_bar()
	for item: Node in _items(bar):
		var glyph := item.get_node("Glyph")
		assert_true(glyph.has_node("Line"),
				"%s: INK renders the outline layer on every button" % item.name)
	var bumper := _items(bar)[3].get_node("Glyph")
	assert_eq((bumper.get_node("Char") as TextureRect).modulate, GameColors.TEXT_PRIMARY,
			"LB's label speaks the text voice under INK")


func test_joypad_labels_without_sprites_fall_back_to_text() -> void:
	InputSource.last_device = InputSource.Device.JOYPAD
	HintBarCommands.joy_skin_override = HintBarCommands.JoySkin.PLAYSTATION
	var bar := _make_bar()
	assert_eq(bar.last_model, HintBarCommands.Model.CONTROLLER)
	# Every PS label the bar shows today is sprite-backed (Options/Share ride
	# the START/SELECT pills), so exercise the fallback contract directly: an
	# unmapped label renders as bracketed text.
	assert_null(HintBarCommands.joy_glyph_texture("NotARealLabel"))
	# Cross renders layered PS-style: dark button, the MARK carries color+glow.
	var glyph := _items(bar)[0].get_node("Glyph")
	var character := glyph.get_node("Char") as TextureRect
	assert_eq(character.modulate, GameColorPalette.get_color("Azure", 6), "Cross mark is azure")
	assert_not_null(character.material, "the colored mark wears the glow")
	assert_null((glyph.get_node("Form") as TextureRect).material,
			"PS button plastic is dark and glowless")


func test_touch_renders_buttons() -> void:
	InputSource.last_device = InputSource.Device.TOUCH
	var bar := _make_bar()
	assert_eq(bar.last_model, HintBarCommands.Model.TOUCH)
	var items := _items(bar)
	assert_eq(items.size(), 3, "End turn / Threat / Menu — Select is the map tap")
	for item: Node in items:
		assert_true(item is Button, "%s should be a Button" % item.name)
		assert_eq((item as Button).focus_mode, Control.FOCUS_NONE,
				"taps must not steal menu focus")
	assert_eq((items[0] as Button).text, "End turn")
	assert_eq(bar._step_label.text, "Tap a unit")


func test_debug_force_touch_overrides_the_device() -> void:
	DebugConfig.debug_force_touch_hints = true
	assert_eq(_make_bar().last_model, HintBarCommands.Model.TOUCH)


# --- touch buttons fire the key's action -----------------------------------------

func test_touch_button_requests_its_action() -> void:
	InputSource.last_device = InputSource.Device.TOUCH
	var bar := _make_bar()
	watch_signals(bar)
	(_items(bar)[0] as Button).pressed.emit()
	assert_signal_emitted_with_parameters(bar, "action_requested", [&"end_turn"])
	(_items(bar)[2] as Button).pressed.emit()
	assert_signal_emitted_with_parameters(bar, "action_requested", [&"ui_cancel"], 1)


# --- boundaries re-sample -------------------------------------------------------

func test_state_change_resamples_contents() -> void:
	var bar := _make_bar()
	GameStateManager.change_state(Enums.InputState.UNIT_SELECTED)
	assert_eq(bar._step_label.text, "Choose a destination")
	assert_eq(_items(bar).size(), 3)
	GameStateManager.change_state(Enums.InputState.UNIT_DETAIL)
	assert_false(bar._step_label.visible, "unit detail has no step line")
	assert_eq(_items(bar).size(), 1)
	assert_true(bar.visible, "one item is still something to say")


func test_device_is_sampled_at_the_boundary_not_live() -> void:
	var bar := _make_bar()
	InputSource.last_device = InputSource.Device.JOYPAD
	assert_eq(bar.last_model, HintBarCommands.Model.KEYBOARD_MOUSE,
			"no boundary crossed yet — the glyphs must not swap mid-state")
	GameStateManager.change_state(Enums.InputState.UNIT_SELECTED)
	assert_eq(bar.last_model, HintBarCommands.Model.CONTROLLER)


func test_enemy_phase_shows_step_only() -> void:
	var bar := _make_bar()
	bar._on_enemy_phase_started()
	assert_eq(bar._step_label.text, HintBarCommands.ENEMY_PHASE_STEP)
	assert_eq(_items(bar).size(), 0)
	assert_true(bar.visible)
	bar._on_player_phase_started(2)
	assert_eq(_items(bar).size(), 5)


# --- the planning step: NOTICE border, or the "Move here" button ------------------

func test_planning_step_wears_the_notice_border_under_marker_mode() -> void:
	var bar := _make_bar()
	GameStateManager.change_state(Enums.InputState.UNIT_SELECTED)
	assert_eq(bar.last_step_form, HintBar.StepForm.LABEL)
	assert_true(bar._step_label.visible)
	var plain: StyleBoxFlat = bar._step_panel.get_theme_stylebox("panel")
	assert_eq(plain.border_color, GameColors.STATIC_BORDER, "plain glass before the marker")

	GameStateManager.change_state(Enums.InputState.MOVEMENT_PLANNING)
	assert_eq(bar.last_step_form, HintBar.StepForm.NOTICE, "keyboard → AUTO resolves to MARKER")
	assert_true(bar._step_label.visible, "still a label — NOTICE is not a button")
	assert_false(bar._step_button.visible)
	assert_eq(bar._step_label.text, "Select the marker again to move")
	var notice: StyleBoxFlat = bar._step_panel.get_theme_stylebox("panel")
	assert_eq(notice.border_color, GameColors.NOTICE_BORDER, "violet = look here, not a button")
	assert_eq(notice.bg_color, GameColors.HUD_PANEL_BACKGROUND)

	GameStateManager.change_state(Enums.InputState.ACTION_MENU_OPEN)
	assert_eq(bar.last_step_form, HintBar.StepForm.LABEL, "notice released when the line changes")


func test_button_mode_offers_move_here_and_it_confirms_the_plan() -> void:
	Settings.move_confirm_mode = Settings.MoveConfirmMode.BUTTON
	var bar := _make_bar()
	GameStateManager.change_state(Enums.InputState.MOVEMENT_PLANNING)
	assert_eq(bar.last_step_form, HintBar.StepForm.BUTTON)
	assert_true(bar._step_button.visible)
	assert_false(bar._step_label.visible)
	assert_eq(bar._step_button.text, "Move here")
	assert_eq(bar._step_button.focus_mode, Control.FOCUS_NONE, "the bar never takes focus")
	var ring: StyleBoxFlat = bar._step_button.get_theme_stylebox("normal")
	assert_eq(ring.border_color, GameColors.TEXT_INFO, "parked-gold CTA: INFO ring, no rings")
	assert_true(bar._step_panel.get_theme_stylebox("panel") is StyleBoxEmpty, "button draws its own ring")
	watch_signals(bar)
	bar._step_button.pressed.emit()
	assert_signal_emitted(bar, "move_confirm_requested")
	# Nothing is selected in this test, so InputManager must refuse quietly.
	assert_false(InputManager.confirm_planned_movement())


func test_auto_mode_follows_the_device() -> void:
	var bar := _make_bar()
	GameStateManager.change_state(Enums.InputState.MOVEMENT_PLANNING)
	assert_eq(bar.last_step_form, HintBar.StepForm.NOTICE, "keyboard → marker")
	InputSource.last_device = InputSource.Device.TOUCH
	GameStateManager.change_state(Enums.InputState.UNIT_SELECTED)
	GameStateManager.change_state(Enums.InputState.MOVEMENT_PLANNING)
	assert_eq(bar.last_step_form, HintBar.StepForm.BUTTON, "touch → button: the thumb is already there")
	Settings.move_confirm_mode = Settings.MoveConfirmMode.MARKER
	bar.refresh()
	assert_eq(bar.last_step_form, HintBar.StepForm.NOTICE, "MARKER overrides the device")


# --- geometry --------------------------------------------------------------------

func test_fills_a_sized_parent_and_puts_the_row_inside_it_at_the_bottom() -> void:
	# The F5 2026-08-20/21 bug: set_anchors_preset() on an already-parented
	# node keeps the 0×0 rect, and the bottom-anchored row ends up at y = -26 —
	# off the top of the screen. The bar must fill its parent.
	var canvas := Control.new()
	canvas.size = Vector2(640, 360)
	add_child_autofree(canvas)
	var bar := HintBar.new()
	canvas.add_child(bar)
	bar.battle_active = true
	bar.refresh()
	assert_eq(bar.size, Vector2(640, 360), "bar fills the HUD canvas")
	var row_rect: Rect2 = bar._strip.get_rect()
	assert_eq(row_rect.position.y, 360.0 - 14.0 - 12.0, "row sits 12 px above the bottom edge")
	assert_eq(row_rect.end.y, 360.0 - 12.0)
	assert_true(Rect2(Vector2.ZERO, canvas.size).encloses(row_rect),
			"the row must be ON the canvas, not above it: %s" % row_rect)

func test_corner_inset_is_real_geometry() -> void:
	var bar := _make_bar()
	bar.placement = HintBar.Placement.CORNERS
	bar.corner_inset = 12
	assert_eq(bar._strip.offset_left, 12.0)
	assert_eq(bar._strip.offset_right, -12.0)
	assert_eq(bar._strip.offset_bottom, -12.0)
	assert_eq(bar._strip.offset_top, -float(bar.bar_height + 12))
	bar.placement = HintBar.Placement.FULL_WIDTH
	assert_eq(bar._strip.offset_left, 0.0)
	assert_eq(bar._strip.offset_bottom, 0.0)


func test_touch_row_is_button_height_plus_padding() -> void:
	InputSource.last_device = InputSource.Device.TOUCH
	var bar := _make_bar()
	bar.placement = HintBar.Placement.FULL_WIDTH
	assert_eq(bar._strip.offset_top, -float(bar.touch_button_height + 4))


func test_glass_backing_follows_placement() -> void:
	# Mockup: CORNERS = two glass boxes (step / items), strip transparent;
	# FULL_WIDTH = one glass strip edge to edge, clusters transparent.
	var bar := _make_bar()
	bar.placement = HintBar.Placement.CORNERS
	assert_true(bar._step_panel.get_theme_stylebox("panel") is StyleBoxFlat, "step cluster glass")
	assert_true(bar._items_panel.get_theme_stylebox("panel") is StyleBoxFlat, "items cluster glass")
	assert_true(bar._strip.get_theme_stylebox("panel") is StyleBoxEmpty, "strip clear")
	var glass: StyleBoxFlat = bar._items_panel.get_theme_stylebox("panel")
	assert_eq(glass.bg_color, GameColors.HUD_PANEL_BACKGROUND)
	assert_eq(glass.border_color, GameColors.STATIC_BORDER)
	assert_eq(glass.border_width_top, 1)
	bar.placement = HintBar.Placement.FULL_WIDTH
	assert_true(bar._strip.get_theme_stylebox("panel") is StyleBoxFlat, "strip glass")
	assert_true(bar._items_panel.get_theme_stylebox("panel") is StyleBoxEmpty, "items cluster clear")
