## Impetuous passive: hits hard out of the gate, then tires. +20% damage on the
## unit's first move use of the turn, -10% for each use after (linear: +20, +10,
## 0, -10, ...). An "attack" = one move use (per RQD), so a multi-hit move's hits
## all share the same tier; the falloff applies across separate move uses in a turn.
##
## A modify_damage handler (no wiring needed). Attacker-side; reads
## Unit.attacks_this_turn, which is bumped per initiated combat and reset each
## turn refresh. Counters don't increment it, so they sit at the unit's last tier.
class_name ImpetuousPassive
extends CombatEffect


const FIRST_BONUS_PCT: float = 20.0
const FALLOFF_PCT: float = 10.0


func modify_damage(ctx: CombatHitContext) -> void:
	var attacker: Node2D = ctx.attacker
	if attacker == null:
		return
	var data: Variant = attacker.get("character_data")
	if data == null or not data.has_equipped_passive("Impetuous"):
		return

	# attacks_this_turn includes the current move use (bumped at combat start), so
	# use #1 → 0 prior → +20%, use #2 → +10%, etc.
	var prior_uses: int = maxi(0, int(attacker.get("attacks_this_turn")) - 1)
	var bonus_pct: float = FIRST_BONUS_PCT - FALLOFF_PCT * prior_uses
	if is_equal_approx(bonus_pct, 0.0):
		return
	ctx.damage = maxi(1, roundi(ctx.damage * (1.0 + bonus_pct / 100.0)))
