## Hardy passive: tough stock, little fazes them. Every debuff lands on this
## unit one stack lighter, never below one. Most debuffs lose a stack per turn,
## so they wear off a turn sooner; stack-sized ones (Void's locks, a chain
## lightning mark's arcs) come in one smaller.
##
## A query hook: StatusEffectSystem.apply_status_effect_by_name asks the
## target's passives before stacking a debuff. A one-stack debuff still lands,
## so Hardy shortens Rooted and Freeze but never makes the unit immune.
class_name HardyPassive
extends CombatEffect


func lightens_debuffs() -> bool:
	return true
