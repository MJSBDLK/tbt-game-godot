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
	# ROOTED collapses movement via the can_move latch. process_control_locks
	# sets can_move=false at turn start (gate-then-decrement); the getter reads
	# the latch, not live stacks — so a stack that's about to be consumed this
	# turn still gates it. See StatusEffectSystem.process_control_locks.
	var unit := _make_unit_with_move_distance(5)
	var effect := _make_rooted_effect()
	effect.stacks = 1
	unit.active_status_effects.append(effect)
	unit.can_move = true  # as refresh_unit sets it at turn start
	StatusEffectSystem.process_control_locks(unit)
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
