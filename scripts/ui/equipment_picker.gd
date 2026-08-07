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


enum EditMode { MOVES, PASSIVES, STATS }


# Display order + labels for the stat-allocation panel. Mirrors the abbreviation
# convention used in the summary header so the player learns one set of names.
const _STAT_ROWS: Array = [
	{"name": "max_hp",      "label": "HP"},
	{"name": "strength",    "label": "STR"},
	{"name": "special",     "label": "SPC"},
	{"name": "skill",       "label": "SKL"},
	{"name": "agility",     "label": "AGL"},
	{"name": "athleticism", "label": "ATH"},
	{"name": "defense",     "label": "DEF"},
	{"name": "resistance",  "label": "RES"},
]

# Cap bar geometry for the stat rows. 3px tall rather than the 1px used in the
# read-only panels: this is the screen where you're actively pushing the bar,
# so the segment you just bought has to be visible while your eye is on the
# [+] button. Width is a minimum — the row's spacer lets it stretch.
const STAT_CAP_BAR_WIDTH: int = 40
const STAT_CAP_BAR_HEIGHT: int = 3


## Emitted when the user dismisses the picker via the close button. Prep
## screen listens for this to re-expand the roster strip and clear selection.
signal closed

## Emitted whenever the stat-allocation surface mutates the character
## (increment / decrement / reset). Prep screen uses this to refresh the
## roster card's "★N unspent" badge live as the player allocates.
signal stats_changed


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
#
# `_detail_target_kind` disambiguates passive-name strings from move-name
# strings; both flow through the same field but render via different paths.
var _detail_target: Variant = null  # Move, passive name (String), or null
var _detail_target_kind: String = ""  # "" | "move" | "passive"

# UI refs
var _summary_label: RichTextLabel = null
var _equipped_moves_box: VBoxContainer = null
var _equipped_passives_box: VBoxContainer = null
var _bank_box: VBoxContainer = null
var _detail_box: VBoxContainer = null
var _detail_col: VBoxContainer = null
var _mode_toggle_button: Button = null
# The MOVES/PASSIVES three-column body and the STATS body live as siblings
# under root; visibility flips together based on edit_mode.
var _equipment_body: HBoxContainer = null
var _stats_body: VBoxContainer = null
var _stat_rows_box: VBoxContainer = null
var _stat_pool_label: Label = null
var _stat_reset_button: Button = null


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
	var ui_manager: Node = UIManager

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

	# Mode toggle button — flips between editing moves and editing passives.
	# Click cycles. Inactive section becomes preview-only on the next refresh.
	_mode_toggle_button = Button.new()
	_mode_toggle_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_mode_toggle_button.tooltip_text = "Toggle moves / passives"
	if ui_manager != null:
		_mode_toggle_button.add_theme_font_override("font", ui_manager.font_8px)
		_mode_toggle_button.add_theme_font_size_override("font_size", 8)
	_mode_toggle_button.pressed.connect(_on_mode_toggle_pressed)
	root.add_child(_mode_toggle_button)

	# Three-column body (MOVES/PASSIVES editing). Hidden when STATS mode active.
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 8)
	root.add_child(columns)
	_equipment_body = columns

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

	_build_stats_body(root, ui_manager)


func _build_stats_body(root: VBoxContainer, ui_manager: Node) -> void:
	_stats_body = VBoxContainer.new()
	_stats_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_body.add_theme_constant_override("separation", 4)
	_stats_body.visible = false
	root.add_child(_stats_body)

	# Top row: pool counter on the left, Reset on the right.
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	_stats_body.add_child(header_row)

	_stat_pool_label = Label.new()
	_stat_pool_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# Same Yellow-5 accent as the roster cards' ★N badge and the allocation
	# pluses — one color = "this is the stat-up currency" wherever it appears.
	_stat_pool_label.add_theme_color_override("font_color", GameColorPalette.get_color("Yellow", 5))
	if ui_manager != null:
		_stat_pool_label.add_theme_font_override("font", ui_manager.font_8px)
		_stat_pool_label.add_theme_font_size_override("font_size", 8)
	header_row.add_child(_stat_pool_label)

	_stat_reset_button = Button.new()
	_stat_reset_button.text = "Reset"
	_stat_reset_button.tooltip_text = "Refund every allocated point back to the pool"
	_stat_reset_button.custom_minimum_size = Vector2(44, 14)
	if ui_manager != null:
		_stat_reset_button.add_theme_font_override("font", ui_manager.font_5px)
		_stat_reset_button.add_theme_font_size_override("font_size", 5)
	_stat_reset_button.pressed.connect(_on_stat_reset_pressed)
	header_row.add_child(_stat_reset_button)

	# Trailing spacer absorbs the row's leftover width so the pool label and
	# Reset stay paired on the left — Reset on the far right of the panel was
	# easy to miss.
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(header_spacer)

	# 8 stat rows live here — repopulated each refresh.
	_stat_rows_box = VBoxContainer.new()
	_stat_rows_box.add_theme_constant_override("separation", 2)
	_stat_rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stat_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_body.add_child(_stat_rows_box)


# =============================================================================
# REFRESH
# =============================================================================

func _refresh() -> void:
	_refresh_summary()
	_refresh_mode_toggle()
	_refresh_visible_body()
	if edit_mode == EditMode.STATS:
		_refresh_stats_body()
		return
	_refresh_equipped_moves()
	_refresh_equipped_passives()
	_refresh_bank()
	_refresh_detail()


func _refresh_visible_body() -> void:
	if _equipment_body != null:
		_equipment_body.visible = edit_mode != EditMode.STATS
	if _stats_body != null:
		_stats_body.visible = edit_mode == EditMode.STATS


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
	_summary_label.text = "[b]%s[/b]  Lv %d  %s  %s   Inj: %s\nHP %d  STR %d  SPC %d  SKL %d  AGL %d  ATH %d  DEF %d  RES %d" % [
		_character_data.character_name, _character_data.level, type_str, class_str,
		_injury_summary_bbcode(),
		_character_data.max_hp, _character_data.strength, _character_data.special, _character_data.skill,
		_character_data.agility, _character_data.athleticism, _character_data.defense, _character_data.resistance,
	]


## The summary used to show only an injury COUNT — "we can't see injuries on
## the intermission screen" (playtest). Now each injury renders inline as its
## icon + name + battles-remaining, with severity/description on hover via
## [hint]. Falls back to the display name alone when an icon is missing.
func _injury_summary_bbcode() -> String:
	var injuries: Array = _character_data.current_injuries
	if injuries == null or injuries.is_empty():
		return "—"
	var parts: PackedStringArray = PackedStringArray()
	for injury: Injury in injuries:
		var data: InjuryData = injury.get_data()
		var display_name: String = data.display_name if data != null else injury.injury_id.capitalize()
		var severity_name: String = "Major" if injury.severity == Enums.InjurySeverity.MAJOR else "Minor"
		var icon_tag: String = ""
		if data != null and data.icon_path != "" and ResourceLoader.exists(data.icon_path):
			icon_tag = "[img]%s[/img] " % data.icon_path
		parts.append("[hint=%s (%s) — %d battle%s left]%s%s (%d)[/hint]" % [
			display_name, severity_name, injury.battles_remaining,
			"" if injury.battles_remaining == 1 else "s",
			icon_tag, display_name, injury.battles_remaining,
		])
	return ", ".join(parts)


func _refresh_mode_toggle() -> void:
	if _mode_toggle_button == null:
		return
	var mode_str: String = "Moves"
	match edit_mode:
		EditMode.PASSIVES: mode_str = "Passives"
		EditMode.STATS: mode_str = "Stats"
	_mode_toggle_button.text = "Editing: %s  ⇄" % mode_str


func _on_mode_toggle_pressed() -> void:
	# Wipe selection + detail before switching — the new mode's interactive
	# section is different, so any held slot is now meaningless.
	_clear_selection()
	match edit_mode:
		EditMode.MOVES: edit_mode = EditMode.PASSIVES
		EditMode.PASSIVES: edit_mode = EditMode.STATS
		_: edit_mode = EditMode.MOVES
	_refresh()


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
		var btn := _make_slot_button(
			label, "equipped", i, edit_mode == EditMode.MOVES, move_or_null)
		_equipped_moves_box.add_child(btn)


func _refresh_equipped_passives() -> void:
	_clear_box(_equipped_passives_box)
	if _character_data == null:
		return
	var passives: Array = _character_data.equipped_passives
	# 4 fixed slots — matches the move grid visually so the equipped column
	# reads as a uniform 4×N stack regardless of which mode you're in.
	var slot_count: int = 4
	for i: int in range(slot_count):
		var label: String = "— (empty)"
		var passive_name: String = ""
		if i < passives.size():
			var p: Variant = passives[i]
			if p != null:
				passive_name = str(p)
				label = passive_name
		var btn := _make_slot_button(
			label, "equipped_passive", i, edit_mode == EditMode.PASSIVES,
			null, passive_name)
		_equipped_passives_box.add_child(btn)


func _refresh_bank() -> void:
	_clear_box(_bank_box)
	if _character_data == null:
		return
	if edit_mode == EditMode.MOVES:
		_populate_move_bank()
	else:
		_populate_passive_bank()


func _populate_move_bank() -> void:
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
		var btn := _make_slot_button(available[i], "bank", i, true, bank_move)
		# Stash the item name as metadata so swaps don't need to re-resolve from index.
		btn.set_meta("item_name", available[i])
		_bank_box.add_child(btn)


func _populate_passive_bank() -> void:
	# Mirror the move bank: pool minus equipped, alphabetized.
	var equipped_names: Dictionary = {}
	for passive: Variant in _character_data.equipped_passives:
		if passive != null:
			equipped_names[str(passive)] = true
	var available: Array[String] = []
	for name: String in _character_data.base_pool_passives:
		if not equipped_names.has(name):
			available.append(name)
	available.sort()
	if available.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(no other passives available)"
		_bank_box.add_child(empty_label)
		return
	for i: int in range(available.size()):
		var btn := _make_slot_button(available[i], "bank", i, true, null, available[i])
		btn.set_meta("item_name", available[i])
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

	match _detail_target_kind:
		"move":
			var move: Move = null
			if _detail_target is Move:
				move = _detail_target
			elif _detail_target is String:
				move = MoveData.get_move(_detail_target)
			if move != null:
				_render_move_detail(move)
		"passive":
			_render_passive_detail(str(_detail_target))


func _render_move_detail(move: Move) -> void:
	var ui_manager: Node = UIManager
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


func _render_passive_detail(passive_name: String) -> void:
	var ui_manager: Node = UIManager
	var name_label := Label.new()
	name_label.text = passive_name
	if ui_manager != null:
		name_label.add_theme_font_override("font", ui_manager.font_8px)
		name_label.add_theme_font_size_override("font_size", 8)
	_detail_box.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = PassiveData.get_description(passive_name)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if ui_manager != null:
		desc_label.add_theme_font_override("font", ui_manager.font_5px)
		desc_label.add_theme_font_size_override("font_size", 5)
	_detail_box.add_child(desc_label)


# =============================================================================
# SELECTION + SWAP
# =============================================================================

## `move`: present for move slots; drives the inline element + damage icons.
## Passive slots pass `move = null`; the icon row simply collapses.
func _make_slot_button(
		label_text: String, origin: String, index: int, interactive: bool,
		move: Move = null, _passive_name: String = "") -> Button:
	var ui_manager: Node = UIManager

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
	if origin == "equipped_passive":
		if index >= _character_data.equipped_passives.size():
			return false
		var p: Variant = _character_data.equipped_passives[index]
		return p != null and str(p) != ""
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
		_capture_detail_target(origin, index)
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
	_capture_detail_target(origin, index)


func _select_carry(origin: String, index: int) -> void:
	_selection_mode = SelectionMode.CARRY
	_selection_origin = origin
	_selection_index = index
	_capture_detail_target(origin, index)


## Routes the lifted slot (in _selection_*) into the target slot. Equipped→
## equipped reorders; bank↔equipped swaps; bank→bank is a no-op (bank entries
## don't have positional identity worth preserving). Dispatches the move vs
## passive variant based on `edit_mode` — the inactive section can't initiate
## a swap, so origin combinations from the wrong mode never reach here.
func _execute_swap_into(target_origin: String, target_index: int) -> void:
	var src_origin: String = _selection_origin
	var src_index: int = _selection_index
	if edit_mode == EditMode.MOVES:
		if src_origin == "equipped" and target_origin == "equipped":
			_reorder_equipped_moves(src_index, target_index)
		elif src_origin == "equipped" and target_origin == "bank":
			var bank_name: String = _read_bank_item_name(target_index)
			if bank_name != "":
				_swap_move(src_index, bank_name)
		elif src_origin == "bank" and target_origin == "equipped":
			var bank_name: String = _read_bank_item_name(src_index)
			if bank_name != "":
				_swap_move(target_index, bank_name)
	else:  # PASSIVES
		if src_origin == "equipped_passive" and target_origin == "equipped_passive":
			_reorder_equipped_passives(src_index, target_index)
		elif src_origin == "equipped_passive" and target_origin == "bank":
			var bank_name: String = _read_bank_item_name(target_index)
			if bank_name != "":
				_swap_passive(src_index, bank_name)
		elif src_origin == "bank" and target_origin == "equipped_passive":
			var bank_name: String = _read_bank_item_name(src_index)
			if bank_name != "":
				_swap_passive(target_index, bank_name)
	# bank → bank: intentional no-op


func _read_bank_item_name(bank_index: int) -> String:
	if bank_index < 0 or bank_index >= _bank_box.get_child_count():
		return ""
	var btn: Node = _bank_box.get_child(bank_index)
	if btn == null or not btn.has_meta("item_name"):
		return ""
	return str(btn.get_meta("item_name"))


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


## Sets `_detail_target` and `_detail_target_kind` based on the slot at
## (origin, index). Kind matters because move names and passive names are both
## bare strings — without it, the detail renderer can't tell which lookup to
## perform.
func _capture_detail_target(origin: String, index: int) -> void:
	_detail_target = null
	_detail_target_kind = ""
	if _character_data == null:
		return
	if origin == "equipped":
		var moves: Array[Move] = _character_data.equipped_moves
		if index < moves.size():
			_detail_target = moves[index]
			_detail_target_kind = "move"
		return
	if origin == "equipped_passive":
		var passives: Array = _character_data.equipped_passives
		if index < passives.size() and passives[index] != null:
			_detail_target = str(passives[index])
			_detail_target_kind = "passive"
		return
	if origin == "bank":
		if index < 0 or index >= _bank_box.get_child_count():
			return
		var btn: Node = _bank_box.get_child(index)
		if btn == null or not btn.has_meta("item_name"):
			return
		_detail_target = str(btn.get_meta("item_name"))
		_detail_target_kind = "move" if edit_mode == EditMode.MOVES else "passive"


func _clear_selection() -> void:
	_selection_mode = SelectionMode.NONE
	_selection_origin = ""
	_selection_index = -1
	# Detail tracks the active selection — when nothing's pending, nothing's
	# being previewed, so the column collapses on the next refresh.
	_detail_target = null
	_detail_target_kind = ""


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


## Mirror of `_reorder_equipped_moves` for the passive list.
func _reorder_equipped_passives(index_a: int, index_b: int) -> void:
	if _character_data == null:
		return
	var passives: Array = _character_data.equipped_passives
	if index_a < 0 or index_b < 0 or index_a >= passives.size() or index_b >= passives.size():
		return
	var temp: Variant = passives[index_a]
	passives[index_a] = passives[index_b]
	passives[index_b] = temp


## Mirror of `_swap_move` for passives. Stored as bare strings — no
## per-instance state to track (passives don't have PP / cooldowns yet).
func _swap_passive(equipped_index: int, bank_passive_name: String) -> void:
	if _character_data == null:
		return
	if PassiveData.get_passive(bank_passive_name) == null:
		push_warning("EquipmentPicker: passive '%s' not in PassiveData" % bank_passive_name)
		return
	var passives: Array = _character_data.equipped_passives
	if equipped_index < passives.size():
		passives[equipped_index] = bank_passive_name
	else:
		while passives.size() < equipped_index:
			passives.append("")
		passives.append(bank_passive_name)


# =============================================================================
# STATS BODY
# =============================================================================

func _refresh_stats_body() -> void:
	_clear_box(_stat_rows_box)
	if _character_data == null:
		_stat_pool_label.text = ""
		_stat_reset_button.disabled = true
		return

	var spent: int = _character_data.allocated_total()
	var pool: int = _character_data.available_stat_ups
	var remaining: int = pool - spent
	# "Stat Ups: 7 / 10 unspent" reads as a glance — pool size on the right
	# anchors expectations so a player ramping a fresh recruit (with a small
	# pool) doesn't think the system is broken.
	_stat_pool_label.text = "Stat Ups: %d / %d unspent" % [remaining, pool]
	_stat_reset_button.disabled = spent == 0

	for entry: Dictionary in _STAT_ROWS:
		var row := _make_stat_row(str(entry["name"]), str(entry["label"]), remaining)
		_stat_rows_box.add_child(row)


func _make_stat_row(stat_name: String, abbrev: String, points_remaining: int) -> HBoxContainer:
	var ui_manager: Node = UIManager

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)

	var name_label := Label.new()
	name_label.text = abbrev
	name_label.custom_minimum_size = Vector2(22, 14)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if ui_manager != null:
		name_label.add_theme_font_override("font", ui_manager.font_8px)
		name_label.add_theme_font_size_override("font_size", 8)
	row.add_child(name_label)

	var points: int = _character_data.get_allocated_points(stat_name)
	var level_value: int = _character_data.get_base_plus_growth(stat_name)
	var resulting: int = level_value + StatAllocation.compute_delta(stat_name, level_value, points)

	var minus_button := Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(14, 14)
	minus_button.disabled = points <= 0
	if ui_manager != null:
		minus_button.add_theme_font_override("font", ui_manager.font_8px)
		minus_button.add_theme_font_size_override("font_size", 8)
	minus_button.pressed.connect(_on_stat_decrement.bind(stat_name))
	row.add_child(minus_button)

	# Value display: "30+++ → 33". The pluses are colored; the arrow + result
	# only appear when allocation produced a non-zero delta. Level value stays
	# left-aligned regardless of allocation so columns don't jitter as the
	# player clicks +/-. Fit-content (no SIZE_EXPAND_FILL) so the + button hugs
	# the value instead of being banished to the far right of the row.
	var value_label := RichTextLabel.new()
	value_label.bbcode_enabled = true
	value_label.fit_content = true
	value_label.scroll_active = false
	value_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Just wide enough for a plain 3-digit number; the "+++ → N" preview pushes
	# the + button rightward when allocated, which doubles as a visual cue that
	# the stat has been spent on. Cross-row alignment loses out to the -/value/+
	# cluster reading as a single tight unit.
	value_label.custom_minimum_size = Vector2(20, 14)
	if ui_manager != null:
		value_label.add_theme_font_override("normal_font", ui_manager.font_8px)
		value_label.add_theme_font_size_override("normal_font_size", 8)
	# Yellow 5 = the stat-up accent (matches the ★N badge + pool counter), so
	# "what's being modified" and "what's left to spend" read as one system.
	var accent_hex: String = GameColorPalette.get_color("Yellow", 5).to_html(false)
	var pluses: String = "+".repeat(points)
	var trailer: String = ""
	if points > 0 and resulting != level_value:
		trailer = "  → %d" % resulting
	value_label.text = "%d[color=#%s]%s%s[/color]" % [level_value, accent_hex, pluses, trailer]
	row.add_child(value_label)

	var plus_button := Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(14, 14)
	# `+` greys out at the per-stat cap OR when the pool is empty, so the
	# affordance reads "this button can't do anything right now" in either case.
	plus_button.disabled = points >= StatAllocation.PER_STAT_CAP or points_remaining <= 0
	if ui_manager != null:
		plus_button.add_theme_font_override("font", ui_manager.font_8px)
		plus_button.add_theme_font_size_override("font_size", 8)
	plus_button.pressed.connect(_on_stat_increment.bind(stat_name))
	row.add_child(plus_button)

	# Cap bar, same component the character sheet and unit detail panel use.
	# This screen is where caps actually change a decision — it's where you
	# spend StatUps — and it was the one surface with no cap awareness at all.
	# The bonus segment is what makes it worth the pixels here: press [+] and
	# you watch the accent segment push out past the class ceiling, which is
	# the "StatUps may exceed the cap" rule demonstrating itself.
	var cap_bar := StatCapBar.new(stat_name, STAT_CAP_BAR_HEIGHT)
	cap_bar.custom_minimum_size = Vector2(STAT_CAP_BAR_WIDTH, STAT_CAP_BAR_HEIGHT)
	cap_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap_bar.set_character(_character_data)
	cap_bar.tooltip_text = "%s %d of %d %s cap · game max %d" % [
		abbrev,
		_character_data.get_base_plus_growth(stat_name),
		_character_data.get_stat_cap(stat_name),
		Enums.get_class_display_name(_character_data.current_class),
		_character_data.get_global_stat_cap(stat_name),
	]
	row.add_child(cap_bar)
	# Radiant Dawn order: LABEL, GAUGE, NUMBER, then the controls. Built last
	# because the tooltip reads state the earlier locals computed, then moved
	# into position — appending it after [+] put the gauge nowhere near the
	# number it describes.
	row.move_child(cap_bar, 1)

	# Disabled buttons swallow clicks silently — gui_input still fires on them,
	# so a press on a greyed +/- red-flashes the info that explains WHY it's
	# disabled (pool counter when out of points, the row's value otherwise).
	minus_button.gui_input.connect(
			_on_disabled_stat_button_input.bind(minus_button, stat_name, value_label))
	plus_button.gui_input.connect(
			_on_disabled_stat_button_input.bind(plus_button, stat_name, value_label))

	# Trailing spacer absorbs the row's leftover width so the -/value/+ cluster
	# stays packed on the left edge instead of stretching across the panel.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	return row


func _on_stat_increment(stat_name: String) -> void:
	if _character_data == null:
		return
	var points: int = _character_data.get_allocated_points(stat_name)
	if points >= StatAllocation.PER_STAT_CAP:
		return
	if _character_data.allocated_total() >= _character_data.available_stat_ups:
		return
	_character_data.set_allocated_points(stat_name, points + 1)
	_refresh_summary()
	_refresh_stats_body()
	stats_changed.emit()


func _on_stat_decrement(stat_name: String) -> void:
	if _character_data == null:
		return
	var points: int = _character_data.get_allocated_points(stat_name)
	if points <= 0:
		return
	_character_data.set_allocated_points(stat_name, points - 1)
	_refresh_summary()
	_refresh_stats_body()
	stats_changed.emit()


func _on_stat_reset_pressed() -> void:
	if _character_data == null:
		return
	if _character_data.allocated_total() == 0:
		return
	_character_data.reset_allocations()
	_refresh_summary()
	_refresh_stats_body()
	stats_changed.emit()


## Pressing a DISABLED +/- button gives no feedback by default (disabled
## buttons never emit `pressed`), which reads as "the screen is broken".
## gui_input still fires on them, so flash the info that explains the refusal:
## the pool counter when the press failed for lack of points, otherwise the
## row's own value (per-stat cap reached / nothing allocated to remove).
func _on_disabled_stat_button_input(event: InputEvent, button: Button,
		stat_name: String, value_label: Control) -> void:
	if not button.disabled or _character_data == null:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var points: int = _character_data.get_allocated_points(stat_name)
	var out_of_points: bool = \
			_character_data.allocated_total() >= _character_data.available_stat_ups
	if button.text == "+" and out_of_points and points < StatAllocation.PER_STAT_CAP:
		_flash_denied(_stat_pool_label)
	else:
		_flash_denied(value_label)


## Quick red pulse on `control` — the "that's why not" gesture.
func _flash_denied(control: Control) -> void:
	if control == null or not control.is_inside_tree():
		return
	var tween := control.create_tween()
	tween.tween_property(control, "modulate", Color(1.0, 0.25, 0.25), 0.05)
	tween.tween_property(control, "modulate", Color.WHITE, 0.35)


# =============================================================================
# UTILITIES
# =============================================================================

func _clear_box(box: VBoxContainer) -> void:
	if box == null:
		return
	for child: Node in box.get_children():
		child.queue_free()
