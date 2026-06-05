## Smoke test — proves the GUT harness loads and runs.
## If this fails, the test runner setup is broken, not your code.
extends GutTest


func test_harness_is_alive() -> void:
	assert_true(true, "GutTest base class loaded and assert_true works")


func test_basic_math() -> void:
	assert_eq(2 + 2, 4, "GDScript arithmetic still works")
