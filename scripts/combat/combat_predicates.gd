## Named per-unit predicates for conditional combat effects (Phase 4).
## One registry so move JSON can reference conditions by name — a conditional
## statusEffect branches on one ("brave" → Roar's CHALLENGED-vs-SHOCKED split),
## a move-wide immune_predicate exempts matching units entirely (Shriek).
##
## Adding a predicate = one match arm here + its name in JSON. Keep them PURE
## (read unit state, mutate nothing) — they run inside targeting filters and
## the action menu's meaningful-effect check, not just combat execution.
class_name CombatPredicates
extends RefCounted


## Evaluate `predicate` against `unit`. Unknown names warn and return false —
## a typo'd immunity must not silently exempt everyone (fail toward "the move
## works normally", surfaced in the log).
static func evaluate(predicate: String, unit: Node2D) -> bool:
	match predicate:
		"brave":
			return is_brave(unit)
		"not_brave":
			return not is_brave(unit)
		"electric":
			return is_electric(unit)
		_:
			push_warning("CombatPredicates: unknown predicate '%s'" % predicate)
			return false


## The fear-cluster keystone: brave units are challenged by Roar (CHALLENGED
## instead of SHOCKED) and immune to Shriek of the Damned. Brave = Chivalric
## PRIMARY type (per the Phase 4 spec — a Chivalric secondary isn't enough) or
## the Bravery passive, which grants the mechanical courage without the type's
## weaknesses/resistances. Uses effective_primary_type, so Crystallization
## stripping the type strips the courage with it — the passive is the way to
## be brave that nothing can take from you.
static func is_brave(unit: Node2D) -> bool:
	if unit == null:
		return false
	var data: Variant = unit.get("character_data")
	if data == null:
		return false
	if data.effective_primary_type() == Enums.ElementalType.CHIVALRIC:
		return true
	for handler: CombatEffect in PassiveRegistry.get_handlers_for(data, unit):
		if handler.grants_bravery():
			return true
	return false


## Lightning doesn't bother the already-charged: ELECTRIC on EITHER effective
## type slot makes the unit immune to every hop of a chain-lightning strike
## (ScheduledEffects skips them as arc candidates; RQD 2026-08-03).
static func is_electric(unit: Node2D) -> bool:
	if unit == null:
		return false
	var data: Variant = unit.get("character_data")
	if data == null:
		return false
	return data.effective_primary_type() == Enums.ElementalType.ELECTRIC \
			or data.effective_secondary_type() == Enums.ElementalType.ELECTRIC
