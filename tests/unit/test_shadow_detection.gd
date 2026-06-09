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
# Bbox padding to cell multiples
# =============================================================================

func test_pad_bbox_round_to_cells() -> void:
	# 19x40 content centered in 128x128 canvas → padded to 32x64 (1x2 cells).
	# Bottom-aligned, so y-end stays where content y-end was.
	var src_bbox := Rect2i(50, 30, 19, 40)  # ends at y=70
	var padded: Rect2i = ContextMenu._pad_bbox_to_cells(src_bbox, Vector2i(128, 128))
	assert_eq(padded.size, Vector2i(32, 64),
			"19x40 rounds up to 32x64 (1x2 cells)")
	assert_eq(padded.position.y + padded.size.y, 70,
			"Bottom edge preserved (bottom-aligned padding)")


func test_pad_bbox_no_op_when_already_cell_sized() -> void:
	# 32x32 stays 32x32.
	var src_bbox := Rect2i(0, 0, 32, 32)
	var padded: Rect2i = ContextMenu._pad_bbox_to_cells(src_bbox, Vector2i(128, 128))
	assert_eq(padded.size, Vector2i(32, 32))


func test_pad_bbox_clamps_to_canvas() -> void:
	# Content near top edge — padded rect would extend above canvas, clamp it.
	var src_bbox := Rect2i(50, 5, 19, 30)
	var padded: Rect2i = ContextMenu._pad_bbox_to_cells(src_bbox, Vector2i(128, 128))
	assert_true(padded.position.y >= 0, "Padded rect doesn't go negative")
	assert_true(padded.position.y + padded.size.y <= 128, "Padded rect fits canvas")


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
