@tool
extends MarginContainer


const JSON_PATH: String = "res://data/type_chart.json"

const TYPES: Array[String] = [
	"Air", "Chivalric", "Cold", "Electric", "Fire", "Gentry", "Gravity",
	"Heraldic", "Occult", "Plant", "Robo", "Simple", "Void", "Obsidian"
]

const TYPE_ABBREVS: Array[String] = [
	"Air", "Chv", "Cld", "Elc", "Fir", "Gen", "Grv",
	"Her", "Occ", "Plt", "Rob", "Sim", "Vod", "Obs"
]

const CELL_SIZE := Vector2(50, 50)
const HEADER_WIDTH: float = 80.0

const COLOR_NORMAL := Color(0.75, 0.75, 0.75)
const COLOR_OUCH := Color(0.85, 0.25, 0.25)
const COLOR_RESIST := Color(0.3, 0.45, 0.8)
const COLOR_IMMUNE := Color(0.2, 0.2, 0.2)

const EFFECT_NEUTRAL: String = ""
const EFFECT_OUCH: String = "ouch"
const EFFECT_RESIST: String = "resist"
const EFFECT_IMMUNE: String = "immune"

const CYCLE_ORDER: Array[String] = [EFFECT_NEUTRAL, EFFECT_OUCH, EFFECT_RESIST, EFFECT_IMMUNE]

# "Attacking:Defending" -> stage string (one of vulnerable/resist/immune); only non-neutral entries
var _data: Dictionary = {}
# 14x14 array of cell PanelContainers
var _cells: Array[Array] = []
var _dirty: bool = false
var _status_label: Label = null
var _confirm_dialog: ConfirmationDialog = null


func _ready() -> void:
	_build_ui()
	_load_data()
	visibility_changed.connect(_on_visibility_changed)


func _build_ui() -> void:
	# Root margin
	add_theme_constant_override("margin_left", 8)
	add_theme_constant_override("margin_right", 8)
	add_theme_constant_override("margin_top", 8)
	add_theme_constant_override("margin_bottom", 8)

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	# Toolbar
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	vbox.add_child(toolbar)

	var title := Label.new()
	title.text = "Type Effectiveness Chart"
	var title_font_size_override := 16
	title.add_theme_font_size_override("font_size", title_font_size_override)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)

	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_save_data)
	toolbar.add_child(save_button)

	var clear_button := Button.new()
	clear_button.text = "Clear All"
	clear_button.pressed.connect(_on_clear_pressed)
	toolbar.add_child(clear_button)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.custom_minimum_size.x = 120
	toolbar.add_child(_status_label)

	# Confirmation dialog for Clear All
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.dialog_text = "Clear all type matchups? This sets everything to neutral."
	_confirm_dialog.confirmed.connect(_clear_all)
	add_child(_confirm_dialog)

	# Scroll area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	# Grid
	var type_count := TYPES.size()
	var grid := GridContainer.new()
	grid.columns = type_count + 1
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(grid)

	# Corner cell (empty)
	var corner := Control.new()
	corner.custom_minimum_size = Vector2(HEADER_WIDTH, CELL_SIZE.y)
	grid.add_child(corner)

	# Column headers (defending types)
	for col_index: int in range(type_count):
		var header := _create_header_cell(TYPE_ABBREVS[col_index], true)
		grid.add_child(header)

	# Data rows
	_cells.clear()
	for row_index: int in range(type_count):
		# Row header (attacking type)
		var row_header := _create_header_cell(TYPES[row_index], false)
		grid.add_child(row_header)

		var row_cells: Array = []
		for col_index: int in range(type_count):
			var cell := _create_data_cell(row_index, col_index)
			grid.add_child(cell)
			row_cells.append(cell)
		_cells.append(row_cells)


func _create_header_cell(text: String, is_column: bool) -> PanelContainer:
	var cell := PanelContainer.new()
	if is_column:
		cell.custom_minimum_size = CELL_SIZE
	else:
		cell.custom_minimum_size = Vector2(HEADER_WIDTH, CELL_SIZE.y)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.add_child(label)

	return cell


func _create_data_cell(row_index: int, col_index: int) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = CELL_SIZE

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_NORMAL
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	cell.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "·"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.add_child(label)

	cell.gui_input.connect(_on_cell_input.bind(row_index, col_index))
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return cell


func _on_cell_input(event: InputEvent, row_index: int, col_index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_cycle_cell(row_index, col_index)


func _cycle_cell(row_index: int, col_index: int) -> void:
	var key := _make_key(TYPES[row_index], TYPES[col_index])
	var current: String = _data.get(key, EFFECT_NEUTRAL)

	var cycle_index := CYCLE_ORDER.find(current)
	if cycle_index < 0:
		cycle_index = 0
	var next_index := (cycle_index + 1) % CYCLE_ORDER.size()
	var next_value: String = CYCLE_ORDER[next_index]

	if next_value == EFFECT_NEUTRAL:
		_data.erase(key)
	else:
		_data[key] = next_value

	_update_cell_visual(row_index, col_index)
	_mark_dirty()


func _update_cell_visual(row_index: int, col_index: int) -> void:
	var cell: PanelContainer = _cells[row_index][col_index]
	var key := _make_key(TYPES[row_index], TYPES[col_index])
	var value: String = _data.get(key, EFFECT_NEUTRAL)

	var style: StyleBoxFlat = cell.get_theme_stylebox("panel") as StyleBoxFlat
	var label: Label = cell.get_child(0) as Label

	match value:
		EFFECT_OUCH:
			style.bg_color = COLOR_OUCH
			label.text = "ouch"
			label.add_theme_color_override("font_color", Color.WHITE)
		EFFECT_RESIST:
			style.bg_color = COLOR_RESIST
			label.text = "rsst"
			label.add_theme_color_override("font_color", Color.WHITE)
		EFFECT_IMMUNE:
			style.bg_color = COLOR_IMMUNE
			label.text = "imm"
			label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_:
			style.bg_color = COLOR_NORMAL
			label.text = "·"
			label.remove_theme_color_override("font_color")


func _load_data() -> void:
	_data.clear()

	if not FileAccess.file_exists(JSON_PATH):
		push_warning("TypeChartEditor: File not found: %s" % JSON_PATH)
		_refresh_all_cells()
		return

	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	if file == null:
		push_warning("TypeChartEditor: Failed to open: %s" % JSON_PATH)
		_refresh_all_cells()
		return

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error("TypeChartEditor: JSON parse error: %s" % json.get_error_message())
		_refresh_all_cells()
		return

	var data: Dictionary = json.data
	var matchups: Array = data.get("matchups", [])
	for entry: Dictionary in matchups:
		var attacking: String = entry.get("attacking", "")
		var defending: String = entry.get("defending", "")
		var effect_key: String = entry.get("effect", "")
		if attacking == "" or defending == "" or effect_key == "":
			continue
		if effect_key != EFFECT_OUCH and effect_key != EFFECT_RESIST and effect_key != EFFECT_IMMUNE:
			push_warning("TypeChartEditor: skipping unknown effect '%s' on %s:%s" % [effect_key, attacking, defending])
			continue
		_data[_make_key(attacking, defending)] = effect_key

	_refresh_all_cells()
	_dirty = false
	_update_status("Loaded %d matchups" % _data.size())


func _save_data() -> void:
	# Build sorted matchups array
	var matchups: Array[Dictionary] = []
	var keys: Array = _data.keys()
	keys.sort()
	for key: String in keys:
		var parts := key.split(":")
		matchups.append({
			"attacking": parts[0],
			"defending": parts[1],
			"effect": _data[key]
		})

	var output := {
		"description": "Type effectiveness matchups. 'effect' is one of: ouch, resist, immune. Unlisted pairs are neutral. Multipliers derive from TYPE_COEFFICIENT in type_chart.gd.",
		"matchups": matchups
	}

	var file := FileAccess.open(JSON_PATH, FileAccess.WRITE)
	if file == null:
		push_error("TypeChartEditor: Failed to write: %s" % JSON_PATH)
		_update_status("Save failed!")
		return

	file.store_string(JSON.stringify(output, "\t"))
	file.close()

	# Notify Godot the file changed
	EditorInterface.get_resource_filesystem().scan()

	_dirty = false
	_update_status("Saved (%d matchups)" % matchups.size())


func _on_clear_pressed() -> void:
	_confirm_dialog.popup_centered()


func _clear_all() -> void:
	_data.clear()
	_refresh_all_cells()
	_mark_dirty()
	_update_status("Cleared all matchups")


func _refresh_all_cells() -> void:
	for row_index: int in range(TYPES.size()):
		for col_index: int in range(TYPES.size()):
			_update_cell_visual(row_index, col_index)


func _mark_dirty() -> void:
	_dirty = true
	_update_status("Unsaved changes")


func _update_status(text: String) -> void:
	if _status_label:
		_status_label.text = text


func _on_visibility_changed() -> void:
	if visible:
		_load_data()


func _make_key(attacking: String, defending: String) -> String:
	return attacking + ":" + defending
