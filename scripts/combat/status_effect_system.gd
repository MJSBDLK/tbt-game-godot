## Autoload singleton managing status effect application, processing, and removal.
## Registered as "StatusEffectSystem" in project.godot.
## Stateless: operates on units' active_status_effects arrays.
##
## Slot model: each unit may hold ONE buff and ONE debuff at a time.
## Reapplication of the same effect adds stacks (capped at config.max_stacks).
## Application of a different effect in the same category is rejected unless the
## move/caller passes replace_existing = true.
extends Node


signal status_effect_applied(unit: Node2D, effect_type_name: String)
signal status_effect_removed(unit: Node2D, effect_type_name: String)
signal status_damage_dealt(unit: Node2D, damage: int, effect_type_name: String)

var _default_configs: Dictionary = {}


func _ready() -> void:
	_default_configs = StatusEffectData.get_default_configs()
	DebugConfig.log_status("StatusEffectSystem: Loaded %d default configs" % _default_configs.size())


# =============================================================================
# APPLICATION
# =============================================================================

## Apply a status effect from a move. Routes to caster or target depending on
## move.status_effect_self_target. Rolls against move.status_effect_chance.
func apply_status_effect(caster: Node2D, target: Node2D, move: Move) -> bool:
	if move == null:
		return false
	if move.status_effect_type == Enums.StatusEffectType.NONE:
		return false
	if move.status_effect_chance <= 0.0:
		return false

	var actual_target: Node2D = caster if move.status_effect_self_target else target
	if actual_target == null:
		return false

	# Roll chance — the caster is the actor, so use the caster's luck.
	# A cursed caster has a lower probability of successfully landing the status.
	var caster_data: Variant = caster.get("character_data") if caster != null else null
	var success: bool = false
	if caster_data != null:
		success = caster_data.roll_succeeds(move.status_effect_chance)
	else:
		success = randf() < move.status_effect_chance
	if not success:
		DebugConfig.log_status("StatusEffectSystem: %s missed (chance %.2f, luck-adjusted)" % [
			Enums.StatusEffectType.keys()[move.status_effect_type], move.status_effect_chance])
		return false

	var effect_type_name: String = Enums.StatusEffectType.keys()[move.status_effect_type]
	var stacks_to_apply: int = move.status_effect_stacks  # 0 = use config default
	return apply_status_effect_by_name(
		caster, actual_target, effect_type_name, stacks_to_apply,
		move.status_effect_replaces, move.element_type, move.damage_type)


## Apply a status effect by name. Returns true if applied (or successfully restacked).
## stacks_to_apply: 0 = use the effect's default_apply_stacks.
## replace_existing: bypass same-category immunity, removing any active effect of the same category.
## source_element/source_damage_type: stamped onto the StatusEffect for injury attribution
## if a DoT tick from this effect kills the target.
func apply_status_effect_by_name(caster: Node2D, target: Node2D, effect_type_name: String, stacks_to_apply: int = 0, replace_existing: bool = false, source_element: Enums.ElementalType = Enums.ElementalType.NONE, source_damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL) -> bool:
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

	if stacks_to_apply <= 0:
		stacks_to_apply = config.default_apply_stacks

	# Check for an existing effect (same type → restack, same category → immunity check)
	var existing_same_type: StatusEffect = null
	var existing_same_category: StatusEffect = null
	for entry: StatusEffect in active_effects:
		if entry.effect_type_name == effect_type_name:
			existing_same_type = entry
		elif entry.category == config.category:
			existing_same_category = entry

	# Same type already on target — add stacks (capped)
	if existing_same_type != null:
		var before: int = existing_same_type.stacks
		existing_same_type.stacks = mini(existing_same_type.stacks + stacks_to_apply, config.max_stacks)
		_refresh_effect_on_restack(existing_same_type, config, caster, target)
		DebugConfig.log_status("StatusEffectSystem: %s stacks %d → %d on %s" % [
			effect_type_name, before, existing_same_type.stacks, target.get("unit_name")])
		_recalculate_stat_modifiers(target)
		status_effect_applied.emit(target, effect_type_name)
		return true

	# Different effect already in this category — blocked unless replace requested
	if existing_same_category != null:
		if not replace_existing:
			DebugConfig.log_status("StatusEffectSystem: %s blocked on %s (already has %s)" % [
				effect_type_name, target.get("unit_name"), existing_same_category.effect_type_name])
			return false
		# Replace: remove the existing same-category effect
		active_effects.erase(existing_same_category)
		status_effect_removed.emit(target, existing_same_category.effect_type_name)
		DebugConfig.log_status("StatusEffectSystem: %s replaced by %s on %s" % [
			existing_same_category.effect_type_name, effect_type_name, target.get("unit_name")])

	# Create a new effect
	var effect := StatusEffect.new()
	effect.effect_type_name = effect_type_name
	effect.category = config.category
	effect.affected_stat = config.affected_stat
	effect.stacks = mini(stacks_to_apply, config.max_stacks)
	effect.source_element = source_element
	effect.source_damage_type = source_damage_type

	var caster_data: Variant = caster.get("character_data") if caster != null else null
	effect.caster_level = caster_data.level if caster_data != null else 1

	# Cache DoT/HoT values at apply time so future rebalancing doesn't retroactively change them
	if config.dot_damage_per_stack > 0:
		effect.dot_damage_per_tick = _calculate_dot_damage_value(effect.caster_level, target)
	if config.hot_heal_per_stack > 0:
		effect.hot_heal_per_tick = _calculate_dot_damage_value(effect.caster_level, target)

	# VOID: lock random move(s) — one per stack
	if effect_type_name == "VOID":
		_assign_void_locked_moves(effect, target)

	active_effects.append(effect)
	_recalculate_stat_modifiers(target)

	DebugConfig.log_status("StatusEffectSystem: Applied %s (%d stacks) to %s" % [
		effect_type_name, effect.stacks, target.get("unit_name")])
	status_effect_applied.emit(target, effect_type_name)
	return true


# =============================================================================
# TICK PROCESSING
# =============================================================================

## Process all status effects at the start of a unit's turn.
## Deals DoT damage, decrements stacks of turn_start-tick effects, removes empty effects.
func process_turn_start_effects(unit: Node2D) -> void:
	if unit == null:
		return

	var active_effects: Array = unit.get("active_status_effects")
	if active_effects == null or active_effects.is_empty():
		return

	var effects_to_remove: Array[StatusEffect] = []

	for effect: StatusEffect in active_effects:
		var config: StatusEffectData = _default_configs.get(effect.effect_type_name, null)
		if config == null:
			continue
		if config.tick_trigger != "turn_start":
			continue

		# DoT: deal cached per-tick damage before consuming the stack
		if effect.dot_damage_per_tick > 0:
			var source: Dictionary = {
				"element": effect.source_element,
				"damage_type": effect.source_damage_type,
				"name": effect.effect_type_name,
			}
			unit.call("take_damage", effect.dot_damage_per_tick, source)
			DebugConfig.log_status("StatusEffectSystem: %s took %d %s damage" % [
				unit.get("unit_name"), effect.dot_damage_per_tick, effect.effect_type_name])
			status_damage_dealt.emit(unit, effect.dot_damage_per_tick, effect.effect_type_name)

		# HoT: heal before consuming the stack
		if effect.hot_heal_per_tick > 0:
			unit.call("heal", effect.hot_heal_per_tick)
			DebugConfig.log_status("StatusEffectSystem: %s healed %d from %s" % [
				unit.get("unit_name"), effect.hot_heal_per_tick, effect.effect_type_name])

		# Consume one stack
		effect.stacks -= 1
		if effect.stacks <= 0:
			effects_to_remove.append(effect)
		else:
			DebugConfig.log_status("StatusEffectSystem: %s stacks → %d on %s" % [
				effect.effect_type_name, effect.stacks, unit.get("unit_name")])
			# VOID: pop the most recently locked move when stacks drop
			if effect.effect_type_name == "VOID" and effect.locked_move_indices.size() > effect.stacks:
				effect.locked_move_indices.pop_back()

	for effect: StatusEffect in effects_to_remove:
		active_effects.erase(effect)
		DebugConfig.log_status("StatusEffectSystem: %s expired on %s" % [
			effect.effect_type_name, unit.get("unit_name")])
		status_effect_removed.emit(unit, effect.effect_type_name)

	if effects_to_remove.size() > 0:
		_recalculate_stat_modifiers(unit)


# =============================================================================
# QUERIES
# =============================================================================

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


## Get the current stack count for an effect on a unit. Returns 0 if not present.
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


## Get the maximum stack count for an effect type from its config. Returns 0 if unknown.
func get_effect_max_stacks(effect_type_name: String) -> int:
	var config: StatusEffectData = _default_configs.get(effect_type_name, null)
	if config == null:
		return 0
	return config.max_stacks


## Check if a specific move index is locked by VOID.
func is_move_locked(unit: Node2D, move_index: int) -> bool:
	if unit == null:
		return false
	var active_effects: Array = unit.get("active_status_effects")
	if active_effects == null:
		return false
	for effect: StatusEffect in active_effects:
		if effect.effect_type_name == "VOID" and move_index in effect.locked_move_indices:
			return true
	return false


# =============================================================================
# REMOVAL
# =============================================================================

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


# =============================================================================
# PASSIVE TRIGGERS
# =============================================================================

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


# =============================================================================
# PRIVATE HELPERS
# =============================================================================

## Recalculate every status_modifier_* on a unit's character_data using the
## three-pass percentage model:
##   pass 1 (raw_passive) = base + growth + allocated + bond + passive
##   pass 2 (unmodified)  = raw_passive + injury_modifier  (% of raw_passive — handled by InjurySystem)
##   pass 3 (effective)   = unmodified + status_modifier   (% of unmodified — this function)
##
## Buffs/debuffs scale off the unit's already-injured stat (pass 2), so an injured
## unit gets less out of buffs. status_modifier is computed by summing all percentages
## affecting a given stat and then applying that combined % to the unmodified stat.
## Result is rounded toward zero with a minimum magnitude of 1 if the summed % is non-zero.
func _recalculate_stat_modifiers(unit: Node2D) -> void:
	var character_data: Variant = unit.get("character_data")
	if character_data == null:
		return

	character_data.reset_status_modifiers()

	var active_effects: Array = unit.get("active_status_effects")
	if active_effects == null:
		return

	# Sum percentages per affected stat
	var stat_pcts: Dictionary = {}  # stat_name → summed pct
	for effect: StatusEffect in active_effects:
		if effect.affected_stat == "":
			continue
		var config: StatusEffectData = _default_configs.get(effect.effect_type_name, null)
		if config == null or config.pct_per_stack == 0.0:
			continue
		var contribution: float = config.pct_per_stack * effect.stacks
		stat_pcts[effect.affected_stat] = stat_pcts.get(effect.affected_stat, 0.0) + contribution

	# Apply each summed % to the unmodified stat
	for stat_name: String in stat_pcts.keys():
		var pct: float = stat_pcts[stat_name]
		if is_zero_approx(pct):
			continue
		var unmodified: int = character_data.get_unmodified_stat(stat_name)
		var modifier: int = _apply_pct_with_floor(unmodified, pct)
		var field: String = "status_modifier_%s" % stat_name
		character_data.set(field, modifier)


## Apply a percentage to a base value with floor-toward-zero rounding and a
## minimum non-zero magnitude. Used so that small modifiers always have at
## least ±1 effect when applied to a non-zero base.
func _apply_pct_with_floor(base: int, pct: float) -> int:
	if is_zero_approx(pct):
		return 0
	var raw: float = base * (pct / 100.0)
	var magnitude: int = int(floor(absf(raw)))
	if magnitude == 0:
		magnitude = 1
	return magnitude if pct > 0.0 else -magnitude


## Compute DoT per-tick damage from caster level and target HP.
func _calculate_dot_damage_value(caster_level: int, target: Node2D) -> int:
	var character_data: Variant = target.get("character_data") if target != null else null
	if character_data == null:
		return 1
	var max_hp: int = character_data.max_hp
	@warning_ignore("integer_division")
	return maxi(1, caster_level + max_hp / 10)


## On reapplication of an existing effect, refresh runtime values that depend
## on the (possibly newer) caster.
func _refresh_effect_on_restack(effect: StatusEffect, config: StatusEffectData, caster: Node2D, target: Node2D) -> void:
	var caster_data: Variant = caster.get("character_data") if caster != null else null
	if caster_data != null:
		effect.caster_level = caster_data.level
	if config.dot_damage_per_stack > 0:
		effect.dot_damage_per_tick = _calculate_dot_damage_value(effect.caster_level, target)
	if config.hot_heal_per_stack > 0:
		effect.hot_heal_per_tick = _calculate_dot_damage_value(effect.caster_level, target)
	if effect.effect_type_name == "VOID":
		# Top up locked move indices to match new stack count
		_assign_void_locked_moves(effect, target)


## Pick random unlocked move slots equal to (effect.stacks - already locked) and
## append them to effect.locked_move_indices.
func _assign_void_locked_moves(effect: StatusEffect, target: Node2D) -> void:
	var character_data: Variant = target.get("character_data") if target != null else null
	if character_data == null:
		return
	var equipped: Array[Move] = character_data.equipped_moves
	while effect.locked_move_indices.size() < effect.stacks:
		var unlocked: Array[int] = []
		for i: int in range(equipped.size()):
			if i not in effect.locked_move_indices:
				unlocked.append(i)
		if unlocked.is_empty():
			break
		effect.locked_move_indices.append(unlocked[randi() % unlocked.size()])
