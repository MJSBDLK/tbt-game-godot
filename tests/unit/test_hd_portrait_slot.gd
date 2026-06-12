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
