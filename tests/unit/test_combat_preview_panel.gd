## CombatPreviewPanel's multiplier column: type effectiveness × STAB, coloured
## by the type stage alone (ui-style-guide §6 LOCK on the colour tiers). STAB
## used to be applied to the damage number silently — the column now says so.
extends GutTest


const _SCENE: PackedScene = preload("res://scenes/ui/panels/combat_preview_panel/combat_preview_panel.tscn")


func _unit(primary := Enums.ElementalType.NONE) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.base_strength = 20
	data.base_special = 20
	data.base_defense = 10
	data.base_resistance = 10
	data.base_max_hp = 30
	data.primary_type = primary
	unit.character_data = data
	unit.current_hp = data.max_hp
	return unit


func _move(element := Enums.ElementalType.FIRE) -> Move:
	var move := Move.new()
	move.move_name = "Ember"
	move.abbrev_name = "Ember"
	move.base_power = 10
	move.accuracy = 90
	move.damage_type = Enums.DamageType.PHYSICAL
	move.element_type = element
	move.attack_range = 1
	return move


func _panel() -> CombatPreviewPanel:
	var panel := _SCENE.instantiate() as CombatPreviewPanel
	add_child_autofree(panel)
	return panel


# --- the pure part -------------------------------------------------------------

func test_displayed_multiplier_is_type_times_stab() -> void:
	assert_almost_eq(CombatPreviewPanel.displayed_multiplier(1.0, 1.2), 1.2, 0.0001,
			"STAB on a neutral matchup shows as x1.2")
	assert_almost_eq(CombatPreviewPanel.displayed_multiplier(1.44, 1.2), 1.728, 0.0001,
			"a type edge and STAB compound, as the damage does")
	assert_almost_eq(CombatPreviewPanel.displayed_multiplier(1.44, 1.0), 1.44, 0.0001)


func test_immunity_is_not_rescued_by_stab() -> void:
	assert_eq(CombatPreviewPanel.displayed_multiplier(TypeChart.IMMUNE_MULTIPLIER, 1.2),
			TypeChart.IMMUNE_MULTIPLIER)


# --- on the panel ----------------------------------------------------------------

func test_a_stab_move_shows_its_multiplier_in_the_neutral_tier() -> void:
	var panel := _panel()
	var attacker := _unit(Enums.ElementalType.FIRE)
	var defender := _unit(Enums.ElementalType.NONE)
	panel.show_preview(attacker, defender, _move(Enums.ElementalType.FIRE))
	var label: Label = panel._attacker_multiplier_label
	assert_true(label.get_parent().visible, "STAB alone is worth showing")
	assert_eq(label.text, "x%.2f" % DamageCalculator.STAB_MULTIPLIER)
	assert_eq(label.get_theme_color("font_color"), panel._MULTIPLIER_COLORS["neut"][0],
			"the colour is the TYPE stage — neutral — so it can't read as a type edge")


func test_an_off_type_neutral_move_shows_nothing() -> void:
	var panel := _panel()
	panel.show_preview(_unit(Enums.ElementalType.PLANT), _unit(Enums.ElementalType.NONE),
			_move(Enums.ElementalType.FIRE))
	assert_false(panel._attacker_multiplier_label.get_parent().visible,
			"no type edge, no STAB — the column stays quiet as before")


func test_the_shown_number_matches_the_damage_scale() -> void:
	# The damage number IS base × type × STAB; the column must not promise a
	# different scale than the number above it was computed with.
	var panel := _panel()
	var stab_attacker := _unit(Enums.ElementalType.FIRE)
	var plain_attacker := _unit(Enums.ElementalType.PLANT)
	var defender := _unit(Enums.ElementalType.NONE)
	var move := _move(Enums.ElementalType.FIRE)
	panel.show_preview(plain_attacker, defender, move)
	var plain_damage: int = int(panel._attacker_damage_label.text)
	panel.show_preview(stab_attacker, defender, move)
	var stab_damage: int = int(panel._attacker_damage_label.text)
	assert_eq(stab_damage, roundi(plain_damage * DamageCalculator.STAB_MULTIPLIER))
	assert_eq(panel._attacker_multiplier_label.text, "x%.2f" % DamageCalculator.STAB_MULTIPLIER)
