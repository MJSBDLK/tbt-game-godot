## CharacterData.secondary_chance: skill scales a move's secondary-effect chance
## by (1 + skill/100), capped at 100%, and the curse comes off after. Every
## secondary roll (status, crit, conditional) and the combat preview read it.
extends GutTest


func _data(skill: int, luck_penalty_pct: float = 0.0) -> CharacterData:
	var data := CharacterData.new()
	data.base_skill = skill
	data.luck_penalty_pct = luck_penalty_pct
	return data


func _unit(skill: int, luck_penalty_pct: float = 0.0) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	unit.character_data = _data(skill, luck_penalty_pct)
	unit.current_hp = 10
	return unit


func _bleed_move(chance: float) -> Move:
	var move := Move.new()
	move.base_power = 3
	move.status_effect_type = Enums.StatusEffectType.BLEED
	move.status_effect_chance = chance
	return move


func _crit_move(chance: float) -> Move:
	var move := Move.new()
	move.base_power = 5
	move.crit_chance = chance
	return move


# --- the number ----------------------------------------------------------------

func test_zero_skill_leaves_the_move_chance_alone() -> void:
	assert_almost_eq(_data(0).secondary_chance(0.5), 0.5, 0.0001)


func test_skill_scales_the_chance() -> void:
	assert_almost_eq(_data(10).secondary_chance(0.5), 0.55, 0.0001, "skill 10: 50% -> 55%")
	assert_almost_eq(_data(50).secondary_chance(0.5), 0.75, 0.0001, "skill 50: 50% -> 75%")


func test_the_chance_caps_at_one_before_the_curse() -> void:
	assert_almost_eq(_data(50).secondary_chance(0.7), 1.0, 0.0001, "105% caps at 100%")
	assert_almost_eq(_data(50, 10.0).secondary_chance(0.7), 0.9, 0.0001,
			"a curse still bites a capped chance")


func test_the_chance_never_goes_below_zero() -> void:
	assert_almost_eq(_data(0, 100.0).secondary_chance(0.5), 0.0, 0.0001)
	assert_almost_eq(_data(-200).secondary_chance(0.5), 0.0, 0.0001, "negative skill floors the scale at 0")


# --- every roll reads it -------------------------------------------------------
# Skill 100 lifts a 50% chance to a sure thing; a full curse zeroes it. Twenty
# tries each, so a roll that ignored the scaling would fail near-certainly.

func test_status_roll_uses_the_scaled_chance() -> void:
	for attempt: int in 20:
		assert_true(StatusEffectSystem.apply_status_effect(_unit(100), _unit(0), _bleed_move(0.5)),
				"skill 100 lands a 50% status every time")
		assert_false(StatusEffectSystem.apply_status_effect(_unit(0, 100.0), _unit(0), _bleed_move(1.0)),
				"a full curse never lands one")


func test_crit_roll_uses_the_scaled_chance() -> void:
	for attempt: int in 20:
		var ctx := CombatHitContext.new()
		ctx.move = _crit_move(0.5)
		ctx.attacker = _unit(100)
		ctx.damage = 5
		ctx.apply_status = true
		CritEffect.new().modify_damage(ctx)
		assert_true(ctx.is_crit, "skill 100 crits a 50% crit move every time")


# --- the preview shows the rolled number ---------------------------------------

func test_preview_shows_the_scaled_chance() -> void:
	assert_eq(CombatPreviewPanel._secondary_chance_text(_unit(50), _bleed_move(0.5)), "75%")
	assert_eq(CombatPreviewPanel._secondary_chance_text(_unit(50), Move.new()), "--", "no secondary")
