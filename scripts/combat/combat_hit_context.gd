## Mutable per-hit context threaded through the combat effect pipeline.
## One instance is built per landed hit (see Unit._execute_single_hit /
## _execute_heal_hit), populated, then passed to each CombatEffect handler.
##
## modify_damage handlers mutate `damage`; on_hit handlers read the finalized
## `damage` and apply riders (afflictions, cleanse, displacement). `base_damage`
## is preserved so handlers can reason about pre-modifier damage if needed.
class_name CombatHitContext
extends RefCounted


# Combatants. attacker is the caster; defender is the move's target (which may be
# an ally, or the caster itself for self-target support moves).
var attacker: Node2D = null
var defender: Node2D = null
var move: Move = null

# Damage. base_damage = DamageCalculator output; damage = after modify_damage
# handlers (crit, etc.). Equal in Phase 0 (no damage modifiers yet).
var base_damage: int = 0
var damage: int = 0

# Set by a crit modify_damage handler (Phase 1) so feedback/popups can react.
var is_crit: bool = false

# True only on a combat's first hit (and the first counter). Afflictions apply
# on the first hit only; cleanse + displacement run every hit. Mirrors the old
# `apply_status` parameter on _execute_single_hit.
var apply_status: bool = true

# Heal hits skip displacement. Set by _execute_heal_hit.
var is_heal: bool = false
