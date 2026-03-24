extends ColorRect


const TIERS: Array[Dictionary] = [
	{"label": "x4  Devastating",        "value": 47, "multiplier": 4.0},
	{"label": "x3",                     "value": 34, "multiplier": 3.0},
	{"label": "x2  Super Effective",    "value": 22, "multiplier": 2.0},
	{"label": "x1  Neutral",            "value": 15, "multiplier": 1.0},
	{"label": "x½  Not Very Effective", "value": 7,  "multiplier": 0.5},
	{"label": "x¼  Barely Effective",   "value": 3,  "multiplier": 0.25},
	{"label": "x0  No Effect",          "value": 0,  "multiplier": 0.0},
]


static func _get_light_color(multiplier: float) -> Color:
	if multiplier >= 4.0: return GameColors.MULTIPLIER_X4_LIGHT
	elif multiplier >= 3.0: return GameColors.MULTIPLIER_X3_LIGHT
	elif multiplier >= 2.0: return GameColors.MULTIPLIER_X2_LIGHT
	elif multiplier >= 1.0: return GameColors.MULTIPLIER_X1_LIGHT
	elif multiplier >= 0.5: return GameColors.MULTIPLIER_HALF_LIGHT
	elif multiplier > 0.0: return GameColors.MULTIPLIER_QUARTER_LIGHT
	else: return GameColors.MULTIPLIER_X0_LIGHT


static func _get_dark_color(multiplier: float) -> Color:
	if multiplier >= 4.0: return GameColors.MULTIPLIER_X4_DARK
	elif multiplier >= 3.0: return GameColors.MULTIPLIER_X3_DARK
	elif multiplier >= 2.0: return GameColors.MULTIPLIER_X2_DARK
	elif multiplier >= 1.0: return GameColors.MULTIPLIER_X1_DARK
	elif multiplier >= 0.5: return GameColors.MULTIPLIER_HALF_DARK
	elif multiplier > 0.0: return GameColors.MULTIPLIER_QUARTER_DARK
	else: return GameColors.MULTIPLIER_X0_DARK

# Gray 0 @ 95% alpha — the background behind each number
var background_color: Color = Color(GameColorPalette.get_color("Gray", 0), 0.95)


func _ready() -> void:
	var ui_manager: Node = get_node_or_null("/root/UIManager")

	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "DAMAGE POPUP COLOR PREVIEW"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null and ui_manager.font_8px != null:
		header.add_theme_font_override("font", ui_manager.font_8px)
		header.add_theme_font_size_override("font_size", 8)
	header.add_theme_color_override("font_color", GameColorPalette.get_color("Gray", 7))
	vbox.add_child(header)

	# Gray 7 reference bar
	var ref_hbox := HBoxContainer.new()
	ref_hbox.add_theme_constant_override("separation", 8)
	ref_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(ref_hbox)

	var ref_swatch := ColorRect.new()
	ref_swatch.custom_minimum_size = Vector2(30, 14)
	ref_swatch.color = GameColorPalette.get_color("Gray", 7)
	ref_hbox.add_child(ref_swatch)

	var ref_label := Label.new()
	ref_label.text = "Gray 7 — brightness target"
	if ui_manager != null and ui_manager.font_5px != null:
		ref_label.add_theme_font_override("font", ui_manager.font_5px)
		ref_label.add_theme_font_size_override("font_size", 5)
	ref_label.add_theme_color_override("font_color", GameColorPalette.get_color("Gray", 7))
	ref_hbox.add_child(ref_label)

	# Each tier
	for tier: Dictionary in TIERS:
		var light_color: Color = _get_light_color(tier["multiplier"])
		var dark_color: Color = _get_dark_color(tier["multiplier"])

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(hbox)

		# Light color swatch
		var light_swatch := ColorRect.new()
		light_swatch.custom_minimum_size = Vector2(20, 14)
		light_swatch.color = light_color
		hbox.add_child(light_swatch)

		# Dark color swatch
		var dark_swatch := ColorRect.new()
		dark_swatch.custom_minimum_size = Vector2(20, 14)
		dark_swatch.color = dark_color
		hbox.add_child(dark_swatch)

		# Damage number with orthogonal glow shader as border
		var glow_material: ShaderMaterial = preload("res://resources/hud_glow.tres").duplicate()
		glow_material.set_shader_parameter("glow_color", Color(GameColorPalette.get_color("Gray", 1), 0.975))

		var number_label := Label.new()
		number_label.text = str(tier["value"])
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number_label.add_theme_color_override("font_color", light_color)
		number_label.material = glow_material
		if ui_manager != null and ui_manager.font_8px != null:
			number_label.add_theme_font_override("font", ui_manager.font_8px)
			number_label.add_theme_font_size_override("font_size", 16)
		hbox.add_child(number_label)

		# Tier description with orthogonal glow
		var desc_material: ShaderMaterial = preload("res://resources/hud_glow.tres").duplicate()
		desc_material.set_shader_parameter("glow_color", dark_color)

		var desc_label := GlowLabel.new()
		desc_label.text = tier["label"]
		desc_label.material = desc_material
		desc_label.glow_color = dark_color
		if ui_manager != null and ui_manager.font_8px != null:
			desc_label.add_theme_font_override("font", ui_manager.font_8px)
			desc_label.add_theme_font_size_override("font_size", 8)
		desc_label.add_theme_color_override("font_color", light_color)
		hbox.add_child(desc_label)
