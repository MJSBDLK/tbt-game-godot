## Resolves on-hit displacement (knockback/pull) via DisplacementSystem. Gathered
## for damage hits (not heals) when move.displace_distance > 0. Awaitable — the
## push tween runs to completion before the next hit. Thin wrapper for now; the
## displacement subsystem itself gets generalized in Phase 3.
class_name DisplaceEffect
extends CombatEffect


func on_hit(ctx: CombatHitContext) -> void:
	await DisplacementSystem.resolve(ctx.attacker, ctx.defender, ctx.move, ctx.damage)
