## StatBreakdown — the per-source lines behind a stat's number (the "why is
## my STR 12?" tooltip, RQD 2026-09-13). The contract: every line names its
## cause, and the lines always sum to the number on screen, including the
## cases the rounding rules make awkward (a cancelling buff/debuff pair, a
## Maximum-blocked debuff, a field some caller wrote without the ledger).
extends GutTest


func _character(base_strength: int = 10) -> CharacterData:
	var data := CharacterData.new()
	data.base_strength = base_strength
	data.base_max_hp = 40
	return data


func _effect(name: String, affected_stat: String, stacks: int) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_type_name = name
	effect.affected_stat = affected_stat
	effect.stacks = stacks
	return effect


func _unit(data: CharacterData, effects: Array, passives: Array = []) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.current_hp = 100
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	unit.active_status_effects = effects
	return unit


# =============================================================================
# THE LINES
# =============================================================================

func test_an_unmodified_stat_is_its_base_alone() -> void:
	assert_eq(StatBreakdown.text(_character(), "strength"), "Base (10)",
			"nothing to explain: just the base, so the tooltip still answers 'where's this from'")


func test_a_statup_is_its_own_line_even_when_it_rounds_to_nothing() -> void:
	var data := _character(4)
	data.available_stat_ups = 1
	data.set_allocated_points("strength", 1)
	assert_eq(StatBreakdown.text(data, "strength"), "Base (4)\n+0 (StatUp)",
			"the +0 IS the explanation the confused player needs")
	data.base_strength = 15
	assert_eq(StatBreakdown.text(data, "strength"), "Base (15)\n+2 (StatUp)")
	data.set_allocated_points("strength", 2)
	assert_eq(StatBreakdown.text(data, "strength"), "Base (15)\n+3 (2 StatUps)")


func test_a_stat_aura_names_its_passive() -> void:
	var data := _character()
	data.add_passive_bonus("strength", 3, "Competitive")
	assert_eq(data.passive_bonus_strength, 3, "add_passive_bonus writes the field")
	assert_eq(StatBreakdown.text(data, "strength"), "Base (10)\n+3 (Competitive)")


func test_a_field_written_behind_the_ledgers_back_still_adds_up() -> void:
	var data := _character()
	data.passive_bonus_strength = 3  # a writer that skipped the ledger
	assert_eq(StatBreakdown.text(data, "strength"), "Base (10)\n+3 (Passives)",
			"unattributed points wear the bucket's name rather than vanish")


func test_a_cancelling_buff_and_debuff_both_show() -> void:
	var data := _character()
	var unit := _unit(data, [_effect("RALLIED", "strength", 2), _effect("BURN", "strength", 2)])
	StatusEffectSystem.recalculate_stat_modifiers(unit)
	assert_eq(data.status_modifier_strength, 0, "+20% and -20% cancel on the field")
	assert_eq(StatBreakdown.text(data, "strength"), "Base (10)\n+2 (Rallied)\n-2 (Burn)",
			"RQD's case: both lines stay visible when they net to zero")


func test_maximum_appears_as_the_line_that_undid_the_debuff() -> void:
	var data := _character()
	var unit := _unit(data, [_effect("BURN", "strength", 2)], ["Maximum"])
	StatusEffectSystem.recalculate_stat_modifiers(unit)
	assert_eq(data.status_modifier_strength, 0)
	assert_eq(StatBreakdown.text(data, "strength"), "Base (10)\n-2 (Burn)\n+2 (Maximum)",
			"the protecting passive is a source too")


func test_cavalier_zeroes_the_buff_and_says_so() -> void:
	var data := _character()
	var unit := _unit(data, [_effect("RALLIED", "strength", 2)], ["Cavalier"])
	StatusEffectSystem.recalculate_stat_modifiers(unit)
	assert_eq(StatBreakdown.text(data, "strength"), "Base (10)\n+2 (Rallied)\n-2 (Cavalier)")


func test_lines_always_sum_to_the_getter() -> void:
	var data := _character(15)
	data.available_stat_ups = 2
	data.set_allocated_points("strength", 2)
	data.add_passive_bonus("strength", 3, "Competitive")
	var unit := _unit(data, [_effect("RALLIED", "strength", 1), _effect("BURN", "strength", 3)])
	StatusEffectSystem.recalculate_stat_modifiers(unit)
	var entries: Array[Dictionary] = StatBreakdown.lines(data, "strength")
	assert_eq(StatBreakdown.total_of(entries), data.strength,
			"a tooltip the player can add up is the whole point")
	assert_eq(entries[0]["label"], "Base")


# =============================================================================
# MARGINAL ATTRIBUTION — one rounded total, split in application order
# =============================================================================

func _floor_rule(base: int, pct: float) -> int:
	if is_zero_approx(pct):
		return 0
	var magnitude: int = int(floor(absf(base * pct / 100.0)))
	if magnitude == 0:
		magnitude = 1
	return magnitude if pct > 0.0 else -magnitude


func test_pct_lines_sum_to_the_rule_applied_to_the_total() -> void:
	# +20% then -10% on 15: the game applies floor(15 × 10%) = 1 as ONE
	# modifier. Alone the lines would read +3 and -1; attributed in order
	# they read +3 and -2, and that sum is the number on screen.
	var entries: Array[Dictionary] = StatBreakdown.pct_lines(15,
			[["Rallied", 20.0], ["Burn", -10.0]], _floor_rule)
	assert_eq(entries.size(), 2)
	assert_eq(int(entries[0]["amount"]), 3)
	assert_eq(int(entries[1]["amount"]), -2)
	assert_eq(StatBreakdown.total_of(entries), _floor_rule(15, 10.0))


func test_record_appends_per_stat() -> void:
	var ledger: Dictionary = {}
	StatBreakdown.record(ledger, "defense", "Fortify", 2)
	StatBreakdown.record(ledger, "defense", "Subvert", -1)
	StatBreakdown.record(ledger, "skill", "Focus", 1)
	assert_eq((ledger["defense"] as Array).size(), 2)
	assert_eq(StatBreakdown.total_of(ledger["defense"]), 1)
	assert_eq(StatBreakdown.total_of(ledger["skill"]), 1)


func test_resets_clear_the_ledgers_with_the_fields() -> void:
	var data := _character()
	data.add_passive_bonus("strength", 3, "Competitive")
	data.reset_passive_bonuses()
	assert_eq(data.passive_bonus_strength, 0)
	assert_true(data.passive_bonus_sources.is_empty(),
			"a stale ledger line would print a bonus the unit no longer has")


func test_modifier_field_names_the_hp_fields_without_max() -> void:
	assert_eq(CharacterData.modifier_field("injury_modifier_", "max_hp"), "injury_modifier_hp")
	assert_eq(CharacterData.modifier_field("status_modifier_", "strength"), "status_modifier_strength")
