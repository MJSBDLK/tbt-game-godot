## Maps passive names to their CombatEffect handlers. Passives ARE CombatEffect
## handlers (see .claude/todo-archive.md "Combat Effect Pipeline" Phase 2) — the same
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
	_handlers["Ghost"] = GhostPassive.new()
	_handlers["Capricious"] = CapriciousPassive.new()
	_handlers["Glib"] = GlibPassive.new()
	_handlers["Impetuous"] = ImpetuousPassive.new()
	_handlers["Flippant"] = FlippantPassive.new()
	_handlers["Impulsive"] = ImpulsivePassive.new()
	_handlers["Anti-Gravity"] = AntiGravityPassive.new()
	_handlers["Regenerator"] = RegeneratorPassive.new()
	_handlers["Jury Rig"] = JuryRigPassive.new()
	_handlers["Waste Not"] = WasteNotPassive.new()
	_handlers["Stellar"] = StellarPassive.new()
	_handlers["Extendo"] = ExtendoPassive.new()
	_handlers["Protector"] = ProtectorPassive.new()
	_handlers["Bravery"] = BraveryPassive.new()
	# NB: Maximum has no handler — it's a stat-calc rule (the clamp in
	# StatusEffectSystem._recalculate_stat_modifiers reads has_maximum_protection),
	# not a dispatchable effect. Stellar above just sets the maximum_from_aura flag.
	_initialized = true


## Handler for a single passive name, or null if not coded yet.
static func get_handler(passive_name: String) -> CombatEffect:
	_ensure_initialized()
	return _handlers.get(passive_name, null)


## All coded handlers for a unit's equipped passives, deduped. Returns shared
## singletons — never mutate them.
##
## When `unit` is supplied, passive slots locked by VOID (unit.is_passive_index_locked)
## are skipped, so a void-locked passive's combat effect goes inert. The argument is
## optional and defaults to null (no gating) to keep the many non-combat callers and
## the tests that pass only character_data working unchanged. Pass the unit from any
## call site that has it so locking is honored consistently.
static func get_handlers_for(character_data: Variant, unit: Node2D = null) -> Array[CombatEffect]:
	_ensure_initialized()
	var out: Array[CombatEffect] = []
	if character_data == null:
		return out
	var passives: Variant = character_data.get("equipped_passives")
	if passives == null:
		return out
	var can_check_lock: bool = unit != null and unit.has_method("is_passive_index_locked")
	for index: int in range(passives.size()):
		if can_check_lock and unit.is_passive_index_locked(index):
			continue
		var handler: CombatEffect = _handlers.get(passives[index], null)
		if handler != null and not out.has(handler):
			out.append(handler)
	return out
