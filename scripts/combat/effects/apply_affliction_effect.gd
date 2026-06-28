## Applies a move's `statusEffect` (affliction or boost) on hit. Gathered when
## move.status_effect_type != NONE.
##
## Mirrors the old inline block in Unit._execute_single_hit: applies on the first
## hit only (apply_status), and delegates to StatusEffectSystem.apply_status_effect
## which owns the chance roll, self-vs-target routing (status_effect_self_target),
## restack, and same-category immunity.
class_name ApplyAfflictionEffect
extends CombatEffect


func on_hit(ctx: CombatHitContext) -> void:
	if not ctx.apply_status:
		return
	if ctx.move.status_effect_type == Enums.StatusEffectType.NONE:
		return
	StatusEffectSystem.apply_status_effect(ctx.attacker, ctx.defender, ctx.move)
