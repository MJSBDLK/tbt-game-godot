## The bEXP SPEND panel (slice 4; pour spec 2026-08-13, revised same day):
## swaps in for the UnitSheet in Manage Units' center column. The stat rows
## are the same LevelUpStatBlock the mid-battle celebration uses.
##
## THE POUR MODEL, current form (RQD pivots 2A + round 4):
##
##   [RESET] [-10] [-1] [+1] [+10] [99] [100] [CONFIRM]
##   — one centered row, above the XP bar
##
## SINGLE-LEVEL CAP: a unit's stage can never cross more than one level
## boundary (staged + experience <= 100). [100] fills exactly to the level;
## [99] parks at the brink; the minus buttons refund the stage and [RESET]
## takes back the bound unit's whole pour. Leaving (✕ / Escape / the toggle)
## discards EVERY unit's stage. Nothing commits but CONFIRM — and after a
## level-up reveal the panel HOLDS the +1 view until the player continues
## (CONTINUE square or a click anywhere): gains are acknowledged, never
## yanked away on a timer.
##
## Buttons wear the StatUp [−]/[+] scheme (UnitSheet._make_alloc_button's
## vocabulary, text edition): square 1px ring + glyph in ONE voice,
## brightening together on hover, MUTED when the press would change nothing.
## Glow on the glyph only — the ring is a stylebox draw, which the glow
## shader passes through untouched, exactly the "not on the border, too
## tight" rule.
##
## TWO KINDS OF BUTTON, TOLD APART BY VOICE (RQD 2026-08-16): the six pour
## squares are INCREMENTS and wear PRIMARY (azure = interactivity's hue);
## RESET and CONFIRM are STAGE OPERATIONS and wear their own marks —
##   CONFIRM = the call to action in its motion-parked form: the INFO gold
##            ring + glyph §14 gives the CTA with motion off (the amber
##            monopoly, no rings — those stay reserved). Gold rhymes with the
##            committed XP fill it's about to turn the staged segment into.
##   RESET   = the DANGER voice: red ring + glyph, the universal undo/discard
##            mark, deliberately NOT a gold — WARNING is a gold too, and two
##            golds one gap apart is the "they look the same" problem again.
##            Red 5 sits below banana gold, so billing reads CONFIRM > RESET
##            > ± straight off the palette.
## Plus PROXIMITY: an ACTION_GROUP_GAP either side of the ± cluster, so the
## two stage-ops read as a different family before color even registers.
## Eight identical PRIMARY squares made "reset or commit is next" invisible.
##
## THE TWO-SEGMENT BAR (RQD 2026-08-13): committed XP keeps its normal INFO
## gold; the staged extension is its own segment in the PRIMARY pair,
## pulsing. PRIMARY over the other candidates (RQD asked for the options to
## be weighed): SECONDARY is a near-gold and turns the bar to mush at 4px;
## SUCCESS means committed wins (at-cap, growth +1s) and must not mark
## something revocable; MUTED is too quiet for the one thing on screen
## asking for a decision. Azure also reads right semantically — it's the
## interactive family's hue, and a staged pour is input-in-flight, not a
## fact. The pulse is motion-gated emphasis; the hue split alone carries the
## meaning for reduced-motion players (the two-marks rule).
##
## CONFIRM commits through SquadManager.commit_bexp_pour: 1:1 into REAL
## experience, a crossed 100 rolls one bEXP-mechanics level (revealed via
## the block, modifiers stripped then restored), and sub-level XP persists —
## the 99 brink's whole reason to exist: the next combat action takes the
## level with full growth rolls instead of bEXP's fixed spread.
class_name BexpSpendPanel
extends PanelContainer


## A commit happened — rail badges, workbench squad stats, and the top bar's
## pool readout are stale.
signal changed
## The player is done — the screen restores the sheet.
signal closed
## The player acknowledged the level-up reveal (the CONTINUE press). Internal
## pacing signal — the confirm coroutine awaits it.
signal continue_pressed


const XP_PER_LEVEL: int = 100
## Extra pixels (on top of the row's 2px separation) isolating the ± cluster
## from RESET / CONFIRM — grouping by proximity. Budgeted against the sheet
## column: the row must still fit SHEET_WIDTH minus margins (pinned by test).
const ACTION_GROUP_GAP: int = 4


var _character: CharacterData = null
## character_id -> staged pour (uncommitted, refundable-by-discard). Held
## across rail switches so pouring is a squad-wide decision with one confirm.
var _staged: Dictionary = {}
var _revealing: bool = false
## The reveal finished and the panel is holding the +1 view for the player
## (RQD 2026-08-13 round 4: don't yank the gains away on a timer).
var _awaiting_continue: bool = false

var _stack: VBoxContainer = null
var _name_label: Label = null
var _level_value_label: Label = null
var _pool_value_label: Label = null
var _actions_row: HBoxContainer = null
var _xp_committed_fill: GlowColorRect = null
var _xp_staged_fill: GlowColorRect = null
var _xp_value_label: Label = null
var _block: LevelUpStatBlock = null
var _pulse_tween: Tween = null


# =============================================================================
# PURE POUR MATH — the staging layer is arithmetic, so it's all testable
# =============================================================================

## New staged value after a button press. Three bounds: refunds floor at 0
## (unused since the minus buttons left, kept for the math's honesty), pours
## ceiling at the pool, and the whole stage ceilings at ONE level
## (RQD pivot 2A: staged + experience never exceeds 100).
static func clamp_pour(staged: int, delta: int, pool_remaining: int,
		experience: int) -> int:
	var level_cap: int = maxi(0, XP_PER_LEVEL - experience)
	return clampi(staged + delta, 0,
			mini(staged + maxi(0, pool_remaining), level_cap))


## The brink: how much more to pour so the gauge parks at 99/100.
static func brink_amount(gauge: int) -> int:
	return maxi(0, (XP_PER_LEVEL - 1) - gauge)


func _ready() -> void:
	# The sheet's chrome — this panel stands in the sheet's column slot.
	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.HUD_PANEL_BACKGROUND
	style.border_color = GameColorPalette.get_color("Straw2", 3)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)
	_build()


func bind(character: CharacterData) -> void:
	# A rail switch mid-hold counts as the acknowledgement — resolve the
	# waiting confirm coroutine so it can't hang across a rebind.
	_resolve_pending_continue()
	_character = character
	_refresh()


## Leaving the panel abandons the whole stage — only CONFIRM commits.
func discard_stage() -> void:
	_resolve_pending_continue()
	_staged.clear()
	if _character != null:
		_refresh()


func _resolve_pending_continue() -> void:
	if _awaiting_continue:
		continue_pressed.emit()


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
	title_row.add_child(_close_button())

	var ident_row := HBoxContainer.new()
	ident_row.add_theme_constant_override("separation", 6)
	_stack.add_child(ident_row)
	_name_label = _live_label("", GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW)
	ident_row.add_child(_name_label)
	_level_value_label = _live_label("", GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW)
	ident_row.add_child(_level_value_label)

	# The action row — pour squares + CONFIRM, one line, centered (RQD
	# 2026-08-13 round 4), ABOVE the XP bar (2B). Rebuilt per refresh like
	# the StatUp buttons, so each button is constructed already in its
	# current state. Eight buttons in a 200px column — separation 2 and 2px
	# glyph margins keep the row inside the sheet width (pinned by test: the
	# row's minimum must fit SHEET_WIDTH, so a label change can't silently
	# overflow).
	_actions_row = HBoxContainer.new()
	_actions_row.add_theme_constant_override("separation", 2)
	_actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stack.add_child(_actions_row)

	# XP row — track + committed INFO fill + staged PRIMARY segment.
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
	_xp_committed_fill = UnitSheet.glow_bar(
			GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW, 0.0)
	_xp_committed_fill.visible = false
	track.add_child(_xp_committed_fill)
	_xp_staged_fill = UnitSheet.glow_bar(
			GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW, 0.0)
	_xp_staged_fill.visible = false
	track.add_child(_xp_staged_fill)
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


# =============================================================================
# POUR (staged, discard-refundable)
# =============================================================================

func _on_pour_pressed(amount: int) -> void:
	if _revealing or _character == null:
		return
	var staged: int = _staged_for_bound()
	var new_staged: int = clamp_pour(staged, amount, _pool_remaining(),
			_character.experience)
	if new_staged == staged:
		return
	_staged[_character.character_id] = new_staged
	_refresh()


func _on_brink_pressed() -> void:
	if _revealing or _character == null:
		return
	_on_pour_pressed(brink_amount(_character.experience + _staged_for_bound()))


## Take back the BOUND unit's whole stage in one press (other units' stages
## survive — this is a per-unit undo, not the panel-wide discard).
func _on_reset_pressed() -> void:
	if _revealing or _character == null:
		return
	if _staged.erase(_character.character_id):
		_refresh()


func _on_close_pressed() -> void:
	discard_stage()
	closed.emit()


# =============================================================================
# CONFIRM — the one commit (at most one level per unit, by the staging cap)
# =============================================================================

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
	var amount: int = _staged_for_bound()
	_staged.clear()
	changed.emit()
	if amount > 0:
		var before: Dictionary = LevelUpStatBlock.stat_snapshot(_character)
		var leveled: int = SquadManager.commit_bexp_pour(_character, amount)
		if leveled > 0:
			changed.emit()
			_level_value_label.text = "Lv %d" % _character.level
			_pool_value_label.text = str(SquadManager.bonus_xp_pool)
			_block.build(_character, before, not Settings.ui_motion_enabled, false)
			if Settings.ui_motion_enabled:
				await _block.play_reveal()
			# Hold the +1 view until the player says so (round 4) — a timer
			# yanking the gains away made the reveal feel like a glitch.
			_awaiting_continue = true
			_show_continue_action()
			await continue_pressed
			_awaiting_continue = false
	_revealing = false
	changed.emit()
	_refresh()


## The reveal's parking state: the action row collapses to one enabled
## CONTINUE square. Clicking anywhere on the panel body works too — the
## affordance is the button, the forgiveness is the whole surface.
func _show_continue_action() -> void:
	for child: Node in _actions_row.get_children():
		child.queue_free()
	_actions_row.add_child(_square_button("CONTINUE", true,
			"back to the pour view", func() -> void: continue_pressed.emit()))


func _gui_input(event: InputEvent) -> void:
	if _awaiting_continue and event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		continue_pressed.emit()


# =============================================================================
# REFRESH — every readout derived from the stage is a preview
# =============================================================================

func _refresh() -> void:
	if _character == null:
		return
	var staged: int = _staged_for_bound()
	var uncommitted: bool = staged > 0
	# The single-level cap keeps the gauge in 0..100 — no wrapping.
	var gauge: int = _character.experience + staged

	_name_label.text = _character.character_name.to_upper()
	# » not →: the arrow isn't in UndeadPixelLight8, and the fallback font's
	# taller metrics grew the label and shoved the whole GUI down a few px
	# the moment the preview line appeared (RQD 2026-08-13).
	_level_value_label.text = ("Lv %d » %d" % [_character.level, _character.level + 1]) \
			if gauge >= XP_PER_LEVEL else "Lv %d" % _character.level

	# Committed keeps its normal gold; the staged extension is its own
	# PRIMARY segment starting where the committed fill ends.
	var committed_ratio: float = clampf(
			_character.experience / float(XP_PER_LEVEL), 0.0, 1.0)
	var gauge_ratio: float = clampf(gauge / float(XP_PER_LEVEL), 0.0, 1.0)
	_xp_committed_fill.visible = committed_ratio > 0.0
	_xp_committed_fill.anchor_right = committed_ratio
	_xp_staged_fill.visible = uncommitted
	_xp_staged_fill.anchor_left = committed_ratio
	_xp_staged_fill.anchor_right = gauge_ratio
	_xp_value_label.text = "%d/100" % gauge
	_pool_value_label.text = str(_pool_remaining())

	# Preview text joins the staged segment's voice; committed state keeps
	# the INFO live-value gold.
	var value_color: Color = GameColors.TEXT_PRIMARY if uncommitted else GameColors.TEXT_INFO
	var value_glow: Color = GameColors.TEXT_PRIMARY_GLOW if uncommitted else GameColors.TEXT_INFO_GLOW
	for preview_label: Label in [_level_value_label, _xp_value_label, _pool_value_label]:
		preview_label.add_theme_color_override("font_color", value_color)
		if preview_label.material is ShaderMaterial:
			preview_label.material.set_shader_parameter("glow_color", value_glow)
	_update_pulse(uncommitted)

	# UNMODIFIED stats, always (RQD 2026-08-13): this venue is about growth —
	# what bEXP levels actually move. Modifiers (injuries, buffs, StatUps)
	# live one Escape away on the manage screen; showing them here made the
	# post-reveal "restore" read as the stats jumping. Stripped at rest and
	# stripped in the reveal = nothing ever blends.
	_block.build(_character, LevelUpStatBlock.stat_snapshot(_character), true, false)
	_rebuild_actions(staged)


## [RESET] [-10] [-1] [+1] [+10] [99] [100] [CONFIRM] — every button
## constructed already in its enabled/disabled state (the StatUp-button
## pattern), so enablement is a build-time fact, not mutated chrome.
## RESET clears the BOUND unit's stage only; leaving the panel is still the
## all-units discard.
func _rebuild_actions(staged: int) -> void:
	for child: Node in _actions_row.get_children():
		child.queue_free()
	var pool_remaining: int = _pool_remaining()
	var experience: int = _character.experience
	var gauge: int = experience + staged

	_actions_row.add_child(_square_button("RESET", staged > 0,
			"take back this unit's staged pour" if staged > 0 else "nothing staged here",
			_on_reset_pressed, GameColors.TEXT_DANGER, GameColors.TEXT_DANGER_GLOW))
	_actions_row.add_child(_group_gap())

	for amount: int in [-10, -1, 1, 10]:
		var would: int = clamp_pour(staged, amount, pool_remaining, experience)
		var label_text: String = ("+%d" % amount) if amount > 0 else str(amount)
		_actions_row.add_child(_square_button(label_text, would != staged,
				("pour %d" % amount) if amount > 0 else ("refund %d" % -amount),
				_on_pour_pressed.bind(amount)))

	var brink: int = brink_amount(gauge)
	_actions_row.add_child(_square_button("99",
			brink > 0 and clamp_pour(staged, brink, pool_remaining, experience) != staged,
			("pour %d — park at 99/100 so a combat action takes the level" +
			" (full growth rolls, not bEXP's fixed spread)") % brink
			if brink > 0 else "already at the brink",
			_on_brink_pressed))

	# [100] fills exactly to the level boundary — the clamp's level cap IS
	# the "max out at a single level-up" pivot (2A), so a full-pool press
	# stages only what one level needs.
	var full_would: int = clamp_pour(staged, XP_PER_LEVEL, pool_remaining, experience)
	_actions_row.add_child(_square_button("100", full_would != staged,
			"fill the level — %d more" % maxi(0, XP_PER_LEVEL - gauge),
			_on_pour_pressed.bind(XP_PER_LEVEL)))
	_actions_row.add_child(_group_gap())

	var confirm := _square_button("CONFIRM",
			_staged_total() > 0 and not _revealing,
			"roll the staged level — commits, growths are final"
			if _staged_total() > 0 else "nothing staged",
			_on_confirm_pressed, GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW)
	_actions_row.add_child(confirm)


## The proximity mark between the ± cluster and a stage-op (see header).
func _group_gap() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(ACTION_GROUP_GAP, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


# =============================================================================
# WIDGET HELPERS
# =============================================================================

## The StatUp [−]/[+] scheme, text edition: square 1px ring + glyph in one
## voice — `body`/`glow` when enabled (PRIMARY by default; INFO for CONFIRM,
## DANGER for RESET — see header), MUTED when the press would do nothing —
## brightening together on hover. Glow on the glyph only — the ring is an
## untextured stylebox draw, which the glow shader passes through, so no
## halo collision.
func _square_button(label_text: String, enabled: bool, tip: String,
		handler: Callable, voice_body: Color = GameColors.TEXT_PRIMARY,
		voice_glow: Color = GameColors.TEXT_PRIMARY_GLOW) -> Button:
	var button := Button.new()
	button.text = label_text
	button.disabled = not enabled
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(14, 14)
	if UIManager.font_8px != null:
		button.add_theme_font_override("font", UIManager.font_8px)
	button.add_theme_font_size_override("font_size", 8)

	var body: Color = voice_body if enabled else GameColors.TEXT_MUTED
	var glow: Color = voice_glow if enabled else GameColors.TEXT_MUTED_GLOW
	button.add_theme_color_override("font_color", body)
	button.add_theme_color_override("font_disabled_color", body)
	button.add_theme_color_override("font_hover_color", GameColors.brightened(body))
	button.add_theme_color_override("font_pressed_color", GameColors.brightened(body))
	var button_material := (load("res://resources/hud_glow.tres") as Material).duplicate()
	(button_material as ShaderMaterial).set_shader_parameter("glow_color", glow)
	button.material = button_material

	var ring := StyleBoxFlat.new()
	ring.bg_color = Color.TRANSPARENT
	ring.border_color = body
	ring.set_border_width_all(1)
	ring.content_margin_left = 2
	ring.content_margin_right = 2
	# Glyph sits 1px below true center (RQD 2026-08-16) — the same optical
	# correction InteractiveButton's TEXT_TOP/BOTTOM_MARGIN_PIXELS make: the
	# 8px font's ink sits low, so geometric center reads high. Asymmetric
	# margins keep the 14px square; only the text moves.
	ring.content_margin_top = 2
	ring.content_margin_bottom = 0
	var ring_hover := ring.duplicate() as StyleBoxFlat
	ring_hover.border_color = GameColors.brightened(body)
	button.add_theme_stylebox_override("normal", ring)
	button.add_theme_stylebox_override("disabled", ring)
	button.add_theme_stylebox_override("focus", ring)
	button.add_theme_stylebox_override("hover", ring_hover)
	button.add_theme_stylebox_override("pressed", ring_hover)

	button.pressed.connect(handler)
	return button


## The ✕ keeps the bare-glyph recipe (no ring — it's a leave, not an action
## in the pour vocabulary).
func _close_button() -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.text = "✕"
	if UIManager.font_8px != null:
		button.add_theme_font_override("font", UIManager.font_8px)
	button.add_theme_font_size_override("font_size", 8)
	button.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color",
			GameColors.brightened(GameColors.TEXT_PRIMARY))
	var button_material := (load("res://resources/hud_glow.tres") as Material).duplicate()
	(button_material as ShaderMaterial).set_shader_parameter("glow_color",
			GameColors.TEXT_PRIMARY_GLOW)
	button.material = button_material
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(_on_close_pressed)
	return button


## The motion half of the uncommitted mark: a slow alpha breath on the
## STAGED segment only — committed gold never pulses. The hue split carries
## the meaning; this only adds emphasis, so reduced motion never starts it.
func _update_pulse(uncommitted: bool) -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	_xp_staged_fill.modulate.a = 1.0
	if uncommitted and Settings.ui_motion_enabled:
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(_xp_staged_fill, "modulate:a", 0.55, 0.6)
		_pulse_tween.tween_property(_xp_staged_fill, "modulate:a", 1.0, 0.6)


func _live_label(text_value: String, color: Color, glow: Color) -> Label:
	var label := GlowLabel.styled(text_value, UIManager.font_8px, 8, color, glow)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
