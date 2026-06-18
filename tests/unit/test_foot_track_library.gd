## Tests for FootTrackLibrary.resolve_variant — the pure terrain -> variant rule
## (name-match + override map), independent of texture loading.
extends GutTest


func test_exact_name_match_is_case_insensitive() -> void:
	assert_eq(FootTrackLibrary.resolve_variant("Regolith", ["regolith", "snow"], {}), "regolith",
			"PascalCase terrain matches a lowercase variant")
	assert_eq(FootTrackLibrary.resolve_variant("regolith", ["regolith"], {}), "regolith",
			"Already-lowercase terrain matches")


func test_miss_returns_empty() -> void:
	assert_eq(FootTrackLibrary.resolve_variant("Rock", ["regolith", "snow"], {}), "",
			"A terrain with no variant gets no tracks")
	assert_eq(FootTrackLibrary.resolve_variant("", ["regolith"], {}), "",
			"Empty terrain name resolves to nothing")


func test_override_maps_nonmatching_terrain() -> void:
	var overrides := { "PolarIce": "snow", "Tundra": "snow" }
	assert_eq(FootTrackLibrary.resolve_variant("PolarIce", ["snow"], overrides), "snow",
			"Override maps PolarIce to the snow variant")
	assert_eq(FootTrackLibrary.resolve_variant("tundra", ["snow"], overrides), "snow",
			"Override lookup is case-insensitive on the terrain key")


func test_override_to_missing_variant_yields_empty() -> void:
	# Override points at a variant not yet shipped -> render nothing, not error.
	assert_eq(FootTrackLibrary.resolve_variant("Tundra", ["regolith"], { "Tundra": "snow" }), "",
			"Mapping to an absent variant renders nothing")


func test_override_wins_over_name_match() -> void:
	assert_eq(FootTrackLibrary.resolve_variant("snow", ["snow", "regolith"], { "snow": "regolith" }), "regolith",
			"Explicit override takes precedence over a name match")
