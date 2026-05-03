## Equipment picker — between-mission move/passive editor for a single unit.
##
## Layout (per .claude/equipment_picker.md):
##   Summary header (name, class, types, stats, injuries)
##   Three-column body:
##     Left:  Equipped Moves (top, 4 slots) + Equipped Passives (bottom, 1-2)
##     Center: Bank (alphabetized list of available moves/passives)
##     Right: Detail of currently-highlighted entry
##
## Selection model: click a slot in the active equipped section, then click an
## entry in the bank — swaps. Or click bank first, then equipped slot. Inactive
## equipped section is preview-only (clicks update the detail column but don't
## participate in swaps).
##
## Live commit semantics: every swap mutates CharacterData immediately. No
## Done/Cancel — closing the picker just navigates away.
##
## Each major section accepts a `collapsed: bool` parameter for the cramped-
## screen fallback strategy (Tier 1/2 in the design doc). For MVP all sections
## start expanded — we'll wire the auto-collapse trigger in step 5a after we
## see how it looks at 640x360.
class_name EquipmentPicker
extends Control


enum EditMode { MOVES, PASSIVES }


@export var edit_mode: EditMode = EditMode.MOVES :
	set(value):
		edit_mode = value
		if is_node_ready():
			_refresh()


var _character_data: CharacterData = null

# Selection state. _selection_origin is "equipped" or "bank" or "" (none).
# _selection_index is the slot/list index within that origin.
var _selection_origin: String = ""
var _selection_index: int = -1
# What to render in the detail column on the right. Independent of selection
# state — clicking a preview-only passive updates this without disturbing a
# pending swap selection.
var _detail_target: Variant = null  # Move or passive name (String) or null

# UI refs
var _summary_label: RichTextLabel = null
var _equipped_moves_box: VBoxContainer = null
var _equipped_passives_box: VBoxContainer = null
var _bank_box: VBoxContainer = null
var _detail_box: VBoxContainer = null
var _mode_toggle_label: Label = null


# =============================================================================
# PUBLIC API
# =============================================================================

func set_character(character: CharacterData) -> void:
	_character_data = character
	_clear_selection()
	if is_node_ready():
		_refresh()


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var ui_manager: Node = get_node_or_null("/root/UIManager")

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# Summary header
	_summary_label = RichTextLabel.new()
	_summary_label.bbcode_enabled = true
	_summary_label.fit_content = true
	_summary_label.scroll_active = false
	_summary_label.custom_minimum_size = Vector2(0, 38)
	if ui_manager != null:
		_summary_label.add_theme_font_override("normal_font", ui_manager.font_8px)
		_summary_label.add_theme_font_size_override("normal_font_size", 8)
	root.add_child(_summary_label)

	# Mode toggle hint
	_mode_toggle_label = Label.new()
	_mode_toggle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if ui_manager != null:
		_mode_toggle_label.add_theme_font_override("font", ui_manager.font_5px)
		_mode_toggle_label.add_theme_font_size_override("font_size", 5)
	root.add_child(_mode_toggle_label)

	# Three-column body
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 8)
	root.add_child(columns)

	# Left: equipped moves (top) + passives (bottom)
	var equipped_col := VBoxContainer.new()
	equipped_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipped_col.size_flags_stretch_ratio = 1.0
	equipped_col.add_theme_constant_override("separation", 8)
	columns.add_child(equipped_col)

	var moves_header := Label.new()
	moves_header.text = "EQUIPPED MOVES"
	if ui_manager != null:
		moves_header.add_theme_font_override("font", ui_manager.font_5px)
		moves_header.add_theme_font_size_override("font_size", 5)
	equipped_col.add_child(moves_header)

	_equipped_moves_box = VBoxContainer.new()
	_equipped_moves_box.add_theme_constant_override("separation", 2)
	equipped_col.add_child(_equipped_moves_box)

	var passives_header := Label.new()
	passives_header.text = "EQUIPPED PASSIVES"
	if ui_manager != null:
		passives_header.add_theme_font_override("font", ui_manager.font_5px)
		passives_header.add_theme_font_size_override("font_size", 5)
	equipped_col.add_child(passives_header)

	_equipped_passives_box = VBoxContainer.new()
	_equipped_passives_box.add_theme_constant_override("separation", 2)
	equipped_col.add_child(_equipped_passives_box)

	# Center: bank (scrollable)
	var bank_col := VBoxContainer.new()
	bank_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank_col.size_flags_stretch_ratio = 1.4
	columns.add_child(bank_col)

	var bank_header := Label.new()
	bank_header.text = "BANK"
	if ui_manager != null:
		bank_header.add_theme_font_override("font", ui_manager.font_5px)
		bank_header.add_theme_font_size_override("font_size", 5)
	bank_col.add_child(bank_header)

	var bank_scroll := ScrollContainer.new()
	bank_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bank_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bank_col.add_child(bank_scroll)

	_bank_box = VBoxContainer.new()
	_bank_box.add_theme_constant_override("separation", 2)
	_bank_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank_scroll.add_child(_bank_box)

	# Right: detail
	var detail_col := VBoxContainer.new()
	detail_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_col.size_flags_stretch_ratio = 1.2
	columns.add_child(detail_col)

	var detail_header := Label.new()
	detail_header.text = "DETAIL"
	if ui_manager != null:
		detail_header.add_theme_font_override("font", ui_manager.font_5px)
		detail_header.add_theme_font_size_override("font_size", 5)
	detail_col.add_child(detail_header)

	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 4)
	_detail_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_col.add_child(_detail_box)


# =============================================================================
# REFRESH
# =============================================================================

func _refresh() -> void:
	_refresh_summary()
	_refresh_mode_toggle()
	_refresh_equipped_moves()
	_refresh_equipped_passives()
	_refresh_bank()
	_refresh_detail()


func _refresh_summary() -> void:
	if _summary_label == null:
		return
	if _character_data == null:
		_summary_label.text = "[i]No unit selected[/i]"
		return
	var class_str: String = Enums.CharacterClass.keys()[_character_data.current_class].capitalize()
	var prim: String = Enums.elemental_type_to_string(_character_data.primary_type).capitalize()
	var sec: String = Enums.elemental_type_to_string(_character_data.secondary_type).capitalize()
	var type_str: String = prim if sec == "None" or sec == "" else "%s / %s" % [prim, sec]
	var injury_str: String = "—"
	if _character_data.current_injuries != null and _character_data.current_injuries.size() > 0:
		injury_str = "%d" % _character_data.current_injuries.size()
	_summary_label.text = "[b]%s[/b]  Lv %d  %s  %s   Inj: %s\nHP %d  STR %d  SPC %d  SKL %d  AGL %d  ATH %d  DEF %d  RES %d" % [
		_character_data.character_name, _character_data.level, type_str, class_str, injury_str,
		_character_data.max_hp, _character_data.strength, _character_data.special, _character_data.skill,
		_character_data.agility, _character_data.athleticism, _character_data.defense, _character_data.resistance,
	]


func _refresh_mode_toggle() -> void:
	if _mode_toggle_label == null:
		return
	var mode_str: String = "Moves" if edit_mode == EditMode.MOVES else "Passives"
	_mode_toggle_label.text = "Editing: %s   (toggle deferred — moves only for now)" % mode_str


func _refresh_equipped_moves() -> void:
	_clear_box(_equipped_moves_box)
	if _character_data == null:
		return
	var moves: Array[Move] = _character_data.equipped_moves
	# Pad to 4 slots so empty equipped slots are visible.
	for i: int in range(4):
		var label: String
		var move_or_null: Move = null
		if i < moves.size():
			move_or_null = moves[i]
			label = moves[i].move_name
		else:
			label = "— (empty)"
		var btn := _make_slot_button(label, "equipped", i, edit_mode == EditMode.MOVES)
		_equipped_moves_box.add_child(btn)


func _refresh_equipped_passives() -> void:
	_clear_box(_equipped_passives_box)
	if _character_data == null:
		return
	var passives: Array = _character_data.equipped_passives
	# Show at least 1 slot even if empty.
	var slot_count: int = maxi(passives.size(), 1)
	for i: int in range(slot_count):
		var label: String = "— (empty)"
		if i < passives.size():
			var p: Variant = passives[i]
			label = str(p) if p != null else "— (empty)"
		# Passives are preview-only this iteration regardless of edit_mode.
		var btn := _make_slot_button(label, "equipped_passive", i, false)
		_equipped_passives_box.add_child(btn)


func _refresh_bank() -> void:
	_clear_box(_bank_box)
	if _character_data == null:
		return
	# Bank shows movepool entries that aren't currently equipped.
	# Alphabetize for predictable scrolling.
	var equipped_names: Dictionary = {}
	for move: Move in _character_data.equipped_moves:
		if move != null:
			equipped_names[move.move_name] = true
	var available: Array[String] = []
	for name: String in _character_data.base_pool_moves:
		if not equipped_names.has(name):
			available.append(name)
	available.sort()

	if available.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(no other moves available)"
		_bank_box.add_child(empty_label)
		return

	for i: int in range(available.size()):
		var btn := _make_slot_button(available[i], "bank", i, edit_mode == EditMode.MOVES)
		# Stash the move name on the button as metadata so we don't need to re-resolve from index.
		btn.set_meta("move_name", available[i])
		_bank_box.add_child(btn)


func _refresh_detail() -> void:
	_clear_box(_detail_box)
	if _detail_target == null:
		var hint := Label.new()
		hint.text = "Click a move or passive\nto see details."
		hint.modulate.a = 0.6
		_detail_box.add_child(hint)
		return

	if _detail_target is Move:
		var move: Move = _detail_target
		_render_move_detail(move)
	elif _detail_target is String:
		# Bank entry stored as name — resolve to Move and render.
		var move := MoveData.get_move(_detail_target)
		if move != null:
			_render_move_detail(move)
		else:
			var name_only := Label.new()
			name_only.text = str(_detail_target)
			_detail_box.add_child(name_only)


func _render_move_detail(move: Move) -> void:
	var ui_manager: Node = get_node_or_null("/root/UIManager")
	var name_label := Label.new()
	name_label.text = move.move_name
	if ui_manager != null:
		name_label.add_theme_font_override("font", ui_manager.font_8px)
		name_label.add_theme_font_size_override("font_size", 8)
	_detail_box.add_child(name_label)

	var meta_label := Label.new()
	var elem_str: String = Enums.elemental_type_to_string(move.element_type).capitalize()
	var dmg_str: String = Enums.DamageType.keys()[move.damage_type].capitalize()
	meta_label.text = "%s / %s" % [dmg_str, elem_str]
	if ui_manager != null:
		meta_label.add_theme_font_override("font", ui_manager.font_5px)
		meta_label.add_theme_font_size_override("font_size", 5)
	_detail_box.add_child(meta_label)

	var stats_label := Label.new()
	stats_label.text = "Pow %d  Rng %d  AOE %d  Uses %d" % [
		move.base_power, move.attack_range, move.area_of_effect, move.max_uses
	]
	if ui_manager != null:
		stats_label.add_theme_font_override("font", ui_manager.font_5px)
		stats_label.add_theme_font_size_override("font_size", 5)
	_detail_box.add_child(stats_label)

	var desc_label := Label.new()
	desc_label.text = move.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if ui_manager != null:
		desc_label.add_theme_font_override("font", ui_manager.font_5px)
		desc_label.add_theme_font_size_override("font_size", 5)
	_detail_box.add_child(desc_label)


# =============================================================================
# SELECTION + SWAP
# =============================================================================

func _make_slot_button(label_text: String, origin: String, index: int, interactive: bool) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.toggle_mode = false
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Even non-interactive (preview) buttons accept clicks — they update the
	# detail column but don't participate in swap selection.
	btn.pressed.connect(_on_slot_pressed.bind(origin, index, interactive))
	# Visual cue for highlighted slot (matches selection state).
	if origin == _selection_origin and index == _selection_index:
		btn.modulate = Color(1.4, 1.4, 0.8)
	if not interactive:
		btn.modulate.a = 0.65
	return btn


func _on_slot_pressed(origin: String, index: int, interactive: bool) -> void:
	# Update the detail column regardless of interactivity.
	_detail_target = _resolve_slot_target(origin, index)

	if not interactive:
		# Preview-only click — refresh detail but leave any pending swap intact.
		_refresh_detail()
		return

	# Interactive click — drives the selection / swap state machine.
	if _selection_origin == "":
		# Nothing pending; this click highlights.
		_selection_origin = origin
		_selection_index = index
	elif _selection_origin == origin:
		# Same column — change the highlight.
		_selection_index = index
	else:
		# Cross-column click — swap.
		var equipped_idx: int = _selection_index if _selection_origin == "equipped" else index
		var bank_button: Button = _bank_box.get_child(_selection_index if _selection_origin == "bank" else index) as Button
		if bank_button != null and bank_button.has_meta("move_name"):
			_swap_move(equipped_idx, bank_button.get_meta("move_name"))
		_clear_selection()
	_refresh()


func _resolve_slot_target(origin: String, index: int) -> Variant:
	if _character_data == null:
		return null
	if origin == "equipped":
		var moves: Array[Move] = _character_data.equipped_moves
		if index < moves.size():
			return moves[index]
		return null
	if origin == "bank":
		var btn: Node = _bank_box.get_child(index)
		if btn != null and btn.has_meta("move_name"):
			return btn.get_meta("move_name")
		return null
	if origin == "equipped_passive":
		var passives: Array = _character_data.equipped_passives
		if index < passives.size():
			return passives[index]  # passive name string
		return null
	return null


func _clear_selection() -> void:
	_selection_origin = ""
	_selection_index = -1


## Replaces the equipped-move slot at `equipped_index` with the bank move named
## `bank_move_name`. The displaced move falls back into the bank automatically
## (bank is recomputed each refresh as base_pool_moves minus equipped). Live
## commits to CharacterData immediately.
func _swap_move(equipped_index: int, bank_move_name: String) -> void:
	if _character_data == null:
		return
	var new_move := MoveData.get_move(bank_move_name)
	if new_move == null:
		push_warning("EquipmentPicker: bank move '%s' not found in MoveData" % bank_move_name)
		return
	if equipped_index < _character_data.equipped_moves.size():
		_character_data.equipped_moves[equipped_index] = new_move
	else:
		# Filling an empty slot.
		while _character_data.equipped_moves.size() <= equipped_index:
			_character_data.equipped_moves.append(Move.EMPTY)
		_character_data.equipped_moves[equipped_index] = new_move


# =============================================================================
# UTILITIES
# =============================================================================

func _clear_box(box: VBoxContainer) -> void:
	if box == null:
		return
	for child: Node in box.get_children():
		child.queue_free()
