// Class tree editor: one unit's promotion tree at a time, drawn as a tree and
// saved straight into the game's data/classes/ (its README is the format; the
// game reads it through ClassTrees). Opened from disk like the art board, so
// it can't read files on its own: it asks once for the data/classes folder
// (File System Access API: Chrome, Edge, or Brave with
// brave://flags/#file-system-access-api) and IndexedDB remembers the grant.
// Units and their idle sprites come from game_data.js, the board's data; the
// rules (slots, placements, problems, file text) are class_tree_logic.js, and
// sprite thumbnails crop the way the board's do (board_logic.js spriteGeometry).
//
// Every edit saves the one file it touched: a slot or the tree's notes save
// trees/<unit>.json, a class's name or notes save pool/<class>.json. Typing is
// the unit's, not the class's: it lives on each slot, in the tree's file.
// A unit with no tree file yet gets one on its first edit. The one edit that
// touches more: a slot refusing a class of another tier offers to move the
// class to that tier, saving the class and every tree whose slot it leaves.
"use strict";

(function (global) {

const Logic = global.ClassTreeLogic;
const { spriteGeometry } = global.ArtBoardLogic;
const SPRITE_BOX = 56;  // CSS px, .slot-sprite
const REPOSITORY_ROOT = "../../";
const HANDLE_KEY = "classes";

const state = {
	remembered: null,  // the folder granted in an earlier session (IndexedDB)
	folder: null,      // the folder, once this session may read and write it
	loaded: false,     // every file read: nothing is editable before, or a fresh tree could replace a real one
	pool: {},      // class id → {name, tier, notes}
	trees: {},     // unit id → tree (only units with a file, plus the one being edited)
	unit: null,    // the unit on show
	selected: [],  // the selected slot's path
	errors: {},    // slot path → {text: why the last name typed there was refused, move: moveTier's offer or none}
};
const units = unitList();
const spriteFound = new Map();  // url → {width, height} once loaded, false when missing

// ------------------------------------------------------------------- data ----

// The characters from game_data.js, in the art board's ranking order.
function unitList() {
	const characters = (global.ART_DASHBOARD_DATA || {}).characters || [];
	const ranking = global.ART_DASHBOARD_RANKING || [];
	const rank = (id) => (ranking.includes(id) ? ranking.indexOf(id) : ranking.length);
	return characters.map((character) => ({
		id: character.id,
		name: character.name,
		currentClass: character.class,
		idle: ((character.requirements.find((requirement) => requirement.id === "idle") || {}).candidates || [])[0],
		clips: character.clips || {},
	})).sort((a, b) => rank(a.id) - rank(b.id) || a.name.localeCompare(b.name));
}

function unitNamed(id) {
	return units.find((unit) => unit.id === id) || null;
}

// The trees with a file: a unit merely open in the editor doesn't use its base class yet.
function savedTrees() {
	const saved = {};
	for (const id of Object.keys(state.trees)) if (!state.trees[id].unsaved) saved[id] = state.trees[id];
	return saved;
}

// The tree on show: the unit's file, or a fresh one with its class in code as the base.
function currentTree() {
	console.assert(state.loaded, "class trees: a tree asked for before the files were read");
	if (!state.trees[state.unit]) {
		const unit = unitNamed(state.unit);
		const today = unit ? state.pool[unit.currentClass] : null;
		const base = today && today.tier === 1 ? unit.currentClass : "";
		state.trees[state.unit] = Logic.newTree(base);
		state.trees[state.unit].unsaved = true;
	}
	return state.trees[state.unit];
}

// ------------------------------------------------------------ the folder ----

function database() {
	return new Promise((resolve, reject) => {
		const request = global.indexedDB.open("tbt-art-board", 1);
		request.onupgradeneeded = () => request.result.createObjectStore("handles");
		request.onsuccess = () => resolve(request.result);
		request.onerror = () => reject(request.error);
	});
}

async function storedHandle() {
	try {
		const store = (await database()).transaction("handles").objectStore("handles");
		return await new Promise((resolve) => {
			const request = store.get(HANDLE_KEY);
			request.onsuccess = () => resolve(request.result || null);
			request.onerror = () => resolve(null);
		});
	} catch (error) {
		return null;
	}
}

// Best effort: without it (a private window) the page still works, it just asks again next time.
async function storeHandle(handle) {
	try {
		(await database()).transaction("handles", "readwrite").objectStore("handles").put(handle, HANDLE_KEY);
	} catch (error) {
		// nothing to do
	}
}

async function hasFile(folder, name) {
	try {
		await folder.getFileHandle(name);
		return true;
	} catch (error) {
		return false;
	}
}

async function readFolder(name) {
	const entries = {};
	const folder = await state.folder.getDirectoryHandle(name, { create: true });
	for await (const [fileName, handle] of folder.entries()) {
		if (handle.kind !== "file" || !fileName.endsWith(".json")) continue;
		const text = await (await handle.getFile()).text();
		try {
			entries[fileName.slice(0, -5)] = JSON.parse(text);
		} catch (error) {
			setStatus(`${name}/${fileName} isn't valid JSON: ${error.message}`, true);
		}
	}
	return entries;
}

async function write(folderName, id, text) {
	const folder = await state.folder.getDirectoryHandle(folderName, { create: true });
	const writable = await (await folder.getFileHandle(`${id}.json`, { create: true })).createWritable();
	await writable.write(text);
	await writable.close();
	setStatus(`Saved ${folderName}/${id}.json at ${new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`);
}

// A fresh tree must never replace a file: true (and says so) when someone
// made the unit's file since the page read the folder.
async function freshTreeTaken(unitId) {
	if (!state.trees[unitId].unsaved) return false;
	const trees = await state.folder.getDirectoryHandle("trees", { create: true });
	if (!(await hasFile(trees, `${unitId}.json`))) return false;
	setStatus(`trees/${unitId}.json appeared on disk: reload the page before editing ${unitId}`, true);
	return true;
}

async function saveTree(unitId) {
	if (await freshTreeTaken(unitId)) throw new Error("refusing to replace a tree file with a fresh tree");
	delete state.trees[unitId].unsaved;
	await write("trees", unitId, Logic.treeText(state.trees[unitId]));
}

async function saveClass(classId) {
	await write("pool", classId, Logic.classText(state.pool[classId]));
}

async function connect() {
	try {
		if (state.remembered && (await state.remembered.requestPermission({ mode: "readwrite" })) === "granted") {
			state.folder = state.remembered;
			return load();
		}
		const handle = await global.showDirectoryPicker({ id: "tbt-class-data", mode: "readwrite" });
		if (handle.name !== "classes" || !(await hasFile(handle, "README.md"))) {
			global.alert("Pick the folder data/classes inside the game's repo.");
			return;
		}
		state.folder = handle;
		storeHandle(handle);  // not awaited: remembering the grant mustn't hold up the page
		await load();
	} catch (error) {
		if (error.name !== "AbortError") global.alert(`Couldn't open the folder: ${error.message}`);
	}
}

async function load() {
	state.loaded = false;
	setStatus("Reading data/classes…");
	render();
	state.pool = await readFolder("pool");
	state.trees = await readFolder("trees");
	state.loaded = true;
	document.getElementById("connect").hidden = true;
	if (!state.unit) state.unit = units.length ? units[0].id : Object.keys(state.trees)[0];
	setStatus(`${Object.keys(state.pool).length} classes, ${Object.keys(state.trees).length} trees`);
	render();
}

// ----------------------------------------------------------------- edits ----

// Put the class called `name` into the slots at `paths` (one, or both halves
// of a merged card): a pool class, or a draft's name when it names no class
// (a blank name keeps the draft's typing and notes). A new class gets made
// only for the base, or by `makeClass` (the draft's button), taking the
// draft's typing and notes along.
async function placeClass(paths, name, makeClass) {
	const tree = currentTree();
	if (await freshTreeTaken(state.unit)) return;  // before a new class gets made for it
	const path = paths[0];
	const key = path.join(".");
	if (!makeClass && path.length > 0 && !Logic.findByName(state.pool, name)) {
		delete state.errors[key];
		for (const each of paths) Logic.setDraft(tree, each, { name });
		state.selected = path;
		await saveTree(state.unit);
		render();
		return;
	}
	const result = Logic.placementAll(tree, state.pool, paths, name);
	if (!result.ok) {
		state.errors[key] = { text: result.error, move: null };
		if (result.wrongTier) {
			const move = Logic.moveTier(treesInPlay(), state.unit, state.pool, paths, result.wrongTier);
			if (move.ok) state.errors[key].move = { id: result.wrongTier, ...move };
		}
		render();
		return;
	}
	const draft = Logic.draftAt(tree, path);
	if (!makeClass && draftNotesLost(tree, paths, name.trim())) return render();
	delete state.errors[key];
	if (result.create) {
		state.pool[result.id] = { name: name.trim(), tier: path.length + 1,
			notes: draft ? draft.notes : "" };
		await saveClass(result.id);
	}
	for (const each of paths) Logic.setClass(tree, each, result.id);
	state.selected = path;
	await saveTree(state.unit);
	render();
}

// True when the person backs out of `className` replacing a draft that has
// notes: placing a class ends the draft, and its notes would go with it.
function draftNotesLost(tree, paths, className) {
	const draft = paths.map((path) => Logic.draftAt(tree, path)).find((each) => each && each.notes.trim());
	return Boolean(draft) && !global.confirm(`${className} replaces this slot's draft${draft.name ? ` (${draft.name})` : ""}, `
		+ `and its notes go with it:\n\n${draft.notes.trim()}\n\nPlace ${className} anyway?`);
}

// The slots the card holding `path` stands for: one, or both halves of a merged card.
function cardPaths(tree, path) {
	const card = Logic.layout(tree).cards.find((each) => each.paths.some((other) => other.join(".") === path.join(".")));
	return card ? card.paths : [path];
}

// The saved trees plus the one on show, saved or not: what a move of tier reaches.
function treesInPlay() {
	return { ...savedTrees(), [state.unit]: currentTree() };
}

// Move class `id` to the tier of the slots at `paths` and put it there (the
// offer under a wrong-tier refusal). Worked out again, since the trees may
// have changed since the offer; emptying another unit's slot asks first.
async function moveClassTier(paths, id) {
	const key = paths[0].join(".");
	const move = Logic.moveTier(treesInPlay(), state.unit, state.pool, paths, id);
	if (!move.ok) {
		state.errors[key] = { text: move.error, move: null };
		render();
		return;
	}
	const elsewhere = move.empties.filter((empty) => empty.unit !== state.unit);
	if (elsewhere.length && !global.confirm(`Moving ${state.pool[id].name} to tier ${move.tier} takes it out of `
		+ `${elsewhere.map(slotLabel).join(", ")}, leaving those slots empty. Move it?`)) return;
	if (draftNotesLost(currentTree(), paths, state.pool[id].name)) return;
	if (await freshTreeTaken(state.unit)) return;
	state.pool[id].tier = move.tier;
	await saveClass(id);
	for (const empty of move.empties) Logic.setClass(state.trees[empty.unit], empty.path, "");
	for (const path of paths) Logic.setClass(currentTree(), path, id);
	delete state.errors[key];
	state.selected = paths[0];
	for (const unit of new Set([state.unit, ...move.empties.map((empty) => empty.unit)])) await saveTree(unit);
	render();
}

// "Robot's base", "Ernesto's tier-3 slot under Engineer": a slot, said for a person.
function slotLabel({ unit, path }) {
	const owner = (unitNamed(unit) || { name: unit }).name;
	if (path.length === 0) return `${owner}'s base`;
	if (path.length === 1) return `${owner}'s tier-2 slot`;
	const parent = state.trees[unit].promotions[path[0]].class;
	return `${owner}'s tier-3 slot under ${(state.pool[parent] || { name: `choice ${path[0] + 1}` }).name}`;
}

// Swap the two slots under the one at `path`; the selection follows its slot.
async function flipBranches(path) {
	const tree = currentTree();
	if (await freshTreeTaken(state.unit)) return;
	Logic.flip(tree, path);
	const depth = path.length;
	if (state.selected.length > depth && path.every((index, at) => state.selected[at] === index)) {
		state.selected = state.selected.map((index, at) => (at === depth ? 1 - index : index));
	}
	state.errors = {};
	await saveTree(state.unit);
	render();
}

// The All classes table's tier picker: move class `id` to `tier` outright.
// The slots holding it at its old tier go empty, after asking.
async function retierClass(id, tier) {
	const empties = Logic.retierEmpties(savedTrees(), id, tier);
	if (empties.length && !global.confirm(`Moving ${state.pool[id].name} to tier ${tier} takes it out of `
		+ `${empties.map(slotLabel).join(", ")}, leaving those slots empty. Move it?`)) {
		render();
		return;
	}
	state.pool[id].tier = tier;
	await saveClass(id);
	for (const empty of empties) Logic.setClass(state.trees[empty.unit], empty.path, "");
	for (const unit of new Set(empties.map((empty) => empty.unit))) await saveTree(unit);
	// A tree with no file yet is made again, so its base is a tier-1 class again.
	for (const unit of Object.keys(state.trees)) if (state.trees[unit].unsaved) delete state.trees[unit];
	render();
}

async function setSlotTypes(tree, paths, unitId, types) {
	for (const path of paths) Logic.setTypes(tree, path, types);
	await saveTree(unitId);
	render();
}

async function setArt(paths, art) {
	for (const path of paths) Logic.setArt(currentTree(), path, art);
	await saveTree(state.unit);
	render();
}

async function editClass(classId, change) {
	change(state.pool[classId]);
	await saveClass(classId);
	render();
}

// ---------------------------------------------------------------- render ----

function element(tag, className, text) {
	const node = document.createElement(tag);
	if (className) node.className = className;
	if (text !== undefined) node.textContent = text;
	return node;
}

function setStatus(text, isError) {
	const status = document.getElementById("status");
	status.textContent = text;
	status.classList.toggle("status-error", Boolean(isError));
}

function render() {
	renderDatalists();
	renderUnits();
	renderTree();
	renderClassPanel();
	renderPool();
}

function renderDatalists() {
	const holder = document.getElementById("datalists");
	holder.replaceChildren();
	for (const tier of [1, 2, 3]) {
		const list = element("datalist");
		list.id = `tier-${tier}-classes`;
		for (const entry of Logic.classesOfTier(state.pool, tier)) list.append(new Option(entry.name));
		holder.append(list);
	}
}

function renderUnits() {
	const nav = document.getElementById("units");
	nav.replaceChildren(element("h2", "", "Units"));
	const shared = (name) => units.filter((unit) => unit.name === name).length > 1;
	const item = (id, name) => {
		const button = element("button", "unit-item" + (id === state.unit ? " selected" : ""));
		button.type = "button";
		button.title = `${id}.json`;
		if (shared(name)) name = `${name} (${id})`;  // the two buglers
		const tree = state.trees[id] && !state.trees[id].unsaved ? state.trees[id] : null;
		const designed = tree ? Logic.designedCount(tree) : 0;
		button.append(element("span", "", name), element("span", "unit-count" + (designed === 7 ? " complete" : ""), `${designed}/7`));
		button.addEventListener("click", () => {
			state.unit = id;
			state.selected = [];
			state.errors = {};
			render();
		});
		return button;
	};
	for (const unit of units) nav.append(item(unit.id, unit.name));
	const homeless = Object.keys(savedTrees()).filter((id) => !unitNamed(id)).sort();
	if (homeless.length) {
		nav.append(element("h2", "", "No unit yet"));
		for (const id of homeless) nav.append(item(id, id));
	}
}

function renderTree() {
	const view = document.getElementById("tree");
	view.replaceChildren();
	if (state.folder && !state.loaded) {
		view.append(element("p", "tree-subtitle", "Reading data/classes…"));
		return;
	}
	if (!state.folder) {
		const message = global.showDirectoryPicker
			? "Connect the data/classes folder (top right) to see and edit the trees."
			: "This browser can't open folders. Use Chrome or Edge, or Brave with brave://flags/#file-system-access-api turned on.";
		view.append(element("p", "tree-subtitle", message));
		return;
	}
	const unit = unitNamed(state.unit);
	const tree = currentTree();
	view.append(element("h2", "", unit ? unit.name : state.unit));
	const today = state.pool[unit ? unit.currentClass : ""];
	let subtitle = unit
		? `${unit.id}.json · its class in the game today: ${today ? today.name : unit.currentClass}${tree.unsaved ? " · no tree file yet: the first edit makes one" : ""}`
		: `${state.unit}: a tree with no unit yet`;
	const shared = Logic.sharedClasses(tree);
	if (shared.length) {
		subtitle += ` · ${Logic.classCount(tree)} classes: both branches reach ${(state.pool[shared[0]] || { name: shared[0] }).name}`;
	}
	view.append(element("p", "tree-subtitle", subtitle));

	const grid = element("div", "tree-grid");
	["Base · levels 1–20", "Tier 2 · from level 21", "Tier 3 · from level 41"].forEach((label, column) => {
		const heading = element("div", "tree-column-label", label);
		heading.style.gridColumn = String(column + 1);
		heading.style.gridRow = "1";
		grid.append(heading);
	});
	const { cards, edges } = Logic.layout(tree);
	const merged = cards.some((card) => card.paths.length > 1);
	const slotsByPath = new Map(Logic.slots(tree).map((slot) => [slot.path.join("."), slot]));
	const nodes = cards.map((card) => {
		const node = slotCard(card, slotsByPath.get(card.paths[0].join(".")), merged);
		node.style.gridColumn = String(card.tier);
		node.style.gridRow = `${2 + card.row} / span ${card.span}`;  // row 1 is the column labels
		grid.append(node);
		return node;
	});
	view.append(grid);
	drawLines(grid, edges.map(([parent, child]) => [nodes[parent], nodes[child]]));

	const name = unit ? unit.name : state.unit;
	view.append(element("h3", "notes-heading", `Notes on ${name}'s tree`));
	view.append(element("p", "panel-hint", "The whole tree: what it's for, how the branches differ, open questions. Saved in the tree's file as you type."));
	const notes = element("textarea", "tree-notes");
	notes.placeholder = `Anything about ${name}'s classes as a whole`;
	notes.value = tree.notes || "";
	const unitId = state.unit;  // the save may land after another unit is picked
	autosave(notes, async () => {
		tree.notes = notes.value;
		await saveTree(unitId);
		renderUnits();  // a first save turns "no tree file yet" into a counted tree
	});
	view.append(notes);
	const problems = Logic.problems(tree, state.pool);
	if (problems.length) {
		const list = element("ul", "tree-problems");
		for (const problem of problems) list.append(element("li", "", problem));
		view.append(list);
	}
}

// One card: a slot, or a merged tier-3 card standing for one slot under each
// branch (layout.paths), which every edit here changes together. `merged`:
// the tree has a merged card, which fixes the tier-3 order the view shows.
function slotCard(layoutCard, slot, merged) {
	const paths = layoutCard.paths;
	const entry = slot.classId ? state.pool[slot.classId] : null;
	const key = slot.path.join(".");
	const selected = paths.some((path) => path.join(".") === state.selected.join("."));
	const card = element("div", "slot" + (entry ? "" : " empty") + (slot.draft ? " draft" : "") + (selected ? " selected" : ""));
	card.addEventListener("click", (event) => {
		if (event.target.closest("input, select, button")) return;
		state.selected = slot.path;
		render();
	});

	card.append(spriteBox(slot));
	const name = element("input", "slot-class");
	name.value = entry ? entry.name : slot.classId || (slot.draft ? slot.draft.name : "");
	name.placeholder = slot.tier === 1 ? "Base class" : "Not designed yet";
	name.setAttribute("list", `tier-${slot.tier}-classes`);
	name.addEventListener("change", () => placeClass(paths, name.value));
	name.addEventListener("focus", () => {
		state.selected = slot.path;
		renderClassPanel();
		for (const other of document.querySelectorAll(".slot.selected")) other.classList.remove("selected");
		card.classList.add("selected");
	});
	card.append(name);
	const typing = slot.types.join(" / ");
	const types = entry ? typing || "types not set" : slot.draft ? ["draft", typing].filter(Boolean).join(" · ") : typing;
	card.append(element("div", "slot-types", types));
	if (slot.tier > 1) {
		const art = element("select", "slot-art");
		art.title = "How this class's art gets made for this unit";
		for (const kind of Logic.ART_KINDS) art.append(new Option(kind.label, kind.id, false, kind.id === slot.art));
		art.addEventListener("change", () => setArt(paths, art.value));
		card.append(art);
	}
	if (slot.tier === 1 || (slot.tier === 2 && !merged)) card.append(flipButton(slot));
	const error = state.errors[key];
	if (error) {
		const box = element("div", "slot-error", error.text);
		if (error.move) box.append(moveOffer(paths, error.move));
		card.append(box);
	}
	return card;
}

// The flip, sitting on the fork of the lines out of a card.
function flipButton(slot) {
	const button = element("button", "slot-flip", "⇅");
	button.type = "button";
	button.title = slot.tier === 1
		? "Flip the two branches: each tier-2 class takes its tier-3 classes along"
		: "Flip the two tier-3 classes under this one";
	button.addEventListener("click", () => flipBranches(slot.path));
	return button;
}

// The way out under a wrong-tier refusal: a button, and what it would empty.
function moveOffer(paths, move) {
	const offer = element("div", "slot-fix");
	const button = element("button", "notes-button", `Move ${state.pool[move.id].name} to tier ${move.tier}`);
	button.type = "button";
	button.addEventListener("click", () => moveClassTier(paths, move.id));
	offer.append(button);
	if (move.empties.length) offer.append(element("span", "panel-hint", `Takes it out of ${move.empties.map(slotLabel).join(", ")}`));
	return offer;
}

// The tree's lines, drawn over the grid once it's laid out: from each card's
// right edge to the left edge of each card it promotes into. A merged card
// has two coming in. Redrawn when the grid resizes.
const SVG = "http://www.w3.org/2000/svg";
function drawLines(grid, pairs) {
	const svg = document.createElementNS(SVG, "svg");
	svg.classList.add("tree-lines");
	grid.prepend(svg);
	const draw = () => {
		const box = grid.getBoundingClientRect();
		svg.setAttribute("width", String(box.width));
		svg.setAttribute("height", String(box.height));
		svg.replaceChildren();
		for (const [parent, child] of pairs) {
			const from = parent.getBoundingClientRect();
			const to = child.getBoundingClientRect();
			// Whole pixels plus a half: a 1px line on a pixel row, not across two.
			const x1 = Math.round(from.right - box.left);
			const y1 = Math.round(from.top + from.height / 2 - box.top) + 0.5;
			const x2 = Math.round(to.left - box.left);
			const y2 = Math.round(to.top + to.height / 2 - box.top) + 0.5;
			const middle = Math.round((x1 + x2) / 2) + 0.5;
			const line = document.createElementNS(SVG, "path");
			line.setAttribute("d", `M${x1} ${y1} H${middle} V${y2} H${x2}`);
			svg.append(line);
		}
	};
	global.requestAnimationFrame(draw);
	new ResizeObserver(draw).observe(grid);
}

// The slot's idle sprite: the unit's own for the base, <unit>_<class> for a promotion.
function spriteBox(slot) {
	const box = element("div", "slot-sprite");
	const unit = unitNamed(state.unit);
	let url = null;
	if (unit && slot.tier === 1 && unit.idle) url = REPOSITORY_ROOT + unit.idle.path;
	else if (unit && slot.classId) url = `${REPOSITORY_ROOT}art/sprites/characters/${unit.id}_${slot.classId}/idle.png`;
	const missing = !slot.classId ? "" : slot.art === "redraw" ? "not drawn yet" : slot.tier === 1 ? "no art" : "not made yet";
	if (!url) {
		box.textContent = missing;
		return box;
	}
	// The first frame, cropped to the art's used pixels: the unit's own idle
	// bounds, which a palette-swapped variant shares.
	const bounds = unit && unit.idle && unit.clips[unit.idle.path] ? unit.clips[unit.idle.path].art_bounds : null;
	const show = (size) => {
		if (!size) {
			box.textContent = missing;
			return;
		}
		const geometry = spriteGeometry(size, 0, bounds, global.devicePixelRatio || 1, SPRITE_BOX);
		const art = element("div", "slot-sprite-art");
		art.style.width = `${geometry.width}px`;
		art.style.height = `${geometry.height}px`;
		art.style.backgroundImage = `url("${url}")`;
		art.style.backgroundSize = `${geometry.size[0]}px ${geometry.size[1]}px`;
		art.style.backgroundPosition = `${geometry.position[0]}px ${geometry.position[1]}px`;
		box.append(art);
	};
	if (spriteFound.has(url)) show(spriteFound.get(url));
	else {
		const probe = new Image();
		probe.onload = () => {
			spriteFound.set(url, { width: probe.naturalWidth, height: probe.naturalHeight });
			show(spriteFound.get(url));
		};
		probe.onerror = () => { spriteFound.set(url, false); show(false); };
		probe.src = url;
	}
	return box;
}

function renderClassPanel() {
	const panel = document.getElementById("class-panel");
	panel.replaceChildren();
	if (!state.loaded) return;
	const tree = currentTree();
	const slot = Logic.slots(tree).find((each) => each.path.join(".") === state.selected.join("."));
	const entry = slot && slot.classId ? state.pool[slot.classId] : null;
	if (!entry && slot && slot.tier > 1) {
		renderDraftPanel(panel, tree, slot);
		return;
	}
	if (!entry) {
		panel.append(element("h3", "", "Class"),
			element("p", "panel-hint", "Click a slot to edit it: its typing in this unit's tree, and its class's name and notes, "
				+ "the same in every tree that uses it. An empty slot takes typing and notes before it has a name."));
		return;
	}
	const id = slot.classId;
	const paths = cardPaths(tree, slot.path);
	const unitId = state.unit;  // the save may land after another unit is picked
	panel.append(element("h3", "", entry.name));
	panel.append(element("p", "panel-hint", `Tier ${entry.tier} · file pool/${id}.json`));
	panel.append(element("h4", "panel-section", `As ${(unitNamed(unitId) || { name: unitId }).name}'s ${entry.name}`));
	panel.append(...typePickers(slot.types, (types) => setSlotTypes(tree, paths, unitId, types)));
	panel.append(element("h4", "panel-section", "The class, in every tree"));

	const name = element("input");
	name.value = entry.name;
	name.addEventListener("change", () => {
		if (!name.value.trim()) return render();
		editClass(id, (edited) => { edited.name = name.value.trim(); });
	});
	panel.append(labelled("Name", name));

	const notes = element("textarea", "class-notes");
	notes.placeholder = `Anything about the ${entry.name} class, in every tree that uses it`;
	notes.value = entry.notes || "";
	autosave(notes, async () => {
		entry.notes = notes.value;
		await saveClass(id);
	});
	panel.append(labelled("Notes on the class", notes));

	const users = Logic.typingsOf(savedTrees(), id);
	if (!users.length) {
		panel.append(element("p", "panel-hint", "No saved tree uses it yet."));
		return;
	}
	panel.append(element("p", "panel-hint", users.length > 1 ? `Shared by ${users.length} trees, each with its own typing:` : "Used by:"));
	const list = element("ul", "used-by");
	for (const user of users) list.append(element("li", "", typedUser(user)));
	panel.append(list);
}

// An empty promotion slot, or one holding a draft: typing and notes before
// (or without) a name, kept in the tree's file until it's made a class.
function renderDraftPanel(panel, tree, slot) {
	const draft = slot.draft || { name: "", notes: "" };
	const paths = cardPaths(tree, slot.path);
	const unitId = state.unit;  // the save may land after another unit is picked
	const change = async (changes) => {
		for (const path of paths) Logic.setDraft(tree, path, changes);
		await saveTree(unitId);
	};
	panel.append(element("h3", "", draft.name || (slot.draft ? "Unnamed draft" : "Empty slot")));
	panel.append(element("p", "panel-hint", "A draft: a class in the making, kept in this tree's file only. "
		+ "The game reads the slot as empty, and no other tree can pick it. Name it in its slot."));
	panel.append(...typePickers(slot.types, (types) => setSlotTypes(tree, paths, unitId, types)));
	const notes = element("textarea", "class-notes");
	notes.placeholder = "What this class could be, name or no name";
	notes.value = draft.notes;
	autosave(notes, () => change({ notes: notes.value }));
	panel.append(labelled("Notes on the draft", notes));
	if (!draft.name) {
		panel.append(element("p", "panel-hint", "Once it has a name, it can become a class."));
		return;
	}
	const make = element("button", "notes-button", "Make it a class");
	make.type = "button";
	make.addEventListener("click", () => placeClass(paths, draft.name, true));
	panel.append(make);
	panel.append(element("p", "panel-hint", `Creates pool/${Logic.classId(draft.name)}.json: a tier-${slot.tier} class `
		+ "with these notes, which any tree can use. The typing stays this slot's."));
}

// "Ernesto: Simple / Robo": a unit using a class, and its typing for it.
function typedUser({ unit, types }) {
	return `${(unitNamed(unit) || { name: unit }).name}: ${types.join(" / ") || "types not set"}`;
}

// The Type and Second type pickers; `save` gets the new list, a repeat dropped.
function typePickers(current, save) {
	return [0, 1].map((index) => {
		const type = element("select");
		type.append(new Option("—", ""));
		for (const each of Logic.ELEMENTAL_TYPES) type.append(new Option(each, each, false, current[index] === each));
		type.addEventListener("change", () => {
			const types = [current[0] || "", current[1] || ""];
			types[index] = type.value;
			save(types.filter(Boolean).filter((each, at, all) => all.indexOf(each) === at));
		});
		return labelled(index === 0 ? "Type" : "Second type", type);
	});
}

// Long writing saves itself: a pause in typing, or leaving the box, writes
// the file. No re-render, so the cursor and scroll stay where they are.
const AUTOSAVE_PAUSE_MS = 900;
function autosave(textarea, save) {
	let timer = null;
	let saved = textarea.value;
	const flush = async () => {
		clearTimeout(timer);
		if (textarea.value === saved) return;
		saved = textarea.value;
		try {
			await save();
		} catch (error) {
			setStatus(`Not saved: ${error.message}`, true);
		}
	};
	textarea.addEventListener("input", () => {
		clearTimeout(timer);
		timer = setTimeout(flush, AUTOSAVE_PAUSE_MS);
		setStatus("Typing…");
	});
	textarea.addEventListener("change", flush);
	textarea.addEventListener("blur", flush);
}

function labelled(text, control) {
	const label = element("label", "", text);
	label.append(control);
	return label;
}

function renderPool() {
	const body = document.querySelector("#pool .pool-body");
	body.replaceChildren();
	const table = element("table");
	const head = element("tr");
	for (const title of ["Class", "Tier", "Used by (and its typing there)"]) head.append(element("th", "", title));
	table.append(head);
	for (const tier of [1, 2, 3]) {
		for (const entry of Logic.classesOfTier(state.pool, tier)) {
			const users = Logic.typingsOf(savedTrees(), entry.id);
			const row = element("tr", users.length ? "" : "unused");
			const picker = element("select", "pool-tier");
			picker.title = `Move ${entry.name} to another tier`;
			for (const each of [1, 2, 3]) picker.append(new Option(String(each), String(each), false, each === tier));
			picker.addEventListener("change", () => retierClass(entry.id, Number(picker.value)));
			const tierCell = element("td");
			tierCell.append(picker);
			row.append(element("td", "", entry.name), tierCell,
				element("td", "", users.map(typedUser).join(", ") || "no tree yet"));
			table.append(row);
		}
	}
	body.append(table);
}

// ----------------------------------------------------------------- start ----

async function start() {
	document.getElementById("connect").addEventListener("click", connect);
	render();
	if (!global.showDirectoryPicker) {
		setStatus("Can't open folders in this browser", true);
		document.getElementById("connect").hidden = true;
		return;
	}
	state.remembered = await storedHandle();
	if (state.folder) return;  // connected by hand while IndexedDB answered
	if (!state.remembered) {
		setStatus("Not connected");
		return;
	}
	if ((await state.remembered.queryPermission({ mode: "readwrite" })) === "granted") {
		state.folder = state.remembered;
		await load();
		return;
	}
	document.getElementById("connect").textContent = "Allow data/classes";
	setStatus("Allow access to continue");
}

start();

})(window);
