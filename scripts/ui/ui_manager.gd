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
const BORDER_MARGIN: int = 10             # All borders are 10px on each side

# Layout containers
var _main_layout: Control = null
var _left_panel: VBoxContainer = null
var _center_area: Control = null
var _right_panel: VBoxContainer = null

# Panels
var _unit_info_panel: UnitInfoPanel = null
var _terrain_info_panel: TerrainInfoPanel = null
var _action_menu_panel: ActionMenuPanel = null
var _combat_preview_panel: CombatPreviewPanel = null

# Panel side state: when true, action/combat panels are on the left, info panels on the right.
var _action_panels_on_left: bool = false

# Overlays
var _overlay_layer: CanvasLayer = null
var _phase_transition_overlay: Node = null
var _battle_result_overlay: Node = null


func _ready() -> void:
	layer = 10
	_load_pixel_fonts()
	_load_border_textures()
	_build_theme()
	_build_layout()
	_build_overlay_layer()
	_instantiate_panels()
	_instantiate_overlays()
	DebugConfig.log_pixel_perfect_ui("UIManager: Initialized with 140-360-140 layout")


# =============================================================================
# PUBLIC API — UNIT INFO
# =============================================================================

func show_unit_info(unit: Node) -> void:
	if _unit_info_panel == null:
		return
	if _is_action_ui_open():
		return
	_unit_info_panel.show_unit(unit as Unit)


func hide_unit_info() -> void:
	if _unit_info_panel == null:
		return
	_unit_info_panel.hide_panel()


# =============================================================================
# PUBLIC API — TERRAIN INFO
# =============================================================================

func show_terrain_info(tile: Variant) -> void:
	if _terrain_info_panel == null:
		return
	# Terrain info is suppressed while the action menu or combat preview is active.
	if _is_action_ui_open():
		return
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


func hide_combat_preview() -> void:
	if _combat_preview_panel == null:
		return
	_combat_preview_panel.hide_panel()


# =============================================================================
# PUBLIC API — OVERLAYS
# =============================================================================

func show_phase_transition(text: String, color: Color) -> void:
	if _phase_transition_overlay != null and _phase_transition_overlay.has_method("show_transition"):
		await _phase_transition_overlay.show_transition(text, color)


func show_battle_result(is_victory: bool, turn_count: int, player_units_lost: int,
		enemies_defeated: int, total_players: int, total_enemies: int) -> void:
	if _battle_result_overlay != null and _battle_result_overlay.has_method("show_result"):
		_battle_result_overlay.show_result(is_victory, turn_count, player_units_lost,
			enemies_defeated, total_players, total_enemies)


func hide_battle_result() -> void:
	if _battle_result_overlay != null and _battle_result_overlay.has_method("hide_result"):
		_battle_result_overlay.hide_result()


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
	var unit_info_scene := load("res://scenes/ui/panels/unit_info_panel.tscn")
	if unit_info_scene != null:
		_unit_info_panel = unit_info_scene.instantiate() as UnitInfoPanel
		_left_panel.add_child(_unit_info_panel)

	# Terrain info panel (left, bottom)
	var terrain_info_scene := load("res://scenes/ui/panels/terrain_info_panel.tscn")
	if terrain_info_scene != null:
		_terrain_info_panel = terrain_info_scene.instantiate() as TerrainInfoPanel
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


## Returns true if the unit's world position will appear in the right half of the
## screen after the camera finishes panning (uses target_position, not current).
func _unit_is_in_right_half(unit: Node) -> bool:
	var cam := _get_camera()
	var node2d := unit as Node2D
	if cam == null or node2d == null:
		return false
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var screen_x: float = (node2d.global_position.x - cam.target_position.x) * cam.zoom.x + viewport_width / 2.0
	return screen_x > viewport_width / 2.0


func _get_camera() -> CameraController:
	var viewport := get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_2d() as CameraController


## Returns true when info panels (unit info, terrain info) should be suppressed.
## True when the action menu or combat preview is visible, OR we're in
## ATTACK_TARGETING state (combat preview may not be shown on every hover tile).
func _is_action_ui_open() -> bool:
	if _action_menu_panel != null and _action_menu_panel.visible:
		return true
	if _combat_preview_panel != null and _combat_preview_panel.visible:
		return true
	var state_manager := get_node_or_null("/root/GameStateManager")
	if state_manager != null and state_manager.current_state == Enums.InputState.ATTACK_TARGETING:
		return true
	return false


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


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	DebugConfig.log_ui("UIManager: Missing border texture '%s'" % path)
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
