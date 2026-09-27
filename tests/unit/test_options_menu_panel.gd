## OptionsMenuPanel — three tabs over one row registry (RQD 2026-09-09:
## "Options menu has gotten too big for the screen"). Pins: which tab every
## persisted setting lives on, that the tallest tab fits the 360 px HUD
## canvas (THE regression — sixteen rows in one column ran ~420 px), that
## switching tabs never resizes the panel, the shoulder / Q-E actions and
## their bindings, that a pill press writes its setting, and the cursor-model
## landing.
extends GutTest


const CANVAS_HEIGHT: float = 360.0
const CANVAS_WIDTH: float = 640.0
## The fullscreen border overlay is 10 px per side — the panel must not sit
## under it either.
const BORDER_INSET: float = 10.0

var _panel: OptionsMenuPanel = null
var _saved_click_attack: bool = false
var _saved_pacing: int = 0
var _saved_warning: bool = true
var _saved_move_confirm: int = 0
var _saved_kind: InputSource.Kind = InputSource.Kind.POINTER
var _saved_vsync: bool = true
var _saved_max_fps: int = 0


func before_each() -> void:
	_saved_click_attack = Settings.click_to_attack_enabled
	_saved_pacing = Settings.battle_pacing
	_saved_warning = Settings.end_turn_warning
	_saved_move_confirm = Settings.move_confirm_mode
	_saved_kind = InputSource.last_kind
	_saved_vsync = Settings.vsync_enabled
	_saved_max_fps = Settings.max_fps
	_panel = OptionsMenuPanel.new()
	add_child_autofree(_panel)


func after_each() -> void:
	Settings.set_click_to_attack_enabled(_saved_click_attack)
	Settings.set_battle_pacing(_saved_pacing)
	Settings.set_end_turn_warning(_saved_warning)
	Settings.set_move_confirm_mode(_saved_move_confirm)
	InputSource.last_kind = _saved_kind
	Settings.set_vsync_enabled(_saved_vsync)
	Settings.set_max_fps(_saved_max_fps)


func _action(name: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func _ids(tab: OptionsMenuPanel.Tab) -> Array[String]:
	return _panel.tab_row_ids(tab)


# =============================================================================
# THE REGISTRY
# =============================================================================

func test_every_persisted_setting_lives_on_exactly_one_tab() -> void:
	# The membership decision, pinned. Moving a row is editing this list.
	assert_eq(_ids(OptionsMenuPanel.Tab.GAMEPLAY), ["click_attack", "auto_end_turn",
			"end_turn_warning", "move_confirm", "battle_animations", "battle_pacing",
			"seeded_reload", "control_hints", "tooltip_hold", "cursor_speed",
			"preset"] as Array[String])
	assert_eq(_ids(OptionsMenuPanel.Tab.VIDEO), ["zoom_mode", "portrait_effects",
			"ui_motion", "type_icons", "vsync", "max_fps"] as Array[String])
	assert_eq(_ids(OptionsMenuPanel.Tab.AUDIO), ["master_volume", "sfx_volume",
			"music_volume"] as Array[String])
	var all_ids: Array[String] = []
	for tab: int in OptionsMenuPanel.TAB_ORDER:
		for id: String in _ids(tab as OptionsMenuPanel.Tab):
			assert_false(all_ids.has(id), "%s appears on two tabs" % id)
			all_ids.append(id)
	assert_eq(all_ids.size(), 20, "nineteen persisted settings + the preset row, each on one tab")


# =============================================================================
# GEOMETRY — the bug this fixes
# =============================================================================

func test_the_tallest_tab_fits_the_reference_canvas() -> void:
	_panel.show_panel()
	var minimum: Vector2 = _panel.get_combined_minimum_size()
	assert_lte(minimum.y, CANVAS_HEIGHT - 2.0 * BORDER_INSET,
			"the panel column fits inside the 360 px canvas and its border")
	assert_lte(minimum.x, CANVAS_WIDTH - 2.0 * BORDER_INSET)
	assert_gt(minimum.y, 100.0, "…and it is a real column, not an empty shell")


func test_switching_tabs_never_resizes_the_panel() -> void:
	# The rows area is pinned to the largest tab, so the strip and Close stay
	# put under the pointer. Audio has 3 rows, Gameplay 11.
	_panel.show_panel()
	var gameplay: Vector2 = _panel.get_combined_minimum_size()
	_panel.select_tab(OptionsMenuPanel.Tab.AUDIO)
	assert_eq(_panel.get_combined_minimum_size(), gameplay, "Audio is as tall as Gameplay")
	_panel.select_tab(OptionsMenuPanel.Tab.VIDEO)
	assert_eq(_panel.get_combined_minimum_size(), gameplay)


# =============================================================================
# TABS
# =============================================================================

func test_only_the_current_tabs_rows_show_and_its_header_is_selected() -> void:
	_panel.show_panel()
	assert_eq(_panel.current_tab, OptionsMenuPanel.Tab.GAMEPLAY, "opens on Gameplay")
	assert_true((_panel._tab_boxes[OptionsMenuPanel.Tab.GAMEPLAY] as Control).visible)
	assert_false((_panel._tab_boxes[OptionsMenuPanel.Tab.VIDEO] as Control).visible)
	assert_true((_panel._tab_buttons[OptionsMenuPanel.Tab.GAMEPLAY] as InteractiveButton).selected,
			"the current header wears the §14 brackets")
	assert_false((_panel._tab_buttons[OptionsMenuPanel.Tab.VIDEO] as InteractiveButton).selected)
	_panel.select_tab(OptionsMenuPanel.Tab.VIDEO)
	assert_false((_panel._tab_boxes[OptionsMenuPanel.Tab.GAMEPLAY] as Control).visible)
	assert_true((_panel._tab_boxes[OptionsMenuPanel.Tab.VIDEO] as Control).visible)
	assert_true((_panel._tab_buttons[OptionsMenuPanel.Tab.VIDEO] as InteractiveButton).selected)
	assert_false((_panel._tab_buttons[OptionsMenuPanel.Tab.GAMEPLAY] as InteractiveButton).selected,
			"selection is unique — the old header lets go")


func test_shoulder_actions_step_through_the_tabs_and_wrap() -> void:
	_panel.show_panel()
	_panel._unhandled_input(_action(OptionsMenuPanel.TAB_NEXT_ACTION))
	assert_eq(_panel.current_tab, OptionsMenuPanel.Tab.VIDEO)
	_panel._unhandled_input(_action(OptionsMenuPanel.TAB_NEXT_ACTION))
	assert_eq(_panel.current_tab, OptionsMenuPanel.Tab.AUDIO)
	_panel._unhandled_input(_action(OptionsMenuPanel.TAB_NEXT_ACTION))
	assert_eq(_panel.current_tab, OptionsMenuPanel.Tab.GAMEPLAY, "wraps forward")
	_panel._unhandled_input(_action(OptionsMenuPanel.TAB_PREV_ACTION))
	assert_eq(_panel.current_tab, OptionsMenuPanel.Tab.AUDIO, "wraps backward")


func test_the_tab_actions_are_bound_for_keyboard_and_pad() -> void:
	# Q / E and LB / RB — the strip's glyphs read these bindings live.
	for action: StringName in [OptionsMenuPanel.TAB_PREV_ACTION, OptionsMenuPanel.TAB_NEXT_ACTION]:
		assert_true(InputMap.has_action(action), "%s exists in the InputMap" % action)
		var has_key: bool = false
		var pad_button: int = -1
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				has_key = true
			if event is InputEventJoypadButton:
				pad_button = (event as InputEventJoypadButton).button_index
		assert_true(has_key, "%s has a keyboard binding" % action)
		assert_eq(pad_button, JOY_BUTTON_LEFT_SHOULDER if action == OptionsMenuPanel.TAB_PREV_ACTION
				else JOY_BUTTON_RIGHT_SHOULDER, "%s rides the shoulder button" % action)


func test_the_open_tab_is_remembered_across_opens() -> void:
	_panel.show_panel()
	_panel.select_tab(OptionsMenuPanel.Tab.AUDIO)
	_panel.hide_panel()
	_panel.show_panel()
	assert_eq(_panel.current_tab, OptionsMenuPanel.Tab.AUDIO, "reopens where the player left off")
	assert_true((_panel._tab_boxes[OptionsMenuPanel.Tab.AUDIO] as Control).visible)


# =============================================================================
# ROWS
# =============================================================================

func test_a_pill_press_writes_the_setting_and_lights_the_new_pill() -> void:
	Settings.set_click_to_attack_enabled(false)
	_panel.show_panel()
	var pills: Dictionary = _panel._choice_buttons["click_attack"]
	var on_pill: Button = pills[true]
	var off_pill: Button = pills[false]
	assert_eq(off_pill.get_theme_stylebox("normal"), _panel._toggle_style_active,
			"the current value's pill is lit at build")
	on_pill.pressed.emit()
	assert_true(Settings.click_to_attack_enabled, "the press persisted through the Settings setter")
	assert_eq(on_pill.get_theme_stylebox("normal"), _panel._toggle_style_active, "On lights up")
	assert_eq(off_pill.get_theme_stylebox("normal"), _panel._toggle_style_inactive, "Off dims")


func _lit(row_id: String, value: Variant) -> bool:
	var pill: Button = _panel._choice_buttons[row_id][value]
	return pill.get_theme_stylebox("normal") == _panel._toggle_style_active


func test_a_preset_press_relights_every_row_it_sets() -> void:
	Settings.apply_preset("newcomer")
	_panel.show_panel()
	assert_true(_lit("preset", "newcomer"), "the defaults read as Newcomer")
	(_panel._choice_buttons["preset"]["veteran"] as Button).pressed.emit()
	assert_eq(Settings.battle_pacing, Settings.BattlePacing.FAST, "the press applied the preset")
	assert_true(_lit("preset", "veteran"))
	assert_false(_lit("preset", "newcomer"))
	assert_true(_lit("battle_pacing", Settings.BattlePacing.FAST), "the rows above follow")
	assert_true(_lit("end_turn_warning", false))
	assert_true(_lit("click_attack", true))
	assert_true(_lit("move_confirm", Settings.MoveConfirmMode.MARKER))


func test_a_hand_change_unlights_the_preset() -> void:
	Settings.apply_preset("veteran")
	_panel.show_panel()
	(_panel._choice_buttons["battle_pacing"][Settings.BattlePacing.RELAXED] as Button).pressed.emit()
	assert_false(_lit("preset", "veteran"), "custom now — neither preset is lit")
	assert_false(_lit("preset", "newcomer"))


func _slider(row_id: String) -> HSlider:
	for tab: int in OptionsMenuPanel.TAB_ORDER:
		for row: Node in (_panel._tab_boxes[tab] as Control).get_children():
			if String(row.get_meta("row_id", "")) != row_id:
				continue
			for child: Node in row.get_children():
				if child is HSlider:
					return child as HSlider
	return null


func test_slider_rows_wear_the_pill_palette_not_godots_default() -> void:
	# RQD 2026-09-10: "sliders in the options menu need to be styled to match
	# existing visual design." The stock HSlider was the last default-theme
	# widget in the menu. Track = unlit pill, fill = lit pill, knob = a small
	# pixel plate — nothing Godot-shaped.
	_panel.show_panel()
	for row_id: String in ["tooltip_hold", "cursor_speed", "max_fps", "master_volume"]:
		var slider: HSlider = _slider(row_id)
		assert_not_null(slider, row_id)
		assert_eq(slider.get_theme_stylebox("slider"), _panel._slider_track_style,
				"%s: the track is the unlit pill" % row_id)
		assert_eq(slider.get_theme_stylebox("grabber_area"), _panel._slider_fill_style,
				"%s: the fill is the lit pill" % row_id)
		assert_eq(slider.get_theme_icon("grabber"), _panel._slider_knob, "%s: house knob" % row_id)
		assert_eq(slider.get_theme_icon("grabber_highlight"), _panel._slider_knob_highlight)
	assert_eq(_panel._slider_knob.get_size(), Vector2(OptionsMenuPanel.SLIDER_KNOB_SIZE),
			"a %s px knob on a 14 px row, not the 16 px default disc" % OptionsMenuPanel.SLIDER_KNOB_SIZE)
	assert_eq(_panel._slider_fill_style.border_color, GameColors.TEXT_SECONDARY,
			"the fill's rim is the lit pill's gold — 'this is the current value'")
	assert_eq(_panel._slider_track_style.border_color, GameColors.ACTION_BUTTON_BORDER,
			"the track's rim is the unlit pill's gray")
	assert_eq(_panel._slider_track_style.get_minimum_size().y, float(OptionsMenuPanel.SLIDER_TRACK_HEIGHT))


# =============================================================================
# FPS CAP — stops up to the display's rate; Higher? past it
# =============================================================================
# Headless reports no refresh rate, so the display here is the 60 Hz fallback.

func _open_on_video(vsync: bool, max_fps: int) -> void:
	Settings.set_vsync_enabled(vsync)
	Settings.set_max_fps(max_fps)
	_panel.current_tab = OptionsMenuPanel.Tab.VIDEO
	_panel.show_panel()


func _fps_readout() -> String:
	return _panel._fps_readout.text


func test_the_slider_tops_out_at_the_display() -> void:
	_open_on_video(true, 0)
	var slider: HSlider = _panel._fps_slider
	assert_eq(slider.value, slider.max_value, "0 sits on the top stop")
	assert_eq(_fps_readout(), str(Settings.display_refresh_rate()),
			"the top stop reads the display's rate — the number most players never knew")


func test_the_display_stop_stores_zero_and_the_others_their_rate() -> void:
	_open_on_video(true, 0)
	var slider: HSlider = _panel._fps_slider
	slider.value = slider.max_value - 1
	assert_eq(Settings.max_fps, _panel._fps_stops[int(slider.max_value) - 1])
	assert_eq(_fps_readout(), str(Settings.max_fps))
	slider.value = slider.max_value
	assert_eq(Settings.max_fps, 0, "the display's stop follows the display to another monitor")


func test_higher_opens_the_stops_to_1000() -> void:
	_open_on_video(true, 0)
	assert_eq(_panel._higher_pill.text, OptionsMenuPanel.HIGHER_LABEL)
	_panel._higher_pill.pressed.emit()
	assert_eq(_panel._higher_pill.text, OptionsMenuPanel.LOWER_LABEL,
			"open, the pill says what pressing it again does")
	var slider: HSlider = _panel._fps_slider
	assert_eq(slider.value, float(_panel._fps_stops.find(Settings.display_refresh_rate())),
			"opening never moves the knob")
	slider.value = slider.max_value
	assert_eq(Settings.max_fps, Settings.FPS_CAP_MAX)
	assert_eq(_fps_readout(), "1000")


func test_closing_higher_drops_a_cap_past_the_display_back_to_it() -> void:
	_open_on_video(true, 0)
	_panel._higher_pill.pressed.emit()
	_panel._fps_slider.value = _panel._fps_slider.max_value
	_panel._higher_pill.pressed.emit()
	assert_eq(_panel._higher_pill.text, OptionsMenuPanel.HIGHER_LABEL)
	assert_eq(Settings.max_fps, 0)
	assert_eq(_panel._fps_slider.value, _panel._fps_slider.max_value, "the knob sits on the display's stop")
	assert_eq(_fps_readout(), str(Settings.display_refresh_rate()))


func test_a_cap_past_the_display_reopens_on_the_range_that_shows_it() -> void:
	_open_on_video(true, 240)
	assert_eq(_fps_readout(), "240")
	assert_eq(_panel._fps_stops.back(), Settings.FPS_CAP_MAX, "Higher? opens already open")
	(_panel._choice_buttons["vsync"][false] as Button).pressed.emit()
	assert_eq(Settings.max_fps, 240, "VSync off leaves the cap alone")


func test_the_pill_keeps_its_width_when_it_flips() -> void:
	# A narrower Lower? would slide the slider and readout under the pointer.
	_open_on_video(true, 0)
	var width: float = _panel._higher_pill.get_combined_minimum_size().x
	_panel._higher_pill.pressed.emit()
	assert_eq(_panel._higher_pill.get_combined_minimum_size().x, width)


func test_the_cursor_presses_past_the_top_stop_onto_higher() -> void:
	_open_on_video(true, 0)
	var slider: HSlider = _panel._fps_slider
	slider.grab_focus()
	slider.gui_input.emit(_action(&"ui_right"))
	assert_eq(_panel.get_viewport().gui_get_focus_owner(), _panel._higher_pill,
			"the slider eats left/right; the top stop hands the cursor on")
	_assert_explains("max_fps", "the pill explains its row")


# =============================================================================
# DESCRIPTION PANE — every input can read what a row does
# =============================================================================

func _row(row_id: String) -> HBoxContainer:
	for tab: int in OptionsMenuPanel.TAB_ORDER:
		for row: Node in (_panel._tab_boxes[tab] as Control).get_children():
			if String(row.get_meta("row_id", "")) == row_id:
				return row as HBoxContainer
	return null


func _spec(row_id: String) -> Dictionary:
	for spec: Dictionary in _panel._row_specs():
		if spec.id == row_id:
			return spec
	return {}


func _assert_explains(row_id: String, note: String) -> void:
	assert_eq(_panel._description_heading.text, String(_spec(row_id).label), note)
	assert_eq(_panel._description_body.text, String(_spec(row_id).description), note)


func test_every_row_has_something_to_say() -> void:
	for spec: Dictionary in _panel._row_specs():
		assert_false(String(spec.get("description", "")).is_empty(), "%s explains itself" % spec.id)


func test_each_mode_a_description_walks_through_gets_its_own_line() -> void:
	# "On: this thing" / "Off: other thing" — a line per choice, never a run-on.
	for spec: Dictionary in _panel._row_specs():
		if int(spec.kind) != OptionsMenuPanel.RowKind.CHOICE:
			continue
		var description: String = spec.description
		for choice: Array in spec.choices:
			var at: int = description.find("%s:" % choice[1])
			if at > 0:
				assert_eq(description[at - 1], "\n", "%s: '%s:' starts a line" % [spec.id, choice[1]])


func test_no_row_carries_a_native_tooltip() -> void:
	# The pane is the explanation; a native tooltip on top would say it twice.
	_panel.show_panel()
	var stack: Array[Node] = [_panel]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Control:
			assert_eq((node as Control).tooltip_text, "", "%s has no native tooltip" % node)
		stack.append_array(node.get_children())


func test_a_pointer_open_starts_on_the_placeholder() -> void:
	InputSource.last_kind = InputSource.Kind.POINTER
	_panel.show_panel()
	assert_eq(_panel._description_heading.text, "", "no row yet")
	assert_eq(_panel._description_body.text, OptionsMenuPanel.DESCRIPTION_FLAVOR, "…just the flavor line")


func test_hovering_a_rows_name_explains_it() -> void:
	_panel.show_panel()
	(_row("seeded_reload").get_child(0) as Label).mouse_entered.emit()
	_assert_explains("seeded_reload", "mouse: hover the name")


func test_tapping_a_rows_name_explains_it() -> void:
	_panel.show_panel()
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	(_row("battle_pacing").get_child(0) as Label).gui_input.emit(tap)
	_assert_explains("battle_pacing", "touch: tap the name (no hover, no cursor)")


func test_the_cursor_explains_the_row_it_lands_on() -> void:
	InputSource.last_kind = InputSource.Kind.CURSOR
	_panel.show_panel()
	await get_tree().process_frame
	_assert_explains("click_attack", "the open lands on the first row, and says what it is")
	(_panel._choice_buttons["move_confirm"][Settings.move_confirm_mode] as Button).grab_focus()
	_assert_explains("move_confirm", "the cursor moved, the pane followed")


func test_hovering_or_pressing_a_pill_explains_its_row() -> void:
	_panel.show_panel()
	var pills: Dictionary = _panel._choice_buttons["end_turn_warning"]
	(pills[true] as Button).mouse_entered.emit()
	_assert_explains("end_turn_warning", "hover a pill")
	(_panel._choice_buttons["preset"]["newcomer"] as Button).pressed.emit()
	_assert_explains("preset", "press a pill")


func test_a_slider_explains_its_row() -> void:
	_panel.show_panel()
	_slider("cursor_speed").mouse_entered.emit()
	_assert_explains("cursor_speed", "sliders too")


func test_switching_tabs_clears_a_row_the_new_tab_does_not_have() -> void:
	InputSource.last_kind = InputSource.Kind.POINTER
	_panel.show_panel()
	(_row("seeded_reload").get_child(0) as Label).mouse_entered.emit()
	_panel.select_tab(OptionsMenuPanel.Tab.AUDIO)
	assert_eq(_panel._description_heading.text, "", "Seeded Reload isn't on Audio")


func test_escape_closes_and_emits() -> void:
	_panel.show_panel()
	watch_signals(_panel)
	_panel._unhandled_input(_action(&"ui_cancel"))
	assert_false(_panel.visible)
	assert_signal_emitted(_panel, "closed", "UIManager returns to the system menu off this")


# =============================================================================
# CURSOR MODEL
# =============================================================================

func test_a_cursor_driven_open_lands_on_the_first_rows_active_pill() -> void:
	InputSource.last_kind = InputSource.Kind.CURSOR
	Settings.set_click_to_attack_enabled(false)
	_panel.show_panel()
	await get_tree().process_frame
	var focus_owner: Control = _panel.get_viewport().gui_get_focus_owner()
	assert_eq(focus_owner, _panel._choice_buttons["click_attack"][false],
			"the cursor lands on the current value of the first Gameplay row")


func test_a_pointer_open_stays_quiet_until_a_navigation_press() -> void:
	InputSource.last_kind = InputSource.Kind.POINTER
	_panel.show_panel()
	await get_tree().process_frame
	assert_null(_panel.get_viewport().gui_get_focus_owner(), "no phantom cursor under the pointer")
	_panel._unhandled_input(_action(&"ui_down"))
	await get_tree().process_frame
	assert_not_null(_panel.get_viewport().gui_get_focus_owner(), "the first nav press summons it")


func test_switching_tabs_reseats_a_cursor_that_was_in_the_rows() -> void:
	InputSource.last_kind = InputSource.Kind.CURSOR
	_panel.show_panel()
	await get_tree().process_frame
	_panel.step_tab(1)
	await get_tree().process_frame
	var focus_owner: Control = _panel.get_viewport().gui_get_focus_owner()
	assert_not_null(focus_owner, "focus survives the switch")
	assert_true((_panel._tab_boxes[OptionsMenuPanel.Tab.VIDEO] as Control).is_ancestor_of(focus_owner),
			"…and lands in the tab that is now showing, never on a hidden row")
