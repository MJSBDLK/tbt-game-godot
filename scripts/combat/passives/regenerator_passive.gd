## Regenerator passive: heals a slice of max HP at the start of each turn. A
## SEPARATE heal channel from the REGEN boost — if a unit has both, they heal
## independently (two heals), per design. Routed through apply_healing_reduction
## so Laceration still dampens it and it can't overheal.
##
## A turn-start handler (TurnManager._process_passive_turn_start).
class_name RegeneratorPassive
extends CombatEffect


const HEAL_PCT_OF_MAX_HP: float = 0.08


func on_turn_start(unit: Unit, _allies: Array[Unit]) -> void:
	if unit.character_data == null:
		return
	var base_heal: int = maxi(1, int(floor(unit.character_data.max_hp * HEAL_PCT_OF_MAX_HP)))
	var applied: int = DamageCalculator.apply_healing_reduction(unit, base_heal)
	unit.heal(applied)
