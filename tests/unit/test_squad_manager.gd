## Tests for SquadManager autoload — battle-start / battle-end hooks that
## mutate persistent CharacterData state across missions.
extends GutTest


# =============================================================================
# Battle-start move PP reset
# =============================================================================
# Regression: Move.reset_uses() existed but no caller — player units carried
# depleted PP from one mission into the next. SquadManager._on_battle_started
# now loops each player unit's equipped_moves and calls reset_uses().

func _make_move_at_uses(max_uses: int, current_uses: int) -> Move:
	var move := Move.new()
	move.max_uses = max_uses
	move.current_uses = current_uses
	return move


func _make_unit_with_moves(moves: Array) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.character_id = "test_subject"
	for move: Variant in moves:
		data.equipped_moves.append(move)
	unit.character_data = data
	return unit


func test_battle_start_refills_depleted_moves_to_max() -> void:
	var move := _make_move_at_uses(5, 1)  # depleted
	var unit := _make_unit_with_moves([move])

	SquadManager._on_battle_started([unit])

	assert_eq(move.current_uses, 5,
			"Depleted move refilled to max_uses at battle start")


func test_battle_start_refills_all_equipped_moves_independently() -> void:
	var move_a := _make_move_at_uses(3, 0)
	var move_b := _make_move_at_uses(8, 2)
	var move_c := _make_move_at_uses(10, 10)  # already full
	var unit := _make_unit_with_moves([move_a, move_b, move_c])

	SquadManager._on_battle_started([unit])

	assert_eq(move_a.current_uses, 3, "Move A refilled from 0")
	assert_eq(move_b.current_uses, 8, "Move B refilled from 2")
	assert_eq(move_c.current_uses, 10, "Move C unchanged (already full)")


func test_battle_start_handles_null_move_in_equipped_list() -> void:
	# Some character configs may have empty slots (Move.EMPTY or actual null).
	# The reset loop guards against null so a sparse list doesn't crash.
	var move := _make_move_at_uses(4, 1)
	var unit := _make_unit_with_moves([null, move])

	SquadManager._on_battle_started([unit])

	assert_eq(move.current_uses, 4,
			"Null slot skipped, valid move still refilled")


func test_battle_start_skips_units_without_character_data() -> void:
	# A unit whose character_data is null shouldn't crash the loop or block
	# subsequent units from being processed.
	var move := _make_move_at_uses(5, 0)
	var data_unit := _make_unit_with_moves([move])
	var null_unit := TestFakeUnit.new()
	add_child_autofree(null_unit)
	null_unit.character_data = null

	SquadManager._on_battle_started([null_unit, data_unit])

	assert_eq(move.current_uses, 5,
			"Subsequent unit's moves still refilled after null character_data")


func test_battle_start_handles_null_unit_in_list() -> void:
	# Defensive: a null entry in the units array shouldn't crash either.
	var move := _make_move_at_uses(5, 0)
	var unit := _make_unit_with_moves([move])

	SquadManager._on_battle_started([null, unit])

	assert_eq(move.current_uses, 5,
			"Null unit skipped, valid unit still processed")
