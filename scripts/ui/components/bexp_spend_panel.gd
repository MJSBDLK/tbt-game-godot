## The bEXP SPEND panel (slice 4, RQD 2026-08-11; pour spec restored
## 2026-08-13): swaps in for the UnitSheet in Manage Units' center column.
## "I don't like the idea of populating the third panel with a second stat
## screen" — the sheet's OWN column converts, and the stat rows are the same
## LevelUpStatBlock the mid-battle celebration uses.
##
## THE POUR MODEL — the established spec (todo.md subtask + the intermission
## mockup's "amounts" style, which RQD had to remind me existed):
##
##   [-100][-10][-1]  [+1][+10]  [99]  [+100]
##
## Pouring is STAGED ARITHMETIC — a preview, fully refundable, held per unit
## so the rail can hop between candidates mid-decision. Every readout derived
## from staged bEXP (level, XP number, XP bar, the pool) shows the value it
## WILL be, marked uncommitted: the SECONDARY tint is the load-bearing signal
## and is always on; the pulse is emphasis layered over it, motion-gated,
## because a state that exists only as an animation vanishes for anyone who
## turns ui_motion_enabled off (the mockup's two-marks rule, verbatim).
##
## CONFIRM is the one commit: SquadManager.commit_bexp_pour rolls each
## crossed level with bEXP mechanics and the remainder persists as real XP —
## which is why the 99 brink button earns its slot: parked at 99, the next
## combat action takes the level with FULL growth rolls instead of bEXP's
## fixed spread. ✕ / Escape / leaving discards the stage; nothing rolled.
class_name BexpSpendPanel
extends PanelContainer


## A commit happened — rail badges, workbench squad stats, and the top bar's
## pool readout are stale.
signal changed
## The player is done — the screen restores the sheet.
signal closed


## Breath between the last reveal beat and the modifiers coming back.
const RESTORE_PAUSE_SECONDS: float = 0.5
## The pour buttons, in display order. 99 is handled specially (brink).
const POUR_AMOUNTS: Array = [-100, -10, -1, 1, 10]
const XP_PER_LEVEL: int = 100


var _character: CharacterData = null
## character_id -> staged pour (uncommitted, refundable). Held across rail
## switches so pouring is a squad-wide decision with one confirm.
var _staged: Dictionary = {}
var _revealing: bool = false

var _stack: VBoxContainer = null
var _name_label: Label = null
var _level_value_label: Label = null
var _pool_value_label: Label = null
var _xp_fill: GlowColorRect = null
var _xp_value_label: Label = null
var _block: LevelUpStatBlock = null
var _pour_buttons: Dictionary = {}  # amount -> Button ("99" under key 99)
var _confirm_button: Button = null
var _pulse_tween: Tween = null


# =============================================================================
# PURE POUR MATH — the staging layer is arithmetic, so it's all testable
# =============================================================================

## New staged value after pressing a pour/refund button: refunds floor at 0,
## pours ceiling at what's actually left in the pool.
static func clamp_pour(staged: int, delta: int, pool_remaining: int) -> int:
	return clampi(staged + delta, 0, staged + maxi(0, pool_remaining))


## The brink: how much to pour so the PREVIEW gauge parks at 99/100.
static func brink_amount(preview_xp: int) -> int:
	return maxi(0, (XP_PER_LEVEL - 1) - preview_xp)


## Where the gauge will sit after commit (0..99).
static func preview_xp(experience: int, staged: int) -> int:
	return (experience + staged) % XP_PER_LEVEL


## Whole levels the staged pour will roll on commit.
static func preview_levels(experience: int, staged: int) -> int:
	return (experience + staged) / XP_PER_LEVEL


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
	_refresh()


## Leaving the panel abandons the whole stage — only CONFIRM commits.
func discard_stage() -> void:
	_staged.clear()
	if _character != null:
		_refresh()


func _staged_total() -> int:
	var total: int = 0
	for amount: Variant in _staged.values():
		total += int(amount)
	return total


func _staged_for_bound() -> int:
	if _character == null:
		return 0
	return int(_staged.get(_character.character_id, 0))


func _pool_remaining() -> int:
	return SquadManager.bonus_xp_pool - _staged_total()


# =============================================================================
# BUILD
# =============================================================================

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
			GameColors.TEXT_PRIMARY_GLOW, _on_close_pressed))

	var ident_row := HBoxContainer.new()
	ident_row.add_theme_constant_override("separation", 6)
	_stack.add_child(ident_row)
	_name_label = _live_label("", GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW)
	ident_row.add_child(_name_label)
	_level_value_label = _live_label("", GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW)
	ident_row.add_child(_level_value_label)

	# XP row — the sheet's recipe (track + fill + n/100), preview-aware.
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
	_xp_value_label = _live_label("0/100", GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW)
	xp_row.add_child(_xp_value_label)

	var pool_row := HBoxContainer.new()
	pool_row.add_theme_constant_override("separation", 4)
	_stack.add_child(pool_row)
	pool_row.add_child(UnitSheet.dim_label("BANKED"))
	_pool_value_label = _live_label("", GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW)
	pool_row.add_child(_pool_value_label)

	_block = LevelUpStatBlock.new()
	_stack.add_child(_block)

	# The spec's button row: [-100][-10][-1] [+1][+10] [99] [+100].
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 3)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_stack.add_child(buttons)
	for amount: int in POUR_AMOUNTS:
		var label_text: String = ("+%d" % amount) if amount > 0 else str(amount)
		var pour_button := _text_button(label_text, GameColors.TEXT_PRIMARY,
				GameColors.TEXT_PRIMARY_GLOW, _on_pour_pressed.bind(amount))
		_pour_buttons[amount] = pour_button
		buttons.add_child(pour_button)
	var brink_button := _text_button("99", GameColors.TEXT_PRIMARY,
			GameColors.TEXT_PRIMARY_GLOW, _on_brink_pressed)
	_pour_buttons[99] = brink_button
	buttons.add_child(brink_button)
	var full_button := _text_button("+100", GameColors.TEXT_PRIMARY,
			GameColors.TEXT_PRIMARY_GLOW, _on_pour_pressed.bind(100))
	_pour_buttons[100] = full_button
	buttons.add_child(full_button)

	_confirm_button = _text_button("CONFIRM", GameColors.TEXT_PRIMARY,
			GameColors.TEXT_PRIMARY_GLOW, _on_confirm_pressed)
	_stack.add_child(_confirm_button)


# =============================================================================
# POUR (staged, refundable)
# =============================================================================

func _on_pour_pressed(amount: int) -> void:
	if _revealing or _character == null:
		return
	var staged: int = _staged_for_bound()
	var new_staged: int = clamp_pour(staged, amount, _pool_remaining())
	if new_staged == staged:
		return
	_staged[_character.character_id] = new_staged
	_refresh()


func _on_brink_pressed() -> void:
	if _revealing or _character == null:
		return
	var staged: int = _staged_for_bound()
	_on_pour_pressed(brink_amount(preview_xp(_character.experience, staged)))


func _on_close_pressed() -> void:
	discard_stage()
	closed.emit()


# =============================================================================
# CONFIRM — the one commit
# =============================================================================

## Commits every unit's staged pour. The BOUND unit goes last and gets the
## reveal (it's the one on screen); other units' levels land silently and
## surface on the rail. Per-level chunking keeps each reveal diffing its own
## snapshot.
func _on_confirm_pressed() -> void:
	if _revealing or _staged_total() <= 0 or _character == null:
		return
	_revealing = true
	for character_id: String in _staged.keys():
		if character_id == _character.character_id:
			continue
		var other: CharacterData = SquadManager.get_character_by_id(character_id)
		if other != null:
			SquadManager.commit_bexp_pour(other, int(_staged[character_id]))
	var remaining: int = _staged_for_bound()
	_staged.clear()
	changed.emit()
	while remaining > 0:
		var chunk: int = mini(remaining, XP_PER_LEVEL - _character.experience)
		remaining -= chunk
		var before: Dictionary = LevelUpStatBlock.stat_snapshot(_character)
		var leveled: int = SquadManager.commit_bexp_pour(_character, chunk)
		if leveled > 0:
			changed.emit()
			_level_value_label.text = "Lv %d" % _character.level
			_pool_value_label.text = str(SquadManager.bonus_xp_pool)
			_block.build(_character, before, not Settings.ui_motion_enabled, false)
			if Settings.ui_motion_enabled:
				await _block.play_reveal()
			await get_tree().create_timer(RESTORE_PAUSE_SECONDS).timeout
	_revealing = false
	changed.emit()
	_refresh()


# =============================================================================
# REFRESH — every readout is a preview while anything is staged
# =============================================================================

func _refresh() -> void:
	if _character == null:
		return
	var staged: int = _staged_for_bound()
	var uncommitted: bool = staged > 0
	var will_be_level: int = _character.level + preview_levels(_character.experience, staged)
	var gauge: int = preview_xp(_character.experience, staged)

	_name_label.text = _character.character_name.to_upper()
	_level_value_label.text = ("Lv %d → %d" % [_character.level, will_be_level]) \
			if will_be_level > _character.level else "Lv %d" % _character.level

	var xp_ratio: float = clampf(gauge / float(XP_PER_LEVEL), 0.0, 1.0)
	_xp_fill.visible = xp_ratio > 0.0
	_xp_fill.anchor_right = xp_ratio
	_xp_value_label.text = "%d/100" % gauge
	_pool_value_label.text = str(_pool_remaining())

	# The uncommitted tint (always) + pulse (motion only) — the two-marks
	# rule. SECONDARY is the provisional/modifier voice everywhere else, so
	# staged values borrow it rather than minting a new pair.
	var value_color: Color = GameColors.TEXT_SECONDARY if uncommitted else GameColors.TEXT_INFO
	var value_glow: Color = GameColors.TEXT_SECONDARY_GLOW if uncommitted else GameColors.TEXT_INFO_GLOW
	for preview_label: Label in [_level_value_label, _xp_value_label, _pool_value_label]:
		preview_label.add_theme_color_override("font_color", value_color)
		if preview_label.material is ShaderMaterial:
			preview_label.material.set_shader_parameter("glow_color", value_glow)
	_xp_fill.color = value_color
	_xp_fill.glow_color = value_glow
	_update_pulse(uncommitted)

	_block.build(_character, LevelUpStatBlock.stat_snapshot(_character), true, true)
	_refresh_buttons()


func _refresh_buttons() -> void:
	var staged: int = _staged_for_bound()
	var pool_remaining: int = _pool_remaining()
	var gauge: int = preview_xp(_character.experience, staged)
	for amount: int in POUR_AMOUNTS:
		var enabled: bool = (staged >= -amount) if amount < 0 else (pool_remaining >= amount)
		_set_button_enabled(_pour_buttons[amount], enabled,
				("refund %d" % -amount) if amount < 0 else ("pour %d" % amount))
	var brink: int = brink_amount(gauge)
	_set_button_enabled(_pour_buttons[99], brink > 0 and pool_remaining >= brink,
			"pour %d — park at 99/100 so a combat action takes the level (full growth rolls, not bEXP's fixed spread)" % brink
			if brink > 0 else "already at the brink")
	_set_button_enabled(_pour_buttons[100], pool_remaining >= 100, "pour 100 — one full level")
	_set_button_enabled(_confirm_button, _staged_total() > 0 and not _revealing,
			"roll the staged levels — commits, growths are final" if _staged_total() > 0
			else "nothing staged")


func _set_button_enabled(button: Button, enabled: bool, tip: String) -> void:
	button.disabled = not enabled
	var color: Color = GameColors.TEXT_PRIMARY if enabled else GameColors.TEXT_MUTED
	var glow: Color = GameColors.TEXT_PRIMARY_GLOW if enabled else GameColors.TEXT_MUTED_GLOW
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color",
			GameColors.brightened(color) if enabled else color)
	button.add_theme_color_override("font_disabled_color", color)
	if button.material is ShaderMaterial:
		(button.material as ShaderMaterial).set_shader_parameter("glow_color", glow)
	button.tooltip_text = tip


## The motion half of the uncommitted mark: a slow alpha breath on the XP
## fill. The tint carries the meaning; this only adds emphasis, so reduced
## motion simply never starts it.
func _update_pulse(uncommitted: bool) -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	_xp_fill.modulate.a = 1.0
	if uncommitted and Settings.ui_motion_enabled:
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(_xp_fill, "modulate:a", 0.55, 0.6)
		_pulse_tween.tween_property(_xp_fill, "modulate:a", 1.0, 0.6)


# =============================================================================
# WIDGET HELPERS
# =============================================================================

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


func _live_label(text_value: String, color: Color, glow: Color) -> Label:
	var label := GlowLabel.styled(text_value, UIManager.font_8px, 8, color, glow)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
