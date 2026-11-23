## Grudge passive: when an ally within 3 tiles falls, this unit goes after
## whoever did it. It takes CHALLENGED with the killer as the challenger, so
## it can only attack the killer until the status runs out or the killer
## falls. The player can read it and bait it.
##
## An on_ally_defeated handler (PassiveEffectsSystem.notify_defeated_by, after a
## killing hit). Enemy side only; CHALLENGED binds player units too, so a
## player-side grudge is one condition away. The one-debuff slot rule still
## applies: a unit already carrying another debuff can't take the grudge.
class_name GrudgePassive
extends CombatEffect


const RANGE_TILES: int = 3


func on_ally_defeated(unit: Unit, fallen: Unit, killer: Unit) -> void:
	if unit == null or fallen == null or killer == null or not is_instance_valid(killer):
		return
	if unit.faction != Enums.UnitFaction.ENEMY or killer.faction == unit.faction:
		return
	if killer.is_defeated() or unit.current_tile == null or fallen.current_tile == null:
		return
	if unit.character_data == null or not unit.character_data.has_equipped_passive("Grudge"):
		return
	var distance: int = absi(fallen.current_tile.grid_x - unit.current_tile.grid_x) \
			+ absi(fallen.current_tile.grid_y - unit.current_tile.grid_y)
	if distance > RANGE_TILES:
		return
	# The killer is the caster, so StatusEffectSystem stamps it as source_unit:
	# that's who MoveTargeting.active_challenger binds this unit to.
	StatusEffectSystem.apply_status_effect_by_name(killer, unit, "CHALLENGED")
