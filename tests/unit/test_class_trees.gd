## The class data in data/classes/ (ClassTrees): the files on disk are sound,
## and problems_in catches each way the editor or a hand edit could break them.
extends GutTest


func _pool() -> Dictionary:
	return {
		soldier = {name = "Soldier", tier = 1, notes = ""},
		commando = {name = "Commando", tier = 2, notes = ""},
		legionnaire = {name = "Legionnaire", tier = 2, notes = ""},
		ranger = {name = "Ranger", tier = 3, notes = ""},
		sniper = {name = "Sniper", tier = 3, notes = ""},
		centurion = {name = "Centurion", tier = 3, notes = ""},
		praetorian = {name = "Praetorian", tier = 3, notes = ""},
	}


func _slot(class_id: String, promotions: Array = []) -> Dictionary:
	var slot := {"class": class_id, "types": [], "art": "palette"}
	if not promotions.is_empty():
		slot["promotions"] = promotions
	return slot


func _tree() -> Dictionary:
	return {
		base = "soldier",
		base_types = ["Simple"],
		promotions = [
			_slot("commando", [_slot("ranger"), _slot("sniper")]),
			_slot("legionnaire", [_slot("centurion"), _slot("praetorian")]),
		],
		notes = "",
	}


func test_the_files_on_disk_are_sound() -> void:
	var problems := ClassTrees.problems()
	assert_eq(problems.size(), 0, "\n".join(problems))
	assert_gt(ClassTrees.pool().size(), 0, "the pool loaded")
	assert_gt(ClassTrees.trees().size(), 0, "the trees loaded")


func test_a_full_tree_from_the_pool_is_sound() -> void:
	assert_eq(ClassTrees.problems_in(_pool(), {unit = _tree()}).size(), 0)


func test_undesigned_slots_are_fine() -> void:
	var tree := _tree()
	tree.promotions[1] = _slot("", [_slot(""), _slot("")])
	assert_eq(ClassTrees.problems_in(_pool(), {unit = tree}).size(), 0, "\"\" is a slot not designed yet")


func test_a_draft_is_only_for_an_empty_slot() -> void:
	var tree := _tree()
	tree.promotions[1] = _slot("", [_slot(""), _slot("")])
	tree.promotions[1]["draft"] = {name = "", notes = "slow, tanky"}
	assert_eq(ClassTrees.problems_in(_pool(), {unit = tree}).size(), 0, "an empty slot may hold a class in the making")
	tree.promotions[0]["draft"] = {name = "Big Boy", notes = ""}
	assert_eq(ClassTrees.problems_in(_pool(), {unit = tree}), PackedStringArray([
		"tree unit: base > 1 holds commando and a draft; a draft is only for an empty slot"]))


func test_typing_is_each_slot_s_not_the_class_s() -> void:
	# Two units' Colossus can differ: Simple/Robo for one, mono Cold for the other.
	var first := _tree()
	first.promotions[0].promotions[0].types = ["Simple", "Robo"]
	var second := _tree()
	second.promotions[0].promotions[0].types = ["Cold"]
	assert_eq(ClassTrees.problems_in(_pool(), {first = first, second = second}).size(), 0)
	var pool := _pool()
	pool.ranger["types"] = ["Simple"]
	assert_eq(ClassTrees.problems_in(pool, {}), PackedStringArray([
		"class ranger: typing is per unit, so it goes on each tree's slot, not the class"]))


func test_a_bad_slot_or_base_typing_is_caught() -> void:
	var tree := _tree()
	tree.base_types = ["Simple", "Robo", "Cold"]
	tree.promotions[1].types = ["Rock"]
	assert_eq(ClassTrees.problems_in(_pool(), {unit = tree}), PackedStringArray([
		"tree unit: base: types must be a list of at most two",
		"tree unit: base > 2: no elemental type called Rock"]))


func test_two_units_can_share_classes() -> void:
	var problems := ClassTrees.problems_in(_pool(), {first = _tree(), second = _tree()})
	assert_eq(problems.size(), 0, "the pool is shared; only within one tree is a repeat wrong")


func test_both_branches_may_reach_one_shared_tier_three_class() -> void:
	# The middle ground either path reaches: 7 slots, 6 classes.
	var tree := _tree()
	tree.promotions[1].promotions[0] = _slot("ranger")
	assert_eq(ClassTrees.problems_in(_pool(), {unit = tree}).size(), 0)


func test_only_one_tier_three_class_may_be_shared() -> void:
	var tree := _tree()
	tree.promotions[1].promotions = [_slot("ranger"), _slot("sniper")]
	assert_eq(ClassTrees.problems_in(_pool(), {unit = tree}), PackedStringArray([
		"tree unit: only one tier-3 class can sit under both branches, not ranger and sniper"]))


func test_a_branch_promoting_into_one_class_twice_is_caught() -> void:
	var tree := _tree()
	tree.promotions[0].promotions[1] = _slot("ranger")
	assert_eq(ClassTrees.problems_in(_pool(), {unit = tree}), PackedStringArray([
		"tree unit: base > 1 promotes into ranger twice"]))


func test_the_same_tier_two_class_twice_is_caught() -> void:
	var tree := _tree()
	tree.promotions[1]["class"] = "commando"
	assert_eq(ClassTrees.problems_in(_pool(), {unit = tree}), PackedStringArray([
		"tree unit: both tier-2 slots hold commando"]))


func test_a_class_in_the_wrong_tier_is_caught() -> void:
	var tree := _tree()
	tree.promotions[0].promotions[0] = _slot("legionnaire")
	var problems := ClassTrees.problems_in(_pool(), {unit = tree})
	assert_true(problems.has("tree unit: base > 1 > 1 is a tier-3 slot holding legionnaire, a tier-2 class"), str(problems))


func test_an_unknown_class_is_caught() -> void:
	var tree := _tree()
	tree.promotions[0]["class"] = "jedi"
	assert_eq(ClassTrees.problems_in(_pool(), {unit = tree}), PackedStringArray([
		"tree unit: base > 1 names jedi, which isn't in the pool"]))


func test_a_missing_branch_is_caught() -> void:
	var tree := _tree()
	(tree.promotions[0].promotions as Array).pop_back()
	assert_eq(ClassTrees.problems_in(_pool(), {unit = tree}), PackedStringArray([
		"tree unit: base > 1 needs exactly 2 promotions"]))


func test_a_bad_art_kind_is_caught() -> void:
	var tree := _tree()
	tree.promotions[1].art = "photoshop"
	assert_eq(ClassTrees.problems_in(_pool(), {unit = tree}), PackedStringArray([
		"tree unit: base > 2 art photoshop isn't one of palette, palette_layer, redraw"]))


func test_the_editor_offers_every_elemental_type() -> void:
	# The class tree editor (class_tree_logic.js) can't read the enum; its list is pinned to it here.
	var source := FileAccess.get_file_as_string("res://tools/art_dashboard/class_tree_logic.js")
	var start := source.find("const ELEMENTAL_TYPES = [")
	var block := source.substr(start, source.find("];", start) - start)
	var listed := PackedStringArray()
	var quoted := RegEx.create_from_string("\"([A-Za-z]+)\"")
	for found: RegExMatch in quoted.search_all(block):
		listed.append(found.get_string(1))
	var expected := PackedStringArray()
	for key: String in Enums.ElementalType.keys():
		if key != "NONE":
			expected.append(key.capitalize())
	assert_eq(listed, expected, "class_tree_logic.js ELEMENTAL_TYPES = Enums.ElementalType without NONE")
