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

	# Formula
	var base_damage: float = (move.base_power * attack_stat / 5.0) - defense_stat
	var final_damage := maxi(1, roundi(base_damage * type_multiplier))

	DebugConfig.log_combat("DamageCalc: power=%d * atk=%d / 5 - def=%d = %.1f * type=%.2f -> %d" % [
		move.base_power, attack_stat, defense_stat, base_damage, type_multiplier, final_damage])

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

	return type_chart_manager.get_combined_effectiveness(
		move.element_type, defender_data.primary_type, defender_data.secondary_type)


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
