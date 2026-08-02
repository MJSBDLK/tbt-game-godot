## Applies a move's CONDITIONAL statusEffect on hit: which effect (if any)
## lands depends on a CombatPredicates check against the target. Gathered when
## move.status_conditional is non-empty. (Roar: brave → CHALLENGED, everyone
## else → SHOCKED.)
##
## Mirrors ApplyAfflictionEffect's contract: first hit only (apply_status),
## chance rolled with the caster's luck, application delegated to
## StatusEffectSystem (restack, same-category immunity, indicators). An empty
## branch means those targets get nothing — a legal authoring choice.
class_name ConditionalAfflictionEffect
extends CombatEffect


func on_hit(ctx: CombatHitContext) -> void:
	if not ctx.apply_status:
		return
	var conditional: Dictionary = ctx.move.status_conditional
	if conditional.is_empty():
		return
	# Move-wide immunity is filtered at AoE gathering; this covers the
	# single-target path so an immune unit never takes either branch.
	if not ctx.move.immune_predicate.is_empty() \
			and CombatPredicates.evaluate(ctx.move.immune_predicate, ctx.defender):
		return

	var predicate: String = conditional.get("predicate", "")
	var matched: bool = CombatPredicates.evaluate(predicate, ctx.defender)
	var branch: Dictionary = conditional.get("then" if matched else "else", {})
	if branch.is_empty():
		return

	var chance: float = float(branch.get("chance", 1.0))
	var caster_data: Variant = ctx.attacker.get("character_data") if ctx.attacker != null else null
	var success: bool = caster_data.roll_succeeds(chance) if caster_data != null \
			else GameRng.randf() < chance
	if not success:
		DebugConfig.log_status("ConditionalAffliction: %s missed on %s (chance %.2f)" % [
			branch.get("effect", "?"), ctx.defender.get("unit_name"), chance])
		return

	StatusEffectSystem.apply_status_effect_by_name(
		ctx.attacker, ctx.defender, String(branch.get("effect", "")),
		int(branch.get("stacks", 0)), bool(branch.get("replaces", false)),
		ctx.move.element_type, ctx.move.damage_type)
