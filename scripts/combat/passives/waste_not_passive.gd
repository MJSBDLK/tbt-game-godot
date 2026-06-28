## Waste Not passive: defeating an enemy refunds the use the killing move just
## spent — so finishing a kill is "free" PP. Attacker-side; fires only when the
## hit defeated the target (run_on_kill is gated on that), and gates on the
## killer (ctx.attacker) carrying Waste Not.
##
## An on_kill handler. The refund is capped at the move's max_uses by Move.refund_use.
class_name WasteNotPassive
extends CombatEffect


func on_kill(ctx: CombatHitContext) -> void:
	if ctx.attacker == null or ctx.move == null:
		return
	var data: Variant = ctx.attacker.get("character_data")
	if data != null and data.has_equipped_passive("Waste Not"):
		ctx.move.refund_use()
