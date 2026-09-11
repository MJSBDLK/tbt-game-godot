## Save browser, two modes on one panel:
##   LOAD    — every occupied slot across the four rings, newest first, one
##             click to load (save_chosen). Opened from the system menu's Load
##             button and the start screen's Load Game.
##   OVERWRITE — the four MANUAL slots in slot order, empty ones included, one
##             click to name the slot a manual save should land in
##             (slot_chosen). Opened by a Save press when the manual ring is
##             full — the only time a manual save would destroy something.
## The owner does the disk work off the signal; this widget never touches disk
## beyond listing.
##
## Functionality-first scaffold (UI work order): plain rows wearing the slot
## color identity — YELLOW = turn autosave, BLUE = battle-start autosave,
## GREEN = base autosave (placeholder), plain text = manual
## (GameColors.SAVE_AUTO_*). Lawrence pass later.
class_name SaveBrowserPanel
extends PanelContainer


signal closed()
signal save_chosen(path: String)
signal slot_chosen(path: String)

enum Mode { LOAD, OVERWRITE }

const PANEL_MIN_WIDTH: int = 220
const ROW_HEIGHT: int = 14

var mode: Mode = Mode.LOAD

var _content_container: VBoxContainer = null
var _row_buttons: Array[Button] = []


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_MIN_WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	# Same inset-background recipe as the options/system menus.
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
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

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_right", 13)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 3)
	margin.add_child(_content_container)


## LOAD mode: list everything loadable.
func show_panel() -> void:
	mode = Mode.LOAD
	_rebuild_rows()
	visible = true
	_focus_first_row_if_cursor_driven()


## OVERWRITE mode: the four manual slots. Called when a manual save found no
## free slot; the chosen slot comes back on slot_chosen, a cancel on closed.
func show_overwrite_picker() -> void:
	mode = Mode.OVERWRITE
	_rebuild_rows()
	visible = true
	_focus_first_row_if_cursor_driven()


func hide_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_panel()


## Rows rebuild on every open — saves change between visits.
func _rebuild_rows() -> void:
	for child: Node in _content_container.get_children():
		child.queue_free()
	_row_buttons.clear()

	var ui_manager: Node = UIManager
	var title := Label.new()
	title.text = "LOAD GAME" if mode == Mode.LOAD else "OVERWRITE WHICH SAVE?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	if ui_manager != null:
		title.add_theme_font_override("font", ui_manager.font_8px)
		title.add_theme_font_size_override("font_size", 8)
	_content_container.add_child(title)

	if mode == Mode.LOAD:
		_build_load_rows(ui_manager)
	else:
		_build_overwrite_rows(ui_manager)

	var close_button := Button.new()
	close_button.text = "Close" if mode == Mode.LOAD else "Cancel"
	close_button.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	if ui_manager != null:
		close_button.add_theme_font_override("font", ui_manager.font_5px)
		close_button.add_theme_font_size_override("font_size", 5)
	close_button.pressed.connect(hide_panel)
	_content_container.add_child(close_button)
	_row_buttons.append(close_button)


func _build_load_rows(ui_manager: Node) -> void:
	var saves: Array[Dictionary] = SaveManager.list_saves()
	if saves.is_empty():
		_content_container.add_child(_make_note("No saves yet.", ui_manager))
	for entry: Dictionary in saves:
		var row: Button = _build_row(entry, ui_manager)
		row.pressed.connect(func() -> void: save_chosen.emit(str(entry.get("path", ""))))
		_content_container.add_child(row)
		_row_buttons.append(row)


## All four manual slots, in slot order. An empty slot is offered too — the
## picker only opens when the ring is full, but a slot freed between the
## lookup and the open (another process, a deleted file) should still be the
## obvious choice rather than a hidden one.
func _build_overwrite_rows(ui_manager: Node) -> void:
	for entry: Dictionary in SaveManager.list_manual_slots():
		var row: Button
		if bool(entry.get("empty", false)):
			row = _build_empty_slot_row(int(entry.get("slot_index", 0)), ui_manager)
		else:
			row = _build_row(entry, ui_manager)
			if bool(entry.get("unreadable", false)):
				row.text = "Slot %d   (unreadable)" % (int(entry.get("slot_index", 0)) + 1)
		row.pressed.connect(func() -> void: slot_chosen.emit(str(entry.get("path", ""))))
		_content_container.add_child(row)
		_row_buttons.append(row)


func _build_row(entry: Dictionary, ui_manager: Node) -> Button:
	var kind: String = str(entry.get("kind", ""))
	var row := Button.new()
	row.text = "%s   %s" % [entry.get("label", "saved game"),
			_format_timestamp(int(entry.get("created_unix", 0)))]
	row.tooltip_text = _kind_display_name(kind)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	if ui_manager != null:
		row.add_theme_font_override("font", ui_manager.font_5px)
		row.add_theme_font_size_override("font_size", 5)
	var kind_color: Color = _kind_color(kind)
	row.add_theme_color_override("font_color", kind_color)
	row.add_theme_color_override("font_hover_color", kind_color.lightened(0.3))
	return row


func _build_empty_slot_row(slot_index: int, ui_manager: Node) -> Button:
	var row := Button.new()
	row.text = "Slot %d   (empty)" % (slot_index + 1)
	row.tooltip_text = "Empty manual slot"
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	if ui_manager != null:
		row.add_theme_font_override("font", ui_manager.font_5px)
		row.add_theme_font_size_override("font_size", 5)
	row.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	return row


func _make_note(text: String, ui_manager: Node) -> Label:
	var note := Label.new()
	note.text = text
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null:
		note.add_theme_font_override("font", ui_manager.font_5px)
		note.add_theme_font_size_override("font_size", 5)
	return note


## Cursor-model opens land the cursor on the first row so a pad can drive the
## list at all (plain Buttons have no other entry point); pointer opens stay
## quiet, per InputSource doctrine.
func _focus_first_row_if_cursor_driven() -> void:
	if _row_buttons.is_empty() or not InputSource.is_cursor_driven():
		return
	_row_buttons[0].grab_focus.call_deferred()


static func _kind_color(kind: String) -> Color:
	match kind:
		SaveManager.KIND_AUTO_BATTLE:
			return GameColors.SAVE_AUTO_BATTLE
		SaveManager.KIND_AUTO_TURN:
			return GameColors.SAVE_AUTO_TURN
		SaveManager.KIND_AUTO_BASE:
			return GameColors.SAVE_AUTO_BASE
	return GameColors.TEXT_PRIMARY


static func _kind_display_name(kind: String) -> String:
	match kind:
		SaveManager.KIND_AUTO_BATTLE:
			return "Autosave — battle start"
		SaveManager.KIND_AUTO_TURN:
			return "Autosave — turn start"
		SaveManager.KIND_AUTO_BASE:
			return "Autosave — between missions"
	return "Manual save"


## "YYYY-MM-DDTHH:MM:SS" → "MM-DD HH:MM". Year and seconds are noise at the
## row scale; the full stamp lives in the file if anyone needs it.
static func _format_timestamp(unix: int) -> String:
	if unix <= 0:
		return ""
	return Time.get_datetime_string_from_unix_time(unix).substr(5, 11).replace("T", " ")
