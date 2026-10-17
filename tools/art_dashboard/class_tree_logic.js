// The class tree editor's rules, with no DOM: a tree's slots, what's wrong
// with one, who uses a class, and the files' exact text. class_trees.js draws
// the page from these; class_tree_test.js runs them in node. The file format
// and the game's own checks: data/classes/README.md, ClassTrees.problems_in.
"use strict";

(function (global) {

const ART_KINDS = [
	{ id: "palette", label: "Palette swap" },
	{ id: "palette_layer", label: "Swap + layer" },
	{ id: "redraw", label: "Redraw" },
];
// Enums.ElementalType without NONE, spelled as in the character JSONs.
// test_class_trees.gd pins the two lists together.
const ELEMENTAL_TYPES = [
	"Air", "Chivalric", "Cold", "Electric", "Fire", "Gentry", "Gravity", "Heraldic",
	"Occult", "Plant", "Robo", "Simple", "Void", "Obsidian", "Monster", "Beast",
];
const CHOICES = 2;  // each slot below tier 3 promotes into two
const TOP_TIER = 3;

// A class's id, which is its file name: the name in lowercase, words joined by "_".
function classId(name) {
	return name.trim().toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
}

function emptySlot(tier) {
	const slot = { class: "", types: [], art: "palette" };
	if (tier < TOP_TIER) slot.promotions = Array.from({ length: CHOICES }, () => emptySlot(tier + 1));
	return slot;
}

function newTree(base) {
	return { base: base || "", base_types: [], promotions: Array.from({ length: CHOICES }, () => emptySlot(2)), notes: "" };
}

// Every slot, the base first, then depth-first: {path, tier, classId, types, art, draft}.
// path is [] for the base, [i] for a tier-2 slot, [i, j] for a tier-3 one;
// types are the slot's own (setTypes); draft is null or {name, notes} (setDraft).
function slots(tree) {
	const out = [{ path: [], tier: 1, classId: tree.base, types: tree.base_types || [], art: null, draft: null }];
	const slot = (path, tier, entry) => ({ path, tier, classId: entry.class, types: entry.types || [], art: entry.art,
		draft: entry.draft || null });
	tree.promotions.forEach((second, i) => {
		out.push(slot([i], 2, second));
		second.promotions.forEach((third, j) => out.push(slot([i, j], 3, third)));
	});
	return out;
}

function slotObject(tree, path) {
	let slot = null;
	let children = tree.promotions;
	for (const index of path) {
		slot = children[index];
		children = slot.promotions || [];
	}
	return slot;
}

// Placing a class, or emptying a slot, ends any draft there.
function setClass(tree, path, id) {
	if (path.length === 0) {
		tree.base = id;
		return;
	}
	const slot = slotObject(tree, path);
	slot.class = id;
	delete slot.draft;
}

// A draft: an empty promotion slot's tentative class, {name, notes}, either
// blank; brainstorming with no class file. It lives only in the tree's file,
// and the game reads the slot as empty. `changes` merges in; a draft left
// with nothing in it is gone. (Its typing is the slot's, as for any class.)
function setDraft(tree, path, changes) {
	console.assert(path.length > 0, "class trees: the base is always a class, never a draft");
	const slot = slotObject(tree, path);
	const draft = { name: "", notes: "", ...slot.draft, ...changes };
	draft.name = draft.name.trim();
	slot.class = "";
	if (draft.name || draft.notes.trim()) slot.draft = { name: draft.name, notes: draft.notes };
	else delete slot.draft;
}

// Typing is the unit's, not the class's: each slot sets its own, so two
// units' Colossus can differ. The base's is the tree's base_types.
function setTypes(tree, path, types) {
	if (path.length === 0) tree.base_types = types.slice();
	else slotObject(tree, path).types = types.slice();
}

function draftAt(tree, path) {
	return path.length ? slotObject(tree, path).draft || null : null;
}

function setArt(tree, path, art) {
	slotObject(tree, path).art = art;
}

// Swap the two classes the slot at `path` promotes into: from the base, the
// two tier-2 branches, each taking its own tier-3 classes along.
function flip(tree, path) {
	const children = path.length === 0 ? tree.promotions : slotObject(tree, path).promotions;
	console.assert(children && children.length === CHOICES, "class trees: only a slot with promotions flips");
	children.reverse();
}

function designedCount(tree) {
	return slots(tree).filter((slot) => slot.classId).length;
}

// What `key` reads off a tier-3 slot, for those under both branches.
function sharedUnder(tree, key) {
	const under = tree.promotions.map((branch) => branch.promotions.map(key).filter(Boolean));
	return [...new Set(under[0].filter((each) => under[1].includes(each)))];
}

// The tier-3 classes under both branches: the middle ground either path
// reaches. At most one, which makes the tree's 7 slots 6 classes.
function sharedClasses(tree) {
	return sharedUnder(tree, (slot) => slot.class);
}

// What a promotion slot shows: its class, its draft (any case), or "".
// The view merges two tier-3 slots showing the same thing, drafts included.
function shownIn(slot) {
	return slot.class || (slot.draft && slot.draft.name ? `draft:${slot.draft.name.toLowerCase()}` : "");
}

function classCount(tree) {
	return new Set(slots(tree).map((slot) => slot.classId).filter(Boolean)).size;
}

// Where each card sits in the tree view, and the lines between them:
// {cards: [{paths, tier, row, span}], edges: [[parent card, child card]]}.
// Rows count 0-3 down the tier-3 column. A tier-3 class (or draft) under both
// branches is ONE card that two lines run into: branch 1 puts it last and
// branch 2 first, so they meet in the middle (a slot's place among its
// siblings is display only; the file keeps its own order).
function layout(tree) {
	const cards = [{ paths: [[]], tier: 1, row: 0, span: 4 }];
	const edges = [];
	const shared = sharedUnder(tree, shownIn)[0] || null;
	let merged = -1;
	tree.promotions.forEach((branch, i) => {
		const parent = cards.push({ paths: [[i]], tier: 2, row: i * 2, span: 2 }) - 1;
		edges.push([0, parent]);
		const at = shared ? branch.promotions.findIndex((slot) => shownIn(slot) === shared) : -1;
		const order = at < 0 ? [0, 1] : i === 0 ? [1 - at, at] : [at, 1 - at];
		order.forEach((j, position) => {
			if (j === at) {
				if (merged < 0) merged = cards.push({ paths: [[i, j]], tier: 3, row: 1, span: 2 }) - 1;
				else cards[merged].paths.push([i, j]);
				edges.push([parent, merged]);
			} else {
				edges.push([parent, cards.push({ paths: [[i, j]], tier: 3, row: i * 2 + position, span: 1 }) - 1]);
			}
		});
	});
	return { cards, edges };
}

// placement() for a card holding several slots (a merged tier-3 card): the
// name goes into all of them, checked one after another on a copy.
function placementAll(tree, pool, paths, name) {
	const trial = JSON.parse(JSON.stringify(tree));
	let result = null;
	for (const path of paths) {
		result = placement(trial, pool, path, name);
		if (!result.ok) return result;
		setClass(trial, path, result.id);
	}
	return result;
}

// The slots in `trees` holding class `id` at a tier other than `tier`: what
// moving the class to `tier` empties, or they'd hold it in the wrong tier.
function retierEmpties(trees, id, tier) {
	const empties = [];
	for (const each of Object.keys(trees).sort()) {
		for (const slot of slots(trees[each])) {
			if (slot.classId === id && slot.tier !== tier) empties.push({ unit: each, path: slot.path });
		}
	}
	return empties;
}

// The way out of a wrong-tier refusal: move pool class `id` to the tier of
// the slots at `paths` in `unit`'s tree, and put it there. Every slot in
// `trees` holding it at another tier goes empty, or it would be wrong there
// instead. {ok, tier, empties: [{unit, path}]}, or the placement's refusal
// when the move alone doesn't make it fit.
function moveTier(trees, unit, pool, paths, id) {
	const tier = paths[0].length + 1;
	const empties = retierEmpties(trees, id, tier);
	const tree = JSON.parse(JSON.stringify(trees[unit]));
	for (const empty of empties) if (empty.unit === unit) setClass(tree, empty.path, "");
	const result = placementAll(tree, { ...pool, [id]: { ...pool[id], tier } }, paths, pool[id].name);
	return result.ok ? { ok: true, tier, empties } : result;
}

// Why putting `id` in the slot at `path` breaks the repeat rules, or "": the
// two tier-2 classes differ, a tier-2 class never promotes into one class
// twice, and at most one tier-3 class sits under both branches.
function repeatError(tree, path, id, name) {
	if (path.length === 1) {
		return tree.promotions[1 - path[0]].class === id ? `${name} is already the other tier-2 choice.` : "";
	}
	if (path.length === 2) {
		const [branch, index] = path;
		if (tree.promotions[branch].promotions[1 - index].class === id) return `${name} is already under this tier-2 class.`;
		const after = JSON.parse(JSON.stringify(tree));
		after.promotions[branch].promotions[index].class = id;
		if (sharedClasses(after).length > 1) return "Only one tier-3 class can sit under both branches.";
	}
	return "";
}

// The units whose trees use `id`, in id order.
function usedBy(trees, id) {
	return Object.keys(trees).filter((unit) => slots(trees[unit]).some((slot) => slot.classId === id)).sort();
}

// Each unit's typing for class `id`, in id order: [{unit, types}].
function typingsOf(trees, id) {
	return usedBy(trees, id).map((unit) => ({ unit, types: slots(trees[unit]).find((slot) => slot.classId === id).types }));
}

// The pool's classes of one tier, by name: [{id, name}].
function classesOfTier(pool, tier) {
	return Object.keys(pool).filter((id) => pool[id].tier === tier)
		.map((id) => ({ id, name: pool[id].name }))
		.sort((a, b) => a.name.localeCompare(b.name));
}

// The pool class called `name` (any case), or null.
function findByName(pool, name) {
	const wanted = name.trim().toLowerCase();
	return Object.keys(pool).find((id) => pool[id].name.toLowerCase() === wanted) || null;
}

// What putting the class called `name` into the slot at `path` would do:
// {ok, id, create, error}. An unknown name makes a new class of the slot's tier.
function placement(tree, pool, path, name) {
	const tier = path.length + 1;
	if (!name.trim()) return { ok: true, id: "", create: false };
	const existing = findByName(pool, name);
	const id = existing || classId(name);
	if (!id) return { ok: false, error: "A class name needs a letter or a number." };
	if (existing && pool[existing].tier !== tier) {
		return { ok: false, wrongTier: existing,
			error: `${pool[existing].name} is a tier-${pool[existing].tier} class; this slot is tier ${tier}.` };
	}
	if (!existing && pool[id]) {
		return { ok: false, error: `"${name}" would be the file ${id}.json, which ${pool[id].name} already has.` };
	}
	const repeat = repeatError(tree, path, id, existing ? pool[existing].name : name.trim());
	if (repeat) return { ok: false, error: repeat };
	return { ok: true, id, create: !existing };
}

// The same checks ClassTrees.problems_in runs on a tree, for the page.
function problems(tree, pool) {
	const found = [];
	const name = (id) => (pool[id] ? pool[id].name : id);
	for (const slot of slots(tree)) {
		if (slot.classId && slot.draft) found.push(`${name(slot.classId)} has a draft too.`);
		if (!slot.classId) continue;
		const entry = pool[slot.classId];
		if (!entry) found.push(`${slot.classId} isn't in the pool.`);
		else if (entry.tier !== slot.tier) found.push(`${entry.name} is tier ${entry.tier}, in a tier-${slot.tier} slot.`);
	}
	const [first, second] = tree.promotions;
	if (first.class && first.class === second.class) found.push(`${name(first.class)} is in both tier-2 slots.`);
	for (const branch of tree.promotions) {
		const [left, right] = branch.promotions;
		if (left.class && left.class === right.class) found.push(`${name(left.class)} is twice under one tier-2 class.`);
	}
	if (sharedClasses(tree).length > 1) found.push("Only one tier-3 class can sit under both branches.");
	if (!tree.base) found.push("No base class.");
	return found;
}

// The files' exact text: tab-indented, keys in the README's order, a closing
// newline, so saving an untouched file changes nothing.
function treeText(tree) {
	const slot = (s, tier) => {
		const out = { class: s.class };
		if (s.draft) out.draft = { name: s.draft.name, notes: s.draft.notes };
		out.types = s.types || [];
		out.art = s.art;
		if (tier < TOP_TIER) out.promotions = s.promotions.map((child) => slot(child, tier + 1));
		return out;
	};
	return JSON.stringify({ base: tree.base, base_types: tree.base_types || [], promotions: tree.promotions.map((s) => slot(s, 2)),
		notes: tree.notes || "" }, null, "\t") + "\n";
}

function classText(entry) {
	return JSON.stringify({ name: entry.name, tier: entry.tier, notes: entry.notes || "" }, null, "\t") + "\n";
}

const logic = {
	ART_KINDS, ELEMENTAL_TYPES, TOP_TIER, classId, newTree, slots, setClass, setDraft, draftAt, setTypes, setArt, flip, designedCount, sharedClasses,
	classCount, layout, placementAll, retierEmpties, moveTier, usedBy, typingsOf,
	classesOfTier, findByName, placement, problems, treeText, classText,
};
if (typeof module !== "undefined") module.exports = logic;
else global.ClassTreeLogic = logic;

})(typeof window !== "undefined" ? window : globalThis);
