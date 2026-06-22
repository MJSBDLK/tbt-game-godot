## Competitive passive: +3 to whichever single stat is highest among allied units
## within 3 Manhattan tiles. "Max tries to keep up with his strongest teammate."
##
## Stat aura — dispatched from PassiveEffectsSystem.recompute, which zeroes
## passive_bonus_* before calling, so this only adds. HP is excluded (a +3 HP bump
## off a comparative passive is too strong). Self is excluded; ties broken by the
## order of COMPARABLE_STATS. Migrated from PassiveEffectsSystem._apply_competitive.
class_name CompetitivePassive
extends CombatEffect


const COMPARABLE_STATS: Array[String] = [
	"strength", "special", "skill", "agility",
	"athleticism", "defense", "resistance",
]
const RANGE_TILES: int = 3
const BONUS: int = 3


func apply_stat_aura(unit: Unit, faction_units: Array[Unit]) -> void:
	if unit == null or unit.character_data == null or unit.current_tile == null:
		return

	var nearby: Array[Unit] = _allies_within_range(unit, faction_units)
	if nearby.is_empty():
		return

	var best_stat_name: String = ""
	var best_value: int = -1
	for stat_name: String in COMPARABLE_STATS:
		for ally: Unit in nearby:
			var value: int = _read_stat(ally.character_data, stat_name)
			if value > best_value:
				best_value = value
				best_stat_name = stat_name

	if best_stat_name != "":
		_add_passive_bonus(unit.character_data, best_stat_name, BONUS)


func _allies_within_range(unit: Unit, faction_units: Array[Unit]) -> Array[Unit]:
	var out: Array[Unit] = []
	var origin_x: int = unit.current_tile.grid_x
	var origin_y: int = unit.current_tile.grid_y
	for ally: Unit in faction_units:
		if ally == null or ally == unit or ally.is_defeated() or ally.current_tile == null:
			continue
		var dx: int = absi(ally.current_tile.grid_x - origin_x)
		var dy: int = absi(ally.current_tile.grid_y - origin_y)
		if dx + dy <= RANGE_TILES:
			out.append(ally)
	return out


func _read_stat(data: CharacterData, stat_name: String) -> int:
	# Read through the public getters so we see the ally's *current* stat
	# (their own passive bonuses, status modifiers, etc.). No feedback loop
	# because Competitive doesn't read max_hp.
	match stat_name:
		"strength": return data.strength
		"special": return data.special
		"skill": return data.skill
		"agility": return data.agility
		"athleticism": return data.athleticism
		"defense": return data.defense
		"resistance": return data.resistance
		_: return 0


func _add_passive_bonus(data: CharacterData, stat_name: String, amount: int) -> void:
	match stat_name:
		"strength": data.passive_bonus_strength += amount
		"special": data.passive_bonus_special += amount
		"skill": data.passive_bonus_skill += amount
		"agility": data.passive_bonus_agility += amount
		"athleticism": data.passive_bonus_athleticism += amount
		"defense": data.passive_bonus_defense += amount
		"resistance": data.passive_bonus_resistance += amount
