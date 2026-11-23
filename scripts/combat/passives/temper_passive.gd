## Temper passive: a miss stings. The swing after one hits 20% harder but is 15
## points less accurate, so the frustration can win the fight or blow it.
##
## modify_accuracy + modify_damage (no wiring). Reads Unit.missed_last_swing,
## which Unit._execute_single_hit sets on every miss and clears on every landed
## hit, counters included. The flag outlives the turn: a miss on the enemy's
## phase still sours the next swing.
class_name TemperPassive
extends CombatEffect


const DAMAGE_BONUS_PCT: float = 20.0
const ACCURACY_PENALTY: int = 15


func modify_accuracy(ctx: CombatHitContext) -> void:
	if _is_tempered(ctx.attacker):
		ctx.accuracy -= ACCURACY_PENALTY


func modify_damage(ctx: CombatHitContext) -> void:
	if _is_tempered(ctx.attacker):
		ctx.damage = maxi(1, roundi(ctx.damage * (1.0 + DAMAGE_BONUS_PCT / 100.0)))


func _is_tempered(attacker: Node2D) -> bool:
	if attacker == null or not bool(attacker.get("missed_last_swing")):
		return false
	var data: Variant = attacker.get("character_data")
	return data != null and data.has_equipped_passive("Temper")
