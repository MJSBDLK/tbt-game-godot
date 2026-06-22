## Base class for a single combat effect handler. Subclasses override only the
## phase hooks they care about; the rest stay no-ops.
##
## This is the shared substrate for the whole move/passive rework (see
## .claude/todo.md "Combat Effect Pipeline"): move-effects, passives, and
## afflictions all become CombatEffect handlers gathered into one pipeline.
## Phase 0 only invokes modify_damage + on_hit; the other hooks are declared
## now so later phases (crit, passives, displacement) drop in without touching
## the dispatcher's shape.
class_name CombatEffect
extends RefCounted


## Adjust hit chance before the to-hit roll. (Reserved — not yet invoked.)
func modify_accuracy(_ctx: CombatHitContext) -> void:
	pass


## Adjust outgoing damage after base calc, before the hit lands. Mutate
## `ctx.damage`. (Crit lands here in Phase 1.)
func modify_damage(_ctx: CombatHitContext) -> void:
	pass


## Apply rider effects after damage/heal lands (afflictions, cleanse,
## displacement, ...). May be a coroutine — the dispatcher awaits it.
func on_hit(_ctx: CombatHitContext) -> void:
	pass


## Rider effects targeting the caster specifically. (Reserved — Phase 0 routes
## self-target afflictions through on_hit via StatusEffectSystem's own routing.)
func on_hit_self(_ctx: CombatHitContext) -> void:
	pass


## Fires when this hit defeats the target. (Reserved — Waste Not, etc.)
func on_kill(_ctx: CombatHitContext) -> void:
	pass
