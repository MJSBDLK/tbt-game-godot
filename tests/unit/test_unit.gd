## Unit-level behavior tests. Uses Unit.new() + autofree() (not
## add_child_autofree) so _ready() never fires — fresh Unit instances test
## clean against pure-state getters and methods that don't require the scene
## tree (HealthBar, LevelLabel, etc).
extends GutTest


# =============================================================================
# Rooted status effect → movement range collapses to 0
# =============================================================================

func _make_rooted_effect() -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_type_name = "ROOTED"
	return effect


func _make_unit_with_move_distance(move_distance: int) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	var data := CharacterData.new()
	data.move_distance = move_distance
	unit.character_data = data
	return unit


func test_max_movement_range_zero_when_character_data_null() -> void:
	var unit := Unit.new()
	autofree(unit)
	assert_eq(unit.max_movement_range, 0,
			"Unit without character_data can't move")


func test_max_movement_range_baseline_with_no_status_effects() -> void:
	var unit := _make_unit_with_move_distance(5)
	assert_eq(unit.max_movement_range, 5 * Unit.MOVEMENT_SCALE,
			"Baseline = move_distance * MOVEMENT_SCALE")


func test_foot_tracks_emit_on_commit_not_on_walk() -> void:
	# Regression: tracks must lay only when the move is committed (set_acted),
	# not during the tentative walk — else "preview move + cancel" leaves
	# footprints behind. Here the stash exists but no commit has happened yet.
	var unit := Unit.new()
	autofree(unit)
	watch_signals(unit)
	var path: Array[Tile] = [_make_loose_tile(), _make_loose_tile()]
	unit._pending_track_tiles = path
	assert_signal_not_emitted(unit, "path_traversed", "no tracks before commit")
	unit.set_acted()
	assert_signal_emitted(unit, "path_traversed", "tracks lay on set_acted()")


func test_foot_tracks_cancelled_move_lays_none() -> void:
	# Regression for the reported bug: a cancelled tentative move must lay no
	# tracks, even if the unit later acts.
	var unit := Unit.new()
	autofree(unit)
	watch_signals(unit)
	var path: Array[Tile] = [_make_loose_tile(), _make_loose_tile()]
	unit._pending_track_tiles = path
	unit.cancel_movement()
	unit.set_acted()
	assert_signal_not_emitted(unit, "path_traversed",
			"a cancelled move lays nothing even after a later commit")


func _make_loose_tile() -> Tile:
	var tile := Tile.new()
	autofree(tile)
	return tile


func test_max_movement_range_zero_when_rooted() -> void:
	# Regression: ROOTED debuff used to do nothing because the getter only
	# consulted character_data.get_effective_move_distance() (which scans
	# injuries, never status effects). active_status_effects lives on Unit.
	var unit := _make_unit_with_move_distance(5)
	unit.active_status_effects.append(_make_rooted_effect())
	assert_eq(unit.max_movement_range, 0,
			"Rooted unit can't move regardless of move_distance")


func test_max_movement_range_ignores_non_blocking_effects() -> void:
	# Shocked reduces skill, doesn't block movement. Make sure we don't
	# zero out the range for arbitrary debuffs.
	var unit := _make_unit_with_move_distance(5)
	var shocked := StatusEffect.new()
	shocked.effect_type_name = "SHOCKED"
	unit.active_status_effects.append(shocked)
	assert_eq(unit.max_movement_range, 5 * Unit.MOVEMENT_SCALE,
			"Shocked doesn't block movement")


# =============================================================================
# Capricious post-combat reroll
# =============================================================================
# Behavior: at end of combat, a unit with the Capricious passive caches its
# just-used move into last_used_move_index, then picks a *different* usable
# move from equipped_moves as the new assigned_move. If only one usable move
# remains, keeps the current assignment.

func _make_move(name: String, uses: int = 5) -> Move:
	var move := Move.new()
	move.move_name = name
	move.max_uses = uses
	move.current_uses = uses
	return move


func _make_capricious_unit_with_moves(moves: Array[Move]) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.current_hp = 10  # not defeated
	var data := CharacterData.new()
	data.equipped_passives.append("Capricious")
	for move: Move in moves:
		data.equipped_moves.append(move)
	unit.character_data = data
	return unit


func test_capricious_rerolls_to_a_different_move() -> void:
	# With exactly two usable moves and the first one just used, the reroll
	# must pick the second (the only "different" option) — deterministic.
	var move_a := _make_move("MoveA")
	var move_b := _make_move("MoveB")
	var unit := _make_capricious_unit_with_moves([move_a, move_b])
	unit.assigned_move = move_a

	unit._capricious_post_combat_reroll(unit)

	assert_eq(unit.last_used_move_index, 0,
			"last_used cached from the move that was just assigned")
	assert_eq(unit.assigned_move, move_b,
			"Reroll picked the only different usable move")


func test_capricious_keeps_assignment_when_only_one_usable_move() -> void:
	# If the "different" pool is empty (only one usable move total), the
	# reroll is a no-op — can't conjure variety from nothing.
	var move_a := _make_move("MoveA")
	var unit := _make_capricious_unit_with_moves([move_a])
	unit.assigned_move = move_a

	unit._capricious_post_combat_reroll(unit)

	assert_eq(unit.assigned_move, move_a,
			"Single-move unit keeps its current assignment after combat")


func test_capricious_noop_without_passive() -> void:
	# Same setup as the reroll test, but no Capricious passive. assigned_move
	# should not change.
	var move_a := _make_move("MoveA")
	var move_b := _make_move("MoveB")
	var unit := Unit.new()
	autofree(unit)
	unit.current_hp = 10
	var data := CharacterData.new()
	# Deliberately no "Capricious" in equipped_passives
	data.equipped_moves.append(move_a)
	data.equipped_moves.append(move_b)
	unit.character_data = data
	unit.assigned_move = move_a

	unit._capricious_post_combat_reroll(unit)

	assert_eq(unit.assigned_move, move_a,
			"Unit without Capricious doesn't reroll")


# =============================================================================
# Attack-clip direction selection (_select_attack_clip)
# =============================================================================
# A diagonal attack used to match neither "horizontal" nor "vertical" → boop
# nudge, and its Manhattan distance (2 for a diagonal neighbor) could even pick
# the ranged clip. DIAGONAL_USES_SIDE_ANIMATION makes a diagonal count as
# horizontal (side-swing, mirrored by flip_h) and matches range on Chebyshev
# (ring) distance so a diagonal neighbor reads as range 1.

func _attack_anim_table() -> Dictionary:
	# Mirrors a spaceman-style table: side melee at range 1, side ranged at 2+,
	# and a vertical melee. Bodies are stubbed — only use_when matters here.
	return {
		"meleeside": { "use_when": { "direction": "horizontal", "range": 1 } },
		"shootside": { "use_when": { "direction": "horizontal", "range_min": 2 } },
		"meleeup": { "use_when": { "direction": "vertical", "range": 1 } },
	}


func test_diagonal_uses_side_melee_when_enabled() -> void:
	# Diagonal neighbor (1,1): ring distance 1 → the side melee, NOT the ranged
	# clip (the old Manhattan-2 bug) and NOT a boop.
	var clip := Unit._select_attack_clip(_attack_anim_table(), Vector2i(1, 1), true)
	assert_eq(str(clip.get("use_when", {}).get("direction", "")), "horizontal",
			"Diagonal attack uses the east/west clip when the toggle is on")
	assert_eq(int(clip.get("use_when", {}).get("range", -1)), 1,
			"Diagonal-adjacent reads as ring distance 1 → melee, not the ranged clip")


func test_far_diagonal_uses_side_ranged() -> void:
	# Diagonal at ring distance 2 still uses a side clip — the ranged one.
	var clip := Unit._select_attack_clip(_attack_anim_table(), Vector2i(2, 2), true)
	assert_true(clip.get("use_when", {}).has("range_min"),
			"A far diagonal (ring distance 2) picks the ranged side clip")


func test_diagonal_boops_when_disabled() -> void:
	# Toggle off restores legacy behavior: a diagonal matches no directional clip.
	assert_true(Unit._select_attack_clip(_attack_anim_table(), Vector2i(1, 1), false).is_empty(),
			"With the toggle off a diagonal matches no directional clip → boop fallback")


func test_vertical_attack_picks_vertical_clip() -> void:
	# A due north/south attack still uses the vertical clip, toggle or not.
	for flag: bool in [true, false]:
		var clip := Unit._select_attack_clip(_attack_anim_table(), Vector2i(0, 1), flag)
		assert_eq(str(clip.get("use_when", {}).get("direction", "")), "vertical",
				"Due-vertical attack uses the vertical clip (flag=%s)" % flag)


func test_horizontal_attack_picks_side_melee() -> void:
	# A due east/west adjacent attack uses the side melee, toggle or not.
	for flag: bool in [true, false]:
		var clip := Unit._select_attack_clip(_attack_anim_table(), Vector2i(-1, 0), flag)
		assert_eq(int(clip.get("use_when", {}).get("range", -1)), 1,
				"Due-horizontal adjacent attack picks the side melee (flag=%s)" % flag)


func test_orthogonal_range_matching_is_flag_independent() -> void:
	# Chebyshev == Manhattan for orthogonal attacks, so a straight range-2 attack
	# picks the ranged clip identically with the toggle on or off — the toggle
	# only ever changes diagonal behavior.
	for flag: bool in [true, false]:
		var clip := Unit._select_attack_clip(_attack_anim_table(), Vector2i(-2, 0), flag)
		assert_true(clip.get("use_when", {}).has("range_min"),
				"Horizontal range-2 attack picks the ranged clip regardless of toggle (flag=%s)" % flag)
