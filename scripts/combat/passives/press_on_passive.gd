## Press On passive: not used to killing, so a downed foe leaves this unit in
## shock; the reckoning comes later, and for now there's still danger. Dropping
## a foe gives it FORTIFIED for a turn (one stack: +10% defense, at least +1).
##
## An on_kill handler (CombatEffectPipeline.run_on_kill). Gated on the killer,
## ctx.attacker, which is the counter-attacker when a counter does the deed.
class_name PressOnPassive
extends CombatEffect


const FORTIFIED_STACKS: int = 1


func on_kill(ctx: CombatHitContext) -> void:
	if ctx.attacker == null:
		return
	var data: Variant = ctx.attacker.get("character_data")
	if data != null and data.has_equipped_passive("Press On"):
		StatusEffectSystem.apply_status_effect_by_name(ctx.attacker, ctx.attacker,
				"FORTIFIED", FORTIFIED_STACKS)
