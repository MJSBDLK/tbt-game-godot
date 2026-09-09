## RecordingPresenter — the test double for the CombatPresenter seam. Records
## every beat in order with the names of the units involved, waits for
## nothing, draws nothing. Lets a test assert "hit 1, counter, bonus hit,
## denial callout, death" as a sequence without tweens, timers, or sprites —
## and proves that request_skip() changes timing only, never order.
class_name RecordingPresenter
extends CombatPresenter


## One entry per beat: { "beat": String, plus "actor"/"target"/"unit" names,
## "text", "seconds", "damage" ... whatever the beat carried }.
var beats: Array[Dictionary] = []


func beat_names() -> Array[String]:
	var names: Array[String] = []
	for entry: Dictionary in beats:
		names.append(entry["beat"])
	return names


## Entries for one beat kind, in order.
func beats_named(beat: String) -> Array[Dictionary]:
	var matching: Array[Dictionary] = []
	for entry: Dictionary in beats:
		if entry["beat"] == beat:
			matching.append(entry)
	return matching


func count(beat: String) -> int:
	return beats_named(beat).size()


static func _name_of(unit: Node2D) -> String:
	if unit == null:
		return "<null>"
	var unit_name: Variant = unit.get("unit_name")
	return str(unit_name) if unit_name != null else unit.name


func _record(beat: String, fields: Dictionary = {}) -> void:
	var entry: Dictionary = { "beat": beat }
	entry.merge(fields)
	beats.append(entry)


func open(exchange_attacker: Node2D, exchange_defender: Node2D, exchange_move: Move) -> void:
	super.open(exchange_attacker, exchange_defender, exchange_move)
	_record("open", { "attacker": _name_of(exchange_attacker), "defender": _name_of(exchange_defender),
			"move": exchange_move.move_name if exchange_move != null else "" })


func close() -> void:
	super.close()
	_record("close")


## Never waits — but records the requested hold so pacing can be asserted.
func hold(seconds: float) -> void:
	_record("hold", { "seconds": seconds, "skipped": is_skipping() })


func strike_to_contact(actor: Node2D, target: Node2D, strike_move: Move) -> void:
	_record("strike", { "actor": _name_of(actor), "target": _name_of(target),
			"move": strike_move.move_name if strike_move != null else "" })


func nudge_to_contact(actor: Node2D, target: Node2D) -> void:
	_record("nudge", { "actor": _name_of(actor), "target": _name_of(target) })


func release_contact(actor: Node2D) -> void:
	_record("release", { "actor": _name_of(actor) })


func impact(target: Node2D, impact_weight: float, tint: Color = Color.TRANSPARENT) -> void:
	_record("impact", { "target": _name_of(target), "weight": impact_weight, "tint": tint })


func miss(actor: Node2D, target: Node2D, strike_move: Move) -> void:
	_record("miss", { "actor": _name_of(actor), "target": _name_of(target),
			"move": strike_move.move_name if strike_move != null else "" })


func show_damage(actor: Node2D, target: Node2D, damage: int, effectiveness_text: String,
		multiplier: float) -> void:
	_record("damage", { "actor": _name_of(actor), "target": _name_of(target), "damage": damage,
			"effectiveness": effectiveness_text, "multiplier": multiplier })


func show_heal(actor: Node2D, target: Node2D, amount: int) -> void:
	_record("heal", { "actor": _name_of(actor), "target": _name_of(target), "amount": amount })


func callout(unit: Node2D, text: String, color: Color) -> void:
	_record("callout", { "unit": _name_of(unit), "text": text, "color": color })


func out_of_range(unit: Node2D) -> void:
	_record("out_of_range", { "unit": _name_of(unit) })


func cast_flourish(actor: Node2D, cast_move: Move) -> void:
	_record("cast", { "actor": _name_of(actor), "move": cast_move.move_name if cast_move != null else "" })


func death(unit: Node2D) -> void:
	_record("death", { "unit": _name_of(unit) })


func displace(plan: DisplacementSystem.DisplacePlan) -> void:
	var movers: Array[String] = []
	for mover: Dictionary in plan.movers:
		movers.append("%s×%d" % [_name_of(mover.unit), (mover.path as Array).size()])
	_record("displace", { "movers": movers })
