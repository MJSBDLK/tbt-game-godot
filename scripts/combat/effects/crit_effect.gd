## Resolves crit for a hit. Crit is a one-time damage doubling, NOT a status.
##
## Two behaviors, distinguished by the move's crit_self_target flag:
##   - Self-target (Focus, Uppercut): on_hit BANKS a crit on the caster
##     (pending_crit) for their next attack. Doesn't affect this hit.
##   - Otherwise: modify_damage crits THIS hit, either by consuming a banked
##     pending_crit or by rolling the move's secondary crit_chance.
##
## Gathered for damage hits (not heals) when the move has crit_chance > 0 or the
## attacker is carrying a banked pending_crit. See CombatEffectPipeline.gather.
class_name CritEffect
extends CombatEffect


func modify_damage(ctx: CombatHitContext) -> void:
	# Banking moves don't crit their own hit — they bank in on_hit instead.
	if ctx.move.crit_self_target:
		return

	var attacker: Node2D = ctx.attacker
	var should_crit: bool = false

	# A banked crit fires on the next DAMAGING hit, then clears. Gating on
	# base_power > 0 keeps a zero-power move from wasting the banked crit.
	if attacker != null and bool(attacker.get("pending_crit")) and ctx.move.base_power > 0:
		should_crit = true
		attacker.set("pending_crit", false)
	# Otherwise roll the move's secondary crit (first hit only, like afflictions).
	elif ctx.apply_status and ctx.move.crit_chance > 0.0:
		should_crit = GameRng.randf() < ctx.move.crit_chance

	if should_crit:
		ctx.damage = roundi(ctx.damage * DamageCalculator.CRIT_MULTIPLIER)
		ctx.is_crit = true


func on_hit(ctx: CombatHitContext) -> void:
	# Bank a crit on the caster for their next attack (self-target setup moves).
	if not ctx.move.crit_self_target:
		return
	if not ctx.apply_status:
		return
	if ctx.move.crit_chance <= 0.0:
		return
	if GameRng.randf() < ctx.move.crit_chance and ctx.attacker != null:
		ctx.attacker.set("pending_crit", true)
