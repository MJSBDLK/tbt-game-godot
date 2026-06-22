## Phase 1 tests for crit: the CritEffect handler, gather wiring, the move parser
## reinterpreting "Crit"/"Critical" as a crit (not a status), and the removal of
## CRITICAL from the status system.
extends GutTest


const CRIT := DamageCalculator.CRIT_MULTIPLIER


func _crit_move(chance: float, self_target: bool, base_power: int = 5) -> Move:
	var move := Move.new()
	move.move_name = "CritMove"
	move.base_power = base_power
	move.crit_chance = chance
	move.crit_self_target = self_target
	return move


func _attacker(pending: bool = false) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	unit.pending_crit = pending
	return unit


func _ctx(move: Move, attacker: TestFakeUnit, damage: int = 5, apply_status: bool = true) -> CombatHitContext:
	var ctx := CombatHitContext.new()
	ctx.move = move
	ctx.attacker = attacker
	ctx.base_damage = damage
	ctx.damage = damage
	ctx.apply_status = apply_status
	return ctx


# =============================================================================
# This-hit crit (secondary crit roll)
# =============================================================================

func test_this_hit_crit_doubles_damage() -> void:
	var ctx := _ctx(_crit_move(1.0, false), _attacker())
	CritEffect.new().modify_damage(ctx)
	assert_eq(ctx.damage, roundi(5 * CRIT), "crit_chance 1.0 doubles this hit")
	assert_true(ctx.is_crit, "is_crit flag set")


func test_no_crit_leaves_damage_unchanged() -> void:
	var ctx := _ctx(_crit_move(0.0, false), _attacker())
	CritEffect.new().modify_damage(ctx)
	assert_eq(ctx.damage, 5, "no crit chance, no pending → unchanged")
	assert_false(ctx.is_crit)


func test_secondary_crit_skipped_on_bonus_hit() -> void:
	# apply_status=false (bonus hits) — the secondary crit roll doesn't fire.
	var ctx := _ctx(_crit_move(1.0, false), _attacker(), 5, false)
	CritEffect.new().modify_damage(ctx)
	assert_eq(ctx.damage, 5, "secondary crit is first-hit-only")


# =============================================================================
# Banked crit (pending_crit)
# =============================================================================

func test_pending_crit_doubles_and_is_consumed() -> void:
	var attacker := _attacker(true)
	var ctx := _ctx(_crit_move(0.0, false), attacker)
	CritEffect.new().modify_damage(ctx)
	assert_eq(ctx.damage, roundi(5 * CRIT), "banked crit doubles the next hit")
	assert_true(ctx.is_crit)
	assert_false(attacker.pending_crit, "pending_crit consumed exactly once")


func test_pending_crit_not_wasted_on_zero_power_move() -> void:
	# A banked crit must survive a 0-power move (e.g. recasting a setup move).
	var attacker := _attacker(true)
	var ctx := _ctx(_crit_move(0.0, false, 0), attacker)
	CritEffect.new().modify_damage(ctx)
	assert_eq(ctx.damage, 5, "0-power move doesn't crit")
	assert_true(attacker.pending_crit, "banked crit preserved")


# =============================================================================
# Banking (self-target setup moves)
# =============================================================================

func test_self_target_does_not_crit_this_hit() -> void:
	var attacker := _attacker()
	var ctx := _ctx(_crit_move(1.0, true), attacker)
	CritEffect.new().modify_damage(ctx)
	assert_eq(ctx.damage, 5, "self-target banking doesn't double the setup hit")
	assert_false(ctx.is_crit)


func test_self_target_on_hit_banks_pending_crit() -> void:
	var attacker := _attacker()
	var ctx := _ctx(_crit_move(1.0, true), attacker)
	CritEffect.new().on_hit(ctx)
	assert_true(attacker.pending_crit, "self-target crit banks pending_crit on the caster")


func test_banking_skipped_on_bonus_hit() -> void:
	var attacker := _attacker()
	var ctx := _ctx(_crit_move(1.0, true), attacker, 5, false)
	CritEffect.new().on_hit(ctx)
	assert_false(attacker.pending_crit, "banking is first-hit-only")


# =============================================================================
# gather() wiring
# =============================================================================

func test_gather_adds_crit_effect_for_crit_move() -> void:
	var ctx := _ctx(_crit_move(0.3, false), _attacker())
	var effects := CombatEffectPipeline.gather(ctx)
	assert_true(effects.any(func(e): return e is CritEffect), "crit_chance move gathers CritEffect")


func test_gather_adds_crit_effect_when_pending() -> void:
	var move := Move.new()  # plain attack, no crit_chance
	move.base_power = 5
	var ctx := _ctx(move, _attacker(true))
	var effects := CombatEffectPipeline.gather(ctx)
	assert_true(effects.any(func(e): return e is CritEffect), "pending_crit gathers CritEffect on a plain attack")


func test_gather_no_crit_effect_without_crit_or_pending() -> void:
	var move := Move.new()
	move.base_power = 5
	var ctx := _ctx(move, _attacker(false))
	var effects := CombatEffectPipeline.gather(ctx)
	assert_false(effects.any(func(e): return e is CritEffect), "plain attack, no pending → no CritEffect")


func test_gather_no_crit_on_heal() -> void:
	var move := _crit_move(1.0, false)
	var ctx := _ctx(move, _attacker(true))
	ctx.is_heal = true
	var effects := CombatEffectPipeline.gather(ctx)
	assert_false(effects.any(func(e): return e is CritEffect), "heals never crit")


# =============================================================================
# Parser: "Crit"/"Critical" → crit fields, not a status
# =============================================================================

func test_focus_parses_as_self_target_crit() -> void:
	# Focus uses statusEffect {effect:"Critical", chance:1.0, target:"self"} —
	# now interpreted as a banked crit, not a CRITICAL status.
	var focus: Move = MoveData.get_move("Focus")
	assert_not_null(focus, "Focus exists in the bank")
	assert_almost_eq(focus.crit_chance, 1.0, 0.001, "crit_chance parsed from the secondary")
	assert_true(focus.crit_self_target, "target:self → banking")
	assert_eq(focus.status_effect_type, Enums.StatusEffectType.NONE,
			"Crit does NOT populate the status slot")


# =============================================================================
# CRITICAL removed from the status system
# =============================================================================

func test_critical_removed_from_status_configs() -> void:
	assert_false(StatusEffectData.get_default_configs().has("CRITICAL"),
			"No CRITICAL status config remains")


func test_critical_removed_from_enum() -> void:
	assert_false(Enums.StatusEffectType.keys().has("CRITICAL"),
			"CRITICAL is gone from the StatusEffectType enum")
