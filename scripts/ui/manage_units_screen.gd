## MANAGE UNITS — the three-column workspace ([.claude/intermission.md] §3).
## Slices 2+3 of the intermission port: rail · sheet · workbench, all live.
## The bEXP lane on the sheet's XP row is slice 4.
##
## VENUE (§2): this is the HUD venue — glass panels and the full button
## vocabulary, against the same MenuStageBackdrop the hub uses, dimmed harder
## (0.80 vs the menu's 0.35) because dense data needs a quiet ground more than
## bare text does.
##
## ONE SCREEN, NO MODES (§3a): click a slot, the workbench offers what fits in
## it. The rail decides WHO (RosterRail), the sheet shows their state
## (UnitSheet — every editable thing on it is a slot), the workbench is
## downstream of whatever slot was clicked (UnitWorkbench). This screen is
## only the wiring between the three: selection flows right, mutations flow
## back left as refreshes.
##
## DEPLOYMENT flows through CampaignManager (already saved + read by
## BattleScene). On open, the carried selection is resolved against THIS
## roster and THIS map's cap (permadeath pruning, cap clamping, first-arrival
## seeding — RosterRail.resolved_deployment); every pip toggle writes straight
## back. No Begin Mission here: leaving for the mission is the hub's job.
class_name ManageUnitsScreen
extends Control


const TOP_BAR_HEIGHT: int = 16
const SHEET_WIDTH: int = 210
const BODY_MARGIN: int = 4
const COLUMN_GAP: int = 4
## The workspace dims the shared stage harder than the hub does (§2) — same
## ink as MenuStageBackdrop.DIM_COLOR, more of it.
const WORKSPACE_DIM_ALPHA: float = 0.8

## The bEXP deep link (§3g): the hub's "Allocate Bonus EXP" entry opens this
## screen with the rail sorted level-ASCENDING — the units the catch-up
## economy exists for are already on top. Static because SceneRouter can't
## carry arguments; consumed (and cleared) on _ready. Slice 4 extends the
## link to also preselect the level row.
static var open_sorted_by_level: bool = false


var _rail: RosterRail = null
var _sheet: UnitSheet = null
var _bexp_panel: BexpSpendPanel = null
var _workbench: UnitWorkbench = null
var _pool_value_label: Label = null
var _squad_value_label: Label = null

var _squad_cap: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_squad_cap = _read_squad_cap()
	_build_content()
	_seed_rail()
	SquadManager.bonus_xp_changed.connect(_on_pool_changed)
	if open_sorted_by_level:
		open_sorted_by_level = false
		_rail.set_sort("lv", true)
		# The deep link is "Allocate Bonus EXP" — land IN the spend view, not
		# a click away from it (§3g, extended by slice 4).
		_set_bexp_mode(true)


# =============================================================================
# PURE COPY RULES
# =============================================================================

## `4/6` when the map declares a cap, a bare count when it doesn't (cap 0 =
## unknown mission / no campaign — same convention as the old prep screen).
static func squad_readout(deployed: int, cap: int) -> String:
	if cap > 0:
		return "%d/%d" % [deployed, cap]
	return str(deployed)


# =============================================================================
# STATE
# =============================================================================

func _read_squad_cap() -> int:
	if not CampaignManager.is_active():
		return 0
	return TilemapGridBuilder.count_player_spawns(CampaignManager.get_current_mission_path())


## Resolve the carried deployment for this roster + map, hand it to the rail,
## and write the resolved form back so the hub and BattleScene see the same
## truth the pips show. An UNSET selection that resolves empty (no campaign /
## cap 0 unloadable map) shows everyone deployed WITHOUT writing — the legacy
## "unset = deploy everyone" read for editor previews. A CHOSEN empty one is
## the player's own 0/N and shows exactly that.
func _seed_rail() -> void:
	var roster: Array[CharacterData] = SquadManager.get_active_roster()
	var chosen: bool = CampaignManager.is_active() and CampaignManager.has_deployment()
	var deployed: Array[String] = RosterRail.resolved_deployment(
			roster, CampaignManager.get_deployment(), _squad_cap, chosen)
	if deployed.is_empty() and not chosen:
		for character: CharacterData in roster:
			deployed.append(character.character_id)
	elif CampaignManager.is_active():
		CampaignManager.set_deployment(deployed)
	_rail.set_state(roster, deployed, _squad_cap)
	_refresh_squad_label()
	_show_unit(_rail.get_selected_id())


func _on_deployment_changed(deployed_ids: Array[String]) -> void:
	if CampaignManager.is_active():
		CampaignManager.set_deployment(deployed_ids)
	_refresh_squad_label()
	# The stat lane's ACROSS THE SQUAD list reads the deployed set.
	_workbench.set_squad(_deployed_characters())


func _deployed_characters() -> Array[CharacterData]:
	var deployed: Array[CharacterData] = []
	for character: CharacterData in SquadManager.get_active_roster():
		if _rail.is_deployed(character.character_id):
			deployed.append(character)
	return deployed


func _refresh_squad_label() -> void:
	if _squad_value_label != null:
		_squad_value_label.text = squad_readout(_rail.deployed_count(), _squad_cap)


func _on_pool_changed(new_pool: int) -> void:
	if _pool_value_label != null:
		_pool_value_label.text = str(new_pool)


## Rail → sheet → workbench, in that order. The sheet keeps its slot-kind
## selection across the switch (§3b: click Move 2 on Max, click Ernesto in
## the rail — you're on Ernesto's Move 2), so the workbench re-shows the SAME
## lane for the new unit. In bEXP mode the spend panel rebinds instead —
## pouring into several units is one rail click each.
func _show_unit(character_id: String) -> void:
	var character: CharacterData = SquadManager.get_character_by_id(character_id)
	if character == null:
		return
	_sheet.set_character(character)
	if _bexp_panel.visible:
		_bexp_panel.bind(character)
	_workbench.set_squad(_deployed_characters())
	_workbench.show_lane(character, _sheet.get_selection_kind(), _sheet.get_selection_key())


# =============================================================================
# bEXP MODE (slice 4) — the sheet's column converts to the spend view
# =============================================================================

## "I don't like the idea of populating the third panel with a second stat
## screen, so maybe converting the center panel?" (RQD 2026-08-11) — the
## sheet and the spend panel share one column slot; exactly one is visible.
## Entered via the sheet's XP row, the top bar's bEXP readout, or the hub's
## deep link; exited via the panel's ✕, either trigger again, or Escape.
func _set_bexp_mode(active: bool) -> void:
	if active == _bexp_panel.visible:
		return
	_bexp_panel.visible = active
	_sheet.visible = not active
	if active:
		_bexp_panel.bind(SquadManager.get_character_by_id(_rail.get_selected_id()))
	else:
		# Leaving abandons any staged pour — only CONFIRM commits.
		_bexp_panel.discard_stage()


func _toggle_bexp_mode() -> void:
	_set_bexp_mode(not _bexp_panel.visible)


## A purchased level: rail readouts (Lv, sort) and the workbench's squad
## stats are stale — same fan-out as a sheet mutation, plus the sheet itself
## (its XP row and stat block re-read the character when it comes back).
func _on_bexp_spent() -> void:
	_rail.refresh()
	_sheet.refresh()
	_workbench.set_squad(_deployed_characters())
	_workbench.show_lane(SquadManager.get_character_by_id(_rail.get_selected_id()),
			_sheet.get_selection_kind(), _sheet.get_selection_key())


func _on_slot_selected(kind: String, key: Variant) -> void:
	var character: CharacterData = SquadManager.get_character_by_id(_rail.get_selected_id())
	_workbench.show_lane(character, kind, key)


## A sheet mutation (StatUp allocation): the rail's ★N badges and any open
## stat lane are now stale.
func _on_sheet_changed() -> void:
	_rail.refresh()
	_workbench.show_lane(SquadManager.get_character_by_id(_rail.get_selected_id()),
			_sheet.get_selection_kind(), _sheet.get_selection_key())


## A workbench commit (equip): the sheet's slot names are now stale.
func _on_workbench_changed() -> void:
	_sheet.refresh()
	_rail.refresh()


# =============================================================================
# BUILD
# =============================================================================

func _build_content() -> void:
	add_child(MenuStageBackdrop.new())
	var workspace_dim := ColorRect.new()
	workspace_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	workspace_dim.color = GameColors.with_alpha(MenuStageBackdrop.DIM_COLOR, WORKSPACE_DIM_ALPHA)
	workspace_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(workspace_dim)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_top_bar())

	var body_margin := MarginContainer.new()
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		body_margin.add_theme_constant_override(side, BODY_MARGIN)
	root.add_child(body_margin)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", COLUMN_GAP)
	body_margin.add_child(body)

	_rail = RosterRail.new()
	_rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rail.unit_selected.connect(_show_unit)
	_rail.deployment_changed.connect(_on_deployment_changed)
	body.add_child(_rail)

	_sheet = UnitSheet.new()
	_sheet.custom_minimum_size = Vector2(SHEET_WIDTH, 0)
	_sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet.slot_selected.connect(_on_slot_selected)
	_sheet.changed.connect(_on_sheet_changed)
	_sheet.bexp_requested.connect(func() -> void: _set_bexp_mode(true))
	body.add_child(_sheet)

	# The spend view shares the sheet's column slot — see _set_bexp_mode.
	_bexp_panel = BexpSpendPanel.new()
	_bexp_panel.custom_minimum_size = Vector2(SHEET_WIDTH, 0)
	_bexp_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bexp_panel.visible = false
	_bexp_panel.changed.connect(_on_bexp_spent)
	_bexp_panel.closed.connect(func() -> void: _set_bexp_mode(false))
	body.add_child(_bexp_panel)

	_workbench = UnitWorkbench.new()
	_workbench.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workbench.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_workbench.changed.connect(_on_workbench_changed)
	body.add_child(_workbench)


func _build_top_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, TOP_BAR_HEIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.HUD_PANEL_BACKGROUND
	style.border_color = GameColorPalette.get_color("Straw2", 3)
	style.border_width_bottom = 1
	style.content_margin_left = 6
	style.content_margin_right = 6
	bar.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	bar.add_child(row)

	# Bare glyphs over empty styleboxes, so the glow material on the Button
	# only ever glows text — the same trick the rail's sort links use.
	var back := Button.new()
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	back.text = "◀ Intermission"
	if UIManager.font_8px != null:
		back.add_theme_font_override("font", UIManager.font_8px)
	back.add_theme_font_size_override("font_size", 8)
	back.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	back.add_theme_color_override("font_hover_color",
			GameColors.brightened(GameColors.TEXT_PRIMARY))
	var back_material := (load("res://resources/hud_glow.tres") as Material).duplicate()
	(back_material as ShaderMaterial).set_shader_parameter("glow_color",
			GameColors.TEXT_PRIMARY_GLOW)
	back.material = back_material
	for state: String in ["normal", "hover", "pressed", "focus"]:
		back.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	back.pressed.connect(_on_back_pressed)
	row.add_child(back)

	row.add_child(_key_value_pair("MISSION", _mission_readout(),
			GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW, null))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var pool_holder: Array[Label] = []
	var pool_pair := _key_value_pair("bEXP", str(SquadManager.bonus_xp_pool),
			GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW, pool_holder)
	# The readout doubles as the bEXP-mode toggle (slice 4) — the labels
	# inside ignore mouse, so the pair itself takes the click.
	pool_pair.mouse_filter = Control.MOUSE_FILTER_STOP
	pool_pair.tooltip_text = "allocate bonus EXP"
	pool_pair.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			_toggle_bexp_mode())
	row.add_child(pool_pair)
	_pool_value_label = pool_holder[0]

	var squad_holder: Array[Label] = []
	row.add_child(_key_value_pair("SQUAD", "",
			GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW, squad_holder))
	_squad_value_label = squad_holder[0]
	return bar


func _mission_readout() -> String:
	if not CampaignManager.is_active():
		return "PREVIEW"
	return "%d OF %d" % [CampaignManager.get_current_mission_index() + 1,
			CampaignManager.get_mission_count()]


## `KEY value` — SECONDARY-voice key, semantic-voiced value (each with its
## orthogonal glow). When `value_out` is non-null the value label is appended
## to it so callers can keep a live handle.
func _key_value_pair(key_text: String, value_text: String, value_color: Color,
		value_glow: Color, value_out: Variant) -> HBoxContainer:
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 4)
	var key_label := GlowLabel.styled(key_text, UIManager.font_8px, 8,
			GameColors.TEXT_SECONDARY, GameColors.TEXT_SECONDARY_GLOW)
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pair.add_child(key_label)
	var value_label := GlowLabel.styled(value_text, UIManager.font_8px, 8,
			value_color, value_glow)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pair.add_child(value_label)
	if value_out is Array:
		(value_out as Array).append(value_label)
	return pair


# =============================================================================
# NAVIGATION
# =============================================================================

func _on_back_pressed() -> void:
	SceneRouter.change_scene_to(CampaignManager.INTERMISSION_PATH)


## Escape backs out one layer at a time: bEXP mode → sheet → hub (same
## direction the ◀ button points). Safe to claim here: InputManager's battle
## handlers are gated on grid readiness, and no battle grid exists behind
## this screen.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _bexp_panel != null and _bexp_panel.visible:
			_set_bexp_mode(false)
			return
		_on_back_pressed()
