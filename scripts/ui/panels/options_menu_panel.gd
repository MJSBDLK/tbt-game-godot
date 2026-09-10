## Centered options menu — three tabs (Gameplay / Video / Audio) over one row
## registry. Opened from the system menu's Options button, the start screen,
## and the intermission hub (UIManager.show_options_menu).
##
## WHY TABS (RQD 2026-09-09: "Options menu has gotten too big for the
## screen"): sixteen rows in one column ran ~420 px on the 360 px HUD canvas,
## so the title and Close clipped on 16:9 and only just fit the Deck's 8:5.
## Tabs cap the column at the tallest tab, and the rows area is pinned to
## that height so the strip and Close never jump between tabs.
##
## ROW REGISTRY: every persisted setting is ONE entry in _row_specs() — tab,
## label, tooltip, kind (CHOICE = the toggle pills, SLIDER = HSlider + live
## readout), current value, write callable. Adding a setting is adding an
## entry; test_options_menu_panel.gd pins which tab each one lives on and
## that the tallest tab fits the canvas. The choice pills stay hand-rolled ON
## PURPOSE — the §14 border vocabulary has no toggle/segmented design yet
## (ui-style-guide §14 note); the tab headers and Close are InteractiveButtons
## (lit border = pressable; the current tab wears `selected`, the brackets).
##
## INPUT: tab headers are focusable and pressable; menu_tab_prev/menu_tab_next
## (Q / E, LB / RB — project.godot) switch from anywhere in the panel and wrap.
## Cursor model (InputSource, RQD 2026-07-29): a cursor-driven open lands
## focus on the current tab's first row (on its ACTIVE pill — "you are here"
## is the current value); a pointer open stays quiet and the first navigation
## press summons the cursor there. Escape / B closes.
class_name OptionsMenuPanel
extends PanelContainer


signal closed()

enum Tab { GAMEPLAY, VIDEO, AUDIO }
enum RowKind { CHOICE, SLIDER }

const GLOW_MATERIAL: ShaderMaterial = preload("res://resources/hud_glow.tres")

const OPTION_LABEL_WIDTH: int = 80
const OPTION_HEIGHT: int = 14
const PANEL_MIN_WIDTH: int = 220
const ROW_SEPARATION: int = 6
const TAB_BUTTON_WIDTH: int = 60
## Width reserved on each side of the strip for the "[Q]" / "[LB]" glyph, so
## the headers sit centered whether or not a glyph is showing.
const TAB_GLYPH_WIDTH: int = 24

const TAB_ORDER: Array[int] = [Tab.GAMEPLAY, Tab.VIDEO, Tab.AUDIO]
const TAB_LABELS: Dictionary = {Tab.GAMEPLAY: "Gameplay", Tab.VIDEO: "Video", Tab.AUDIO: "Audio"}
const TAB_PREV_ACTION: StringName = &"menu_tab_prev"
const TAB_NEXT_ACTION: StringName = &"menu_tab_next"


## The open tab. Remembered across opens within a session (the panel instance
## lives in UIManager), so reopening lands where the player left off.
var current_tab: Tab = Tab.GAMEPLAY

var _content_container: VBoxContainer = null
var _rows_area: Control = null
var _tab_boxes: Dictionary = {}       # Tab → VBoxContainer; only the current one is visible
var _tab_buttons: Dictionary = {}     # Tab → InteractiveButton
var _choice_buttons: Dictionary = {}  # row id → {choice value → Button}
var _choice_values: Dictionary = {}   # row id → the value currently active
var _border_overlay: PanelBorderOverlay = null

# Style caches
var _toggle_style_active: StyleBoxFlat = null
var _toggle_style_inactive: StyleBoxFlat = null
var _toggle_style_hovered: StyleBoxFlat = null


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_MIN_WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Transparent panel — we draw our own inset background.
	var panel_style := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", panel_style)

	# Inset background (5px from each edge = midpoint of 10px border)
	var background := Panel.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = GameColors.HUD_PANEL_BACKGROUND
	bg_style.set_corner_radius_all(5)
	background.add_theme_stylebox_override("panel", bg_style)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.offset_left = 5
	background.offset_right = -5
	background.offset_top = 5
	background.offset_bottom = -5
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# Toggle button styles
	_toggle_style_active = _create_toggle_style(GameColors.ACTION_BUTTON_BG_HOVERED, true)
	_toggle_style_inactive = _create_toggle_style(GameColors.ACTION_BUTTON_BG_NORMAL, false)
	_toggle_style_hovered = _create_toggle_style(GameColors.ACTION_BUTTON_BG_HOVERED, false)

	# Margins
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", ROW_SEPARATION)
	margin.add_child(_content_container)

	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_panel()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(TAB_PREV_ACTION):
		step_tab(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(TAB_NEXT_ACTION):
		step_tab(1)
		get_viewport().set_input_as_handled()
		return
	# Quiet-open adoption (InputSource, RQD 2026-07-29): a pointer-opened
	# panel has no cursor — the first navigation press summons it onto the
	# current tab's first row instead of falling on deaf ears.
	if InputSource.is_navigation_press(event) \
			and get_viewport().gui_get_focus_owner() == null:
		_focus_first_row()
		get_viewport().set_input_as_handled()


# =============================================================================
# PUBLIC API
# =============================================================================

func show_panel() -> void:
	_populate()
	visible = true
	_ensure_border_overlay()
	# Default selection is a CURSOR-model courtesy (controller/keyboard needs
	# a starting point). Under pointer input it would read as a phantom "you
	# are here" nobody put there — open quiet; the first nav press adopts.
	if InputSource.is_cursor_driven():
		_focus_first_row()


func hide_panel() -> void:
	visible = false
	_clear_items()
	closed.emit()


## Switch tabs: mark the header, swap the visible rows box, and — when a row
## held the cursor — re-seat it on the new tab's first row, so a switch never
## strands focus on a hidden control.
func select_tab(tab: Tab) -> void:
	var focus_owner: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var cursor_was_in_rows: bool = focus_owner != null and _rows_area != null \
			and _rows_area.is_ancestor_of(focus_owner)
	current_tab = tab
	for key: int in _tab_boxes:
		(_tab_boxes[key] as Control).visible = (key == tab)
	for key: int in _tab_buttons:
		(_tab_buttons[key] as InteractiveButton).selected = (key == tab)
	if cursor_was_in_rows:
		_focus_first_row()


## Next / previous tab in TAB_ORDER, wrapping at both ends.
func step_tab(direction: int) -> void:
	var index: int = TAB_ORDER.find(current_tab)
	select_tab(TAB_ORDER[posmod(index + direction, TAB_ORDER.size())] as Tab)


## The row ids that live on a tab, in display order — the registry as tests
## (and anyone auditing the menu) see it.
func tab_row_ids(tab: Tab) -> Array[String]:
	var ids: Array[String] = []
	for spec: Dictionary in _row_specs():
		if int(spec.tab) == tab:
			ids.append(String(spec.id))
	return ids


# =============================================================================
# THE REGISTRY
# =============================================================================

## One entry per persisted setting; order within a tab is display order.
## `current` is read at build time — Settings is the source of truth, correct
## even when no camera / battle exists (Options from the hub). `write`
## persists through the Settings setter; the few settings a live system needs
## to be nudged about (camera zoom mode, a pending auto end) route through a
## named _write_* method.
func _row_specs() -> Array[Dictionary]:
	var on_off: Array = [[true, "On"], [false, "Off"]]
	return [
		# --- GAMEPLAY ------------------------------------------------------
		# Click-to-attack shortcut. Off by default — new players kept attacking
		# enemies they meant to inspect.
		{id = "click_attack", tab = Tab.GAMEPLAY, kind = RowKind.CHOICE, label = "Quick Attack",
			tooltip = "Clicking an enemy with a unit selected attacks immediately.",
			choices = on_off, current = Settings.click_to_attack_enabled,
			write = Settings.set_click_to_attack_enabled},
		# Auto end turn (meeting ask 2026-06-28): ON = the phase hands off the
		# moment every unit has acted. OFF = the phase waits and the system
		# menu's End Turn wears the call-to-action.
		{id = "auto_end_turn", tab = Tab.GAMEPLAY, kind = RowKind.CHOICE, label = "Auto End Turn",
			tooltip = "End your turn automatically once every unit has acted.",
			choices = on_off, current = Settings.auto_end_turn,
			write = _write_auto_end_turn},
		# Move Confirm — the playtest toggle (RQD 2026-08-21). Auto = button on
		# touch, marker elsewhere; Marker = press the marker again (fluent);
		# Button = the hint bar offers "Move here" (clear, clunkier).
		{id = "move_confirm", tab = Tab.GAMEPLAY, kind = RowKind.CHOICE, label = "Move Confirm",
			tooltip = "How a planned move is confirmed. Marker: press the marker again. Button: a Move Here button in the hint bar. Auto: button on touch screens, marker otherwise.",
			choices = [[Settings.MoveConfirmMode.AUTO, "Auto"], [Settings.MoveConfirmMode.MARKER, "Marker"],
					[Settings.MoveConfirmMode.BUTTON, "Button"]],
			current = Settings.move_confirm_mode, write = Settings.set_move_confirm_mode},
		# Move Commit — the todo-4A playtest toggle (RQD 2026-08-31). Walk = the
		# unit walks on plan-confirm; Ghost = a ghost holds the spot and the
		# unit walks when the action commits, so cancel never teleports.
		{id = "move_commit", tab = Tab.GAMEPLAY, kind = RowKind.CHOICE, label = "Move Commit",
			tooltip = "When a confirmed move actually happens. Walk: the unit walks right away, before choosing an action. Ghost: a ghost holds the spot and the unit walks when the action is confirmed.",
			choices = [[Settings.MoveCommitMode.WALK_THEN_ACT, "Walk"],
					[Settings.MoveCommitMode.ACT_THEN_WALK, "Ghost"]],
			current = Settings.move_commit_mode, write = Settings.set_move_commit_mode},
		# Battle Animations (todo-archive "Battle animations plan" D4/D5).
		# Scene = the FE7-style cutaway always; Player = cutaway on the
		# player's turn, in-place beats on the enemy's; Map = in-place always.
		{id = "battle_animations", tab = Tab.GAMEPLAY, kind = RowKind.CHOICE, label = "Battle Anims",
			tooltip = "How attacks are shown. Scene: a side-view combat scene for every attack. Player: the scene on your turn only, quick map animations on the enemy's. Map: quick map animations always.",
			choices = [[Settings.BattleAnimations.ALWAYS, "Scene"],
					[Settings.BattleAnimations.PLAYER_PHASE_ONLY, "Player"],
					[Settings.BattleAnimations.MAP, "Map"]],
			current = Settings.battle_animations, write = Settings.set_battle_animations},
		# Seeded Reload: On = loading a save restores the dice exactly (same
		# actions, same outcomes — Fire-Emblem-fair). Off = every load re-rolls
		# fate. Saves always record the dice, so flipping this never
		# invalidates one.
		{id = "seeded_reload", tab = Tab.GAMEPLAY, kind = RowKind.CHOICE, label = "Seeded Reload",
			tooltip = "On: loading a save keeps the dice — same choices, same results.\nOff: every load re-rolls fate.",
			choices = on_off, current = Settings.seeded_reload,
			write = Settings.set_seeded_reload},
		# Control Hints: the battle HUD's hint / command bar. Under TOUCH the
		# bar is the only End turn / Menu / Threat zones control, so the
		# tooltip says so — a phone player who turns it off is choosing the
		# pause menu as their only exit.
		{id = "control_hints", tab = Tab.GAMEPLAY, kind = RowKind.CHOICE, label = "Control Hints",
			tooltip = "Show the bottom bar of button hints for the current step. On touch screens it is also the End Turn / Menu / Threat Zones control.",
			choices = on_off, current = Settings.show_control_hints,
			write = Settings.set_show_control_hints},
		# Hold-to-peek delay for move detail tooltips (ui-style-guide §14). The
		# 200 ms floor is a softlock guard: shorter than a player can reliably
		# release would open a tooltip on every tap (RQD 2026-07-19).
		{id = "tooltip_hold", tab = Tab.GAMEPLAY, kind = RowKind.SLIDER, label = "Tooltip Hold",
			tooltip = "How long to hold a move chip before its detail card opens.",
			min_value = float(Settings.TOOLTIP_HOLD_MIN_MS), max_value = float(Settings.TOOLTIP_HOLD_MAX_MS),
			step = float(Settings.TOOLTIP_HOLD_STEP_MS), current = float(Settings.tooltip_hold_ms),
			format = _format_milliseconds, write = _write_tooltip_hold},
		# --- VIDEO ---------------------------------------------------------
		# Zoom mode: the camera mirrors Settings on spawn, and a live camera
		# is nudged by _write_zoom_mode.
		{id = "zoom_mode", tab = Tab.VIDEO, kind = RowKind.CHOICE, label = "Zoom Mode",
			tooltip = "Smooth: any zoom level, slight shimmer. Integer: whole pixel multiples, always crisp.",
			choices = [[false, "Smooth"], [true, "Integer"]],
			current = Settings.integer_zoom_mode, write = _write_zoom_mode},
		# HD line-art portrait distortion / glass shaders. Accessibility
		# (motion / flicker); every HDPortraitSlot re-applies off Settings.changed.
		{id = "portrait_effects", tab = Tab.VIDEO, kind = RowKind.CHOICE, label = "Portrait FX",
			tooltip = "Distortion and glass effects on the line-art portraits.",
			choices = on_off, current = Settings.portrait_effects_enabled,
			write = Settings.set_portrait_effects_enabled},
		# Border-vocabulary animations (brackets, rings, backlight fade).
		# Colors always stay — only motion stops. InteractiveButton reads the
		# flag live every frame, so this applies instantly.
		{id = "ui_motion", tab = Tab.VIDEO, kind = RowKind.CHOICE, label = "UI Motion",
			tooltip = "Animated button borders. Off keeps the colors but stops the movement.",
			choices = on_off, current = Settings.ui_motion_enabled,
			write = Settings.set_ui_motion_enabled},
		# On-map type icons beside unit health bars. Off by default (noisy);
		# units re-apply live off Settings.changed.
		{id = "type_icons", tab = Tab.VIDEO, kind = RowKind.CHOICE, label = "Type Icons",
			tooltip = "Show units' elemental types beside their health bars on the map.",
			choices = on_off, current = Settings.unit_type_icons_enabled,
			write = Settings.set_unit_type_icons_enabled},
		# FPS cap: the leftmost notch (below 30) reads as "Off" → Engine.max_fps 0.
		{id = "max_fps", tab = Tab.VIDEO, kind = RowKind.SLIDER, label = "FPS Cap",
			tooltip = "Cap the framerate. Off = uncapped (VSync still applies).",
			min_value = 20.0, max_value = 1000.0, step = 10.0,
			current = float(Settings.max_fps) if Settings.max_fps >= 30 else 20.0,
			format = _format_fps, write = _write_max_fps},
		# --- AUDIO ---------------------------------------------------------
		# Volume buses are minted by Settings at load.
		{id = "master_volume", tab = Tab.AUDIO, kind = RowKind.SLIDER, label = "Master Vol.",
			tooltip = "Overall game volume.", min_value = 0.0, max_value = 1.0, step = 0.05,
			current = Settings.master_volume, format = _format_percent,
			write = Settings.set_master_volume},
		{id = "sfx_volume", tab = Tab.AUDIO, kind = RowKind.SLIDER, label = "SFX Vol.",
			tooltip = "Sound effect volume.", min_value = 0.0, max_value = 1.0, step = 0.05,
			current = Settings.sfx_volume, format = _format_percent,
			write = Settings.set_sfx_volume},
		{id = "music_volume", tab = Tab.AUDIO, kind = RowKind.SLIDER, label = "Music Vol.",
			tooltip = "Music volume.", min_value = 0.0, max_value = 1.0, step = 0.05,
			current = Settings.music_volume, format = _format_percent,
			write = Settings.set_music_volume},
	]


# --- write hooks that do more than persist -----------------------------------

func _write_auto_end_turn(value: Variant) -> void:
	Settings.set_auto_end_turn(bool(value))
	# Flipping auto-end ON with a spent phase pending honors the new rule now:
	# the hand-off the player just asked for happens instead of dangling.
	if bool(value):
		var turn_manager: Node = get_node_or_null("/root/TurnManager")
		if turn_manager != null:
			turn_manager.check_end_player_turn()


func _write_zoom_mode(integer: Variant) -> void:
	# Persist first (survives restart), then apply live to the current camera.
	Settings.set_integer_zoom_mode(bool(integer))
	var camera := _get_camera()
	if camera != null:
		camera.integer_zoom_mode = bool(integer)


func _write_tooltip_hold(value: float) -> void:
	Settings.set_tooltip_hold_ms(roundi(value))


func _write_max_fps(value: float) -> void:
	Settings.set_max_fps(0 if value < 30.0 else roundi(value))


# --- slider readouts ---------------------------------------------------------

func _format_milliseconds(value: float) -> String:
	return "%dms" % roundi(value)


func _format_fps(value: float) -> String:
	return "Off" if value < 30.0 else "%d" % roundi(value)


func _format_percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


# =============================================================================
# POPULATION
# =============================================================================

func _populate() -> void:
	_clear_items()
	_create_title("OPTIONS")
	_create_tab_strip()
	_create_separator()
	_create_rows_area()
	_create_separator()
	_create_close_button()


func _create_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	var glow: ShaderMaterial = GLOW_MATERIAL.duplicate()
	glow.set_shader_parameter("glow_color", GameColors.TEXT_SECONDARY_GLOW)
	label.material = glow
	_content_container.add_child(label)


func _create_separator() -> void:
	var sep := HSeparator.new()
	var empty_style := StyleBoxEmpty.new()
	empty_style.content_margin_top = 2
	empty_style.content_margin_bottom = 2
	sep.add_theme_stylebox_override("separator", empty_style)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_container.add_child(sep)


## "[Q] Gameplay Video Audio [E]" — headers are InteractiveButtons (pressable
## = lit border; the current one wears `selected`, the §14 brackets), flanked
## by the shortcut glyphs in the driving device's own vocabulary.
func _create_tab_strip() -> void:
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	# 8, not the rows' 4: the selected header's §14 brackets sit
	# BRACKET_INSET_PIXELS outside its rect and need clear air on both sides.
	strip.add_theme_constant_override("separation", 2 * InteractiveButton.BRACKET_INSET_PIXELS + 4)
	_tab_buttons.clear()
	strip.add_child(_create_tab_glyph(TAB_PREV_ACTION))
	for tab: int in TAB_ORDER:
		var button := InteractiveButton.new()
		button.text = String(TAB_LABELS[tab])
		button.custom_minimum_size = Vector2(TAB_BUTTON_WIDTH, OPTION_HEIGHT)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.selected = (tab == current_tab)
		button.pressed.connect(func() -> void:
			# A clicked button takes focus natively; under the pointer model
			# that's a phantom cursor nobody summoned (InputSource doctrine —
			# see SystemMenuPanel._create_button). Cursor presses keep theirs.
			if not InputSource.is_cursor_driven():
				button.release_focus()
			select_tab(tab as Tab))
		_tab_buttons[tab] = button
		strip.add_child(button)
	strip.add_child(_create_tab_glyph(TAB_NEXT_ACTION))
	_content_container.add_child(strip)


## The shortcut beside the strip, as the driving device writes it ("[Q]",
## "[LB]" — HintBarCommands' tables, so a rebind shows up here too). Blank
## under touch: the headers are the buttons. Always takes its width, so the
## headers stay centered either way.
func _create_tab_glyph(action: StringName) -> Label:
	var label := Label.new()
	label.text = _tab_glyph_text(action)
	label.custom_minimum_size = Vector2(TAB_GLYPH_WIDTH, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _tab_glyph_text(action: StringName) -> String:
	if InputSource.is_touch_driven():
		return ""
	var glyph: String
	if InputSource.last_device == InputSource.Device.JOYPAD:
		glyph = HintBarCommands.joy_label_for_action(action, HintBarCommands.current_joy_skin())
	else:
		glyph = HintBarCommands.key_label_for_action(action)
	return "" if glyph.is_empty() else "[%s]" % glyph


## One VBox per tab, all built up front and stacked in one area whose minimum
## size is the LARGEST tab's — so switching never resizes the panel and the
## strip / Close stay put under the pointer. Only the current tab's box is
## visible; hidden boxes take no focus and no clicks.
func _create_rows_area() -> void:
	_rows_area = Control.new()
	_rows_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_container.add_child(_rows_area)
	_tab_boxes.clear()
	_choice_buttons.clear()
	_choice_values.clear()
	for tab: int in TAB_ORDER:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", ROW_SEPARATION)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.visible = (tab == current_tab)
		_rows_area.add_child(box)
		_tab_boxes[tab] = box
	for spec: Dictionary in _row_specs():
		var box: VBoxContainer = _tab_boxes[int(spec.tab)]
		match int(spec.kind):
			RowKind.CHOICE:
				box.add_child(_create_choice_row(spec))
			RowKind.SLIDER:
				box.add_child(_create_slider_row(spec))
	var largest := Vector2.ZERO
	for tab: int in _tab_boxes:
		var minimum: Vector2 = (_tab_boxes[tab] as Control).get_combined_minimum_size()
		largest = Vector2(maxf(largest.x, minimum.x), maxf(largest.y, minimum.y))
	assert(largest.y > 0.0, "OptionsMenuPanel: the rows area measured empty — no rows were built")
	_rows_area.custom_minimum_size = largest


func _create_row_label(text: String, tooltip: String) -> Label:
	var label := Label.new()
	label.text = text
	label.tooltip_text = tooltip
	label.custom_minimum_size = Vector2(OPTION_LABEL_WIDTH, 0)
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	var glow: ShaderMaterial = GLOW_MATERIAL.duplicate()
	glow.set_shader_parameter("glow_color", GameColors.TEXT_PRIMARY_GLOW)
	label.material = glow
	return label


## LABEL · [pill][pill](…) — one pill per choice, the current one lit.
func _create_choice_row(spec: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.set_meta("row_id", spec.id)
	row.add_child(_create_row_label(spec.label, spec.get("tooltip", "")))

	var pills := HBoxContainer.new()
	pills.add_theme_constant_override("separation", 2)
	var buttons: Dictionary = {}
	for choice: Array in spec.choices:
		var value: Variant = choice[0]
		var button := _create_toggle_button(String(choice[1]), value == spec.current)
		button.pressed.connect(_on_choice_pressed.bind(spec, value))
		buttons[value] = button
		pills.add_child(button)
	_choice_buttons[spec.id] = buttons
	_choice_values[spec.id] = spec.current
	row.add_child(pills)
	return row


func _on_choice_pressed(spec: Dictionary, value: Variant) -> void:
	(spec.write as Callable).call(value)
	_choice_values[spec.id] = value
	var buttons: Dictionary = _choice_buttons.get(spec.id, {})
	for key: Variant in buttons:
		_apply_toggle_state(buttons[key], key == value)


## LABEL · slider · readout. The readout label is captured by the closure;
## the row is freed wholesale by _clear_items, so no member refs are needed.
func _create_slider_row(spec: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.set_meta("row_id", spec.id)
	row.add_child(_create_row_label(spec.label, spec.get("tooltip", "")))

	var slider := HSlider.new()
	slider.min_value = float(spec.min_value)
	slider.max_value = float(spec.max_value)
	slider.step = float(spec.step)
	slider.value = float(spec.current)
	slider.custom_minimum_size = Vector2(80, OPTION_HEIGHT)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var format: Callable = spec.format
	var write: Callable = spec.write
	var value_label := Label.new()
	value_label.text = str(format.call(float(spec.current)))
	value_label.custom_minimum_size = Vector2(30, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	row.add_child(value_label)

	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = str(format.call(value))
		write.call(value))
	return row


func _create_close_button() -> void:
	# The one plain action in this panel — a vocabulary InteractiveButton.
	var button := InteractiveButton.new()
	button.text = "Close"
	button.custom_minimum_size = Vector2(0, OPTION_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.pressed.connect(func() -> void: hide_panel())
	_content_container.add_child(button)


# =============================================================================
# TOGGLE PILLS
# =============================================================================

func _create_toggle_button(text: String, is_active: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(56, OPTION_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.toggle_mode = false
	_apply_toggle_state(button, is_active)
	return button


func _apply_toggle_state(button: Button, is_active: bool) -> void:
	if is_active:
		button.add_theme_stylebox_override("normal", _toggle_style_active)
		button.add_theme_stylebox_override("hover", _toggle_style_active)
		button.add_theme_stylebox_override("pressed", _toggle_style_active)
		button.add_theme_stylebox_override("focus", _toggle_style_active)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
	else:
		button.add_theme_stylebox_override("normal", _toggle_style_inactive)
		button.add_theme_stylebox_override("hover", _toggle_style_hovered)
		button.add_theme_stylebox_override("pressed", _toggle_style_active)
		button.add_theme_stylebox_override("focus", _toggle_style_hovered)
		button.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", GameColors.TEXT_SECONDARY)


func _create_toggle_style(background_color: Color, is_active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = GameColors.ACTION_BUTTON_BORDER if not is_active \
		else GameColors.TEXT_SECONDARY
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style


# =============================================================================
# CURSOR — focus is "you are here"
# =============================================================================

## Deferred and re-resolved at fire time (same guard as SystemMenuPanel): the
## control the grab was queued for can be freed by a repopulate.
func _focus_first_row() -> void:
	_grab_first_row_focus.call_deferred()


## The current tab's first row: its ACTIVE pill for a choice row (the cursor
## lands on the current value), the slider for a slider row.
func _grab_first_row_focus() -> void:
	if not visible or not _tab_boxes.has(current_tab):
		return
	var box: Control = _tab_boxes[current_tab]
	if not is_instance_valid(box) or not box.is_inside_tree() or box.get_child_count() == 0:
		return
	var first_row: Node = box.get_child(0)
	var row_id: String = String(first_row.get_meta("row_id", ""))
	var target: Control = null
	if _choice_buttons.has(row_id):
		target = (_choice_buttons[row_id] as Dictionary).get(_choice_values.get(row_id), null)
	if target == null:
		target = _first_focusable(first_row)
	if target != null and target.is_inside_tree():
		target.grab_focus()


static func _first_focusable(node: Node) -> Control:
	for child: Node in node.get_children():
		var control := child as Control
		if control != null and control.visible and control.focus_mode != Control.FOCUS_NONE:
			return control
		var nested: Control = _first_focusable(child)
		if nested != null:
			return nested
	return null


# =============================================================================
# INTERNAL
# =============================================================================

func _get_camera() -> CameraController:
	# The options panel lives in HUDViewport; the world camera is in the root
	# viewport. Route through SceneRouter so we don't end up looking at the
	# wrong viewport.
	return SceneRouter.get_world_camera() as CameraController


func _clear_items() -> void:
	if _content_container == null:
		return
	for child: Node in _content_container.get_children():
		_content_container.remove_child(child)
		child.queue_free()
	_rows_area = null
	_tab_boxes.clear()
	_tab_buttons.clear()
	_choice_buttons.clear()
	_choice_values.clear()


func _ensure_border_overlay() -> void:
	if _border_overlay != null:
		return
	var ui_manager: Node = UIManager
	if ui_manager != null and ui_manager.has_method("create_fullscreen_border_overlay"):
		_border_overlay = ui_manager.create_fullscreen_border_overlay()
		if _border_overlay != null:
			add_child(_border_overlay)
