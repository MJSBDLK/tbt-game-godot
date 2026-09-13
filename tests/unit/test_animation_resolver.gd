## UnitAnimationResolver (Phase 1 of .claude/todo-archive.md ("Battle animations plan")): the
## direction-free "which clip plays" decision. Pins the intent derivation,
## the explicit chain per intent, all three override levels and their
## fall-through, and the PROCEDURAL terminal — plus the archer case RQD
## asked for. Replaces the use_when direction/range tests that lived in
## test_unit.gd.
extends GutTest


func _move(range_value: int, damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL,
		label: String = "Probe", style: String = "auto") -> Move:
	var move := Move.new()
	move.move_name = label
	move.attack_range = range_value
	move.damage_type = damage_type
	move.animation_style = style
	return move


func _clips(keys: Array) -> Dictionary:
	var table: Dictionary = {}
	for key: String in keys:
		table[key] = { "path": "res://stub/%s.png" % key, "frames": 1 }
	return table


# =============================================================================
# INTENT
# =============================================================================

func test_attack_intent_combines_reach_and_kind() -> void:
	assert_eq(UnitAnimationResolver.attack_intent(_move(1)), "melee_physical")
	assert_eq(UnitAnimationResolver.attack_intent(_move(1, Enums.DamageType.SPECIAL)), "melee_special")
	assert_eq(UnitAnimationResolver.attack_intent(_move(3)), "ranged_physical", "range 3 → ranged")
	assert_eq(UnitAnimationResolver.attack_intent(_move(2, Enums.DamageType.SPECIAL)), "ranged_special")
	assert_eq(UnitAnimationResolver.attack_intent(_move(1, Enums.DamageType.SUPPORT)), "cast",
			"support moves are casts")
	assert_eq(UnitAnimationResolver.attack_intent(null), "melee_physical", "null move = a plain swing")


func test_attack_intent_honours_the_gameplay_style_tag() -> void:
	assert_eq(UnitAnimationResolver.attack_intent(_move(3, Enums.DamageType.PHYSICAL, "Spear", "melee")),
			"melee_physical", "a range-3 move tagged melee reads as a stab")
	assert_eq(UnitAnimationResolver.attack_intent(_move(1, Enums.DamageType.SPECIAL, "Blast", "ranged")),
			"ranged_special", "a range-1 move tagged ranged reads as a shot")


func test_effective_animation_style_derivation() -> void:
	assert_eq(_move(1).effective_animation_style(), "melee", "range 1 → melee")
	assert_eq(_move(3).effective_animation_style(), "ranged", "range 3 → ranged")
	assert_eq(_move(3, Enums.DamageType.PHYSICAL, "Spear", "melee").effective_animation_style(),
			"melee", "explicit tag wins")


# =============================================================================
# CHAIN
# =============================================================================

func test_every_attack_intent_has_a_chain_ending_in_any_attack() -> void:
	for intent: String in ["melee_physical", "melee_special", "ranged_physical", "ranged_special"]:
		var chain := UnitAnimationResolver.chain_for(intent)
		assert_eq(chain[0], intent, "%s: the exact refinement comes first" % intent)
		assert_eq(chain[-1], UnitAnimationResolver.ANY_ATTACK,
				"%s: any attack clip beats the procedural nudge" % intent)


func test_reactions_have_no_fallback_but_procedural() -> void:
	for intent: String in ["dodge", "hurt", "death"]:
		assert_eq(UnitAnimationResolver.chain_for(intent), [intent] as Array[String])
		assert_eq(UnitAnimationResolver.resolve(_clips(["melee", "ranged"]), {}, null, intent),
				UnitAnimationResolver.PROCEDURAL, "%s never borrows an attack clip" % intent)


func test_unknown_intent_is_procedural() -> void:
	assert_eq(UnitAnimationResolver.chain_for("moonwalk").size(), 0)
	assert_eq(UnitAnimationResolver.resolve(_clips(["melee"]), {}, null, "moonwalk"),
			UnitAnimationResolver.PROCEDURAL)


func test_the_plain_clip_serves_its_refinements() -> void:
	var table := _clips(["melee", "ranged"])
	assert_eq(UnitAnimationResolver.resolve(table, {}, _move(1, Enums.DamageType.SPECIAL), "melee_special"),
			"melee", "no melee_special → melee")
	assert_eq(UnitAnimationResolver.resolve(table, {}, _move(2), "ranged_physical"),
			"ranged", "no ranged_physical → ranged")


func test_a_refinement_wins_when_present() -> void:
	var table := _clips(["melee", "melee_special", "ranged"])
	assert_eq(UnitAnimationResolver.resolve(table, {}, null, "melee_special"), "melee_special")
	assert_eq(UnitAnimationResolver.resolve(table, {}, null, "melee_physical"), "melee",
			"the physical swing doesn't borrow the special one while melee exists")


func test_the_archer_shoots_point_blank() -> void:
	# A bow unit with only a ranged clip, forced into melee by a passive:
	# melee_physical → (no melee) → ranged_physical → (no) → ranged. Shoot.
	var bow_only := _clips(["ranged"])
	assert_eq(UnitAnimationResolver.resolve(bow_only, {}, _move(1), "melee_physical"), "ranged")


func test_a_brawler_swings_at_range() -> void:
	# The mirror: melee-only sprite (Grasker) using a ranged move → the swing,
	# not a boop.
	var fists_only := _clips(["melee"])
	assert_eq(UnitAnimationResolver.resolve(fists_only, {}, _move(3), "ranged_physical"), "melee")


func test_any_attack_catches_odd_tables() -> void:
	# Only a refinement of the OTHER reach exists: the chain's own steps miss,
	# ANY_ATTACK still finds it rather than dropping to procedural.
	var odd := _clips(["ranged_special"])
	assert_eq(UnitAnimationResolver.resolve(odd, {}, _move(1), "melee_physical"), "ranged_special")


func test_cast_borrows_a_swing_when_no_cast_clip() -> void:
	assert_eq(UnitAnimationResolver.resolve(_clips(["cast", "melee"]), {}, null, "cast"), "cast")
	assert_eq(UnitAnimationResolver.resolve(_clips(["melee"]), {}, null, "cast"), "melee")
	assert_eq(UnitAnimationResolver.resolve(_clips(["idle"]), {}, null, "cast"),
			UnitAnimationResolver.PROCEDURAL, "idle alone → today's scale pulse")


func test_idle_alone_is_always_playable() -> void:
	for intent: String in UnitAnimationResolver.CHAINS.keys():
		if intent == "idle":
			continue
		assert_eq(UnitAnimationResolver.resolve(_clips(["idle"]), {}, _move(1), intent),
				UnitAnimationResolver.PROCEDURAL, "%s with only idle → procedural, never an error" % intent)


# =============================================================================
# OVERRIDES — most specific wins, missing clips fall through
# =============================================================================

func test_intent_override_redirects_a_whole_intent() -> void:
	# RQD's example: "when this unit uses its melee special, play the ranged
	# physical animation."
	var table := _clips(["melee", "ranged"])
	var overrides := { "melee_special": "ranged" }
	assert_eq(UnitAnimationResolver.resolve(table, overrides, _move(1, Enums.DamageType.SPECIAL), "melee_special"),
			"ranged")
	assert_eq(UnitAnimationResolver.resolve(table, overrides, _move(1), "melee_physical"),
			"melee", "other intents untouched")


func test_move_override_beats_intent_override() -> void:
	var table := _clips(["melee", "ranged", "cast"])
	var overrides := { "melee_special": "ranged", "move:Sparkle": "cast" }
	var sparkle := _move(1, Enums.DamageType.SPECIAL, "Sparkle")
	assert_eq(UnitAnimationResolver.resolve(table, overrides, sparkle, "melee_special"), "cast",
			"the move-specific override is the most specific")


func test_move_visual_clip_sits_between_the_two_override_levels() -> void:
	var table := _clips(["melee", "ranged", "cast"])
	var shot := _move(1, Enums.DamageType.SPECIAL, "Zap")
	shot.animation_clip = "ranged"
	assert_eq(UnitAnimationResolver.resolve(table, { "melee_special": "cast" }, shot, "melee_special"),
			"ranged", "the move's animationClip beats the character's intent override")
	assert_eq(UnitAnimationResolver.resolve(table, { "move:Zap": "cast" }, shot, "melee_special"),
			"cast", "…but loses to the character's move-specific override")


func test_override_keys_are_case_insensitive() -> void:
	var table := _clips(["melee", "ranged"])
	assert_eq(UnitAnimationResolver.resolve(table, { "Melee_Special": "RANGED" }, null, "melee_special"),
			"ranged")
	assert_eq(UnitAnimationResolver.resolve(table, { "MOVE:uppercut": "ranged" },
			_move(1, Enums.DamageType.PHYSICAL, "Uppercut"), "melee_physical"), "ranged")


func test_a_missing_override_target_falls_through_to_the_chain() -> void:
	var table := _clips(["melee"])
	assert_eq(UnitAnimationResolver.resolve(table, { "melee_special": "ranged" }, null, "melee_special"),
			"melee", "override names a clip this character lacks → chain, not procedural")
	var shot := _move(1, Enums.DamageType.SPECIAL, "Zap")
	shot.animation_clip = "cast"
	assert_eq(UnitAnimationResolver.resolve(table, {}, shot, "melee_special"), "melee")
	assert_eq(UnitAnimationResolver.resolve(table, { "move:Zap": "dodge" }, shot, "melee_special"), "melee")


func test_animation_style_never_changes_combat_math() -> void:
	# The reason animationClip exists as a SEPARATE key: is_ranged_style feeds
	# Crater's defense split, so a visual override must not touch it.
	var stab := _move(1, Enums.DamageType.PHYSICAL, "Stab")
	stab.animation_clip = "ranged"
	assert_false(stab.is_ranged_style(), "a melee move that LOOKS like a shot is still melee to the terrain")


func test_attack_intent_reads_the_distance_when_a_target_is_known() -> void:
	assert_eq(UnitAnimationResolver.attack_intent(_move(3), 1), "melee_physical",
			"a range-3 move fired point-blank is a melee moment (the use_when-era rule)")
	assert_eq(UnitAnimationResolver.attack_intent(_move(3, Enums.DamageType.SPECIAL), 2), "ranged_special")
	assert_eq(UnitAnimationResolver.attack_intent(_move(1), 2), "ranged_physical",
			"a punch landed two tiles away (Extendo) reads as ranged, as before — tag the move melee to keep the swing")
	assert_eq(UnitAnimationResolver.attack_intent(_move(1, Enums.DamageType.SPECIAL, "Blast", "ranged"), 1),
			"ranged_special", "the tag forces the family regardless of distance")
	assert_eq(UnitAnimationResolver.attack_intent(_move(3, Enums.DamageType.PHYSICAL, "Spear", "melee"), 3),
			"melee_physical")
	assert_eq(UnitAnimationResolver.attack_intent(_move(3), 0), "ranged_physical",
			"no target known → the move's own reach")
	assert_eq(UnitAnimationResolver.attack_intent(null, 2), "ranged_physical", "null move at range")


func test_the_same_reach_beats_the_right_kind_at_the_wrong_reach() -> void:
	# Ernesto: a jab (`melee`) and a long thrust (`ranged_physical`). His
	# Laser is special; at range it must be the thrust, never the jab.
	var ernesto := { "melee": {}, "ranged_physical": {} }
	assert_eq(UnitAnimationResolver.resolve(ernesto, {}, null, "ranged_special"), "ranged_physical")
	assert_eq(UnitAnimationResolver.resolve(ernesto, {}, null, "melee_special"), "melee")
	var caster := { "melee": {}, "ranged_special": {} }
	assert_eq(UnitAnimationResolver.resolve(caster, {}, null, "ranged_physical"), "ranged_special",
			"a physical shot from a caster is the spell, not the staff whack")
