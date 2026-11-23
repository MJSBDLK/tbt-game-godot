## Picks ONE of the move's random_payloads per cast and applies it to the target:
## a heal (a share of max HP, through Laceration's reducer) or a status. Gathered
## when move.random_payloads is non-empty. (Rummage: what's in the pack today?)
class_name OneOfEffect
extends CombatEffect


func on_hit(ctx: CombatHitContext) -> void:
	if not ctx.apply_status or ctx.defender == null:
		return
	var payload: Dictionary = GameRng.pick_random(ctx.move.random_payloads)
	assert(payload.has("heal_pct") or payload.has("effect"), "OneOfEffect: payload with nothing in it")
	if payload.has("heal_pct"):
		var data: CharacterData = ctx.defender.get("character_data")
		var amount: int = maxi(1, int(floor(data.max_hp * float(payload["heal_pct"]))))
		amount = DamageCalculator.apply_healing_reduction(ctx.defender, amount)
		ctx.defender.heal(amount)
		if ctx.presenter != null:
			ctx.presenter.show_heal(ctx.attacker, ctx.defender, amount)
	else:
		StatusEffectSystem.apply_status_effect_by_name(ctx.attacker, ctx.defender,
				String(payload["effect"]), int(payload.get("stacks", 0)))
	DebugConfig.log_combat("OneOf: %s drew %s for %s" % [
		ctx.attacker.get("unit_name"), payload, ctx.defender.get("unit_name")])
