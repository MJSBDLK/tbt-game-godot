## Base class for a combat effect handler — the shared substrate for the whole
## move/passive system. Move effects, passives, and (eventually) afflictions are
## all CombatEffect subclasses. A subclass overrides only the hooks it needs;
## the rest stay no-ops. THIS HEADER IS THE LIVING MAP of the system — start here.
##
## WHERE EACH HOOK FIRES (the key thing: hooks run at DIFFERENT dispatch points,
## not all in one loop):
##
##   Per-hit combat — CombatEffectPipeline.gather() collects a hit's handlers
##   (the move's own effects + BOTH combatants' passives) and runs:
##     • modify_accuracy   dispatched from DamageCalculator.hit_chance_pct
##                         (so the combat preview shows the same number)
##     • modify_damage     CombatEffectPipeline.run_modify_damage  (crit, ...)
##     • on_hit/on_hit_self CombatEffectPipeline.run_on_hit  (afflictions,
##                         cleanse, displacement, Bellows, ...)
##     • on_kill           (reserved — Waste Not, etc.)
##   Stat auras  — apply_stat_aura, from PassiveEffectsSystem.recompute
##                 (fires on turn start / movement / defeat).
##   Pathfinding — passes_through_units, from GridManager._tile_blocks_passage.
##
## OWNER RULE: per-hit, gather() pools the move's effects AND both combatants'
## passive handlers (deduped by identity), so a passive handler can't assume it's
## "the attacker's" — it checks ctx for the unit it cares about (Bellows checks
## ctx.defender, Reliable checks ctx.attacker). Aura/pathfinding hooks are
## dispatched per-owner, so those act on the unit passed in directly.
##
## WHERE THINGS LIVE: move-effect handlers in scripts/combat/effects/, passive
## handlers in scripts/combat/passives/ (resolved by name via PassiveRegistry).
## Per-hit state rides on CombatHitContext; handlers are STATELESS shared
## singletons — never store per-hit state on them.
##
## TYPING: per-hit hooks take Node2D (duck-typed, matching DamageCalculator /
## DisplacementSystem); apply_stat_aura takes Unit (the aura dispatch works with
## live Units).
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


## Stat aura: write passive_bonus_* onto the unit's CharacterData based on
## battlefield state (ally positions, etc.). Dispatched from
## PassiveEffectsSystem.recompute (turn/move/defeat), NOT the per-hit pipeline —
## bonuses are zeroed before each recompute, so handlers just add. Typed as Unit
## (the aura dispatch works with live Units) unlike the Node2D-duck-typed per-hit
## hooks. (Competitive now; Stellar / Zone Control to follow.)
func apply_stat_aura(_unit: Unit, _faction_units: Array[Unit]) -> void:
	pass


## Turn-start effect: one-shot actions at the start of the unit's faction phase
## (heal, clear a debuff, ...). Dispatched from TurnManager._process_passive_turn_start.
## `allies` is the unit's faction list (for passives that affect nearby allies,
## e.g. Jury Rig). Distinct from apply_stat_aura, which only writes stat bonuses.
func on_turn_start(_unit: Unit, _allies: Array[Unit]) -> void:
	pass


## Pathfinding: does this passive let its owner move THROUGH enemy-occupied tiles?
## Queried by GridManager._tile_blocks_passage on the mover's own passives. (Ghost.)
func passes_through_units() -> bool:
	return false


## Move selection: does this passive re-randomize the unit's move each combat
## (avoiding back-to-back repeats)? Queried by EnemyAI (turn move-pick) and
## Unit (post-combat reroll); the selection logic lives there. (Capricious.)
func randomizes_move() -> bool:
	return false
