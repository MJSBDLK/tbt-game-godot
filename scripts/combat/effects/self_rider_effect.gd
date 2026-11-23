## The user takes a status of its own on hit, next to whatever the move does
## to the target: Arm Twist roots the target AND the user. Gathered when
## move.self_rider is set; first hit only (ctx.apply_status), like afflictions.
class_name SelfRiderEffect
extends CombatEffect


func on_hit(ctx: CombatHitContext) -> void:
	if not ctx.apply_status or ctx.attacker == null or ctx.move.self_rider.is_empty():
		return
	if ctx.attacker.has_method("is_defeated") and ctx.attacker.is_defeated():
		return
	StatusEffectSystem.apply_status_effect_by_name(ctx.attacker, ctx.attacker,
			String(ctx.move.self_rider["effect"]), int(ctx.move.self_rider.get("stacks", 0)))
