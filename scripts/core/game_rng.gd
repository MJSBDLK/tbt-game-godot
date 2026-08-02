## The gameplay dice — one seeded RandomNumberGenerator behind every roll that
## mutates GAME STATE: hit rolls, crit rolls, status/injury procs, growth
## rolls, enemy spawn picks, AI move picks, recruit shuffles.
##
## Why one instance instead of the global randf()/randi(): the globals can be
## seeded but their internal state can't be READ BACK, so a save file could
## never record "where the dice are." A RandomNumberGenerator instance exposes
## seed + state as writable properties, which makes reload determinism
## possible: SaveManager stores capture_state() in every save, and on load
## either restores it (Settings.seeded_reload, the fair default — repeating
## the same actions after a reload repeats the same outcomes) or calls
## reseed() (the save-scummer's option: every reload re-rolls fate).
##
## The routing rule:
##   - Gameplay state rolls  -> GameRng.* (this class)
##   - Cosmetic rolls        -> the globals, or a local RNG (screenshake,
##     void-lock FX, hypoesthesia static, foot-track variants)
##   - Debug scaffolding     -> the globals (DebugConfig.testing_* cheats are
##     MEANT to vary; determinism there would make Ctrl+K repros stale)
## Cosmetic/debug rolls must never touch this stream: an extra draw desyncs
## a seeded reload, turning "same actions, same outcome" into a lie.
##
## The API mirrors the global function names, so a call site migrates by
## prefixing `GameRng.` — plus shuffle()/pick_random() replacing the Array
## methods (which draw from the global stream and would leak rolls).
class_name GameRng
extends RefCounted


static var _rng: RandomNumberGenerator = _make_rng()


static func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng


# =============================================================================
# ROLLS — mirror the global-scope names
# =============================================================================

static func randf() -> float:
	return _rng.randf()


static func randi() -> int:
	return _rng.randi()


static func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


static func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## In-place Fisher-Yates on this stream. Replaces Array.shuffle(), which draws
## from the global RNG and would bypass the saveable state.
static func shuffle(array: Array) -> void:
	for i: int in range(array.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: Variant = array[i]
		array[i] = array[j]
		array[j] = swap


## Replaces Array.pick_random() for the same reason as shuffle().
static func pick_random(array: Array) -> Variant:
	if array.is_empty():
		return null
	return array[_rng.randi_range(0, array.size() - 1)]


# =============================================================================
# SAVE/LOAD SURFACE
# =============================================================================

## Snapshot of the dice for a save file. seed and state are int64; JSON's
## number type is a double (53-bit mantissa), so both ship as STRINGS to
## survive the stringify/parse round trip bit-exact.
static func capture_state() -> Dictionary:
	return {
		"seed": "%d" % _rng.seed,
		"state": "%d" % _rng.state,
	}


## Restores a capture_state() snapshot. Order matters: assigning seed resets
## state (Godot derives a fresh state from it), so seed goes first and the
## exact stream position second.
static func restore_state(snapshot: Dictionary) -> void:
	if not (snapshot.has("seed") and snapshot.has("state")):
		push_warning("GameRng: malformed state snapshot %s — reseeding instead" % [snapshot])
		reseed()
		return
	_rng.seed = int(str(snapshot["seed"]).to_int())
	_rng.state = int(str(snapshot["state"]).to_int())


## Fresh entropy — used on new campaigns, and on load when the player has
## turned Settings.seeded_reload off (reload = re-roll fate).
static func reseed() -> void:
	_rng.randomize()
