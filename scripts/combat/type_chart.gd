## Type effectiveness chart loaded from JSON.
##
## Single source of truth for the type-coefficient lives here: `TYPE_COEFFICIENT`.
## All effectiveness multipliers are derived: ouch = k, 2x ouch = k²,
## resist = 1/k, 2x resist = 1/k². Doubled tiers fall out of dual-type stacking,
## so JSON only needs single-tier entries.
##
## JSON encoding: each matchup stores `"effect"` as one of "ouch", "resist",
## or "immune". Pairs not listed default to neutral. This keeps the JSON free of
## numeric values so changing the coefficient is a one-line code change.
class_name TypeChart
extends Resource


## Tunable. Pokémon-style was 2.0; small-grain TBS plays better around 1.2.
const TYPE_COEFFICIENT: float = 1.2

const DEFAULT_EFFECTIVENESS: float = 1.0
const IMMUNE_MULTIPLIER: float = 0.0

# Stage ints. Doubled tiers (±2) only arise from dual-type combination at lookup time.
const STAGE_OUCH: int = 1
const STAGE_NEUTRAL: int = 0
const STAGE_RESIST: int = -1

# Cache: "ATTACKING:DEFENDING" -> multiplier
var _effectiveness_cache: Dictionary = {}


func load_from_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		DebugConfig.log_error("TypeChart: File not found: %s" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		DebugConfig.log_error("TypeChart: Failed to open: %s" % path)
		return false

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()

	if error != OK:
		DebugConfig.log_error("TypeChart: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return false

	var data: Dictionary = json.data
	if not data.has("matchups"):
		DebugConfig.log_error("TypeChart: Missing 'matchups' array")
		return false

	_effectiveness_cache.clear()
	var matchups: Array = data["matchups"]
	for entry: Dictionary in matchups:
		var attacking: String = entry.get("attacking", "")
		var defending: String = entry.get("defending", "")
		var effect_key: String = entry.get("effect", "")
		if attacking == "" or defending == "" or effect_key == "":
			continue
		var multiplier := effect_to_multiplier(effect_key)
		var key := _make_key(attacking, defending)
		_effectiveness_cache[key] = multiplier

	DebugConfig.log_combat("TypeChart: Loaded %d matchups from %s" % [_effectiveness_cache.size(), path])
	return true


## Get effectiveness multiplier for attacking type vs defending type.
func get_effectiveness(attacking_type: Enums.ElementalType, defending_type: Enums.ElementalType) -> float:
	if attacking_type == Enums.ElementalType.NONE or defending_type == Enums.ElementalType.NONE:
		return DEFAULT_EFFECTIVENESS

	var attacking_name := Enums.elemental_type_to_string(attacking_type)
	var defending_name := Enums.elemental_type_to_string(defending_type)
	var key := _make_key(attacking_name, defending_name)
	return _effectiveness_cache.get(key, DEFAULT_EFFECTIVENESS)


## Map a stage string ("ouch" / "resist" / "immune") to a multiplier.
static func effect_to_multiplier(effect_key: String) -> float:
	match effect_key:
		"ouch":
			return TYPE_COEFFICIENT
		"resist":
			return 1.0 / TYPE_COEFFICIENT
		"immune":
			return IMMUNE_MULTIPLIER
		_:
			return DEFAULT_EFFECTIVENESS


## Map a stage int (-2..+2, with sentinel for immune) to a multiplier.
## Used by UI code that already knows the integer stage.
static func stage_to_multiplier(stage: int) -> float:
	if stage == STAGE_NEUTRAL:
		return DEFAULT_EFFECTIVENESS
	return pow(TYPE_COEFFICIENT, float(stage))


## Reverse lookup: classify a multiplier into a stage.
## Returns -2 (2x resist), -1 (resist), 0 (neutral), 1 (ouch), 2 (2x/double ouch).
## IMMUNE is a special case — callers should check `is_immune()` first.
static func multiplier_to_stage(multiplier: float) -> int:
	if is_immune(multiplier):
		return -99
	if is_equal_approx(multiplier, 1.0):
		return 0
	# log_k(m) = stage. Round to nearest int to handle float drift.
	var stage_float := log(multiplier) / log(TYPE_COEFFICIENT)
	return roundi(stage_float)


static func is_immune(multiplier: float) -> bool:
	return multiplier <= 0.0


## Get display text for an effectiveness multiplier.
##
## `verbose` swaps the doubled-tier prefix between compact "2x" (for on-map chips,
## combat preview, anywhere space-constrained) and the longer "Double" (for
## tooltips, flavor text, codex). Single-tier labels are the same in both modes.
static func get_effectiveness_text(multiplier: float, verbose: bool = false) -> String:
	if is_immune(multiplier):
		return "Immune"
	var stage := multiplier_to_stage(multiplier)
	match stage:
		2:
			return "Double Ouch" if verbose else "2x Ouch"
		1:
			return "Ouch"
		0:
			return ""
		-1:
			return "Resist"
		-2:
			return "Double Resist" if verbose else "2x Resist"
		_:
			return ""


func _make_key(attacking_name: String, defending_name: String) -> String:
	# Normalize to title case for consistent lookup
	return attacking_name.to_pascal_case() + ":" + defending_name.to_pascal_case()
