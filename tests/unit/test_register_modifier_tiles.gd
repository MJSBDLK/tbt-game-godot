## Tests for the tile registration tool's pure planning helpers. The tool
## itself is a headless SceneTree script that rewrites battle_tileset.tres;
## preload reaches its statics without running it.
##
## The contract under test: SOURCE IDS ARE STABLE. A painted cell references
## (source_id, atlas_coords); renumbering a source silently repaints every
## map that used it.
extends GutTest


const Registrar = preload("res://tools/register_modifier_tiles.gd")

const BASE := 100


# =============================================================================
# plan_source_ids
# =============================================================================

func test_existing_sprites_keep_their_ids() -> void:
	var existing := {"castle_a": 110, "crater_a": 111, "arch_a": 100}
	var plan: Dictionary = Registrar.plan_source_ids(existing, ["arch_a", "castle_a", "crater_a"], BASE)
	var ids: Dictionary = plan["ids"]
	assert_eq(ids["arch_a"], 100)
	assert_eq(ids["castle_a"], 110)
	assert_eq(ids["crater_a"], 111)


func test_new_sprite_sorting_before_existing_does_not_shift_anyone() -> void:
	# THE regression: `bush_a` sorts between arch_a and castle_a. The old
	# tool re-minted in sorted order, so castle_a would have become 101 and
	# every castle painted anywhere would have turned into a bush.
	var existing := {"arch_a": 100, "castle_a": 101, "crater_a": 102}
	var plan: Dictionary = Registrar.plan_source_ids(
			existing, ["arch_a", "bush_a", "castle_a", "crater_a"], BASE)
	var ids: Dictionary = plan["ids"]
	assert_eq(ids["arch_a"], 100, "arch_a untouched")
	assert_eq(ids["castle_a"], 101, "castle_a untouched")
	assert_eq(ids["crater_a"], 102, "crater_a untouched")
	assert_eq(ids["bush_a"], 103, "newcomer appended above the highest id in use")


func test_new_sprites_append_in_sorted_order() -> void:
	var existing := {"arch_a": 100}
	var plan: Dictionary = Registrar.plan_source_ids(
			existing, ["zebra_a", "arch_a", "bush_a"], BASE)
	var ids: Dictionary = plan["ids"]
	assert_eq(ids["bush_a"], 101, "sorted: bush before zebra")
	assert_eq(ids["zebra_a"], 102)


func test_ids_append_above_gaps_not_into_them() -> void:
	# A hole in the id space (someone deleted 101 by hand) must NOT be
	# refilled: an old map might still reference it, and reviving the id
	# under a different sprite would repaint those cells.
	var existing := {"arch_a": 100, "crater_a": 102}
	var plan: Dictionary = Registrar.plan_source_ids(existing, ["arch_a", "crater_a", "new_a"], BASE)
	assert_eq(plan["ids"]["new_a"], 103, "new id goes above the max, never into the gap")


func test_empty_tileset_starts_at_base() -> void:
	var plan: Dictionary = Registrar.plan_source_ids({}, ["b", "a"], BASE)
	assert_eq(plan["ids"]["a"], BASE)
	assert_eq(plan["ids"]["b"], BASE + 1)


func test_stale_sources_are_reported_not_dropped() -> void:
	var existing := {"arch_a": 100, "ghost_a": 101}
	var plan: Dictionary = Registrar.plan_source_ids(existing, ["arch_a"], BASE)
	assert_eq(plan["stale"], ["ghost_a"], "sprite with no PNG is flagged")
	assert_eq(plan["ids"]["ghost_a"], 101, "…but keeps its id so painted cells don't orphan")


func test_plan_is_idempotent() -> void:
	var names := ["arch_a", "bush_a", "castle_a"]
	var first: Dictionary = Registrar.plan_source_ids({}, names, BASE)
	var second: Dictionary = Registrar.plan_source_ids(first["ids"], names, BASE)
	assert_eq(second["ids"], first["ids"], "re-running on its own output changes nothing")
	assert_eq(second["stale"].size(), 0)


# =============================================================================
# atlas_position_for — the footprint sits centered in the exported canvas
# =============================================================================

func test_atlas_position_1x1_no_overhang() -> void:
	assert_eq(Registrar.atlas_position_for(Vector2i(32, 32), Vector2i(1, 1), 32), Vector2i(0, 0))


func test_atlas_position_1x1_with_one_cell_overhang() -> void:
	# 96x96 tree: 1 cell of canopy/overhang on every side of the 1x1 trunk.
	assert_eq(Registrar.atlas_position_for(Vector2i(96, 96), Vector2i(1, 1), 32), Vector2i(1, 1))


func test_atlas_position_multi_cell() -> void:
	# 128x128 castle with a 2x2 footprint → one overhang cell per side.
	assert_eq(Registrar.atlas_position_for(Vector2i(128, 128), Vector2i(2, 2), 32), Vector2i(1, 1))
	# 160x128 building with a 3x2 footprint → (5-3)/2, (4-2)/2.
	assert_eq(Registrar.atlas_position_for(Vector2i(160, 128), Vector2i(3, 2), 32), Vector2i(1, 1))
	# Exporter contract violated (96px tall can't center a 2-row footprint):
	# integer division truncates toward the top-left rather than crashing.
	assert_eq(Registrar.atlas_position_for(Vector2i(160, 96), Vector2i(3, 2), 32), Vector2i(1, 0))
	# Wide 1-row arch: 96x32 with 1x1 footprint → centered column.
	assert_eq(Registrar.atlas_position_for(Vector2i(96, 32), Vector2i(1, 1), 32), Vector2i(1, 0))


func test_sprite_name_strips_png() -> void:
	assert_eq(Registrar.sprite_name_from_filename("castle_a.png"), "castle_a")


# =============================================================================
# restore_uids_in_text — headless ResourceSaver drops uid="..." attributes;
# the tool re-inserts them so a run's diff shows only real changes.
# =============================================================================

const _FAKE_UIDS := {
	"res://resources/battle_tileset.tres": "uid://tileset",
	"res://art/x/arch_a.png": "uid://arch",
}


func _fake_uid(path: String) -> String:
	return _FAKE_UIDS.get(path, "")


func test_restore_uids_reinserts_header_and_ext_resource_uids_in_canonical_order() -> void:
	var stripped := "\n".join([
		'[gd_resource type="TileSet" format=3]',
		'',
		'[ext_resource type="Texture2D" path="res://art/x/arch_a.png" id="3_i1d7l"]',
	])
	var restored := Registrar.restore_uids_in_text(
			stripped, "res://resources/battle_tileset.tres", _fake_uid)
	var lines := restored.split("\n")
	assert_eq(lines[0], '[gd_resource type="TileSet" format=3 uid="uid://tileset"]',
			"header gets the resource's own uid")
	assert_eq(lines[2], '[ext_resource type="Texture2D" uid="uid://arch" path="res://art/x/arch_a.png" id="3_i1d7l"]',
			"ext_resource uid lands between type and path, Godot's order")


func test_restore_uids_leaves_lines_that_already_have_one_alone() -> void:
	var intact := '[ext_resource type="Texture2D" uid="uid://keep" path="res://art/x/arch_a.png" id="1"]'
	assert_eq(Registrar.restore_uids_in_text(intact, "res://resources/battle_tileset.tres", _fake_uid),
			intact, "an existing uid is never rewritten")


func test_restore_uids_skips_unknown_paths_and_other_lines() -> void:
	var text := "\n".join([
		'[ext_resource type="Texture2D" path="res://art/x/unknown.png" id="9"]',
		'[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_x"]',
		'resource_name = "arch_a"',
	])
	assert_eq(Registrar.restore_uids_in_text(text, "res://nope.tres", _fake_uid), text,
			"unknown uid → untouched; non-resource lines untouched")


func test_restore_uids_is_idempotent() -> void:
	var stripped := '[gd_resource type="TileSet" format=3]\n[ext_resource type="Texture2D" path="res://art/x/arch_a.png" id="1"]'
	var once := Registrar.restore_uids_in_text(stripped, "res://resources/battle_tileset.tres", _fake_uid)
	var twice := Registrar.restore_uids_in_text(once, "res://resources/battle_tileset.tres", _fake_uid)
	assert_eq(twice, once)
