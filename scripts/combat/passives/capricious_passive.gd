## Capricious passive: can't use the same move twice in a row — re-randomizes the
## unit's assigned move (from its remaining usable moves) each combat. A capability
## flag; the actual pick logic lives at the two call sites that need it (EnemyAI's
## per-turn move assignment and Unit's post-combat reroll), since both are tied to
## those systems' internals (usable/locked moves, last_used_move_index). Migrated
## from the inline has_equipped_passive("Capricious") checks.
class_name CapriciousPassive
extends CombatEffect


func randomizes_move() -> bool:
	return true
