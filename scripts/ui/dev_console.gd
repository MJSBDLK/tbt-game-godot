## The dev console: Quake's ` for this project. Its one job today is
## ArtVariables — type `shadow_ink_alpha 0.3` and every shadow on the board
## follows that frame, no F5. Lawrence's loop is the point (see the header of
## art_variables.gd); the command table is the seam for whatever a dev wants
## typed next.
##
## Lives in a CanvasLayer inside HUDViewport (mount), so it draws over every
## screen SceneRouter puts there and reads the keyboard through InputRouter
## like any HUD Control.
##
## OPEN MEANS THE GAME IS DEAF. The root Control spans the whole canvas and
## stops the mouse (the panel is a child), the key pipeline's leftovers are
## swallowed here (_unhandled_key_input — a half-typed "w" with Ctrl held is
## the instawin cheat), joypad events die in _input, and is_open() is the
## gate the three places that don't take events read: InputRouter (nothing
## reaches the world, motion included), InputManager's hover poll and
## CameraController's key pan — both poll Input, which ignores handled flags.
##
## execute() is the whole interpreter and takes no UI, so GUT drives it as a
## string in, string out.
class_name DevConsole
extends Control


const FONT_8PX: FontFile = preload("res://fonts/UndeadPixelLight8.ttf")
const HEIGHT: float = 150.0
const MARGIN: int = 4
const LAYER: int = 100  # above SceneRouter's HUD screens
const HISTORY_MAX: int = 50
const COLUMN_GAP: int = 12
# Tab-separated lines lay out as table rows (see _print_reply): the HUD font
# is proportional, so space-padding can't align a column. ASCII only — the
# font has no em dash or middle dot, and a fallback glyph is a taller line.
const HELP_TEXT := """NAME	show a knob
NAME VALUE	set it, takes effect now
list	every knob, and what the file says where they differ
reset [NAME]	back to the file
dump	changed knobs as file lines, copied to the clipboard
clear	empty the log
Tab completes a name, Up/Down recall a line, ` or Esc closes"""

# The mounted one; is_open() follows it and forgets it when freed.
static var _active: DevConsole = null

var _log: RichTextLabel = null
var _prompt: LineEdit = null
var _history: PackedStringArray = []
var _history_cursor: int = 0
var _entries: int = 0


## Put a console over the HUD. Gated by the caller (DebugConfig.cheats_enabled).
static func mount(hud_viewport: SubViewport) -> DevConsole:
	var layer := CanvasLayer.new()
	layer.name = "DevConsoleLayer"
	layer.layer = LAYER
	var console := DevConsole.new()
	console.name = "DevConsole"
	layer.add_child(console)
	hud_viewport.add_child(layer)
	return console


## True while a console is up — the gate for everything that must not react
## to input under it.
static func is_open() -> bool:
	return is_instance_valid(_active) and _active.visible


func _ready() -> void:
	_active = self
	# The root is the whole canvas: a click anywhere outside the panel lands
	# here and goes no further. Anchors on an already-parented Control: the
	# offsets preset, or it stays 0×0 (HintBar shipped invisible over this).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var panel := Control.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = HEIGHT  # not size: anchored Controls take their rect from offsets
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var backdrop := ColorRect.new()
	backdrop.color = GameColors.HUD_PANEL_BACKGROUND
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, MARGIN)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	margin.add_child(column)

	_log = RichTextLabel.new()
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_override("normal_font", FONT_8PX)
	_log.add_theme_font_size_override("normal_font_size", 8)
	_log.add_theme_color_override("default_color", GameColors.TEXT_PRIMARY)
	column.add_child(_log)

	_prompt = LineEdit.new()
	_prompt.placeholder_text = "help"
	_prompt.add_theme_font_override("font", FONT_8PX)
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	_prompt.add_theme_color_override("caret_color", GameColors.TEXT_PRIMARY)
	# Godot's stock LineEdit is rounded and padded — wrong on a pixel HUD. A
	# flat 1px box, lit on focus.
	_prompt.add_theme_stylebox_override("normal", _prompt_box(GameColors.TEXT_PRIMARY_GLOW))
	_prompt.add_theme_stylebox_override("focus", _prompt_box(GameColors.TEXT_SECONDARY))
	_prompt.text_submitted.connect(_on_submitted)
	_prompt.gui_input.connect(_on_prompt_gui_input)
	column.add_child(_prompt)


static func _prompt_box(border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = GameColors.UI_BACKDROP
	box.border_color = border
	box.set_border_width_all(1)
	box.set_content_margin_all(2)
	return box


# =============================================================================
# OPEN / CLOSE
# =============================================================================

func _input(event: InputEvent) -> void:
	if visible and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		get_viewport().set_input_as_handled()  # no pad path yet; nothing under us gets it
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_QUOTELEFT or key.keycode == KEY_ASCIITILDE:
		if DebugConfig.cheats_enabled:
			toggle()
			get_viewport().set_input_as_handled()
	elif visible and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


## Keys the prompt didn't take stop here, before any HUD panel's
## _unhandled_input and before the root ever sees them.
func _unhandled_key_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	_history_cursor = _history.size()
	_prompt.clear()
	_prompt.grab_focus()


func close() -> void:
	visible = false
	_prompt.release_focus()


# =============================================================================
# PROMPT
# =============================================================================

func _on_submitted(line: String) -> void:
	_prompt.clear()
	if line.strip_edges() == "":
		return
	if line.strip_edges().to_lower() == "clear":
		_log.clear()
		_entries = 0
		return
	if _entries > 0:
		_log.add_text("\n")  # a breath between entries
	_entries += 1
	_print("> " + line, GameColors.TEXT_SECONDARY)
	var reply := execute(line)
	if reply != "":
		_print_reply(reply, GameColors.TEXT_WARNING if reply.begins_with("unknown") \
				or reply.contains("can't") else GameColors.TEXT_PRIMARY)
	_remember(line)


func _on_prompt_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	match (event as InputEventKey).keycode:
		KEY_TAB:
			_prompt.text = complete(_prompt.text)
			_prompt.caret_column = _prompt.text.length()
			_prompt.accept_event()
		KEY_UP:
			_recall(-1)
			_prompt.accept_event()
		KEY_DOWN:
			_recall(1)
			_prompt.accept_event()


func _print(text: String, color: Color) -> void:
	_log.push_color(color)
	_log.add_text(text + "\n")
	_log.pop()


## A reply is lines; a run of tab-separated lines becomes a table so the
## columns line up. The first column is the name, lit like the echo.
func _print_reply(text: String, color: Color) -> void:
	var rows: Array[PackedStringArray] = []
	for line in text.split("\n"):
		if line.contains("\t"):
			rows.append(line.split("\t"))
			continue
		_flush_table(rows)
		_print(line, color)
	_flush_table(rows)


func _flush_table(rows: Array[PackedStringArray]) -> void:
	if rows.is_empty():
		return
	var columns := 0
	for row in rows:
		columns = maxi(columns, row.size())
	_log.push_table(columns)
	for row in rows:
		for i in columns:
			_log.push_cell()
			_log.set_cell_padding(Rect2(0, 0, COLUMN_GAP, 0))
			_log.push_color(GameColors.TEXT_SECONDARY if i == 0 else GameColors.TEXT_PRIMARY)
			_log.add_text(row[i] if i < row.size() else "")
			_log.pop()
			_log.pop()
	_log.pop()
	_log.newline()  # a table is inline; without this the next line sits beside it
	rows.clear()


func _remember(line: String) -> void:
	if _history.is_empty() or _history[_history.size() - 1] != line:
		_history.append(line)
	if _history.size() > HISTORY_MAX:
		_history.remove_at(0)
	_history_cursor = _history.size()


func _recall(step: int) -> void:
	if _history.is_empty():
		return
	_history_cursor = clampi(_history_cursor + step, 0, _history.size())
	_prompt.text = _history[_history_cursor] if _history_cursor < _history.size() else ""
	_prompt.caret_column = _prompt.text.length()


## Tab: grow the first word to the one knob or command it starts, or to the
## letters every candidate shares. Pure so it can be pinned.
func complete(text: String) -> String:
	if text.contains(" ") or text == "":
		return text
	var prefix := text.to_upper()
	var candidates: PackedStringArray = []
	for name in DebugConfig.art_knob_names():
		if name.begins_with(prefix):
			candidates.append(name)
	for command in ["help", "list", "reset", "dump", "clear"]:
		if command.begins_with(text.to_lower()):
			candidates.append(command)
	if candidates.is_empty():
		return text
	if candidates.size() == 1:
		return candidates[0] + " "
	var shared := candidates[0]
	for candidate in candidates:
		while not candidate.begins_with(shared):
			shared = shared.left(shared.length() - 1)
	return shared


# =============================================================================
# INTERPRETER
# =============================================================================

## One line in, the reply out. Knob names are case-blind; commands are the
## five words in HELP_TEXT.
func execute(line: String) -> String:
	var words := line.strip_edges().split(" ", false)
	if words.is_empty():
		return ""
	match words[0].to_lower():
		"help":
			return HELP_TEXT
		"list":
			return _list()
		"reset":
			return _reset(words)
		"dump":
			return _dump()
		"clear":
			return ""
	var knob := words[0].to_upper()
	if not DebugConfig.art_knob_names().has(knob):
		return "unknown: %s. 'help' lists the commands, 'list' the knobs" % words[0]
	if words.size() == 1:
		return _line_for(knob)
	var raw := " ".join(words.slice(1))
	var value: Variant = _parse_value(raw, typeof(DebugConfig.get_art_knob(knob)))
	if value == null:
		return "%s: can't read '%s' as a %s" % [knob, raw,
				_type_name(typeof(DebugConfig.get_art_knob(knob)))]
	if not DebugConfig.set_art_knob(knob, value):
		return "%s: can't set that" % knob
	return _line_for(knob)


func _line_for(knob: String) -> String:
	return "%s = %s" % [knob, var_to_str(DebugConfig.get_art_knob(knob))]


## Rows: name, value, and what the file says when that differs.
func _list() -> String:
	var lines: PackedStringArray = []
	for knob in DebugConfig.art_knob_names():
		var value: Variant = DebugConfig.get_art_knob(knob)
		var default_value: Variant = DebugConfig.art_knob_default(knob)
		var file_note := "" if value == default_value else "file: %s" % var_to_str(default_value)
		lines.append("%s\t%s\t%s" % [knob, var_to_str(value), file_note])
	return "\n".join(lines)


func _reset(words: PackedStringArray) -> String:
	if words.size() == 1:
		DebugConfig.reset_art_knobs()
		return "every knob back to the file"
	var knob := words[1].to_upper()
	if not DebugConfig.art_knob_names().has(knob):
		return "unknown: %s" % words[1]
	DebugConfig.set_art_knob(knob, DebugConfig.art_knob_default(knob))
	return _line_for(knob)


## The changed knobs in the file's own syntax, on the clipboard — paste over
## the matching lines and the tuning session is committed. (The log can't be
## copied from: the prompt keeps keyboard focus, so Ctrl+C never reaches it.)
func _dump() -> String:
	var lines: PackedStringArray = []
	for knob in DebugConfig.art_knob_names():
		var value: Variant = DebugConfig.get_art_knob(knob)
		if value != DebugConfig.art_knob_default(knob):
			lines.append("static var %s: %s = %s" % [knob, _type_name(typeof(value)), var_to_str(value)])
	if lines.is_empty():
		return "nothing changed from the file"
	var text := "\n".join(lines)
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(text)
		return "on the clipboard. Paste over the matching lines in scripts/core/art_variables.gd:\n" + text
	return "paste over the matching lines in scripts/core/art_variables.gd:\n" + text


## The typed value, or null when the words don't read as the knob's type.
## Kinder than the file: `.4`, `on`, `#ff0000` and `0 0 0 1` all count.
static func _parse_value(raw: String, type: int) -> Variant:
	var text := raw.strip_edges()
	match type:
		TYPE_FLOAT:
			return float(text) if text.is_valid_float() else null
		TYPE_BOOL:
			match text.to_lower():
				"true", "on", "yes", "1":
					return true
				"false", "off", "no", "0":
					return false
			return null
		TYPE_COLOR:
			var parsed: Variant = str_to_var(text)
			if typeof(parsed) == TYPE_COLOR:
				return parsed
			if Color.html_is_valid(text):
				return Color.html(text)
			var parts := text.split(" ", false)
			if parts.size() != 4:
				return null
			for part in parts:
				if not part.is_valid_float():
					return null
			return Color(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]))
	return null


static func _type_name(type: int) -> String:
	match type:
		TYPE_FLOAT:
			return "float"
		TYPE_BOOL:
			return "bool"
		TYPE_COLOR:
			return "Color"
		TYPE_INT:
			return "int"
	return type_string(type)
