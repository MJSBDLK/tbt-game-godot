## Status-applied callouts + the Bellows-boosted-swing announcement (RQD
## 2026-08-21, todo #2A). Before this, every status landed silently except for
## a 6x6 icon and 1px pips — "I unknowingly activated the enemy's Bellows,
## which obliterated me on the next hit." Now: applying/restacking ANY status
## floats its name over the unit in buff-green / debuff-red, the icon pops,
## and a fire hit that Bellows is scaling announces "BELLOWS xN" over the
## attacker before the swing, with a warm hit flash on the target.
extends GutTest


const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"

var _saved_motion: bool = true


func before_each() -> void:
	_saved_motion = Settings.ui_motion_enabled
	Settings.ui_motion_enabled = true


func after_each() -> void:
	Settings.ui_motion_enabled = _saved_motion


## Real units from the scene, each in its own container so popup scans can't
## see another unit's callouts (same harness as test_combat_xp).
func _spawn_unit(json_path: String, faction: Enums.UnitFaction) -> Unit:
	var unit: Unit = (load("res://scenes/battle/unit.tscn") as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	var container := Node2D.new()
	add_child_autofree(container)
	container.add_child(unit)
	var tile := Tile.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	add_child_autofree(tile)
	tile.grid_x = 0
	tile.grid_y = 0
	tile.terrain_type_name = "Plains"
	unit.initialize(tile)
	return unit


func _callouts(unit: Unit) -> Array[DamagePopup]:
	var popups: Array[DamagePopup] = []
	for child: Node in unit.get_parent().get_children():
		if child is DamagePopup and child._damage_label != null:
			popups.append(child)
	return popups


func _callout_texts(unit: Unit) -> Array:
	var texts: Array = []
	for popup: DamagePopup in _callouts(unit):
		texts.append(popup._damage_label.text)
	return texts


func _callout_color(unit: Unit, text: String) -> Color:
	for popup: DamagePopup in _callouts(unit):
		if popup._damage_label.text == text:
			return popup._damage_label.modulate
	return Color.TRANSPARENT


# =============================================================================
# PURE TEXT
# =============================================================================

func test_status_callout_text_names_the_status_and_counts_restacks() -> void:
	assert_eq(Unit.status_callout_text("Burn", 1), "BURN", "first application: just the name")
	assert_eq(Unit.status_callout_text("Burn", 2), "BURN ×2", "a restack counts up")
	assert_eq(Unit.status_callout_text("Chain L.", 3), "CHAIN L. ×3")
	assert_eq(Unit.status_callout_text("Bellows", 0), "BELLOWS", "0 stacks (shouldn't happen) degrades to the name")


func test_bellows_callout_text_reads_like_a_multiplier() -> void:
	assert_eq(Unit.bellows_callout_text(1.25), "BELLOWS ×1.25")
	assert_eq(Unit.bellows_callout_text(1.5), "BELLOWS ×1.5", "trailing zero dropped")
	assert_eq(Unit.bellows_callout_text(2.0), "BELLOWS ×2", "a whole number stays whole")


# =============================================================================
# STATUS APPLIED → CALLOUT
# =============================================================================

func test_a_debuff_landing_floats_its_name_in_danger_ink() -> void:
	var unit := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)
	StatusEffectSystem.apply_status_effect_by_name(null, unit, "BURN", 1)
	assert_has(_callout_texts(unit), "BURN", "the status says its name when it lands")
	assert_eq(_callout_color(unit, "BURN"), GameColors.TEXT_DANGER,
			"debuffs wear the danger red — NOT element ink, which is the move-name voice")


func test_a_multi_stack_application_says_how_many() -> void:
	# Burn / Poison apply several stacks at once by default — the stacks ARE
	# the DoT's magnitude (and the pips show them), so "BURN ×4" on first
	# landing is the honest reading, not a miscount.
	var unit := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)
	var default_stacks: int = StatusEffectData.get_default_configs()["BURN"].default_apply_stacks
	StatusEffectSystem.apply_status_effect_by_name(null, unit, "BURN")
	assert_has(_callout_texts(unit), Unit.status_callout_text("Burn", default_stacks),
			"the callout carries the applied stack count (%d here)" % default_stacks)


func test_a_buff_landing_floats_in_success_ink() -> void:
	var unit := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)
	StatusEffectSystem.apply_status_effect_by_name(null, unit, "BELLOWS")
	assert_has(_callout_texts(unit), "BELLOWS",
			"Bellows activating is no longer silent (todo #2A)")
	assert_eq(_callout_color(unit, "BELLOWS"), GameColors.TEXT_SUCCESS, "buffs wear the success green")


func test_a_restack_counts_up() -> void:
	var unit := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)
	StatusEffectSystem.apply_status_effect_by_name(null, unit, "BELLOWS")
	StatusEffectSystem.apply_status_effect_by_name(null, unit, "BELLOWS")
	var texts := _callout_texts(unit)
	assert_has(texts, "BELLOWS", "first stack: the name")
	assert_has(texts, "BELLOWS ×2", "second stack: the count — the pips alone are one pixel")


func test_another_units_status_stays_over_that_unit() -> void:
	var bystander := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	var victim := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)
	StatusEffectSystem.apply_status_effect_by_name(null, victim, "POISON", 1)
	assert_has(_callout_texts(victim), "POISON")
	assert_eq(_callout_texts(bystander).size(), 0, "the handler gates on unit == self")


func test_the_icon_pops_when_a_status_lands() -> void:
	var unit := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)
	StatusEffectSystem.apply_status_effect_by_name(null, unit, "BURN", 1)
	var indicator: StatusEffectIndicator = unit._status_indicator
	assert_true(indicator.visible, "the icon row shows the new status")
	assert_eq(indicator._icon_effect_types, ["BURN"] as Array[String], "the drawn slot knows what it stands for")
	assert_almost_eq(indicator._icon_sprites[0].scale.x, StatusEffectIndicator.POP_SCALE, 0.001,
			"snaps to the pop scale the instant it lands…")
	await wait_seconds(StatusEffectIndicator.POP_SECONDS + 0.1)
	assert_almost_eq(indicator._icon_sprites[0].scale.x, 1.0, 0.01, "…and eases back to 1")


func test_the_icon_pop_is_parked_under_reduce_motion() -> void:
	Settings.ui_motion_enabled = false
	var unit := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)
	StatusEffectSystem.apply_status_effect_by_name(null, unit, "BURN", 1)
	assert_almost_eq(unit._status_indicator._icon_sprites[0].scale.x, 1.0, 0.001,
			"no scale snap without motion")
	assert_has(_callout_texts(unit), "BURN", "the callout still carries the event")


# =============================================================================
# BELLOWS-BOOSTED SWING
# =============================================================================

func _fire_move() -> Move:
	var move := Move.new()
	move.move_name = "Test Blaze"
	move.element_type = Enums.ElementalType.FIRE
	move.damage_type = Enums.DamageType.SPECIAL
	move.base_power = 5
	move.accuracy = 255  # clamps to 100 — the swing always lands
	move.attack_range = 1
	return move


func test_a_bellows_boosted_swing_announces_its_multiplier_over_the_attacker() -> void:
	var attacker := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	var target := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)
	StatusEffectSystem.apply_status_effect_by_name(null, attacker, "BELLOWS", 2)
	assert_almost_eq(DamageCalculator.bellows_multiplier(attacker, _fire_move()), 1.5, 0.001,
			"precondition: two stacks = x1.5")
	await attacker._execute_single_hit(target, _fire_move(), true)
	assert_has(_callout_texts(attacker), "BELLOWS ×1.5",
			"the boost is named over the attacker with the calculator's own number")


func test_an_unboosted_swing_says_nothing_about_bellows() -> void:
	var attacker := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	var target := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)
	await attacker._execute_single_hit(target, _fire_move(), true)
	for text: String in _callout_texts(attacker):
		assert_false(text.begins_with("BELLOWS"), "no stacks, no announcement: got '%s'" % text)
