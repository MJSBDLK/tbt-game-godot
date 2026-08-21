## HintBarCommands — the hint / command bar's table + glyph resolution. Pins:
## the per-state ceiling, that every advertised action exists, that glyphs
## come from the LIVE InputMap (rebind → new glyph, unbind → item drops), the
## three renderings of the DEFAULT row the mockup locked, and the joy skins.
extends GutTest


const _UNBOUND: StringName = &"__hint_test_unbound"
const _REBIND: StringName = &"__hint_test_rebind"


func before_each() -> void:
	HintBarCommands.joy_skin_override = HintBarCommands.JoySkin.XBOX


func after_each() -> void:
	HintBarCommands.joy_skin_override = -1
	for action: StringName in [_UNBOUND, _REBIND]:
		if InputMap.has_action(action):
			InputMap.erase_action(action)


func _glyphs(state: Enums.InputState, model: HintBarCommands.Model, enemy: bool = false) -> Array:
	var out: Array = []
	for entry: Dictionary in HintBarCommands.resolve(state, model, enemy):
		out.append(entry.glyph)
	return out


func _verbs(state: Enums.InputState, model: HintBarCommands.Model) -> Array:
	var out: Array = []
	for entry: Dictionary in HintBarCommands.resolve(state, model):
		out.append(entry.verb)
	return out


# --- table shape -------------------------------------------------------------

func test_every_state_respects_the_item_ceiling() -> void:
	for state: Enums.InputState in HintBarCommands.states_with_entries():
		for model: HintBarCommands.Model in [HintBarCommands.Model.CONTROLLER,
				HintBarCommands.Model.KEYBOARD_MOUSE, HintBarCommands.Model.TOUCH]:
			assert_lte(HintBarCommands.resolve(state, model).size(),
					HintBarCommands.MAX_ITEMS_PER_STATE,
					"%s under model %d" % [Enums.InputState.keys()[state], model])


func test_every_advertised_action_exists_in_the_input_map() -> void:
	for state: Enums.InputState in HintBarCommands.states_with_entries():
		for item: Dictionary in HintBarCommands.items_for(state):
			assert_true(InputMap.has_action(item.action),
					"%s advertises unknown action %s" % [Enums.InputState.keys()[state], item.action])


func test_waypoints_are_taught_one_click_at_a_time() -> void:
	# RQD 2026-08-21: the first click plots, it does not move; the marker it
	# leaves is the explanation and the next step line says what it's for.
	var kb := HintBarCommands.Model.KEYBOARD_MOUSE
	assert_eq(_verbs(Enums.InputState.UNIT_SELECTED, kb)[0], "Plot path",
			"never promise 'Move here' for a click that only plots")
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.UNIT_SELECTED, kb), "Choose a destination")
	assert_eq(_verbs(Enums.InputState.MOVEMENT_PLANNING, kb)[0], "Add stop")
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.MOVEMENT_PLANNING, kb),
			"Select the marker again to move")
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.MOVEMENT_PLANNING, HintBarCommands.Model.TOUCH),
			"Tap the marker again to move")
	# Same glyphs in both states — only the words change.
	assert_eq(_glyphs(Enums.InputState.MOVEMENT_PLANNING, kb), _glyphs(Enums.InputState.UNIT_SELECTED, kb))


func test_only_the_planning_step_is_a_call_to_action() -> void:
	# §14: CTA = "the game suggests this next"; ONE on screen. The planning
	# line is it (so the change from "Choose a destination" registers — RQD
	# 2026-08-21); nothing else in the table claims it, and not during the
	# enemy phase.
	assert_true(HintBarCommands.step_is_call_to_action(Enums.InputState.MOVEMENT_PLANNING))
	assert_false(HintBarCommands.step_is_call_to_action(Enums.InputState.MOVEMENT_PLANNING, true))
	var cta_states: Array = []
	for state: Enums.InputState in HintBarCommands.states_with_entries():
		if HintBarCommands.step_is_call_to_action(state):
			cta_states.append(state)
	assert_eq(cta_states, [Enums.InputState.MOVEMENT_PLANNING])


func test_states_the_bar_is_silent_in() -> void:
	for state: Enums.InputState in [Enums.InputState.PAUSED, Enums.InputState.BATTLE_RESULT,
			Enums.InputState.DIALOGUE, Enums.InputState.RECRUITING]:
		assert_eq(HintBarCommands.items_for(state).size(), 0, Enums.InputState.keys()[state])
		assert_eq(HintBarCommands.step_text_for(state, HintBarCommands.Model.KEYBOARD_MOUSE), "")


# --- the DEFAULT row, three renderings (mockup round 1) -----------------------

func test_default_row_under_controller() -> void:
	# X / LB are the 2026-08-20 bindings (end_turn / toggle_threat_zones were
	# keyboard-only before); B is ui_cancel, which opens the menu from DEFAULT.
	assert_eq(_glyphs(Enums.InputState.DEFAULT, HintBarCommands.Model.CONTROLLER),
			["A", "Y", "X", "LB", "B"])
	assert_eq(_verbs(Enums.InputState.DEFAULT, HintBarCommands.Model.CONTROLLER),
			["Select", "Unit info", "End turn", "Threat zones", "Menu"])


func test_default_row_under_keyboard_mouse() -> void:
	assert_eq(_glyphs(Enums.InputState.DEFAULT, HintBarCommands.Model.KEYBOARD_MOUSE),
			["LMB", "I", "E", "V", "Esc"])


func test_default_row_under_touch_is_only_the_buttons() -> void:
	# Select has no button — tapping the map IS the select. The three that have
	# no gesture become buttons.
	assert_eq(_glyphs(Enums.InputState.DEFAULT, HintBarCommands.Model.TOUCH),
			["End turn", "Threat", "Menu"])


func test_unit_selected_row() -> void:
	assert_eq(_glyphs(Enums.InputState.UNIT_SELECTED, HintBarCommands.Model.KEYBOARD_MOUSE),
			["LMB", "RMB", "I"])
	assert_eq(_glyphs(Enums.InputState.UNIT_SELECTED, HintBarCommands.Model.TOUCH),
			["Cancel", "Unit info"])


# --- step text ----------------------------------------------------------------

func test_step_text_per_model() -> void:
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.DEFAULT,
			HintBarCommands.Model.KEYBOARD_MOUSE), "Select a unit")
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.DEFAULT,
			HintBarCommands.Model.CONTROLLER), "Select a unit")
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.DEFAULT,
			HintBarCommands.Model.TOUCH), "Tap a unit")
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.UNIT_DETAIL,
			HintBarCommands.Model.TOUCH), "", "unit detail has no step line")


func test_enemy_phase_is_step_only() -> void:
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.DEFAULT,
			HintBarCommands.Model.CONTROLLER, true), HintBarCommands.ENEMY_PHASE_STEP)
	assert_eq(_glyphs(Enums.InputState.DEFAULT, HintBarCommands.Model.CONTROLLER, true), [])


# --- glyphs come from the LIVE InputMap ---------------------------------------

func test_unbound_action_drops_out_of_the_bar() -> void:
	InputMap.add_action(_UNBOUND)
	var item := {action = _UNBOUND, verb = "Nope"}
	assert_eq(HintBarCommands.glyph_for(item, HintBarCommands.Model.CONTROLLER), "")
	assert_eq(HintBarCommands.glyph_for(item, HintBarCommands.Model.KEYBOARD_MOUSE), "")
	assert_eq(HintBarCommands.glyph_for(item, HintBarCommands.Model.TOUCH), "",
			"no touch_label → no button either")


func test_rebinding_shows_the_new_key_not_the_default() -> void:
	InputMap.add_action(_REBIND)
	var q := InputEventKey.new()
	q.keycode = KEY_Q
	InputMap.action_add_event(_REBIND, q)
	assert_eq(HintBarCommands.key_label_for_action(_REBIND), "Q")

	InputMap.action_erase_events(_REBIND)
	var z := InputEventKey.new()
	z.keycode = KEY_Z
	InputMap.action_add_event(_REBIND, z)
	assert_eq(HintBarCommands.key_label_for_action(_REBIND), "Z",
			"the bar reads bindings at sample time — a rebind is reflected, never the default")

	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_RIGHT_SHOULDER
	InputMap.action_add_event(_REBIND, pad)
	assert_eq(HintBarCommands.joy_label_for_action(_REBIND, HintBarCommands.JoySkin.XBOX), "RB")


func test_key_labels_special_and_physical() -> void:
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	assert_eq(HintBarCommands.key_label(esc), "Esc")
	var physical_only := InputEventKey.new()
	physical_only.physical_keycode = KEY_E  # how project.godot authors letters
	assert_eq(HintBarCommands.key_label(physical_only), "E")
	var none := InputEventKey.new()
	assert_eq(HintBarCommands.key_label(none), "")


# --- controller skins -----------------------------------------------------------

func test_joy_skin_from_pad_name() -> void:
	assert_eq(HintBarCommands.joy_skin_for_name("Sony DualSense Wireless Controller"),
			HintBarCommands.JoySkin.PLAYSTATION)
	assert_eq(HintBarCommands.joy_skin_for_name("Nintendo Switch Pro Controller"),
			HintBarCommands.JoySkin.NINTENDO)
	assert_eq(HintBarCommands.joy_skin_for_name("Steam Deck Controller"),
			HintBarCommands.JoySkin.STEAM_DECK)
	assert_eq(HintBarCommands.joy_skin_for_name("Xbox Series X Controller"),
			HintBarCommands.JoySkin.XBOX)
	assert_eq(HintBarCommands.joy_skin_for_name("Some Generic Gamepad"),
			HintBarCommands.JoySkin.XBOX, "unknown → Xbox layout (what Steam Input reports too)")


func test_joy_button_labels_per_skin() -> void:
	assert_eq(HintBarCommands.joy_button_label(JOY_BUTTON_A, HintBarCommands.JoySkin.XBOX), "A")
	assert_eq(HintBarCommands.joy_button_label(JOY_BUTTON_A, HintBarCommands.JoySkin.PLAYSTATION), "Cross")
	assert_eq(HintBarCommands.joy_button_label(JOY_BUTTON_A, HintBarCommands.JoySkin.NINTENDO), "B",
			"Nintendo prints the swapped letter on the same position")
	assert_eq(HintBarCommands.joy_button_label(JOY_BUTTON_LEFT_SHOULDER, HintBarCommands.JoySkin.STEAM_DECK), "L1")
	assert_eq(HintBarCommands.joy_button_label(JOY_BUTTON_LEFT_SHOULDER, HintBarCommands.JoySkin.XBOX), "LB")
	assert_eq(HintBarCommands.joy_button_label(JOY_BUTTON_START, HintBarCommands.JoySkin.XBOX), "Menu")


func test_skin_override_drives_resolution() -> void:
	HintBarCommands.joy_skin_override = HintBarCommands.JoySkin.PLAYSTATION
	assert_eq(_glyphs(Enums.InputState.DEFAULT, HintBarCommands.Model.CONTROLLER),
			["Cross", "Triangle", "Square", "L1", "Circle"])
