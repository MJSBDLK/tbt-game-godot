## Gloat passive: when the owner lands a crit or drops a foe, every foe within
## RANGE_TILES takes CHALLENGED from it, a turn of only being able to aim at
## the owner. Once per hit, even when a crit also kills. Counters count.
##
## An on_hit (crits) and on_kill (kills without a crit) handler. Both check
## ctx.attacker, the unit whose swing it was, for the passive.
class_name GloatPassive
extends CombatEffect


const RANGE_TILES: int = 2
## 2 stacks = 1 bound turn: statuses tick at the start of their owner's turn.
const CHALLENGED_STACKS: int = 2


func on_hit(ctx: CombatHitContext) -> void:
	if ctx.is_crit:
		_gloat(ctx.attacker as Unit)


func on_kill(ctx: CombatHitContext) -> void:
	if not ctx.is_crit:
		_gloat(ctx.attacker as Unit)


static func _gloat(unit: Unit) -> void:
	if unit == null or unit.is_defeated() or unit.current_tile == null:
		return
	if unit.character_data == null or not unit.character_data.has_equipped_passive("Gloat"):
		return
	for tile: Tile in GridManager.get_tiles_within_range(unit.current_tile, RANGE_TILES):
		var foe := tile.current_unit as Unit
		if foe == null or foe.is_defeated() or foe.faction == unit.faction:
			continue
		StatusEffectSystem.apply_status_effect_by_name(unit, foe, "CHALLENGED", CHALLENGED_STACKS)
