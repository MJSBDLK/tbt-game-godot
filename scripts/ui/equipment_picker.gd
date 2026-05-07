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


## Emitted when the user dismisses the picker via the close button. Prep
## screen listens for this to re-expand the roster strip and clear selection.
signal closed


@export var edit_mode: EditMode = EditMode.MOVES :
	set(value):
		edit_mode = value
		if is_node_ready():
			_refresh()


## Selection state machine. The picker has three states:
##
##   NONE   — no slot is highlighted. Click any slot → BROWSE.
##   BROWSE — a slot is highlighted; the user is reading. Detail column shows
##            its content; the swap icon (➡⬅) appears on the slot.
##            • Click the same slot again → NONE (deselect).
##            • Click a different slot → BROWSE that slot (move highlight).
##            • Click the swap icon → CARRY.
##   CARRY  — a slot has been "lifted" for swapping. The next click on a
##            different slot completes the swap and returns to NONE.
##            • Click the same slot again → BROWSE (cancel carry).
##            • Click outside any slot, or press Esc → BROWSE (cancel carry).
##
## This separates "I'm browsing" from "I'm rearranging" so users can read
## moves without accidentally swapping them.
enum SelectionMode { NONE, BROWSE, CARRY }


var _character_data: CharacterData = null

var _selection_mode: SelectionMode = SelectionMode.NONE
# When mode != NONE, these point to the selected slot.
# _selection_origin is "equipped" or "bank" (or "equipped_passive" for the
# preview-only passive list — though it never enters CARRY).
var _selection_origin: String = ""
var _selection_index: int = -1
# What to render in the detail column on the right. Tracks selection plus
# preview-only clicks (e.g. clicking a passive while in moves edit mode
# updates detail without disturbing the swap state).
var _detail_target: Variant = null  # Move or passive name (String) or null

# UI refs
var _summary_label: RichTextLabel = null
var _equipped_moves_box: VBoxContainer = null
var _equipped_passives_box: VBoxContainer = null
var _bank_box: VBoxContainer = null
var _detail_box: VBoxContainer = null
var _detail_col: VBoxContainer = null
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

	# Summary header + close button
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	root.add_child(header_row)

	_summary_label = RichTextLabel.new()
	_summary_label.bbcode_enabled = true
	_summary_label.fit_content = true
	_summary_label.scroll_active = false
	_summary_label.custom_minimum_size = Vector2(0, 38)
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ui_manager != null:
		_summary_label.add_theme_font_override("normal_font", ui_manager.font_8px)
		_summary_label.add_theme_font_size_override("normal_font_size", 8)
	header_row.add_child(_summary_label)

	var close_button := Button.new()
	close_button.text = "✕"
	close_button.tooltip_text = "Close (return to squad)"
	close_button.custom_minimum_size = Vector2(20, 20)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if ui_manager != null:
		close_button.add_theme_font_override("font", ui_manager.font_8px)
		close_button.add_theme_font_size_override("font_size", 8)
	close_button.pressed.connect(func() -> void: closed.emit())
	header_row.add_child(close_button)

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
	_equipped_moves_box.add_theme_constant_override("separation", 1)
	equipped_col.add_child(_equipped_moves_box)

	var passives_header := Label.new()
	passives_header.text = "EQUIPPED PASSIVES"
	if ui_manager != null:
		passives_header.add_theme_font_override("font", ui_manager.font_5px)
		passives_header.add_theme_font_size_override("font_size", 5)
	equipped_col.add_child(passives_header)

	_equipped_passives_box = VBoxContainer.new()
	_equipped_passives_box.add_theme_constant_override("separation", 1)
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
	_bank_box.add_theme_constant_override("separation", 1)
	_bank_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank_scroll.add_child(_bank_box)

	# Right: detail. Hidden by default; appears once the user clicks a slot.
	_detail_col = VBoxContainer.new()
	_detail_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_col.size_flags_stretch_ratio = 1.2
	_detail_col.visible = false
	columns.add_child(_detail_col)

	var detail_header := Label.new()
	detail_header.text = "DETAIL"
	if ui_manager != null:
		detail_header.add_theme_font_override("font", ui_manager.font_5px)
		detail_header.add_theme_font_size_override("font_size", 5)
	_detail_col.add_child(detail_header)

	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 4)
	_detail_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_col.add_child(_detail_box)


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
		var btn := _make_slot_button(label, "equipped", i, edit_mode == EditMode.MOVES, move_or_null)
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
		var bank_move: Move = MoveData.get_move(available[i])
		var btn := _make_slot_button(available[i], "bank", i, edit_mode == EditMode.MOVES, bank_move)
		# Stash the move name on the button as metadata so we don't need to re-resolve from index.
		btn.set_meta("move_name", available[i])
		_bank_box.add_child(btn)


func _refresh_detail() -> void:
	_clear_box(_detail_box)
	# Hide the whole detail column when there's nothing to show — gives the
	# equipped + bank columns more horizontal room and reads as "nothing
	# pending."
	if _detail_target == null:
		if _detail_col != null:
			_detail_col.visible = false
		return
	if _detail_col != null:
		_detail_col.visible = true

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

func _make_slot_button(label_text: String, origin: String, index: int, interactive: bool, move: Move = null) -> Button:
	var ui_manager: Node = get_node_or_null("/root/UIManager")

	var btn := Button.new()
	btn.toggle_mode = false
	# Without `btn.text` the Button collapses to its theme's empty-string
	# height — way shorter than the icons + label we layout as children.
	# Lock a minimum height so the hover highlight matches the visible
	# content. 14px = 10px icon + 4px combined vertical padding — snug
	# without the icons touching the slots above/below.
	btn.custom_minimum_size = Vector2(0, 14)
	# Even non-interactive (preview) buttons accept clicks — they update the
	# detail column but don't participate in selection state.
	btn.pressed.connect(_on_slot_pressed.bind(origin, index, interactive))

	# Build the slot's interior as a single HBoxContainer anchored to the
	# Button's full rect (offset for left padding + space on the right for
	# the swap icon). Children pass clicks through to the Button so the
	# whole row remains clickable as a unit; only the swap icon (TextureButton,
	# added below) captures its own click.
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 4
	hbox.offset_right = -14  # leaves room for the swap icon
	hbox.add_theme_constant_override("separation", 3)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)

	# Elemental + damage type icons. Skip on empty slots and on slots that
	# don't carry move data (e.g. passives, which pass move = null).
	var has_move_icons: bool = move != null and move.move_id != "empty"
	if has_move_icons:
		var elem_icon: TextureRect = _make_inline_icon(_elemental_icon_path(move.element_type))
		if elem_icon != null:
			hbox.add_child(elem_icon)
		var dmg_icon: TextureRect = _make_inline_icon(Enums.get_damage_type_icon(move.damage_type))
		if dmg_icon != null:
			hbox.add_child(dmg_icon)

	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ui_manager != null:
		name_label.add_theme_font_override("font", ui_manager.font_8px)
		name_label.add_theme_font_size_override("font_size", 8)
	hbox.add_child(name_label)

	var is_selected: bool = (
		_selection_mode != SelectionMode.NONE
		and origin == _selection_origin
		and index == _selection_index
	)
	name_label.text = label_text
	if is_selected and _selection_mode == SelectionMode.CARRY:
		# CARRY = "I'm holding this." Strong saturated amber + a subtle
		# modulate pulse so the slot reads as "active." The spinning swap
		# icon (added below) is the primary cue.
		btn.modulate = Color(2.0, 1.3, 0.4)
		var pulse := btn.create_tween()
		pulse.set_loops()
		pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(btn, "modulate", Color(2.4, 1.6, 0.5), 0.45)
		pulse.tween_property(btn, "modulate", Color(2.0, 1.3, 0.4), 0.45)
	elif is_selected:
		# BROWSE = "I'm reading this." Soft warm tint, no animation.
		btn.modulate = Color(1.4, 1.4, 0.8)
	if not interactive:
		btn.modulate.a = 0.65

	# Swap affordance:
	#  • BROWSE: static icon, click to lift.
	#  • CARRY: spinning icon, decorative — clicks pass through so clicking
	#    the slot (anywhere, including on the icon) cancels via the
	#    same-slot-click branch in _on_slot_pressed.
	if interactive and _slot_has_content(origin, index) and is_selected:
		var swap_icon := _make_swap_icon(origin, index)
		if _selection_mode == SelectionMode.CARRY:
			swap_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			swap_icon.pivot_offset = Vector2(4, 4)  # center of the 8×8 icon
			# `as_relative()` so each loop adds another TAU instead of snapping
			# back to the source value (which is what set_loops() does by
			# default — would freeze at TAU after the first revolution).
			var spin := swap_icon.create_tween()
			spin.set_loops()
			spin.tween_property(swap_icon, "rotation", TAU, 1.2).as_relative()
		btn.add_child(swap_icon)
	return btn


# 10×10 inline icon helper for elemental and damage type rendered inside a slot.
func _make_inline_icon(path: String) -> TextureRect:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var icon := TextureRect.new()
	icon.texture = load(path) as Texture2D
	icon.custom_minimum_size = Vector2(10, 10)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _elemental_icon_path(element_type: Enums.ElementalType) -> String:
	if element_type == Enums.ElementalType.NONE:
		return ""
	var type_name: String = Enums.ElementalType.keys()[element_type].to_lower()
	return "res://art/sprites/ui/elemental_type_icons_10x10/%s.png" % type_name


func _slot_has_content(origin: String, index: int) -> bool:
	if _character_data == null:
		return false
	if origin == "equipped":
		if index >= _character_data.equipped_moves.size():
			return false
		var move: Move = _character_data.equipped_moves[index]
		return move != null and move.move_id != "empty"
	if origin == "bank":
		return true
	return false


func _make_swap_icon(origin: String, index: int) -> TextureButton:
	var icon := TextureButton.new()
	icon.texture_normal = _get_swap_icon_texture()
	icon.custom_minimum_size = Vector2(8, 8)
	icon.size = Vector2(8, 8)
	icon.tooltip_text = "Swap with another move"
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Anchor to the right-center of the slot button. Position offset moves it
	# 12px in from the right edge with a 4px top offset so it visually sits
	# centered on a ~16px-tall slot.
	icon.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	icon.position = Vector2(-12, -4)
	icon.pressed.connect(_on_swap_icon_pressed.bind(origin, index))
	return icon


func _on_slot_pressed(origin: String, index: int, interactive: bool) -> void:
	# Preview-only clicks (e.g. passives in moves edit mode) update detail
	# but never touch selection state.
	if not interactive:
		_detail_target = _resolve_slot_target(origin, index)
		_refresh_detail()
		return

	match _selection_mode:
		SelectionMode.NONE:
			_select_browse(origin, index)
		SelectionMode.BROWSE:
			if _selection_origin == origin and _selection_index == index:
				# Same slot → deselect.
				_clear_selection()
			else:
				# Different slot → just move the highlight.
				_select_browse(origin, index)
		SelectionMode.CARRY:
			if _selection_origin == origin and _selection_index == index:
				# Clicked the lifted slot itself → cancel carry, drop back
				# to BROWSE on the same slot.
				_selection_mode = SelectionMode.BROWSE
			else:
				_execute_swap_into(origin, index)
				_clear_selection()
	_refresh()


func _on_swap_icon_pressed(origin: String, index: int) -> void:
	_select_carry(origin, index)
	_refresh()


func _select_browse(origin: String, index: int) -> void:
	_selection_mode = SelectionMode.BROWSE
	_selection_origin = origin
	_selection_index = index
	_detail_target = _resolve_slot_target(origin, index)


func _select_carry(origin: String, index: int) -> void:
	_selection_mode = SelectionMode.CARRY
	_selection_origin = origin
	_selection_index = index
	_detail_target = _resolve_slot_target(origin, index)


## Routes the lifted slot (in _selection_*) into the target slot. Equipped→
## equipped reorders; bank↔equipped swaps; bank→bank is a no-op (bank entries
## don't have positional identity worth preserving).
func _execute_swap_into(target_origin: String, target_index: int) -> void:
	var src_origin: String = _selection_origin
	var src_index: int = _selection_index
	if src_origin == "equipped" and target_origin == "equipped":
		_reorder_equipped_moves(src_index, target_index)
	elif src_origin == "equipped" and target_origin == "bank":
		var bank_btn: Button = _bank_box.get_child(target_index) as Button
		if bank_btn != null and bank_btn.has_meta("move_name"):
			_swap_move(src_index, bank_btn.get_meta("move_name"))
	elif src_origin == "bank" and target_origin == "equipped":
		var bank_btn: Button = _bank_box.get_child(src_index) as Button
		if bank_btn != null and bank_btn.has_meta("move_name"):
			_swap_move(target_index, bank_btn.get_meta("move_name"))
	# bank → bank: intentional no-op


# =============================================================================
# CANCEL / ESC HANDLING
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			_on_cancel_input()
			accept_event()
	elif event is InputEventMouseButton:
		# Click on empty space (not consumed by any slot button) cancels a
		# pending carry. Esc handles the same case for keyboard.
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT \
				and _selection_mode == SelectionMode.CARRY:
			_on_cancel_input()


func _on_cancel_input() -> void:
	if _selection_mode == SelectionMode.CARRY:
		# Drop back to BROWSE on the same slot — the user changed their mind
		# but probably still wants to read what they were holding.
		_selection_mode = SelectionMode.BROWSE
		_refresh()
	elif _selection_mode == SelectionMode.BROWSE:
		_clear_selection()
		_refresh()


# =============================================================================
# SWAP ICON ASSET
# =============================================================================

const _SWAP_ICON_PATH: String = "res://art/sprites/ui/swap_flat_8x8.png"


static func _get_swap_icon_texture() -> Texture2D:
	return load(_SWAP_ICON_PATH) as Texture2D


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
	_selection_mode = SelectionMode.NONE
	_selection_origin = ""
	_selection_index = -1
	# Detail tracks the active selection — when nothing's pending, nothing's
	# being previewed, so the column collapses on the next refresh.
	_detail_target = null


## Swaps the positions of two already-equipped moves. Lets the player reorder
## their loadout (e.g. moving the "main" attack to slot 1) without round-trips
## through the bank.
func _reorder_equipped_moves(index_a: int, index_b: int) -> void:
	if _character_data == null:
		return
	var moves: Array[Move] = _character_data.equipped_moves
	if index_a < 0 or index_b < 0 or index_a >= moves.size() or index_b >= moves.size():
		return
	var temp: Move = moves[index_a]
	moves[index_a] = moves[index_b]
	moves[index_b] = temp


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
