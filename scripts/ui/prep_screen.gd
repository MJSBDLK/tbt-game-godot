## SUPERSEDED (slice 2 of the intermission port, 2026-08-10): the flow now
## routes IntermissionHub → ManageUnitsScreen, and nothing links here anymore.
## Kept on disk until slice 3 absorbs EquipmentPicker into the workbench —
## this screen is currently the only way to reach move/passive editing and
## StatUp allocation (open it directly with F6 if you need those). Delete
## together with that migration.
##
## Between-mission prep hub (squad manager). Master-detail layout per
## .claude/squad_manager.md §3+§8: vertical roster strip on the left, focused
## unit's editing surface on the right.
##
## The roster strip is split into two named lists: SQUAD (deploying) and
## BENCH (held back). Cards move between lists via the per-card move button.
## Begin Mission is disabled when the Squad list is empty.
##
## Each roster card has two interactive zones:
##   - Card body click → selects the unit, opens equipment_picker on the right
##   - Move button     → moves the card to the other list (Squad ↔ Bench)
##                       without changing focus selection
class_name PrepScreen
extends Control


const BENCHED_MODULATE_ALPHA: float = 0.55

# Carmack toggle: when a unit is selected and the picker is open, the strip's
# secondary info either hides (true) or stays visible at the cost of taller
# cards (false). Hide-mode reads cleaner and fits more units on screen — the
# detail panel has all the same data in higher fidelity. Keep-mode lets the
# player audit the whole roster's typing/injuries without dismissing the
# picker. Flip and re-test to compare.
const COLLAPSE_HIDES_DETAILS: bool = true

const _CARD_HEIGHT_FULL: int = 36
const _CARD_HEIGHT_COLLAPSED: int = 20
const _PORTRAIT_SIZE_FULL: int = 32
const _PORTRAIT_SIZE_COLLAPSED: int = 16
const _ICON_SIZE: int = 10
const _ELEMENTAL_ICON_DIR: String = "res://art/sprites/ui/elemental_type_icons_10x10/"

# Strip width changes with collapse state so the picker can reclaim space when
# the user is editing a unit. Full = wide enough for portrait + name + class +
# icons + fingerprint + bench button; collapsed = portrait + full name.
const _STRIP_WIDTH_FULL: int = 220
const _STRIP_WIDTH_COLLAPSED: int = 120

var _header_label: Label = null
var _squad_header: Label = null
var _bench_header: Label = null
var _squad_strip: VBoxContainer = null
var _bench_strip: VBoxContainer = null
var _bench_empty_hint: Label = null
var _detail_host: Control = null
var _begin_button: Button = null
var _picker: EquipmentPicker = null
var _empty_prompt: Label = null

# Per-character UI state (parallel arrays indexed alongside the roster).
# _card_buttons doubles as the click target and the modulate target.
var _card_buttons: Array[Button] = []
var _move_buttons: Array[Button] = []
var _character_ids: Array[String] = []
# Per-card visual handles for the collapse toggle. Parallel to _card_buttons.
# _card_portraits may contain null for characters with no derivable sprite.
var _card_portraits: Array = []
var _card_detail_rows: Array[Array] = []
# The name row inside each card hosts the "★N unspent" badge — kept so we
# can rebuild just the badge when the picker emits `stats_changed`. Parallel
# to _card_buttons.
var _card_name_rows: Array[HBoxContainer] = []
# Current badge node per card (null if no unspent points). Parallel to
# _card_buttons. Tracked separately from _card_name_rows so we can free /
# replace just the badge without disturbing the name + class labels.
var _card_badges: Array = []

# Cached so _apply_collapse_state can resize the scroll panel without
# walking the tree.
var _roster_scroll: ScrollContainer = null

# Tracks the strip's current visual state so we don't re-apply unnecessarily.
var _is_collapsed: bool = false

var _selected_character_id: String = ""

# Maximum Squad size for the upcoming mission, read from the mission scene's
# SpawnTileLayer. 0 means "unknown / unlimited" (e.g. no active campaign).
var _squad_cap: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_chrome()
	_populate_roster()


# =============================================================================
# BUILD
# =============================================================================

func _build_chrome() -> void:
	var ui_manager: Node = UIManager

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.08, 0.08, 0.12, 1.0)
	add_child(background)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	root.offset_left = 8
	root.offset_top = 8
	root.offset_right = -8
	root.offset_bottom = -8
	add_child(root)

	# Top bar: header + Begin Mission
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	root.add_child(top_bar)

	_header_label = Label.new()
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ui_manager != null:
		_header_label.add_theme_font_override("font", ui_manager.font_11px)
		_header_label.add_theme_font_size_override("font_size", 11)
	top_bar.add_child(_header_label)

	_begin_button = Button.new()
	_begin_button.text = "Begin Mission"
	_begin_button.custom_minimum_size = Vector2(110, 22)
	_begin_button.pressed.connect(_on_begin_pressed)
	top_bar.add_child(_begin_button)

	# Main split: roster strip on left, detail host on right
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	root.add_child(main)

	# Left: scrolling roster (squad header + cards, then bench header + cards)
	_roster_scroll = ScrollContainer.new()
	_roster_scroll.custom_minimum_size = Vector2(_STRIP_WIDTH_FULL, 0)
	_roster_scroll.size_flags_horizontal = Control.SIZE_FILL
	_roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(_roster_scroll)
	var roster_scroll: ScrollContainer = _roster_scroll

	var roster_root := VBoxContainer.new()
	roster_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_root.add_theme_constant_override("separation", 6)
	roster_scroll.add_child(roster_root)

	_squad_header = _make_section_header(ui_manager, "Squad")
	roster_root.add_child(_squad_header)

	_squad_strip = VBoxContainer.new()
	_squad_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_squad_strip.add_theme_constant_override("separation", 4)
	roster_root.add_child(_squad_strip)

	_bench_header = _make_section_header(ui_manager, "Bench")
	roster_root.add_child(_bench_header)

	_bench_strip = VBoxContainer.new()
	_bench_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bench_strip.add_theme_constant_override("separation", 4)
	roster_root.add_child(_bench_strip)

	_bench_empty_hint = Label.new()
	_bench_empty_hint.text = "(empty)"
	_bench_empty_hint.modulate.a = 0.5
	if ui_manager != null:
		_bench_empty_hint.add_theme_font_override("font", ui_manager.font_5px)
		_bench_empty_hint.add_theme_font_size_override("font_size", 5)
	_bench_strip.add_child(_bench_empty_hint)

	# Right: detail host. Plain Control so the picker (added later) can use
	# PRESET_FULL_RECT to fill it — Container-based hosts would override that.
	_detail_host = Control.new()
	_detail_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_host.size_flags_stretch_ratio = 3.0
	_detail_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_host.clip_contents = true
	main.add_child(_detail_host)

	_empty_prompt = Label.new()
	_empty_prompt.text = "Select a unit on the left to manage their equipment."
	_empty_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_prompt.modulate.a = 0.6
	if ui_manager != null:
		_empty_prompt.add_theme_font_override("font", ui_manager.font_8px)
		_empty_prompt.add_theme_font_size_override("font_size", 8)
	_detail_host.add_child(_empty_prompt)


func _make_section_header(ui_manager: Node, base_text: String) -> Label:
	var label := Label.new()
	label.text = base_text
	if ui_manager != null:
		label.add_theme_font_override("font", ui_manager.font_8px)
		label.add_theme_font_size_override("font_size", 8)
	label.modulate = Color(1.0, 1.0, 0.85, 0.9)
	return label


func _populate_roster() -> void:
	var campaign_manager: Node = get_node_or_null("/root/CampaignManager")
	if campaign_manager != null and campaign_manager.is_active():
		var mission_index: int = campaign_manager.get_current_mission_index()
		var mission_count: int = campaign_manager.get_mission_count()
		_header_label.text = "Mission %d of %d" % [mission_index + 1, mission_count]
		_squad_cap = TilemapGridBuilder.count_player_spawns(campaign_manager.get_current_mission_path())
	else:
		_header_label.text = "Squad Preview"
		_squad_cap = 0

	var roster: Array[CharacterData] = SquadManager.get_active_roster()
	for character: CharacterData in roster:
		_add_roster_card(character)
	# Default-everyone-to-squad can exceed the cap on big rosters; per design §9
	# overflow goes to Bench. Move the tail of the squad to bench until we fit.
	_enforce_squad_cap_initial()
	_refresh_section_state()
	_refresh_begin_button()


## Called once after _populate_roster has placed every card in Squad. If the
## roster is larger than the cap, the trailing cards spill over to Bench so
## the player starts under the cap (per squad_manager.md §9 first-time rule).
func _enforce_squad_cap_initial() -> void:
	if _squad_cap <= 0:
		return
	while _count_cards_in(_squad_strip) > _squad_cap:
		var last_card: Node = _squad_strip.get_child(_squad_strip.get_child_count() - 1)
		if last_card is Button:
			var idx: int = _card_buttons.find(last_card as Button)
			_squad_strip.remove_child(last_card)
			_bench_strip.add_child(last_card)
			if idx != -1:
				_move_buttons[idx].text = "→ Deploy"
		else:
			break


func _add_roster_card(character: CharacterData) -> void:
	var ui_manager: Node = UIManager

	# The entire card is one Button so clicking anywhere on it selects the
	# unit. The move button sits inside as a child Button — its clicks are
	# consumed at that node and don't bubble up to the parent's pressed.
	# Card height tracks the portrait — 32px sprite + 2px padding top/bottom.
	var card_button := Button.new()
	card_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_button.custom_minimum_size = Vector2(0, _CARD_HEIGHT_FULL)
	card_button.toggle_mode = false
	card_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card_button.pressed.connect(_on_card_select_pressed.bind(character.character_id))
	_squad_strip.add_child(card_button)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_button.add_child(margin)

	# Outer row: portrait | info VBox (3 rows) | move button.
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)

	var portrait_node: TextureRect = null
	var portrait_texture: Texture2D = CharacterPortrait.get_sprite_crop_for(character)
	if portrait_texture != null:
		portrait_node = TextureRect.new()
		portrait_node.texture = portrait_texture
		portrait_node.custom_minimum_size = Vector2(_PORTRAIT_SIZE_FULL, _PORTRAIT_SIZE_FULL)
		portrait_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		portrait_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(portrait_node)

	# Info box stacks: name+class on top, type+injury icons in the middle,
	# stat fingerprint at the bottom.
	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_box.add_theme_constant_override("separation", 1)
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(info_box)

	# Row 1: full name (8px) | class + level (5px, dim)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_box.add_child(name_row)

	var name_label := Label.new()
	name_label.text = character.character_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	if ui_manager != null:
		name_label.add_theme_font_override("font", ui_manager.font_8px)
		name_label.add_theme_font_size_override("font_size", 8)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(name_label)

	var class_label := Label.new()
	var class_str: String = Enums.CharacterClass.keys()[character.current_class].capitalize()
	class_label.text = "%s Lv%d" % [class_str, character.level]
	class_label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	if ui_manager != null:
		class_label.add_theme_font_override("font", ui_manager.font_5px)
		class_label.add_theme_font_size_override("font_size", 5)
	class_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(class_label)

	# Eye-catching "★N" badge when the unit has stat-up points waiting to be
	# distributed. Drives the player into the picker's Stats mode — without it
	# they could miss the existence of the allocation surface entirely. The
	# badge node is tracked in _card_badges so we can refresh it live as the
	# player allocates inside the picker, without rebuilding the whole card.
	var badge_node: Label = _make_unspent_badge(character, ui_manager)
	if badge_node != null:
		name_row.add_child(badge_node)

	# Row 2: elemental type icons (left) | injury icons (right)
	var icon_row := HBoxContainer.new()
	icon_row.add_theme_constant_override("separation", 2)
	icon_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_box.add_child(icon_row)

	_add_type_icon(icon_row, character.primary_type)
	_add_type_icon(icon_row, character.secondary_type)

	var icon_spacer := Control.new()
	icon_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.add_child(icon_spacer)

	for injury: Injury in character.current_injuries:
		_add_injury_icon(icon_row, injury)

	# Row 3: stat fingerprint
	var fingerprint := StatFingerprint.new()
	fingerprint.set_character(character)
	info_box.add_child(fingerprint)

	var move_button := Button.new()
	move_button.text = "→ Bench"
	move_button.custom_minimum_size = Vector2(44, 14)
	move_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ui_manager != null:
		move_button.add_theme_font_override("font", ui_manager.font_5px)
		move_button.add_theme_font_size_override("font_size", 5)
	move_button.pressed.connect(_on_card_move_pressed.bind(card_button))
	content.add_child(move_button)

	_card_portraits.append(portrait_node)
	# Everything secondary hides on collapse — only portrait + name remain so
	# the strip becomes a pure navigation index. The picker has all of these
	# data points in higher fidelity, so duplicating them here while editing
	# is just visual noise.
	_card_detail_rows.append([class_label, icon_row, fingerprint, move_button] as Array)

	_card_buttons.append(card_button)
	_move_buttons.append(move_button)
	_character_ids.append(character.character_id)
	_card_name_rows.append(name_row)
	_card_badges.append(badge_node)


## Builds the unspent-points badge for a character if they have any unspent.
## Returns null when there's nothing to display — keeps the call sites
## branch-free. Pulled out so _refresh_card_badge can recreate the same node
## after allocation without duplicating the styling.
func _make_unspent_badge(character: CharacterData, ui_manager: Node) -> Label:
	var unspent: int = character.available_stat_ups - character.allocated_total()
	if unspent <= 0:
		return null
	var badge := Label.new()
	badge.text = "★%d" % unspent
	badge.modulate = GameColorPalette.get_color("Yellow", 5)
	if ui_manager != null:
		badge.add_theme_font_override("font", ui_manager.font_8px)
		badge.add_theme_font_size_override("font_size", 8)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.tooltip_text = "%d unspent stat-up point%s" % [unspent, "" if unspent == 1 else "s"]
	return badge


## Refreshes the ★N badge on the card for `character_id` based on its current
## allocation state. Frees the old badge (if any) and rebuilds from scratch —
## simpler than mutating-in-place and the badge is one Label, not a hot path.
## Called from the equipment_picker's `stats_changed` signal so the badge
## tracks +/- clicks live.
func _refresh_card_badge(character_id: String) -> void:
	var index: int = _character_ids.find(character_id)
	if index == -1:
		return
	var character: CharacterData = SquadManager.get_character_by_id(character_id)
	if character == null:
		return
	var name_row: HBoxContainer = _card_name_rows[index]
	var old_badge: Variant = _card_badges[index]
	if old_badge != null and is_instance_valid(old_badge):
		name_row.remove_child(old_badge)
		(old_badge as Node).queue_free()
	var new_badge: Label = _make_unspent_badge(character, UIManager)
	if new_badge != null:
		name_row.add_child(new_badge)
		# When the strip is collapsed, the badge inherits visibility from
		# _card_detail_rows entries — but the badge isn't in that list. Match
		# the collapse state explicitly so a live-recreated badge doesn't
		# briefly flicker into view while the picker is open.
		new_badge.visible = not _is_collapsed
	_card_badges[index] = new_badge


# =============================================================================
# SELECTION + DEPLOYMENT
# =============================================================================

func _on_card_select_pressed(character_id: String) -> void:
	# Clicking the currently-focused unit again toggles the picker closed —
	# same effect as the ✕ button, but matches the natural "click again to
	# deselect" expectation.
	if character_id == _selected_character_id and _picker != null and _picker.visible:
		_on_picker_closed()
		return
	_selected_character_id = character_id
	var character: CharacterData = SquadManager.get_character_by_id(character_id)
	if character == null:
		return
	_show_picker_for(character)
	_highlight_selected_card()


## Move the card between Squad and Bench lists. Selection is preserved — the
## unit stays focused in the detail panel even while changing roles, so the
## player can flip a unit on/off without losing their place.
func _on_card_move_pressed(card_button: Button) -> void:
	var index: int = _card_buttons.find(card_button)
	if index == -1:
		return
	var move_btn: Button = _move_buttons[index]
	var in_squad: bool = card_button.get_parent() == _squad_strip

	if in_squad:
		_squad_strip.remove_child(card_button)
		_bench_strip.add_child(card_button)
		move_btn.text = "→ Deploy"
	else:
		# Cap enforced via the disabled state on the move button, but guard here
		# anyway so a stale click can't slip a unit past the cap.
		if _squad_cap > 0 and _count_cards_in(_squad_strip) >= _squad_cap:
			return
		_bench_strip.remove_child(card_button)
		_squad_strip.add_child(card_button)
		move_btn.text = "→ Bench"

	_refresh_section_state()
	_refresh_begin_button()


func _show_picker_for(character: CharacterData) -> void:
	if _picker == null:
		_picker = EquipmentPicker.new()
		_picker.set_anchors_preset(Control.PRESET_FULL_RECT)
		_picker.closed.connect(_on_picker_closed)
		# Live ★N badge updates while the player is in the Stats tab. The
		# signal carries no payload — the picker's current character is the
		# only valid target, so we route through _selected_character_id.
		_picker.stats_changed.connect(_on_picker_stats_changed)
		_detail_host.add_child(_picker)
	_empty_prompt.visible = false
	_picker.visible = true
	_picker.set_character(character)
	if COLLAPSE_HIDES_DETAILS:
		_apply_collapse_state(true)


func _on_picker_stats_changed() -> void:
	if _selected_character_id == "":
		return
	_refresh_card_badge(_selected_character_id)


## Tear down picker focus: hide the picker, clear the selected card highlight,
## and re-expand the strip so the player is back in roster-overview mode.
func _on_picker_closed() -> void:
	if _picker != null:
		_picker.visible = false
	_empty_prompt.visible = true
	_selected_character_id = ""
	_apply_collapse_state(false)
	_highlight_selected_card()


# =============================================================================
# COLLAPSE STATE
# =============================================================================

## Toggles the strip's per-card secondary info between full and collapsed
## form. Called when the picker opens (collapse) and could be called again
## from a future "back to roster" affordance to expand. Does nothing on
## subsequent identical calls — handlers are free to fire it without thinking.
func _apply_collapse_state(collapsed: bool) -> void:
	if _is_collapsed == collapsed:
		return
	_is_collapsed = collapsed
	var portrait_size: int = _PORTRAIT_SIZE_COLLAPSED if collapsed else _PORTRAIT_SIZE_FULL
	var card_height: int = _CARD_HEIGHT_COLLAPSED if collapsed else _CARD_HEIGHT_FULL
	var strip_width: int = _STRIP_WIDTH_COLLAPSED if collapsed else _STRIP_WIDTH_FULL
	if _roster_scroll != null:
		_roster_scroll.custom_minimum_size = Vector2(strip_width, 0)
	for i: int in range(_card_buttons.size()):
		_card_buttons[i].custom_minimum_size = Vector2(0, card_height)
		var portrait: TextureRect = _card_portraits[i]
		if portrait != null:
			portrait.custom_minimum_size = Vector2(portrait_size, portrait_size)
		for control_node: Variant in _card_detail_rows[i]:
			if control_node is Control:
				(control_node as Control).visible = not collapsed


# =============================================================================
# CARD ICON HELPERS
# =============================================================================

func _add_type_icon(parent: HBoxContainer, element_type: Enums.ElementalType) -> void:
	if element_type == Enums.ElementalType.NONE:
		return
	var type_name: String = Enums.ElementalType.keys()[element_type].to_lower()
	var path: String = _ELEMENTAL_ICON_DIR + type_name + ".png"
	if not ResourceLoader.exists(path):
		return
	parent.add_child(_make_icon(load(path) as Texture2D))


func _add_injury_icon(parent: HBoxContainer, injury: Injury) -> void:
	var data: InjuryData = InjuryDatabase.get_injury_by_id(injury.injury_id)
	if data == null or data.icon_path.is_empty() or not ResourceLoader.exists(data.icon_path):
		return
	parent.add_child(_make_icon(load(data.icon_path) as Texture2D))


func _make_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(_ICON_SIZE, _ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _highlight_selected_card() -> void:
	for i: int in range(_character_ids.size()):
		var is_selected: bool = _character_ids[i] == _selected_character_id
		var card: Button = _card_buttons[i]
		var benched: bool = card.get_parent() == _bench_strip
		var base_alpha: float = BENCHED_MODULATE_ALPHA if benched else 1.0
		card.modulate = Color(1.2, 1.2, 0.85, base_alpha) if is_selected else Color(1.0, 1.0, 1.0, base_alpha)


## Recomputes header counts, applies bench dimming, and toggles the (empty)
## hint under the bench header. Called whenever a card moves between lists.
func _refresh_section_state() -> void:
	var squad_count: int = _count_cards_in(_squad_strip)
	var bench_count: int = _count_cards_in(_bench_strip)
	if _squad_header != null:
		if _squad_cap > 0:
			_squad_header.text = "Squad (%d/%d)" % [squad_count, _squad_cap]
		else:
			_squad_header.text = "Squad (%d)" % squad_count
	if _bench_header != null:
		_bench_header.text = "Bench (%d)" % bench_count
	if _bench_empty_hint != null:
		_bench_empty_hint.visible = bench_count == 0

	# When the cap is hit, disable the Deploy button on every bench card so the
	# affordance reads "you can't add anyone right now". Bench-ing from a full
	# squad stays enabled (and re-enables those buttons).
	var squad_full: bool = _squad_cap > 0 and squad_count >= _squad_cap
	for i: int in range(_card_buttons.size()):
		var card: Button = _card_buttons[i]
		var on_bench: bool = card.get_parent() == _bench_strip
		_move_buttons[i].disabled = on_bench and squad_full

	# Re-apply selection-aware modulation so dimming follows the new parent.
	_highlight_selected_card()


func _count_cards_in(strip: VBoxContainer) -> int:
	var count: int = 0
	for child: Node in strip.get_children():
		if child is Button:
			count += 1
	return count


func _selected_deployed_ids() -> Array[String]:
	var ids: Array[String] = []
	for i: int in range(_card_buttons.size()):
		if _card_buttons[i].get_parent() == _squad_strip:
			ids.append(_character_ids[i])
	return ids


func _refresh_begin_button() -> void:
	if _begin_button == null:
		return
	_begin_button.disabled = _selected_deployed_ids().is_empty()


# =============================================================================
# BEGIN MISSION
# =============================================================================

func _on_begin_pressed() -> void:
	var campaign_manager: Node = get_node_or_null("/root/CampaignManager")
	if campaign_manager == null or not campaign_manager.is_active():
		push_warning("PrepScreen: no active campaign — returning to start screen")
		SceneRouter.change_scene_to("res://scenes/ui/start_screen.tscn")
		return
	campaign_manager.set_deployment(_selected_deployed_ids())
	campaign_manager.deploy_to_current_mission()
