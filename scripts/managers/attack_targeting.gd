## Attack targeting: who the chosen move can hit, and what the forecast shows
## for a tile. InputManager owns the session (start, cancel, swing) and its
## wiring to the UI, the board cursor and the state machine; this holds the
## session's state and its rules, the way BoardCursor holds the cursor's.
class_name AttackTargeting
extends RefCounted


## What a tap does while targeting on touch (target_tap).
enum TargetTap { ARM, ATTACK, CANCEL }
## What the forecast shows for a tile (forecast_for).
enum Forecast { NONE, ATTACK, HEAL, SUPPORT }

var attacker: Unit = null
var move: Move = null
## The tiles holding someone the move can hit.
var tiles: Array[Tile] = []
## Touch only: the target a first tap armed; a second tap on it attacks.
var armed_tile: Tile = null


func is_active() -> bool:
	return attacker != null and move != null


func begin(attacking_unit: Unit, chosen_move: Move) -> void:
	attacker = attacking_unit
	move = chosen_move
	tiles = MoveTargeting.get_valid_target_tiles(attacking_unit, chosen_move)
	armed_tile = null


func end() -> void:
	attacker = null
	move = null
	tiles = []
	armed_tile = null


## A tile holding a unit the move can hit.
func is_target_tile(tile: Tile) -> bool:
	if not is_active() or tile == null or not tiles.has(tile) or tile.current_unit is not Unit:
		return false
	return MoveTargeting.is_valid_target(tile.current_unit as Unit, attacker, move)


## Touch has no hover to show the forecast before the press, so the tap that
## picks a target can't also be the one that attacks: the first tap on a
## target ARMs it (forecast up), a second tap on the armed target ATTACKs, a
## tap on another target re-arms, and a tap off the targets CANCELs, as a
## click would.
static func target_tap(armed: Tile, tapped: Tile, tapped_is_target: bool) -> TargetTap:
	if not tapped_is_target:
		return TargetTap.CANCEL
	return TargetTap.ATTACK if tapped == armed else TargetTap.ARM


## A touch tap on `tile`; an ARM remembers the tile.
func tap(tile: Tile) -> TargetTap:
	var result := target_tap(armed_tile, tile, is_target_tile(tile))
	if result == TargetTap.ARM:
		armed_tile = tile
	return result


## What the forecast panel shows for `tile`: {kind, target, heal_amount}.
## ATTACK names the unit the shot will actually hit: a Protector between the
## attacker and the aimed-at enemy body-blocks, so it's the one previewed.
## SUPPORT (an ally move that doesn't heal) has no preview yet.
func forecast_for(tile: Tile) -> Dictionary:
	if not is_target_tile(tile):
		return {kind = Forecast.NONE}
	var target := tile.current_unit as Unit
	if move.heals:
		return {kind = Forecast.HEAL, target = target,
				heal_amount = DamageCalculator.calculate_heal_amount(attacker, target, move)}
	if move.targets_allies():
		return {kind = Forecast.SUPPORT}
	return {kind = Forecast.ATTACK,
			target = MoveTargeting.resolve_actual_target(attacker, target, move)}
