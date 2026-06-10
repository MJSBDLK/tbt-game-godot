## Tests for the Aseprite tag exporter's pure-logic helpers — shadow
## signature detection, content bbox, padded crop math, and bbox union.
## Helpers live as static methods on the @tool plugin script; preload
## reaches them without instantiating the editor plugin itself.
extends GutTest


const ContextMenu = preload("res://addons/aseprite_tag_exporter/context_menu.gd")


# =============================================================================
# Shadow signature detection
# =============================================================================

func _make_image_filled(w: int, h: int, color: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img


func test_shadow_signature_matches_pure_black_at_40_percent_alpha() -> void:
	# Exactly RGB(0,0,0) / alpha 102 — Lawrence's emitted convention.
	var img := _make_image_filled(4, 4, Color8(0, 0, 0, 102))
	assert_true(ContextMenu._image_matches_shadow_signature(img),
			"Pure black at A=102 must register as shadow")


func test_shadow_signature_rejects_fully_transparent_image() -> void:
	# Empty image has no opaque pixels to even check.
	var img := _make_image_filled(4, 4, Color(0, 0, 0, 0))
	assert_false(ContextMenu._image_matches_shadow_signature(img),
			"Empty image is empty, not shadow")


func test_shadow_signature_rejects_colored_pixels() -> void:
	# Single off-color pixel disqualifies the whole image.
	var img := _make_image_filled(4, 4, Color8(0, 0, 0, 102))
	img.set_pixel(2, 2, Color8(180, 60, 40, 102))  # rust pixel
	assert_false(ContextMenu._image_matches_shadow_signature(img),
			"Non-black pixel disqualifies shadow detection")


func test_shadow_signature_rejects_wrong_alpha() -> void:
	# Alpha 255 (fully opaque) is too far from 102.
	var img := _make_image_filled(4, 4, Color8(0, 0, 0, 255))
	assert_false(ContextMenu._image_matches_shadow_signature(img),
			"Pure black at fully opaque is not a 40% shadow")


func test_shadow_signature_accepts_small_alpha_variation() -> void:
	# Alpha 110 is within ±13 tolerance of 102.
	var img := _make_image_filled(4, 4, Color8(0, 0, 0, 110))
	assert_true(ContextMenu._image_matches_shadow_signature(img),
			"Small alpha drift within tolerance still reads as shadow")


func test_shadow_signature_ignores_transparent_pixels() -> void:
	# An image with mixed transparent + shadow-colored opaque pixels still
	# matches as long as no opaque pixel violates the rule.
	var img := _make_image_filled(4, 4, Color(0, 0, 0, 0))
	img.set_pixel(1, 1, Color8(0, 0, 0, 102))
	img.set_pixel(2, 2, Color8(0, 0, 0, 102))
	assert_true(ContextMenu._image_matches_shadow_signature(img),
			"Mostly-transparent shadow with a couple opaque pixels still matches")


# =============================================================================
# Layer-name detection
# =============================================================================

func test_layer_name_exact_shadow_matches() -> void:
	assert_true(ContextMenu._is_shadow_layer_by_name("shadow"))
	assert_true(ContextMenu._is_shadow_layer_by_name("Shadow"))
	assert_true(ContextMenu._is_shadow_layer_by_name("SHADOW"))


func test_layer_name_suffix_shadow_matches() -> void:
	assert_true(ContextMenu._is_shadow_layer_by_name("crater_shadow"))
	assert_true(ContextMenu._is_shadow_layer_by_name("TreeShadow_shadow"))
	assert_true(ContextMenu._is_shadow_layer_by_name("x_SHADOW"))


func test_layer_name_unrelated_does_not_match() -> void:
	assert_false(ContextMenu._is_shadow_layer_by_name("Object"))
	assert_false(ContextMenu._is_shadow_layer_by_name("Background"))
	assert_false(ContextMenu._is_shadow_layer_by_name("shadow_underlay"))  # not a suffix
	assert_false(ContextMenu._is_shadow_layer_by_name(""))


# =============================================================================
# Content bbox
# =============================================================================

func test_content_bbox_empty_image_returns_zero_rect() -> void:
	var img := _make_image_filled(8, 8, Color(0, 0, 0, 0))
	var bbox: Rect2i = ContextMenu._content_bbox(img)
	assert_eq(bbox.size, Vector2i.ZERO,
			"Empty image has no content bbox")


func test_content_bbox_tight_to_opaque_pixels() -> void:
	var img := _make_image_filled(10, 10, Color(0, 0, 0, 0))
	img.set_pixel(2, 3, Color8(255, 0, 0, 255))
	img.set_pixel(6, 7, Color8(0, 255, 0, 255))
	var bbox: Rect2i = ContextMenu._content_bbox(img)
	assert_eq(bbox.position, Vector2i(2, 3))
	assert_eq(bbox.size, Vector2i(5, 5))  # 2..6 = 5 wide, 3..7 = 5 tall


# =============================================================================
# Bbox padding around pivot
# =============================================================================

func test_pad_bbox_around_pivot_content_symmetric() -> void:
	# 30x30 content symmetric around pivot (64, 64): bbox (49, 49, 30, 30).
	# Should pad to 32x32 (next cell multiple containing 30) centered on pivot.
	var src_bbox := Rect2i(49, 49, 30, 30)
	var pivot := Vector2i(64, 64)
	var padded: Rect2i = ContextMenu._pad_bbox_around_pivot(src_bbox, pivot, Vector2i(128, 128))
	assert_eq(padded.size, Vector2i(32, 32),
			"30x30 symmetric content pads to 32x32 (1x1 cell)")
	# Pivot lands at center of padded rect.
	assert_eq(pivot - padded.position, Vector2i(16, 16),
			"Pivot at (16, 16) in cropped image == center of 32x32")


func test_pad_bbox_around_pivot_asymmetric_expands_to_contain() -> void:
	# Content extends further left of pivot (24) than right (4). Padded width
	# must cover the worse half (24), so full extent ≥ 48 → rounds up to 64.
	var src_bbox := Rect2i(40, 60, 28, 8)  # pivot at 64 → dist_left=24, dist_right=4
	var pivot := Vector2i(64, 64)
	var padded: Rect2i = ContextMenu._pad_bbox_around_pivot(src_bbox, pivot, Vector2i(128, 128))
	assert_eq(padded.size.x, 64,
			"Asymmetric content expands the rect on both sides of pivot (2 cells wide)")
	# Pivot still at the center of the padded rect (no clamping happened).
	assert_eq(pivot.x - padded.position.x, 32,
			"Pivot at x=32 in cropped == center of 64-wide image")


func test_pad_bbox_around_pivot_minimum_one_cell() -> void:
	# A tiny 5x5 content still produces at least a 32x32 padded output.
	var src_bbox := Rect2i(62, 62, 5, 5)
	var pivot := Vector2i(64, 64)
	var padded: Rect2i = ContextMenu._pad_bbox_around_pivot(src_bbox, pivot, Vector2i(128, 128))
	assert_eq(padded.size, Vector2i(32, 32),
			"Tiny content still produces minimum 1x1 cell output")


func test_pad_bbox_around_pivot_clamps_to_canvas_edge() -> void:
	# Pivot near canvas edge — padded rect would extend past the boundary, clamp.
	var src_bbox := Rect2i(5, 5, 10, 10)
	var pivot := Vector2i(10, 10)
	var padded: Rect2i = ContextMenu._pad_bbox_around_pivot(src_bbox, pivot, Vector2i(128, 128))
	assert_true(padded.position.x >= 0, "Padded rect can't have negative position")
	assert_true(padded.position.y >= 0, "Padded rect can't have negative position")
	assert_true(padded.position.x + padded.size.x <= 128, "Padded rect fits canvas")
	assert_true(padded.position.y + padded.size.y <= 128, "Padded rect fits canvas")


# =============================================================================
# Dimension suffix parsing — Lawrence's `_WxH` tag-name convention
# =============================================================================

func test_dimension_suffix_parses_1x1() -> void:
	var info: Dictionary = ContextMenu._parse_dimension_suffix("arch_a_1x1")
	assert_eq(info["footprint"], Vector2i(1, 1))
	assert_eq(info["basename"], "arch_a")


func test_dimension_suffix_parses_multi_cell() -> void:
	var info: Dictionary = ContextMenu._parse_dimension_suffix("castle_a_2x2")
	assert_eq(info["footprint"], Vector2i(2, 2))
	assert_eq(info["basename"], "castle_a")
	var info2: Dictionary = ContextMenu._parse_dimension_suffix("building_b_3x2")
	assert_eq(info2["footprint"], Vector2i(3, 2))
	assert_eq(info2["basename"], "building_b")


func test_dimension_suffix_handles_no_suffix() -> void:
	# Character workflow: tags like "idle" or "melee" have no dimension suffix.
	# Returns zero footprint and unchanged basename so the existing pipeline
	# falls through to bbox-derived sizing.
	var info: Dictionary = ContextMenu._parse_dimension_suffix("idle")
	assert_eq(info["footprint"], Vector2i.ZERO)
	assert_eq(info["basename"], "idle")
	var info2: Dictionary = ContextMenu._parse_dimension_suffix("melee_long")
	assert_eq(info2["footprint"], Vector2i.ZERO)
	assert_eq(info2["basename"], "melee_long")


func test_dimension_suffix_only_matches_at_end() -> void:
	# "10x10" anywhere except the end shouldn't match (false positive guard).
	var info: Dictionary = ContextMenu._parse_dimension_suffix("size_10x10_test")
	assert_eq(info["footprint"], Vector2i.ZERO,
			"_WxH must be at end of name, not in middle")


# =============================================================================
# Cell-aligned crop for sprites with marked footprints
# =============================================================================

func test_crop_for_footprint_fits_in_minimum_when_content_is_small() -> void:
	# Tiny content centered on pivot, footprint 1x1. Output should be exactly
	# 32x32 (the minimum for a 1x1 footprint).
	var bbox := Rect2i(62, 62, 5, 5)
	var pivot := Vector2i(64, 64)
	var fp := Vector2i(1, 1)
	var rect: Rect2i = ContextMenu._crop_rect_around_pivot_for_footprint(
			bbox, pivot, Vector2i(128, 128), fp)
	assert_eq(rect.size, Vector2i(32, 32))
	# Pivot lands at exact center of the 32x32 (cell center for 1x1).
	assert_eq(pivot - rect.position, Vector2i(16, 16))


func test_crop_for_footprint_expands_to_3_cells_when_overhang_present() -> void:
	# Content extends 24 px above the pivot (e.g. a tall tree above its
	# trunk). 1x1 footprint can't fit (half-extent of 16 < 24), so the
	# output expands to footprint + 2k = 3 cells (= 96 px), giving 48 px
	# of half-extent on each side.
	var bbox := Rect2i(56, 40, 16, 32)  # extends from y=40 to y=72 around pivot y=64
	var pivot := Vector2i(64, 64)
	var fp := Vector2i(1, 1)
	var rect: Rect2i = ContextMenu._crop_rect_around_pivot_for_footprint(
			bbox, pivot, Vector2i(128, 128), fp)
	# Output height jumps from 32 → 96 (1+2*1 cells), never 64.
	assert_eq(rect.size.y, 96,
			"1x1 footprint with vertical overhang pads to 96 (1+2 cells), not 64")
	# Pivot stays at PNG-center vertically; with 96 height, that's y=48 → cell 1 center.
	assert_eq(pivot.y - rect.position.y, 48)


func test_crop_for_footprint_2x2_pads_in_even_cell_count() -> void:
	# 2x2 footprint with horizontal overhang that exceeds 32 px past pivot.
	# Half-extent must be > 32 to push beyond 2x2's 64-wide native size.
	# Output pads to 2+2k cells = 4 (never 3, which wouldn't preserve the
	# 2x2 gameplay area's centering).
	var bbox := Rect2i(24, 56, 80, 16)  # x=24..104, half-extent 40 on each side of pivot
	var pivot := Vector2i(64, 64)
	var fp := Vector2i(2, 2)
	var rect: Rect2i = ContextMenu._crop_rect_around_pivot_for_footprint(
			bbox, pivot, Vector2i(256, 256), fp)
	assert_eq(rect.size.x, 128,
			"2x2 footprint with 40 px overhang pads to 128 (2+2 cells), not 96")
	# 2x2 footprint sits in the center cells [k, k+1] = [1, 2]. Pivot at PNG center
	# (x=64) is the boundary between cells 1 and 2.
	assert_eq(pivot.x - rect.position.x, 64)


func test_crop_for_footprint_minimum_size_when_no_content_overflow() -> void:
	# Content fits inside the marked footprint cleanly. Output stays at
	# exactly footprint × 32, no extra cells.
	var bbox := Rect2i(50, 56, 28, 16)
	var pivot := Vector2i(64, 64)
	var fp := Vector2i(2, 1)
	var rect: Rect2i = ContextMenu._crop_rect_around_pivot_for_footprint(
			bbox, pivot, Vector2i(128, 128), fp)
	assert_eq(rect.size, Vector2i(64, 32),
			"2x1 footprint with no overhang stays at 64x32")


# =============================================================================
# Bbox union
# =============================================================================

func test_bbox_union_returns_other_when_one_is_empty() -> void:
	var empty := Rect2i()
	var real := Rect2i(5, 5, 10, 10)
	assert_eq(ContextMenu._bbox_union(empty, real), real)
	assert_eq(ContextMenu._bbox_union(real, empty), real)


func test_bbox_union_covers_both_inputs() -> void:
	var a := Rect2i(5, 5, 10, 10)   # 5,5 to 15,15
	var b := Rect2i(20, 8, 5, 4)    # 20,8 to 25,12
	var u: Rect2i = ContextMenu._bbox_union(a, b)
	assert_eq(u.position, Vector2i(5, 5))
	assert_eq(u.size, Vector2i(20, 10))  # 5..25 = 20 wide, 5..15 = 10 tall (b's height fits within)


# =============================================================================
# Integration — layer parser against Lawrence's real test asset
# =============================================================================

func test_parse_layers_finds_object_and_shadow_in_test_asset() -> void:
	# Lawrence's bundle file has exactly two image layers: Object + Shadow.
	# If this regresses, either the .aseprite binary format changed or the
	# parser drifted.
	var asset_path := "res://art/sprites/decorations/decorations_and_modifiers.aseprite"
	if not FileAccess.file_exists(asset_path):
		pending("test asset not present — skipping")
		return
	var global_path: String = ProjectSettings.globalize_path(asset_path)
	var names: Array[String] = ContextMenu._parse_layers(global_path)
	assert_true(names.has("Object"), "Object layer must be detected (found: %s)" % str(names))
	assert_true(names.has("Shadow"), "Shadow layer must be detected (found: %s)" % str(names))
