## Loner passive: used to the road alone and good at avoiding trouble. +25%
## agility while no ally stands within 2 tiles. A percentage of the unit's own
## agility (level-ups included, buffs not), rounded down with a floor of 1 like
## status buffs, so it keeps pace with the stat instead of fading late game.
##
## Stat aura — dispatched from PassiveEffectsSystem.recompute, which zeroes
## passive_bonus_* first, so this only adds.
class_name LonerPassive
extends CombatEffect


const AGILITY_BONUS_PCT: float = 25.0
const COMPANY_RANGE_TILES: int = 2


func apply_stat_aura(unit: Unit, faction_units: Array[Unit]) -> void:
	if unit == null or unit.character_data == null or unit.current_tile == null:
		return
	for ally: Unit in faction_units:
		if ally == null or ally == unit or ally.is_defeated() or ally.current_tile == null:
			continue
		var distance: int = absi(ally.current_tile.grid_x - unit.current_tile.grid_x) \
				+ absi(ally.current_tile.grid_y - unit.current_tile.grid_y)
		if distance <= COMPANY_RANGE_TILES:
			return
	unit.character_data.add_passive_bonus("agility", bonus_for(unit.character_data), "Loner")


static func bonus_for(data: CharacterData) -> int:
	var agility: int = data.get_base_plus_growth("agility")
	if agility <= 0:
		return 0
	return maxi(1, int(floor(agility * AGILITY_BONUS_PCT / 100.0)))
