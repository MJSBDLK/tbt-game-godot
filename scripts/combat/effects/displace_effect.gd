## Resolves on-hit displacement (the knockback/pull/shove/spin family) via
## DisplacementSystem. Gathered for damage hits (not heals) when
## move.displace_distance > 0. Awaitable — push tweens run to completion before
## the next hit. The full schema (subjects, shapes, vectors, contest saves,
## blocked policies) is documented in displacement_system.gd's header.
class_name DisplaceEffect
extends CombatEffect


func on_hit(ctx: CombatHitContext) -> void:
	await DisplacementSystem.resolve(ctx.attacker, ctx.defender, ctx.move, ctx.presenter)
