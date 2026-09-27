## Right-side system menu panel (like the action menu but for game-level actions).
## Appears when pressing Escape in DEFAULT state or tapping the menu button.
## Contains: End Turn, then Close, Options, Save, Load, Main Menu, Quit.
## Close sits FIRST under End Turn and is the cursor's default landing: the
## most common reason to open this menu is to peek and leave, and a default on
## End Turn let controller A-A end the turn by accident. Wears the border
## vocabulary (§14) — all buttons are InteractiveButtons, focus is the cursor.
##
## Second page: the End Turn warning (show_end_turn_confirm, opened by
## UIManager.request_end_turn when units can still act). "N units haven't
## acted." over End Turn / Cancel, Cancel the landing for the same A-A
## reason. Cancel goes back where the player came from: the menu list if it
## was open, the board if the E key / hint bar asked. The camera frames the
## waiting units beside the panel; Cancel glides it back to the view it had —
## the press asked the question, backing out undoes what it moved.
##
## Options, Save and Load run here, with the save browser UIManager hands
## over (attach_save_browser). End Turn, Main Menu and Quit signal UIManager:
## End Turn shares the E key's path, the other two leave the battle.
class_name SystemMenuPanel
extends PanelContainer


signal end_turn_selected()
## End Turn pressed on the warning page — the player meant it.
signal end_turn_confirmed()
## Leave the battle for the start screen (RQD 2026-08-16). Sits beside Quit
## and, like Quit, doesn't confirm — the turn autosave ring means at most the
## current turn is lost, and neither the hub's Quit to Menu nor Quit here asks.
signal main_menu_selected()
signal quit_selected()
signal closed()

const BUTTON_HEIGHT: int = 14
# 140px column minus 13px margins each side (the +1 selector breathing room —
# at the old 116 the pinned buttons would silently widen the panel past 140).
const BUTTON_WIDTH: int = 114

var _content_container: VBoxContainer = null
var _border_overlay: PanelBorderOverlay = null
var _save_button: InteractiveButton = null
# The cursor's default landing — see the header. Rebuilt on every populate.
var _close_button: InteractiveButton = null
# Bumped on every flash so an older restore-timer can't clobber a newer flash.
var _save_flash_serial: int = 0
var _confirming_end_turn: bool = false
var _cancel_returns_to_menu: bool = false
var _waiting_flashes: Array[SilhouetteCallToAction] = []
# CameraController.current_view() from before the framing; empty = nothing to undo.
var _view_before_question: Dictionary = {}
var _save_browser: SaveBrowserPanel = null


func _ready() -> void:
	custom_minimum_size = Vector2(140, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Transparent panel — we draw our own inset background to avoid
	# the dark bg peeking outside the border's rounded corners.
	var panel_style := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", panel_style)

	# Inset background (5px from each edge = midpoint of 10px border)
	# Uses a Panel with rounded corners so it doesn't peek past the border.
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

	# Margins: 12px left/right with 116px buttons = 140px panel
	var margin := MarginContainer.new()
	# +1 on every side (RQD 2026-07-29, matching the action menu): breathing
	# room for the selector — bracket arms reach up to 3px past the focused
	# item's rect.
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_right", 13)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_bottom", 32)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 2)
	margin.add_child(_content_container)

	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _confirming_end_turn:
			_cancel_end_turn_confirm()
		else:
			hide_menu()
		get_viewport().set_input_as_handled()
		return
	# Quiet-open adoption (InputSource, RQD 2026-07-29): a pointer-opened
	# menu has no cursor — the first navigation press summons it onto the
	# default item (Close) instead of falling on deaf ears.
	if InputSource.is_navigation_press(event) \
			and get_viewport().gui_get_focus_owner() == null:
		_focus_default_item()
		get_viewport().set_input_as_handled()


# =============================================================================
# PUBLIC API
# =============================================================================

func show_menu() -> void:
	_end_question()
	_populate_menu()
	visible = true
	_ensure_border_overlay()


func hide_menu() -> void:
	visible = false
	_end_question()
	_clear_items()
	closed.emit()


## The page names how many can still act, and each of them flashes its
## outline (SilhouetteCallToAction) for exactly as long as the question is
## up: show_menu and hide_menu — every way off this page — stop them.
func show_end_turn_confirm(waiting: Array[Unit]) -> void:
	_cancel_returns_to_menu = visible and not _confirming_end_turn
	_end_question()
	_confirming_end_turn = true
	for unit: Unit in waiting:
		var flash := SilhouetteCallToAction.play_on(unit.get_node_or_null("Sprite2D") as Sprite2D)
		if flash != null:
			_waiting_flashes.append(flash)
	_clear_items()
	var message := GlowLabel.styled(("1 unit hasn't acted." if waiting.size() == 1
			else "%d units haven't acted." % waiting.size()),
			UIManager.font_8px, 8, GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW)
	message.custom_minimum_size = Vector2(BUTTON_WIDTH, 0)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_container.add_child(message)
	_create_spacer()
	_create_button("End Turn", func() -> void: end_turn_confirmed.emit())
	_close_button = _create_button("Cancel", _cancel_end_turn_confirm)
	_resize_panel()
	visible = true
	_ensure_border_overlay()
	_frame_waiting(waiting)
	if InputSource.is_cursor_driven():
		_focus_default_item()


## Every waiting unit on screen, clear of this panel's column. Called once
## the panel is placed and sized — the column is its footprint.
func _frame_waiting(waiting: Array[Unit]) -> void:
	var camera := SceneRouter.get_world_camera() as CameraController
	if camera == null or waiting.is_empty():
		return
	var points := PackedVector2Array()
	for unit: Unit in waiting:
		points.append(unit.global_position)
	var view_size := camera.get_viewport_rect().size
	var column := maxf(size.x, custom_minimum_size.x) * SceneRouter.get_hud_scale()
	var on_left := anchor_left < 0.5
	var free_region := Rect2(column if on_left else 0.0, 0.0, view_size.x - column, view_size.y)
	_view_before_question = camera.current_view()
	camera.frame_points(points, free_region)


func _cancel_end_turn_confirm() -> void:
	var camera := SceneRouter.get_world_camera() as CameraController
	if camera != null and not _view_before_question.is_empty():
		camera.return_to_view(_view_before_question)
	if _cancel_returns_to_menu:
		show_menu()
	else:
		hide_menu()


## Every way off the question comes through here: the flashes stop and the
## framing's view is forgotten — only Cancel goes back to it, before this runs.
func _end_question() -> void:
	_confirming_end_turn = false
	_view_before_question = {}
	# Untyped on purpose: a unit freed mid-question leaves a freed flash here,
	# and a typed loop variable refuses a freed instance.
	for flash: Variant in _waiting_flashes:
		if is_instance_valid(flash):
			flash.queue_free()
	_waiting_flashes.clear()


# =============================================================================
# MENU POPULATION
# =============================================================================

func _populate_menu() -> void:
	_clear_items()

	_create_end_turn_button()
	_create_spacer()
	# Close leads the list (RQD 2026-08-21) — see the header for why.
	_close_button = _create_button("Close", func() -> void: hide_menu())
	_create_button("Options", _open_options)
	_save_button = _create_button("Save", _save)
	_create_button("Load", _open_load)
	_create_button("Main Menu", func() -> void: main_menu_selected.emit())
	_create_button("Quit", func() -> void: quit_selected.emit())

	_resize_panel()
	# Default selection is a CURSOR-model courtesy (controller/keyboard needs
	# a starting point). Under pointer input it reads as a phantom "you are
	# here" nobody put there — open quiet; the first nav press adopts focus.
	# The landing is Close, not End Turn: a safe default for a stray accept.
	if InputSource.is_cursor_driven():
		_focus_default_item()


const END_TURN_BUTTON_HEIGHT: int = 22


## Pins the panel's outer corner to the top of one screen edge; it grows
## inward to fit its content — no hardcoded width. UIManager picks the side
## (the action panels' side, away from the unit in play).
func pin_to_side(on_left: bool) -> void:
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_top = 0
	offset_bottom = 0
	offset_left = 0
	offset_right = 0
	if on_left:
		anchor_left = 0.0
		anchor_right = 0.0
		grow_horizontal = Control.GROW_DIRECTION_END
	else:
		anchor_left = 1.0
		anchor_right = 1.0
		grow_horizontal = Control.GROW_DIRECTION_BEGIN


# =============================================================================
# OPTIONS / SAVE / LOAD
# =============================================================================
# Opening Options or the save browser hides this panel WITHOUT `closed`: the
# game stays PAUSED under them, and their close brings the menu back.

## UIManager builds the browser in its overlay layer (centered, like Options)
## and hands it over; this menu is its only opener.
func attach_save_browser(browser: SaveBrowserPanel) -> void:
	assert(_save_browser == null, "SystemMenuPanel: the save browser is attached once")
	_save_browser = browser
	browser.closed.connect(_on_save_browser_closed)
	browser.save_chosen.connect(_on_save_chosen)
	browser.slot_chosen.connect(_on_overwrite_slot_chosen)


func _open_options() -> void:
	visible = false
	UIManager.show_options_menu()  # its close lands in UIManager._on_options_menu_closed


## A free manual slot: silent write, the Save row itself flashes the outcome.
## Ring full: the press would destroy a save the player asked to keep, so the
## overwrite picker takes over and the write lands in _on_overwrite_slot_chosen.
func _save() -> void:
	if SaveManager.find_free_manual_slot().is_empty():
		assert(_save_browser != null, "SystemMenuPanel: Save on a full ring needs the save browser")
		visible = false
		_save_browser.show_overwrite_picker()
		return
	flash_save_result(not SaveManager.write_manual_save().is_empty())


func _open_load() -> void:
	assert(_save_browser != null, "SystemMenuPanel: Load needs the save browser")
	visible = false
	_save_browser.show_panel()


func _on_overwrite_slot_chosen(path: String) -> void:
	var written: String = SaveManager.write_manual_save_to(path)
	# hide_panel emits closed, which brings this menu back (still PAUSED) —
	# then the Save row flashes on the rebuilt menu.
	_save_browser.hide_panel()
	if visible:
		flash_save_result(not written.is_empty())


## Back to this menu — only while still PAUSED: a chosen save changes scene
## and resets state, and the menu must not rise over the load.
func _on_save_browser_closed() -> void:
	if GameStateManager.current_state == Enums.InputState.PAUSED:
		show_menu()


func _on_save_chosen(path: String) -> void:
	# Hidden WITHOUT closed (hide_panel would bring this menu back over the
	# scene change); load_save_and_continue routes from here.
	_save_browser.visible = false
	if not SaveManager.load_save_and_continue(path):
		push_warning("SystemMenuPanel: failed to load save '%s'" % path)
		_save_browser.show_panel()


# =============================================================================
# BUTTON BUILDING
# =============================================================================

## Flashes the save outcome ON the Save row itself — the menu stays open, so
## the button the player just pressed is the feedback venue. Restores the
## label after a beat; the serial guards against an older timer clobbering a
## rapid re-save's flash.
func flash_save_result(success: bool) -> void:
	if _save_button == null:
		return
	_save_flash_serial += 1
	var serial: int = _save_flash_serial
	_save_button.text = "Saved!" if success else "Save FAILED"
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(_save_button) and serial == _save_flash_serial:
		_save_button.text = "Save"


func _create_end_turn_button() -> InteractiveButton:
	# Vocabulary End Turn: a plain lit button, taller for prominence. The old
	# magenta accent died with adoption — magenta belongs to SPECIAL damage
	# now (§14), and the mockup's End Turn is a standard vocabulary button.
	var button := InteractiveButton.new()
	button.text = "END TURN"
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, END_TURN_BUTTON_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The CTA's long-promised trigger (wired 2026-07-29 with the auto-end-turn
	# Options toggle): a SPENT phase — every unit acted, phase waiting. Only
	# reachable with auto-end off; with it on, TurnManager ends the phase
	# before this state could ever be seen. Computed at populate: the menu
	# rebuilds on every open, and input is locked while it's up.
	button.call_to_action = _end_turn_wants_attention()
	button.pressed.connect(func() -> void: end_turn_selected.emit())
	button.focus_entered.connect(_on_item_focused.bind(button))
	_content_container.add_child(button)
	return button


func _end_turn_wants_attention() -> bool:
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager == null or not turn_manager.is_player_phase():
		return false
	# Empty roster guard: outside battle the phase defaults to PLAYER and
	# all_player_units_acted() is vacuously true — no units, no invitation.
	if turn_manager.get_player_units().is_empty():
		return false
	return turn_manager.all_player_units_acted()


func _create_spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_container.add_child(spacer)


func _create_button(text: String, callback: Callable) -> InteractiveButton:
	var button := InteractiveButton.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	button.pressed.connect(func() -> void:
		# Godot natively focuses any clicked button, which routes through
		# _on_item_focused and hangs the §14 brackets on it. Under the POINTER
		# model that's a phantom cursor nobody summoned (InputSource doctrine:
		# pointer opens quiet) — invisible historically because every item
		# closed the menu on press; Save, the first stay-open item, exposed it
		# (RQD 2026-08-01). Cursor-model presses keep their "you are here."
		if not InputSource.is_cursor_driven():
			button.release_focus()
			_clear_selection_marks()
		callback.call())
	button.focus_entered.connect(_on_item_focused.bind(button))
	_content_container.add_child(button)
	return button


func _clear_selection_marks() -> void:
	for child: Node in _content_container.get_children():
		var item := child as InteractiveButton
		if item != null:
			item.selected = false


# =============================================================================
# CURSOR — focus is "you are here"; the brackets follow it (§14 selected)
# =============================================================================

func _on_item_focused(item: InteractiveButton) -> void:
	for child: Node in _content_container.get_children():
		var button := child as InteractiveButton
		if button != null:
			button.selected = (button == item)


## Deferred and re-resolved at fire time (same guard as ActionMenuPanel):
## the item the grab was queued for can be freed by a repopulate.
func _focus_default_item() -> void:
	_grab_default_focus.call_deferred()


## Close is the landing; End Turn (child 0) is the fallback only if Close
## somehow wasn't built — it always is, so the fallback is a belt-and-braces
## guard, not a path.
func _grab_default_focus() -> void:
	if _content_container == null or _content_container.get_child_count() == 0:
		return
	var target: Control = _close_button
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		target = _content_container.get_child(0) as Control
	if target != null and target.is_inside_tree():
		target.grab_focus()


func _clear_items() -> void:
	if _content_container == null:
		return
	for child: Node in _content_container.get_children():
		_content_container.remove_child(child)
		child.queue_free()
	_close_button = null
	_save_button = null


func _resize_panel() -> void:
	custom_minimum_size.y = 0
	await get_tree().process_frame
	var item_count := _content_container.get_child_count()
	var total_height := item_count * (BUTTON_HEIGHT + 2) + 26  # margins (13 top + 13 bottom)
	custom_minimum_size.y = total_height


func _ensure_border_overlay() -> void:
	if _border_overlay != null:
		return
	var ui_manager: Node = UIManager
	if ui_manager != null and ui_manager.has_method("create_fullscreen_border_overlay"):
		_border_overlay = ui_manager.create_fullscreen_border_overlay()
		if _border_overlay != null:
			add_child(_border_overlay)
