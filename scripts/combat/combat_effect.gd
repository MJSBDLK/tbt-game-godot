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
##   Targeting   — extra_attack_range, from MoveTargeting.effective_attack_range
##                 (additive range bonus; tiles past base range need a clear reach
##                 via GridGeometry.reach_is_clear). (Extendo.)
##   Redirect    — intercepts_attack, from MoveTargeting.resolve_actual_target
##                 (a unit between attacker and target body-blocks the hit). The
##                 resolver does the geometry/faction pre-filter. (Protector.)
##   Statuses    — lightens_debuffs / deepens_buffs, from StatusEffectSystem.
##                 apply_status_effect_by_name (debuffs land a stack lighter,
##                 buffs a stack heavier, on the owner). (Hardy, Grateful.)
##   Crits       — prevents_crits, from CritEffect.modify_damage on the defender. (Wary.)
##   Terrain     — terrain_cost_relief, from GridManager._scaled_tile_cost, which
##                 every movement range, route and path cost goes through. (Pathfinder.)
##   Ally falls  — on_ally_defeated, from PassiveEffectsSystem.notify_defeated_by,
##                 which Unit._execute_single_hit calls after a killing hit; runs
##                 for every live unit on the fallen's side. (Grudge.)
##   Own fall    — on_defeated, from PassiveEffectsSystem on Unit.unit_defeated:
##                 any cause of death, while the fallen still holds its tile.
##                 (Dead Weight.)
##   Exchange    — after_attacked, from PassiveEffectsSystem.notify_attacked, once
##                 per exchange after the counters, when the attacker landed a hit
##                 and both still stand. Awaitable. (Big Gut.)
##   Hit count   — prevents_bonus_hits, from DamageCalculator.calculate_attack_count
##                 on the defender's passives. (Thick Skin.) extra_volley_hits,
##                 from DamageCalculator.volley_hits on the attacker's, for a
##                 multi-hit move. (Outburst.)
##   Movement    — exerts_zone_of_control (Stonewall) and leash_tiles (On Duty),
##                 from GridManager's movement range and pathfinding; leash_tiles
##                 also from GridManager.displacement_allows, which every
##                 DisplacementSystem resolver asks. extra_move_tiles, from
##                 Unit.max_movement_range. (Panic.)
##   Move slots  — locks_move, from Unit.is_move_index_locked: the menu greys
##                 the move with the lock scrim and nothing can use it. (Panic.)
##   Foe walks   — on_foe_walked_away, from PassiveEffectsSystem.notify_walked on
##                 Unit.path_traversed (a committed walk): a foe that started next
##                 to the owner ended its walk out of reach. (Tag Along.)
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


## Fear cluster: does this passive make its owner count as brave (challenged by
## Roar, immune to Shriek) without being Chivalric-typed? Queried by
## CombatPredicates.is_brave — never check this directly. (Bravery.)
func grants_bravery() -> bool:
	return false


## Crits: can hits on this passive's owner never crit? Queried by CritEffect on the
## DEFENDER's passives; a banked crit stays banked for the next target. (Wary.)
func prevents_crits() -> bool:
	return false


## Pathfinding: tiles off this many from any terrain cost above 1 (never below 1).
## Queried by GridManager._scaled_tile_cost on the mover's passives. (Pathfinder.)
func terrain_cost_relief() -> float:
	return 0.0


## Statuses: do debuffs land on this passive's owner one stack lighter (never
## below one)? Queried by StatusEffectSystem.apply_status_effect_by_name on the
## target's passives. (Hardy.)
func lightens_debuffs() -> bool:
	return false


## Statuses: do buffs land on this passive's owner one stack heavier (up to the
## buff's cap)? Queried with lightens_debuffs. (Grateful.)
func deepens_buffs() -> bool:
	return false


## Ally falls: `fallen`, on `unit`'s side, was just defeated by `killer`'s hit.
## Dispatched per live ally of the fallen by PassiveEffectsSystem.notify_defeated_by.
## Kills by DoT, scheduled strikes and collisions have no killer and don't fire.
## (Grudge.)
func on_ally_defeated(_unit: Unit, _fallen: Unit, _killer: Unit) -> void:
	pass


## Own fall: `unit`, this passive's owner, was just defeated by any cause. It
## still holds its tile, so handlers can look at its neighbors. (Dead Weight.)
func on_defeated(_unit: Unit) -> void:
	pass


## Exchange over: `attacker` landed at least one hit on `unit` (this passive's
## owner) with `move`, the counters are done, and both still stand. May be a
## coroutine; the dispatcher awaits it. (Big Gut.)
func after_attacked(_unit: Unit, _attacker: Unit, _move: Move, _presenter: CombatPresenter) -> void:
	pass


## Hit count: do foes get only one hit on this passive's owner per attack,
## whatever their athleticism lead? (Thick Skin.)
func prevents_bonus_hits() -> bool:
	return false


## Hit count: extra hits `attacker` (this passive's owner) lands with `move`,
## a multi-hit move, this swing. (Outburst.)
func extra_volley_hits(_attacker: Node2D, _move: Move) -> int:
	return 0


## Movement: extra tiles `unit` (this passive's owner) may walk this turn,
## read live, so it follows HP. (Panic.)
func extra_move_tiles(_unit: Unit) -> int:
	return 0


## Move slots: is `move` unusable for `unit` (this passive's owner) right now?
## (Panic.)
func locks_move(_unit: Unit, _move: Move) -> bool:
	return false


## Foe walks: `foe` started its committed walk on `left_tile`, next to `unit`
## (this passive's owner), and ended it out of reach. (Tag Along.)
func on_foe_walked_away(_unit: Unit, _foe: Unit, _left_tile: Tile) -> void:
	pass


## Movement: does a foe that steps next to this passive's owner have to stop
## there? (Stonewall.)
func exerts_zone_of_control() -> bool:
	return false


## Movement: how many tiles from where its turn began the owner may end up,
## walking or displaced. -1 = no limit. (On Duty.)
func leash_tiles() -> int:
	return -1


## Targeting: extra attack range (additive) this passive grants its owner for the
## given move. Gathered from the ATTACKER's passives by
## MoveTargeting.effective_attack_range. Tiles beyond the move's base range are
## only legal with an unobstructed reach (GridGeometry.reach_is_clear) — extended
## reach can't cross terrain impassable for the attacker. (Extendo: +1 physical.)
func extra_attack_range(_move: Move) -> int:
	return 0


## Targeting redirect: should `interceptor` body-block an attack aimed at someone
## else? Queried by MoveTargeting.resolve_actual_target only on units that already
## sit strictly between attacker and the intended target on a compass axis AND are
## allies of the target (the geometric + faction + offensive pre-filter lives in
## the resolver), so a handler just decides its own extra conditions. Return true
## to take the hit instead of the target. (Protector: unconditional.)
func intercepts_attack(_interceptor: Unit, _attacker: Unit, _target: Unit, _move: Move) -> bool:
	return false
