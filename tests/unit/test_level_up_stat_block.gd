## LevelUpStatBlock — the one level-up reveal, shared by the mid-battle
## LevelUpStatPanel and the intermission bEXP pour. Pins the ding staircase
## that moved here from the retired post-battle report (2026-09-09) and the
## rebuild's exact row indexing (hosts and tests address rows by index).
extends GutTest


var _saved_motion: bool = true


func before_each() -> void:
	_saved_motion = Settings.ui_motion_enabled


func after_each() -> void:
	Settings.ui_motion_enabled = _saved_motion


func _unit() -> CharacterData:
	var data := CharacterData.new()
	data.character_name = "Block Test"
	data.level = 4
	data.base_max_hp = 20
	data.base_strength = 8
	return data


func _built(unit: CharacterData, before: Dictionary, show_deltas: bool) -> LevelUpStatBlock:
	var block := LevelUpStatBlock.new()
	add_child_autofree(block)
	block.build(unit, before, show_deltas, false)
	return block


func _ding_pitches(block: LevelUpStatBlock) -> Array[float]:
	var pitches: Array[float] = []
	for child: Node in block.get_children():
		if child is AudioStreamPlayer:
			pitches.append((child as AudioStreamPlayer).pitch_scale)
	return pitches


# =============================================================================
# THE DING STAIRCASE
# =============================================================================

func test_ding_sample_exists_and_pitch_climbs_per_ding() -> void:
	assert_true(ResourceLoader.exists(LevelUpStatBlock.DING_STREAM_PATH),
			"generated placeholder chime is on disk (tools/godot/generate_ui_sfx.gd)")
	var unit := _unit()
	var block := _built(unit, LevelUpStatBlock.stat_snapshot(unit), true)
	block.play_ding()
	block.play_ding()
	var pitches := _ding_pitches(block)
	assert_eq(pitches.size(), 2, "one fire-and-forget player per ding")
	assert_almost_eq(pitches[0], 1.0, 0.001, "first ding rings the root note")
	assert_almost_eq(pitches[1], LevelUpStatBlock.DING_SEMITONE_RATIO, 0.001,
			"each successive ding rings a semitone higher — the ascending staircase")


func test_every_plus_one_reveal_rings_and_the_staircase_resets_per_build() -> void:
	Settings.ui_motion_enabled = true
	var unit := _unit()
	var before: Dictionary = LevelUpStatBlock.stat_snapshot(unit)
	unit.growth_gains_strength += 1
	unit.growth_gains_agility += 1
	var block := _built(unit, before, false)
	await block.play_reveal()
	# The ~140 ms chime frees its player before the next 180 ms beat, so
	# count dings, not survivors; the last player is always still ringing.
	assert_eq(block._dings_played, 2, "a ding per revealed +1 — the reveal makes noise now")
	var pitches := _ding_pitches(block)
	assert_gt(pitches.size(), 0, "the last ding's player is still up")
	assert_almost_eq(pitches[-1], LevelUpStatBlock.DING_SEMITONE_RATIO, 0.001,
			"the second +1 rang a semitone above the first — it climbs")

	block.build(unit, before, true, false)
	assert_eq(block._dings_played, 0, "a rebuild starts the next character on the root note")
	assert_eq(_ding_pitches(block).size(), 0, "stale players leave with the rows")


func test_a_skipped_reveal_stops_ringing() -> void:
	Settings.ui_motion_enabled = true
	var unit := _unit()
	var before: Dictionary = LevelUpStatBlock.stat_snapshot(unit)
	unit.growth_gains_strength += 1
	unit.growth_gains_agility += 1
	var block := _built(unit, before, false)
	block.play_reveal()
	block.abort_reveal()
	await wait_seconds(LevelUpStatBlock.REVEAL_STAGGER_SECONDS * 3.0)
	assert_eq(_ding_pitches(block).size(), 0,
			"a skip shows the gains silently — no staircase after the player moved on")
	for plus: GlowLabel in block._plus_labels:
		assert_true(plus.visible, "…but every gain is shown")


# =============================================================================
# REBUILD — exact row indices in the same frame
# =============================================================================

func test_a_rebuild_leaves_exactly_the_eight_rows_at_once() -> void:
	var unit := _unit()
	var block := _built(unit, LevelUpStatBlock.stat_snapshot(unit), true)
	block.play_ding()
	block.build(unit, LevelUpStatBlock.stat_snapshot(unit), true, false)
	assert_eq(block.get_child_count(), UnitSheet.STAT_ROWS.size(),
			"queued-free children are removed immediately — get_child(i) is row i")
	var defense_row: Control = block.get_child(6)
	assert_eq((defense_row.get_child(0) as Label).text, str(UnitSheet.STAT_ROWS[6][1]),
			"row 6 is the DEF row the bEXP panel test addresses by index")
