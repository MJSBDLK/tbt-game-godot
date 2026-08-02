## GameRng — the seeded gameplay dice behind the save system.
##
## The load-bearing property: capture_state() → (draws) → restore_state() must
## replay the exact same stream, INCLUDING after the snapshot has round-tripped
## through JSON text — that's what makes "seeded reload" honest. seed/state are
## int64s shipped as strings because JSON numbers are doubles (53-bit mantissa)
## and would silently mangle high bits.
extends GutTest


func test_restore_replays_identical_stream() -> void:
	GameRng.reseed()
	var snapshot: Dictionary = GameRng.capture_state()
	var first_run: Array[int] = []
	for _i: int in range(8):
		first_run.append(GameRng.randi())
	GameRng.restore_state(snapshot)
	for i: int in range(8):
		assert_eq(GameRng.randi(), first_run[i],
			"restored stream must replay draw %d identically" % i)


func test_capture_mid_stream_resumes_position() -> void:
	GameRng.reseed()
	GameRng.randi()  # advance somewhere mid-stream
	var snapshot: Dictionary = GameRng.capture_state()
	var expected: float = GameRng.randf()
	GameRng.restore_state(snapshot)
	assert_eq(GameRng.randf(), expected,
		"capture must record the stream POSITION, not just the seed")


func test_snapshot_survives_json_round_trip() -> void:
	GameRng.reseed()
	var snapshot: Dictionary = GameRng.capture_state()
	var expected: int = GameRng.randi()

	var parsed: Variant = JSON.parse_string(JSON.stringify(snapshot))
	assert_true(parsed is Dictionary, "snapshot must survive stringify/parse")
	GameRng.restore_state(parsed as Dictionary)
	assert_eq(GameRng.randi(), expected,
		"JSON-round-tripped snapshot must replay the same stream (int64-as-string)")


func test_snapshot_fields_are_strings() -> void:
	var snapshot: Dictionary = GameRng.capture_state()
	assert_true(snapshot["seed"] is String, "seed ships as a string for int64 precision")
	assert_true(snapshot["state"] is String, "state ships as a string for int64 precision")
	assert_true(str(snapshot["seed"]).is_valid_int(), "seed string must parse as int")
	assert_true(str(snapshot["state"]).is_valid_int(), "state string must parse as int")


func test_shuffle_is_deterministic_and_a_permutation() -> void:
	GameRng.reseed()
	var snapshot: Dictionary = GameRng.capture_state()
	var first: Array = [1, 2, 3, 4, 5, 6, 7, 8]
	GameRng.shuffle(first)

	var second: Array = [1, 2, 3, 4, 5, 6, 7, 8]
	GameRng.restore_state(snapshot)
	GameRng.shuffle(second)

	assert_eq(first, second, "same dice state must produce the same shuffle")
	var sorted_copy: Array = first.duplicate()
	sorted_copy.sort()
	assert_eq(sorted_copy, [1, 2, 3, 4, 5, 6, 7, 8], "shuffle must keep every element")


func test_pick_random_edges() -> void:
	assert_null(GameRng.pick_random([]), "empty array picks null")
	assert_eq(GameRng.pick_random(["only"]), "only", "single-element array picks it")


func test_malformed_snapshot_reseeds_instead_of_crashing() -> void:
	GameRng.restore_state({"seed": "123"})  # missing state — warns + reseeds
	var value: int = GameRng.randi_range(1, 6)
	assert_between(value, 1, 6, "dice must keep working after a malformed restore")
