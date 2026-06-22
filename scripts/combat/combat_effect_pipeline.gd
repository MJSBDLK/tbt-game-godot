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

	# Affliction/boost rider (applies on first hit only; the handler gates on
	# ctx.apply_status). Self-vs-target routing is inside apply_status_effect.
	if move.status_effect_type != Enums.StatusEffectType.NONE:
		effects.append(ApplyAfflictionEffect.new())

	# On-hit cleanse (every hit).
	if not move.cleanse_effects.is_empty():
		effects.append(CleanseEffect.new())

	# On-hit displacement (damage hits only — heals don't displace).
	if not ctx.is_heal and move.displace_distance > 0:
		effects.append(DisplaceEffect.new())

	return effects


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
