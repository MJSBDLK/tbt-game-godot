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
##     "stacks": int,           # arc budget fallback for MARKERLESS entries;
##                              #   marked entries read the marker's live stacks
##     "immune": String,        # CombatPredicates name arc victims are checked
##                              #   against (primary victims were filtered at cast)
##     "params": Dictionary,    # handler knobs (power, ...)
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
## Re-marking an already-marked unit RESTACKS the marker instead of queuing a
## working second entry (the extra entry finds no marker and fizzles) — so a
## double Shriek arcs DEEPER, it doesn't strike twice.
##
## SAVES: entries are plain data — SaveManager serializes the queue per unit
## verbatim and re-coerces ints on restore. No live references anywhere.
##
## Handlers: chain_lightning_strike — the RQD 2026-08-03 chain design. The
## marked unit takes flat params.power (raw, like DoT ticks — telegraphed
## damage should be readable, not stat-mitigated), then the bolt ARCS: one arc
## per marker stack (max 4 = a 5-target chain), each hop to a unit within
## Chebyshev 1 of the last one struck ("touching, even at corners" — the
## clustering intuition; spread a full king-move apart to break the chain).
## Damage halves per hop (power >> hop, floored, minimum 1), no unit is struck
## twice by one chain, faction-blind (the damned don't discriminate). ELECTRIC
## types are immune to every hop, as are units matching entry.immune ("brave"
## for Shriek). The path comes from an exhaustive longest-path search
## (_best_chain), so the chain never strands itself in a dead end while
## targets remain reachable — five units huddled together = five units hit.
## Ties between equally long chains are broken by the SEEDED GameRng, so the
## bolt is unpredictable in play but identical on a seeded reload.
class_name ScheduledEffects
extends RefCounted


const EFFECT_CHAIN_LIGHTNING := "chain_lightning_strike"
const KNOWN_EFFECTS: PackedStringArray = [EFFECT_CHAIN_LIGHTNING]

## Read beat between the strike callout and the damage, mirroring the
## CORRUPTION / OUT OF RANGE convention: name the cause, then show the effect.
const CALLOUT_READ_SECONDS := 0.4

## Beat between chain hops so the bolt visibly TRAVELS instead of the whole
## chain resolving as one simultaneous splash.
const ARC_HOP_SECONDS := 0.15


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
	# Effect-specific immunity: lightning can't take hold on the already-
	# charged, so an ELECTRIC unit is never marked — not just skipped by arcs.
	if effect_name == EFFECT_CHAIN_LIGHTNING and CombatPredicates.is_electric(target):
		return false

	var marker: String = String(spec.get("marker", ""))
	if not marker.is_empty():
		var marked: bool = StatusEffectSystem.apply_status_effect_by_name(
			caster, target, marker, int(spec.get("stacks", 0)), false,
			move.element_type, move.damage_type)
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
		"stacks": maxi(1, int(spec.get("stacks", 1))),
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
	# One arc per marker stack — a restacked mark arcs deeper. Markerless
	# entries fall back to the budget captured at schedule time.
	var arc_budget: int = int(entry.get("stacks", 1))
	if not marker.is_empty():
		var marker_effect: StatusEffect = _find_status(unit, marker)
		if marker_effect == null:
			# The mark was cleansed (or replaced away) — the strike is defused.
			DebugConfig.log_status("ScheduledEffects: %s on %s defused (marker gone)" % [
				entry.get("effect"), unit.unit_name])
			return
		source_element = marker_effect.source_element
		arc_budget = maxi(1, marker_effect.stacks)
		StatusEffectSystem.remove_status_effect(unit, marker)

	var power: int = int(entry.get("params", {}).get("power", 4))

	unit.spawn_text_callout("CHAIN LIGHTNING", GameColors.TEXT_DANGER)
	if unit.is_inside_tree():
		await unit.get_tree().create_timer(CALLOUT_READ_SECONDS).timeout

	# Resolve the whole path BEFORE any damage lands, so a mid-chain defeat
	# can't shift who was reachable at strike time. Damage halves per hop
	# (bit-shift = floor-divide by 2^hop), never below 1.
	var chain: Array[Unit] = _best_chain(unit, arc_budget, String(entry.get("immune", "")))
	for hop: int in range(chain.size()):
		var victim: Unit = chain[hop]
		var damage: int = power if hop == 0 else maxi(1, power >> hop)
		_strike(unit, victim, damage, source_element)
		if hop < chain.size() - 1 and unit.is_inside_tree():
			await unit.get_tree().create_timer(ARC_HOP_SECONDS).timeout

	# Defeats resolve after the whole chain so it reads as one event.
	# _handle_defeat self-guards against double-play (same contract the
	# displacement executor relies on for collateral kills).
	for victim: Unit in chain:
		if victim.is_defeated() and victim.has_method("_handle_defeat"):
			await victim._handle_defeat()


## The arc path: `origin` first, then up to `arc_budget` hops, each to a unit
## within Chebyshev 1 of the previous one struck. Exhaustive longest-path
## search — the chain must not strand itself in a dead end while targets
## remain reachable (RQD's clustering rule: five units huddled together = five
## units hit). Small by construction: depth ≤ 4 arcs, ≤ 8 candidates per hop.
## When several chains tie for longest, GameRng picks one (RQD 2026-08-03:
## the path shouldn't be predictable) — the SEEDED die, so a seeded reload
## replays the same bolt and saves stay deterministic. A forced outcome
## (single longest chain) draws nothing, keeping the roll stream lean.
static func _best_chain(origin: Unit, arc_budget: int, immune: String) -> Array[Unit]:
	var longest: Array = []  # every terminal chain tied at the max length
	_gather_chains([origin] as Array[Unit], arc_budget, immune, longest)
	if longest.size() == 1:
		var only: Array[Unit] = longest[0]
		return only
	var picked: Array[Unit] = GameRng.pick_random(longest)
	return picked


## DFS over every arc sequence, recording TERMINAL chains (budget spent or
## nowhere left to jump) into `longest` — cleared whenever a longer one
## appears, appended on ties. Prefixes never terminate early, so only true
## maximal chains are candidates. Distinct orderings of the same units count
## separately: they deal different damage, so they're different outcomes.
static func _gather_chains(chain: Array[Unit], arcs_left: int, immune: String,
		longest: Array) -> void:
	var candidates: Array[Unit] = []
	if arcs_left > 0:
		candidates = _arc_candidates(chain.back(), chain, immune)
	if candidates.is_empty():
		if longest.is_empty() or chain.size() > (longest[0] as Array).size():
			longest.clear()
			longest.append(chain)
		elif chain.size() == (longest[0] as Array).size():
			longest.append(chain)
		return
	for candidate: Unit in candidates:
		_gather_chains(chain + ([candidate] as Array[Unit]), arcs_left - 1, immune, longest)


## Legal next hops from `head`: live units on the 8 surrounding tiles
## ("touching, even at corners"), minus anyone already struck this chain,
## ELECTRIC types (immune to every hop), and units matching the move-wide
## immune predicate (Shriek's brave). Faction-blind on purpose — see header.
static func _arc_candidates(head: Unit, struck: Array[Unit], immune: String) -> Array[Unit]:
	var candidates: Array[Unit] = []
	if head.current_tile == null:
		return candidates
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var tile: Tile = GridManager.get_tile(
					head.current_tile.grid_x + dx, head.current_tile.grid_y + dy)
			if tile == null or tile.current_unit == null or not tile.current_unit is Unit:
				continue
			var neighbor := tile.current_unit as Unit
			if neighbor.is_defeated() or neighbor in struck:
				continue
			if CombatPredicates.is_electric(neighbor):
				continue
			if not immune.is_empty() and CombatPredicates.evaluate(immune, neighbor):
				continue
			candidates.append(neighbor)
	return candidates


static func _strike(popup_host: Unit, victim: Unit, damage: int, element: Enums.ElementalType) -> void:
	victim.take_damage(damage, {
		"element": element,
		"damage_type": Enums.DamageType.SPECIAL,
		"name": "Chain Lightning",
	})
	VisualFeedbackManager.apply_hit_flash(victim, 0.4)
	popup_host._spawn_damage_popup(victim, damage, "", 1.0)


static func _find_status(unit: Unit, effect_type_name: String) -> StatusEffect:
	for effect: StatusEffect in unit.active_status_effects:
		if effect.effect_type_name == effect_type_name:
			return effect
	return null
