## Tests for ModifierTerrainMap — the sprite → terrain join table. Runs
## against the real data/modifier_terrain.json (reload() picks up the file).
extends GutTest


func before_all() -> void:
	ModifierTerrainMap.reload()


# =============================================================================
# Prefix resolution
# =============================================================================

func test_prefix_resolves_uniform_sprite() -> void:
	# crater_a has no by_sprite entry → falls to by_prefix "crater" → Crater.
	assert_eq(ModifierTerrainMap.resolve("crater_a", Vector2i(0, 0)), "Crater")
	assert_eq(ModifierTerrainMap.resolve("crater_e", Vector2i(0, 0)), "Crater")


func test_prefix_groups_many_sprites_to_one_terrain() -> void:
	for sprite in ["bulbforest_a", "darkforest_b", "shelltree_a", "piperoot_c"]:
		assert_eq(ModifierTerrainMap.resolve(sprite, Vector2i(0, 0)), "Plant",
				"%s should resolve to Plant" % sprite)


func test_longest_prefix_wins() -> void:
	# "firetopradish" must beat any shorter prefix that happens to be a
	# substring-prefix. firetopradish_* → VolcanicPlant, not Plant.
	assert_eq(ModifierTerrainMap.resolve("firetopradish_a", Vector2i(0, 0)), "VolcanicPlant")


func test_unknown_sprite_resolves_empty() -> void:
	assert_eq(ModifierTerrainMap.resolve("totally_unknown_xyz", Vector2i(0, 0)), "",
			"A sprite with no prefix or by_sprite match is not a gameplay modifier")


# =============================================================================
# Per-cell (rows) resolution — the castle
# =============================================================================

func test_castle_top_row_is_wall_bottom_row_is_castle() -> void:
	# rows = ["Wall", "Castle"]; dy=0 is the north/top row.
	assert_eq(ModifierTerrainMap.resolve("castle_a", Vector2i(0, 0)), "Wall",
			"NW cell (top row) is Wall")
	assert_eq(ModifierTerrainMap.resolve("castle_a", Vector2i(1, 0)), "Wall",
			"NE cell (top row) is Wall")
	assert_eq(ModifierTerrainMap.resolve("castle_a", Vector2i(0, 1)), "Castle",
			"SW cell (bottom row) is Castle")
	assert_eq(ModifierTerrainMap.resolve("castle_a", Vector2i(1, 1)), "Castle",
			"SE cell (bottom row) is Castle")


func test_by_sprite_falls_back_to_prefix_for_uncovered_rows() -> void:
	# If a rows entry is shorter than the footprint, uncovered rows fall to
	# the prefix default. castle prefix → Castle.
	assert_eq(ModifierTerrainMap.resolve("castle_a", Vector2i(0, 5)), "Castle",
			"Row beyond the rows array falls back to the castle prefix default")


# =============================================================================
# is_modifier
# =============================================================================

func test_is_modifier_true_for_mapped_sprites() -> void:
	assert_true(ModifierTerrainMap.is_modifier("crater_a"))
	assert_true(ModifierTerrainMap.is_modifier("castle_a"))
	assert_true(ModifierTerrainMap.is_modifier("volcano_f"))


func test_is_modifier_false_for_unmapped_sprite() -> void:
	assert_false(ModifierTerrainMap.is_modifier("some_pure_decoration"))


# =============================================================================
# occlude_mode — render hint, defaults to interleave
# =============================================================================

func test_occlude_mode_defaults_to_interleave() -> void:
	# castle_a has no `occlude` field → the correct-depth default.
	assert_eq(ModifierTerrainMap.occlude_mode("castle_a"), ModifierTerrainMap.OCCLUDE_INTERLEAVE)
	# An unmapped sprite also defaults to interleave (fails safe).
	assert_eq(ModifierTerrainMap.occlude_mode("totally_unknown_xyz"), ModifierTerrainMap.OCCLUDE_INTERLEAVE)


# =============================================================================
# casts_shadow — render hint gating the GENERATED shadow fallback
# =============================================================================

func test_casts_shadow_defaults_true() -> void:
	assert_true(ModifierTerrainMap.casts_shadow("darkforest_a"), "prefixed sprite, no hint")
	assert_true(ModifierTerrainMap.casts_shadow("some_pure_decoration"), "unknown sprite")


func test_flat_ground_features_opt_out_of_generated_shadows() -> void:
	# A hole in the ground casts nothing; the bridge lies flat on it.
	for name in ["crater_a", "crater_b", "crater_c", "crater_d", "crater_e", "bridge_a"]:
		assert_false(ModifierTerrainMap.casts_shadow(name), "%s is flat — casts nothing" % name)


func test_crater_stays_a_modifier_alongside_its_render_hint() -> void:
	# The by_sprite entry only carries casts_shadow; terrain still comes
	# from the prefix.
	assert_true(ModifierTerrainMap.is_modifier("crater_a"))
	assert_eq(ModifierTerrainMap.resolve("crater_a", Vector2i.ZERO), "Crater")


func test_render_only_entry_does_not_promote_a_pure_decoration() -> void:
	ModifierTerrainMap.load_from_dictionary({
		"by_prefix": {"crater": "Crater"},
		"by_sprite": {"pure_bush": {"casts_shadow": false}},
	})
	assert_false(ModifierTerrainMap.is_modifier("pure_bush"),
			"a hint-only entry on an unprefixed name is still a pure decoration")
	assert_eq(ModifierTerrainMap.resolve("pure_bush", Vector2i.ZERO), "", "…with no terrain")
	assert_false(ModifierTerrainMap.casts_shadow("pure_bush"), "…but the hint is honored")
	ModifierTerrainMap.reload()


# =============================================================================
# Wildcard render hints — "piperoot_*" flags a whole family in one line
# =============================================================================

func _stage_wildcards() -> void:
	ModifierTerrainMap.load_from_dictionary({
		"by_prefix": {"piperoot": "Plant", "volcano": "Volcano"},
		"by_sprite": {
			"piperoot_*": {"casts_shadow": false},
			"volcano_*": {"casts_shadow": false, "occlude": "solid"},
			"volcano_z": {"casts_shadow": true},
		},
	})


func test_wildcard_applies_render_hints_to_the_family() -> void:
	_stage_wildcards()
	assert_false(ModifierTerrainMap.casts_shadow("piperoot_a"))
	assert_false(ModifierTerrainMap.casts_shadow("piperoot_c"))
	assert_eq(ModifierTerrainMap.occlude_mode("volcano_b"), ModifierTerrainMap.OCCLUDE_SOLID)
	assert_true(ModifierTerrainMap.casts_shadow("darkforest_a"), "unrelated sprite untouched")
	ModifierTerrainMap.reload()


func test_exact_entry_beats_wildcard_per_key() -> void:
	_stage_wildcards()
	assert_true(ModifierTerrainMap.casts_shadow("volcano_z"), "exact entry sets the key → it wins")
	assert_eq(ModifierTerrainMap.occlude_mode("volcano_z"), ModifierTerrainMap.OCCLUDE_SOLID,
			"…but a key the exact entry doesn't set still falls through to the wildcard")
	ModifierTerrainMap.reload()


func test_wildcards_never_carry_terrain() -> void:
	_stage_wildcards()
	assert_eq(ModifierTerrainMap.resolve("piperoot_a", Vector2i.ZERO), "Plant", "terrain still comes from by_prefix")
	ModifierTerrainMap.load_from_dictionary({
		"by_prefix": {},
		"by_sprite": {"bush_*": {"casts_shadow": false, "rows": ["Plant"]}},
	})
	assert_eq(ModifierTerrainMap.resolve("bush_a", Vector2i.ZERO), "", "rows on a wildcard are ignored")
	assert_false(ModifierTerrainMap.is_modifier("bush_a"), "a wildcard can't make a sprite a modifier")
	assert_false(ModifierTerrainMap.casts_shadow("bush_a"), "…its render hint still applies")
	ModifierTerrainMap.reload()
