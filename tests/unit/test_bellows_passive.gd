## Phase 2 tests: Bellows migrated to a CombatEffect passive handler, the passive
## registry, and the pipeline gathering passive handlers per hit.
extends GutTest


func _make_unit(passives: Array = []) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.base_max_hp = 100
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	unit.active_status_effects = []
	return unit


func _air_move(element: Enums.ElementalType = Enums.ElementalType.AIR) -> Move:
	var move := Move.new()
	move.move_name = "Gust"
	move.element_type = element
	move.base_power = 4
	return move


func _ctx(attacker: TestFakeUnit, defender: TestFakeUnit, move: Move) -> CombatHitContext:
	var ctx := CombatHitContext.new()
	ctx.attacker = attacker
	ctx.defender = defender
	ctx.move = move
	ctx.damage = 4
	return ctx


func _bellows_stacks(unit: TestFakeUnit) -> int:
	for effect: StatusEffect in unit.active_status_effects:
		if effect.effect_type_name == "BELLOWS":
			return effect.stacks
	return 0


# =============================================================================
# BellowsPassive.on_hit
# =============================================================================

func test_air_hit_on_bellows_unit_grants_stack() -> void:
	var defender := _make_unit(["Bellows"])
	BellowsPassive.new().on_hit(_ctx(_make_unit(), defender, _air_move()))
	assert_gt(_bellows_stacks(defender), 0, "Air damage on a Bellows unit grants BELLOWS")


func test_air_hit_without_passive_grants_nothing() -> void:
	var defender := _make_unit([])  # no Bellows
	BellowsPassive.new().on_hit(_ctx(_make_unit(), defender, _air_move()))
	assert_eq(_bellows_stacks(defender), 0, "No Bellows passive → no grant")


func test_non_air_hit_grants_nothing() -> void:
	var defender := _make_unit(["Bellows"])
	BellowsPassive.new().on_hit(_ctx(_make_unit(), defender, _air_move(Enums.ElementalType.FIRE)))
	assert_eq(_bellows_stacks(defender), 0, "Bellows only triggers on AIR damage")


# =============================================================================
# Registry
# =============================================================================

func test_registry_resolves_bellows() -> void:
	assert_true(PassiveRegistry.get_handler("Bellows") is BellowsPassive,
			"Bellows name resolves to BellowsPassive")


func test_registry_unknown_passive_is_null() -> void:
	assert_null(PassiveRegistry.get_handler("NotARealPassive"),
			"Uncoded passives resolve to null and are skipped")


func test_registry_dedupes_and_skips_unknown() -> void:
	var data := CharacterData.new()
	data.equipped_passives = ["Bellows", "Bellows", "Ghost"]  # dup + not-yet-coded
	var handlers := PassiveRegistry.get_handlers_for(data)
	assert_eq(handlers.size(), 1, "Deduped to one Bellows; Ghost skipped (not coded yet)")


# =============================================================================
# gather() wires passive handlers in (damage hits only)
# =============================================================================

func test_gather_includes_defender_bellows() -> void:
	var ctx := _ctx(_make_unit(), _make_unit(["Bellows"]), _air_move())
	var effects := CombatEffectPipeline.gather(ctx)
	assert_true(effects.any(func(e): return e is BellowsPassive),
			"defender's Bellows is gathered into the per-hit pipeline")


func test_gather_excludes_passives_on_heal() -> void:
	var ctx := _ctx(_make_unit(), _make_unit(["Bellows"]), _air_move())
	ctx.is_heal = true
	var effects := CombatEffectPipeline.gather(ctx)
	assert_false(effects.any(func(e): return e is BellowsPassive),
			"passive triggers don't fire on heals (matches old behavior)")
