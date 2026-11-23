## Still Standing: from full HP, a hit that would drop the owner leaves it at
## 1 HP. A defender modify_damage handler, run after the crit.
extends GutTest


func _fake(passives: Array = [], max_hp: int = 20) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	data.base_max_hp = max_hp
	unit.character_data = data
	unit.current_hp = data.max_hp
	return unit


func _clamped(attacker: TestFakeUnit, defender: TestFakeUnit, damage: int,
		presenter: CombatPresenter = null) -> int:
	var ctx := CombatHitContext.new()
	ctx.attacker = attacker
	ctx.defender = defender
	ctx.damage = damage
	ctx.presenter = presenter
	StillStandingPassive.new().modify_damage(ctx)
	return ctx.damage


func test_a_killing_blow_from_full_leaves_one_hp() -> void:
	var squash := _fake(["Still Standing"])
	assert_eq(_clamped(_fake(), squash, 50), 19)
	assert_eq(_clamped(_fake(), squash, 20), 19, "exactly lethal counts too")


func test_chipped_first_he_goes_down() -> void:
	var squash := _fake(["Still Standing"])
	squash.current_hp = 19
	assert_eq(_clamped(_fake(), squash, 50), 50)


func test_a_hit_he_survives_anyway_is_untouched() -> void:
	assert_eq(_clamped(_fake(), _fake(["Still Standing"]), 5), 5)


func test_it_guards_its_owner_only() -> void:
	assert_eq(_clamped(_fake(["Still Standing"]), _fake(), 50), 50)


func test_the_save_is_announced() -> void:
	var presenter := RecordingPresenter.new()
	_clamped(_fake(), _fake(["Still Standing"]), 50, presenter)
	var callouts := presenter.beats_named("callout")
	assert_eq(callouts.size(), 1)
	assert_eq(callouts[0].get("text"), "STILL STANDING")


func test_a_crit_is_clamped_too() -> void:
	var attacker := _fake()
	attacker.pending_crit = true
	var squash := _fake(["Still Standing"])
	var move := Move.new()
	move.base_power = 15
	var ctx := CombatHitContext.new()
	ctx.attacker = attacker
	ctx.defender = squash
	ctx.move = move
	ctx.damage = 15
	CombatEffectPipeline.run_modify_damage(ctx, CombatEffectPipeline.gather(ctx))
	assert_true(ctx.is_crit, "precondition: the banked crit was spent")
	assert_eq(ctx.damage, 19)


func test_registry_resolves_still_standing() -> void:
	assert_true(PassiveRegistry.get_handler("Still Standing") is StillStandingPassive)
