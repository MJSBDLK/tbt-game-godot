## Central UI manager for the battle screen.
## Builds the 140-360-140 panel layout and manages all UI panels and overlays.
## Registered as Autoload "UIManager".
extends CanvasLayer


# Pixel font resources — loaded with pixel-perfect rendering settings
var font_8px: FontFile = null
var font_11px: FontFile = null
var font_5px: FontFile = null
var battle_theme: Theme = null

# Panel border textures (Lawrence's designs)
var _border_small: Texture2D = null       # 140x140 clean gray border
var _border_tall_left: Texture2D = null   # 140x218 with rivets (top-right, bottom-left)
var _border_tall_right: Texture2D = null  # 140x218 with rivets (bottom-left, top-left)
# 8-piece chopped border for arbitrary-size panels
var _border_corner_top_left: Texture2D = null
var _border_corner_top_right: Texture2D = null
var _border_corner_bottom_left: Texture2D = null
var _border_corner_bottom_right: Texture2D = null
var _border_edge_top: Texture2D = null
var _border_edge_right: Texture2D = null
var _border_edge_bottom: Texture2D = null
var _border_edge_left: Texture2D = null
# 8-piece fullscreen border for large/arbitrary-size panels
var _fullscreen_corner_top_left: Texture2D = null
var _fullscreen_corner_top_right: Texture2D = null
var _fullscreen_corner_bottom_left: Texture2D = null
var _fullscreen_corner_bottom_right: Texture2D = null
var _fullscreen_edge_top: Texture2D = null
var _fullscreen_edge_right: Texture2D = null
var _fullscreen_edge_bottom: Texture2D = null
var _fullscreen_edge_left: Texture2D = null
const BORDER_MARGIN: int = 10             # All borders are 10px on each side

# Layout containers
var _main_layout: Control = null
var _left_panel: VBoxContainer = null
var _center_area: Control = null
var _right_panel: VBoxContainer = null

# Panels
var _unit_info_panel: UnitPreviewPanel = null
var _terrain_info_panel: TerrainPreviewPanel = null
var _action_menu_panel: ActionMenuPanel = null
var _combat_preview_panel: CombatPreviewPanel = null
# Hint / command bar — bottom row of the HUD canvas (HintBar, built
# 2026-08-20). Self-driving: samples state + input model at boundaries.
var _hint_bar: HintBar = null

# Panel side state: when true, action/combat panels are on the left, info panels on the right.
var _action_panels_on_left: bool = false

# Overlays
var _overlay_layer: CanvasLayer = null
var _phase_transition_overlay: Node = null
var _battle_result_overlay: Node = null
var _unit_detail_panel: UnitDetailPanel = null
var _system_menu_panel: SystemMenuPanel = null
var _options_menu_panel: OptionsMenuPanel = null
var _save_browser_panel: SaveBrowserPanel = null
var _battle_result_panel: BattleResultPanel = null
var _level_up_report_panel: LevelUpReportPanel = null
var _bonus_xp_panel: BonusXpPanel = null
# Stashed between BattleResultPanel.closed → LevelUpReportPanel.show_report →
# BonusXpPanel.show_report, since each screen accepts the same payload but
# renders in sequence.
var _pending_post_mission_report: Array = []
# Outcome recorded by show_battle_result (which _end_battle calls before
# emitting battle_ended) so the banner played at the top of the post-mission
# chain knows what to say.
var _pending_result_is_victory: bool = true
# Full stats payload from show_battle_result (turns, kills, losses, totals),
# rendered by BattleResultPanel once the banner clears.
var _pending_battle_stats: Dictionary = {}
var _recruit_picker_panel: Node = null


func _ready() -> void:
	layer = 10
	_load_pixel_fonts()
	_load_border_textures()
	_build_theme()
	_build_layout()
	_build_overlay_layer()
	_instantiate_panels()
	_instantiate_overlays()
	var state_manager := get_node_or_null("/root/GameStateManager")
	if state_manager != null:
		state_manager.state_changed.connect(_on_state_changed)
	DebugConfig.log_pixel_perfect_ui("UIManager: Initialized with 140-360-140 layout")


# =============================================================================
# PUBLIC API — UNIT INFO
# =============================================================================

func show_unit_info(unit: Node) -> void:
	if _unit_info_panel == null:
		return
	if not _is_map_view_active():
		return
	# Info panels live in _left_panel by default. _place_action_panels(true)
	# moves _left_panel to the RIGHT side, so we want on_left=true when the
	# previewed unit is on the LEFT half — info panels flip away from the unit.
	_place_action_panels(not _unit_is_in_right_half(unit))
	_unit_info_panel.show_unit(unit as Unit)


func hide_unit_info() -> void:
	if _unit_info_panel == null:
		return
	_unit_info_panel.hide_panel()


func get_previewed_unit() -> Unit:
	if _unit_info_panel == null:
		return null
	return _unit_info_panel.get_tracked_unit()


# =============================================================================
# PUBLIC API — TERRAIN INFO
# =============================================================================

func show_terrain_info(tile: Variant) -> void:
	if _terrain_info_panel == null:
		return
	if not _is_map_view_active():
		return
	# Info panels live in _left_panel by default. Invert the side test so info
	# panels move to the side opposite the hovered tile.
	if tile != null:
		_place_action_panels(not _tile_is_in_right_half(tile))
	_terrain_info_panel.show_tile(tile)


func hide_terrain_info() -> void:
	if _terrain_info_panel == null:
		return
	_terrain_info_panel.hide_panel()


# =============================================================================
# PUBLIC API — ACTION MENU
# =============================================================================

func show_action_menu(unit: Node) -> void:
	if _action_menu_panel == null:
		return
	# Unit info and terrain info never show alongside the action menu or combat preview
	if _unit_info_panel != null:
		_unit_info_panel.hide_panel()
	if _terrain_info_panel != null:
		_terrain_info_panel.hide_panel()
	if unit != null:
		_place_action_panels(_unit_is_in_right_half(unit))
	_action_menu_panel.show_menu(unit as Unit)


func hide_action_menu() -> void:
	if _action_menu_panel == null:
		return
	_action_menu_panel.hide_menu()


func get_hint_bar() -> HintBar:
	return _hint_bar


func get_action_menu_panel() -> Node:
	return _action_menu_panel


# =============================================================================
# PUBLIC API — COMBAT PREVIEW
# =============================================================================

func show_combat_preview(attacker: Node, defender: Node, move: Move) -> void:
	if _combat_preview_panel == null:
		return
	# Unit info and terrain info never show alongside the action menu or combat preview
	if _unit_info_panel != null:
		_unit_info_panel.hide_panel()
	if _terrain_info_panel != null:
		_terrain_info_panel.hide_panel()
	if attacker != null:
		_place_action_panels(_unit_is_in_right_half(attacker))
	_combat_preview_panel.show_preview(attacker as Unit, defender as Unit, move)


func show_heal_preview(caster: Node, target: Node, move: Move, heal_amount: int) -> void:
	if _combat_preview_panel == null:
		return
	if _unit_info_panel != null:
		_unit_info_panel.hide_panel()
	if _terrain_info_panel != null:
		_terrain_info_panel.hide_panel()
	if caster != null:
		_place_action_panels(_unit_is_in_right_half(caster))
	_combat_preview_panel.show_heal_preview(caster as Unit, target as Unit, move, heal_amount)


func hide_combat_preview() -> void:
	if _combat_preview_panel == null:
		return
	_combat_preview_panel.hide_panel()


# =============================================================================
# PUBLIC API — UNIT DETAIL
# =============================================================================

func show_unit_detail(unit: Unit) -> void:
	if _unit_detail_panel == null:
		return
	_unit_detail_panel.show_unit(unit)


func hide_unit_detail() -> void:
	if _unit_detail_panel == null:
		return
	_unit_detail_panel.hide_panel()


func is_unit_detail_visible() -> bool:
	return _unit_detail_panel != null and _unit_detail_panel.visible


# =============================================================================
# PUBLIC API — SYSTEM MENU
# =============================================================================

func show_system_menu() -> void:
	if _system_menu_panel == null:
		return
	_place_system_menu()
	_system_menu_panel.show_menu()


func hide_system_menu() -> void:
	if _system_menu_panel == null:
		return
	_system_menu_panel.hide_menu()


# =============================================================================
# PUBLIC API — OPTIONS MENU
# =============================================================================

func show_options_menu() -> void:
	if _options_menu_panel == null:
		return
	_options_menu_panel.show_panel()


func hide_options_menu() -> void:
	if _options_menu_panel == null:
		return
	_options_menu_panel.hide_panel()


# =============================================================================
# PUBLIC API — OVERLAYS
# =============================================================================

func show_phase_transition(text: String, color: Color) -> void:
	if _phase_transition_overlay != null and _phase_transition_overlay.has_method("show_transition"):
		await _phase_transition_overlay.show_transition(text, color)


func show_battle_result(is_victory: bool, turn_count: int, player_units_lost: int,
		enemies_defeated: int, total_players: int, total_enemies: int) -> void:
	# Push BATTLE_RESULT — the state-changed handler tears down any in-flight
	# map UI and _is_map_view_active() returns false from this point.
	var state_manager := get_node_or_null("/root/GameStateManager")
	if state_manager != null and state_manager.current_state != Enums.InputState.BATTLE_RESULT:
		state_manager.push_state(Enums.InputState.BATTLE_RESULT)
	# Belt-and-suspenders teardown of map-side panels. The state-changed
	# handler already does this, but if we re-entered BATTLE_RESULT (push
	# above was skipped) the handler never fires — and these panels would
	# otherwise linger underneath the result overlay.
	hide_unit_info()
	hide_terrain_info()
	hide_action_menu()
	hide_combat_preview()
	hide_unit_detail()
	# Record the outcome + stats for the chain. _end_battle calls this BEFORE
	# emitting battle_ended, so both are always fresh when the post-mission
	# chain (_on_post_mission_report_ready) reads them.
	_pending_result_is_victory = is_victory
	_pending_battle_stats = {
		"is_victory": is_victory,
		"turn_count": turn_count,
		"player_units_lost": player_units_lost,
		"enemies_defeated": enemies_defeated,
		"total_players": total_players,
		"total_enemies": total_enemies,
	}
	# The legacy stats overlay is DELIBERATELY NOT shown. The post-mission
	# chain suppresses it via hide_battle_result() in the same frame anyway
	# (its Continue button has no listeners — dead UI, superseded by
	# BattleResultPanel). Showing it after an awaited banner resurrected
	# it as an undismissable zombie underneath the bEXP screen (2026-07-07).


func hide_battle_result() -> void:
	if _battle_result_overlay != null and _battle_result_overlay.has_method("hide_result"):
		_battle_result_overlay.hide_result()
	var state_manager := get_node_or_null("/root/GameStateManager")
	if state_manager != null and state_manager.current_state == Enums.InputState.BATTLE_RESULT:
		state_manager.pop_state()


## Mid-battle level-up celebration (RQD 2026-08-11): a stats-exclusive cut of
## the detail panel, awaited so the combat sequence holds while the reveal
## plays. `before` is LevelUpStatPanel.stat_snapshot taken pre-grant. Safe to
## call from any combat context — returns immediately on bad input.
func show_level_up_celebration(character_data: CharacterData, before: Dictionary) -> void:
	if character_data == null or before.is_empty():
		return
	var panel := LevelUpStatPanel.new()
	add_child(panel)
	panel.present(character_data, before)
	await panel.finished
	panel.queue_free()


## Show the recruit picker with the given candidate JSON paths and await the
## user's choice. Returns the chosen path, or "" if the picker can't be shown
## (caller should treat that as "skip recruitment, keep going").
func show_recruit_picker_and_wait(candidate_paths: Array[String]) -> String:
	if _recruit_picker_panel == null or candidate_paths.is_empty():
		return ""
	if not _recruit_picker_panel.has_method("show_candidates"):
		push_warning("UIManager: recruit picker panel missing show_candidates method")
		return ""
	var state_manager := get_node_or_null("/root/GameStateManager")
	if state_manager != null:
		state_manager.push_state(Enums.InputState.RECRUITING)
	_recruit_picker_panel.show_candidates(candidate_paths)
	var chosen_path: String = await _recruit_picker_panel.recruit_chosen
	if state_manager != null and state_manager.current_state == Enums.InputState.RECRUITING:
		state_manager.pop_state()
	return chosen_path


# =============================================================================
# PUBLIC API — GENERAL
# =============================================================================

func refresh() -> void:
	if _unit_info_panel != null:
		_unit_info_panel.refresh()


# =============================================================================
# FONT LOADING — Pixel-perfect font configuration
# =============================================================================

func _load_pixel_fonts() -> void:
	font_8px = _create_pixel_font("res://fonts/UndeadPixelLight8.ttf")
	font_11px = _create_pixel_font("res://fonts/UndeadPixelLight11.ttf")
	font_5px = _create_pixel_font("res://fonts/NotJamPixel5.ttf")
	DebugConfig.log_pixel_perfect_ui("UIManager: Loaded 3 pixel fonts (8px, 11px, 5px)")


func _create_pixel_font(path: String) -> FontFile:
	var font := FontFile.new()
	font.data = FileAccess.get_file_as_bytes(path)
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.oversampling = 1.0
	return font


# =============================================================================
# THEME BUILDING
# =============================================================================

func _build_theme() -> void:
	battle_theme = Theme.new()

	# Default font: 8px pixel font
	battle_theme.default_font = font_8px
	battle_theme.default_font_size = 8

	# Label defaults
	battle_theme.set_font("font", "Label", font_8px)
	battle_theme.set_font_size("font_size", "Label", 8)
	battle_theme.set_color("font_color", "Label", GameColors.TEXT_PRIMARY)

	# Button defaults
	battle_theme.set_font("font", "Button", font_8px)
	battle_theme.set_font_size("font_size", "Button", 8)
	battle_theme.set_color("font_color", "Button", GameColors.TEXT_PRIMARY)
	battle_theme.set_color("font_hover_color", "Button", Color.WHITE)
	battle_theme.set_color("font_pressed_color", "Button", GameColors.TEXT_SECONDARY)

	# Button styles
	var button_normal := StyleBoxFlat.new()
	button_normal.bg_color = GameColors.BUTTON_NORMAL
	button_normal.border_color = GameColors.MENU_BORDER
	button_normal.set_border_width_all(1)
	button_normal.set_content_margin_all(2)
	battle_theme.set_stylebox("normal", "Button", button_normal)

	var button_hover := StyleBoxFlat.new()
	button_hover.bg_color = GameColors.BUTTON_HOVERED
	button_hover.border_color = GameColors.MENU_BORDER
	button_hover.set_border_width_all(1)
	button_hover.set_content_margin_all(2)
	battle_theme.set_stylebox("hover", "Button", button_hover)

	var button_pressed := StyleBoxFlat.new()
	button_pressed.bg_color = GameColors.BUTTON_PRESSED
	button_pressed.border_color = GameColors.MENU_BORDER
	button_pressed.set_border_width_all(1)
	button_pressed.set_content_margin_all(2)
	battle_theme.set_stylebox("pressed", "Button", button_pressed)

	# PanelContainer style — transparent by default (panels set their own)
	var panel_empty := StyleBoxEmpty.new()
	battle_theme.set_stylebox("panel", "PanelContainer", panel_empty)

	DebugConfig.log_pixel_perfect_ui("UIManager: Theme built with pixel fonts")


# =============================================================================
# LAYOUT BUILDING — 140-360-140 three-panel layout
# =============================================================================

func _build_layout() -> void:
	_main_layout = Control.new()
	_main_layout.name = "MainLayout"
	_main_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_layout.theme = battle_theme
	add_child(_main_layout)

	# Left panel (anchored left, 140px wide, full height)
	_left_panel = VBoxContainer.new()
	_left_panel.name = "LeftPanel"
	_left_panel.custom_minimum_size = Vector2(140, 0)
	_left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_panel.add_theme_constant_override("separation", 4)
	_main_layout.add_child(_left_panel)
	_left_panel.anchor_left = 0.0
	_left_panel.anchor_right = 0.0
	_left_panel.anchor_top = 0.0
	_left_panel.anchor_bottom = 1.0
	_left_panel.offset_left = 0
	_left_panel.offset_right = 140
	_left_panel.offset_top = 0
	_left_panel.offset_bottom = 0

	# Center area (transparent, mouse-passthrough)
	_center_area = Control.new()
	_center_area.name = "CenterArea"
	_center_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_layout.add_child(_center_area)
	_center_area.anchor_left = 0.0
	_center_area.anchor_right = 1.0
	_center_area.anchor_top = 0.0
	_center_area.anchor_bottom = 1.0
	_center_area.offset_left = 140
	_center_area.offset_right = -140
	_center_area.offset_top = 0
	_center_area.offset_bottom = 0

	# Right panel (anchored right, 140px wide, full height)
	_right_panel = VBoxContainer.new()
	_right_panel.name = "RightPanel"
	_right_panel.custom_minimum_size = Vector2(140, 0)
	_right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_panel.add_theme_constant_override("separation", 4)
	_main_layout.add_child(_right_panel)
	_right_panel.anchor_left = 1.0
	_right_panel.anchor_right = 1.0
	_right_panel.anchor_top = 0.0
	_right_panel.anchor_bottom = 1.0
	_right_panel.offset_left = -140
	_right_panel.offset_right = 0
	_right_panel.offset_top = 0
	_right_panel.offset_bottom = 0


func _build_overlay_layer() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "OverlayLayer"
	_overlay_layer.layer = 11
	add_child(_overlay_layer)


# =============================================================================
# PANEL / OVERLAY INSTANTIATION
# =============================================================================

func _instantiate_panels() -> void:
	# Unit info panel (left, top)
	var unit_info_scene := load("res://scenes/ui/panels/unit_preview_panel/unit_preview_panel.tscn")
	if unit_info_scene != null:
		_unit_info_panel = unit_info_scene.instantiate() as UnitPreviewPanel
		_left_panel.add_child(_unit_info_panel)

	# Terrain preview panel (left, bottom)
	var terrain_info_scene := load("res://scenes/ui/panels/terrain_preview_panel/terrain_preview_panel.tscn")
	if terrain_info_scene != null:
		_terrain_info_panel = terrain_info_scene.instantiate() as TerrainPreviewPanel
		_left_panel.add_child(_terrain_info_panel)

	# Action menu panel (right, top)
	var action_menu_scene := load("res://scenes/ui/panels/action_menu_panel.tscn")
	if action_menu_scene != null:
		_action_menu_panel = action_menu_scene.instantiate() as ActionMenuPanel
		_right_panel.add_child(_action_menu_panel)

	# Combat preview panel (right, below action menu)
	var combat_preview_scene := load("res://scenes/ui/panels/combat_preview_panel/combat_preview_panel.tscn")
	if combat_preview_scene != null:
		_combat_preview_panel = combat_preview_scene.instantiate() as CombatPreviewPanel
		_right_panel.add_child(_combat_preview_panel)

	# Hint / command bar — full-rect child of the main layout, positions its own
	# bottom row; added AFTER the side columns so it draws over them.
	_hint_bar = HintBar.new()
	_hint_bar.name = "HintBar"
	_main_layout.add_child(_hint_bar)

	# System menu panel — anchored directly to main layout (not in a VBox)
	# so it can anchor to either screen edge without clipping the border.
	_system_menu_panel = SystemMenuPanel.new()
	_main_layout.add_child(_system_menu_panel)
	_place_system_menu()
	_system_menu_panel.closed.connect(_on_system_menu_closed)
	_system_menu_panel.end_turn_selected.connect(_on_system_menu_end_turn)
	_system_menu_panel.options_selected.connect(_on_system_menu_options)
	_system_menu_panel.save_selected.connect(_on_system_menu_save)
	_system_menu_panel.load_selected.connect(_on_system_menu_load)
	_system_menu_panel.main_menu_selected.connect(_on_system_menu_main_menu)
	_system_menu_panel.quit_selected.connect(_on_system_menu_quit)

	# Options menu panel — centered overlay
	_options_menu_panel = OptionsMenuPanel.new()
	_options_menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	_options_menu_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_options_menu_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_overlay_layer.add_child(_options_menu_panel)
	_options_menu_panel.closed.connect(_on_options_menu_closed)

	# Save browser — centered overlay, same shell recipe as the options menu
	_save_browser_panel = SaveBrowserPanel.new()
	_save_browser_panel.set_anchors_preset(Control.PRESET_CENTER)
	_save_browser_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_save_browser_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_overlay_layer.add_child(_save_browser_panel)
	_save_browser_panel.closed.connect(_on_save_browser_closed)
	_save_browser_panel.save_chosen.connect(_on_save_browser_chosen)


func _instantiate_overlays() -> void:
	# Phase transition overlay
	var phase_scene := load("res://scenes/ui/overlays/phase_transition_overlay.tscn")
	if phase_scene != null:
		_phase_transition_overlay = phase_scene.instantiate()
		_overlay_layer.add_child(_phase_transition_overlay)

	# Battle result overlay
	var result_scene := load("res://scenes/ui/overlays/battle_result_overlay.tscn")
	if result_scene != null:
		_battle_result_overlay = result_scene.instantiate()
		_overlay_layer.add_child(_battle_result_overlay)

	# Unit detail panel (fullscreen overlay)
	var unit_detail_scene := load("res://scenes/ui/panels/unit_detail_panel/unit_info_panel.tscn")
	if unit_detail_scene != null:
		_unit_detail_panel = unit_detail_scene.instantiate() as UnitDetailPanel
		_unit_detail_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_unit_detail_panel.position = Vector2(10, 10)  # Border offset
		_unit_detail_panel.visible = false
		_overlay_layer.add_child(_unit_detail_panel)
		_unit_detail_panel.closed.connect(_on_unit_detail_closed)

	# Post-mission flow: BattleResultPanel → LevelUpReportPanel → BonusXpPanel.
	# Each step self-skips if its preconditions don't fire (no level-ups,
	# zero bEXP pool, etc.), so the chain falls through naturally on defeat
	# or for first-mission victories where there's nothing to celebrate.
	var battle_result_scene := load("res://scenes/ui/panels/battle_result_panel.tscn")
	if battle_result_scene != null:
		_battle_result_panel = battle_result_scene.instantiate() as BattleResultPanel
		_overlay_layer.add_child(_battle_result_panel)
		_battle_result_panel.closed.connect(_on_battle_result_panel_closed)

	var level_up_scene := load("res://scenes/ui/panels/level_up_report_panel.tscn")
	if level_up_scene != null:
		_level_up_report_panel = level_up_scene.instantiate() as LevelUpReportPanel
		_overlay_layer.add_child(_level_up_report_panel)
		_level_up_report_panel.closed.connect(_on_level_up_report_closed)

	var bonus_xp_scene := load("res://scenes/ui/panels/bonus_xp_panel.tscn")
	if bonus_xp_scene != null:
		_bonus_xp_panel = bonus_xp_scene.instantiate() as BonusXpPanel
		_overlay_layer.add_child(_bonus_xp_panel)
		_bonus_xp_panel.closed.connect(_on_bonus_xp_closed)

	var squad_manager: Node = get_node_or_null("/root/SquadManager")
	if squad_manager and squad_manager.has_signal("post_mission_report_ready"):
		squad_manager.post_mission_report_ready.connect(_on_post_mission_report_ready)

	# Recruit picker panel (between-missions choice of N candidates)
	var recruit_picker_scene := load("res://scenes/ui/panels/recruit_picker_panel.tscn")
	if recruit_picker_scene != null:
		_recruit_picker_panel = recruit_picker_scene.instantiate()
		_overlay_layer.add_child(_recruit_picker_panel)


## Entry point for the post-mission flow. Chain (reordered 2026-08-03 —
## results FIRST: the player learns what happened before being asked to
## celebrate or spend):
##   battle_ended signal → _on_post_mission_report_ready (this)
##     → banner ("VICTORY"/"DEFEAT", no numbers) — awaited, blocks the chain
##     → BattleResultPanel.show_result() — turns vs par, itemized bEXP
##         income, kills/losses, injuries/permadeath.
##     → _on_battle_result_panel_closed → LevelUpReportPanel.show_report() —
##         celebrates leveled characters. Self-skips if no one leveled.
##     → _on_level_up_report_closed → BonusXpPanel.show_report() — spend
##         accumulated bEXP on individual characters' experience.
##         Self-skips if bonus_xp_pool == 0.
##     → _on_bonus_xp_closed → _finish_post_mission_flow() — state pop,
##         campaign concludes (victory advances, defeat replays).
func _on_post_mission_report_ready(report: Array) -> void:
	# Suppress the legacy battle-result overlay so its Continue button doesn't
	# compete with the post-mission panel (they share the same overlay layer).
	hide_battle_result()
	var state_manager := get_node_or_null("/root/GameStateManager")
	if state_manager != null and state_manager.current_state != Enums.InputState.POST_MISSION_REPORT:
		state_manager.push_state(Enums.InputState.POST_MISSION_REPORT)
	# Belt-and-suspenders map-panel teardown (mirrors show_battle_result): if
	# POST_MISSION_REPORT was already on the stack the push above is skipped,
	# the state-changed handler never fires, and a hovered terrain preview
	# would sit under the level-up → bEXP → report chain.
	hide_unit_info()
	hide_terrain_info()
	hide_action_menu()
	hide_combat_preview()
	hide_unit_detail()

	_pending_post_mission_report = report
	# Banner-first flow (Lawrence, playtesting): the FIRST thing the player
	# sees at battle end is a bare "VICTORY"/"DEFEAT" riding the phase banner —
	# no numbers, no buttons. The await here holds back the entire level-up →
	# bEXP → report chain until the banner clears; map input is already dead
	# because POST_MISSION_REPORT was pushed above. This must live HERE, not in
	# show_battle_result — the chain starts off battle_ended and would race a
	# banner played anywhere else (it did: bEXP screen over the banner).
	var banner_color: Color = GameColors.PLAYER_UNIT if _pending_result_is_victory \
			else GameColors.ENEMY_UNIT
	await show_phase_transition(
			"VICTORY" if _pending_result_is_victory else "DEFEAT", banner_color)
	if _battle_result_panel != null:
		_battle_result_panel.show_result(_pending_battle_stats,
				SquadManager.last_mission_award_lines, report)
	else:
		_show_level_up_report()


func _on_battle_result_panel_closed() -> void:
	_show_level_up_report()


func _show_level_up_report() -> void:
	if _level_up_report_panel != null:
		# LevelUpReportPanel filters internally; if nobody leveled it emits
		# `closed` immediately and the chain continues without delay.
		_level_up_report_panel.show_report(_pending_post_mission_report)
	else:
		_show_bonus_xp_panel()


func _on_level_up_report_closed() -> void:
	_show_bonus_xp_panel()


func _show_bonus_xp_panel() -> void:
	if _bonus_xp_panel == null:
		_finish_post_mission_flow()
		return
	# BonusXpPanel.show_report self-skips when the pool is empty — no need
	# to peek at SquadManager.bonus_xp_pool here.
	_bonus_xp_panel.show_report(_pending_post_mission_report)


func _on_bonus_xp_closed() -> void:
	_finish_post_mission_flow()


## End of the post-mission chain: release the input state and hand the
## outcome to CampaignManager (victory advances, defeat replays — its call).
## Absorbed from the retired PostMissionReportPanel, which used to own this.
func _finish_post_mission_flow() -> void:
	_pending_post_mission_report = []
	var state_manager := get_node_or_null("/root/GameStateManager")
	if state_manager != null and state_manager.current_state == Enums.InputState.POST_MISSION_REPORT:
		state_manager.pop_state()
	var campaign_manager: Node = get_node_or_null("/root/CampaignManager")
	if campaign_manager != null and campaign_manager.is_active():
		campaign_manager.conclude_mission(_pending_result_is_victory)
	else:
		# No active campaign (e.g. launched a map directly from the editor).
		# Fall back to the start screen so the player can pick a campaign.
		SceneRouter.change_scene_to("res://scenes/ui/start_screen.tscn")


# =============================================================================
# PANEL SIDE MANAGEMENT
# =============================================================================

## Move the action/combat panels to the left or right side based on where the
## active unit will appear after the camera finishes panning.
func _place_action_panels(on_left: bool) -> void:
	if on_left == _action_panels_on_left:
		return
	_action_panels_on_left = on_left

	if on_left:
		# Action panels move to left side; info panels move to right side.
		_right_panel.anchor_left = 0.0
		_right_panel.anchor_right = 0.0
		_right_panel.offset_left = 0
		_right_panel.offset_right = 140
		_left_panel.anchor_left = 1.0
		_left_panel.anchor_right = 1.0
		_left_panel.offset_left = -140
		_left_panel.offset_right = 0
	else:
		# Restore default: info panels on left, action panels on right.
		_left_panel.anchor_left = 0.0
		_left_panel.anchor_right = 0.0
		_left_panel.offset_left = 0
		_left_panel.offset_right = 140
		_right_panel.anchor_left = 1.0
		_right_panel.anchor_right = 1.0
		_right_panel.offset_left = -140
		_right_panel.offset_right = 0


## Anchors the system menu panel to the correct screen edge.
## The panel's outer corner (including border) sits at the screen corner,
## growing inward to fit its content — no hardcoded width.
func _place_system_menu() -> void:
	if _system_menu_panel == null:
		return
	# Pin to a corner point; the panel's minimum size determines the actual rect.
	# grow_horizontal controls which direction it expands from the anchor.
	_system_menu_panel.anchor_top = 0.0
	_system_menu_panel.anchor_bottom = 0.0
	_system_menu_panel.offset_top = 0
	_system_menu_panel.offset_bottom = 0
	_system_menu_panel.offset_left = 0
	_system_menu_panel.offset_right = 0
	if _action_panels_on_left:
		_system_menu_panel.anchor_left = 0.0
		_system_menu_panel.anchor_right = 0.0
		_system_menu_panel.grow_horizontal = Control.GROW_DIRECTION_END
	else:
		_system_menu_panel.anchor_left = 1.0
		_system_menu_panel.anchor_right = 1.0
		_system_menu_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN


## Returns true if the unit's world position will appear in the right half of the
## screen after the camera finishes panning (uses target_position, not current).
## Anchored on current_tile when the unit has one: under ACT_THEN_WALK
## (Settings.move_commit_mode) the sprite lags at the origin while the plan —
## ghost, ranges, the camera's frame — lives on the tile, and the panel must
## dodge THAT. The two agree everywhere else.
func _unit_is_in_right_half(unit: Node) -> bool:
	var node2d := unit as Node2D
	if node2d == null:
		return false
	var tile := unit.get("current_tile") as Node2D
	var anchor: Vector2 = tile.global_position if tile != null else node2d.global_position
	return _world_pos_is_in_right_half(anchor)


## Shared half-of-screen test used by both unit-info and terrain-info side-flipping.
##
## The world and HUD viewports occupy the same physical screen area, so "is the
## world point right of center?" reduces to "is it right of the camera's target
## X?" — viewport widths and zoom cancel out of the sign comparison.
func _world_pos_is_in_right_half(world_pos: Vector2) -> bool:
	var cam := _get_camera()
	if cam == null:
		return false
	return world_pos.x > cam.target_position.x


func _tile_is_in_right_half(tile: Variant) -> bool:
	if tile == null:
		return false
	var node2d := tile as Node2D
	if node2d == null:
		return false
	return _world_pos_is_in_right_half(node2d.global_position)


func _get_camera() -> CameraController:
	# UIManager lives in HUDViewport; the world camera lives in the root
	# viewport (WorldRoot's tree). Go through SceneRouter so we don't depend
	# on tree paths.
	return SceneRouter.get_world_camera() as CameraController


## Returns true when the map view is interactive — the only condition under
## which info panels (unit info, terrain info) should render.
##
## Primary gate is scene-presence: if a BattleScene isn't mounted, there's no
## map to preview, full stop. This makes new non-battle screens (the
## intermission, StartScreen, future overlays) inherently safe — they can't accidentally leak
## map UI by forgetting to push a state. The InputState check stacks on top to
## suppress panels during in-battle modals (ACTION_MENU_OPEN, etc.).
func _is_map_view_active() -> bool:
	if SceneRouter == null or not (SceneRouter.get_current_scene() is BattleScene):
		return false
	var state_manager := get_node_or_null("/root/GameStateManager")
	if state_manager == null:
		return true
	return state_manager.current_state in Enums.MAP_VIEW_STATES


# =============================================================================
# STATE MACHINE — panel visibility driven by GameStateManager
# =============================================================================

func _on_state_changed(_old_state: Enums.InputState, new_state: Enums.InputState) -> void:
	match new_state:
		Enums.InputState.DEFAULT, Enums.InputState.UNIT_SELECTED, Enums.InputState.MOVEMENT_PLANNING:
			hide_action_menu()
			hide_combat_preview()
			hide_unit_detail()
			hide_system_menu()
			hide_options_menu()
		Enums.InputState.ACTION_MENU_OPEN:
			hide_unit_info()
			hide_terrain_info()
			hide_combat_preview()
			hide_unit_detail()
			hide_system_menu()
			hide_options_menu()
		Enums.InputState.ATTACK_TARGETING:
			hide_unit_info()
			hide_terrain_info()
			hide_action_menu()
			hide_unit_detail()
			hide_system_menu()
			hide_options_menu()
		Enums.InputState.UNIT_DETAIL:
			hide_unit_info()
			hide_terrain_info()
			hide_action_menu()
			hide_combat_preview()
			hide_system_menu()
			hide_options_menu()
		Enums.InputState.PAUSED:
			hide_unit_info()
			hide_terrain_info()
			hide_action_menu()
			hide_combat_preview()
			hide_unit_detail()
		Enums.InputState.BATTLE_RESULT, Enums.InputState.POST_MISSION_REPORT, \
		Enums.InputState.RECRUITING:
			hide_unit_info()
			hide_terrain_info()
			hide_action_menu()
			hide_combat_preview()
			hide_unit_detail()
			hide_system_menu()
			hide_options_menu()


func _on_unit_detail_closed() -> void:
	var state_manager := get_node_or_null("/root/GameStateManager")
	# Guard: only pop if we're actually in UNIT_DETAIL state.
	# The state handler also calls hide_unit_detail() which re-emits closed.
	if state_manager != null and state_manager.current_state == Enums.InputState.UNIT_DETAIL:
		state_manager.pop_state()


func _on_system_menu_closed() -> void:
	var state_manager := get_node_or_null("/root/GameStateManager")
	if state_manager != null and state_manager.current_state == Enums.InputState.PAUSED:
		state_manager.pop_state()


func _on_system_menu_end_turn() -> void:
	hide_system_menu()
	var turn_manager := get_node_or_null("/root/TurnManager")
	if turn_manager != null and turn_manager.is_player_phase():
		turn_manager.force_end_player_turn()


func _on_system_menu_options() -> void:
	# Hide system menu panel without emitting closed (stay in PAUSED state)
	if _system_menu_panel != null:
		_system_menu_panel.visible = false
	show_options_menu()


func _on_system_menu_save() -> void:
	# Menu stays open; the Save row itself flashes the outcome.
	var path: String = SaveManager.write_manual_save()
	if _system_menu_panel != null:
		_system_menu_panel.flash_save_result(not path.is_empty())


func _on_system_menu_load() -> void:
	# Same dance as Options: hide without emitting closed (stay PAUSED),
	# browser's own closed signal brings the menu back.
	if _system_menu_panel != null:
		_system_menu_panel.visible = false
	if _save_browser_panel != null:
		_save_browser_panel.show_panel()


func _on_save_browser_closed() -> void:
	# Return to the system menu — but only if still PAUSED (a chosen save
	# changes scene and resets state; don't resurrect the menu over the load).
	var state_manager := get_node_or_null("/root/GameStateManager")
	if state_manager != null and state_manager.current_state == Enums.InputState.PAUSED:
		if _system_menu_panel != null:
			_system_menu_panel.show_menu()


func _on_save_browser_chosen(path: String) -> void:
	# Hide WITHOUT closed (hide_panel would re-show the system menu over the
	# scene change); load_save_and_continue handles the routing from here.
	if _save_browser_panel != null:
		_save_browser_panel.visible = false
	if not SaveManager.load_save_and_continue(path):
		push_warning("UIManager: failed to load save '%s'" % path)
		if _save_browser_panel != null:
			_save_browser_panel.show_panel()


func _on_options_menu_closed() -> void:
	# Return to system menu — but only if still in PAUSED state
	# (state transition handler also calls hide_options_menu which emits closed)
	var state_manager := get_node_or_null("/root/GameStateManager")
	if state_manager != null and state_manager.current_state == Enums.InputState.PAUSED:
		if _system_menu_panel != null:
			_system_menu_panel.show_menu()


## Battle → start screen. Closing the menu first is what unwinds the state
## machine (closed → pop PAUSED → DEFAULT, the same state the game boots in);
## BattleScene._exit_tree clears the grid when the scene swaps, exactly as on
## a mid-battle load. CampaignManager stays active on purpose — the start
## screen's Continue/Load are how the player gets back.
func _on_system_menu_main_menu() -> void:
	hide_system_menu()
	SceneRouter.change_scene_to(CampaignManager.START_SCREEN_PATH)


func _on_system_menu_quit() -> void:
	get_tree().quit()


## Hides a panel node by setting visible = false directly.
## Use this instead of calling hide_panel() to avoid dependency on method names.
func _hide_panel_node(panel: Node) -> void:
	if panel != null:
		panel.visible = false


# =============================================================================
# BORDER TEXTURE LOADING
# =============================================================================

func _load_border_textures() -> void:
	_border_small = _load_texture("res://art/sprites/ui/hud_panel/panel_border_small.png")
	_border_tall_left = _load_texture("res://art/sprites/ui/hud_panel/panel_border_tall.png")
	_border_tall_right = _load_texture("res://art/sprites/ui/hud_panel/panel_border_tall_right.png")
	# 8-piece chopped border for arbitrary-size panels
	_border_corner_top_left = _load_texture("res://art/sprites/ui/hud_panel/hud_panel_top_left.png")
	_border_corner_top_right = _load_texture("res://art/sprites/ui/hud_panel/hud_panel_top_right.png")
	_border_corner_bottom_left = _load_texture("res://art/sprites/ui/hud_panel/hud_panel_bottom_left.png")
	_border_corner_bottom_right = _load_texture("res://art/sprites/ui/hud_panel/hud_panel_bottom_right.png")
	_border_edge_top = _load_texture("res://art/sprites/ui/hud_panel/hud_panel_top.png")
	_border_edge_right = _load_texture("res://art/sprites/ui/hud_panel/hud_panel_right.png")
	_border_edge_bottom = _load_texture("res://art/sprites/ui/hud_panel/hud_panel_bottom.png")
	_border_edge_left = _load_texture("res://art/sprites/ui/hud_panel/hud_panel_left.png")
	# 8-piece fullscreen border
	_fullscreen_corner_top_left = _load_texture("res://art/sprites/ui/hud_panel_fullscreen/hud_border_top_left.png")
	_fullscreen_corner_top_right = _load_texture("res://art/sprites/ui/hud_panel_fullscreen/hud_border_top_right.png")
	_fullscreen_corner_bottom_left = _load_texture("res://art/sprites/ui/hud_panel_fullscreen/hud_border_bottom_left.png")
	_fullscreen_corner_bottom_right = _load_texture("res://art/sprites/ui/hud_panel_fullscreen/hud_border_bottom_right.png")
	_fullscreen_edge_top = _load_texture("res://art/sprites/ui/hud_panel_fullscreen/hud_border_top.png")
	_fullscreen_edge_right = _load_texture("res://art/sprites/ui/hud_panel_fullscreen/hud_border_right.png")
	_fullscreen_edge_bottom = _load_texture("res://art/sprites/ui/hud_panel_fullscreen/hud_border_bottom.png")
	_fullscreen_edge_left = _load_texture("res://art/sprites/ui/hud_panel_fullscreen/hud_border_left.png")


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("UIManager: Missing border texture '%s'" % path)
	return null


# =============================================================================
# HELPERS — PANEL STYLES
# =============================================================================

## Create a StyleBoxTexture from a border texture with 10px margins.
## The border frame is drawn by the texture; center is transparent (content area).
func _create_border_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = BORDER_MARGIN
	style.texture_margin_right = BORDER_MARGIN
	style.texture_margin_top = BORDER_MARGIN
	style.texture_margin_bottom = BORDER_MARGIN
	style.content_margin_left = BORDER_MARGIN + 2
	style.content_margin_right = BORDER_MARGIN + 2
	style.content_margin_top = BORDER_MARGIN + 2
	style.content_margin_bottom = BORDER_MARGIN + 2
	return style


## Create a PDA-styled StyleBoxFlat fallback (used when border textures are missing).
func create_pda_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.PDA_BACKGROUND
	style.border_color = GameColors.PDA_BORDER_GLOW
	style.set_border_width_all(1)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


## Create a dark menu-styled StyleBoxFlat fallback.
func create_menu_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.MENU_BACKGROUND
	style.border_color = GameColors.MENU_BORDER
	style.set_border_width_all(1)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


## Border style for unit info panel (left, tall, with rivets).
func create_unit_info_border() -> StyleBoxTexture:
	if _border_tall_left != null:
		return _create_border_style(_border_tall_left)
	return null


## Border style for terrain info panel (left, small, clean).
func create_terrain_info_border() -> StyleBoxTexture:
	if _border_small != null:
		return _create_border_style(_border_small)
	return null


## Border style for action menu panel (right, 9-patch stretchable).
func create_action_menu_border() -> StyleBoxTexture:
	if _border_small != null:
		return _create_border_style(_border_small)
	return null


## Border style for combat preview panel (right, 9-patch stretchable).
func create_combat_preview_border() -> StyleBoxTexture:
	if _border_small != null:
		return _create_border_style(_border_small)
	return null


func create_panel_border_overlay() -> PanelBorderOverlay:
	## Returns a PanelBorderOverlay configured with the 8-piece chopped border.
	## Add as a child of any Control with Full Rect anchors.
	var overlay := PanelBorderOverlay.new()
	overlay.corner_top_left = _border_corner_top_left
	overlay.corner_top_right = _border_corner_top_right
	overlay.corner_bottom_left = _border_corner_bottom_left
	overlay.corner_bottom_right = _border_corner_bottom_right
	overlay.edge_top = _border_edge_top
	overlay.edge_right = _border_edge_right
	overlay.edge_bottom = _border_edge_bottom
	overlay.edge_left = _border_edge_left
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return overlay


func create_fullscreen_border_overlay() -> PanelBorderOverlay:
	## Returns a PanelBorderOverlay configured with the fullscreen border pieces.
	## Designed for large panels like the unit detail panel.
	var overlay := PanelBorderOverlay.new()
	overlay.corner_top_left = _fullscreen_corner_top_left
	overlay.corner_top_right = _fullscreen_corner_top_right
	overlay.corner_bottom_left = _fullscreen_corner_bottom_left
	overlay.corner_bottom_right = _fullscreen_corner_bottom_right
	overlay.edge_top = _fullscreen_edge_top
	overlay.edge_right = _fullscreen_edge_right
	overlay.edge_bottom = _fullscreen_edge_bottom
	overlay.edge_left = _fullscreen_edge_left
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return overlay
