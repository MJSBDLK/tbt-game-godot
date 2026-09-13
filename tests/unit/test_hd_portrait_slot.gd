## Regression tests for HDPortraitSlot's effects-toggle gating.
##
## The bug: with Portrait FX toggled OFF, rebinding a portrait (character_portrait
## reassigning slot.projection_material) smuggled the VHS tracking shader back
## onto the mirror — glass overlay stayed off (its visibility is separately
## gated) but tracking distortion came back. Every path that writes
## _mirror.material must honor _effects_disabled().
##
## Slots are built with .new() (so _ready never fires — no SceneRouter / HDLayer
## needed) and handed a bare TextureRect as their _mirror, so the setter logic is
## exercised in isolation. We mutate the live Settings autoload's plain field
## directly (not the persisting setter) and restore it after each test.
extends GutTest

var _saved_enabled: bool


func before_each() -> void:
	_saved_enabled = Settings.portrait_effects_enabled


func after_each() -> void:
	Settings.portrait_effects_enabled = _saved_enabled


func _make_slot_with_mirror() -> HDPortraitSlot:
	var slot := HDPortraitSlot.new()
	autofree(slot)
	var mirror := TextureRect.new()
	autofree(mirror)
	slot._mirror = mirror
	return slot


func test_assigning_projection_material_while_disabled_keeps_mirror_clean() -> void:
	# THE regression: this is exactly what character_portrait does on every
	# rebind. With effects off it must NOT land on the mirror.
	Settings.portrait_effects_enabled = false
	var slot := _make_slot_with_mirror()
	slot.projection_material = ShaderMaterial.new()
	assert_null(slot._mirror.material,
			"Reassigning projection_material while effects are off must not re-apply the shader")


func test_assigning_projection_material_while_enabled_applies_it() -> void:
	Settings.portrait_effects_enabled = true
	var slot := _make_slot_with_mirror()
	var material := ShaderMaterial.new()
	slot.projection_material = material
	assert_eq(slot._mirror.material, material,
			"With effects on, projection_material is applied to the mirror")


func test_toggling_off_clears_an_already_applied_material() -> void:
	# Apply while enabled, then flip the setting off — the slot re-applies state
	# from the Settings.changed signal in the live game; here we drive it directly.
	Settings.portrait_effects_enabled = true
	var slot := _make_slot_with_mirror()
	var material := ShaderMaterial.new()
	slot.projection_material = material
	assert_eq(slot._mirror.material, material, "applied while enabled")

	Settings.portrait_effects_enabled = false
	slot._apply_effects_state()
	assert_null(slot._mirror.material, "cleared when effects toggled off")


func test_debug_bypass_also_clears_material() -> void:
	# The dev left-click bypass (DebugConfig) is OR'd with the user setting —
	# either one off means effects off.
	Settings.portrait_effects_enabled = true
	var saved_debug: bool = DebugConfig.debug_portrait_effects_disabled
	DebugConfig.debug_portrait_effects_disabled = true
	var slot := _make_slot_with_mirror()
	slot.projection_material = ShaderMaterial.new()
	assert_null(slot._mirror.material,
			"Debug bypass clears the mirror material even with the user setting on")
	DebugConfig.debug_portrait_effects_disabled = saved_debug


# =============================================================================
# Readied before GameRoot registers (or never, under GUT): the slot must WAIT
# for SceneRouter.game_root_registered, not poll with call_deferred. The old
# self-deferring retry re-ran inside the same message-queue flush and, with no
# HDLayer ever coming, filled the queue and crashed the runner.
# =============================================================================

func test_a_slot_readied_without_an_hd_layer_waits_for_registration() -> void:
	assert_null(SceneRouter.get_hd_layer(), "precondition: GUT never registers a GameRoot")
	var host := TextureRect.new()
	add_child_autofree(host)
	var slot := HDPortraitSlot.new()
	slot.hd_texture = PlaceholderTexture2D.new()
	slot.overlay_material = ShaderMaterial.new()
	host.add_child(slot)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(slot._mirror, "no HDLayer → no mirror yet")
	assert_true(SceneRouter.game_root_registered.is_connected(slot._on_game_root_registered),
			"the slot is parked on the registration signal")

	# Registration arrives: the mirror and overlay land in the layer, in order.
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	SceneRouter._hd_layer = layer
	SceneRouter.game_root_registered.emit()
	SceneRouter._hd_layer = null
	assert_not_null(slot._mirror, "registration builds the mirror")
	assert_eq(slot._mirror.get_parent(), layer)
	assert_not_null(slot._overlay, "and the overlay")
	assert_eq(layer.get_child(0), slot._mirror, "mirror first so the overlay draws above it")
	assert_eq(slot._mirror.stretch_mode, TextureRect.STRETCH_SCALE,
			"the slot hands it an aspect-true rect; the mirror has nothing left to fit")
	assert_false(SceneRouter.game_root_registered.is_connected(slot._on_game_root_registered),
			"one-shot: the slot lets go of the signal once served")


# =============================================================================
# FIT — the art stands on the slot's floor. Square crops are the rule; a crop
# that disagrees with its box anyway is bottom-centered, never floating
# mid-frame with a band underneath. The crew file's frame ring hugs the same rect.
# =============================================================================

func test_a_wide_area_bottom_centers_the_art_at_full_height() -> void:
	# Square art in a 100×50 area: height-constrained to 50×50, centered.
	assert_eq(HDPortraitSlot.portrait_rect_in_area(Vector2(100, 50), 1.0),
			Rect2(25, 0, 50, 50))


func test_a_tall_area_bottom_aligns_the_art_at_full_width() -> void:
	# Square art in a 50×100 area: width-constrained to 50×50, on the floor.
	assert_eq(HDPortraitSlot.portrait_rect_in_area(Vector2(50, 100), 1.0),
			Rect2(0, 50, 50, 50))


func test_the_art_rect_is_pixel_snapped() -> void:
	# 101-wide area centers a 50-wide rect at 25.5 — floored, never fractional
	# (fractional rects shimmer in the pixel viewport).
	var rect: Rect2 = HDPortraitSlot.portrait_rect_in_area(Vector2(101, 50), 1.0)
	assert_eq(rect.position.x, 25.0)
	assert_eq(rect.size, Vector2(50, 50))


func test_a_tall_crop_never_overshoots_the_area() -> void:
	# 0.8 art in a 92 square: 73.6 wide rounds to 74, and 74 / 0.8 = 92.5 would
	# round past the floor. Height is the constraint, so it stays 92.
	var rect: Rect2 = HDPortraitSlot.portrait_rect_in_area(Vector2(92, 92), 0.8)
	assert_eq(rect, Rect2(9, 0, 74, 92))


func test_degenerate_areas_produce_an_empty_rect() -> void:
	assert_eq(HDPortraitSlot.portrait_rect_in_area(Vector2(0, 50), 1.0), Rect2())
	assert_eq(HDPortraitSlot.portrait_rect_in_area(Vector2(50, 50), 0.0), Rect2())


func _art(width: int, height: int) -> Texture2D:
	var texture := PlaceholderTexture2D.new()
	texture.size = Vector2(width, height)
	return texture


func test_a_wide_crop_in_a_square_slot_stands_on_the_floor() -> void:
	# A 1.15:1 crop in the detail panel's 92×92 box: full width, and the
	# spare height is all headroom.
	var slot := _make_slot_with_mirror()
	slot.hd_texture = _art(115, 100)
	var box := Rect2(Vector2(30, 30), Vector2(92, 92))
	var rect: Rect2 = slot.art_rect_in(box)
	assert_eq(rect.size, Vector2(92, 80), "width fills, height follows the crop")
	assert_eq(rect.end.y, box.end.y, "bottom edge on the floor")
	assert_eq(rect.position.x, box.position.x, "full width: no side offset")


func test_a_square_crop_fills_a_square_slot_exactly() -> void:
	var slot := _make_slot_with_mirror()
	slot.hd_texture = _art(1000, 1000)
	var box := Rect2(Vector2(30, 30), Vector2(92, 92))
	assert_eq(slot.art_rect_in(box), box)


func test_no_texture_uses_the_whole_slot() -> void:
	var slot := _make_slot_with_mirror()
	slot.hd_texture = null
	var box := Rect2(Vector2(30, 30), Vector2(92, 92))
	assert_eq(slot.art_rect_in(box), box)


func test_the_mirror_takes_the_art_rect_and_the_overlay_the_whole_slot() -> void:
	# In the tree so global_position resolves. No HDLayer under GUT, so hand
	# the slot a bare mirror + overlay and drive the geometry sync directly.
	var host := Control.new()
	add_child_autofree(host)
	var slot := HDPortraitSlot.new()
	host.add_child(slot)
	slot.position = Vector2(30, 30)
	slot.size = Vector2(92, 92)
	var mirror := TextureRect.new()
	autofree(mirror)
	# As the real mirror is built: without this a TextureRect refuses any size
	# below its texture's, and the fit would be masked.
	mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot._mirror = mirror
	var overlay := ColorRect.new()
	autofree(overlay)
	slot._overlay = overlay
	slot.hd_texture = _art(115, 100)  # the setter re-syncs geometry
	assert_eq(mirror.position, Vector2(30, 42), "mirror sits on the slot's floor")
	assert_eq(mirror.size, Vector2(92, 80))
	assert_eq(overlay.position, Vector2(30, 30), "glass covers the whole slot")
	assert_eq(overlay.size, Vector2(92, 92))
