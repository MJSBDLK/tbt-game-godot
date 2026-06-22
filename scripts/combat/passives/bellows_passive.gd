## Bellows passive: a unit that takes AIR-type attack damage gains a stack of the
## BELLOWS boost (+fire damage). Defender-reactive — fires on the unit being hit.
##
## Migrated from StatusEffectSystem.check_passive_triggers_on_hit. Behavior is
## identical: every air-damage hit grants the hit unit (if it carries Bellows) a
## BELLOWS stack via the default application. Checks ctx.defender for the passive
## (not "my owner"), so it's correct regardless of which combatant's gather added
## it, and dedup keeps it from double-firing when both carry it.
class_name BellowsPassive
extends CombatEffect


func on_hit(ctx: CombatHitContext) -> void:
	if ctx.move == null or ctx.move.element_type != Enums.ElementalType.AIR:
		return
	var defender: Node2D = ctx.defender
	if defender == null:
		return
	var data: Variant = defender.get("character_data")
	if data == null or not data.has_equipped_passive("Bellows"):
		return
	StatusEffectSystem.apply_status_effect_by_name(ctx.attacker, defender, "BELLOWS")
