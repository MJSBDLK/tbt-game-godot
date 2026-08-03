## Per-mission metadata + the bEXP income table. Static lookup, not an
## autoload — SquadManager asks it for award lines at battle end and (later)
## the mission-info UI asks it for par display.
##
## Doctrine ([.claude/mission_objectives.md](../../.claude/mission_objectives.md),
## amended 2026-08-03): bEXP income = coarse end-of-mission turn bands plus
## explicit per-map objectives. Par is a DISPLAYED fact, never a ticking
## countdown; bands are additive (finishing faster never earns less):
##
##   turn_count <= par_turns     -> "Above par"  (+ABOVE_PAR_BEXP)  } both
##   turn_count <= dawdle_turns  -> "No dawdling" (+NO_DAWDLING_BEXP) } lines
##   defeat                      -> no income at all (mission replays)
##
## Objective entries in the manifest are the AWARD side only — runtime
## tracking (couriers, NPC rescues, caches) doesn't exist yet. When it does,
## completed ids flow into compute_award_lines and the lines appear with no
## changes here.
##
## Data: [data/missions/mission_manifest.json](../../data/missions/mission_manifest.json),
## keyed by scene path. Unlisted maps get DEFAULT_* values so ad-hoc battles
## still produce income. All amounts are playtest dials.
class_name MissionCatalog


const MANIFEST_PATH: String = "res://data/missions/mission_manifest.json"

const DEFAULT_PAR_TURNS: int = 8
const DEFAULT_DAWDLE_TURNS: int = 16

# Per-map manifest keys "above_par_bexp" / "dawdle_bexp" override these.
const ABOVE_PAR_BEXP: int = 150
const NO_DAWDLING_BEXP: int = 75

static var _manifest_cache: Dictionary = {}
static var _manifest_loaded: bool = false


## Manifest entry for a mission scene path, with defaults filled in for
## unlisted maps. Always returns a usable Dictionary.
static func entry_for(scene_path: String) -> Dictionary:
	_ensure_loaded()
	var entry: Dictionary = _manifest_cache.get(scene_path, {})
	return {
		"display_name": str(entry.get("display_name", scene_path.get_file().get_basename())),
		"par_turns": int(entry.get("par_turns", DEFAULT_PAR_TURNS)),
		"dawdle_turns": int(entry.get("dawdle_turns", DEFAULT_DAWDLE_TURNS)),
		"above_par_bexp": int(entry.get("above_par_bexp", ABOVE_PAR_BEXP)),
		"dawdle_bexp": int(entry.get("dawdle_bexp", NO_DAWDLING_BEXP)),
		"objectives": entry.get("objectives", []) as Array,
	}


## Itemized bEXP income for a finished mission. Returns an Array of
## { "label": String, "amount": int } — the result screen renders these
## verbatim and SquadManager sums them into the pool. Pure: no autoload
## reads, fully unit-testable.
static func compute_award_lines(entry: Dictionary, turn_count: int,
		is_victory: bool, completed_objective_ids: Array = []) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if not is_victory:
		return lines
	var par: int = int(entry.get("par_turns", DEFAULT_PAR_TURNS))
	var dawdle: int = int(entry.get("dawdle_turns", DEFAULT_DAWDLE_TURNS))
	if turn_count <= dawdle:
		lines.append({"label": "No dawdling", "amount": int(entry.get("dawdle_bexp", NO_DAWDLING_BEXP))})
	if turn_count <= par:
		lines.append({"label": "Above par", "amount": int(entry.get("above_par_bexp", ABOVE_PAR_BEXP))})
	for objective: Variant in entry.get("objectives", []) as Array:
		var objective_dict: Dictionary = objective as Dictionary
		if completed_objective_ids.has(str(objective_dict.get("id", ""))):
			lines.append({
				"label": str(objective_dict.get("label", "Objective")),
				"amount": int(objective_dict.get("bexp", 0)),
			})
	return lines


static func total_of(lines: Array[Dictionary]) -> int:
	var total: int = 0
	for line: Dictionary in lines:
		total += int(line.get("amount", 0))
	return total


static func _ensure_loaded() -> void:
	if _manifest_loaded:
		return
	_manifest_loaded = true
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("MissionCatalog: no manifest at %s — all maps use defaults" % MANIFEST_PATH)
		return
	var text: String = FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_manifest_cache = parsed
	else:
		push_error("MissionCatalog: manifest failed to parse — all maps use defaults")
