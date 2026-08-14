## The bEXP SPEND panel (slice 4, RQD 2026-08-11): swaps in for the UnitSheet
## in Manage Units' center column when the player opens bEXP allocation (the
## sheet's XP row, or the top bar's bEXP readout). "I don't like the idea of
## populating the third panel with a second stat screen" — so the sheet's OWN
## column converts, and the stat rows are the same LevelUpStatBlock the
## mid-battle celebration uses. One component, wherever a level-up plays.
##
## PURCHASE MODEL: one press = one committed level (SquadManager.buy_bexp_level
## rolls growths inside itself — irreversibly, which is exactly why the old
## refundable [-10][-1] pouring design needed a staging layer this design
## doesn't: here every purchase is committed AND CELEBRATED atomically, so
## there is nothing to refund). Press → snapshot → buy → the block strips
## modifiers and reveals the growth beats → modifiers restore. Repeat while
## the pool lasts.
##
## The rail stays live behind this panel — switching units rebinds it, so
## pouring into several units is one click each. Benched units are reachable
## on purpose: the catch-up economy exists for exactly them.
class_name BexpSpendPanel
extends PanelContainer


## A level was bought — rail badges, the workbench squad list, and the top
## bar's pool readout are stale.
signal changed
## The player is done — the screen restores the sheet.
signal closed


## Breath between the last reveal beat and the modifiers coming back.
const RESTORE_PAUSE_SECONDS: float = 0.5


var _character: CharacterData = null
var _stack: VBoxContainer = null
var _name_label: Label = null
var _level_value_label: Label = null
var _pool_value_label: Label = null
var _xp_fill: GlowColorRect = null
var _xp_value_label: Label = null
var _block: LevelUpStatBlock = null
var _buy_button: Button = null
var _revealing: bool = false


func _ready() -> void:
	# The sheet's chrome — this panel stands in the sheet's column slot.
	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.HUD_PANEL_BACKGROUND
	style.border_color = GameColorPalette.get_color("Straw2", 3)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)
	_build()


func bind(character: CharacterData) -> void:
	_character = character
	_revealing = false
	_refresh()


func _build() -> void:
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 5)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 5)
	add_child(margin)
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", 3)
	margin.add_child(_stack)

	var title_row := HBoxContainer.new()
	_stack.add_child(title_row)
	title_row.add_child(UnitSheet.dim_label("ALLOCATE BONUS EXP"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(spacer)
	title_row.add_child(_text_button("✕", GameColors.TEXT_PRIMARY,
			GameColors.TEXT_PRIMARY_GLOW, func() -> void: closed.emit()))

	var ident_row := HBoxContainer.new()
	ident_row.add_theme_constant_override("separation", 6)
	_stack.add_child(ident_row)
	var name_holder: Array[Label] = []
	ident_row.add_child(_live_label("", GameColors.TEXT_PRIMARY,
			GameColors.TEXT_PRIMARY_GLOW, name_holder))
	_name_label = name_holder[0]
	var level_holder: Array[Label] = []
	ident_row.add_child(_live_label("", GameColors.TEXT_INFO,
			GameColors.TEXT_INFO_GLOW, level_holder))
	_level_value_label = level_holder[0]

	# XP row — the sheet's recipe (track + INFO fill + n/100). Display-only
	# here too: bEXP buys LEVELS, combat XP fills this bar.
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 5)
	_stack.add_child(xp_row)
	var xp_key := UnitSheet.dim_label("XP")
	xp_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_row.add_child(xp_key)
	var track := Control.new()
	track.custom_minimum_size = Vector2(0, 4)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.add_child(UnitSheet.glow_bar(
			StatCapBar.COLOR_TRACK, StatCapBar.COLOR_TRACK_GLOW, 1.0))
	_xp_fill = UnitSheet.glow_bar(GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW, 0.0)
	_xp_fill.visible = false
	track.add_child(_xp_fill)
	xp_row.add_child(track)
	var xp_holder: Array[Label] = []
	xp_row.add_child(_live_label("0/100", GameColors.TEXT_INFO,
			GameColors.TEXT_INFO_GLOW, xp_holder))
	_xp_value_label = xp_holder[0]

	var pool_row := HBoxContainer.new()
	pool_row.add_theme_constant_override("separation", 4)
	_stack.add_child(pool_row)
	pool_row.add_child(UnitSheet.dim_label("BANKED"))
	var pool_holder: Array[Label] = []
	pool_row.add_child(_live_label("", GameColors.TEXT_INFO,
			GameColors.TEXT_INFO_GLOW, pool_holder))
	_pool_value_label = pool_holder[0]

	_block = LevelUpStatBlock.new()
	_stack.add_child(_block)

	_buy_button = _text_button("", GameColors.TEXT_PRIMARY,
			GameColors.TEXT_PRIMARY_GLOW, _on_buy_pressed)
	_stack.add_child(_buy_button)


## At-rest refresh: full effective stats (modifiers shown), live ident, pool
## and affordability.
func _refresh() -> void:
	if _character == null:
		return
	_name_label.text = _character.character_name.to_upper()
	_level_value_label.text = "Lv %d" % _character.level
	var xp_ratio: float = clampf(_character.experience / 100.0, 0.0, 1.0)
	_xp_fill.visible = xp_ratio > 0.0
	_xp_fill.anchor_right = xp_ratio
	_xp_value_label.text = "%d/100" % _character.experience
	_pool_value_label.text = str(SquadManager.bonus_xp_pool)
	_block.build(_character, LevelUpStatBlock.stat_snapshot(_character), true, true)
	_refresh_buy_button()


func _refresh_buy_button() -> void:
	var affordable: bool = SquadManager.bonus_xp_pool >= SquadManager.BEXP_LEVEL_COST
	_buy_button.text = "+1 LEVEL — %d bEXP" % SquadManager.BEXP_LEVEL_COST
	_buy_button.disabled = _revealing or not affordable
	var color: Color = GameColors.TEXT_PRIMARY if affordable else GameColors.TEXT_MUTED
	var glow: Color = GameColors.TEXT_PRIMARY_GLOW if affordable else GameColors.TEXT_MUTED_GLOW
	_buy_button.add_theme_color_override("font_color", color)
	_buy_button.add_theme_color_override("font_hover_color",
			GameColors.brightened(color) if affordable else color)
	_buy_button.add_theme_color_override("font_disabled_color", color)
	if _buy_button.material is ShaderMaterial:
		(_buy_button.material as ShaderMaterial).set_shader_parameter("glow_color", glow)
	_buy_button.tooltip_text = "commits immediately — growths roll now" if affordable \
			else "a level costs %d bEXP" % SquadManager.BEXP_LEVEL_COST


## One press = one committed, celebrated level. The block strips modifiers
## for the reveal (growth story only) and the at-rest rebuild restores them —
## the RQD seamless-blend rule.
func _on_buy_pressed() -> void:
	if _revealing or _character == null:
		return
	var before: Dictionary = LevelUpStatBlock.stat_snapshot(_character)
	if not SquadManager.buy_bexp_level(_character):
		_refresh_buy_button()
		return
	_revealing = true
	changed.emit()
	_level_value_label.text = "Lv %d" % _character.level
	_pool_value_label.text = str(SquadManager.bonus_xp_pool)
	_refresh_buy_button()
	_block.build(_character, before, not Settings.ui_motion_enabled, false)
	if Settings.ui_motion_enabled:
		await _block.play_reveal()
	await get_tree().create_timer(RESTORE_PAUSE_SECONDS).timeout
	_revealing = false
	# Rebind may have happened mid-reveal (rail switch) — _refresh reads
	# whatever character the panel holds NOW.
	_refresh()


## Bare glyphs over empty styleboxes — the top bar's button recipe, so text
## glows and chrome doesn't.
func _text_button(text_value: String, color: Color, glow: Color,
		on_pressed: Callable) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.text = text_value
	if UIManager.font_8px != null:
		button.add_theme_font_override("font", UIManager.font_8px)
	button.add_theme_font_size_override("font_size", 8)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", GameColors.brightened(color))
	var button_material := (load("res://resources/hud_glow.tres") as Material).duplicate()
	(button_material as ShaderMaterial).set_shader_parameter("glow_color", glow)
	button.material = button_material
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(on_pressed)
	return button


## SECONDARY-keyed live value label; appended to `out` for later updates.
func _live_label(text_value: String, color: Color, glow: Color,
		out: Array) -> Label:
	var label := GlowLabel.styled(text_value, UIManager.font_8px, 8, color, glow)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	out.append(label)
	return label
