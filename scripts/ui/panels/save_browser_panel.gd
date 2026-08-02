## Save browser: every occupied slot across the three rings (battle-start,
## turn, manual), newest first, one click to load. Opened from the system
## menu's Load button; UIManager owns the load itself via the save_chosen
## signal, so this widget never touches disk beyond listing.
##
## Functionality-first scaffold (UI work order): plain rows wearing the slot
## color identity — RQD 2026-08-01: YELLOW = turn autosave, BLUE = battle-start
## autosave, plain text = manual (GameColors.SAVE_AUTO_*). Lawrence pass later.
class_name SaveBrowserPanel
extends PanelContainer


signal closed()
signal save_chosen(path: String)

const PANEL_MIN_WIDTH: int = 220
const ROW_HEIGHT: int = 14

var _content_container: VBoxContainer = null


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


func show_panel() -> void:
	_rebuild_rows()
	visible = true


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

	var ui_manager: Node = UIManager
	var title := Label.new()
	title.text = "LOAD GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	if ui_manager != null:
		title.add_theme_font_override("font", ui_manager.font_8px)
		title.add_theme_font_size_override("font_size", 8)
	_content_container.add_child(title)

	var saves: Array[Dictionary] = SaveManager.list_saves()
	if saves.is_empty():
		var empty := Label.new()
		empty.text = "No saves yet."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if ui_manager != null:
			empty.add_theme_font_override("font", ui_manager.font_5px)
			empty.add_theme_font_size_override("font_size", 5)
		_content_container.add_child(empty)
	for entry: Dictionary in saves:
		_content_container.add_child(_build_row(entry, ui_manager))

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	if ui_manager != null:
		close_button.add_theme_font_override("font", ui_manager.font_5px)
		close_button.add_theme_font_size_override("font_size", 5)
	close_button.pressed.connect(hide_panel)
	_content_container.add_child(close_button)


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
	row.pressed.connect(func() -> void: save_chosen.emit(str(entry.get("path", ""))))
	return row


static func _kind_color(kind: String) -> Color:
	match kind:
		SaveManager.KIND_AUTO_BATTLE:
			return GameColors.SAVE_AUTO_BATTLE
		SaveManager.KIND_AUTO_TURN:
			return GameColors.SAVE_AUTO_TURN
	return GameColors.TEXT_PRIMARY


static func _kind_display_name(kind: String) -> String:
	match kind:
		SaveManager.KIND_AUTO_BATTLE:
			return "Autosave — battle start"
		SaveManager.KIND_AUTO_TURN:
			return "Autosave — turn start"
	return "Manual save"


## "YYYY-MM-DDTHH:MM:SS" → "MM-DD HH:MM". Year and seconds are noise at the
## row scale; the full stamp lives in the file if anyone needs it.
static func _format_timestamp(unix: int) -> String:
	if unix <= 0:
		return ""
	return Time.get_datetime_string_from_unix_time(unix).substr(5, 11).replace("T", " ")
