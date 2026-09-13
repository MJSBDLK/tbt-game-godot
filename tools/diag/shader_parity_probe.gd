## Compositing parity probe for shaders/modifier_oob_fade.gdshader. Needs a
## real display (the headless renderer draws nothing). Run from the root:
##   DISPLAY=:0 godot-4 --path . --resolution 400x200 -s tools/diag/shader_parity_probe.gd
## Draws four 40x40 squares on white and reads back their center pixels:
##   A  mid-gray sprite, no material            → expect 128
##   B  mid-gray sprite, fade material (no fade) → expect 128 (same as A)
##   C  40% black sprite, fade material         → expect 153 (white × 0.6)
##   D  white mask via draw_texture_rect with GameColors.CAST_SHADOW_INK —
##      UnitShadow's draw path                  → expect 153 (same as C)
## Written 2026-09-07 after the fade shader sampled the texture twice
## (fragment COLOR already holds texture × modulate) — B came out 64 and C
## 214, i.e. dark buildings and pale terrain shadows. Re-run after ANY edit
## to that shader.
extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	var root := get_root()
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.size = Vector2(400, 200)
	root.add_child(bg)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/modifier_oob_fade.gdshader")
	mat.set_shader_parameter("map_min", Vector2(-99999, -99999))
	mat.set_shader_parameter("map_max", Vector2(99999, 99999))

	var gray := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	gray.fill(Color8(128, 128, 128, 255))
	var ink := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	ink.fill(Color8(0, 0, 0, 102))
	var white := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)

	var a := Sprite2D.new()
	a.texture = ImageTexture.create_from_image(gray)
	a.position = Vector2(50, 50)
	root.add_child(a)
	var b := Sprite2D.new()
	b.texture = ImageTexture.create_from_image(gray)
	b.position = Vector2(150, 50)
	b.material = mat
	root.add_child(b)
	var c := Sprite2D.new()
	c.texture = ImageTexture.create_from_image(ink)
	c.position = Vector2(250, 50)
	c.material = mat
	root.add_child(c)
	var drawer_script := GDScript.new()
	drawer_script.source_code = """
extends Node2D
var mask: Texture2D
func _draw() -> void:
	draw_texture_rect(mask, Rect2(Vector2(-20, -20), Vector2(40, 40)), false, Color(0.0, 0.0, 0.0, 0.4))
"""
	drawer_script.reload()
	var d: Node2D = drawer_script.new()
	d.set("mask", ImageTexture.create_from_image(white))
	d.position = Vector2(350, 50)
	root.add_child(d)

	for i in 4:
		await process_frame
	var img := root.get_texture().get_image()
	var expected := {"A": 128, "B": 128, "C": 153, "D": 153}
	var xs := {"A": 50, "B": 150, "C": 250, "D": 350}
	var ok := true
	for key: String in xs:
		var px: Color = img.get_pixel(xs[key], 50)
		var value := roundi(px.r * 255.0)
		var pass_str := "OK " if absi(value - expected[key]) <= 2 else "BAD"
		if pass_str == "BAD":
			ok = false
		print("[parity] %s %s got %d expected %d  (rgb %d,%d,%d)" % [
			pass_str, key, value, expected[key],
			roundi(px.r * 255.0), roundi(px.g * 255.0), roundi(px.b * 255.0)])
	print("[parity] ", "ALL OK" if ok else "MISMATCH")
	quit(0 if ok else 1)
