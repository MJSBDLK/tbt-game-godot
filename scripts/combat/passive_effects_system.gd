## Computes per-turn / per-move passive bonuses that depend on battlefield
## state (positions, ally compositions, etc.) and writes them into each
## CharacterData's `passive_bonus_*` fields. The stat getters on
## CharacterData already sum `passive_bonus_*` into the final stat, so any
## downstream reader (UI, combat resolver) sees the updated value with no
## extra wiring.
##
## Currently implements:
##   • Competitive — +3 to whichever stat is the highest single value among
##     allied units within 3 Manhattan tiles. Encourages running Max next
##     to your strongest unit so he "tries to keep up."
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


# Stats Competitive can boost. HP intentionally excluded — narratively a
# competitive personality copies offensive/defensive stats, not vitality;
# mechanically a +3 HP bump on a comparative passive is too lifesteal-y.
const _COMPARABLE_STATS: Array[String] = [
	"strength", "special", "skill", "agility",
	"athleticism", "defense", "resistance",
]
const _COMPETITIVE_RANGE: int = 3
const _COMPETITIVE_BONUS: int = 3


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
	var players: Array[Unit] = turn_manager.get_player_units()
	var enemies: Array[Unit] = turn_manager.get_enemy_units()

	for unit: Unit in players:
		_recompute_unit(unit, players)
	for unit: Unit in enemies:
		_recompute_unit(unit, enemies)


func _recompute_unit(unit: Unit, faction_units: Array[Unit]) -> void:
	if unit == null or unit.is_defeated() or unit.character_data == null:
		return
	var data: CharacterData = unit.character_data
	_zero_passive_bonuses(data)
	if data.has_equipped_passive("Competitive"):
		_apply_competitive(unit, data, faction_units)


func _zero_passive_bonuses(data: CharacterData) -> void:
	data.passive_bonus_hp = 0
	data.passive_bonus_strength = 0
	data.passive_bonus_special = 0
	data.passive_bonus_skill = 0
	data.passive_bonus_agility = 0
	data.passive_bonus_athleticism = 0
	data.passive_bonus_defense = 0
	data.passive_bonus_resistance = 0


# =============================================================================
# COMPETITIVE
# =============================================================================

## Finds the single highest stat value among allies within range and grants
## +_COMPETITIVE_BONUS to that stat. Ties broken by the order of
## _COMPARABLE_STATS — first stat encountered wins. Self is excluded; if
## no allies are in range, no bonus is applied.
func _apply_competitive(unit: Unit, data: CharacterData, faction_units: Array[Unit]) -> void:
	if unit.current_tile == null:
		return
	var nearby: Array[Unit] = _allies_within_range(
		unit, faction_units, _COMPETITIVE_RANGE)
	if nearby.is_empty():
		return

	var best_stat_name: String = ""
	var best_value: int = -1
	for stat_name: String in _COMPARABLE_STATS:
		for ally: Unit in nearby:
			var value: int = _read_stat(ally.character_data, stat_name)
			if value > best_value:
				best_value = value
				best_stat_name = stat_name

	if best_stat_name == "":
		return
	_add_passive_bonus(data, best_stat_name, _COMPETITIVE_BONUS)


func _allies_within_range(unit: Unit, faction_units: Array[Unit], range_tiles: int) -> Array[Unit]:
	var out: Array[Unit] = []
	if unit.current_tile == null:
		return out
	var origin_x: int = unit.current_tile.grid_x
	var origin_y: int = unit.current_tile.grid_y
	for ally: Unit in faction_units:
		if ally == null or ally == unit or ally.is_defeated():
			continue
		if ally.current_tile == null:
			continue
		var dx: int = absi(ally.current_tile.grid_x - origin_x)
		var dy: int = absi(ally.current_tile.grid_y - origin_y)
		if dx + dy <= range_tiles:
			out.append(ally)
	return out


func _read_stat(data: CharacterData, stat_name: String) -> int:
	# Read through the public getters so we see the ally's *current* stat
	# (including their own passive bonuses, status modifiers, etc.). Avoids
	# a feedback loop because Competitive doesn't read max_hp.
	match stat_name:
		"strength": return data.strength
		"special": return data.special
		"skill": return data.skill
		"agility": return data.agility
		"athleticism": return data.athleticism
		"defense": return data.defense
		"resistance": return data.resistance
		_: return 0


func _add_passive_bonus(data: CharacterData, stat_name: String, amount: int) -> void:
	match stat_name:
		"strength": data.passive_bonus_strength += amount
		"special": data.passive_bonus_special += amount
		"skill": data.passive_bonus_skill += amount
		"agility": data.passive_bonus_agility += amount
		"athleticism": data.passive_bonus_athleticism += amount
		"defense": data.passive_bonus_defense += amount
		"resistance": data.passive_bonus_resistance += amount
