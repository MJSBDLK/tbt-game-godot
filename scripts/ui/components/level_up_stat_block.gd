## The reusable level-up stat rows — LABEL · GAUGE · VALUE · [+1] — shared by
## the mid-battle LevelUpStatPanel and the intermission bEXP spend panel
## (RQD 2026-08-11: the level-up reveal is ONE component, wherever it plays).
## Rows come from the same vocabulary as every other stat surface (UnitSheet
## statics + StatCapBar), so caps and at-cap SUCCESS render identically to
## the sheet and the detail panel by construction.
##
## MODIFIER STRIPPING (the RQD "remove/restore modifiers around animations"
## rule): a reveal tells the GROWTH story, so `show_modifiers = false` renders
## raw grown values with no bonus segments — a "+1" beside an injury-carved
## bar would read as a lie. Hosts that show the block at rest build with
## `show_modifiers = true` (full effective stats, penalties and all) and
## rebuild stripped just for the animation, restoring after.
class_name LevelUpStatBlock
extends VBoxContainer


## Stagger between consecutive "+1" reveals — one rhythm for every
## celebration in the game (this block is the only reveal there is).
const REVEAL_STAGGER_SECONDS: float = 0.18
const REVEAL_PUNCH_SECONDS: float = 0.28

const STAT_BAR_WIDTH: float = 64.0
const STAT_BAR_HEIGHT: int = 3

## The ding (placeholder chime from tools/godot/generate_ui_sfx.gd; Lawrence
## replaces the file, same name). Each successive ding on one build rings a
## semitone higher — the ascending staircase IS the dopamine (2^(1/12) per
## step); build() resets it so every character's reveal starts on the root.
## Moved here from the retired post-battle LevelUpReportPanel (2026-09-09)
## so the mid-battle reveal and the intermission bEXP pour both make noise.
const DING_STREAM_PATH: String = "res://audio/ui/ding_level_up.wav"
const DING_SEMITONE_RATIO: float = 1.059463


var _plus_labels: Array[GlowLabel] = []
var _reveal_aborted: bool = false
var _dings_played: int = 0


# =============================================================================
# PURE STATICS — snapshot / diff
# =============================================================================

## Everything a reveal needs to diff against, captured BEFORE grant_xp or
## process_bexp_level_up roll growths: per-stat grown values, the level, and
## the spendable stat-up pool.
static func stat_snapshot(character: CharacterData) -> Dictionary:
	var stats: Dictionary = {}
	for entry: Array in UnitSheet.STAT_ROWS:
		var stat_name: String = str(entry[0])
		stats[stat_name] = character.get_base_plus_growth(stat_name)
	return {
		"level": character.level,
		"stat_ups": character.available_stat_ups,
		"stats": stats,
	}


## The stats whose GROWN value rose since the snapshot, in display order.
static func grown_stats(before: Dictionary, character: CharacterData) -> Array[String]:
	var grown: Array[String] = []
	var stats: Dictionary = before.get("stats", {})
	for entry: Array in UnitSheet.STAT_ROWS:
		var stat_name: String = str(entry[0])
		if character.get_base_plus_growth(stat_name) > int(stats.get(stat_name, 0)):
			grown.append(stat_name)
	return grown


## Newly awarded spendable points since the snapshot (level milestones).
static func stat_ups_gained(before: Dictionary, character: CharacterData) -> int:
	return maxi(0, character.available_stat_ups - int(before.get("stat_ups", 0)))


# =============================================================================
# BUILD + REVEAL
# =============================================================================

func _init() -> void:
	add_theme_constant_override("separation", 2)


## Rebuilds the eight rows. `show_deltas_immediately` seats every grown "+1"
## visible (reduced motion / at-rest hosts); otherwise they hide until
## play_reveal gives each its beat.
func build(character: CharacterData, before: Dictionary,
		show_deltas_immediately: bool, show_modifiers: bool) -> void:
	# remove_child BEFORE queue_free so a rebuild's row indices are exact in
	# the same frame (hosts and tests address rows by index) — a queued-free
	# child still counts as a child until the frame ends.
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_plus_labels.clear()
	_reveal_aborted = false
	_dings_played = 0
	var grown: Array[String] = grown_stats(before, character)
	for entry: Array in UnitSheet.STAT_ROWS:
		add_child(_stat_row(character, str(entry[0]), str(entry[1]),
				grown.has(str(entry[0])), show_deltas_immediately, show_modifiers))


## Staggered "+1" pops, one beat per grown stat. Awaitable; returns early if
## abort_reveal() fires mid-run (skip-clicks). Callers gate on
## Settings.ui_motion_enabled — with motion off, build with deltas shown
## instead of calling this.
func play_reveal() -> void:
	for plus: GlowLabel in _plus_labels:
		if _reveal_aborted:
			return
		await get_tree().create_timer(REVEAL_STAGGER_SECONDS).timeout
		if _reveal_aborted or not is_instance_valid(plus):
			return
		plus.visible = true
		play_ding()
		plus.pivot_offset = plus.size / 2.0
		plus.scale = Vector2(1.6, 1.6)
		var tween := create_tween()
		tween.tween_property(plus, "scale", Vector2.ONE,
				REVEAL_PUNCH_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Skip: stop the choreography and show every remaining gain — a skip must
## never hide a roll.
func abort_reveal() -> void:
	_reveal_aborted = true
	for plus: GlowLabel in _plus_labels:
		if is_instance_valid(plus):
			plus.visible = true
			plus.scale = Vector2.ONE


## One ding, one step up the staircase. Fire-and-forget player, same pattern
## as InteractiveButton._play_sfx; overlapping ring-outs are intentional at
## the 0.18 s stagger. Silent when the sample is missing (a stripped build
## never errors) or off-tree. Public so a host can ring its own beat — the
## battle panel's stat-up badge continues the climb after the last "+1".
## Players are appended AFTER the rows, so row indices never shift.
func play_ding() -> void:
	if not is_inside_tree() or not ResourceLoader.exists(DING_STREAM_PATH):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(DING_STREAM_PATH) as AudioStream
	player.bus = &"SFX"
	player.pitch_scale = pow(DING_SEMITONE_RATIO, _dings_played)
	_dings_played += 1
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _stat_row(character: CharacterData, stat_name: String, abbrev: String,
		grew: bool, show_delta: bool, show_modifiers: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)

	var key := UnitSheet.dim_label(abbrev)
	key.custom_minimum_size.x = 22
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(key)

	var bar := StatCapBar.new(stat_name, STAT_BAR_HEIGHT)
	bar.custom_minimum_size = Vector2(STAT_BAR_WIDTH, STAT_BAR_HEIGHT)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Stripped mode hides the bonus segment — the reveal is about growth,
	# and modifiers return with the at-rest rebuild.
	bar.show_bonus = show_modifiers
	bar.set_stat(character, stat_name)
	row.add_child(bar)

	var capped: bool = StatCapBar.is_at_cap(character, stat_name)
	var value_color: Color = GameColors.TEXT_SUCCESS if capped else GameColors.TEXT_PRIMARY
	var value_glow: Color = GameColors.TEXT_SUCCESS_GLOW if capped else GameColors.TEXT_PRIMARY_GLOW
	var shown_value: int = character.get(stat_name) if show_modifiers \
			else character.get_base_plus_growth(stat_name)
	var value := GlowLabel.styled(str(shown_value),
			UIManager.font_8px, 8, value_color, value_glow)
	value.custom_minimum_size.x = 16
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)

	# The "+1" seat exists on every row so the columns line up; only grown
	# rows ever show theirs. SUCCESS voice: growth is the win condition.
	var plus := GlowLabel.styled("+1", UIManager.font_8px, 8,
			GameColors.TEXT_SUCCESS, GameColors.TEXT_SUCCESS_GLOW)
	plus.custom_minimum_size.x = 14
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.visible = grew and show_delta
	row.add_child(plus)
	if grew:
		_plus_labels.append(plus)

	return row
