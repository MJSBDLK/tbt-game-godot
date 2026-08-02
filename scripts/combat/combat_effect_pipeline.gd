## Orchestrates combat effect handlers for a single hit. Stateless static class.
##
## gather() builds the ordered handler list for a hit from the move's fields;
## run_modify_damage() / run_on_hit() execute a phase across that list. Unit's
## hit executors call gather() once, then run each phase at the right moment.
##
## Phase 0 derives handlers from the move's existing parsed fields at gather time
## (rather than precompiling a spec list onto Move) — lower risk, no change to
## Move duplication. When the JSON gains a generic `effects` array, gather() can
## read that instead. Handler order matches the old inline block exactly:
## affliction → cleanse → displace.
class_name CombatEffectPipeline
extends RefCounted


## Build the handler list for this hit, in resolution order.
static func gather(ctx: CombatHitContext) -> Array[CombatEffect]:
	var effects: Array[CombatEffect] = []
	var move: Move = ctx.move
	if move == null:
		return effects

	# Crit (damage hits only — heals and support applications have no damage
	# to double). Added when the move has a secondary crit, or the attacker is
	# carrying a banked pending_crit to spend on this hit. Runs in the
	# modify_damage phase (this-hit crit) and/or on_hit (banking setup moves).
	if not ctx.is_heal and not ctx.is_support:
		var attacker_pending: bool = ctx.attacker != null and bool(ctx.attacker.get("pending_crit"))
		if move.crit_chance > 0.0 or attacker_pending:
			effects.append(CritEffect.new())

	# Affliction/boost rider (applies on first hit only; the handler gates on
	# ctx.apply_status). Self-vs-target routing is inside apply_status_effect.
	if move.status_effect_type != Enums.StatusEffectType.NONE:
		effects.append(ApplyAfflictionEffect.new())

	# Conditional-by-target affliction (Phase 4 — Roar). Which effect lands is
	# the handler's per-target decision; mutually exclusive with the flat form.
	if not move.status_conditional.is_empty():
		effects.append(ConditionalAfflictionEffect.new())

	# Scheduled effect (Phase 4 — Shriek). Marks the target now, fires later
	# via ScheduledEffects' tick clock.
	if not move.scheduled_effect.is_empty():
		effects.append(ScheduleEffectHandler.new())

	# On-hit cleanse (every hit).
	if not move.cleanse_effects.is_empty():
		effects.append(CleanseEffect.new())

	# On-hit displacement (heals don't displace; support applications MAY —
	# that's how a Roar-knockback style shove would ride a support cast).
	if not ctx.is_heal and move.displace_distance > 0:
		effects.append(DisplaceEffect.new())

	# Passive handlers from both combatants participate in the per-hit phases
	# (damage hits only — matches the old check_passive_triggers_on_hit, which
	# never ran on heals; support applications aren't combat exchanges either).
	# Appended after move effects so passive on-hit triggers (e.g. Bellows) fire
	# after the move's own riders, preserving prior order. Each handler checks
	# ctx for the relevant unit, so adding both sides is safe; dedup keeps a
	# shared passive from firing twice.
	if not ctx.is_heal and not ctx.is_support:
		_append_passives(effects, ctx.attacker)
		_append_passives(effects, ctx.defender)

	return effects


static func _append_passives(effects: Array[CombatEffect], unit: Node2D) -> void:
	if unit == null:
		return
	for handler: CombatEffect in PassiveRegistry.get_handlers_for(unit.get("character_data"), unit):
		if not effects.has(handler):
			effects.append(handler)


## Run the damage-modifier phase. Mutates ctx.damage. No-op in Phase 0 (no
## damage-modifying handlers exist yet); crit hooks in here in Phase 1.
static func run_modify_damage(ctx: CombatHitContext, effects: Array[CombatEffect]) -> void:
	for effect: CombatEffect in effects:
		effect.modify_damage(ctx)


## Run the on-hit phase (afflictions, cleanse, displacement). Awaitable because
## displacement animates.
static func run_on_hit(ctx: CombatHitContext, effects: Array[CombatEffect]) -> void:
	for effect: CombatEffect in effects:
		# Only DisplaceEffect.on_hit is a coroutine; the base/others return
		# synchronously. Await unconditionally so async handlers complete in order.
		@warning_ignore("redundant_await")
		await effect.on_hit(ctx)


## Run the on-kill phase. Call only when the hit defeated the target. Handlers
## react to the kill (e.g. Waste Not refunds the killer's move use); each checks
## ctx for the relevant unit (Waste Not checks ctx.attacker, the killer).
static func run_on_kill(ctx: CombatHitContext, effects: Array[CombatEffect]) -> void:
	for effect: CombatEffect in effects:
		effect.on_kill(ctx)
