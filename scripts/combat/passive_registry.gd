## Maps passive names to their CombatEffect handlers. Passives ARE CombatEffect
## handlers (see .claude/todo.md "Combat Effect Pipeline" Phase 2) — the same
## type the move/affliction effects use, so a unit's passives can be gathered
## into the per-hit combat pipeline alongside the move's own effects.
##
## Handlers are STATELESS, shared singletons (one instance per passive name). All
## per-hit state lives on the CombatHitContext, so sharing is safe and lets the
## pipeline dedupe by identity (a passive both combatants carry runs once).
##
## Only migrated passives appear here; unknown/not-yet-coded names resolve to
## null and are simply skipped. Passives that hook non-combat dispatch points
## (auras, pathfinding, AI move-pick) will register here too as those phases are
## added to CombatEffect and wired to their call sites.
class_name PassiveRegistry
extends RefCounted


static var _handlers: Dictionary = {}  # String -> CombatEffect
static var _initialized: bool = false


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_handlers["Bellows"] = BellowsPassive.new()
	_handlers["Reliable"] = ReliablePassive.new()
	_handlers["Low Profile"] = LowProfilePassive.new()
	_handlers["Competitive"] = CompetitivePassive.new()
	_initialized = true


## Handler for a single passive name, or null if not coded yet.
static func get_handler(passive_name: String) -> CombatEffect:
	_ensure_initialized()
	return _handlers.get(passive_name, null)


## All coded handlers for a unit's equipped passives, deduped. Returns shared
## singletons — never mutate them.
static func get_handlers_for(character_data: Variant) -> Array[CombatEffect]:
	_ensure_initialized()
	var out: Array[CombatEffect] = []
	if character_data == null:
		return out
	var passives: Variant = character_data.get("equipped_passives")
	if passives == null:
		return out
	for passive_name: Variant in passives:
		var handler: CombatEffect = _handlers.get(passive_name, null)
		if handler != null and not out.has(handler):
			out.append(handler)
	return out
