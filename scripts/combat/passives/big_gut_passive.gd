## Big Gut passive: a foe that lands a melee hit on the owner bounces off the
## belly, one tile back, unless it's stout enough to hold (a constitution save
## with Bounce Out's margin). It answers once per exchange, after the counters,
## so it never costs the owner its own counter.
##
## An after_attacked handler (PassiveEffectsSystem.notify_attacked). The bounce
## is a displacement move, so it rides the same plan, save, slide and On Duty
## line as any shove.
class_name BigGutPassive
extends CombatEffect


const BOUNCE_TILES: int = 1
const SAVE_MARGIN: int = 1


func after_attacked(unit: Unit, attacker: Unit, _move: Move, presenter: CombatPresenter) -> void:
	if unit.current_tile == null or attacker.current_tile == null:
		return
	var distance := absi(unit.current_tile.grid_x - attacker.current_tile.grid_x) \
			+ absi(unit.current_tile.grid_y - attacker.current_tile.grid_y)
	# Melee only: the attacker has to be touching the belly.
	if distance != 1:
		return
	await DisplacementSystem.resolve(unit, attacker, bounce_move(), presenter)


static func bounce_move() -> Move:
	var move := Move.new()
	move.move_name = "Big Gut"
	move.displace_distance = BOUNCE_TILES
	move.displace_vector = "away_from_attacker"
	move.displace_contest_stat = "constitution"
	move.displace_contest_margin = SAVE_MARGIN
	move.displace_on_blocked = "stop"
	return move
