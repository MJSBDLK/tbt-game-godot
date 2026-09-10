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
var _saved_kind: InputSource.Kind = InputSource.Kind.POINTER


func before_each() -> void:
	_saved_click_attack = Settings.click_to_attack_enabled
	_saved_kind = InputSource.last_kind
	_panel = OptionsMenuPanel.new()
	add_child_autofree(_panel)


func after_each() -> void:
	Settings.set_click_to_attack_enabled(_saved_click_attack)
	InputSource.last_kind = _saved_kind


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
			"move_confirm", "move_commit", "battle_animations", "seeded_reload",
			"control_hints", "tooltip_hold"] as Array[String])
	assert_eq(_ids(OptionsMenuPanel.Tab.VIDEO), ["zoom_mode", "portrait_effects",
			"ui_motion", "type_icons", "max_fps"] as Array[String])
	assert_eq(_ids(OptionsMenuPanel.Tab.AUDIO), ["master_volume", "sfx_volume",
			"music_volume"] as Array[String])
	var all_ids: Array[String] = []
	for tab: int in OptionsMenuPanel.TAB_ORDER:
		for id: String in _ids(tab as OptionsMenuPanel.Tab):
			assert_false(all_ids.has(id), "%s appears on two tabs" % id)
			all_ids.append(id)
	assert_eq(all_ids.size(), 16, "sixteen persisted settings, each on one tab")


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
	# put under the pointer. Audio has 3 rows, Gameplay 8.
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
