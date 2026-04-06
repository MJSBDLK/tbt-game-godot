## Autoload singleton managing status effect application, processing, and removal.
## Registered as "StatusEffectSystem" in project.godot.
## Stateless: operates on units' active_status_effects arrays.
extends Node


signal status_effect_applied(unit: Node2D, effect_type_name: String)
signal status_effect_removed(unit: Node2D, effect_type_name: String)
signal status_damage_dealt(unit: Node2D, damage: int, effect_type_name: String)

var _default_configs: Dictionary = {}


func _ready() -> void:
	_default_configs = StatusEffectData.get_default_configs()
	DebugConfig.log_status("StatusEffectSystem: Loaded %d default configs" % _default_configs.size())


## Apply a status effect from a move to a target unit.
## Rolls against the move's status_effect_chance. Returns true if applied.
func apply_status_effect(caster: Node2D, target: Node2D, move: Move) -> bool:
	if move == null or target == null:
		return false
	if move.status_effect_type == Enums.StatusEffectType.NONE:
		return false
	if move.status_effect_chance <= 0.0:
		return false

	# Roll chance
	var roll := randf()
	if roll > move.status_effect_chance:
		DebugConfig.log_status("StatusEffectSystem: %s missed (roll %.2f > chance %.2f)" % [
			Enums.StatusEffectType.keys()[move.status_effect_type], roll, move.status_effect_chance])
		return false

	var effect_type_name: String = Enums.StatusEffectType.keys()[move.status_effect_type]
	return apply_status_effect_by_name(caster, target, effect_type_name)


## Apply a status effect by name. Returns true if applied.
func apply_status_effect_by_name(caster: Node2D, target: Node2D, effect_type_name: String) -> bool:
	if target == null:
		return false

	var config: StatusEffectData = _default_configs.get(effect_type_name, null)
	if config == null:
		DebugConfig.log_error("StatusEffectSystem: Unknown effect type '%s'" % effect_type_name)
		return false

	var active_effects: Array = target.get("active_status_effects")
	if active_effects == null:
		DebugConfig.log_error("StatusEffectSystem: Target has no active_status_effects")
		return false

	# Stack-based effects (e.g. BELLOWS): increment stacks on existing instance
	if config.max_stacks > 0:
		for existing: StatusEffect in active_effects:
			if existing.effect_type_name == effect_type_name:
				if existing.stacks < existing.max_stacks:
					existing.stacks += 1
					DebugConfig.log_status("StatusEffectSystem: %s stacks -> %d on %s" % [
						effect_type_name, existing.stacks, target.get("unit_name")])
				else:
					DebugConfig.log_status("StatusEffectSystem: %s already at max stacks (%d) on %s" % [
						effect_type_name, existing.max_stacks, target.get("unit_name")])
				status_effect_applied.emit(target, effect_type_name)
				return true
		# No existing instance — create one at 1 stack
		var effect := StatusEffect.new()
		effect.effect_type_name = effect_type_name
		effect.affected_stat = config.affected_stat
		effect.modifier = config.modifier
		effect.remaining_turns = -1  # Stack-based effects don't use turn countdown
		effect.stacks = 1
		effect.max_stacks = config.max_stacks
		active_effects.append(effect)
		DebugConfig.log_status("StatusEffectSystem: Applied %s (1 stack) to %s" % [
			effect_type_name, target.get("unit_name")])
		status_effect_applied.emit(target, effect_type_name)
		return true

	# Check for existing non-stackable effect
	if not config.stackable:
		for existing: StatusEffect in active_effects:
			if existing.effect_type_name == effect_type_name:
				# Refresh duration instead of stacking
				existing.remaining_turns = config.duration
				DebugConfig.log_status("StatusEffectSystem: Refreshed %s on %s" % [
					effect_type_name, target.get("unit_name")])
				return true

	# Create new effect
	var effect := StatusEffect.new()
	effect.effect_type_name = effect_type_name
	effect.affected_stat = config.affected_stat
	effect.modifier = config.modifier
	effect.remaining_turns = config.duration

	var caster_data: Variant = caster.get("character_data") if caster != null else null
	effect.caster_level = caster_data.level if caster_data != null else 1

	# VOID: lock a random move
	if effect_type_name == "VOID":
		var target_data: Variant = target.get("character_data")
		if target_data != null:
			var equipped: Array[Move] = target_data.equipped_moves
			var unlocked_indices: Array[int] = []
			for i: int in range(equipped.size()):
				if not _is_move_locked(active_effects, i):
					unlocked_indices.append(i)
			if unlocked_indices.size() > 0:
				effect.locked_move_index = unlocked_indices[randi() % unlocked_indices.size()]

	active_effects.append(effect)
	_recalculate_stat_modifiers(target)

	DebugConfig.log_status("StatusEffectSystem: Applied %s to %s (duration=%d)" % [
		effect_type_name, target.get("unit_name"), config.duration])
	status_effect_applied.emit(target, effect_type_name)
	return true


## Process all status effects at the start of a unit's turn.
## Deals DoT damage, decrements durations, removes expired effects.
func process_turn_start_effects(unit: Node2D) -> void:
	if unit == null:
		return

	var active_effects: Array = unit.get("active_status_effects")
	if active_effects == null or active_effects.is_empty():
		return

	var effects_to_remove: Array[StatusEffect] = []
	var character_data: Variant = unit.get("character_data")

	for effect: StatusEffect in active_effects:
		var config: StatusEffectData = _default_configs.get(effect.effect_type_name, null)
		if config == null:
			continue

		# Apply DoT damage
		if config.is_dot:
			var dot_damage := _calculate_dot_damage(effect, character_data)
			if dot_damage > 0:
				unit.call("take_damage", dot_damage)
				DebugConfig.log_status("StatusEffectSystem: %s took %d %s damage" % [
					unit.get("unit_name"), dot_damage, effect.effect_type_name])
				status_damage_dealt.emit(unit, dot_damage, effect.effect_type_name)

		# Stack-based effects: lose 1 stack per turn instead of using duration
		if effect.max_stacks > 0:
			effect.stacks -= 1
			if effect.stacks <= 0:
				effects_to_remove.append(effect)
			else:
				DebugConfig.log_status("StatusEffectSystem: %s stacks -> %d on %s" % [
					effect.effect_type_name, effect.stacks, unit.get("unit_name")])
			continue

		# Decrement turns
		effect.remaining_turns -= 1
		if effect.remaining_turns <= 0:
			effects_to_remove.append(effect)

	# Remove expired effects
	for effect: StatusEffect in effects_to_remove:
		active_effects.erase(effect)
		DebugConfig.log_status("StatusEffectSystem: %s expired on %s" % [
			effect.effect_type_name, unit.get("unit_name")])
		status_effect_removed.emit(unit, effect.effect_type_name)

	if effects_to_remove.size() > 0:
		_recalculate_stat_modifiers(unit)


## Check if unit can move (blocked by ROOTED or FREEZE).
func can_unit_move(unit: Node2D) -> bool:
	if unit == null:
		return false
	var active_effects: Array = unit.get("active_status_effects")
	if active_effects == null:
		return true
	for effect: StatusEffect in active_effects:
		if effect.effect_type_name == "ROOTED" or effect.effect_type_name == "FREEZE":
			return false
	return true


## Check if unit can act (blocked by FREEZE).
func can_unit_act(unit: Node2D) -> bool:
	if unit == null:
		return false
	var active_effects: Array = unit.get("active_status_effects")
	if active_effects == null:
		return true
	for effect: StatusEffect in active_effects:
		if effect.effect_type_name == "FREEZE":
			return false
	return true


## Remove all effects of a given type from a unit.
func remove_status_effect(unit: Node2D, effect_type_name: String) -> void:
	if unit == null:
		return
	var active_effects: Array = unit.get("active_status_effects")
	if active_effects == null:
		return

	var to_remove: Array[StatusEffect] = []
	for effect: StatusEffect in active_effects:
		if effect.effect_type_name == effect_type_name:
			to_remove.append(effect)

	for effect: StatusEffect in to_remove:
		active_effects.erase(effect)

	if to_remove.size() > 0:
		_recalculate_stat_modifiers(unit)
		status_effect_removed.emit(unit, effect_type_name)


## Remove all status effects from a unit.
func clear_all_effects(unit: Node2D) -> void:
	if unit == null:
		return
	var active_effects: Array = unit.get("active_status_effects")
	if active_effects == null:
		return
	active_effects.clear()
	_recalculate_stat_modifiers(unit)


## Get the current stack count for a stack-based effect on a unit. Returns 0 if not present.
func get_effect_stacks(unit: Node2D, effect_type_name: String) -> int:
	if unit == null:
		return 0
	var active_effects: Array = unit.get("active_status_effects")
	if active_effects == null:
		return 0
	for effect: StatusEffect in active_effects:
		if effect.effect_type_name == effect_type_name:
			return effect.stacks
	return 0


## Check if a unit has a specific passive equipped.
func _unit_has_passive(unit: Node2D, passive_name: String) -> bool:
	var character_data: Variant = unit.get("character_data")
	if character_data == null:
		return false
	var passives: Array = character_data.get("equipped_passives")
	if passives == null:
		return false
	return passive_name in passives


## Called after a unit takes attack damage. Checks for passive triggers like Bellows.
## Currently only triggers on damaging attacks; non-damaging air moves do not trigger Bellows.
func check_passive_triggers_on_hit(attacker: Node2D, target: Node2D, move: Move) -> void:
	if target == null or move == null:
		return

	# Bellows: air-type attack damage grants fire buff stacks
	if move.element_type == Enums.ElementalType.AIR and _unit_has_passive(target, "Bellows"):
		apply_status_effect_by_name(attacker, target, "BELLOWS")


## Check if a specific move index is locked by VOID.
func is_move_locked(unit: Node2D, move_index: int) -> bool:
	if unit == null:
		return false
	var active_effects: Array = unit.get("active_status_effects")
	if active_effects == null:
		return false
	return _is_move_locked(active_effects, move_index)


# =============================================================================
# PRIVATE HELPERS
# =============================================================================

func _calculate_dot_damage(effect: StatusEffect, character_data: Variant) -> int:
	if character_data == null:
		return 1
	var max_hp: int = character_data.get("max_hp")
	@warning_ignore("integer_division")
	return maxi(1, effect.caster_level + max_hp / 10)


func _recalculate_stat_modifiers(unit: Node2D) -> void:
	var character_data: Variant = unit.get("character_data")
	if character_data == null:
		return

	character_data.reset_status_modifiers()

	var active_effects: Array = unit.get("active_status_effects")
	if active_effects == null:
		return

	for effect: StatusEffect in active_effects:
		if effect.affected_stat == "" or effect.modifier == 0:
			continue
		var stat_field := "status_modifier_%s" % effect.affected_stat
		var current_value: int = character_data.get(stat_field)
		character_data.set(stat_field, current_value + effect.modifier)


func _is_move_locked(active_effects: Array, move_index: int) -> bool:
	for effect: StatusEffect in active_effects:
		if effect.effect_type_name == "VOID" and effect.locked_move_index == move_index:
			return true
	return false
