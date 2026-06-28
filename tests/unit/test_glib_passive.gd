## Phase 2: Glib — "gets along with other sarcastic little shits." A stat aura on
## the dedicated avoid channel: sarcastic allies near each other dodge better;
## earnest allies near a Glib unit dodge worse. Emitter-writes, so it exercises
## the two-pass recompute (PassiveEffectsSystem.recompute_faction).
extends GutTest


func _unit(grid_x: int, grid_y: int, passives: Array = []) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.current_hp = 100  # alive (is_defeated() is current_hp <= 0)
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	var tile := Tile.new()
	autofree(tile)
	tile.grid_x = grid_x
	tile.grid_y = grid_y
	unit.current_tile = tile
	return unit


func _avoid(unit: Unit) -> int:
	return unit.character_data.passive_bonus_avoid


# =============================================================================
# Handler (emitter writes to allies)
# =============================================================================

func test_glib_boosts_a_nearby_glib_ally() -> void:
	var emitter := _unit(0, 0, ["Glib"])
	var buddy := _unit(1, 0, ["Glib"])
	GlibPassive.new().apply_stat_aura(emitter, [emitter, buddy])
	assert_eq(_avoid(buddy), GlibPassive.AVOID_BOOST, "sarcastic ally gets +avoid")


func test_glib_penalizes_a_nearby_earnest_ally() -> void:
	var emitter := _unit(0, 0, ["Glib"])
	var earnest := _unit(1, 0, [])
	GlibPassive.new().apply_stat_aura(emitter, [emitter, earnest])
	assert_eq(_avoid(earnest), -GlibPassive.AVOID_PENALTY, "earnest ally loses avoid")


func test_other_humor_passives_count_as_in_group() -> void:
	# A non-Glib member of HUMOR_PASSIVES (Anti-Gravity) is "in on the bit" — it
	# gets the boost, not the penalty. Locks in the list-driven in-group check.
	var emitter := _unit(0, 0, ["Glib"])
	var anti_grav := _unit(1, 0, ["Anti-Gravity"])
	GlibPassive.new().apply_stat_aura(emitter, [emitter, anti_grav])
	assert_eq(_avoid(anti_grav), GlibPassive.AVOID_BOOST, "Anti-Gravity is in-group → boosted")


func test_glib_excludes_self() -> void:
	var emitter := _unit(0, 0, ["Glib"])
	GlibPassive.new().apply_stat_aura(emitter, [emitter])
	assert_eq(_avoid(emitter), 0, "a lone Glib unit gets no boost from itself")


func test_glib_ignores_out_of_range() -> void:
	var emitter := _unit(0, 0, ["Glib"])
	var far_buddy := _unit(10, 0, ["Glib"])
	GlibPassive.new().apply_stat_aura(emitter, [emitter, far_buddy])
	assert_eq(_avoid(far_buddy), 0, "out of range → no effect")


# =============================================================================
# Two-pass recompute: clustering stacks, mixing penalizes
# =============================================================================

func test_clustered_glib_units_buff_each_other() -> void:
	var a := _unit(0, 0, ["Glib"])
	var b := _unit(1, 0, ["Glib"])
	var c := _unit(0, 1, ["Glib"])
	var units: Array[Unit] = [a, b, c]
	PassiveEffectsSystem.recompute_faction(units)
	# Each is boosted by the OTHER two.
	assert_eq(_avoid(a), 2 * GlibPassive.AVOID_BOOST)
	assert_eq(_avoid(b), 2 * GlibPassive.AVOID_BOOST)
	assert_eq(_avoid(c), 2 * GlibPassive.AVOID_BOOST)


func test_earnest_ally_in_a_glib_pack_is_doubly_penalized() -> void:
	var glib_a := _unit(0, 0, ["Glib"])
	var glib_b := _unit(1, 0, ["Glib"])
	var earnest := _unit(0, 1, [])
	var units: Array[Unit] = [glib_a, glib_b, earnest]
	PassiveEffectsSystem.recompute_faction(units)
	assert_eq(_avoid(earnest), -2 * GlibPassive.AVOID_PENALTY, "−penalty from each Glib unit")
	# Sanity: the two Glib units still buff each other (proves no clobber across passes).
	assert_eq(_avoid(glib_a), GlibPassive.AVOID_BOOST)


# =============================================================================
# Registry + avoid channel reaches the hit formula
# =============================================================================

func test_registry_resolves_glib() -> void:
	assert_true(PassiveRegistry.get_handler("Glib") is GlibPassive)


func test_avoid_channel_lowers_incoming_hit_chance() -> void:
	# +20 avoid on the defender should drop a 90% move to 70% (no skill/agi gap).
	var attacker := _unit(0, 0)
	var defender := _unit(5, 5)
	defender.character_data.passive_bonus_avoid = 20
	var move := Move.new()
	move.accuracy = 90
	move.attack_range = 1
	assert_eq(DamageCalculator.hit_chance_pct(attacker, defender, move), 70)
