## Queues a move's `scheduled_effect` on hit (Shriek of the Damned's delayed
## chain-lightning mark). Gathered when move.scheduled_effect is non-empty.
## First hit only (apply_status) — a multi-hit move marks once. The heavy
## lifting (marker status, queue entry, tick clock) lives in ScheduledEffects.
class_name ScheduleEffectHandler
extends CombatEffect


func on_hit(ctx: CombatHitContext) -> void:
	if not ctx.apply_status:
		return
	if ctx.move.scheduled_effect.is_empty():
		return
	# AoE gathering already filtered immune units; this covers single-target
	# casts of a scheduling move so immunity holds on every path.
	if not ctx.move.immune_predicate.is_empty() \
			and CombatPredicates.evaluate(ctx.move.immune_predicate, ctx.defender):
		return
	ScheduledEffects.schedule(ctx.attacker, ctx.defender, ctx.move)
