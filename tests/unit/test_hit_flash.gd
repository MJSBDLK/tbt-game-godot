## HitFlash: a struck unit's sprite flashes overbright and eases back, for as
## long as the hit's weight says, and a unit freed mid-flash takes the flash
## with it (a flash outliving its unit logged errors from a freed capture).
extends GutTest


func _target() -> Node2D:
	var target := Node2D.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	target.add_child(sprite)
	add_child(target)
	return target


func test_heavier_hits_flash_longer_within_the_bounds() -> void:
	assert_eq(HitFlash.duration_for(0.0), HitFlash.MIN_DURATION)
	assert_eq(HitFlash.duration_for(1.0), HitFlash.MAX_DURATION)
	assert_gt(HitFlash.duration_for(0.5), HitFlash.MIN_DURATION)
	assert_eq(HitFlash.duration_for(3.0), HitFlash.MAX_DURATION, "an overweight hit clamps")


func test_the_flash_snaps_overbright_and_eases_back() -> void:
	var target := _target()
	var sprite: Sprite2D = target.get_node("Sprite2D")
	var tween := HitFlash.play(target, 0.0, Color.RED)
	assert_eq(sprite.modulate, Color.RED * 3.0, "overbright on impact")
	await tween.finished
	assert_eq(sprite.modulate, Color.RED, "eased back to the flash color")
	target.free()


func test_nothing_to_flash_is_a_no_op() -> void:
	assert_null(HitFlash.play(null, 1.0))
	var bare: Node2D = autofree(Node2D.new())
	assert_null(HitFlash.play(bare, 1.0), "no sprite, no flash")


func test_a_unit_freed_mid_flash_takes_the_flash_with_it() -> void:
	var target := _target()
	var tween := HitFlash.play(target, 1.0)
	target.free()
	await wait_process_frames(2)
	assert_false(tween.is_valid(), "the tween died with the sprite, callback and all")
