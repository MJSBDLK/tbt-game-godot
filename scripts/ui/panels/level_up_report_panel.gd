## Between-mission level-up celebration screen.
##
## SCOPE — functional scaffolding only. Per the project's UI work order
## (see [[feedback-ui-scope-order]]) this lands functionality-first so the user
## can mock up the stylized version on top, with Lawrence doing final polish.
## Anything cosmetic in here (colors, layout proportions, animation curves,
## sound stubs) is a placeholder.
##
## Why this screen exists ([[project-level-up-screen]]):
##   Level-ups are the long-term retention hook. Mission-scoped facts and
##   consequences (turns, income, injuries) live on BattleResultPanel; this
##   screen is the separated dopamine moment for character growth.
##
## DATA CONTRACT — receives the same Array as BattleResultPanel via
## show_report(). Each entry is a Dictionary with these fields (set by
## SquadManager._on_battle_ended). The screen only renders entries where
## `level_after > level_before`; everyone else is skipped:
##   "character_name": String
##   "level_before": int
##   "level_after": int
##   "growths_gained": Array[String]   # ["STR", "AGL", ...]
##   "stat_ups_gained": int            # spendable points awarded this level
##
## Sequence per leveled character:
##   1. Card slides/fades in
##   2. "Lv X → Lv Y" header pulses on the new level
##   3. Growth "+1" floaters stagger in next to each grown stat (120ms apart),
##      each triggering a ding hook (currently stubbed — see _play_ding())
##   4. Stat-up badge punches in (if stat_ups_gained > 0)
##   5. "Next" button becomes interactive
##
## EMITS `closed` when the user clicks past the last leveled character —
## UIManager then chains BonusXpPanel (injuries already showed on the result
## screen before this one). If no one leveled (defeat, or victory where every
## survivor whiffed growths AND was at no stat-up milestone), UIManager skips
## this screen.
class_name LevelUpReportPanel
extends Control


signal closed


# Stagger between consecutive stat reveals on a single character card. Tuned
# so each ding gets its own beat without the whole sequence dragging — adjust
# alongside the real sound asset.
const GROWTH_STAGGER_SECONDS: float = 0.18

# Length of the "boing" scale punch when a stat's growth reveals. The row
# overshoots then settles back to 1.0; the "+1 → N" text stays visible
# afterwards (no fade-out).
const REVEAL_PUNCH_SECONDS: float = 0.28

# Delay between the last growth reveal and the Next button becoming
# interactive. Forces a small breath so the dopamine moment lands; without it
# the player blasts through.
const POST_ANIMATION_PAUSE_SECONDS: float = 0.35


# Stat rows rendered top-to-bottom. Each entry: [growth_abbrev, display_label,
# CharacterData stat-name key]. growth_abbrev matches the abbreviations packed
# into `growths_gained` by SquadManager so we know which rows light up.
const _STAT_ROWS: Array = [
	["HP",  "HP",  "max_hp"],
	["STR", "STR", "strength"],
	["SPC", "SPC", "special"],
	["SKL", "SKL", "skill"],
	["AGL", "AGL", "agility"],
	["ATH", "ATH", "athleticism"],
	["DEF", "DEF", "defense"],
	["RES", "RES", "resistance"],
]


# Filtered list of report entries for characters who actually leveled. Indexed
# by _current_index as the user advances through the celebration.
var _leveled_entries: Array = []
var _current_index: int = 0

# Per-character cached row value labels keyed by stat abbrev. Rebuilt for each
# character so the reveal animation can rewrite the right row when its stagger
# timer fires.
var _stat_value_labels: Dictionary = {}  # stat_abbrev -> RichTextLabel

var _portrait: TextureRect = null
var _name_label: Label = null
var _level_header: RichTextLabel = null
var _stat_rows_box: VBoxContainer = null
var _statup_badge: Label = null
var _progress_label: Label = null
var _next_button: Button = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_chrome()


# =============================================================================
# PUBLIC API
# =============================================================================

## Filters the report to leveled characters and begins the sequence. If no one
## leveled, emits `closed` immediately without showing — UIManager treats that
## as the skip case.
func show_report(report: Array) -> void:
	_leveled_entries.clear()
	for entry: Dictionary in report:
		var before: int = entry.get("level_before", 0)
		var after: int = entry.get("level_after", before)
		if after > before:
			_leveled_entries.append(entry)
	if _leveled_entries.is_empty():
		closed.emit()
		return
	_current_index = 0
	visible = true
	_show_current_entry()


# =============================================================================
# BUILD
# =============================================================================

func _build_chrome() -> void:
	var ui_manager: Node = UIManager

	# Dim background — Lawrence pass will replace with proper backdrop art.
	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.05, 0.06, 0.10, 0.92)
	add_child(background)

	# Centered card. Anchors approximate a 16:9 card centered in the 640x360
	# reference resolution.
	var card := VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.anchor_left = 0.18
	card.anchor_right = 0.82
	card.anchor_top = 0.12
	card.anchor_bottom = 0.88
	card.add_theme_constant_override("separation", 6)
	add_child(card)

	# Top: "LEVEL UP" banner. Cosmetic — Lawrence pass will treat this as a
	# title plate with custom font / glow / animation.
	var banner := Label.new()
	banner.text = "LEVEL UP"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null:
		banner.add_theme_font_override("font", ui_manager.font_11px)
		banner.add_theme_font_size_override("font_size", 11)
	banner.modulate = GameColorPalette.get_color("Yellow", 7)
	card.add_child(banner)

	# Body row: portrait | info column
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	card.add_child(body)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(64, 64)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(_portrait)

	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 4)
	body.add_child(info_col)

	_name_label = Label.new()
	if ui_manager != null:
		_name_label.add_theme_font_override("font", ui_manager.font_11px)
		_name_label.add_theme_font_size_override("font_size", 11)
	info_col.add_child(_name_label)

	_level_header = RichTextLabel.new()
	_level_header.bbcode_enabled = true
	_level_header.fit_content = true
	_level_header.scroll_active = false
	_level_header.custom_minimum_size = Vector2(0, 14)
	if ui_manager != null:
		_level_header.add_theme_font_override("normal_font", ui_manager.font_8px)
		_level_header.add_theme_font_size_override("normal_font_size", 8)
	info_col.add_child(_level_header)

	_stat_rows_box = VBoxContainer.new()
	_stat_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stat_rows_box.add_theme_constant_override("separation", 2)
	info_col.add_child(_stat_rows_box)

	_statup_badge = Label.new()
	_statup_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_statup_badge.modulate = GameColorPalette.get_color("Yellow", 5)
	if ui_manager != null:
		_statup_badge.add_theme_font_override("font", ui_manager.font_8px)
		_statup_badge.add_theme_font_size_override("font_size", 8)
	_statup_badge.visible = false
	info_col.add_child(_statup_badge)

	# Footer: progress indicator + Next button.
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	card.add_child(footer)

	_progress_label = Label.new()
	_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ui_manager != null:
		_progress_label.add_theme_font_override("font", ui_manager.font_5px)
		_progress_label.add_theme_font_size_override("font_size", 5)
	_progress_label.modulate = Color(1.0, 1.0, 1.0, 0.6)
	footer.add_child(_progress_label)

	_next_button = Button.new()
	_next_button.text = "Next"
	_next_button.custom_minimum_size = Vector2(60, 18)
	if ui_manager != null:
		_next_button.add_theme_font_override("font", ui_manager.font_8px)
		_next_button.add_theme_font_size_override("font_size", 8)
	_next_button.pressed.connect(_on_next_pressed)
	footer.add_child(_next_button)


# =============================================================================
# SEQUENCE
# =============================================================================

## Renders the current leveled-character entry and kicks off its animation
## sequence. Each character gets a full fresh render so per-character state
## (portrait, growth row labels) rebuilds from scratch.
func _show_current_entry() -> void:
	var entry: Dictionary = _leveled_entries[_current_index]
	var character_id: String = _resolve_character_id(entry.get("character_name", ""))
	var character: CharacterData = SquadManager.get_character_by_id(character_id) if character_id != "" else null

	_portrait.texture = null
	if character != null:
		_portrait.texture = CharacterPortrait.get_sprite_crop_for(character)

	_name_label.text = entry.get("character_name", "?")

	var level_before: int = entry.get("level_before", 0)
	var level_after: int = entry.get("level_after", level_before)
	var yellow: String = GameColorPalette.get_color("Yellow", 7).to_html(false)
	_level_header.text = "Lv %d  →  [color=#%s][b]Lv %d[/b][/color]" % [level_before, yellow, level_after]

	_rebuild_stat_rows(character, entry.get("growths_gained", []) as Array)

	var stat_ups: int = entry.get("stat_ups_gained", 0)
	_statup_badge.visible = stat_ups > 0
	if stat_ups > 0:
		var noun: String = "STAT-UP POINT" if stat_ups == 1 else "STAT-UP POINTS"
		_statup_badge.text = "★ +%d %s ★" % [stat_ups, noun]

	_progress_label.text = "%d / %d" % [_current_index + 1, _leveled_entries.size()]
	_next_button.text = "Continue" if _current_index == _leveled_entries.size() - 1 else "Next"
	_next_button.disabled = true

	# Kick the animation sequence. Caller doesn't await — _animate_growths
	# re-enables the Next button when it's done.
	_animate_growths(entry.get("growths_gained", []) as Array)


## Tears down and rebuilds the 8 stat rows for the current character. Each row
## renders as "STR  8" before the level-up animation fires for it; after the
## stat's reveal, the row becomes "STR  8 +1 → 9" with the delta in green and
## the new value in yellow. The pre-grow value (`character.get(stat_key) - 1`
## for grown stats) is computed at build time so the row knows where it came
## from — character.get() returns the post-level-up value.
##
## Caches each row's RichTextLabel in _stat_value_labels keyed by stat abbrev
## so _reveal_growth can rewrite it when the stagger timer fires.
func _rebuild_stat_rows(character: CharacterData, growths_gained: Array) -> void:
	for child: Node in _stat_rows_box.get_children():
		child.queue_free()
	_stat_value_labels.clear()

	var grew_set: Dictionary = {}
	for abbrev: String in growths_gained:
		grew_set[abbrev] = true

	var ui_manager: Node = UIManager
	for spec: Array in _STAT_ROWS:
		var abbrev: String = spec[0]
		var label_text: String = spec[1]
		var stat_key: String = spec[2]

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 6)

		var name_label := Label.new()
		name_label.text = label_text
		name_label.custom_minimum_size = Vector2(24, 0)
		if ui_manager != null:
			name_label.add_theme_font_override("font", ui_manager.font_8px)
			name_label.add_theme_font_size_override("font_size", 8)
		row.add_child(name_label)

		var value_label := RichTextLabel.new()
		value_label.bbcode_enabled = true
		value_label.fit_content = true
		value_label.scroll_active = false
		value_label.custom_minimum_size = Vector2(80, 12)
		if ui_manager != null:
			value_label.add_theme_font_override("normal_font", ui_manager.font_8px)
			value_label.add_theme_font_size_override("normal_font_size", 8)

		# Pre-grow value: the current stat minus 1 if it grew. Growth gains are
		# +1 per process_level_up roll, so the delta is always 1 for now. If a
		# future LEVELS_PER_VICTORY > 1 means a stat can roll twice in one
		# mission, this needs to read from a "growth_delta" field on the report.
		var current_value: int = int(character.get(stat_key)) if character != null else 0
		var grew: bool = grew_set.has(abbrev)
		var pre_value: int = current_value - 1 if grew else current_value
		value_label.text = str(pre_value)
		value_label.set_meta("pre_value", pre_value)
		value_label.set_meta("new_value", current_value)
		row.add_child(value_label)

		_stat_value_labels[abbrev] = value_label
		_stat_rows_box.add_child(row)


# =============================================================================
# ANIMATION
# =============================================================================

## Walks the grown stats in _STAT_ROWS order (not the order they appear in
## `growths_gained`) so the animation always reads top-to-bottom. Staggers each
## reveal by GROWTH_STAGGER_SECONDS so the dings land as a rhythmic cascade
## rather than a single chord.
func _animate_growths(growths_gained: Array) -> void:
	var grew_set: Dictionary = {}
	for abbrev: String in growths_gained:
		grew_set[abbrev] = true

	var delay: float = 0.0
	var any_animated: bool = false
	for spec: Array in _STAT_ROWS:
		var abbrev: String = spec[0]
		if not grew_set.has(abbrev):
			continue
		any_animated = true
		_schedule_reveal(abbrev, delay)
		delay += GROWTH_STAGGER_SECONDS

	# Stat-up badge punches in AFTER the last growth ding so it doesn't fight
	# for attention. Lawrence pass: replace with a proper sparkle / shimmer.
	if _statup_badge.visible:
		_schedule_statup_punch(delay)
		delay += 0.2

	# Re-enable Next after the dust settles. _animate_growths returns
	# immediately; this timer fires asynchronously.
	var total_wait: float = delay + REVEAL_PUNCH_SECONDS + POST_ANIMATION_PAUSE_SECONDS
	if not any_animated and not _statup_badge.visible:
		total_wait = 0.1  # No animation to wait on — just a heartbeat.
	get_tree().create_timer(total_wait).timeout.connect(_enable_next_button)


func _enable_next_button() -> void:
	if _next_button == null:
		return
	_next_button.disabled = false
	_next_button.grab_focus()


## Rewrites the stat row to "8 +1 → 9" with the delta in green and the new
## value in yellow, then scale-punches the row so the change "lands." The
## reveal stays on screen permanently — no fade-out — so the player can read
## the full progression after the animation settles.
##
## Lawrence pass: the scale punch is the placeholder boing. Replace with a
## bounce curve, a flash, a sparkle particle, or a per-stat color shift. The
## stat-name label could also pulse alongside the value.
func _schedule_reveal(stat_abbrev: String, delay_seconds: float) -> void:
	get_tree().create_timer(delay_seconds).timeout.connect(
		func() -> void:
			_reveal_growth(stat_abbrev)
			_play_ding(stat_abbrev)
	)


func _reveal_growth(stat_abbrev: String) -> void:
	if not _stat_value_labels.has(stat_abbrev):
		return
	var label: RichTextLabel = _stat_value_labels[stat_abbrev]
	if label == null or not is_instance_valid(label):
		return

	var pre_value: int = int(label.get_meta("pre_value", 0))
	var new_value: int = int(label.get_meta("new_value", pre_value))
	var delta: int = new_value - pre_value
	var green: String = GameColorPalette.get_color("Green", 6).to_html(false)
	var yellow: String = GameColorPalette.get_color("Yellow", 7).to_html(false)
	label.text = "%d  [color=#%s]+%d[/color]  →  [color=#%s][b]%d[/b][/color]" % [
		pre_value, green, delta, yellow, new_value,
	]

	# Scale-punch the row label: shrink under, overshoot, settle. Pivot from
	# the row's left edge so the row doesn't appear to slide — only puff.
	label.pivot_offset = Vector2(0, label.size.y / 2.0)
	label.scale = Vector2(0.7, 0.7)
	var t: Tween = create_tween()
	t.tween_property(label, "scale", Vector2(1.18, 1.18), REVEAL_PUNCH_SECONDS * 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "scale", Vector2(1.0, 1.0), REVEAL_PUNCH_SECONDS * 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _schedule_statup_punch(delay_seconds: float) -> void:
	get_tree().create_timer(delay_seconds).timeout.connect(
		func() -> void:
			if _statup_badge == null or not is_instance_valid(_statup_badge):
				return
			_statup_badge.pivot_offset = _statup_badge.size / 2.0
			_statup_badge.scale = Vector2(0.4, 0.4)
			var t: Tween = create_tween()
			t.tween_property(_statup_badge, "scale", Vector2(1.15, 1.15), 0.15) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(_statup_badge, "scale", Vector2(1.0, 1.0), 0.12)
			_play_ding("stat_up")
	)


## Sound stub. Audio infrastructure doesn't exist yet (no AudioStreamPlayer
## autoload, no SFX assets) — when it lands, swap this for a real call.
## Per-stat differentiation is optional: a single "ding" works fine; a
## distinct tone per stat is the polished version.
##
## To wire up later:
##   var sfx: AudioStreamPlayer = SFXManager.get_oneshot()
##   sfx.stream = preload("res://audio/level_up_ding.ogg")
##   sfx.pitch_scale = _pitch_for_stat(stat_abbrev)  # optional ascending pitch
##   sfx.play()
func _play_ding(_stat_abbrev: String) -> void:
	pass  # PLACEHOLDER — see docstring


# =============================================================================
# NAVIGATION
# =============================================================================

func _on_next_pressed() -> void:
	_current_index += 1
	if _current_index >= _leveled_entries.size():
		_finish()
		return
	_show_current_entry()


func _finish() -> void:
	visible = false
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		if _next_button != null and not _next_button.disabled:
			_on_next_pressed()
			get_viewport().set_input_as_handled()


# =============================================================================
# UTILITIES
# =============================================================================

## Reverse-lookup: the report ships character_name (display text), but
## SquadManager keys by character_id. Walk the active roster to find the id
## whose CharacterData.character_name matches. Returns "" if not found —
## happens for permadead characters (they get filtered out earlier, but
## belt-and-suspenders).
func _resolve_character_id(character_name: String) -> String:
	for character: CharacterData in SquadManager.get_active_roster():
		if character.character_name == character_name:
			return character.character_id
	return ""
