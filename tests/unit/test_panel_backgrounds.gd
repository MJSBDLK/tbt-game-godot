## Pins panel background colors — the answer to "the backgrounds of the UI
## panels are getting the alpha values changed and editing the .tscn files
## isn't fixing it."
##
## ROOT CAUSE (why .tscn edits are inert): most panels build their background
## StyleBoxFlat IN CODE at _ready and add_theme_stylebox_override it, replacing
## whatever the scene authored. The color they all use is
## GameColors.HUD_PANEL_BACKGROUND, which BAKES 0.85 alpha via with_alpha().
## Panel opacity is therefore edited in exactly one place — game_colors.gd —
## and these tests fail loudly if either the constant or a panel's use of it
## drifts.
extends GutTest

const _EXPECTED_PANEL_ALPHA: float = 0.85


func test_hud_panel_background_bakes_the_designed_alpha() -> void:
	assert_almost_eq(GameColors.HUD_PANEL_BACKGROUND.a, _EXPECTED_PANEL_ALPHA, 0.001,
			"HUD_PANEL_BACKGROUND carries the designed 0.85 alpha — change it in game_colors.gd, not .tscn")
	var opaque_rgb := Color(GameColors.HUD_PANEL_BACKGROUND, 1.0)
	assert_eq(opaque_rgb, Color(GameColorPalette.get_color("Eggshell", 1), 1.0),
			"HUD panel body color comes from the Eggshell ramp")


func test_action_menu_panel_applies_hud_background_at_ready() -> void:
	var panel := ActionMenuPanel.new()
	add_child_autofree(panel)
	var style: StyleBox = panel.get_theme_stylebox("panel")
	assert_true(style is StyleBoxFlat, "Action menu builds its own StyleBoxFlat in code")
	var flat := style as StyleBoxFlat
	assert_eq(flat.bg_color, GameColors.HUD_PANEL_BACKGROUND,
			"Action menu background == GameColors.HUD_PANEL_BACKGROUND (alpha included)")
	assert_almost_eq(flat.bg_color.a, _EXPECTED_PANEL_ALPHA, 0.001,
			"Nothing mutated the panel alpha after _ready")


func test_menu_background_alpha_pinned() -> void:
	assert_almost_eq(GameColors.MENU_BACKGROUND.a, 0.9, 0.001,
			"MENU_BACKGROUND bakes 0.9 alpha")
	assert_almost_eq(GameColors.UI_BACKDROP.a, _EXPECTED_PANEL_ALPHA, 0.001,
			"UI_BACKDROP bakes 0.85 alpha")
