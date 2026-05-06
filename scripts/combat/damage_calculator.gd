## Pure calculation helpers for combat damage, multi-hit, and counter-attack checks.
## All static methods — no state, no side effects.
##
## Damage formula (from Unity):
##   attack_stat = strength (physical) or special (special move)
##   defense_stat = defense (physical) or resistance (special)
##   base_damage = (move.base_power * attack_stat / 5) - defense_stat
##   final_damage = max(1, round(base_damage * type_multiplier))
class_name DamageCalculator
extends RefCounted


## Calculate damage for a single hit.
static func calculate_damage(attacker: Node2D, defender: Node2D, move: Move) -> int:
	if attacker == null or defender == null or move == null:
		return 1

	var attacker_data: CharacterData = attacker.get("character_data")
	var defender_data: CharacterData = defender.get("character_data")
	if attacker_data == null or defender_data == null:
		return 1

	# Pick attack/defense stats based on damage type
	var attack_stat: int
	var defense_stat: int
	if move.damage_type == Enums.DamageType.PHYSICAL:
		attack_stat = attacker_data.strength
		defense_stat = defender_data.defense
	else:
		attack_stat = attacker_data.special
		defense_stat = defender_data.resistance

	# Type effectiveness
	var type_multiplier := get_type_effectiveness(attacker, defender, move)

	# Bellows: +25% fire damage per stack
	var bellows_multiplier := 1.0
	if move.element_type == Enums.ElementalType.FIRE:
		var status_system: Node = attacker.get_node_or_null("/root/StatusEffectSystem")
		if status_system != null:
			var bellows_stacks: int = status_system.get_effect_stacks(attacker, "BELLOWS")
			if bellows_stacks > 0:
				bellows_multiplier = 1.0 + (bellows_stacks * 0.25)

	# Formula
	var base_damage: float = (move.base_power * attack_stat / 5.0) - defense_stat
	var final_damage := maxi(1, roundi(base_damage * type_multiplier * bellows_multiplier))

	DebugConfig.log_combat("DamageCalc: power=%d * atk=%d / 5 - def=%d = %.1f * type=%.2f * bellows=%.2f -> %d" % [
		move.base_power, attack_stat, defense_stat, base_damage, type_multiplier, bellows_multiplier, final_damage])

	return final_damage


## Calculate number of attacks based on athleticism ratio.
## 4x = 4 hits, 3x = 3, 2x = 2, else 1.
static func calculate_attack_count(attacker: Node2D, defender: Node2D) -> int:
	if attacker == null or defender == null:
		return 1

	var attacker_data: CharacterData = attacker.get("character_data")
	var defender_data: CharacterData = defender.get("character_data")
	if attacker_data == null or defender_data == null:
		return 1

	var attacker_athleticism := maxi(1, attacker_data.athleticism)
	var defender_athleticism := maxi(1, defender_data.athleticism)
	var ratio := float(attacker_athleticism) / float(defender_athleticism)

	if ratio >= 4.0:
		return 4
	elif ratio >= 3.0:
		return 3
	elif ratio >= 2.0:
		return 2
	return 1


## Get combined type effectiveness (handles dual-type defenders).
static func get_type_effectiveness(attacker: Node2D, defender: Node2D, move: Move) -> float:
	if move == null:
		return 1.0

	var defender_data: CharacterData = defender.get("character_data")
	if defender_data == null:
		return 1.0

	var type_chart_manager: Node = Engine.get_singleton("TypeChartManager") if Engine.has_singleton("TypeChartManager") else null
	if type_chart_manager == null:
		# Fallback: try autoload path
		type_chart_manager = attacker.get_node_or_null("/root/TypeChartManager")
	if type_chart_manager == null:
		return 1.0

	# Use effective types so Crystallization-injured units lose their typing.
	return type_chart_manager.get_combined_effectiveness(
		move.element_type,
		defender_data.effective_primary_type(),
		defender_data.effective_secondary_type())


## Raw heal output of a move before per-target modifiers (Laceration, missing-HP clamp).
## This is the "formula" — when stronger support moves come online they extend this
## (e.g. multi-stat scaling, fixed amounts, percentages of max HP).
static func move_heal_output(caster: Node2D, move: Move) -> int:
	if caster == null or move == null:
		return 0
	var raw: int = move.base_power
	var caster_data: CharacterData = caster.get("character_data")
	if caster_data != null:
		raw += caster_data.special
	return raw


## Apply target-side healing modifiers (Laceration `healing_reduction_pct`, missing-HP clamp).
## Used by every heal source so reduction is computed in one place: move heals,
## Regen ticks, anything else that lands HP on a unit.
static func apply_healing_reduction(target: Node2D, raw_amount: int) -> int:
	if target == null or raw_amount <= 0:
		return 0
	var target_data: CharacterData = target.get("character_data")
	var actual: int = raw_amount
	if target_data != null and target_data.healing_reduction_pct > 0.0:
		actual = maxi(1, int(floor(raw_amount * (1.0 - target_data.healing_reduction_pct / 100.0))))
	var current_hp: int = target.get("current_hp")
	var max_hp: int = target_data.max_hp if target_data != null else current_hp
	return maxi(0, mini(actual, max_hp - current_hp))


## Final, ready-to-apply heal amount: move output → target reduction → missing-HP clamp.
## Both the combat preview panel and Unit._execute_heal_hit route through this so
## the preview is guaranteed to match what actually lands.
static func calculate_heal_amount(caster: Node2D, target: Node2D, move: Move) -> int:
	return apply_healing_reduction(target, move_heal_output(caster, move))


## Check if defender can counter-attack the attacker.
static func can_counter_attack(defender: Node2D, attacker: Node2D) -> bool:
	if defender == null or attacker == null:
		return false

	# Must not be defeated
	var defender_hp: int = defender.get("current_hp")
	if defender_hp <= 0:
		return false

	# Must have an assigned move with uses remaining
	var defender_move: Move = defender.get("assigned_move")
	if defender_move == null or not defender_move.has_uses_remaining():
		return false

	# Support moves don't deal damage, so they can't counter-attack.
	# A unit with only support moves equipped is helpless on retaliation by design.
	if defender_move.damage_type == Enums.DamageType.SUPPORT:
		return false

	# Must be in range
	var distance := get_manhattan_distance(defender, attacker)
	if distance > defender_move.attack_range:
		return false

	return true


## How "heavy" a hit feels, from 0.0 (trivial) to 1.0 (devastating).
## Uses the higher of raw-damage ratio and %HP ratio so both big numbers
## and chunk-damage on fragile units register appropriately.
const MAX_REASONABLE_DAMAGE: float = 50.0

static func calculate_impact_weight(damage: int, target_max_hp: int) -> float:
	var raw_ratio := float(damage) / MAX_REASONABLE_DAMAGE
	var hp_ratio := float(damage) / maxf(1.0, float(target_max_hp))
	return clampf(maxf(raw_ratio, hp_ratio), 0.0, 1.0)


## Manhattan distance between two units via their current tiles.
static func get_manhattan_distance(unit_a: Node2D, unit_b: Node2D) -> int:
	var tile_a: Variant = unit_a.get("current_tile")
	var tile_b: Variant = unit_b.get("current_tile")
	if tile_a == null or tile_b == null:
		return 999
	return absi(tile_a.grid_x - tile_b.grid_x) + absi(tile_a.grid_y - tile_b.grid_y)
