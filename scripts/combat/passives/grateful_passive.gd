## Grateful passive: help goes further on him. Every buff lands on the owner
## one stack heavier, up to the buff's cap, so it lasts a turn longer (most
## buffs lose a stack a turn). Hardy's mirror: Hardy lightens debuffs.
##
## A query hook: StatusEffectSystem.apply_status_effect_by_name asks the
## target's passives before stacking a buff. A buff already at its cap
## (Covered holds one stack) gains nothing.
class_name GratefulPassive
extends CombatEffect


func deepens_buffs() -> bool:
	return true
