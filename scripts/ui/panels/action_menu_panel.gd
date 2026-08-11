## Scene-based action menu panel for the right side.
## The first real menu wearing the border vocabulary (ui-style-guide.md §14):
## move chips are MoveChipButtons, text actions are InteractiveButtons — the
## exact components the F6 gallery rehearsed (Lawrence: "cramped but
## organized", accepted 2026-07-19). Focus is the menu cursor: brackets
## follow it; the assigned move carries the border-ramp orbit (marker hunt
## revival, RQD 2026-07-26 — parked brackets retired with it). A chip holding
## attention (focus or hover) live-paints its reach on the grid via
## GridManager.display_move_range_preview (RQD 2026-07-30).
## Signals back to ActionMenuManager for business logic.
class_name ActionMenuPanel
extends PanelContainer


signal move_selected(move: Move)
signal wait_selected()
signal cancel_selected()
signal assign_submenu_requested()
signal assign_move_selected(move: Move)
signal unit_info_requested()

const BUTTON_HEIGHT: int = 14
const BUTTON_WIDTH: int = 120
const CHIP_HEIGHT: int = 14

var _content_container: VBoxContainer = null
var _is_assign_submenu: bool = false
var _active_unit: Unit = null
var _border_overlay: PanelBorderOverlay = null


func _ready() -> void:
	custom_minimum_size = Vector2(140, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Transparent panel — the tint is an inset child, NOT the stylebox: a
	# full-rect square fill peeked past the border overlay's rounded corners
	# (RQD 2026-07-29; same fix the system menu ships). Content stays inset
	# via the MarginContainer.
	var panel_style := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", panel_style)

	# Inset background (5px from each edge = midpoint of the 10px border
	# art) with rounded corners, so the tint stays tucked under the border.
	var background := Panel.new()
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = GameColors.HUD_PANEL_BACKGROUND
	background_style.set_corner_radius_all(5)
	background.add_theme_stylebox_override("panel", background_style)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.offset_left = 5
	background.offset_right = -5
	background.offset_top = 5
	background.offset_bottom = -5
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	# +1 on every side (RQD 2026-07-29): breathing room for the selector —
	# the focused item's bracket arms reach up to 3px past its rect.
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


# =============================================================================
# PUBLIC API
# =============================================================================

func show_menu(unit: Unit) -> void:
	if unit == null:
		return
	_active_unit = unit
	_is_assign_submenu = false
	_populate_main_menu(unit)
	visible = true
	_ensure_border_overlay()


func hide_menu() -> void:
	visible = false
	_clear_items()
	_active_unit = null


func get_active_unit() -> Unit:
	return _active_unit


func is_assign_submenu() -> bool:
	return _is_assign_submenu


func show_assign_submenu() -> void:
	if _active_unit != null:
		_populate_assign_submenu(_active_unit)


func show_main_menu() -> void:
	if _active_unit != null:
		_is_assign_submenu = false
		_populate_main_menu(_active_unit)


# =============================================================================
# MENU POPULATION
# =============================================================================

func _populate_main_menu(unit: Unit) -> void:
	_clear_items()

	# Moves, per the §7/§14 gameplay rules: out-of-range HIDDEN, depleted
	# GRAYED (disabled tier, press explains why), VOID-locked grayed with the
	# lock scrim so the player sees what the lock took away.
	var data: CharacterData = unit.character_data
	var equipped: Array[Move] = data.equipped_moves if data != null else []
	for i: int in range(equipped.size()):
		var move: Move = equipped[i]
		if move == null:
			continue
		var captured_move := move
		if unit.is_move_index_locked(i):
			_create_move_chip(captured_move, false, Callable(), true)
			continue
		if MoveTargeting.get_valid_target_tiles(unit, move).size() == 0:
			continue  # out of range: hidden
		if not move.has_uses_remaining():
			_create_move_chip(captured_move, false, Callable())  # depleted: grayed
			continue
		var is_assigned := (unit.assigned_move == move)
		_create_move_chip(captured_move, is_assigned,
				func() -> void: move_selected.emit(captured_move))

	# Text buttons for non-move actions.
	_create_button("Unit Info", func() -> void: unit_info_requested.emit())
	_create_button("Assign Move", func() -> void: assign_submenu_requested.emit())
	_create_button("Wait", func() -> void: wait_selected.emit())
	_create_button("Cancel", func() -> void: cancel_selected.emit())

	_resize_panel()
	_focus_when_cursor_driven()


func _populate_assign_submenu(unit: Unit) -> void:
	_clear_items()
	_is_assign_submenu = true

	var data: CharacterData = unit.character_data
	var equipped: Array[Move] = data.equipped_moves if data != null else []
	for i: int in range(equipped.size()):
		var move: Move = equipped[i]
		if move == null:
			continue
		var captured_move := move
		if unit.is_move_index_locked(i):
			_create_move_chip(captured_move, false, Callable(), true)
		elif not move.has_uses_remaining():
			# Depleted: grayed, not hidden — assigning it would be pointless
			# and the deny says why.
			_create_move_chip(captured_move, false, Callable())
		else:
			var is_assigned := (unit.assigned_move == move)
			_create_move_chip(captured_move, is_assigned,
					func() -> void: assign_move_selected.emit(captured_move))

	_create_button("Back", func() -> void:
		_is_assign_submenu = false
		_populate_main_menu(unit))

	_resize_panel()
	_focus_when_cursor_driven()


# =============================================================================
# MOVE CHIP BUILDING
# =============================================================================

func _create_move_chip(move: Move, is_assigned: bool, callback: Callable, locked: bool = false) -> MoveChipButton:
	var chip_button := MoveChipButton.new()
	chip_button.custom_minimum_size = Vector2(BUTTON_WIDTH, CHIP_HEIGHT)
	if callback.is_valid():
		chip_button.pressed.connect(callback)
	# Disabled chips (depleted/locked) refuse with a reason instead of dying
	# silently — §14 press-for-why. setup() decides disabled from the move.
	chip_button.denied.connect(_on_chip_denied.bind(chip_button))
	chip_button.focus_entered.connect(_on_item_focused.bind(chip_button))
	# Grid live-paint: attention on a chip (focus OR hover) paints its reach.
	chip_button.focus_entered.connect(_on_chip_attention_gained.bind(chip_button))
	chip_button.mouse_entered.connect(_on_chip_attention_gained.bind(chip_button))
	chip_button.focus_exited.connect(_on_chip_attention_lost)
	chip_button.mouse_exited.connect(_on_chip_attention_lost)
	_content_container.add_child(chip_button)
	chip_button.setup(move, is_assigned, locked)
	return chip_button


# =============================================================================
# BUTTON BUILDING
# =============================================================================

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


# =============================================================================
# GRID LIVE-PAINT — the chip is a mnemonic, the board is the truth
# =============================================================================

## Whichever chip holds attention paints its move's reach footprint on the
## actual grid (RQD 2026-07-30). Attention = focus under the cursor model,
## hover under pointer — the same two channels the backlight answers to, so
## the lit chip and the painted board always agree. Depleted and locked chips
## paint too: range is a fact of the move, not an affordance. Text actions
## carry no move, so focus moving onto them lets the paint clear.
func _on_chip_attention_gained(chip: MoveChipButton) -> void:
	if visible and _active_unit != null and chip.get_move() != null:
		GridManager.display_move_range_preview(_active_unit, chip.get_move())


## Loss re-derives DEFERRED: focus hopping chip-to-chip fires exited before
## the next entered, and an immediate clear would flash the board between
## adjacent chips. After the dust settles, whichever chip still holds
## attention (focus preferred, else hover) repaints; none = clear.
func _on_chip_attention_lost() -> void:
	_rederive_range_paint.call_deferred()


func _rederive_range_paint() -> void:
	if not visible or _active_unit == null:
		GridManager.clear_move_range_preview()
		return
	var attended := _attended_chip()
	if attended != null:
		GridManager.display_move_range_preview(_active_unit, attended.get_move())
	else:
		GridManager.clear_move_range_preview()


func _attended_chip() -> MoveChipButton:
	var hovered: MoveChipButton = null
	for child: Node in _content_container.get_children():
		var chip := child as MoveChipButton
		if chip == null:
			continue
		if chip.has_focus():
			return chip
		if chip.is_hovered():
			hovered = chip
	return hovered


## Default selection is a CURSOR-model courtesy (InputSource, RQD 2026-07-29):
## controller/keyboard needs a starting point; under pointer input it reads
## as a phantom "you are here" nobody put there. Pointer opens quiet, and the
## first navigation press adopts focus (see _unhandled_input). A submenu
## opened BY a press inherits the right answer for free — the opening press
## itself set InputSource's model.
func _focus_when_cursor_driven() -> void:
	if InputSource.is_cursor_driven():
		_focus_first_item()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# Quiet-open adoption: a pointer-opened menu has no cursor — the first
	# navigation press summons it onto the first item.
	if InputSource.is_navigation_press(event) \
			and get_viewport().gui_get_focus_owner() == null:
		_focus_first_item()
		get_viewport().set_input_as_handled()


## The cursor opens on the first item — matters most on controller, where
## the traveling focus IS the pointer (Steam Deck primary target).
## Deferred AND re-resolved at fire time: a repopulate (main -> submenu) can
## free the item the grab was queued for, so the deferred call must look up
## whatever is first NOW, not hold a reference from populate time.
func _focus_first_item() -> void:
	_grab_first_focus.call_deferred()


func _grab_first_focus() -> void:
	if _content_container == null or _content_container.get_child_count() == 0:
		return
	var first := _content_container.get_child(0) as Control
	if first != null and first.is_inside_tree():
		first.grab_focus()


func _on_chip_denied(chip: MoveChipButton) -> void:
	DenyTooltip.show_above(chip, chip.disabled_reason)


func _clear_items() -> void:
	if _content_container == null:
		return
	# Every repopulate (and hide) drops the live-paint with the chips that drove
	# it; the next attention event repaints. Cursor-driven opens repaint on the
	# same frame their first chip grabs focus.
	GridManager.clear_move_range_preview()
	for child: Node in _content_container.get_children():
		_content_container.remove_child(child)
		child.queue_free()


func _resize_panel() -> void:
	# Reset minimum so the panel can shrink when content is smaller.
	custom_minimum_size.y = 0
	await get_tree().process_frame
	var item_count := _content_container.get_child_count()
	var total_height := item_count * (CHIP_HEIGHT + 2) + 26  # margins (13 top + 13 bottom)
	custom_minimum_size.y = total_height


func _ensure_border_overlay() -> void:
	if _border_overlay != null:
		return
	var ui_manager: Node = UIManager
	if ui_manager == null:
		return
	_border_overlay = ui_manager.create_fullscreen_border_overlay()
	if _border_overlay != null:
		add_child(_border_overlay)
