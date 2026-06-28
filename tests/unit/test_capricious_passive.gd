## Phase 2 slice 6: Capricious migrated to a randomizes_move capability flag.
## The flag is read by EnemyAI (turn move-pick) and Unit (post-combat reroll);
## the selection logic stays at those sites. Tests the flag/registry plus the
## real Unit._capricious_post_combat_reroll dispatch.
extends GutTest


func _move(move_name: String) -> Move:
	var move := Move.new()
	move.move_name = move_name
	return move  # _init tops up current_uses, so has_uses_remaining() is true


func _unit(passives: Array, moves: Array) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.current_hp = 100  # alive
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	var typed_moves: Array[Move] = []  # equipped_moves is typed Array[Move]
	for move: Move in moves:
		typed_moves.append(move)
	data.equipped_moves = typed_moves
	unit.character_data = data
	return unit


# =============================================================================
# Flag + registry
# =============================================================================

func test_capricious_randomizes_move() -> void:
	assert_true(CapriciousPassive.new().randomizes_move())


func test_base_does_not_randomize_move() -> void:
	assert_false(CombatEffect.new().randomizes_move())


func test_registry_resolves_capricious() -> void:
	assert_true(PassiveRegistry.get_handler("Capricious") is CapriciousPassive)


# =============================================================================
# Unit._capricious_post_combat_reroll dispatch
# =============================================================================

func test_reroll_switches_to_a_different_move() -> void:
	var move_a := _move("A")
	var move_b := _move("B")
	var unit := _unit(["Capricious"], [move_a, move_b])
	unit.assigned_move = move_a
	unit._capricious_post_combat_reroll(unit)
	assert_eq(unit.assigned_move, move_b, "rerolls away from the just-used move")


func test_reroll_noop_without_capricious() -> void:
	var move_a := _move("A")
	var move_b := _move("B")
	var unit := _unit([], [move_a, move_b])  # no move-randomizer passive
	unit.assigned_move = move_a
	unit._capricious_post_combat_reroll(unit)
	assert_eq(unit.assigned_move, move_a, "no capability → keeps its move")


func test_reroll_keeps_move_when_no_alternative() -> void:
	var move_a := _move("A")
	var unit := _unit(["Capricious"], [move_a])  # only one usable move
	unit.assigned_move = move_a
	unit._capricious_post_combat_reroll(unit)
	assert_eq(unit.assigned_move, move_a, "can't conjure variety from one move")
