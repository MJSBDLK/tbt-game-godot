## Where a stat's number comes from, line by line: the "why is my STR 12?"
## tooltip on the unit detail panel's rows and the Manage Units sheet's rows.
## Reads CharacterData's modifier fields AND the source ledgers the writing
## systems keep beside them (status_modifier_sources et al.), so every line
## names its cause and the lines always sum to the number on screen. A ledger
## that drifts from its field (a test poking the field directly, a writer that
## skipped the ledger) shows up as a line wearing the bucket's own name rather
## than as a tooltip that doesn't add up: a total the player can check is the
## whole point.
class_name StatBreakdown


## Appends one {"label", "amount"} line to `ledger[stat_name]`.
static func record(ledger: Dictionary, stat_name: String, label: String, amount: int) -> void:
	var entries: Array = ledger.get(stat_name, [])
	entries.append({"label": label, "amount": amount})
	ledger[stat_name] = entries


## Lines for a stack of percentage effects the game applies as ONE rounded
## total: each line is what adding that effect changed, in order, so the lines
## sum to `apply_pct.call(base, total_pct)` by construction. Two opposite
## effects that cancel still read +2 / -2, not nothing. `contributions` is an
## Array of [label, pct]; `apply_pct` is the system's own pct→int rule (the
## floor-toward-zero, minimum ±1 one).
static func pct_lines(base: int, contributions: Array, apply_pct: Callable) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var running_pct: float = 0.0
	var running_total: int = 0
	for contribution: Array in contributions:
		running_pct += float(contribution[1])
		var total_now: int = int(apply_pct.call(base, running_pct))
		entries.append({"label": str(contribution[0]), "amount": total_now - running_total})
		running_total = total_now
	return entries


static func total_of(entries: Array) -> int:
	var total: int = 0
	for line: Dictionary in entries:
		total += int(line["amount"])
	return total


## Every line behind `stat_name`'s effective value, Base first. Zero-amount
## lines stay: a StatUp that rounds to nothing is exactly the thing the player
## is confused about.
static func lines(character: CharacterData, stat_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var level_value: int = character.get_base_plus_growth(stat_name)
	out.append({"label": "Base", "amount": level_value})
	var points: int = character.get_allocated_points(stat_name)
	if points > 0:
		out.append({"label": "StatUp" if points == 1 else "%d StatUps" % points,
				"amount": StatAllocation.compute_delta(stat_name, level_value, points)})
	var bond: int = int(character.get(CharacterData.modifier_field("bond_bonus_", stat_name)))
	if bond != 0:
		out.append({"label": "Bond", "amount": bond})
	_append_bucket(out, character.passive_bonus_sources, stat_name, "Passives",
			int(character.get(CharacterData.modifier_field("passive_bonus_", stat_name))))
	_append_bucket(out, character.injury_modifier_sources, stat_name, "Injuries",
			int(character.get(CharacterData.modifier_field("injury_modifier_", stat_name))))
	_append_bucket(out, character.status_modifier_sources, stat_name, "Status",
			int(character.get(CharacterData.modifier_field("status_modifier_", stat_name))))
	# The stat getters are the one other place this sum lives; a term added
	# there and not here would print a tooltip that doesn't add up.
	var drift: int = character.get_stat(stat_name) - total_of(out)
	assert(drift == 0, "StatBreakdown: %s lines are %d short of the stat's getter" % [stat_name, drift])
	if drift != 0:
		out.append({"label": "other", "amount": drift})
	return out


## The bucket's ledger lines, then whatever the field holds that the ledger
## doesn't explain, under the bucket's own name.
static func _append_bucket(out: Array[Dictionary], ledger: Dictionary, stat_name: String,
		bucket_label: String, field_total: int) -> void:
	var explained: int = 0
	for line: Dictionary in ledger.get(stat_name, []):
		out.append(line)
		explained += int(line["amount"])
	if field_total != explained:
		out.append({"label": bucket_label, "amount": field_total - explained})


## The tooltip, one line per source:
##   Base (10)
##   +3 (Competitive)
##   -1 (Trauma)
static func text(character: CharacterData, stat_name: String) -> String:
	var rows: PackedStringArray = []
	for line: Dictionary in lines(character, stat_name):
		if line["label"] == "Base":
			rows.append("Base (%d)" % int(line["amount"]))
		else:
			rows.append("%+d (%s)" % [int(line["amount"]), line["label"]])
	return "\n".join(rows)
