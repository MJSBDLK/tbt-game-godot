## CharacterSheetPanel — row-construction invariants. The panel builds its
## stat rows in code (no scene), so the row builder is exercised directly.
extends GutTest


func test_the_cap_bar_is_the_only_bar_in_a_built_stat_row() -> void:
	# One track per bar (RQD 2026-08-11): the full-width dark backing that
	# used to sit under the cap bar read as a second, longer track once
	# StatCapBar started scaling its track to the class cap. The bar
	# container must hold the StatCapBar and nothing else that draws.
	var panel: CharacterSheetPanel = autofree(CharacterSheetPanel.new())
	var parent := VBoxContainer.new()
	add_child_autofree(parent)
	var row: Dictionary = panel._build_stat_row("STR", UIManager, parent)
	assert_false(row.has("bar_bg"), "the backing rect is gone, not just unreferenced")
	var cap_bar: StatCapBar = row["cap_bar"]
	var bar_container: Node = cap_bar.get_parent()
	for child: Node in bar_container.get_children():
		assert_true(child is StatCapBar,
				"%s: nothing draws in the bar container except the cap bar"
				% child.get_class())
