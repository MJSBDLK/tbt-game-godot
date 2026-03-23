extends ColorRect

const UI_TEXT_SCENE: PackedScene = preload("res://scenes/ui/panels/ui_text.tscn")

func _ready() -> void:
	# Center container
	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	center.add_child(vbox)

	# Header
	var header: Control = UI_TEXT_SCENE.instantiate()
	var header_label: GlowLabel = header.get_node("Label")
	header_label.text = "HEALTH RAMP PREVIEW"
	header_label.uppercase = false
	vbox.add_child(header)

	for i: int in range(GameColors.HEALTH_RAMP.size()):
		var fill_color: Color = GameColors.HEALTH_RAMP[i]
		var bg_color: Color = GameColors.HEALTH_RAMP_BG[i]

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(hbox)

		# Fill swatch
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(30, 12)
		swatch.color = fill_color
		hbox.add_child(swatch)

		# BG swatch
		var bg_swatch := ColorRect.new()
		bg_swatch.custom_minimum_size = Vector2(30, 12)
		bg_swatch.color = bg_color
		hbox.add_child(bg_swatch)

		# Index + HP text
		var text_container: Control = UI_TEXT_SCENE.instantiate()
		var text_label: GlowLabel = text_container.get_node("Label")
		var hp_value: int = roundi(25.0 * float(i) / 10.0)
		text_label.text = "[%d] %d/25  Def 1.%d  Avoid 1.%d" % [i, hp_value, i, i]
		text_label.add_theme_color_override("font_color", fill_color)
		text_label.glow_color = bg_color
		text_label.uppercase = false
		hbox.add_child(text_container)
