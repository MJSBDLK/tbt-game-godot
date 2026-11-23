## Shaken passive: a loner who rarely has company takes losing one hard. When
## an ally within 3 tiles falls to a hit, this unit is SHOCKED for a turn.
## A flaw: the opening it gives is the point.
##
## An on_ally_defeated handler (PassiveEffectsSystem.notify_defeated_by), the
## same trigger as Grudge. Works on either side, unlike Grudge: SHOCKED is a
## real debuff on a player unit too.
class_name ShakenPassive
extends CombatEffect


const RANGE_TILES: int = 3
const SHOCKED_STACKS: int = 1


func on_ally_defeated(unit: Unit, fallen: Unit, killer: Unit) -> void:
	if unit == null or fallen == null or unit.current_tile == null or fallen.current_tile == null:
		return
	if unit.character_data == null or not unit.character_data.has_equipped_passive("Shaken"):
		return
	var distance: int = absi(fallen.current_tile.grid_x - unit.current_tile.grid_x) \
			+ absi(fallen.current_tile.grid_y - unit.current_tile.grid_y)
	if distance > RANGE_TILES:
		return
	var caster: Node2D = killer if killer != null and is_instance_valid(killer) else null
	StatusEffectSystem.apply_status_effect_by_name(caster, unit, "SHOCKED", SHOCKED_STACKS)
