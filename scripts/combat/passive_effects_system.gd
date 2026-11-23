## Computes per-turn / per-move passive bonuses that depend on battlefield
## state (positions, ally compositions, etc.) and writes them into each
## CharacterData's `passive_bonus_*` fields. The stat getters on
## CharacterData already sum `passive_bonus_*` into the final stat, so any
## downstream reader (UI, combat resolver) sees the updated value with no
## extra wiring.
##
## Dispatches to stat-aura passive handlers (CombatEffect.apply_stat_aura) each
## recompute — e.g. Competitive (+3 to an ally's highest stat within 3 tiles).
## This system owns the zero-then-recompute orchestration and the triggers; the
## per-passive logic lives in the handlers (see CompetitivePassive).
##
## Triggers a recompute on:
##   • TurnManager.player_phase_started — covers buff/debuff turn ticks,
##     respawns, anything that mutates roster state between turns.
##   • Unit.movement_completed — positions changed; recompute.
##   • Unit.unit_defeated — one fewer ally; recompute (after the fallen's own
##     on_defeated passives, notify_fallen).
##   • Unit.path_traversed — a committed walk; foes it left behind react
##     (notify_walked: Tag Along), then recompute.
##
## Registered as autoload "PassiveEffectsSystem" in project.godot. Wires up
## per-unit signals via TurnManager.initialize_battle (which fires before
## the first phase signal).
extends Node


func _ready() -> void:
	# TurnManager loads after this script (autoload order), so defer the
	# connect until both nodes exist.
	call_deferred("_connect_turn_manager")


func _connect_turn_manager() -> void:
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager == null:
		push_warning("PassiveEffectsSystem: TurnManager not found")
		return
	if not turn_manager.player_phase_started.is_connected(_on_player_phase_started):
		turn_manager.player_phase_started.connect(_on_player_phase_started)


# =============================================================================
# UNIT WIRING
# =============================================================================

## Called by BattleScene after units spawn. Connects per-unit signals so we
## recompute on movement / defeat. Also runs an initial recompute so the
## opening turn has correct passive bonuses before the first phase signal.
func register_battle_units(player_units: Array[Unit], enemy_units: Array[Unit]) -> void:
	for unit: Unit in player_units:
		_connect_unit_signals(unit)
	for unit: Unit in enemy_units:
		_connect_unit_signals(unit)
	recompute_all()


func _connect_unit_signals(unit: Unit) -> void:
	if unit == null:
		return
	if not unit.movement_completed.is_connected(_on_unit_movement_completed):
		unit.movement_completed.connect(_on_unit_movement_completed)
	if not unit.unit_defeated.is_connected(_on_unit_defeated):
		unit.unit_defeated.connect(_on_unit_defeated)
	if not unit.path_traversed.is_connected(notify_walked):
		unit.path_traversed.connect(notify_walked)


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_player_phase_started(_turn_count: int) -> void:
	recompute_all()


func _on_unit_movement_completed(_unit: Unit) -> void:
	recompute_all()


func _on_unit_defeated(unit: Unit) -> void:
	notify_fallen(unit)
	recompute_all()


# =============================================================================
# RECOMPUTE
# =============================================================================

## Walks every unit currently tracked by TurnManager and recomputes its
## passive bonuses from scratch. Cheap at typical squad sizes (≤8 units),
## and the from-scratch model means we don't have to track per-passive
## additivity rules.
func recompute_all() -> void:
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager == null:
		return
	recompute_faction(turn_manager.get_player_units())
	recompute_faction(turn_manager.get_enemy_units())


## Recompute stat auras for one faction in TWO passes: zero EVERY unit first, then
## apply every unit's auras. The two-pass split is required because auras may write
## to OTHER units (Glib boosts/penalizes allies; Stellar grants Maximum to allies)
## — a single interleaved zero+apply would clobber an emitter's write when its
## target is zeroed later in the loop. Auras that only write to self (Competitive)
## work fine either way. Also the public entry point used by tests.
func recompute_faction(units: Array[Unit]) -> void:
	for unit: Unit in units:
		if _is_live(unit):
			unit.character_data.reset_passive_bonuses()
	for unit: Unit in units:
		if _is_live(unit):
			for handler: CombatEffect in PassiveRegistry.get_handlers_for(unit.character_data, unit):
				handler.apply_stat_aura(unit, units)
	# Auras may have changed Maximum protection (Stellar grants it by proximity),
	# so recompute status stat modifiers — the Maximum clamp reads the fresh flags.
	var status_system: Node = get_node_or_null("/root/StatusEffectSystem")
	if status_system != null:
		for unit: Unit in units:
			if _is_live(unit):
				status_system.recalculate_stat_modifiers(unit)


## A hit by `killer` just defeated `fallen`: every live unit on the fallen's side
## gets its passives' on_ally_defeated (Grudge). Called by Unit._execute_single_hit
## while the fallen still holds its tile, so handlers can measure distance to it.
func notify_defeated_by(fallen: Unit, killer: Unit) -> void:
	assert(fallen != null and fallen.is_defeated(), "notify_defeated_by: the fallen unit must be defeated")
	for unit: Unit in _every_unit():
		if unit == fallen or not _is_live(unit) or unit.faction != fallen.faction:
			continue
		for handler: CombatEffect in PassiveRegistry.get_handlers_for(unit.character_data, unit):
			handler.on_ally_defeated(unit, fallen, killer)


## `unit` just fell, by any cause: its own passives get on_defeated (Dead Weight).
## Runs on Unit.unit_defeated, which take_damage emits before _handle_defeat
## clears the tile.
func notify_fallen(unit: Unit) -> void:
	if unit == null or unit.character_data == null:
		return
	assert(unit.is_defeated(), "notify_fallen: %s is still standing" % unit.unit_name)
	for handler: CombatEffect in PassiveRegistry.get_handlers_for(unit.character_data, unit):
		handler.on_defeated(unit)


## `attacker` landed at least one hit on `defender` this exchange, the counters
## are done and both still stand: the defender's passives get after_attacked
## (Big Gut). Called once per exchange by Unit._run_offensive_exchange.
func notify_attacked(defender: Unit, attacker: Unit, move: Move, presenter: CombatPresenter) -> void:
	assert(defender != null and attacker != null, "notify_attacked: both combatants required")
	assert(not defender.is_defeated() and not attacker.is_defeated(),
			"notify_attacked: only an exchange both survived gets an answer")
	for handler: CombatEffect in PassiveRegistry.get_handlers_for(defender.character_data, defender):
		@warning_ignore("redundant_await")
		await handler.after_attacked(defender, attacker, move, presenter)


## `mover` committed a walk that started on `tiles[0]` (Unit.path_traversed,
## fired by set_acted): every live foe that stood next to that start and
## isn't next to the mover now gets on_foe_walked_away (Tag Along). Positions
## may change, so auras recompute after.
func notify_walked(mover: Unit, tiles: Array) -> void:
	if mover == null or mover.is_defeated() or mover.current_tile == null or tiles.size() < 2:
		return
	var left_tile: Tile = tiles[0]
	assert(left_tile != null, "notify_walked: the walk has no start tile")
	for unit: Unit in _every_unit():
		if not _is_live(unit) or unit.faction == mover.faction or unit.current_tile == null:
			continue
		if _tile_distance(unit.current_tile, left_tile) != 1 \
				or _tile_distance(unit.current_tile, mover.current_tile) <= 1:
			continue
		for handler: CombatEffect in PassiveRegistry.get_handlers_for(unit.character_data, unit):
			handler.on_foe_walked_away(unit, mover, left_tile)
	recompute_all()


## Both sides' units as TurnManager tracks them; empty outside a battle.
func _every_unit() -> Array[Unit]:
	var everyone: Array[Unit] = []
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager != null:
		everyone.append_array(turn_manager.get_player_units())
		everyone.append_array(turn_manager.get_enemy_units())
	return everyone


static func _tile_distance(from: Tile, to: Tile) -> int:
	return absi(from.grid_x - to.grid_x) + absi(from.grid_y - to.grid_y)


func _is_live(unit: Unit) -> bool:
	return unit != null and not unit.is_defeated() and unit.character_data != null


# Stat-aura passives (Competitive, Glib, and future Stellar / Zone Control) live as
# CombatEffect handlers with an apply_stat_aura hook. recompute_faction dispatches
# to them in two passes; this system owns the zero + the recompute triggers.
