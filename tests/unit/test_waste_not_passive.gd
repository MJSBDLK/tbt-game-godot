## Phase 2: Waste Not — defeating an enemy refunds the use the killing move just
## spent. Also covers Move.refund_use and the run_on_kill pipeline phase.
extends GutTest


func _move(max_uses: int, current_uses: int) -> Move:
	var move := Move.new()
	move.max_uses = max_uses
	move.current_uses = current_uses
	return move


func _attacker(passives: Array = []) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	return unit


func _ctx(attacker: TestFakeUnit, move: Move) -> CombatHitContext:
	var ctx := CombatHitContext.new()
	ctx.attacker = attacker
	ctx.defender = _attacker()
	ctx.move = move
	return ctx


# =============================================================================
# Move.refund_use
# =============================================================================

func test_consume_then_refund_roundtrip() -> void:
	var move := _move(10, 10)
	move.consume_use()
	assert_eq(move.current_uses, 9)
	move.refund_use()
	assert_eq(move.current_uses, 10)


func test_refund_caps_at_max() -> void:
	var move := _move(10, 10)
	move.refund_use()
	assert_eq(move.current_uses, 10, "can't exceed max_uses")


# =============================================================================
# WasteNotPassive.on_kill
# =============================================================================

func test_kill_refunds_the_killing_move() -> void:
	var move := _move(10, 5)
	WasteNotPassive.new().on_kill(_ctx(_attacker(["Waste Not"]), move))
	assert_eq(move.current_uses, 6, "killing move regains the use it spent")


func test_no_refund_without_passive() -> void:
	var move := _move(10, 5)
	WasteNotPassive.new().on_kill(_ctx(_attacker([]), move))
	assert_eq(move.current_uses, 5)


func test_refund_capped_at_max_on_kill() -> void:
	var move := _move(10, 10)
	WasteNotPassive.new().on_kill(_ctx(_attacker(["Waste Not"]), move))
	assert_eq(move.current_uses, 10)


# =============================================================================
# Registry + pipeline run_on_kill
# =============================================================================

func test_registry_resolves_waste_not() -> void:
	assert_true(PassiveRegistry.get_handler("Waste Not") is WasteNotPassive)


func test_pipeline_run_on_kill_applies_waste_not() -> void:
	var move := _move(10, 5)
	var ctx := _ctx(_attacker(["Waste Not"]), move)
	var effects := CombatEffectPipeline.gather(ctx)
	CombatEffectPipeline.run_on_kill(ctx, effects)
	assert_eq(move.current_uses, 6, "gathered Waste Not refunded via run_on_kill")
