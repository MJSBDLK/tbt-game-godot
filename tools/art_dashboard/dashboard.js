// Art board: Lawrence's bookmark. Opened straight from disk (file://), so it
// can load images and scripts but not JSON or folder listings. The game's
// facts come from game_data.js (generated); PRESENCE is decided here by
// loading each candidate file as an image, so the board always shows what's
// on disk, not what someone last typed.
//
// Flow: paint the last check from browser storage, load every candidate,
// repaint, save. The window regaining focus re-checks, so alt-tabbing back
// from Aseprite shows the export. Line art is 3024×4032 (≈48 MB decoded
// each), so found line art is only re-read on a full reload; sprites every time.
//
// Each character is a <details>: closed, one pip per box (so closed rows line
// up like a grid); open, its boxes grouped by the color that needs them. New
// boxes go in game_data_generator.gd's COLUMNS and need no layout work here.
//
// Notes need the File System Access API (Brave: brave://flags/#file-system-access-api).
// The page is only ever granted tools/art_dashboard/notes/, and works without it.
"use strict";

(function (global) {

const REPOSITORY_ROOT = "../../";
const DEFAULT_FPS = 12;  // ClipPlayer.DEFAULT_FPS
const THUMBNAIL_SIZE = 64;  // CSS px; sprites scale by whole device pixels inside it
const IDLE_COLUMNS = ["idle", "idle_animation"];
const NEXT_TIER = { red: "orange", orange: "yellow", yellow: "green" };


// ---------------------------------------------------------------- logic ----
// Pure: no DOM, so tools/art_dashboard/dashboard_test.js runs these in node.

function frameCount(probe) {
	return Math.max(1, Math.floor(probe.width / probe.height));
}

// The candidate a requirement's cell shows, or null. Convention files win:
// after a rename the new file is the one Lawrence just made.
function shownCandidate(requirement, probes) {
	const minimumFrames = requirement.min_frames || 1;
	const found = requirement.candidates.filter((candidate) => {
		const probe = probes[candidate.path];
		return probe && probe.exists && (minimumFrames === 1 || frameCount(probe) >= minimumFrames);
	});
	return found.find((candidate) => candidate.convention) || found[0] || null;
}

// A plain melee clip filling the "melee physical" box: it counts, but the
// box says whose clip it is. Idle and line art candidates carry no clip.
function isStandIn(requirement, candidate) {
	return Boolean(candidate && candidate.clip) && candidate.clip !== requirement.id;
}

// What a box shows. "optional": an extra no color needs yet (crits).
// "placeholder": in the game for now, but it doesn't count (placeholders.js).
function boxState(requirement, shown, placeholder) {
	if (shown) return isStandIn(requirement, shown) ? "stand-in" : "shown";
	if (placeholder) return "placeholder";
	if (!requirement.needed) return "not-needed";
	return requirement.tier === "extra" ? "optional" : "missing";
}

// Tier = one below the lowest tier with an unmet, needed requirement.
// "extra" requirements sit outside the ladder, so they never lower it.
// `placeholders` (path → why) never count; they're kept to show on the box.
function evaluateCharacter(character, probes, placeholders = {}) {
	const shown = {};
	const placeholderShown = {};
	for (const requirement of character.requirements) {
		const counted = requirement.candidates.filter((candidate) => !(candidate.path in placeholders));
		shown[requirement.id] = shownCandidate({ ...requirement, candidates: counted }, probes);
		if (!shown[requirement.id]) placeholderShown[requirement.id] = shownCandidate(requirement, probes);
	}
	const unmet = character.requirements.filter((requirement) => requirement.needed && !shown[requirement.id]);
	let tier = "green";
	for (const [needsTier, belowTier] of [["orange", "red"], ["yellow", "orange"], ["green", "yellow"]]) {
		if (unmet.some((requirement) => requirement.tier === needsTier)) {
			tier = belowTier;
			break;
		}
	}
	const nextTier = NEXT_TIER[tier];
	return {
		shown,
		placeholders: placeholderShown,
		unmet,
		tier,
		missingForNext: nextTier ? unmet.filter((requirement) => requirement.tier === nextTier) : [],
	};
}

// Ranked ids first in ranking order, the rest alphabetically after.
function sortCharacters(characters, ranking) {
	const rankOf = new Map(ranking.map((id, index) => [id, index]));
	return characters.slice().sort((first, second) => {
		const firstRank = rankOf.has(first.id) ? rankOf.get(first.id) : Infinity;
		const secondRank = rankOf.has(second.id) ? rankOf.get(second.id) : Infinity;
		return firstRank - secondRank || first.id.localeCompare(second.id);
	});
}

// Declared files off the convention whose convention twin doesn't exist yet.
function pendingRenames(characters, probes) {
	const seen = new Set();
	const renames = [];
	for (const character of characters) {
		for (const requirement of character.requirements) {
			for (const candidate of requirement.candidates) {
				if (!candidate.rename_to || seen.has(candidate.path)) continue;
				const from = probes[candidate.path];
				const to = probes[candidate.rename_to];
				if (!from || !from.exists || (to && to.exists)) continue;
				seen.add(candidate.path);
				renames.push({
					character: character.id,
					from: candidate.path,
					to: candidate.rename_to,
					how: renameInstruction(candidate.path, candidate.rename_to),
				});
			}
		}
	}
	return renames;
}

// Sprites are named by the exporter: folder = .aseprite file, file = tag.
const folderName = (path) => path.split("/").slice(-2, -1)[0];
const fileStem = (path) => path.split("/").pop().replace(/\.png$/, "");

// So a renamed PNG would come back on the next export: rename at the source.
function renameInstruction(from, to) {
	if (!from.startsWith("art/sprites/")) {
		return `Rename ${from.split("/").pop()} to ${to.split("/").pop()}.`;
	}
	const steps = [];
	if (folderName(from) !== folderName(to)) {
		steps.push(`${folderName(from)}.aseprite → ${folderName(to)}.aseprite`);
	}
	if (fileStem(from) !== fileStem(to)) {
		steps.push(`tag "${fileStem(from)}" → "${fileStem(to)}"`);
	}
	return `In Aseprite: ${steps.join(", ")}, then re-export.`;
}

// How to make a box's file: a sprite box is a tag in the character's
// .aseprite, line art is a file to save.
function deliveryHint(path, minimumFrames = 1) {
	if (!path.startsWith("art/sprites/")) return `Save as ${path}`;
	const frames = minimumFrames > 1 ? ` with ${minimumFrames}+ frames` : "";
	return `Tag "${fileStem(path)}"${frames} in ${folderName(path)}.aseprite, then Export Tags as PNGs`;
}

// `characterId` null: the generic form, for the box key.
function boxHint(column, characterId) {
	const path = column.convention.replaceAll("{id}", characterId || "<id>");
	return deliveryHint(path, column.min_frames);
}

function keyframeIndex(columnId, timing, frames) {
	if (IDLE_COLUMNS.includes(columnId)) return 0;
	const hitFrame = timing && Number.isInteger(timing.hit_frame) ? timing.hit_frame : Math.floor(frames / 2);
	return Math.min(Math.max(hitFrame, 0), frames - 1);
}

function frameDurations(timing, frames) {
	if (timing && Array.isArray(timing.frame_durations_ms) && timing.frame_durations_ms.length === frames) {
		return timing.frame_durations_ms;
	}
	const fps = Math.max(1, (timing && timing.fps) || DEFAULT_FPS);
	return new Array(frames).fill(1000 / fps);
}

// Background geometry for one frame of a strip at whole-device-pixel scale.
// `bounds` (the idle's art_bounds) crops to the figure so it reads bigger.
function spriteGeometry(probe, frameIndex, bounds, deviceRatio, size = THUMBNAIL_SIZE) {
	const frameSize = probe.height;
	const padding = 2;
	const crop = bounds
		? {
			left: Math.max(0, bounds.left - padding), top: Math.max(0, bounds.top - padding),
			right: Math.min(frameSize, bounds.right + padding), bottom: Math.min(frameSize, bounds.bottom + padding),
		}
		: { left: 0, top: 0, right: frameSize, bottom: frameSize };
	const cropWidth = crop.right - crop.left;
	const cropHeight = crop.bottom - crop.top;
	const deviceScale = Math.max(1, Math.floor((size * deviceRatio) / Math.max(cropWidth, cropHeight)));
	const scale = deviceScale / deviceRatio;
	return {
		width: cropWidth * scale,
		height: cropHeight * scale,
		size: [probe.width * scale, probe.height * scale],
		position: [-(frameIndex * frameSize + crop.left) * scale, -crop.top * scale],
		frameStep: frameSize * scale,
	};
}

// Line art: the portrait crop when it's on this file, else the top of the art.
function lineArtGeometry(probe, crop, path) {
	if (crop && crop.atlas === path && crop.width > 0) {
		const scale = THUMBNAIL_SIZE / crop.width;
		return {
			width: THUMBNAIL_SIZE,
			height: crop.height * scale,
			size: [probe.width * scale, probe.height * scale],
			position: [-crop.x * scale, -crop.y * scale],
		};
	}
	const scale = THUMBNAIL_SIZE / Math.min(probe.width, probe.height);
	return {
		width: THUMBNAIL_SIZE,
		height: THUMBNAIL_SIZE,
		size: [probe.width * scale, probe.height * scale],
		position: [-(probe.width * scale - THUMBNAIL_SIZE) / 2, 0],
	};
}

const logic = {
	frameCount, shownCandidate, isStandIn, boxState, evaluateCharacter, sortCharacters, pendingRenames,
	renameInstruction, deliveryHint, boxHint, keyframeIndex, frameDurations, spriteGeometry, lineArtGeometry,
};
if (typeof module !== "undefined") {
	module.exports = logic;
	return;
}


// --------------------------------------------------------------- probing ----

// Every file:// page shares one storage origin, so the key names the page.
const CACHE_KEY = "tbt-art-board:" + global.location.pathname;
const probes = {};  // path → {exists, width, height, url}
const pageStamp = Date.now();

function probe(path, stamp) {
	return new Promise((resolve) => {
		const image = new Image();
		const url = REPOSITORY_ROOT + path + "?v=" + stamp;
		image.onload = () => resolve({ exists: true, width: image.naturalWidth, height: image.naturalHeight, url });
		image.onerror = () => resolve({ exists: false, width: 0, height: 0, url });
		image.src = url;
	});
}

function allCandidatePaths(data) {
	const paths = new Map();  // path → is line art
	for (const character of data.characters) {
		for (const requirement of character.requirements) {
			for (const candidate of requirement.candidates) {
				paths.set(candidate.path, requirement.id === "line_art");
				if (candidate.rename_to) paths.set(candidate.rename_to, requirement.id === "line_art");
			}
		}
	}
	return paths;
}

let checking = null;
async function checkFiles(data, { fullReload }) {
	if (checking) return checking;
	const stamp = Date.now();
	const started = performance.now();
	const work = [];
	for (const [path, isLineArt] of allCandidatePaths(data)) {
		const known = probes[path];
		// Found line art keeps its decoded image until a full reload (see header).
		if (!fullReload && isLineArt && known && known.exists) continue;
		work.push(probe(path, stamp).then((result) => { probes[path] = result; }));
	}
	checking = Promise.all(work).then(() => {
		checking = null;
		return performance.now() - started;
	});
	return checking;
}

function loadCache() {
	try {
		const cached = JSON.parse(global.localStorage.getItem(CACHE_KEY) || "null");
		if (!cached || !cached.probes) return null;
		for (const [path, result] of Object.entries(cached.probes)) {
			probes[path] = { ...result, url: REPOSITORY_ROOT + path + "?v=" + pageStamp };
		}
		return cached.checkedAt;
	} catch (error) {
		return null;
	}
}

function saveCache() {
	const stored = {};
	for (const [path, result] of Object.entries(probes)) {
		stored[path] = { exists: result.exists, width: result.width, height: result.height };
	}
	try {
		global.localStorage.setItem(CACHE_KEY, JSON.stringify({ checkedAt: Date.now(), probes: stored }));
	} catch (error) {
		// Storage off (private window): the board just paints after the check.
	}
}


// ------------------------------------------------------------- rendering ----

const element = (tag, className, text) => {
	const node = document.createElement(tag);
	if (className) node.className = className;
	if (text !== undefined) node.textContent = text;
	return node;
};

const TIER_LABELS = { red: "Red", orange: "Orange", yellow: "Yellow", green: "Green" };
const BOX_GROUPS = [
	{ tier: "orange", label: "Orange needs" },
	{ tier: "yellow", label: "Yellow needs" },
	{ tier: "green", label: "Green needs" },
	{ tier: "extra", label: "Extras: no color needs these yet" },
];
const STATE_WORDS = {
	shown: "done", "stand-in": "covered by another clip", missing: "missing",
	optional: "optional", "not-needed": "its moves never play it",
	placeholder: "placeholder, doesn't count",
};
// Path → why the file doesn't count yet (placeholders.js).
let placeholderReasons = {};
const SUMMARY_THUMBNAIL_SIZE = 36;

// Characters open in the grid. null until the viewer opens or closes one:
// until then the next-up character is the open one, and follows along.
const OPEN_KEY = "tbt-art-board-open:" + global.location.pathname;
let openCharacters = loadOpen();

function loadOpen() {
	try {
		const stored = JSON.parse(global.localStorage.getItem(OPEN_KEY) || "null");
		return Array.isArray(stored) ? new Set(stored) : null;
	} catch (error) {
		return null;
	}
}

function saveOpen() {
	try {
		global.localStorage.setItem(OPEN_KEY, JSON.stringify([...openCharacters]));
	} catch (error) {
		// Storage off: open rows just don't survive a reload.
	}
}

let nextUpId = null;
const isOpen = (id) => (openCharacters ? openCharacters.has(id) : id === nextUpId);

function render(data, ranking) {
	stopPlayback();
	const characters = sortCharacters(data.characters, ranking);
	const evaluations = new Map(characters.map((character) =>
		[character.id, evaluateCharacter(character, probes, placeholderReasons)]));
	const columns = data.columns;
	const next = characters.find((character) => ["red", "orange"].includes(evaluations.get(character.id).tier));
	nextUpId = next ? next.id : null;
	renderSummary(characters, evaluations);
	renderNextUp(next, evaluations, ranking, columns);
	renderRenames(pendingRenames(characters, probes), characters);
	renderGrid(characters, evaluations, columns, ranking);
	Notes.decorate();
}

function renderSummary(characters, evaluations) {
	const summary = document.getElementById("summary");
	summary.replaceChildren();
	for (const tier of ["red", "orange", "yellow", "green"]) {
		const count = characters.filter((character) => evaluations.get(character.id).tier === tier).length;
		const chip = element("span", `tier-chip tier-${tier}`, `${TIER_LABELS[tier]} ${count}`);
		summary.append(chip);
	}
	const goodEnough = characters.filter((character) => ["yellow", "green"].includes(evaluations.get(character.id).tier)).length;
	summary.append(element("span", "summary-alpha", `Good enough for alpha: ${goodEnough} of ${characters.length}`));
}

function renderNextUp(next, evaluations, ranking, columns) {
	const panel = document.getElementById("next-up");
	panel.replaceChildren();
	if (!next) {
		panel.append(element("span", "next-up-done", "Every character is good enough for alpha."));
		return;
	}
	const evaluation = evaluations.get(next.id);
	const rank = ranking.indexOf(next.id);
	panel.append(element("span", "next-up-label", "Next up"));
	panel.append(element("span", "next-up-name", (rank >= 0 ? `#${rank + 1} ` : "") + next.name));
	panel.append(element("span", "next-up-needs", `to reach ${TIER_LABELS[NEXT_TIER[evaluation.tier]].toLowerCase()}:`));
	const list = element("ul", "next-up-list");
	for (const requirement of evaluation.missingForNext) {
		const column = columns.find((candidate) => candidate.id === requirement.id);
		const item = element("li");
		item.append(element("span", "need-chip", column.label), element("span", "need-how", boxHint(column, next.id)));
		const placeholder = evaluation.placeholders[requirement.id];
		if (placeholder) item.append(element("span", "need-placeholder", `Placeholder in the game now: ${placeholderReasons[placeholder.path]}`));
		list.append(item);
	}
	panel.append(list);
}

function columnLabel(id, columns) {
	const column = columns.find((candidate) => candidate.id === id);
	return column ? column.label : id;
}

function renderRenames(renames, characters) {
	const panel = document.getElementById("renames");
	panel.hidden = renames.length === 0;
	panel.querySelector("summary").textContent = `Renames to do (${renames.length})`;
	const list = panel.querySelector("ul");
	list.replaceChildren();
	for (const character of characters) {
		const own = renames.filter((rename) => rename.character === character.id);
		if (own.length === 0) continue;
		const group = element("li", "rename-group");
		group.append(element("strong", "", character.name));
		const items = element("ul");
		for (const rename of own) {
			const item = element("li");
			item.append(element("code", "", rename.from), element("span", "rename-arrow", " → "),
				element("code", "", rename.to), element("span", "rename-how", rename.how));
			items.append(item);
		}
		group.append(items);
		list.append(group);
	}
}

// The box key doubles as the home of column notes.
function renderBoxKey(columns) {
	const list = document.querySelector("#box-key ul");
	list.replaceChildren();
	for (const group of BOX_GROUPS) {
		for (const column of columns.filter((candidate) => candidate.tier === group.tier)) {
			const item = element("li", "box-key-item");
			item.dataset.noteTarget = `column--${column.id}`;
			item.dataset.noteLabel = `${column.label} (every character)`;
			const needed = group.tier === "extra" ? "extra" : `for ${group.tier}`;
			const text = element("span", "key-text");
			text.append(element("strong", "", column.label), element("span", "key-how", boxHint(column, null)),
				element("span", "key-fallback", `Missing: the game shows ${column.fallback}.`));
			item.append(element("span", `key-tier tier-text-${group.tier}`, needed), text);
			list.append(item);
		}
	}
}

function renderGrid(characters, evaluations, columns, ranking) {
	const grid = document.getElementById("grid");
	grid.replaceChildren();
	const nameCounts = new Map();
	for (const character of characters) nameCounts.set(character.name, (nameCounts.get(character.name) || 0) + 1);
	for (const character of characters) {
		const evaluation = evaluations.get(character.id);
		const section = element("details", `character tier-${evaluation.tier}`);
		section.dataset.character = character.id;
		section.open = isOpen(character.id);
		section.append(renderCharacterSummary(character, evaluation, columns, ranking, nameCounts.get(character.name) > 1));
		section.append(renderCharacterBody(character, evaluation, columns));
		grid.append(section);
	}
}

function renderCharacterSummary(character, evaluation, columns, ranking, nameClash) {
	const summary = element("summary", "character-summary");
	const rank = ranking.indexOf(character.id);
	summary.append(element("span", "chevron"), element("span", "grid-rank", rank >= 0 ? String(rank + 1) : "–"));

	const still = element("span", "summary-thumbnail");
	const idle = evaluation.shown.idle;
	if (idle) {
		const probeResult = probes[idle.path];
		const timing = character.clips[idle.path];
		const geometry = spriteGeometry(probeResult, 0, timing ? timing.art_bounds : null,
			global.devicePixelRatio || 1, SUMMARY_THUMBNAIL_SIZE);
		still.append(thumbnailElement(probeResult, geometry));
	}
	summary.append(still);

	const name = element("span", "grid-name");
	const label = element("span", "grid-name-text", character.name);
	if (nameClash) label.append(element("span", "grid-name-id", character.id));
	name.append(element("span", `tier-dot tier-${evaluation.tier}`), label);
	name.title = `${character.id}: ${TIER_LABELS[evaluation.tier]}`;
	name.dataset.noteTarget = `character--${character.id}`;
	name.dataset.noteLabel = character.name;
	summary.append(name, renderPips(character, evaluation, columns));

	const needs = evaluation.missingForNext.map((requirement) => columnLabel(requirement.id, columns));
	const nextTier = NEXT_TIER[evaluation.tier];
	summary.append(element("span", `summary-needs tier-text-${nextTier || "green"}`,
		nextTier ? `${TIER_LABELS[nextTier]}: ${needs.join(" · ")}` : "Done"));
	return summary;
}

// One pip per box, in box order, so collapsed rows line up like a grid.
function renderPips(character, evaluation, columns) {
	const pips = element("span", "pips");
	for (const group of BOX_GROUPS) {
		const cluster = element("span", "pip-group");
		for (const column of columns.filter((candidate) => candidate.tier === group.tier)) {
			const requirement = character.requirements.find((candidate) => candidate.id === column.id);
			const state = boxState(requirement, evaluation.shown[column.id], evaluation.placeholders[column.id]);
			const pip = element("span", `pip pip-${state} pip-tier-${group.tier}`);
			pip.title = `${column.label}: ${STATE_WORDS[state]}`;
			cluster.append(pip);
		}
		pips.append(cluster);
	}
	return pips;
}

function renderCharacterBody(character, evaluation, columns) {
	const body = element("div", "character-body");
	for (const group of BOX_GROUPS) {
		const groupColumns = columns.filter((column) => column.tier === group.tier);
		if (groupColumns.length === 0) continue;
		const section = element("section", "box-group");
		section.append(element("h3", `box-group-title tier-line-${group.tier}`, group.label));
		const boxes = element("div", "boxes");
		for (const column of groupColumns) {
			const box = element("div", "box");
			box.append(renderCell(character, evaluation, column, columns), element("span", "box-label", column.label));
			boxes.append(box);
		}
		section.append(boxes);
		body.append(section);
	}
	// Placeholder reasons in plain view, not just in tooltips.
	for (const column of columns) {
		const placeholder = evaluation.placeholders[column.id];
		if (!placeholder) continue;
		const note = element("p", "placeholder-note");
		note.append(element("strong", "", `${column.label} is a placeholder. `),
			element("span", "", placeholderReasons[placeholder.path]));
		body.append(note);
	}
	return body;
}

function thumbnailElement(probeResult, geometry) {
	const thumbnail = element("div", "thumbnail");
	thumbnail.style.backgroundImage = `url("${probeResult.url}")`;
	Object.assign(thumbnail.style, {
		width: `${geometry.width}px`,
		height: `${geometry.height}px`,
		backgroundSize: `${geometry.size[0]}px ${geometry.size[1]}px`,
		backgroundPosition: `${geometry.position[0]}px ${geometry.position[1]}px`,
	});
	thumbnail.dataset.baseX = geometry.position[0];
	return thumbnail;
}

function renderCell(character, evaluation, column, columns) {
	const cell = element("div", "cell");
	cell.dataset.noteTarget = `cell--${character.id}--${column.id}`;
	cell.dataset.noteLabel = `${character.name} · ${column.label}`;
	const requirement = character.requirements.find((candidate) => candidate.id === column.id);
	const placeholder = evaluation.placeholders[column.id];
	const state = boxState(requirement, evaluation.shown[column.id], placeholder);
	const shown = evaluation.shown[column.id] || placeholder;
	const how = boxHint(column, character.id);
	if (state === "not-needed") {
		cell.classList.add("cell-not-needed");
		cell.append(element("span", "cell-dash", "—"));
		cell.title = "Its moves never play this.";
		return cell;
	}
	if (state === "missing" || state === "optional") {
		cell.classList.add(`cell-${state}`);
		cell.append(element("div", "cell-empty"));
		cell.title = (state === "optional"
			? `Optional: no color needs it yet. Without it the game shows ${column.fallback}.`
			: `Missing. Until it's drawn the game shows ${column.fallback}.`) + `\nTo add it: ${how}.`;
		return cell;
	}
	const probeResult = probes[shown.path];
	let geometry;
	let playback = null;
	if (column.id === "line_art") {
		geometry = lineArtGeometry(probeResult, character.crop, shown.path);
	} else {
		const timing = character.clips[shown.path];
		const frames = frameCount(probeResult);
		const bounds = column.id === "idle" && timing ? timing.art_bounds : null;
		const keyframe = keyframeIndex(column.id, timing, frames);
		geometry = spriteGeometry(probeResult, keyframe, bounds, global.devicePixelRatio || 1);
		if (frames > 1 && column.id !== "idle") playback = { frames, keyframe, durations: frameDurations(timing, frames) };
	}
	const thumbnail = thumbnailElement(probeResult, geometry);
	if (column.id === "line_art") thumbnail.classList.add("thumbnail-smooth");
	if (playback) {
		thumbnail.dataset.frames = playback.frames;
		thumbnail.dataset.keyframe = playback.keyframe;
		thumbnail.dataset.frameStep = geometry.frameStep;
		thumbnail.dataset.durations = JSON.stringify(playback.durations);
	}
	cell.append(thumbnail);

	const notes = [];
	if (state === "placeholder") {
		cell.classList.add("cell-placeholder");
		cell.append(element("span", "badge badge-placeholder", "placeholder"));
		notes.push(`Placeholder: ${placeholderReasons[shown.path]}`,
			"It's in the game for now, but doesn't count toward a color.", `To replace it: ${how}.`);
	} else if (state === "stand-in") {
		const owner = columnLabel(shown.clip, columns);
		cell.classList.add("cell-stand-in");
		cell.append(element("span", "badge badge-uses", `= ${owner}`));
		notes.push(`Covered by the ${owner} clip, so it counts. Draw its own only if it should look different:`, `${how}.`);
	} else if (!shown.declared) {
		cell.append(element("span", "badge badge-new", "new"));
		notes.push("Drawn, not in the game yet: Claude wires it in.");
	}
	cell.title = [shown.path, ...notes].join("\n");
	return cell;
}


// -------------------------------------------------------------- hover play ----

let playing = null;
function startPlayback(thumbnail) {
	stopPlayback();
	const durations = JSON.parse(thumbnail.dataset.durations);
	const frameStep = Number(thumbnail.dataset.frameStep);
	const baseX = Number(thumbnail.dataset.baseX);
	const keyframe = Number(thumbnail.dataset.keyframe);
	const originX = baseX + keyframe * frameStep;  // position of frame 0
	let frame = 0;
	const state = { thumbnail, timer: 0 };
	const step = () => {
		thumbnail.style.backgroundPositionX = `${originX - frame * frameStep}px`;
		const wait = durations[frame];
		frame = (frame + 1) % durations.length;
		state.timer = global.setTimeout(step, wait);
	};
	playing = state;
	step();
}

function stopPlayback() {
	if (!playing) return;
	global.clearTimeout(playing.timer);
	playing.thumbnail.style.backgroundPositionX = `${playing.thumbnail.dataset.baseX}px`;
	playing = null;
}


// ----------------------------------------------------------------- notes ----
// File names and shape: notes/README.md. Never required.

const Notes = {
	supported: typeof global.showDirectoryPicker === "function",
	folder: null,
	notes: new Map(),  // file name → note
	editing: null,

	async restore() {
		if (!this.supported) return this.setStatus("unsupported");
		const handle = await storedHandle();
		if (!handle) return this.setStatus("off");
		this.folder = handle;
		if ((await handle.queryPermission({ mode: "readwrite" })) === "granted") return this.open();
		this.setStatus("allow");
	},

	async connect() {
		try {
			if (this.folder && (await this.folder.requestPermission({ mode: "readwrite" })) === "granted") {
				return this.open();
			}
			const handle = await global.showDirectoryPicker({ id: "tbt-art-notes", mode: "readwrite" });
			if (handle.name !== "notes" || !(await hasFile(handle, "README.md"))) {
				global.alert("Pick the folder tools/art_dashboard/notes inside the game's repo.");
				return;
			}
			this.folder = handle;
			await storeHandle(handle);
			await this.open();
		} catch (error) {
			if (error.name !== "AbortError") global.alert(`Notes couldn't connect: ${error.message}`);
		}
	},

	async open() {
		this.notes.clear();
		for await (const [name, entry] of this.folder.entries()) {
			if (entry.kind !== "file" || !name.endsWith(".json")) continue;
			try {
				this.notes.set(name, JSON.parse(await (await entry.getFile()).text()));
			} catch (error) {
				console.warn(`Skipping unreadable note ${name}`, error);
			}
		}
		this.setStatus("on");
		this.decorate();
	},

	setStatus(status) {
		this.status = status;
		const button = document.getElementById("notes-button");
		const labels = {
			unsupported: "Notes: off in this browser",
			off: "Turn on notes",
			allow: "Allow notes",
			on: `Notes (${this.notes.size})`,
		};
		button.textContent = labels[status];
		button.title = status === "unsupported"
			? "Notes need the File System Access API. In Brave: brave://flags/#file-system-access-api → Enabled → Relaunch."
			: status === "on" ? "Click a character, column or box's ✎ to write a note." : "Pick tools/art_dashboard/notes once.";
		document.body.classList.toggle("notes-on", status === "on");
	},

	decorate() {
		if (this.status !== "on") return;
		for (const target of document.querySelectorAll("[data-note-target]")) {
			let button = target.querySelector(":scope > .note-button");
			if (!button) {
				button = element("button", "note-button", "✎");
				button.type = "button";
				target.append(button);
			}
			const note = this.notes.get(target.dataset.noteTarget + ".json");
			button.classList.toggle("has-note", Boolean(note));
			button.title = note ? note.text || "Reply waiting" : "Write a note";
		}
	},

	edit(target) {
		const fileName = target.dataset.noteTarget + ".json";
		const note = this.notes.get(fileName) || { replies: [] };
		this.editing = { fileName, target: parseTarget(target.dataset.noteTarget), note };
		document.getElementById("note-title").textContent = `Note: ${target.dataset.noteLabel}`;
		document.getElementById("note-text").value = note.text || "";
		const replies = document.getElementById("note-replies");
		replies.replaceChildren();
		for (const reply of note.replies || []) {
			const item = element("div", "note-reply");
			item.append(element("strong", "", `${reply.author}: `), element("span", "", reply.text));
			replies.append(item);
		}
		const dialog = document.getElementById("note-dialog");
		dialog.returnValue = "";  // Esc keeps the old value, which would re-save
		dialog.showModal();
	},

	async save(text) {
		const { fileName, target, note } = this.editing;
		const trimmed = text.trim();
		if (!trimmed && !(note.replies || []).length) {
			await this.folder.removeEntry(fileName).catch(() => {});
			this.notes.delete(fileName);
		} else {
			const updated = { target, text: trimmed, updated: new Date().toISOString(), replies: note.replies || [] };
			const file = await (await this.folder.getFileHandle(fileName, { create: true })).createWritable();
			await file.write(JSON.stringify(updated, null, "\t") + "\n");
			await file.close();
			this.notes.set(fileName, updated);
		}
		this.setStatus("on");
		this.decorate();
	},
};

function parseTarget(key) {
	const [kind, first, second] = key.split("--");
	if (kind === "cell") return { kind, character: first, column: second };
	if (kind === "character") return { kind, character: first };
	if (kind === "column") return { kind, column: first };
	return { kind: "board" };
}

async function hasFile(folder, name) {
	try {
		await folder.getFileHandle(name);
		return true;
	} catch (error) {
		return false;
	}
}

// The notes folder handle survives reloads in IndexedDB; the browser still
// asks once per session before the page may write again.
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
			const request = store.get("notes");
			request.onsuccess = () => resolve(request.result || null);
			request.onerror = () => resolve(null);
		});
	} catch (error) {
		return null;
	}
}

async function storeHandle(handle) {
	const transaction = (await database()).transaction("handles", "readwrite");
	transaction.objectStore("handles").put(handle, "notes");
}


// ------------------------------------------------------------------ start ----

function formatTime(timestamp) {
	return new Date(timestamp).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

async function start() {
	const data = global.ART_DASHBOARD_DATA;
	const ranking = global.ART_DASHBOARD_RANKING || [];
	placeholderReasons = global.ART_DASHBOARD_PLACEHOLDERS || {};
	const status = document.getElementById("status");
	if (!data) {
		status.textContent = "game_data.js didn't load. Is this page inside the game's repo?";
		return;
	}
	renderBoxKey(data.columns);
	const cachedAt = loadCache();
	if (cachedAt) {
		render(data, ranking);
		status.textContent = `Last check ${formatTime(cachedAt)} · checking files…`;
	} else {
		status.textContent = "Checking files…";
	}
	document.body.classList.add("checking");

	const refresh = async (fullReload) => {
		document.body.classList.add("checking");
		const elapsed = await checkFiles(data, { fullReload });
		render(data, ranking);
		saveCache();
		document.body.classList.remove("checking");
		status.textContent = `Checked ${formatTime(Date.now())} (${Math.round(elapsed)} ms)`;
	};
	await refresh(true);
	global.addEventListener("focus", () => refresh(false));

	const grid = document.getElementById("grid");
	grid.addEventListener("mouseover", (event) => {
		const thumbnail = event.target.closest(".thumbnail[data-frames]");
		if (thumbnail && (!playing || playing.thumbnail !== thumbnail)) startPlayback(thumbnail);
	});
	grid.addEventListener("mouseout", (event) => {
		if (playing && !playing.thumbnail.contains(event.relatedTarget)) stopPlayback();
	});
	// toggle doesn't bubble. Renders set `open` too; only a change the viewer
	// made differs from isOpen, and only those are remembered.
	grid.addEventListener("toggle", (event) => {
		const section = event.target;
		if (!section.matches || !section.matches("details.character")) return;
		const id = section.dataset.character;
		if (section.open === isOpen(id)) return;
		if (!openCharacters) openCharacters = new Set(nextUpId ? [nextUpId] : []);
		if (section.open) openCharacters.add(id);
		else openCharacters.delete(id);
		saveOpen();
	}, true);
	const setAllOpen = (open) => {
		openCharacters = new Set(open ? data.characters.map((character) => character.id) : []);
		saveOpen();
		for (const section of grid.querySelectorAll("details.character")) section.open = open;
	};
	document.getElementById("open-all").addEventListener("click", () => setAllOpen(true));
	document.getElementById("close-all").addEventListener("click", () => setAllOpen(false));
	document.addEventListener("click", (event) => {
		const noteButton = event.target.closest(".note-button");
		if (!noteButton) return;
		event.preventDefault();  // inside a <summary> the click would also open/close the row
		Notes.edit(noteButton.closest("[data-note-target]"));
	});
	document.getElementById("notes-button").addEventListener("click", () => {
		if (Notes.status === "unsupported") global.alert(document.getElementById("notes-button").title);
		else if (Notes.status === "on") Notes.edit(document.getElementById("board-title"));
		else Notes.connect();
	});
	document.getElementById("note-dialog").addEventListener("close", (event) => {
		if (event.target.returnValue === "save") Notes.save(document.getElementById("note-text").value);
		if (event.target.returnValue === "delete") Notes.save("");
	});
	await Notes.restore();
}

start();

})(typeof window !== "undefined" ? window : globalThis);
