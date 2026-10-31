## Classes and promotion trees, read from data/classes/ (its README is the
## format): a shared pool of classes, and each unit's own tree drawing from
## it, so two units that start as the same class can diverge at 21, or not.
## Typing is the unit's, not the class's: each tree slot sets its own.
## Edited in the class tree editor (tools/art_dashboard/class_trees.html);
## problems_in is what tests/unit/test_class_trees.gd holds the files to.
## The art board's generator draws from it; nothing in the game promotes yet,
## and the class-choice screen will read it here. Design:
## data/design/class-and-promotion.md.
class_name ClassTrees
extends RefCounted


const DIRECTORY: String = "res://data/classes"
## How a class's art gets made for a unit (README: `art`).
const ART_KINDS: PackedStringArray = ["palette", "palette_layer", "redraw"]
## Each slot of a tree promotes into this many classes, down to tier 3.
const CHOICES_PER_PROMOTION: int = 2
const TOP_TIER: int = 3


## Every class: id (its file name) → {name, tier, notes}.
static func pool() -> Dictionary:
	return _read_folder(DIRECTORY + "/pool")


## Every tree: unit id (its file name) → {base, base_types, promotions, notes}.
static func trees() -> Dictionary:
	return _read_folder(DIRECTORY + "/trees")


## What's wrong with the files on disk, one line per problem; empty when sound.
static func problems() -> PackedStringArray:
	return problems_in(pool(), trees())


## What's wrong with `class_pool` and `unit_trees`, one line per problem.
static func problems_in(class_pool: Dictionary, unit_trees: Dictionary) -> PackedStringArray:
	var found := PackedStringArray()
	for class_id: String in class_pool:
		_check_class(class_id, class_pool[class_id], found)
	for unit_id: String in unit_trees:
		_check_tree(unit_id, unit_trees[unit_id], class_pool, found)
	return found


static func _check_class(class_id: String, entry: Variant, found: PackedStringArray) -> void:
	if not entry is Dictionary:
		found.append("class %s: not a JSON object" % class_id)
		return
	if str(entry.get("name", "")).is_empty():
		found.append("class %s: no name" % class_id)
	var tier: int = int(entry.get("tier", 0))
	if tier < 1 or tier > TOP_TIER:
		found.append("class %s: tier %s isn't 1 to %d" % [class_id, entry.get("tier"), TOP_TIER])
	if entry.has("types"):
		found.append("class %s: typing is per unit, so it goes on each tree's slot, not the class" % class_id)


## A slot's types: at most two, spelled as in the character JSONs.
static func _check_types(label: String, types: Variant, found: PackedStringArray) -> void:
	if not types is Array or (types as Array).size() > 2:
		found.append("%s: types must be a list of at most two" % label)
		return
	for type_name: Variant in types:
		if Enums.string_to_elemental_type(str(type_name)) == Enums.ElementalType.NONE:
			found.append("%s: no elemental type called %s" % [label, type_name])


static func _check_tree(unit_id: String, tree: Variant, class_pool: Dictionary,
		found: PackedStringArray) -> void:
	if not tree is Dictionary:
		found.append("tree %s: not a JSON object" % unit_id)
		return
	_check_slot(unit_id, "base", str(tree.get("base", "")), 1, class_pool, found)
	_check_types("tree %s: base" % unit_id, tree.get("base_types", []), found)
	if str(tree.get("base", "")).is_empty():
		found.append("tree %s: no base class" % unit_id)
	_check_promotions(unit_id, "base", tree.get("promotions"), 2, class_pool, found)
	_check_repeats(unit_id, tree, found)


static func _check_promotions(unit_id: String, parent: String, promotions: Variant, tier: int,
		class_pool: Dictionary, found: PackedStringArray) -> void:
	if not promotions is Array or (promotions as Array).size() != CHOICES_PER_PROMOTION:
		found.append("tree %s: %s needs exactly %d promotions" % [unit_id, parent, CHOICES_PER_PROMOTION])
		return
	for index: int in CHOICES_PER_PROMOTION:
		var slot: Variant = promotions[index]
		var where := "%s > %d" % [parent, index + 1]
		if not slot is Dictionary:
			found.append("tree %s: %s isn't a JSON object" % [unit_id, where])
			continue
		_check_slot(unit_id, where, str(slot.get("class", "")), tier, class_pool, found)
		_check_draft(unit_id, where, slot, found)
		_check_types("tree %s: %s" % [unit_id, where], slot.get("types", []), found)
		if not ART_KINDS.has(str(slot.get("art", ""))):
			found.append("tree %s: %s art %s isn't one of %s" % [unit_id, where, slot.get("art"), ", ".join(ART_KINDS)])
		if tier < TOP_TIER:
			_check_promotions(unit_id, where, slot.get("promotions"), tier + 1, class_pool, found)
		elif slot.has("promotions"):
			found.append("tree %s: %s is tier %d, the top: no promotions" % [unit_id, where, TOP_TIER])


## A slot's class: empty (not designed yet), or a pool class of the slot's tier.
static func _check_slot(unit_id: String, where: String, class_id: String, tier: int,
		class_pool: Dictionary, found: PackedStringArray) -> void:
	if class_id.is_empty():
		return
	if not class_pool.has(class_id):
		found.append("tree %s: %s names %s, which isn't in the pool" % [unit_id, where, class_id])
		return
	var class_tier: int = int((class_pool[class_id] as Dictionary).get("tier", 0))
	if class_tier != tier:
		found.append("tree %s: %s is a tier-%d slot holding %s, a tier-%d class" % [
				unit_id, where, tier, class_id, class_tier])


## A draft (README: `draft`) is the editor's class in the making for an empty
## slot, and nothing in the game reads it: {name, notes}, never beside a class.
static func _check_draft(unit_id: String, where: String, slot: Dictionary, found: PackedStringArray) -> void:
	if not slot.has("draft"):
		return
	var draft: Variant = slot["draft"]
	var label := "tree %s: %s draft" % [unit_id, where]
	if not draft is Dictionary:
		found.append("%s isn't a JSON object" % label)
		return
	if not str(slot.get("class", "")).is_empty():
		found.append("tree %s: %s holds %s and a draft; a draft is only for an empty slot" % [
				unit_id, where, slot.get("class")])
	if not draft.get("name", "") is String or not draft.get("notes", "") is String:
		found.append("%s: name and notes must be text" % label)


## Repeats: the two tier-2 classes differ, a tier-2 class never promotes into
## the same class twice, and at most one tier-3 class sits under both branches
## (a middle ground either path reaches: a 6-class tree).
static func _check_repeats(unit_id: String, tree: Dictionary, found: PackedStringArray) -> void:
	var branches: Variant = tree.get("promotions")
	if not branches is Array or (branches as Array).size() != CHOICES_PER_PROMOTION:
		return  # _check_promotions has said so
	var tier_two := PackedStringArray()
	var under: Array[PackedStringArray] = []
	for index: int in CHOICES_PER_PROMOTION:
		var branch: Variant = branches[index]
		tier_two.append(str(branch.get("class", "")) if branch is Dictionary else "")
		var children := PackedStringArray()
		var promotions: Variant = branch.get("promotions") if branch is Dictionary else null
		for child: Variant in (promotions if promotions is Array else []):
			var class_id := str(child.get("class", "")) if child is Dictionary else ""
			if class_id.is_empty():
				continue
			if children.has(class_id):
				found.append("tree %s: base > %d promotes into %s twice" % [unit_id, index + 1, class_id])
			children.append(class_id)
		under.append(children)
	if not tier_two[0].is_empty() and tier_two[0] == tier_two[1]:
		found.append("tree %s: both tier-2 slots hold %s" % [unit_id, tier_two[0]])
	var shared := PackedStringArray()
	for class_id: String in under[0]:
		if under[1].has(class_id) and not shared.has(class_id):
			shared.append(class_id)
	if shared.size() > 1:
		found.append("tree %s: only one tier-3 class can sit under both branches, not %s" % [
				unit_id, " and ".join(shared)])


static func _read_folder(path: String) -> Dictionary:
	var entries: Dictionary = {}
	for file_name: String in DirAccess.get_files_at(path):
		if file_name.get_extension() == "json":
			entries[file_name.get_basename()] = JSON.parse_string(FileAccess.get_file_as_string(path.path_join(file_name)))
	return entries
