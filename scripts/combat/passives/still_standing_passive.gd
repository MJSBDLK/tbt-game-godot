## Still Standing passive: from full HP, a hit that would drop the owner leaves
## it at 1 HP instead. Chip it first, then land the big hit; a foe's bonus hits
## are chip too.
##
## A defender modify_damage handler. Defender passives run last in the pipeline,
## so it sees the crit-doubled damage.
class_name StillStandingPassive
extends CombatEffect


func modify_damage(ctx: CombatHitContext) -> void:
	var defender: Node2D = ctx.defender
	if defender == null:
		return
	var data: Variant = defender.get("character_data")
	if data == null or not data.has_equipped_passive("Still Standing"):
		return
	var hp: int = int(defender.get("current_hp"))
	if hp < data.max_hp or ctx.damage < hp:
		return
	ctx.damage = hp - 1
	# Shown as the swing starts: the cause has to be on screen before the
	# killing blow fails to kill.
	if ctx.presenter != null:
		ctx.presenter.callout(defender, "STILL STANDING", GameColors.TEXT_SECONDARY)
