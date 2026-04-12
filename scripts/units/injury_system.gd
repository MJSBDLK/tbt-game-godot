## Autoload singleton managing the injury lifecycle:
##   1. Unit dies mid-mission → queue an injury onto its character_data.pending_injuries
##   2. Mission ends → commit pending injuries, tick recovery on all units, free expired
##   3. Recompute injury_modifier_* fields on character_data so the stat getters reflect penalties
##
## Severity is calculated from `last_damage_overkill` on the unit at the time of death.
## Same-type immunity (unit element matches killing source element) reduces the severity by one tier;
## a Minor that's been immunity-reduced is dropped entirely.
##
## Registered as "InjurySystem" in project.godot.
extends Node


signal injury_queued(character_data: CharacterData, injury: Injury)
signal injury_committed(character_data: CharacterData, injury: Injury)
signal injury_expired(character_data: CharacterData, injury: Injury)
signal unit_permadead(character_data: CharacterData)


# =============================================================================
# QUEUE (mid-mission)
# =============================================================================

## Called when a unit dies during a mission. Looks up the appropriate injury,
## calculates severity from overkill, applies same-type immunity, and queues
## the result on the unit's character_data. Returns the queued Injury, or null
## if no injury was assigned (e.g. immunity dropped a Minor).
func queue_injury_from_death(unit: Node2D) -> Injury:
	if unit == null:
		return null
	var character_data: CharacterData = unit.get("character_data")
	if character_data == null:
		return null

	var source: Dictionary = unit.get("last_killing_source")
	if source.is_empty():
		DebugConfig.log_status("InjurySystem: %s died without a killing source — no injury assigned" % unit.get("unit_name"))
		return null

	var element: Enums.ElementalType = source.get("element", Enums.ElementalType.NONE)
	var damage_type: Enums.DamageType = source.get("damage_type", Enums.DamageType.PHYSICAL)
	var data: InjuryData = InjuryDatabase.lookup(element, damage_type)
	if data == null:
		DebugConfig.log_status("InjurySystem: No injury defined for (%s, %s)" % [
			Enums.ElementalType.keys()[element], Enums.DamageType.keys()[damage_type]])
		return null

	# Calculate severity from overkill
	var overkill: int = unit.get("last_damage_overkill")
	var max_hp: int = character_data.max_hp
	var overkill_pct: float = float(overkill) / float(max(1, max_hp))
	var severity: Enums.InjurySeverity = Enums.InjurySeverity.MINOR
	if overkill_pct > 0.25:
		severity = Enums.InjurySeverity.MAJOR

	# Same-type immunity: if the unit shares an elemental type with the killing source,
	# reduce severity by one tier. A Minor reduced past Minor becomes nothing.
	# Uses effective types so a Crystallized unit loses its immunity along with its type.
	var unit_has_type: bool = (
		character_data.effective_primary_type() == element or
		character_data.effective_secondary_type() == element
	)
	if unit_has_type:
		match severity:
			Enums.InjurySeverity.MAJOR:
				severity = Enums.InjurySeverity.MINOR
				DebugConfig.log_status("InjurySystem: %s has %s immunity — Major reduced to Minor" % [
					unit.get("unit_name"), Enums.ElementalType.keys()[element]])
			Enums.InjurySeverity.MINOR:
				DebugConfig.log_status("InjurySystem: %s has %s immunity — Minor injury shrugged off" % [
					unit.get("unit_name"), Enums.ElementalType.keys()[element]])
				return null

	# Build the injury instance
	var injury := Injury.new()
	injury.injury_id = data.injury_id
	injury.severity = severity
	injury.battles_remaining = data.major_recovery_battles if severity == Enums.InjurySeverity.MAJOR else data.minor_recovery_battles

	character_data.pending_injuries.append(injury)
	DebugConfig.log_status("InjurySystem: Queued %s (%s) on %s — overkill=%d/%d (%.0f%%)" % [
		data.display_name, Enums.InjurySeverity.keys()[severity], unit.get("unit_name"),
		overkill, max_hp, overkill_pct * 100.0])
	injury_queued.emit(character_data, injury)
	return injury


# =============================================================================
# COMMIT (mission end)
# =============================================================================

## Commits all pending injuries on a single character to current_injuries,
## checking the slot cap. If accepting any pending injury would push total
## slots over MAX_INJURY_SLOTS, the unit is permadead and the function returns false.
func commit_pending_injuries(character_data: CharacterData) -> bool:
	if character_data == null:
		return true
	if character_data.pending_injuries.is_empty():
		return true

	for injury: Injury in character_data.pending_injuries:
		if not character_data.can_accept_injury(injury.slots_occupied()):
			DebugConfig.log_status("InjurySystem: %s permadead — cannot fit %s injury (slots %d/%d)" % [
				character_data.character_name, injury.injury_id,
				character_data.injury_slots_used() + injury.slots_occupied(),
				character_data.MAX_INJURY_SLOTS])
			unit_permadead.emit(character_data)
			return false
		character_data.current_injuries.append(injury)
		injury_committed.emit(character_data, injury)
		DebugConfig.log_status("InjurySystem: Committed %s (%s) on %s" % [
			injury.injury_id, Enums.InjurySeverity.keys()[injury.severity], character_data.character_name])

	character_data.pending_injuries.clear()
	recalculate_injury_modifiers(character_data)
	return true


# =============================================================================
# TICK (mission end, all units regardless of participation)
# =============================================================================

# =============================================================================
# PER-TURN PROCESSING (mid-mission)
# =============================================================================

## Called at the start of a unit's turn (player or enemy phase). Rolls
## per-turn injury effects: PTSD (skip turn), Bends (lock random moves).
## FRIENDLY_FIRE (Corruption) is rolled per-attack inside execute_combat_sequence,
## not here, because it needs to know about the intended target.
func process_turn_start(unit: Node2D, _turn_index_in_battle: int) -> void:
	if unit == null:
		return
	var character_data: CharacterData = unit.get("character_data")
	if character_data == null:
		return
	if character_data.current_injuries.is_empty():
		return

	# Reset per-turn flags before re-applying.
	unit.set("injury_locked_move_indices", [])

	for injury: Injury in character_data.current_injuries:
		var data: InjuryData = injury.get_data()
		if data == null:
			continue
		var mag: float = injury.magnitude()
		match data.mechanic:
			Enums.InjuryMechanic.TURN_SKIP_CHANCE:
				# PTSD — chance to lose this turn entirely
				if randf() * 100.0 < mag:
					unit.set("can_act", false)
					DebugConfig.log_status("InjurySystem: %s skipped turn from PTSD" % unit.get("unit_name"))
			Enums.InjuryMechanic.MOVE_LOCK:
				# Bends — lock N random move slots for this turn
				_lock_random_move_slots(unit, character_data, int(mag))


func _lock_random_move_slots(unit: Node2D, character_data: CharacterData, count: int) -> void:
	var equipped: Array[Move] = character_data.equipped_moves
	if equipped.is_empty():
		return
	var indices: Array[int] = []
	for i: int in range(equipped.size()):
		indices.append(i)
	indices.shuffle()
	var locked: Array[int] = []
	for i: int in range(mini(count, indices.size())):
		locked.append(indices[i])
	unit.set("injury_locked_move_indices", locked)
	DebugConfig.log_status("InjurySystem: %s locked move slots %s from Bends" % [unit.get("unit_name"), locked])


## Decrements battles_remaining on every active injury for the given character_data.
## Removes any injury that hits 0. Recalculates injury_modifier_* afterwards.
func tick_recovery(character_data: CharacterData) -> void:
	if character_data == null:
		return
	if character_data.current_injuries.is_empty():
		return

	var expired: Array[Injury] = []
	for injury: Injury in character_data.current_injuries:
		injury.battles_remaining -= 1
		if injury.battles_remaining <= 0:
			expired.append(injury)

	for injury: Injury in expired:
		character_data.current_injuries.erase(injury)
		injury_expired.emit(character_data, injury)
		DebugConfig.log_status("InjurySystem: %s recovered from %s" % [
			character_data.character_name, injury.injury_id])

	if expired.size() > 0:
		recalculate_injury_modifiers(character_data)


# =============================================================================
# STAT RECALCULATION
# =============================================================================

## Computes injury_modifier_* fields on character_data based on its current injuries.
## Mirrors the StatusEffectSystem._recalculate_stat_modifiers algorithm but uses
## raw_passive_stat as the base (so injuries scale off the unit's natural capability).
func recalculate_injury_modifiers(character_data: CharacterData) -> void:
	if character_data == null:
		return

	character_data.reset_injury_modifiers()

	# Sum percentages per affected stat across all stat-pct injuries
	var stat_pcts: Dictionary = {}  # stat_name → summed pct
	var luck_total: float = 0.0
	var healing_total: float = 0.0

	for injury: Injury in character_data.current_injuries:
		var data: InjuryData = injury.get_data()
		if data == null:
			continue
		var mag: float = injury.magnitude()
		match data.mechanic:
			Enums.InjuryMechanic.STAT_PCT:
				if data.affected_stat != "":
					stat_pcts[data.affected_stat] = stat_pcts.get(data.affected_stat, 0.0) - mag
			Enums.InjuryMechanic.MAX_HP_PCT:
				stat_pcts["max_hp"] = stat_pcts.get("max_hp", 0.0) - mag
			Enums.InjuryMechanic.LUCK_PCT:
				luck_total += mag
			Enums.InjuryMechanic.HEALING_REDUCED:
				healing_total += mag
			# Other mechanics (MOVE_DISTANCE, MOVE_LOCK, TURN_SKIP_CHANCE, FACTION_FLIP,
			# HIDE_HEALTH, REMOVE_TYPE) don't contribute to stat modifiers — they're
			# applied at their respective code sites.
			_:
				pass

	# Apply each summed % to the raw passive stat
	for stat_name: String in stat_pcts.keys():
		var pct: float = stat_pcts[stat_name]
		if is_zero_approx(pct):
			continue
		var raw: int = character_data.get_raw_passive_stat(stat_name)
		var modifier: int = _apply_pct_with_floor(raw, pct)
		var field: String = "injury_modifier_%s" % stat_name
		character_data.set(field, modifier)

	# Cache aggregate luck and healing-reduction values
	character_data.luck_penalty_pct = clampf(luck_total, 0.0, 100.0)
	character_data.healing_reduction_pct = clampf(healing_total, 0.0, 99.0)


# =============================================================================
# HELPERS
# =============================================================================

## Apply a percentage to a base value with floor-toward-zero rounding and a
## minimum non-zero magnitude. Mirrors StatusEffectSystem._apply_pct_with_floor.
func _apply_pct_with_floor(base: int, pct: float) -> int:
	if is_zero_approx(pct):
		return 0
	var raw: float = base * (pct / 100.0)
	var magnitude: int = int(floor(absf(raw)))
	if magnitude == 0:
		magnitude = 1
	return magnitude if pct > 0.0 else -magnitude
