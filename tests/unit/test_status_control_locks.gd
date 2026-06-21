## Regression tests for the ROOTED/FREEZE turn-gating fix.
##
## Locks in "1 stack = exactly one lost turn" regardless of WHEN the effect was
## applied. The bug: turn-start processing decremented control debuffs BEFORE
## anything read them, so a 1-stack ROOTED applied during the opposing phase
## ticked to 0 and was gone before the unit's turn — the root did nothing. The
## de-facto workaround was a 2-stack default (2 → 1 survives the decrement).
##
## The fix splits control debuffs out of the turn-start DoT pass and gates them
## in process_control_locks, which runs AFTER refresh: latch the lock for this
## turn, THEN consume a stack.
extends GutTest


func _make_unit_with_effect(effect_name: String, stacks: int) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var effect := StatusEffect.new()
	effect.effect_type_name = effect_name
	effect.stacks = stacks
	unit.active_status_effects = [effect]
	return unit


## Simulates a single turn boundary the way TurnManager sequences it:
## refresh (reset latches) → control locks (gate + decrement).
func _simulate_turn_start(unit: TestFakeUnit) -> void:
	unit.can_move = true
	unit.can_act = true
	StatusEffectSystem.process_control_locks(unit)


# =============================================================================
# ROOTED — 1 stack costs exactly one turn
# =============================================================================

func test_single_rooted_stack_blocks_exactly_one_turn() -> void:
	var unit := _make_unit_with_effect("ROOTED", 1)

	# The unit's turn comes around: it should be locked this turn.
	_simulate_turn_start(unit)
	assert_false(unit.can_move, "1-stack ROOTED must lock movement on the gated turn")
	assert_true(unit.can_act, "ROOTED blocks movement only, not action")
	assert_eq(unit.active_status_effects.size(), 0, "Stack consumed — effect cleared after the turn it gated")

	# Next turn: nothing left, free to move.
	_simulate_turn_start(unit)
	assert_true(unit.can_move, "ROOTED is spent — movement restored next turn")


func test_two_rooted_stacks_block_two_turns() -> void:
	var unit := _make_unit_with_effect("ROOTED", 2)

	_simulate_turn_start(unit)
	assert_false(unit.can_move, "Turn 1 locked")
	_simulate_turn_start(unit)
	assert_false(unit.can_move, "Turn 2 locked")
	_simulate_turn_start(unit)
	assert_true(unit.can_move, "Turn 3 free — both stacks spent")


# =============================================================================
# FREEZE — locks movement AND action
# =============================================================================

func test_freeze_locks_movement_and_action() -> void:
	var unit := _make_unit_with_effect("FREEZE", 1)

	_simulate_turn_start(unit)
	assert_false(unit.can_move, "FREEZE locks movement")
	assert_false(unit.can_act, "FREEZE also locks action")
	assert_eq(unit.active_status_effects.size(), 0, "Single FREEZE stack consumed")


# =============================================================================
# Tick separation — control debuffs are NOT decremented by the DoT pass
# =============================================================================

func test_turn_start_pass_does_not_touch_control_debuffs() -> void:
	# process_turn_start_effects (the DoT/HoT pass) must leave ROOTED alone, or
	# the control-lock pass would double-decrement.
	var unit := _make_unit_with_effect("ROOTED", 1)

	StatusEffectSystem.process_turn_start_effects(unit)
	assert_eq(unit.active_status_effects.size(), 1, "ROOTED untouched by the DoT pass")
	assert_eq((unit.active_status_effects[0] as StatusEffect).stacks, 1,
			"ROOTED stack not decremented by the DoT pass")


# =============================================================================
# Latch source-of-truth — query helpers read can_move/can_act, not live stacks
# =============================================================================

func test_can_unit_move_reads_latch() -> void:
	var unit := _make_unit_with_effect("ROOTED", 1)
	unit.can_move = false
	assert_false(StatusEffectSystem.can_unit_move(unit), "can_unit_move reflects the latch")
	unit.can_move = true
	assert_true(StatusEffectSystem.can_unit_move(unit), "can_unit_move reflects the latch when cleared")
