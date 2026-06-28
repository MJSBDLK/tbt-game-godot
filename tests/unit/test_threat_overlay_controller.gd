## Phase: threat-overlay controller. The renderer is visual (eyeball-tested in
## game); what's unit-testable here is the controller's on/off state machine. The
## controller's _ready spins up its renderer and pulls enemies from TurnManager
## (empty in tests -> empty danger map), so toggling is safe without a grid.
extends GutTest


func _controller() -> ThreatOverlayController:
	var controller := ThreatOverlayController.new()
	add_child_autofree(controller)
	return controller


func test_starts_hidden() -> void:
	assert_false(_controller().is_showing(), "overlay is off until toggled")


func test_toggle_shows_then_hides() -> void:
	var controller := _controller()
	controller.toggle_all_enemies()
	assert_true(controller.is_showing(), "first toggle turns the all-enemies zone on")
	controller.toggle_all_enemies()
	assert_false(controller.is_showing(), "second toggle turns it back off")


func test_refresh_is_safe_with_no_enemies() -> void:
	# No grid, no enemies registered: refreshing the live overlay must not error.
	var controller := _controller()
	controller.toggle_all_enemies()
	controller.refresh()
	assert_true(controller.is_showing(), "refresh leaves the mode untouched")
