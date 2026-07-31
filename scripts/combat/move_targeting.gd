## Single source of truth for "what tiles/units can this move target?".
## Both the action menu (which moves to surface) and the input manager (which
## tiles to highlight + accept clicks on during targeting mode) call into here.
##
## Drift between these two filters is how the "First Aid hidden from menu" and
## "can't target self with First Aid" bugs both snuck in. New targeting rules
## (range modifiers, line-of-sight, AOE, terrain gates) all land here.
class_name MoveTargeting
extends RefCounted


## Returns true if `target` is a legal AND meaningful recipient of `move` cast
## by `attacker`. Faction + self filter is enforced first; then the move is
## asked whether it would actually do anything to this target (heals on full-HP
## allies, buffs at max stacks, and cleanses with nothing to strip all fail
## here). Both the menu chip filter and the in-targeting tile filter share this
## predicate, so the menu and the highlighted tiles always agree.
static func is_valid_target(target: Unit, attacker: Unit, move: Move) -> bool:
	if target == null or attacker == null or move == null:
		return false
	if target.is_defeated():
		return false
	if move.targets_allies():
		if target.faction != attacker.faction:
			return false
		if move.target_type == Enums.TargetType.ALLY_NOT_SELF and target == attacker:
			return false
	else:
		if target.faction == attacker.faction:
			return false
	return move.has_meaningful_effect_on(target)


## Returns every tile within `move`'s effective range whose occupant is a valid,
## reachable target. Self-targetable moves (ALLY, SELF) include the attacker's
## own tile, which the grid range helper otherwise excludes.
static func get_valid_target_tiles(attacker: Unit, move: Move) -> Array[Tile]:
	var tiles: Array[Tile] = []
	if attacker == null or move == null or attacker.current_tile == null:
		return tiles

	var candidates := GridManager.get_tiles_within_range(attacker.current_tile, effective_attack_range(attacker, move))
	if move.target_type == Enums.TargetType.ALLY or move.target_type == Enums.TargetType.SELF:
		candidates.append(attacker.current_tile)

	for tile: Tile in candidates:
		if tile.current_unit == null or not tile.current_unit is Unit:
			continue
		var target := tile.current_unit as Unit
		if can_target(attacker, target, move):
			tiles.append(tile)
	return tiles


## Every tile within the move's effective reach from where the attacker stands —
## the range FOOTPRINT itself, regardless of who (if anyone) occupies it. This
## is the grid live-paint truth: while a move chip holds the menu cursor's
## attention, the board shows where that move could land ("the chip is a
## mnemonic, the board is the truth"). Geometry matches can_target exactly:
## Manhattan ball of effective range, the attacker's own tile only for
## self-targetable moves, and tiles past the move's base range (Extendo's bonus
## reach) only where the forgiving reach is clear.
static func get_reach_tiles(attacker: Unit, move: Move) -> Array[Tile]:
	var tiles: Array[Tile] = []
	if attacker == null or move == null or attacker.current_tile == null:
		return tiles

	var from: Tile = attacker.current_tile
	var unit_type := GridManager.get_unit_type(attacker)
	for tile: Tile in GridManager.get_tiles_within_range(from, effective_attack_range(attacker, move)):
		var distance := absi(from.grid_x - tile.grid_x) + absi(from.grid_y - tile.grid_y)
		if distance > move.attack_range and not is_reach_clear(from, tile, unit_type):
			continue
		tiles.append(tile)
	if move.target_type == Enums.TargetType.ALLY or move.target_type == Enums.TargetType.SELF:
		tiles.append(from)
	return tiles


## The move's attack range including the attacker's passive range bonuses
## (Extendo). Single source of truth so the menu, highlights, AI, click shortcut,
## and counters all agree. Tiles gained beyond move.attack_range are only legal
## with a clear reach — see can_target. Typed Node2D so combat-side callers
## (DamageCalculator.can_counter_attack) can pass their duck-typed combatants.
static func effective_attack_range(attacker: Node2D, move: Move) -> int:
	if move == null:
		return 0
	var total := move.attack_range
	if attacker != null:
		var data: Variant = attacker.get("character_data")
		for handler: CombatEffect in PassiveRegistry.get_handlers_for(data, attacker):
			total += handler.extra_attack_range(move)
	return total


## True if `attacker` can legally fire `move` at `target` from where it stands: a
## valid recipient (faction/self/meaningful effect), within effective range, and —
## for tiles past the move's base range (Extendo's reach) — with an unobstructed
## path that doesn't cross terrain impassable for the attacker's type. The single
## predicate behind the menu, highlights, AI, and the click-to-attack shortcut.
static func can_target(attacker: Unit, target: Unit, move: Move) -> bool:
	if not is_valid_target(target, attacker, move):
		return false
	if attacker.current_tile == null or target.current_tile == null:
		return false
	var distance := absi(attacker.current_tile.grid_x - target.current_tile.grid_x) \
			+ absi(attacker.current_tile.grid_y - target.current_tile.grid_y)
	if distance > effective_attack_range(attacker, move):
		return false
	# Base range behaves exactly as before; only the bonus reach needs LoS, so
	# non-range-passive units are unaffected.
	if distance > move.attack_range:
		if not is_reach_clear(attacker.current_tile, target.current_tile, GridManager.get_unit_type(attacker)):
			return false
	return true


## The unit an attack actually lands on. If a ranged offensive shot from
## `attacker` at `intended` passes over an ally of `intended` that body-blocks
## (Protector), the NEAREST such bodyguard takes the hit instead. Returns
## `intended` unchanged for ally-targeting/non-single moves, off-axis shots, or
## adjacency (no cell between = nothing to block — which is why this is naturally
## "ranged only"). Called from Unit.execute_combat_sequence (covers player + AI
## execution in one place) and the combat preview, so both always agree.
static func resolve_actual_target(attacker: Unit, intended: Unit, move: Move) -> Unit:
	if attacker == null or intended == null or move == null:
		return intended
	# Only offensive single-target attacks redirect; healing/buffing never does.
	if move.targets_allies() or move.target_type != Enums.TargetType.SINGLE:
		return intended
	if intended.faction == attacker.faction:
		return intended
	if attacker.current_tile == null or intended.current_tile == null:
		return intended

	var from := Vector2i(attacker.current_tile.grid_x, attacker.current_tile.grid_y)
	var to := Vector2i(intended.current_tile.grid_x, intended.current_tile.grid_y)
	# cells_between_on_axis is ordered from the cell next to the attacker, so the
	# first qualifying bodyguard is the nearest one — the body the shot hits first.
	for cell: Vector2i in GridGeometry.cells_between_on_axis(from, to):
		var tile := GridManager.get_tile(cell.x, cell.y)
		if tile == null or tile.current_unit == null or not tile.current_unit is Unit:
			continue
		var blocker := tile.current_unit as Unit
		# Allies-only: a bodyguard shields its own faction (the intended target's).
		if blocker.is_defeated() or blocker.faction != intended.faction:
			continue
		if _intercepts(blocker, attacker, intended, move):
			return blocker
	return intended


## Does any of `blocker`'s passives elect to intercept this attack? The resolver
## has already confirmed `blocker` is a between, non-defeated ally of the target
## on an offensive single-target shot; the handler adds its own conditions.
static func _intercepts(blocker: Unit, attacker: Unit, target: Unit, move: Move) -> bool:
	for handler: CombatEffect in PassiveRegistry.get_handlers_for(blocker.character_data, blocker):
		if handler.intercepts_attack(blocker, attacker, target, move):
			return true
	return false


## Extended-reach line check: can a poke from `from_tile` get to `to_tile`
## without crossing terrain impassable for `unit_type`? Units in the way do NOT
## block (the reach goes over them) — only terrain does (the design call from the
## LoS explorer). Forgiving "reach-around" rule via GridGeometry.reach_is_clear.
static func is_reach_clear(from_tile: Tile, to_tile: Tile, unit_type: String) -> bool:
	if from_tile == null or to_tile == null:
		return false
	var from := Vector2i(from_tile.grid_x, from_tile.grid_y)
	var to := Vector2i(to_tile.grid_x, to_tile.grid_y)
	var is_blocked := func(cell: Vector2i) -> bool:
		var tile := GridManager.get_tile(cell.x, cell.y)
		return tile == null or not tile.can_unit_move_to(unit_type)
	return GridGeometry.reach_is_clear(from, to, is_blocked)
