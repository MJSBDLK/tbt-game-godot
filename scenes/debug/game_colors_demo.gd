## Visual demo of every color defined in GameColors.
## Run this scene (F6) to see all colors rendered in context:
## UI colors on panel backgrounds, health bars with glow text,
## GlowLabels with proper pairings, status effects, multipliers, etc.
extends ColorRect

const GLOW_MATERIAL: ShaderMaterial = preload("res://resources/hud_glow.tres")
const MOVE_CHIP_MATERIAL: ShaderMaterial = preload("res://resources/move_chip_fill.tres")
const SECTION_GAP: int = 16
const ROW_GAP: int = 4
const SWATCH_SIZE := Vector2(20, 12)
const BAR_SIZE := Vector2(60, 4)

var _font_8px: Font = null
var _font_5px: Font = null
var _font_11px: Font = null


func _ready() -> void:
	_load_fonts()

	var scroll := ScrollContainer.new()
	scroll.anchors_preset = Control.PRESET_FULL_RECT
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	add_child(scroll)

	var root_margin := MarginContainer.new()
	root_margin.add_theme_constant_override("margin_left", 12)
	root_margin.add_theme_constant_override("margin_right", 12)
	root_margin.add_theme_constant_override("margin_top", 12)
	root_margin.add_theme_constant_override("margin_bottom", 12)
	root_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root_margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", SECTION_GAP)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_margin.add_child(main_vbox)

	_build_title(main_vbox)
	_build_text_colors(main_vbox)
	_build_health_ramp(main_vbox)
	_build_faction_colors(main_vbox)
	_build_phase_banner_colors(main_vbox)
	_build_multiplier_colors(main_vbox)
	_build_damage_popup_colors(main_vbox)
	_build_tile_colors(main_vbox)
	_build_ui_colors(main_vbox)
	_build_unit_selection_colors(main_vbox)
	_build_path_colors(main_vbox)
	_build_move_chip_colors(main_vbox)
	_build_pda_colors(main_vbox)


# =============================================================================
# FONTS
# =============================================================================

func _load_fonts() -> void:
	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null:
		_font_8px = ui_manager.font_8px
		_font_11px = ui_manager.font_11px
		_font_5px = ui_manager.font_5px
	if _font_8px == null:
		_font_8px = load("res://fonts/UndeadPixelLight8.ttf") as Font
	if _font_11px == null:
		_font_11px = load("res://fonts/UndeadPixelLight11.ttf") as Font
	if _font_5px == null:
		_font_5px = load("res://fonts/NotJamPixel5.ttf") as Font


# =============================================================================
# HELPERS
# =============================================================================

func _make_section_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", GameColorPalette.get_color("Gray", 7))
	if _font_8px:
		label.add_theme_font_override("font", _font_8px)
		label.add_theme_font_size_override("font_size", 8)
	return label


func _make_glow_label(text: String, font_color: Color, glow_color: Color, font: Font = null, font_size: int = 8) -> GlowLabel:
	var label := GlowLabel.new()
	label.text = text
	label.material = GLOW_MATERIAL.duplicate()
	label.glow_color = glow_color
	label.add_theme_color_override("font_color", font_color)
	var f: Font = font if font != null else _font_8px
	if f:
		label.add_theme_font_override("font", f)
		label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_plain_label(text: String, font_color: Color, font: Font = null, font_size: int = 5) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", font_color)
	var f: Font = font if font != null else _font_5px
	if f:
		label.add_theme_font_override("font", f)
		label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_swatch(swatch_color: Color, swatch_size: Vector2 = SWATCH_SIZE) -> ColorRect:
	var rect := ColorRect.new()
	rect.custom_minimum_size = swatch_size
	rect.color = swatch_color
	return rect


## Creates a panel-background container (mimics HUD panels) with children inside.
func _make_panel_bg() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.HUD_PANEL_BACKGROUND
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_hbox(separation: int = 8) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", separation)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	return hbox


func _make_vbox(separation: int = ROW_GAP) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", separation)
	return vbox


# =============================================================================
# TITLE
# =============================================================================

func _build_title(parent: Control) -> void:
	parent.add_child(_make_glow_label(
		"GAME COLORS DEMO",
		GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW,
		_font_11px, 11
	))


# =============================================================================
# TEXT COLORS — rendered as GlowLabels on panel background
# =============================================================================

func _build_text_colors(parent: Control) -> void:
	parent.add_child(_make_section_header("TEXT COLORS"))

	var panel := _make_panel_bg()
	parent.add_child(panel)

	var vbox := _make_vbox(6)
	panel.add_child(vbox)

	# Primary
	vbox.add_child(_make_glow_label(
		"Primary: The quick brown fox  (Azure 9 + Azure 5)",
		GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW
	))

	# Secondary
	vbox.add_child(_make_glow_label(
		"Secondary: The quick brown fox  (YellowOrange 8 + Magenta 4)",
		GameColors.TEXT_SECONDARY, GameColors.TEXT_SECONDARY_GLOW
	))

	# Success
	vbox.add_child(_make_glow_label(
		"Success/Buff: +3 DEF  (Green 6 + Green 3)",
		GameColors.TEXT_SUCCESS, GameColors.TEXT_SUCCESS_GLOW
	))

	# Danger
	vbox.add_child(_make_glow_label(
		"Danger/Debuff: -3 DEF  (Red 5 + Red 2)",
		GameColors.TEXT_DANGER, GameColors.TEXT_DANGER_GLOW
	))

	# Status text
	vbox.add_child(_make_glow_label(
		"Status: BURN 3T  (YellowOrange 7 + Red 4)",
		GameColors.STATUS_TEXT, GameColors.STATUS_TEXT_GLOW
	))


# =============================================================================
# HEALTH RAMP — rendered as actual bars with fill + bg + glow text
# =============================================================================

func _build_health_ramp(parent: Control) -> void:
	parent.add_child(_make_section_header("HEALTH BAR RAMP"))

	var panel := _make_panel_bg()
	parent.add_child(panel)

	var vbox := _make_vbox(3)
	panel.add_child(vbox)

	for i: int in range(GameColors.HEALTH_RAMP.size()):
		var fill_color: Color = GameColors.HEALTH_RAMP[i]
		var bg_color: Color = GameColors.HEALTH_RAMP_BG[i]
		var health_percent: float = float(i) / 10.0
		var hp_value: int = roundi(25.0 * health_percent)

		var hbox := _make_hbox(6)
		vbox.add_child(hbox)

		# Health bar: background + fill layered
		var bar_container := Control.new()
		bar_container.custom_minimum_size = BAR_SIZE
		hbox.add_child(bar_container)

		var bar_bg := ColorRect.new()
		bar_bg.custom_minimum_size = BAR_SIZE
		bar_bg.color = bg_color
		bar_container.add_child(bar_bg)

		var bar_fill := ColorRect.new()
		bar_fill.custom_minimum_size = Vector2(BAR_SIZE.x * health_percent, BAR_SIZE.y)
		bar_fill.color = fill_color
		bar_container.add_child(bar_fill)

		# HP text as GlowLabel in ramp colors
		hbox.add_child(_make_glow_label(
			"%d/25" % hp_value,
			fill_color, bg_color
		))

		# Ramp index label
		hbox.add_child(_make_plain_label(
			"[%d] %d%%" % [i, roundi(health_percent * 100)],
			GameColorPalette.get_color("Gray", 6)
		))

	# Damage preview colors
	var preview_hbox := _make_hbox(6)
	vbox.add_child(preview_hbox)
	preview_hbox.add_child(_make_swatch(GameColors.HEALTH_DAMAGE_PREVIEW, BAR_SIZE))
	preview_hbox.add_child(_make_glow_label(
		"Damage preview zone",
		GameColors.HEALTH_DAMAGE_PREVIEW, GameColors.HEALTH_DAMAGE_PREVIEW_GLOW
	))



# =============================================================================
# FACTION COLORS — unit tints + health bar backgrounds
# =============================================================================

func _build_faction_colors(parent: Control) -> void:
	parent.add_child(_make_section_header("FACTION COLORS"))

	var vbox := _make_vbox(4)
	parent.add_child(vbox)

	var factions: Array[Dictionary] = [
		{
			"name": "PLAYER",
			"unit": GameColors.PLAYER_UNIT,
			"acted": GameColors.PLAYER_UNIT_ACTED,
			"healthbar": GameColors.FACTION_HEALTHBAR_PLAYER,
		},
		{
			"name": "ENEMY",
			"unit": GameColors.ENEMY_UNIT,
			"acted": GameColors.ENEMY_UNIT_ACTED,
			"healthbar": GameColors.FACTION_HEALTHBAR_ENEMY,
		},
		{
			"name": "ALLY",
			"unit": GameColors.ALLY_UNIT,
			"acted": GameColors.ALLY_UNIT_ACTED,
			"healthbar": GameColors.FACTION_HEALTHBAR_ALLY,
		},
		{
			"name": "NEUTRAL",
			"unit": GameColors.NEUTRAL_UNIT,
			"acted": Color.TRANSPARENT,
			"healthbar": GameColors.FACTION_HEALTHBAR_NEUTRAL,
		},
	]

	for faction: Dictionary in factions:
		var hbox := _make_hbox(6)
		vbox.add_child(hbox)

		# Unit color swatch
		hbox.add_child(_make_swatch(faction["unit"]))

		# Acted color swatch
		if faction["acted"] != Color.TRANSPARENT:
			hbox.add_child(_make_swatch(faction["acted"]))
		else:
			hbox.add_child(_make_swatch(Color(0.35, 0.35, 0.35), SWATCH_SIZE))

		# Health bar background swatch
		hbox.add_child(_make_swatch(faction["healthbar"], Vector2(30, 12)))

		hbox.add_child(_make_plain_label(
			"%s  (unit / acted / healthbar bg)" % faction["name"],
			GameColorPalette.get_color("Gray", 7)
		))


# =============================================================================
# PHASE BANNER COLORS — text + accent + glow triples on glow background
# =============================================================================

func _build_phase_banner_colors(parent: Control) -> void:
	parent.add_child(_make_section_header("PHASE TRANSITION BANNERS"))

	var phases: Array[Dictionary] = [
		{
			"name": "PLAYER PHASE",
			"text": GameColors.PHASE_PLAYER_TEXT,
			"accent": GameColors.PHASE_PLAYER_ACCENT,
			"glow": GameColors.PHASE_PLAYER_GLOW,
		},
		{
			"name": "ENEMY PHASE",
			"text": GameColors.PHASE_ENEMY_TEXT,
			"accent": GameColors.PHASE_ENEMY_ACCENT,
			"glow": GameColors.PHASE_ENEMY_GLOW,
		},
		{
			"name": "NEUTRAL PHASE",
			"text": GameColors.PHASE_NEUTRAL_TEXT,
			"accent": GameColors.PHASE_NEUTRAL_ACCENT,
			"glow": GameColors.PHASE_NEUTRAL_GLOW,
		},
		{
			"name": "ALLY PHASE",
			"text": GameColors.PHASE_ALLY_TEXT,
			"accent": GameColors.PHASE_ALLY_ACCENT,
			"glow": GameColors.PHASE_ALLY_GLOW,
		},
	]

	for phase: Dictionary in phases:
		# Banner background = black (like in-game)
		var banner_panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color.BLACK
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		banner_panel.add_theme_stylebox_override("panel", style)
		parent.add_child(banner_panel)

		var hbox := _make_hbox(10)
		banner_panel.add_child(hbox)

		# Phase name as large GlowLabel with double_glow
		var phase_label := _make_glow_label(
			phase["name"],
			phase["text"], phase["accent"],
			_font_11px, 16
		)
		if phase_label.material is ShaderMaterial:
			phase_label.material.set_shader_parameter("double_glow", true)
		hbox.add_child(phase_label)

		# Color reference
		hbox.add_child(_make_plain_label(
			"(text + accent glow, double_glow, black bg)",
			phase["accent"]
		))


# =============================================================================
# MULTIPLIER COLORS — light/dark pairs
# =============================================================================

func _build_multiplier_colors(parent: Control) -> void:
	parent.add_child(_make_section_header("DAMAGE MULTIPLIER COLORS"))

	var panel := _make_panel_bg()
	parent.add_child(panel)

	var vbox := _make_vbox(4)
	panel.add_child(vbox)

	var multipliers: Array[Dictionary] = [
		{"label": "x4 Devastating", "light": GameColors.MULTIPLIER_X4_LIGHT, "dark": GameColors.MULTIPLIER_X4_DARK},
		{"label": "x3", "light": GameColors.MULTIPLIER_X3_LIGHT, "dark": GameColors.MULTIPLIER_X3_DARK},
		{"label": "x2 Super Effective", "light": GameColors.MULTIPLIER_X2_LIGHT, "dark": GameColors.MULTIPLIER_X2_DARK},
		{"label": "x1 Neutral", "light": GameColors.MULTIPLIER_X1_LIGHT, "dark": GameColors.MULTIPLIER_X1_DARK},
		{"label": "x1/2 Not Very Effective", "light": GameColors.MULTIPLIER_HALF_LIGHT, "dark": GameColors.MULTIPLIER_HALF_DARK},
		{"label": "x1/4 Barely Effective", "light": GameColors.MULTIPLIER_QUARTER_LIGHT, "dark": GameColors.MULTIPLIER_QUARTER_DARK},
		{"label": "x0 No Effect", "light": GameColors.MULTIPLIER_X0_LIGHT, "dark": GameColors.MULTIPLIER_X0_DARK},
	]

	for mult: Dictionary in multipliers:
		var hbox := _make_hbox(6)
		vbox.add_child(hbox)
		hbox.add_child(_make_swatch(mult["light"]))
		hbox.add_child(_make_swatch(mult["dark"]))
		hbox.add_child(_make_glow_label(mult["label"], mult["light"], mult["dark"]))


# =============================================================================
# DAMAGE POPUP COLORS — effectiveness colors with Gray 1 @ 97.5% glow border
# =============================================================================

func _build_damage_popup_colors(parent: Control) -> void:
	parent.add_child(_make_section_header("DAMAGE POPUP COLORS"))

	var popup_glow_color := Color(GameColorPalette.get_color("Gray", 1), 0.975)

	var tiers: Array[Dictionary] = [
		{"label": "x4 Devastating", "value": 47, "color": GameColors.MULTIPLIER_X4_LIGHT},
		{"label": "x3", "value": 34, "color": GameColors.MULTIPLIER_X3_LIGHT},
		{"label": "x2 Super Effective", "value": 22, "color": GameColors.MULTIPLIER_X2_LIGHT},
		{"label": "x1 Neutral", "value": 15, "color": GameColors.MULTIPLIER_X1_LIGHT},
		{"label": "x1/2 Not Very Effective", "value": 7, "color": GameColors.MULTIPLIER_HALF_LIGHT},
		{"label": "x1/4 Barely Effective", "value": 3, "color": GameColors.MULTIPLIER_QUARTER_LIGHT},
		{"label": "x0 No Effect", "value": 0, "color": GameColors.MULTIPLIER_X0_LIGHT},
		{"label": "Critical (x2 brightened)", "value": 44, "color": GameColors.brightened(GameColors.MULTIPLIER_X2_LIGHT, 1.3)},
	]

	for tier: Dictionary in tiers:
		var hbox := _make_hbox(10)
		hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		parent.add_child(hbox)

		# Damage number with Gray 1 glow border (like in-game popups)
		var glow_material: ShaderMaterial = GLOW_MATERIAL.duplicate()
		glow_material.set_shader_parameter("glow_color", popup_glow_color)

		var number_label := Label.new()
		number_label.text = str(tier["value"])
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number_label.custom_minimum_size.x = 24
		number_label.add_theme_color_override("font_color", tier["color"])
		number_label.material = glow_material
		if _font_8px:
			number_label.add_theme_font_override("font", _font_8px)
			number_label.add_theme_font_size_override("font_size", 16)
		hbox.add_child(number_label)

		# Tier description
		hbox.add_child(_make_plain_label(tier["label"], GameColorPalette.get_color("Gray", 7)))


# =============================================================================
# TILE COLORS — simple swatches (map-level, not on panel bg)
# =============================================================================

func _build_tile_colors(parent: Control) -> void:
	parent.add_child(_make_section_header("TILE COLORS"))

	var vbox := _make_vbox(4)
	parent.add_child(vbox)

	var tiles: Array[Dictionary] = [
		{"name": "Default (White)", "color": GameColors.TILE_DEFAULT},
		{"name": "Hovered (Gray 8)", "color": GameColors.TILE_HOVERED},
		{"name": "Selected (Yellow 8)", "color": GameColors.TILE_SELECTED},
		{"name": "Movement Range (Azure 5)", "color": GameColors.MOVEMENT_RANGE},
		{"name": "Movement Range Hovered (Azure 7)", "color": GameColors.MOVEMENT_RANGE_HOVERED},
		{"name": "Attack Range (Red 6)", "color": GameColors.ATTACK_RANGE},
		{"name": "Attack Range Hovered (Red 7)", "color": GameColors.ATTACK_RANGE_HOVERED},
	]

	for tile: Dictionary in tiles:
		var hbox := _make_hbox(6)
		vbox.add_child(hbox)
		hbox.add_child(_make_swatch(tile["color"]))
		hbox.add_child(_make_plain_label(tile["name"], GameColorPalette.get_color("Gray", 7)))


# =============================================================================
# UI COLORS — on panel background
# =============================================================================

func _build_ui_colors(parent: Control) -> void:
	parent.add_child(_make_section_header("UI / PANEL COLORS"))

	var panel := _make_panel_bg()
	parent.add_child(panel)

	var vbox := _make_vbox(4)
	panel.add_child(vbox)

	# Panel background itself
	var bg_hbox := _make_hbox(6)
	vbox.add_child(bg_hbox)
	bg_hbox.add_child(_make_swatch(GameColors.HUD_PANEL_BACKGROUND))
	bg_hbox.add_child(_make_plain_label(
		"HUD Panel BG: #302d27 @ 85%  (this background)",
		GameColorPalette.get_color("Gray", 6)
	))

	# Buttons
	var button_colors: Array[Dictionary] = [
		{"name": "Action Button Normal", "color": GameColors.ACTION_BUTTON_BG_NORMAL},
		{"name": "Action Button Hovered", "color": GameColors.ACTION_BUTTON_BG_HOVERED},
		{"name": "Action Button Pressed", "color": GameColors.ACTION_BUTTON_BG_PRESSED},
		{"name": "Action Button Border", "color": GameColors.ACTION_BUTTON_BORDER},
		{"name": "Button Normal", "color": GameColors.BUTTON_NORMAL},
		{"name": "Button Hovered", "color": GameColors.BUTTON_HOVERED},
		{"name": "Button Pressed", "color": GameColors.BUTTON_PRESSED},
		{"name": "Menu BG", "color": GameColors.MENU_BACKGROUND},
		{"name": "Menu Border", "color": GameColors.MENU_BORDER},
		{"name": "UI Backdrop", "color": GameColors.UI_BACKDROP},
	]

	for entry: Dictionary in button_colors:
		var hbox := _make_hbox(6)
		vbox.add_child(hbox)
		hbox.add_child(_make_swatch(entry["color"]))
		hbox.add_child(_make_plain_label(entry["name"], GameColorPalette.get_color("Gray", 7)))


# =============================================================================
# UNIT SELECTION STATES
# =============================================================================

func _build_unit_selection_colors(parent: Control) -> void:
	parent.add_child(_make_section_header("UNIT SELECTION STATES"))

	var vbox := _make_vbox(4)
	parent.add_child(vbox)

	var states: Array[Dictionary] = [
		{"name": "Selected (Green 7)", "color": GameColors.UNIT_SELECTED},
		{"name": "Hovered (Blue 9)", "color": GameColors.UNIT_HOVERED},
		{"name": "Acted (Gray)", "color": GameColors.UNIT_ACTED},
	]

	for state: Dictionary in states:
		var hbox := _make_hbox(6)
		vbox.add_child(hbox)
		hbox.add_child(_make_swatch(state["color"]))
		hbox.add_child(_make_plain_label(state["name"], GameColorPalette.get_color("Gray", 7)))


# =============================================================================
# PATH COLORS
# =============================================================================

func _build_path_colors(parent: Control) -> void:
	parent.add_child(_make_section_header("WAYPOINT / PATH COLORS"))

	var vbox := _make_vbox(4)
	parent.add_child(vbox)

	var paths: Array[Dictionary] = [
		{"name": "Waypoint Indicator (Yellow 6 @ 80%)", "color": GameColors.WAYPOINT_INDICATOR},
		{"name": "Path Arrow (Blue 6 @ 70%)", "color": GameColors.PATH_ARROW},
	]

	for entry: Dictionary in paths:
		var hbox := _make_hbox(6)
		vbox.add_child(hbox)
		hbox.add_child(_make_swatch(entry["color"]))
		hbox.add_child(_make_plain_label(entry["name"], GameColorPalette.get_color("Gray", 7)))


# =============================================================================
# MOVE CHIP COLORS — full and half-filled for each elemental type
# =============================================================================

func _build_move_chip_colors(parent: Control) -> void:
	parent.add_child(_make_section_header("MOVE CHIP COLORS"))

	var panel := _make_panel_bg()
	parent.add_child(panel)

	var vbox := _make_vbox(2)
	panel.add_child(vbox)

	for element_type: int in Enums.ElementalType.values():
		if element_type == Enums.ElementalType.NONE:
			continue

		var typed: Enums.ElementalType = element_type as Enums.ElementalType
		var type_name: String = Enums.elemental_type_to_string(typed)
		var foreground: Color = GameColors.get_move_chip_foreground(typed)
		var background: Color = GameColors.get_move_chip_background(typed)
		var border: Color = GameColors.get_move_chip_border(typed)
		var font_color: Color = GameColors.get_move_chip_font_color(typed)
		var glow_color: Color = GameColors.get_move_chip_glow_color(typed)
		var icon_path: String = "res://art/sprites/ui/elemental_type_icons_10x10/%s.png" % type_name.to_lower()
		var icon_texture: Texture2D = load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null

		var hbox := _make_hbox(2)
		hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		vbox.add_child(hbox)

		# Full chip
		hbox.add_child(_make_move_chip(type_name, foreground, background, border, font_color, glow_color, 1.0, icon_texture))

		# Half chip
		hbox.add_child(_make_move_chip(type_name, foreground, background, border, font_color, glow_color, 0.5, icon_texture))


func _make_move_chip(label_text: String, foreground: Color, background: Color, border: Color, font_color: Color, glow_color: Color, fill_percent: float, icon_texture: Texture2D) -> MoveChip:
	var chip := MoveChip.new()
	chip.custom_minimum_size = Vector2(113, 14)
	chip.material = MOVE_CHIP_MATERIAL.duplicate()
	chip.fill_color = foreground
	chip.empty_color = background
	chip.fill_percent = fill_percent
	chip.border_color = border
	chip.radius_px = 2.0

	# Inner HBoxContainer — matches scene: offset_top=2, offset_bottom=12 (10px inner)
	var inner_hbox := HBoxContainer.new()
	inner_hbox.layout_mode = 0
	inner_hbox.offset_top = 2.0
	inner_hbox.offset_right = 113.0
	inner_hbox.offset_bottom = 12.0
	inner_hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	inner_hbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	chip.add_child(inner_hbox)

	# Move name label (GlowLabel wrapped in MarginContainer, matching ui_text.tscn)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_hbox.add_child(margin)

	var label := _make_glow_label(label_text, font_color, glow_color, _font_5px, 5)
	label.uppercase = false
	margin.add_child(label)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_hbox.add_child(spacer)

	# Type icon
	if icon_texture != null:
		var icon_margin := MarginContainer.new()
		icon_margin.add_theme_constant_override("margin_left", 1)
		icon_margin.add_theme_constant_override("margin_top", 1)
		icon_margin.add_theme_constant_override("margin_right", 3)
		icon_margin.add_theme_constant_override("margin_bottom", 1)
		inner_hbox.add_child(icon_margin)

		var icon := TextureRect.new()
		icon.texture = icon_texture
		icon_margin.add_child(icon)

	return chip


# =============================================================================
# PDA COLORS — on PDA background
# =============================================================================

func _build_pda_colors(parent: Control) -> void:
	parent.add_child(_make_section_header("PDA PANEL COLORS"))

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.PDA_BACKGROUND
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	# Border glow
	style.border_color = GameColors.PDA_BORDER_GLOW
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := _make_vbox(4)
	panel.add_child(vbox)

	var pda_texts: Array[Dictionary] = [
		{"name": "PDA Primary", "color": GameColors.PDA_TEXT_PRIMARY},
		{"name": "PDA Player", "color": GameColors.PDA_TEXT_PLAYER},
		{"name": "PDA Enemy", "color": GameColors.PDA_TEXT_ENEMY},
		{"name": "PDA Neutral", "color": GameColors.PDA_TEXT_NEUTRAL},
		{"name": "PDA Highlight", "color": GameColors.PDA_TEXT_HIGHLIGHT},
	]

	for entry: Dictionary in pda_texts:
		var label := Label.new()
		label.text = "%s: Sample text" % entry["name"]
		label.add_theme_color_override("font_color", entry["color"])
		if _font_8px:
			label.add_theme_font_override("font", _font_8px)
			label.add_theme_font_size_override("font_size", 8)
		vbox.add_child(label)
