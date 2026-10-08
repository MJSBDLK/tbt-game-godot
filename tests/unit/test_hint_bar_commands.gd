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


func _verbs(state: Enums.InputState, model: HintBarCommands.Model,
		hover: HintBarCommands.Hover = HintBarCommands.Hover.UNIT) -> Array:
	var out: Array = []
	for entry: Dictionary in HintBarCommands.resolve(state, model, false, hover):
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
			"never promise a confirm for a click that only plots")
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.UNIT_SELECTED, kb), "Choose a destination")
	assert_eq(_verbs(Enums.InputState.MOVEMENT_PLANNING, kb)[0], "Add stop")
	# "confirm", never "move": the press stages the plan (deferred walk), the
	# sprite walks when the action commits.
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.MOVEMENT_PLANNING, kb),
			"Select the marker again to confirm")
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.MOVEMENT_PLANNING, HintBarCommands.Model.TOUCH),
			"Tap the marker again to confirm")
	# Same glyphs in both states — only the words change.
	assert_eq(_glyphs(Enums.InputState.MOVEMENT_PLANNING, kb), _glyphs(Enums.InputState.UNIT_SELECTED, kb))


func test_only_the_planning_step_is_a_notice_and_has_the_confirm_path_button() -> void:
	# §14 NOTICE (violet, static, not a button): ONE on screen. The planning
	# line is it (so the change from "Choose a destination" registers — RQD
	# 2026-08-21); nothing else in the table claims it, never in the enemy
	# phase. The same state offers the playtest alternative, "Confirm path".
	assert_true(HintBarCommands.step_is_notice(Enums.InputState.MOVEMENT_PLANNING))
	assert_false(HintBarCommands.step_is_notice(Enums.InputState.MOVEMENT_PLANNING, true))
	assert_eq(HintBarCommands.confirm_label_for(Enums.InputState.MOVEMENT_PLANNING), "Confirm path")
	assert_eq(HintBarCommands.confirm_label_for(Enums.InputState.UNIT_SELECTED), "")
	var notice_states: Array = []
	for state: Enums.InputState in HintBarCommands.states_with_entries():
		if HintBarCommands.step_is_notice(state):
			notice_states.append(state)
	assert_eq(notice_states, [Enums.InputState.MOVEMENT_PLANNING])


func test_states_the_bar_is_silent_in() -> void:
	for state: Enums.InputState in [Enums.InputState.PAUSED, Enums.InputState.BATTLE_RESULT,
			Enums.InputState.DIALOGUE, Enums.InputState.RECRUITING]:
		assert_eq(HintBarCommands.items_for(state).size(), 0, Enums.InputState.keys()[state])
		assert_eq(HintBarCommands.step_text_for(state, HintBarCommands.Model.KEYBOARD_MOUSE), "")


# --- the DEFAULT row, three renderings (mockup round 1) -----------------------

func test_default_row_under_controller() -> void:
	# The zones ride RT (a trigger); B is ui_cancel, which opens the menu from
	# DEFAULT. Next unit (RB) is touch's alone: the bar teaches, it doesn't
	# enumerate.
	assert_eq(_glyphs(Enums.InputState.DEFAULT, HintBarCommands.Model.CONTROLLER),
			["A", "Y", "X", "RT", "B"])
	assert_eq(_verbs(Enums.InputState.DEFAULT, HintBarCommands.Model.CONTROLLER),
			["Select", "Unit info", "End turn", "Threat zones", "Menu"])


func test_default_row_under_keyboard_mouse() -> void:
	assert_eq(_glyphs(Enums.InputState.DEFAULT, HintBarCommands.Model.KEYBOARD_MOUSE),
			["LMB", "I", "Bksp", "V", "Esc"])


func test_default_row_under_touch_is_only_the_buttons() -> void:
	# Select has no button — tapping the map IS the select. The ones that have
	# no gesture become buttons; Next is touch's only way to cycle units.
	assert_eq(_glyphs(Enums.InputState.DEFAULT, HintBarCommands.Model.TOUCH),
			["End turn", "Threat", "Menu", "Next"])


func test_the_info_verb_says_what_the_press_does_under_the_cursor() -> void:
	var on_nothing := _verbs(Enums.InputState.DEFAULT, HintBarCommands.Model.CONTROLLER,
			HintBarCommands.Hover.NO_UNIT)
	assert_true(on_nothing.has("Type icons"), "no unit to read: the info button shows type icons")
	assert_eq(_verbs(Enums.InputState.UNIT_SELECTED, HintBarCommands.Model.CONTROLLER,
			HintBarCommands.Hover.NO_UNIT).has("Unit info"), true,
			"with a unit selected the info button is that unit's, whatever's under the cursor")


func test_the_zone_verb_names_the_next_press() -> void:
	var zone_verb := func(press: int) -> String:
		for entry: Dictionary in HintBarCommands.resolve(Enums.InputState.DEFAULT,
				HintBarCommands.Model.CONTROLLER, false, HintBarCommands.Hover.UNIT, press):
			if entry.action == &"toggle_threat_zones":
				return entry.verb
		return ""
	assert_eq(zone_verb.call(-1), "Threat zones", "no battle, no controller: the plain verb")
	assert_eq(zone_verb.call(ThreatOverlayController.Press.SHOW_ARMY), "Threat zones")
	assert_eq(zone_verb.call(ThreatOverlayController.Press.HIDE_ARMY), "Hide threat zones")
	assert_eq(zone_verb.call(ThreatOverlayController.Press.PIN), "Pin zone")
	assert_eq(zone_verb.call(ThreatOverlayController.Press.UNPIN), "Unpin zone")


func test_unit_detail_row_says_what_the_press_does() -> void:
	# RQD 2026-09-10: "all the controls bar reads, in this context, is 'B for
	# close'". The sheet is a focus chain under the cursor model now, so A
	# means something. Touch has no cursor — a tap IS the inspect — so only
	# Close is a button there. Still no step line (mockup round 1).
	assert_eq(_glyphs(Enums.InputState.UNIT_DETAIL, HintBarCommands.Model.CONTROLLER), ["A", "B"])
	assert_eq(_verbs(Enums.InputState.UNIT_DETAIL, HintBarCommands.Model.CONTROLLER),
			["Inspect", "Close"])
	assert_eq(_glyphs(Enums.InputState.UNIT_DETAIL, HintBarCommands.Model.KEYBOARD_MOUSE),
			["LMB", "Esc"])
	assert_eq(_glyphs(Enums.InputState.UNIT_DETAIL, HintBarCommands.Model.TOUCH), ["Close"])


func test_unit_selected_row() -> void:
	assert_eq(_glyphs(Enums.InputState.UNIT_SELECTED, HintBarCommands.Model.KEYBOARD_MOUSE),
			["LMB", "RMB", "I"])
	assert_eq(_glyphs(Enums.InputState.UNIT_SELECTED, HintBarCommands.Model.TOUCH),
			["Cancel", "Unit info"])


# --- step text ----------------------------------------------------------------

func test_step_text_per_model() -> void:
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.DEFAULT,
			HintBarCommands.Model.KEYBOARD_MOUSE), "Select one of your units")
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.DEFAULT,
			HintBarCommands.Model.CONTROLLER), "Select one of your units")
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.DEFAULT,
			HintBarCommands.Model.TOUCH), "Tap one of your units")
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.UNIT_DETAIL,
			HintBarCommands.Model.TOUCH), "", "unit detail has no step line")


# --- inspect notice: a DEFAULT press on a unit you can't command ---------------

func test_inspect_notice_per_unit() -> void:
	assert_eq(HintBarCommands.inspect_notice_for(Enums.UnitFaction.PLAYER, true),
			HintBarCommands.InspectNotice.NONE, "a commandable unit just gets selected")
	assert_eq(HintBarCommands.inspect_notice_for(Enums.UnitFaction.PLAYER, false),
			HintBarCommands.InspectNotice.ALREADY_ACTED)
	assert_eq(HintBarCommands.inspect_notice_for(Enums.UnitFaction.ENEMY, true),
			HintBarCommands.InspectNotice.ENEMY)
	assert_eq(HintBarCommands.inspect_notice_for(Enums.UnitFaction.ALLY, true),
			HintBarCommands.InspectNotice.NOT_YOURS)
	assert_eq(HintBarCommands.inspect_notice_for(Enums.UnitFaction.NEUTRAL, true),
			HintBarCommands.InspectNotice.NOT_YOURS)


func test_inspect_notice_replaces_the_default_step_and_wears_notice() -> void:
	var enemy := HintBarCommands.InspectNotice.ENEMY
	var line := HintBarCommands.step_text_for(Enums.InputState.DEFAULT,
			HintBarCommands.Model.KEYBOARD_MOUSE, false, enemy)
	assert_string_contains(line, "Enemy")
	assert_string_contains(line, "select one of yours")
	assert_string_contains(HintBarCommands.step_text_for(Enums.InputState.DEFAULT,
			HintBarCommands.Model.TOUCH, false, enemy), "tap one of yours", "touch verb")
	assert_true(HintBarCommands.step_is_notice(Enums.InputState.DEFAULT, false, enemy))
	assert_false(HintBarCommands.step_is_notice(Enums.InputState.DEFAULT))


func test_inspect_notice_is_default_only_and_yields_to_the_enemy_phase() -> void:
	var enemy := HintBarCommands.InspectNotice.ENEMY
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.UNIT_SELECTED,
			HintBarCommands.Model.KEYBOARD_MOUSE, false, enemy), "Choose a destination")
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.DEFAULT,
			HintBarCommands.Model.KEYBOARD_MOUSE, true, enemy), HintBarCommands.ENEMY_PHASE_STEP)
	assert_false(HintBarCommands.step_is_notice(Enums.InputState.DEFAULT, true, enemy))


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
			["Cross", "Triangle", "Square", "R2", "Circle"])


func test_triggers_are_labeled_per_skin() -> void:
	var expected := {
		HintBarCommands.JoySkin.XBOX: ["LT", "RT"],
		HintBarCommands.JoySkin.STEAM_DECK: ["L2", "R2"],
		HintBarCommands.JoySkin.PLAYSTATION: ["L2", "R2"],
		HintBarCommands.JoySkin.NINTENDO: ["ZL", "ZR"],
	}
	for skin: HintBarCommands.JoySkin in expected:
		assert_eq([HintBarCommands.joy_trigger_label(JOY_AXIS_TRIGGER_LEFT, skin),
				HintBarCommands.joy_trigger_label(JOY_AXIS_TRIGGER_RIGHT, skin)], expected[skin])
		for label: String in expected[skin]:
			assert_not_null(HintBarCommands.joy_glyph_texture(label), "%s has its sprite" % label)
	assert_eq(HintBarCommands.joy_trigger_label(JOY_AXIS_LEFT_X, HintBarCommands.JoySkin.XBOX), "",
			"a stick isn't a button the bar can name")


# --- the level-up reveal (manual advance, 2026-09-09) --------------------------

func test_the_level_up_reveal_says_continue_in_both_phases() -> void:
	# RQD 2026-09-09 manual advance: LevelUpStatPanel holds for a press. An
	# enemy's hit can level our defender, so the row survives the enemy-phase
	# blank every other state gets — phase_blind is that one exception.
	var state := Enums.InputState.LEVEL_UP_CELEBRATION
	for enemy: bool in [false, true]:
		assert_eq(_glyphs(state, HintBarCommands.Model.CONTROLLER, enemy), ["A"],
				"Continue on the pad (enemy phase: %s)" % enemy)
		assert_eq(_glyphs(state, HintBarCommands.Model.KEYBOARD_MOUSE, enemy), ["LMB"])
		assert_eq(_glyphs(state, HintBarCommands.Model.TOUCH, enemy), ["Continue"],
				"touch gets a real button")
		assert_eq(HintBarCommands.step_text_for(state, HintBarCommands.Model.KEYBOARD_MOUSE, enemy),
				"", "no step line — the panel is the step")
	for other: Enums.InputState in HintBarCommands.states_with_entries():
		if other != state:
			assert_eq(HintBarCommands.items_for(other, true).size(), 0,
					"%s still blanks in the enemy phase" % Enums.InputState.keys()[other])


func test_the_right_click_items_name_backs_binding() -> void:
	var kb := HintBarCommands.Model.KEYBOARD_MOUSE
	assert_eq(_glyphs(Enums.InputState.UNIT_SELECTED, kb), ["LMB", "RMB", "I"])
	var bindings := InputMap.action_get_events(&"back")
	InputMap.action_erase_events(&"back")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_B
	InputMap.action_add_event(&"back", key)
	assert_eq(_glyphs(Enums.InputState.UNIT_SELECTED, kb)[1], "B", "a rebind shows the new button")
	InputMap.action_erase_events(&"back")
	for binding: InputEvent in bindings:
		InputMap.action_add_event(&"back", binding)


func test_an_armed_target_asks_touch_for_the_second_tap() -> void:
	var state := Enums.InputState.ATTACK_TARGETING
	var none := HintBarCommands.InspectNotice.NONE
	assert_eq(HintBarCommands.step_text_for(state, HintBarCommands.Model.TOUCH), "Tap a target")
	assert_eq(HintBarCommands.step_text_for(state, HintBarCommands.Model.TOUCH, false, none, true),
			"Tap the target again to attack")
	assert_true(HintBarCommands.step_is_notice(state, false, none, true),
			"a changed instruction wears the notice border")
	assert_eq(HintBarCommands.step_text_for(state, HintBarCommands.Model.CONTROLLER, false, none, true),
			"Choose a target", "only touch arms: the pad sees the forecast on its cursor")
