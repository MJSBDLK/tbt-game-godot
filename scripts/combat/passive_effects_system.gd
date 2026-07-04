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
##   • Unit.unit_defeated — one fewer ally; recompute.
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


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_player_phase_started(_turn_count: int) -> void:
	recompute_all()


func _on_unit_movement_completed(_unit: Unit) -> void:
	recompute_all()


func _on_unit_defeated(_unit: Unit) -> void:
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
			_zero_passive_bonuses(unit.character_data)
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


func _is_live(unit: Unit) -> bool:
	return unit != null and not unit.is_defeated() and unit.character_data != null


func _zero_passive_bonuses(data: CharacterData) -> void:
	data.passive_bonus_hp = 0
	data.passive_bonus_strength = 0
	data.passive_bonus_special = 0
	data.passive_bonus_skill = 0
	data.passive_bonus_agility = 0
	data.passive_bonus_athleticism = 0
	data.passive_bonus_defense = 0
	data.passive_bonus_resistance = 0
	data.passive_bonus_avoid = 0
	data.maximum_from_aura = false


# Stat-aura passives (Competitive, Glib, and future Stellar / Zone Control) live as
# CombatEffect handlers with an apply_stat_aura hook. recompute_faction dispatches
# to them in two passes; this system owns the zero + the recompute triggers.
