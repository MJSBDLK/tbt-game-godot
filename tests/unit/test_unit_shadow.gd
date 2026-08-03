extends GutTest
## Pins the UnitShadow ground projection — the FULL silhouette turned 90°
## clockwise on the feet pivot, then RQD's three dials: smoosh_x (reach
## scale, 1.0 = none), smoosh_y (vertical squash, 1.0 = none), and shear
## (RQD's "parallelogramization", 0.0 = none) — and the live-frame mirror.
##
## Geometry tests pass the dials EXPLICITLY so tuning the class defaults
## (that's the whole point of the dials) never breaks the suite.


func test_pole_lies_down_pointing_right() -> void:
	# A 1px-wide column with a gap in the middle: [head, GAP, feet] top-down,
	# pivot at the bottom of the column.
	var pole := Image.create(1, 3, false, Image.FORMAT_RGBA8)
	pole.set_pixel(0, 0, Color.WHITE)  # head
	pole.set_pixel(0, 2, Color.WHITE)  # feet
	var projected := UnitShadow.project_silhouette(pole, Vector2(0, 3), 1.0, 1.0, 0.0)
	assert_eq(projected["image"].get_size(), Vector2i(3, 1),
			"A standing pole lies down: height becomes rightward length.")
	assert_eq(projected["anchor"], Vector2(0, 0),
			"The feet pixel stays at the feet.")
	assert_gt(projected["image"].get_pixel(0, 0).a, 0.5, "Feet pixel at the feet.")
	assert_eq(projected["image"].get_pixel(1, 0).a, 0.0, "The gap travels with the body.")
	assert_gt(projected["image"].get_pixel(2, 0).a, 0.5, "Head lands farthest right.")


func test_casters_right_edge_lands_below_the_feet_line() -> void:
	# One row, opaque only on the caster's right: rolling right onto its back
	# puts the right edge down-screen (below the feet line).
	var row := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	row.set_pixel(1, 0, Color.WHITE)
	var projected := UnitShadow.project_silhouette(row, Vector2(0, 1), 1.0, 1.0, 0.0)
	assert_eq(projected["image"].get_size(), Vector2i(1, 1))
	assert_eq(projected["anchor"], Vector2(0, 1),
			"The caster's right edge sits one pixel down-screen of the feet line.")


func test_below_pivot_content_lands_left_of_the_feet() -> void:
	# The berzerker regression ("Are they being smooshed?"): art below the
	# pivot — hanging flails, boots — must cast (left of the feet), not be
	# amputated by a crop at the pivot line.
	var column := Image.create(1, 4, false, Image.FORMAT_RGBA8)
	column.fill(Color.WHITE)
	var projected := UnitShadow.project_silhouette(column, Vector2(0, 2), 1.0, 1.0, 0.0)
	assert_eq(projected["image"].get_size(), Vector2i(4, 1),
			"All four rows cast — two above the pivot, two below.")
	assert_eq(projected["anchor"], Vector2(-2, 0),
			"Below-pivot rows land LEFT of the feet — the rigid turn, whole.")


func test_smoosh_y_flattens_about_the_feet_line() -> void:
	var row := Image.create(4, 1, false, Image.FORMAT_RGBA8)
	row.fill(Color.WHITE)
	var full := UnitShadow.project_silhouette(row, Vector2(0, 1), 1.0, 1.0, 0.0)
	assert_eq(full["image"].get_height(), 4,
			"smoosh_y 1.0 is the undistorted turn — width becomes full vertical span.")
	var smooshed := UnitShadow.project_silhouette(row, Vector2(0, 1), 1.0, 0.5, 0.0)
	assert_eq(smooshed["image"].get_height(), 2,
			"smoosh_y 0.5 halves the vertical span about the feet line.")


func test_smoosh_x_shortens_the_reach() -> void:
	# A 4px pole lying down reaches 4px right; smoosh_x 0.5 (higher sun)
	# pulls the tip back to 2px. The feet pixel never moves.
	var column := Image.create(1, 4, false, Image.FORMAT_RGBA8)
	column.fill(Color.WHITE)
	var full := UnitShadow.project_silhouette(column, Vector2(0, 4), 1.0, 1.0, 0.0)
	assert_eq(full["image"].get_width(), 4,
			"smoosh_x 1.0 is the undistorted turn — height becomes full reach.")
	var shortened := UnitShadow.project_silhouette(column, Vector2(0, 4), 0.5, 1.0, 0.0)
	assert_eq(shortened["image"].get_width(), 2,
			"smoosh_x 0.5 halves the reach about the feet point.")
	assert_eq(shortened["anchor"], Vector2(0, 0),
			"The feet pixel stays at the feet regardless of sun elevation.")


func test_shear_leans_the_shadow() -> void:
	var row := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	row.fill(Color.WHITE)
	var sheared := UnitShadow.project_silhouette(row, Vector2(0, 1), 1.0, 1.0, 1.0)
	assert_eq(sheared["image"].get_size(), Vector2i(2, 2),
			"Shear 1.0 turns the vertical pair into a diagonal — a parallelogram.")
	assert_gt(sheared["image"].get_pixel(0, 0).a, 0.5)
	assert_gt(sheared["image"].get_pixel(1, 1).a, 0.5)
	assert_eq(sheared["image"].get_pixel(1, 0).a, 0.0)
	assert_eq(sheared["image"].get_pixel(0, 1).a, 0.0)


func test_blob_welds_the_gap_between_spread_feet() -> void:
	# RQD's wide-stance problem: two legs cast two disconnected strips.
	# Feet as two opaque pixels with a gap between them, pivot centered:
	var stance := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	stance.set_pixel(0, 0, Color.WHITE)
	stance.set_pixel(2, 0, Color.WHITE)
	var bare := UnitShadow.project_silhouette(stance, Vector2(1, 1), 1.0, 1.0, 0.0)
	assert_eq(bare["image"].get_pixel(0, 1).a, 0.0,
			"Without the blob, the gap between the feet casts nothing.")
	var welded := UnitShadow.project_silhouette(
			stance, Vector2(1, 1), 1.0, 1.0, 0.0, 1.5)
	var feet_center := Vector2i(Vector2(0, 0) - welded["anchor"])
	assert_gt(welded["image"].get_pixel(feet_center.x, feet_center.y).a, 0.5,
			"The contact disc fills the stance gap at the feet point.")


func test_blob_inherits_the_dials() -> void:
	var row := Image.create(5, 1, false, Image.FORMAT_RGBA8)
	row.fill(Color.WHITE)
	# Disc radius 2.5 → undistorted disc spans cy −2..+2.
	var round_blob := UnitShadow.project_silhouette(
			row, Vector2(2, 1), 1.0, 1.0, 0.0, 2.5)
	assert_eq(round_blob["image"].get_height(), 5,
			"Undistorted disc: full circle around the feet point.")
	var squashed_blob := UnitShadow.project_silhouette(
			row, Vector2(2, 1), 1.0, 0.5, 0.0, 2.5)
	assert_eq(squashed_blob["image"].get_height(), 3,
			"smoosh_y flattens the disc into the ellipse — the dials apply.")


func test_stance_radius_measures_the_feet_not_the_widest_points() -> void:
	# 12-wide canvas: "arms" span the full width up high (row 2), "boots"
	# span x 3..8 in the bottom two rows, and a stray 1px cape tip touches
	# the ground at x 0. The band ignores the arms; the trim sheds the tip.
	var art := Image.create(12, 10, false, Image.FORMAT_RGBA8)
	for x in range(12):
		art.set_pixel(x, 2, Color.WHITE)  # arms + rifle, high up
	for y in range(8, 10):
		for x in range(3, 9):
			art.set_pixel(x, y, Color.WHITE)  # boots
	art.set_pixel(0, 9, Color.WHITE)  # cape tip at ground level
	var texture := ImageTexture.create_from_image(art)
	var radius := UnitShadow.measure_stance_radius(texture, 4, 0.1)
	assert_eq(radius, 3.0,
			"Stance = boots width 6 / 2. Arms (band) and cape tip (trim) shed.")


func test_stance_radius_is_zero_without_readable_ink() -> void:
	var clear := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	assert_eq(UnitShadow.measure_stance_radius(
			ImageTexture.create_from_image(clear)), 0.0,
			"No opaque pixels → no stance → no blob.")


func test_mask_is_flat_white_silhouette() -> void:
	var silhouette := Image.create(1, 2, false, Image.FORMAT_RGBA8)
	silhouette.set_pixel(0, 0, Color(0.2, 0.8, 0.3, 1.0))  # opaque, colored
	silhouette.set_pixel(0, 1, Color(1.0, 1.0, 1.0, 0.3))  # semi-transparent
	var projected := UnitShadow.project_silhouette(silhouette, Vector2(0, 2), 1.0, 1.0, 0.0)
	assert_eq(projected["image"].get_size(), Vector2i(1, 1),
			"Semi-transparent edge texels don't cast — the ink crops tight.")
	assert_eq(projected["image"].get_pixel(0, 0), Color.WHITE,
			"Opaque pixels cast flat white — draw modulate supplies the ink.")


func test_nothing_casts_returns_empty() -> void:
	assert_true(UnitShadow.project_silhouette(null, Vector2.ZERO).is_empty(),
			"No silhouette (unreadable texture) → no shadow.")
	var clear := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	assert_true(UnitShadow.project_silhouette(clear, Vector2(1, 1)).is_empty(),
			"A fully transparent frame casts nothing.")


func test_shadow_sits_in_the_terrain_effects_slot_of_its_row() -> void:
	var shadow := UnitShadow.new()
	add_child_autofree(shadow)
	assert_true(shadow.z_as_relative)
	assert_eq(shadow.z_index,
			ZIndexCalculator.ZIndexLayer.TERRAIN_EFFECTS
			- ZIndexCalculator.ZIndexLayer.UNITS,
			"Relative slot must land in the decoration-shadow band of the unit's own row.")
	assert_eq(shadow.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)


func test_sync_builds_a_projection_and_mirrors_ground_motion() -> void:
	var source := Sprite2D.new()
	source.texture = load("res://art/sprites/characters/placeholder_unit.png")
	source.position = Vector2(6.0, 0.0)  # mid-boop lunge
	add_child_autofree(source)
	var shadow := UnitShadow.new()
	shadow.source_sprite = source
	add_child_autofree(shadow)

	shadow.sync_to_source()

	assert_true(shadow.visible)
	assert_not_null(shadow._projection,
			"A readable frame must rasterize into a cached shadow image.")
	assert_eq(shadow._ground_offset, source.position,
			"The lunge is ground motion — mirrored 1:1 around the projection.")


func test_feet_drop_moves_the_pivot_to_the_boots() -> void:
	# Body-centered cast: the node origin is the waist; feet_drop tells the
	# shadow where the boots are. Every row above the true feet counts as
	# height, so the same frame casts farther right — anchor.x shifts by
	# exactly the drop.
	var source := Sprite2D.new()
	source.texture = load("res://art/sprites/characters/placeholder_unit.png")
	add_child_autofree(source)
	var shadow := UnitShadow.new()
	shadow.source_sprite = source
	add_child_autofree(shadow)

	shadow.sync_to_source()
	var waist_anchor: Vector2 = shadow._projection_anchor

	shadow.feet_drop = 10.0
	shadow._rebuild_projection()
	# No anchor.x claim here: with the blob enabled the feet-centered disc
	# pins the left edge, so X is legitimately feet_drop-invariant. Reach
	# geometry is pinned by the pure-function tests.
	assert_eq(shadow._projection_anchor.y, waist_anchor.y + 10.0,
			"The DRAWN smear rides down with the feet — anchor is node-space, "
			+ "not pivot-space (the waist-origin bug RQD measured at −12).")


func test_spawned_unit_hands_the_feet_line_to_its_shadow() -> void:
	# The REAL spawn flow, mirroring BattleScene._create_unit_from_data:
	# scene instantiate → add_child → initialize. Pins the whole chain
	# sidecar art_bounds.bottom → Unit._art_feet_drop → UnitShadow.feet_drop
	# (desert_sniper: art bottom 46 − center pivot 32 = 14).
	var unit: Unit = (load("res://scenes/battle/unit.tscn") as PackedScene).instantiate() as Unit
	unit.character_data = CharacterDataLoader.load_character(
			"res://data/characters/desert_sniper.json")
	unit.faction = Enums.UnitFaction.PLAYER
	add_child_autofree(unit)
	# autofree, NOT add_child_autofree: a bare Tile's _ready expects scene
	# children; move_to_tile doesn't need the tile in the tree.
	var tile: Tile = autofree(Tile.new())
	unit.initialize(tile)

	assert_eq(unit._art_feet_drop, 14.0,
			"Sidecar parse: art_bounds.bottom 46 − pivot.y 32.")
	assert_not_null(unit._shadow, "The scene unit spawns its shadow in _ready.")
	assert_eq(unit._shadow.feet_drop, 14.0,
			"initialize() must hand the feet line to the shadow.")
	unit._shadow.sync_to_source()
	assert_not_null(unit._shadow._projection,
			"The spawned sniper casts from the boots-pivot projection.")
	assert_eq(unit.character_data.shadow_blob_radius, -1.0,
			"No JSON override → the -1 sentinel → the measured path.")
	assert_gt(unit._shadow.blob_radius, 0.0,
			"The idle stance measurement reaches the shadow at spawn.")


func test_atlas_character_hands_the_feet_line_to_its_shadow() -> void:
	# The Blood Mage floating-smear bug (RQD 2026-08-03): atlas-path
	# characters have no pivot sidecar, so _art_feet_drop stayed 0 and the
	# whole cast pivoted at the WAIST — a smear floating at mid-body,
	# glaring next to the pixel-identical (but sidecar'd) Occult whose
	# shadow hugged the ground. The trim rect's bottom edge is the art
	# bottom: frame 8 trims to y 17..59 on a 96 canvas → feet 12 below the
	# node origin.
	var unit: Unit = (load("res://scenes/battle/unit.tscn") as PackedScene).instantiate() as Unit
	unit.character_data = CharacterDataLoader.load_character(
			"res://data/characters/blood_mage.json")
	unit.faction = Enums.UnitFaction.ENEMY
	add_child_autofree(unit)
	var tile: Tile = autofree(Tile.new())
	unit.initialize(tile)

	assert_eq(unit._art_feet_drop, 12.0,
			"Trim bottom (17 + 43) − canvas center 48 = 12.")
	assert_not_null(unit._shadow, "The scene unit spawns its shadow in _ready.")
	assert_eq(unit._shadow.feet_drop, 12.0,
			"initialize() hands the atlas feet line to the shadow.")
	unit._shadow.sync_to_source()
	assert_not_null(unit._shadow._projection,
			"AtlasTexture frames read back and cast (Godot 4.7).")
	assert_gt(unit._shadow.blob_radius, 0.0,
			"The stance measurement reads through the AtlasTexture too.")


func test_atlas_frame_textures_are_shared_instances() -> void:
	# UnitShadow's static projection cache keys on the texture RID. A fresh
	# AtlasTexture per load (every _restore_idle_sprite after an attack)
	# meant a new RID → cache miss → re-rasterize + unbounded cache growth.
	var first := SpriteAtlasLoader.get_frame_texture(
			"res://art/sprites/characters/spaceman_sprites.png",
			"res://art/sprites/characters/spaceman_sprites.json", 8)
	var second := SpriteAtlasLoader.get_frame_texture(
			"res://art/sprites/characters/spaceman_sprites.png",
			"res://art/sprites/characters/spaceman_sprites.json", 8)
	assert_not_null(first)
	assert_true(first == second,
			"Repeat loads of the same frame return the SAME AtlasTexture.")


func test_character_json_override_beats_the_measurement() -> void:
	# The escape hatch: an authored sprite.shadowBlobRadius wins verbatim,
	# and an explicit 0 means "casts no blob" — distinct from unset (-1).
	var overridden := _spawn_sniper_with_blob_override(5.0)
	assert_eq(overridden._shadow.blob_radius, 5.0,
			"Authored radius used verbatim; measurement skipped.")
	var ghost := _spawn_sniper_with_blob_override(0.0)
	assert_eq(ghost._shadow.blob_radius, 0.0,
			"Explicit zero is a real value (no blob), not treated as unset.")


func _spawn_sniper_with_blob_override(radius: float) -> Unit:
	var unit: Unit = (load("res://scenes/battle/unit.tscn") as PackedScene).instantiate() as Unit
	unit.character_data = CharacterDataLoader.load_character(
			"res://data/characters/desert_sniper.json")
	unit.character_data.shadow_blob_radius = radius
	unit.faction = Enums.UnitFaction.PLAYER
	add_child_autofree(unit)
	var tile: Tile = autofree(Tile.new())
	unit.initialize(tile)
	return unit


func test_loader_parses_the_shadow_blob_override() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/characters/desert_sniper.json"))
	source["sprite"]["shadowBlobRadius"] = 2.5
	var fixture_path := "user://test_shadow_blob_override.json"
	var out := FileAccess.open(fixture_path, FileAccess.WRITE)
	out.store_string(JSON.stringify(source))
	out.close()
	var character := CharacterDataLoader.load_character(fixture_path)
	DirAccess.remove_absolute(fixture_path)
	assert_eq(character.shadow_blob_radius, 2.5,
			"sprite.shadowBlobRadius round-trips through the loader.")


func test_shadow_hides_with_its_source_and_without_one() -> void:
	var shadow := UnitShadow.new()
	add_child_autofree(shadow)
	shadow.sync_to_source()
	assert_false(shadow.visible, "No source sprite → no shadow (bare test units).")

	var source := Sprite2D.new()
	source.texture = load("res://art/sprites/characters/placeholder_unit.png")
	source.visible = false
	add_child_autofree(source)
	shadow.source_sprite = source
	shadow.sync_to_source()
	assert_false(shadow.visible, "Hidden sprite (death, etc.) → hidden shadow.")

	source.visible = true
	shadow.sync_to_source()
	assert_true(shadow.visible)


func test_debug_toggle_kills_the_shadow() -> void:
	var source := Sprite2D.new()
	source.texture = load("res://art/sprites/characters/placeholder_unit.png")
	add_child_autofree(source)
	var shadow := UnitShadow.new()
	shadow.source_sprite = source
	add_child_autofree(shadow)

	DebugConfig.unit_cast_shadows = false
	shadow.sync_to_source()
	assert_false(shadow.visible)

	DebugConfig.unit_cast_shadows = true
	shadow.sync_to_source()
	assert_true(shadow.visible)
