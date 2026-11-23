## Close Ranks passive: +2 defense while standing next to an ally (any of the
## four neighboring tiles). Shoulder to shoulder, the line holds.
##
## Stat aura — dispatched from PassiveEffectsSystem.recompute, which zeroes
## passive_bonus_* first, so this only adds. One ally or four, the bonus is the
## same: it's about not standing alone.
class_name CloseRanksPassive
extends CombatEffect


const BONUS: int = 2


func apply_stat_aura(unit: Unit, faction_units: Array[Unit]) -> void:
	if unit == null or unit.character_data == null or unit.current_tile == null:
		return
	for ally: Unit in faction_units:
		if ally == null or ally == unit or ally.is_defeated() or ally.current_tile == null:
			continue
		var distance: int = absi(ally.current_tile.grid_x - unit.current_tile.grid_x) \
				+ absi(ally.current_tile.grid_y - unit.current_tile.grid_y)
		if distance == 1:
			unit.character_data.add_passive_bonus("defense", BONUS, "Close Ranks")
			return
