## The Traveller kit's new moves, read from the real move bank, and the three
## mechanics they brought: defense-pierce (Pick), clearing a whole status slot
## (Pry) and one random payload per cast (Rummage).
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()


func after_all() -> void:
	GridManager.clear_grid()


func _fake(strength: int = 10, defense: int = 10) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.base_strength = strength
	data.base_defense = defense
	unit.character_data = data
	unit.current_hp = 20
	return unit


func _bare_unit(label: String, faction: Enums.UnitFaction = Enums.UnitFaction.ENEMY) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.unit_name = label
	unit.faction = faction
	unit.character_data = CharacterData.new()
	unit.character_data.base_max_hp = 20
	unit.current_hp = 10
	return unit


# =============================================================================
# Parsed shapes
# =============================================================================

func test_pick_ignores_some_defense() -> void:
	var pick := MoveData.get_move("Pick")
	assert_eq([pick.attack_range, pick.base_power, pick.accuracy], [1, 4, 90])
	assert_almost_eq(pick.defense_pierce_pct, 0.3, 0.001)


func test_hatchet_is_his_reach() -> void:
	var hatchet := MoveData.get_move("Hatchet")
	assert_eq([hatchet.attack_range, hatchet.base_power, hatchet.accuracy], [2, 5, 80])


func test_dazzle_may_shock() -> void:
	var dazzle := MoveData.get_move("Dazzle")
	assert_eq(dazzle.damage_type, Enums.DamageType.SPECIAL)
	assert_eq(dazzle.status_effect_type, Enums.StatusEffectType.SHOCKED)


func test_pry_clears_the_buff_slot() -> void:
	assert_eq(MoveData.get_move("Pry").cleanse_effects, PackedStringArray(["BUFF"]))


func test_lantern_lights_the_user_and_allies() -> void:
	var lantern := MoveData.get_move("Lantern")
	assert_eq([lantern.target_type, lantern.area_of_effect, lantern.aoe_affects],
			[Enums.TargetType.SELF, 1, "allies"])
	assert_eq(lantern.status_effect_type, Enums.StatusEffectType.FOCUSED)


func test_rummage_holds_three_finds() -> void:
	var rummage := MoveData.get_move("Rummage")
	assert_eq(rummage.random_payloads.size(), 3)
	assert_almost_eq(float(rummage.random_payloads[0]["heal_pct"]), 0.2, 0.001)
	assert_eq(rummage.random_payloads[1]["effect"], "FORTIFIED")


# =============================================================================
# Defense-pierce
# =============================================================================

func test_pierce_ignores_its_share_of_defense() -> void:
	var attacker := _fake(10, 0)
	var defender := _fake(0, 10)
	var pick := MoveData.get_move("Pick")
	var blunt := MoveData.get_move("Pick")
	blunt.defense_pierce_pct = 0.0
	assert_eq(DamageCalculator.calculate_damage(attacker, defender, pick)
			- DamageCalculator.calculate_damage(attacker, defender, blunt), 3,
			"30% of 10 defense is 3 more damage")


# =============================================================================
# Pry: the buff slot, not the debuff slot
# =============================================================================

func test_pry_strips_a_buff_and_leaves_debuffs() -> void:
	var attacker := _fake()
	var defender := _fake()
	StatusEffectSystem.apply_status_effect_by_name(null, defender, "FORTIFIED", 4)
	StatusEffectSystem.apply_status_effect_by_name(null, defender, "BURN", 2)
	var ctx := CombatHitContext.new()
	ctx.attacker = attacker
	ctx.defender = defender
	ctx.move = MoveData.get_move("Pry")
	CleanseEffect.new().on_hit(ctx)
	assert_eq(StatusEffectSystem.get_effect_stacks(defender, "FORTIFIED"), 0)
	assert_eq(StatusEffectSystem.get_effect_stacks(defender, "BURN"), 2)


# =============================================================================
# Rummage: one payload per cast
# =============================================================================

func _rummage_with(payload: Dictionary) -> Move:
	var move := MoveData.get_move("Rummage")
	move.random_payloads = [payload] as Array[Dictionary]
	return move


func _cast_on_self(unit: Unit, move: Move) -> void:
	var ctx := CombatHitContext.new()
	ctx.attacker = unit
	ctx.defender = unit
	ctx.move = move
	ctx.is_support = true
	OneOfEffect.new().on_hit(ctx)


func test_a_bandage_heals_a_share_of_max_hp() -> void:
	var traveller := _bare_unit("traveller")
	_cast_on_self(traveller, _rummage_with({"heal_pct": 0.2}))
	assert_eq(traveller.current_hp, 14, "20% of 20 max HP")


func test_a_status_find_lands_on_the_user() -> void:
	var traveller := _bare_unit("traveller")
	_cast_on_self(traveller, _rummage_with({"effect": "FORTIFIED", "stacks": 2}))
	assert_eq(StatusEffectSystem.get_effect_stacks(traveller, "FORTIFIED"), 2)


func test_a_cast_draws_exactly_one_find() -> void:
	var traveller := _bare_unit("traveller")
	_cast_on_self(traveller, MoveData.get_move("Rummage"))
	var found: int = int(traveller.current_hp > 10) \
			+ int(StatusEffectSystem.get_effect_stacks(traveller, "FORTIFIED") > 0) \
			+ int(StatusEffectSystem.get_effect_stacks(traveller, "FOCUSED") > 0)
	assert_eq(found, 1)


func test_rummage_counts_as_a_self_payload() -> void:
	assert_true(_bare_unit("traveller")._self_cast_has_self_payload(MoveData.get_move("Rummage")),
			"otherwise the self-cast would only play its flourish")


# =============================================================================
# Lantern reaches allies alongside, not foes
# =============================================================================

func test_lantern_reaches_allies_alongside_only() -> void:
	for x: int in range(4):
		var tile := Tile.new()
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		tile.add_child(sprite)
		add_child_autofree(tile)
		tile.grid_x = x
		tile.grid_y = 0
		tile.terrain_type_name = "Plains"
		GridManager.register_tile(tile)
	var foe := _bare_unit("foe", Enums.UnitFaction.PLAYER)
	var traveller := _bare_unit("traveller")
	var ally := _bare_unit("ally")
	var far_ally := _bare_unit("far ally")
	for pair: Array in [[foe, 0], [traveller, 1], [ally, 2], [far_ally, 3]]:
		var tile: Tile = GridManager.get_tile(pair[1], 0)
		(pair[0] as Unit).current_tile = tile
		tile.current_unit = pair[0]
	var victims := MoveTargeting.get_area_victims(traveller, traveller.current_tile,
			MoveData.get_move("Lantern"))
	assert_eq(victims, [ally] as Array[Unit])
