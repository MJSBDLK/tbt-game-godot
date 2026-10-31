// The class tree editor's rules, outside the browser: node --test tools/art_dashboard/class_tree_test.js
// (The game-side checks of the same files: tests/unit/test_class_trees.gd.)
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const trees = require("./class_tree_logic.js");

const DATA = path.join(__dirname, "../../data/classes");

function pool() {
	return {
		soldier: { name: "Soldier", tier: 1, notes: "" },
		commando: { name: "Commando", tier: 2, notes: "" },
		legionnaire: { name: "Legionnaire", tier: 2, notes: "" },
		ranger: { name: "Ranger", tier: 3, notes: "" },
	};
}

test("a new tree is the full seven-slot shape, all undesigned but the base", () => {
	const tree = trees.newTree("soldier");
	const slots = trees.slots(tree);
	assert.equal(slots.length, 7);
	assert.deepEqual(slots.map((slot) => slot.tier), [1, 2, 3, 3, 2, 3, 3]);
	assert.equal(trees.designedCount(tree), 1);
});

test("setting a class writes the slot at its path", () => {
	const tree = trees.newTree("soldier");
	trees.setClass(tree, [1], "legionnaire");
	trees.setClass(tree, [1, 0], "ranger");
	trees.setArt(tree, [1, 0], "redraw");
	assert.equal(tree.promotions[1].class, "legionnaire");
	assert.equal(tree.promotions[1].promotions[0].class, "ranger");
	assert.equal(tree.promotions[1].promotions[0].art, "redraw");
	assert.equal(trees.designedCount(tree), 3);
});

test("a name from the pool is placed; a new name makes a class of the slot's tier", () => {
	const tree = trees.newTree("soldier");
	assert.deepEqual(trees.placement(tree, pool(), [0], "commando"), { ok: true, id: "commando", create: false });
	assert.deepEqual(trees.placement(tree, pool(), [0], "Elite Mercenary"), { ok: true, id: "elite_mercenary", create: true });
	assert.deepEqual(trees.placement(tree, pool(), [0], ""), { ok: true, id: "", create: false });
});

test("a placement in the wrong tier, or both tier-2 slots the same, is refused", () => {
	const tree = trees.newTree("soldier");
	trees.setClass(tree, [0], "commando");
	assert.match(trees.placement(tree, pool(), [0, 0], "Legionnaire").error, /tier-2 class; this slot is tier 3/);
	assert.match(trees.placement(tree, pool(), [1], "Commando").error, /already the other tier-2 choice/);
	assert.equal(trees.placement(tree, pool(), [0], "Commando").ok, true, "putting it back in its own slot is fine");
});

test("both branches may reach one shared tier-3 class: 7 slots, 6 classes", () => {
	const tree = trees.newTree("soldier");
	trees.setClass(tree, [0], "commando");
	trees.setClass(tree, [1], "legionnaire");
	trees.setClass(tree, [0, 0], "ranger");
	assert.deepEqual(trees.placement(tree, pool(), [1, 1], "Ranger"), { ok: true, id: "ranger", create: false });
	trees.setClass(tree, [1, 1], "ranger");
	assert.deepEqual(trees.sharedClasses(tree), ["ranger"]);
	assert.equal(trees.classCount(tree), 4);
	assert.deepEqual(trees.problems(tree, pool()), []);
});

test("the view draws a shared tier-3 class as one card both branches run into", () => {
	const tree = trees.newTree("soldier");
	trees.setClass(tree, [0, 0], "ranger");   // first under branch 1...
	trees.setClass(tree, [1, 1], "ranger");   // ...last under branch 2: the view swaps both inward
	const { cards, edges } = trees.layout(tree);
	assert.equal(cards.length, 6, "base, two tier-2, three tier-3");
	const merged = cards.findIndex((card) => card.paths.length === 2);
	assert.deepEqual(cards[merged], { paths: [[0, 0], [1, 1]], tier: 3, row: 1, span: 2 });
	assert.deepEqual(edges.filter(([, child]) => child === merged).map(([parent]) => cards[parent].paths[0]), [[0], [1]]);
	assert.deepEqual(cards.filter((card) => card.tier === 3 && card.span === 1).map((card) => [card.paths[0], card.row]),
		[[[0, 1], 0], [[1, 0], 3]], "the unshared slots keep the outside rows");
});

test("without a shared class the view is the plain seven cards", () => {
	const { cards, edges } = trees.layout(trees.newTree("soldier"));
	assert.equal(cards.length, 7);
	assert.equal(edges.length, 6);
	assert.deepEqual(cards.filter((card) => card.tier === 3).map((card) => card.row), [0, 1, 2, 3]);
});

test("a merged card's name goes into both its slots, or neither", () => {
	const tree = trees.newTree("soldier");
	trees.setClass(tree, [0, 1], "ranger");
	trees.setClass(tree, [1, 0], "ranger");
	const local = { ...pool(), sniper: { name: "Sniper", tier: 3, notes: "" } };
	assert.deepEqual(trees.placementAll(tree, local, [[0, 1], [1, 0]], "Sniper"), { ok: true, id: "sniper", create: false });
	trees.setClass(tree, [0, 0], "sniper");
	assert.match(trees.placementAll(tree, local, [[0, 1], [1, 0]], "Sniper").error, /already under this tier-2 class/);
	assert.equal(tree.promotions[0].promotions[1].class, "ranger", "a refused placement changes nothing");
});

test("a second shared class, or one class twice under a branch, is refused", () => {
	const tree = trees.newTree("soldier");
	trees.setClass(tree, [0, 0], "ranger");
	trees.setClass(tree, [0, 1], "sniper");
	trees.setClass(tree, [1, 0], "ranger");
	const local = { ...pool(), sniper: { name: "Sniper", tier: 3, notes: "" } };
	assert.match(trees.placement(tree, local, [1, 1], "Sniper").error, /Only one tier-3 class/);
	assert.match(trees.placement(tree, local, [0, 1], "Ranger").error, /already under this tier-2 class/);
	trees.setClass(tree, [1, 1], "sniper");
	assert.deepEqual(trees.problems(tree, local), ["Only one tier-3 class can sit under both branches."]);
});

test("a wrong-tier class can move to the slot's tier, emptying the slots it held at the old one", () => {
	const ernesto = trees.newTree("soldier");
	const robot = trees.newTree("soldier");
	trees.setClass(robot, [0], "commando");
	assert.equal(trees.placement(ernesto, pool(), [1], "Soldier").wrongTier, "soldier");
	const move = trees.moveTier({ ernesto, robot }, "ernesto", pool(), [[1]], "soldier");
	assert.deepEqual(move, { ok: true, tier: 2, empties: [{ unit: "ernesto", path: [] }, { unit: "robot", path: [] }] });
	assert.equal(ernesto.base, "soldier", "working out the move changes nothing");
});

test("a move that still breaks a rule once moved is refused", () => {
	const tree = trees.newTree("soldier");
	trees.setClass(tree, [0], "commando");
	trees.setClass(tree, [0, 0], "ranger");
	const local = { ...pool(), ranger: { name: "Ranger", tier: 2, notes: "" } };
	assert.match(trees.moveTier({ tree }, "tree", local, [[0, 1]], "ranger").error, /already under this tier-2 class/);
});

test("a draft is a class in the making, in the tree only: typing and notes before a name", () => {
	const tree = trees.newTree("soldier");
	trees.setTypes(tree, [0, 1], ["Simple", "Robo"]);
	trees.setDraft(tree, [0, 1], { notes: "slow, tanky" });
	trees.setDraft(tree, [0, 1], { name: " Big Boy " });
	assert.deepEqual(trees.slots(tree)[3].draft, { name: "Big Boy", notes: "slow, tanky" }, "naming it later keeps the notes");
	assert.deepEqual(trees.slots(tree)[3].types, ["Simple", "Robo"]);
	assert.equal(trees.designedCount(tree), 1, "a draft isn't a designed slot");
	assert.match(trees.treeText(tree), /"class": "",\n\t\t\t\t\t"draft": \{\n\t\t\t\t\t\t"name": "Big Boy"/);
	trees.setClass(tree, [0, 1], "ranger");
	assert.equal(trees.draftAt(tree, [0, 1]), null, "placing a class ends the draft");
	assert.deepEqual(trees.slots(tree)[3].types, ["Simple", "Robo"], "the typing is the slot's: it stays");
	assert.doesNotMatch(trees.treeText(tree), /draft/);
});

test("typing is each unit's: two trees' Colossus differ, and the base has its own", () => {
	const ernesto = trees.newTree("soldier");
	const archer = trees.newTree("soldier");
	trees.setClass(ernesto, [1, 1], "ranger");
	trees.setTypes(ernesto, [1, 1], ["Simple", "Robo"]);
	trees.setClass(archer, [0, 0], "ranger");
	trees.setTypes(archer, [0, 0], ["Cold"]);
	trees.setTypes(archer, [], ["Cold"]);
	assert.deepEqual(trees.typingsOf({ ernesto, archer }, "ranger"),
		[{ unit: "archer", types: ["Cold"] }, { unit: "ernesto", types: ["Simple", "Robo"] }]);
	assert.deepEqual(archer.base_types, ["Cold"]);
	assert.doesNotMatch(trees.classText({ name: "Ranger", tier: 3, notes: "", types: ["Fire"] }), /types/,
		"a class file never carries typing");
});

test("moving a class to another tier empties the slots holding it at its old one", () => {
	const ernesto = trees.newTree("soldier");
	const robot = trees.newTree("commando");
	trees.setClass(robot, [0, 0], "commando");
	assert.deepEqual(trees.retierEmpties({ ernesto, robot }, "soldier", 2), [{ unit: "ernesto", path: [] }]);
	assert.deepEqual(trees.retierEmpties({ ernesto, robot }, "commando", 3), [{ unit: "robot", path: [] }]);
});

test("a draft emptied of everything is gone", () => {
	const tree = trees.newTree("soldier");
	trees.setDraft(tree, [1], { name: "Legate", notes: "" });
	trees.setDraft(tree, [1], { name: "" });
	assert.equal(trees.draftAt(tree, [1]), null);
	assert.equal(tree.promotions[1].draft, undefined);
});

test("the same draft name under both branches is one merged card, as a shared class is", () => {
	const tree = trees.newTree("soldier");
	trees.setDraft(tree, [0, 0], { name: "Dynamo" });
	trees.setDraft(tree, [1, 0], { name: "dynamo" });
	trees.setDraft(tree, [1, 1], { notes: "unnamed drafts never merge" });
	const merged = trees.layout(tree).cards.filter((card) => card.paths.length === 2);
	assert.deepEqual(merged.map((card) => card.paths), [[[0, 0], [1, 0]]]);
	assert.deepEqual(trees.sharedClasses(tree), [], "a draft is no class: the rules don't see it");
});

test("a slot holding a class and a draft is a problem", () => {
	const tree = trees.newTree("soldier");
	trees.setClass(tree, [0], "commando");
	tree.promotions[0].draft = { name: "Big Boy", notes: "" };
	assert.deepEqual(trees.problems(tree, pool()), ["Commando has a draft too."]);
});

test("flipping the base swaps the branches, each taking its tier-3 classes along", () => {
	const tree = trees.newTree("soldier");
	trees.setClass(tree, [0], "commando");
	trees.setClass(tree, [0, 1], "ranger");
	trees.setDraft(tree, [1], { name: "Legate" });
	trees.flip(tree, []);
	assert.equal(tree.promotions[1].class, "commando");
	assert.equal(tree.promotions[1].promotions[1].class, "ranger");
	assert.equal(tree.promotions[0].draft.name, "Legate");
	trees.flip(tree, [1]);
	assert.equal(tree.promotions[1].promotions[0].class, "ranger", "a tier-2 flip swaps its two tier-3 classes");
});

test("a class can be shared between units", () => {
	const first = trees.newTree("soldier");
	const second = trees.newTree("soldier");
	trees.setClass(first, [1], "legionnaire");
	trees.setClass(second, [0], "legionnaire");
	assert.deepEqual(trees.usedBy({ unit_two: second, unit_one: first }, "legionnaire"), ["unit_one", "unit_two"]);
});

test("problems mirror the game's checks", () => {
	const tree = trees.newTree("soldier");
	trees.setClass(tree, [0], "ranger");
	trees.setClass(tree, [1], "jedi");
	assert.deepEqual(trees.problems(tree, pool()), ["Ranger is tier 3, in a tier-2 slot.", "jedi isn't in the pool."]);
});

test("every class tier list is sorted by name", () => {
	assert.deepEqual(trees.classesOfTier(pool(), 2).map((entry) => entry.name), ["Commando", "Legionnaire"]);
});

test("saving an untouched file changes nothing", () => {
	for (const folder of ["pool", "trees"]) {
		for (const name of fs.readdirSync(path.join(DATA, folder)).filter((file) => file.endsWith(".json"))) {
			const text = fs.readFileSync(path.join(DATA, folder, name), "utf8");
			const again = folder === "pool" ? trees.classText(JSON.parse(text)) : trees.treeText(JSON.parse(text));
			assert.equal(again, text, `${folder}/${name}`);
		}
	}
});

test("the trees on disk have no problems the page would show", () => {
	const pool = {};
	for (const name of fs.readdirSync(path.join(DATA, "pool")).filter((file) => file.endsWith(".json"))) {
		pool[name.slice(0, -5)] = JSON.parse(fs.readFileSync(path.join(DATA, "pool", name), "utf8"));
	}
	for (const name of fs.readdirSync(path.join(DATA, "trees")).filter((file) => file.endsWith(".json"))) {
		const tree = JSON.parse(fs.readFileSync(path.join(DATA, "trees", name), "utf8"));
		assert.deepEqual(trees.problems(tree, pool), [], name);
	}
});

test("a class's id is its name in lowercase, accents dropped, words joined by _", () => {
	assert.equal(trees.classId("El Capitán"), "el_capitan", "Lawrence's variant files are named after it");
	assert.equal(trees.classId("  King of Arms "), "king_of_arms");
});

test("every pool file is named for its class", () => {
	for (const name of fs.readdirSync(path.join(DATA, "pool")).filter((file) => file.endsWith(".json"))) {
		const entry = JSON.parse(fs.readFileSync(path.join(DATA, "pool", name), "utf8"));
		assert.equal(`${trees.classId(entry.name)}.json`, name, entry.name);
	}
});
