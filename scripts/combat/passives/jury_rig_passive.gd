## Jury Rig passive: tinkers with the squad's machines — heals each orthogonally
## adjacent robo-type ally a slice of THEIR max HP at the start of each turn.
## (Robo = primary or secondary type is Robo. Adjacency = the 4 orthogonal
## neighbours.) Routed through apply_healing_reduction so Laceration dampens it
## and it can't overheal. The Jury Rig unit itself isn't healed (it's not adjacent
## to itself, and "allies" means others).
##
## A turn-start handler; uses the `allies` faction list to find neighbours.
class_name JuryRigPassive
extends CombatEffect


const HEAL_PCT_OF_MAX_HP: float = 0.10


func on_turn_start(unit: Unit, allies: Array[Unit]) -> void:
	if unit.current_tile == null:
		return
	var origin_x: int = unit.current_tile.grid_x
	var origin_y: int = unit.current_tile.grid_y
	for ally: Unit in allies:
		if ally == null or ally == unit or ally.is_defeated() or ally.current_tile == null:
			continue
		if ally.character_data == null or not _is_robo(ally.character_data):
			continue
		var dx: int = absi(ally.current_tile.grid_x - origin_x)
		var dy: int = absi(ally.current_tile.grid_y - origin_y)
		if dx + dy != 1:  # orthogonally adjacent only
			continue
		var base_heal: int = maxi(1, int(floor(ally.character_data.max_hp * HEAL_PCT_OF_MAX_HP)))
		ally.heal(DamageCalculator.apply_healing_reduction(ally, base_heal))


func _is_robo(data: CharacterData) -> bool:
	return data.primary_type == Enums.ElementalType.ROBO \
		or data.secondary_type == Enums.ElementalType.ROBO
