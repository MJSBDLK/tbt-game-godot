## Phase 0 tests for the combat effect pipeline.
##
## Covers gather() composition + ordering (afflictions → cleanse → displace),
## the heal context dropping displacement, the Phase-0 no-op of run_modify_damage,
## and that ApplyAfflictionEffect honors the first-hit-only apply_status gate.
extends GutTest


func _make_move(
		status: Enums.StatusEffectType = Enums.StatusEffectType.NONE,
		cleanse: PackedStringArray = PackedStringArray(),
		displace: int = 0) -> Move:
	var move := Move.new()
	move.move_name = "TestMove"
	move.status_effect_type = status
	move.status_effect_chance = 1.0
	move.cleanse_effects = cleanse
	move.displace_distance = displace
	return move


func _ctx_for(move: Move, is_heal: bool = false) -> CombatHitContext:
	var ctx := CombatHitContext.new()
	ctx.move = move
	ctx.is_heal = is_heal
	return ctx


# =============================================================================
# gather() — composition + ordering
# =============================================================================

func test_gather_empty_move_yields_no_handlers() -> void:
	var effects := CombatEffectPipeline.gather(_ctx_for(_make_move()))
	assert_eq(effects.size(), 0, "A plain damage move with no riders gathers nothing")


func test_gather_affliction_only() -> void:
	var effects := CombatEffectPipeline.gather(_ctx_for(_make_move(Enums.StatusEffectType.BURN)))
	assert_eq(effects.size(), 1)
	assert_true(effects[0] is ApplyAfflictionEffect, "statusEffect → ApplyAfflictionEffect")


func test_gather_cleanse_only() -> void:
	var effects := CombatEffectPipeline.gather(_ctx_for(_make_move(
			Enums.StatusEffectType.NONE, PackedStringArray(["BLEED"]))))
	assert_eq(effects.size(), 1)
	assert_true(effects[0] is CleanseEffect, "onHit.cleanse → CleanseEffect")


func test_gather_displace_only() -> void:
	var effects := CombatEffectPipeline.gather(_ctx_for(_make_move(
			Enums.StatusEffectType.NONE, PackedStringArray(), 1)))
	assert_eq(effects.size(), 1)
	assert_true(effects[0] is DisplaceEffect, "onHit.displace → DisplaceEffect")


func test_gather_order_is_affliction_cleanse_displace() -> void:
	var move := _make_move(Enums.StatusEffectType.BURN, PackedStringArray(["BLEED"]), 1)
	var effects := CombatEffectPipeline.gather(_ctx_for(move))
	assert_eq(effects.size(), 3)
	assert_true(effects[0] is ApplyAfflictionEffect, "1st: affliction")
	assert_true(effects[1] is CleanseEffect, "2nd: cleanse")
	assert_true(effects[2] is DisplaceEffect, "3rd: displace")


func test_gather_heal_context_drops_displacement() -> void:
	# Heals never displace — the pipeline omits DisplaceEffect for is_heal.
	var move := _make_move(Enums.StatusEffectType.REGEN, PackedStringArray(["BLEED"]), 1)
	var effects := CombatEffectPipeline.gather(_ctx_for(move, true))
	assert_eq(effects.size(), 2, "Heal context keeps affliction + cleanse, drops displace")
	for effect: CombatEffect in effects:
		assert_false(effect is DisplaceEffect, "No DisplaceEffect in a heal context")


# =============================================================================
# run_modify_damage — Phase 0 no-op (no damage modifiers exist yet)
# =============================================================================

func test_modify_damage_is_noop_in_phase_0() -> void:
	var ctx := _ctx_for(_make_move(Enums.StatusEffectType.BURN, PackedStringArray(["BLEED"]), 1))
	ctx.base_damage = 7
	ctx.damage = 7
	var effects := CombatEffectPipeline.gather(ctx)
	CombatEffectPipeline.run_modify_damage(ctx, effects)
	assert_eq(ctx.damage, 7, "No damage-modifying handlers yet — damage unchanged")


# =============================================================================
# ApplyAfflictionEffect — first-hit-only apply_status gate
# =============================================================================

func _make_fake(primary: Enums.ElementalType = Enums.ElementalType.SIMPLE) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.primary_type = primary
	data.base_max_hp = 100
	unit.character_data = data
	unit.active_status_effects = []
	return unit


func test_affliction_skipped_when_apply_status_false() -> void:
	# Bonus hits pass apply_status=false — the affliction must NOT land again.
	var target := _make_fake()
	var ctx := _ctx_for(_make_move(Enums.StatusEffectType.ROOTED))
	ctx.attacker = _make_fake()
	ctx.defender = target
	ctx.apply_status = false
	var effects := CombatEffectPipeline.gather(ctx)
	await CombatEffectPipeline.run_on_hit(ctx, effects)
	assert_eq(target.active_status_effects.size(), 0,
			"apply_status=false must not apply the affliction")


func test_affliction_applied_when_apply_status_true() -> void:
	var target := _make_fake()
	var ctx := _ctx_for(_make_move(Enums.StatusEffectType.ROOTED))
	ctx.attacker = _make_fake()
	ctx.defender = target
	ctx.apply_status = true
	var effects := CombatEffectPipeline.gather(ctx)
	await CombatEffectPipeline.run_on_hit(ctx, effects)
	assert_eq(target.active_status_effects.size(), 1,
			"apply_status=true applies the affliction (chance 1.0)")
	assert_eq((target.active_status_effects[0] as StatusEffect).effect_type_name, "ROOTED")
