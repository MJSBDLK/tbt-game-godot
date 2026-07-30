## Right-side system menu panel (like the action menu but for game-level actions).
## Appears when pressing Escape in DEFAULT state or tapping the menu button.
## Contains: Options, End Turn, Save, Load, Quit.
## Wears the border vocabulary (§14) since the 2026-07-19 adoption — all
## buttons are InteractiveButtons, focus is the cursor.
class_name SystemMenuPanel
extends PanelContainer


signal options_selected()
signal end_turn_selected()
signal save_selected()
signal load_selected()
signal quit_selected()
signal closed()

const BUTTON_HEIGHT: int = 14
# 140px column minus 13px margins each side (the +1 selector breathing room —
# at the old 116 the pinned buttons would silently widen the panel past 140).
const BUTTON_WIDTH: int = 114

var _content_container: VBoxContainer = null
var _border_overlay: PanelBorderOverlay = null


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
		hide_menu()
		get_viewport().set_input_as_handled()


# =============================================================================
# PUBLIC API
# =============================================================================

func show_menu() -> void:
	_populate_menu()
	visible = true
	_ensure_border_overlay()


func hide_menu() -> void:
	visible = false
	_clear_items()
	closed.emit()


# =============================================================================
# MENU POPULATION
# =============================================================================

func _populate_menu() -> void:
	_clear_items()

	_create_end_turn_button()
	_create_spacer()
	_create_button("Options", func() -> void: options_selected.emit())
	_create_button("Save", func() -> void: save_selected.emit())
	_create_button("Load", func() -> void: load_selected.emit())
	_create_button("Quit", func() -> void: quit_selected.emit())
	_create_button("Close", func() -> void: hide_menu())

	_resize_panel()
	_focus_first_item()


const END_TURN_BUTTON_HEIGHT: int = 22


# =============================================================================
# BUTTON BUILDING
# =============================================================================

func _create_end_turn_button() -> InteractiveButton:
	# Vocabulary End Turn: a plain lit button, taller for prominence. The old
	# magenta accent died with adoption — magenta belongs to SPECIAL damage
	# now (§14), and the mockup's End Turn is a standard vocabulary button.
	# call_to_action stays UNWIRED on purpose: TurnManager auto-ends the
	# phase when every unit has acted, so "all acted" can never light this.
	# When a real trigger exists (tutorial hint, auto-end setting), it's one
	# line: button.call_to_action = true.
	var button := InteractiveButton.new()
	button.text = "END TURN"
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, END_TURN_BUTTON_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.pressed.connect(func() -> void: end_turn_selected.emit())
	button.focus_entered.connect(_on_item_focused.bind(button))
	_content_container.add_child(button)
	return button


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
	button.pressed.connect(callback)
	button.focus_entered.connect(_on_item_focused.bind(button))
	_content_container.add_child(button)
	return button


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
func _focus_first_item() -> void:
	_grab_first_focus.call_deferred()


func _grab_first_focus() -> void:
	if _content_container == null or _content_container.get_child_count() == 0:
		return
	var first := _content_container.get_child(0) as Control
	if first != null and first.is_inside_tree():
		first.grab_focus()


func _clear_items() -> void:
	if _content_container == null:
		return
	for child: Node in _content_container.get_children():
		_content_container.remove_child(child)
		child.queue_free()


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
