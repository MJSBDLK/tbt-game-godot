## VoidLockOverlay.set_locked drives the chip's `lock_desaturate` uniform and
## attaches/removes the shadow+sparkle overlay child. Pure UI-component behavior;
## the in-engine look is eyeballed separately (motes animate off TIME).
extends GutTest

const MOVE_CHIP_FILL: Shader = preload("res://resources/shaders/move_chip_fill.gdshader")


func _chip() -> ColorRect:
	var chip := ColorRect.new()
	add_child_autofree(chip)
	var mat := ShaderMaterial.new()
	mat.shader = MOVE_CHIP_FILL
	chip.material = mat
	return chip


func _overlay_count(chip: ColorRect) -> int:
	var count := 0
	for child: Node in chip.get_children():
		if child is VoidLockOverlay:
			count += 1
	return count


func test_lock_sets_desaturate_and_adds_overlay() -> void:
	var chip := _chip()
	VoidLockOverlay.set_locked(chip, true)
	assert_eq((chip.material as ShaderMaterial).get_shader_parameter("lock_desaturate"), 1.0,
			"chip body fully desaturated when locked")
	assert_eq(_overlay_count(chip), 1, "shadow/sparkle overlay added")


func test_unlock_clears_desaturate_and_hides_overlay() -> void:
	var chip := _chip()
	VoidLockOverlay.set_locked(chip, true)
	VoidLockOverlay.set_locked(chip, false)
	assert_eq((chip.material as ShaderMaterial).get_shader_parameter("lock_desaturate"), 0.0,
			"desaturate cleared on unlock")
	var overlay: VoidLockOverlay = chip.get_node_or_null(VoidLockOverlay.NODE_NAME)
	assert_true(overlay == null or not overlay.visible, "overlay hidden on unlock")


func test_unlock_on_fresh_chip_adds_nothing() -> void:
	var chip := _chip()
	VoidLockOverlay.set_locked(chip, false)
	assert_eq(_overlay_count(chip), 0, "never-locked chip stays clean")


func test_repeated_lock_does_not_stack_overlays() -> void:
	var chip := _chip()
	VoidLockOverlay.set_locked(chip, true)
	VoidLockOverlay.set_locked(chip, true)
	assert_eq(_overlay_count(chip), 1, "idempotent — one overlay regardless of repeats")


func test_null_chip_is_safe() -> void:
	VoidLockOverlay.set_locked(null, true)
	assert_true(true, "no crash toggling a null chip")
