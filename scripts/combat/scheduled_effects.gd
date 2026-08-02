## Delayed combat effects (Phase 4): "something happens N turns after the hit."
## THIS HEADER IS THE LIVING DOC for the scheduled-effect model.
##
## MODEL: a move with a `scheduled_effect` (JSON onHit.scheduled — schema on
## Move) doesn't resolve its payload at hit time. Instead schedule() stamps a
## visible MARKER status on the victim (the telegraph) and appends a pending
## entry to the victim's own `scheduled_effects` queue:
##   { "faction": int,          # the CASTER's faction — the tick clock
##     "turns_remaining": int,
##     "effect": String,        # handler name, e.g. "chain_lightning_strike"
##     "marker": String,        # the telegraph status (UPPER), "" = none
##     "immune": String,        # CombatPredicates name splash victims are checked
##                              #   against (primary victims were filtered at cast)
##     "params": Dictionary,    # handler knobs (power, splashPct, ...)
##     "source_name": String }  # caster's name at cast time, for logs/callouts
##
## TICK CLOCK: entries tick at the start of the CASTER's faction phase
## (TurnManager calls tick_faction_phase). An enemy Shriek cast during enemy
## phase T therefore fires at the start of enemy phase T+1 — the player gets
## exactly one full turn to react (spread out, cleanse the mark). The queue
## rides on the VICTIM (it's the victim's fate, survives the caster's death)
## but the CLOCK belongs to the caster's side.
##
## DEFUSING: if the entry has a marker and the victim no longer carries that
## status when the strike fires (cleansed, or replaced via a replaces-move),
## the entry fizzles silently — cleansing the mark IS the counterplay. The
## marker also occupies the victim's one debuff slot, so an already-afflicted
## unit can't be marked at all (schedule() returns false and queues nothing).
##
## SAVES: entries are plain data — SaveManager serializes the queue per unit
## verbatim and re-coerces ints on restore. No live references anywhere.
##
## Handlers: chain_lightning_strike — flat params.power damage to the marked
## unit (raw, like DoT ticks — telegraphed damage should be readable, not
## stat-mitigated), then splashPct% (rounded up) to each orthogonally adjacent
## unit regardless of faction — clustering is the risk, spreading out is the
## counterplay. Splash skips units matching entry.immune ("brave" for Shriek:
## the brave are passed over entirely, mark and splash both).
class_name ScheduledEffects
extends RefCounted


const EFFECT_CHAIN_LIGHTNING := "chain_lightning_strike"
const KNOWN_EFFECTS: PackedStringArray = [EFFECT_CHAIN_LIGHTNING]

## Read beat between the strike callout and the damage, mirroring the
## CORRUPTION / OUT OF RANGE convention: name the cause, then show the effect.
const CALLOUT_READ_SECONDS := 0.4


## Queue `move`'s scheduled effect from `caster` onto `target`. Returns true if
## the entry was queued. False = nothing pending: unknown handler name (warned —
## an authoring typo must not silently vanish), or the marker status failed to
## land (debuff slot occupied → the mark can't take hold).
static func schedule(caster: Node2D, target: Node2D, move: Move) -> bool:
	var spec: Dictionary = move.scheduled_effect
	if spec.is_empty() or target == null:
		return false
	var effect_name: String = String(spec.get("effect", ""))
	if effect_name not in KNOWN_EFFECTS:
		push_warning("ScheduledEffects: move '%s' schedules unknown effect '%s'" % [
			move.move_name, effect_name])
		return false

	var marker: String = String(spec.get("marker", ""))
	if not marker.is_empty():
		var marked: bool = StatusEffectSystem.apply_status_effect_by_name(
			caster, target, marker, 0, false, move.element_type, move.damage_type)
		if not marked:
			return false

	var queue: Variant = target.get("scheduled_effects")
	if queue == null:
		push_warning("ScheduledEffects: target '%s' has no scheduled_effects queue" % [
			target.get("unit_name")])
		return false
	queue.append({
		"faction": int(caster.get("faction")) if caster != null else int(Enums.UnitFaction.ENEMY),
		"turns_remaining": int(spec.get("delay", 1)),
		"effect": effect_name,
		"marker": marker,
		"immune": move.immune_predicate,
		"params": (spec.get("params", {}) as Dictionary).duplicate(true),
		"source_name": String(caster.get("unit_name")) if caster != null else "",
	})
	DebugConfig.log_status("ScheduledEffects: %s queued on %s (fires in %d)" % [
		effect_name, target.get("unit_name"), int(spec.get("delay", 1))])
	return true


## Tick every entry cast by `faction` across ALL live units, firing the ones
## that reach zero. Called by TurnManager at that faction's phase start.
## Await-able: strikes animate (callout beat, defeat handling).
static func tick_faction_phase(faction: Enums.UnitFaction, units: Array[Unit]) -> void:
	for unit: Unit in units.duplicate():
		if unit == null or not is_instance_valid(unit) or unit.is_defeated():
			continue
		# Iterate a snapshot; entries are removed from the live queue on fire.
		for entry: Dictionary in unit.scheduled_effects.duplicate():
			if int(entry.get("faction", -1)) != faction:
				continue
			entry["turns_remaining"] = int(entry.get("turns_remaining", 1)) - 1
			if int(entry["turns_remaining"]) > 0:
				continue
			unit.scheduled_effects.erase(entry)
			await _fire(unit, entry)
			if unit.is_defeated():
				break


static func _fire(unit: Unit, entry: Dictionary) -> void:
	match String(entry.get("effect", "")):
		EFFECT_CHAIN_LIGHTNING:
			await _fire_chain_lightning(unit, entry)
		var unknown:
			push_warning("ScheduledEffects: cannot fire unknown effect '%s'" % unknown)


static func _fire_chain_lightning(unit: Unit, entry: Dictionary) -> void:
	var marker: String = String(entry.get("marker", ""))
	var source_element := Enums.ElementalType.NONE
	if not marker.is_empty():
		var marker_effect: StatusEffect = _find_status(unit, marker)
		if marker_effect == null:
			# The mark was cleansed (or replaced away) — the strike is defused.
			DebugConfig.log_status("ScheduledEffects: %s on %s defused (marker gone)" % [
				entry.get("effect"), unit.unit_name])
			return
		source_element = marker_effect.source_element
		StatusEffectSystem.remove_status_effect(unit, marker)

	var power: int = int(entry.get("params", {}).get("power", 4))
	var splash_pct: float = float(entry.get("params", {}).get("splashPct", 50.0))

	unit.spawn_text_callout("CHAIN LIGHTNING", GameColors.TEXT_DANGER)
	if unit.is_inside_tree():
		await unit.get_tree().create_timer(CALLOUT_READ_SECONDS).timeout

	# Gather splash victims BEFORE any damage lands so a defeat mid-resolution
	# can't shift who was "adjacent at strike time."
	var splash_victims: Array[Unit] = _adjacent_units(unit, String(entry.get("immune", "")))
	var struck: Array[Unit] = [unit]
	_strike(unit, unit, power, source_element)

	var splash_damage: int = int(ceilf(float(power) * splash_pct / 100.0))
	if splash_damage > 0:
		for victim: Unit in splash_victims:
			_strike(unit, victim, splash_damage, source_element)
			struck.append(victim)

	# Defeats resolve after the whole strike so the splash reads as one event.
	# _handle_defeat self-guards against double-play (same contract the
	# displacement executor relies on for collateral kills).
	for victim: Unit in struck:
		if victim.is_defeated() and victim.has_method("_handle_defeat"):
			await victim._handle_defeat()


static func _strike(popup_host: Unit, victim: Unit, damage: int, element: Enums.ElementalType) -> void:
	victim.take_damage(damage, {
		"element": element,
		"damage_type": Enums.DamageType.SPECIAL,
		"name": "Chain Lightning",
	})
	VisualFeedbackManager.apply_hit_flash(victim, 0.4)
	popup_host._spawn_damage_popup(victim, damage, "", 1.0)


## Orthogonally adjacent (Manhattan 1) live units around `unit`, skipping any
## that match the `immune` predicate. Faction-blind on purpose — see header.
static func _adjacent_units(unit: Unit, immune: String) -> Array[Unit]:
	var adjacent: Array[Unit] = []
	if unit.current_tile == null:
		return adjacent
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var tile: Tile = GridManager.get_tile(
			unit.current_tile.grid_x + offset.x, unit.current_tile.grid_y + offset.y)
		if tile == null or tile.current_unit == null or not tile.current_unit is Unit:
			continue
		var neighbor := tile.current_unit as Unit
		if neighbor.is_defeated():
			continue
		if not immune.is_empty() and CombatPredicates.evaluate(immune, neighbor):
			continue
		adjacent.append(neighbor)
	return adjacent


static func _find_status(unit: Unit, effect_type_name: String) -> StatusEffect:
	for effect: StatusEffect in unit.active_status_effects:
		if effect.effect_type_name == effect_type_name:
			return effect
	return null
