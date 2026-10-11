// The art board's rules, with no DOM: which file a box shows, a character's
// tier, the promotion trees, where a box's file goes, sprite geometry.
// dashboard.js draws the page from these; dashboard_test.js and
// check_on_disk.js run them in node.
"use strict";

(function (global) {

const DEFAULT_FPS = 12;  // ClipPlayer.DEFAULT_FPS
const THUMBNAIL_SIZE = 64;  // CSS px; sprites scale by whole device pixels inside it
const IDLE_COLUMNS = ["idle", "idle_animation"];
const NEXT_TIER = { red: "orange", orange: "yellow", yellow: "green" };
const TOP_TIER = 3;  // class tier; Enums.CLASS_INFO: tier 3 promotes into nothing

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
// "inherited": a variant's box showing the art of the class it promotes from.
// "placeholder": in the game for now, but it doesn't count (placeholders.js).
function boxState(requirement, shown, inherited, placeholder) {
	if (shown) return isStandIn(requirement, shown) ? "stand-in" : "shown";
	if (placeholder) return "placeholder";
	if (!requirement.needed) return "not-needed";
	if (inherited) return "inherited";
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

// The promotion tree under a class: {id, name, tier, children, gap}. `gap`: a
// class below the top tier that promotes into nothing yet (not designed).
function promotionTree(classes, classId) {
	const byId = new Map(classes.map((entry) => [entry.id, entry]));
	const grow = (id, path) => {
		const entry = byId.get(id);
		const children = entry.promotes_to.filter((child) => byId.has(child) && !path.includes(child))
			.map((child) => grow(child, [...path, child]));
		return { id, name: entry.name, tier: entry.tier, children, gap: entry.tier < TOP_TIER && children.length === 0 };
	};
	return byId.has(classId) ? grow(classId, [classId]) : null;
}

// "designed": every branch reaches the top tier. "not-designed": no promotions.
function treeStatus(tree) {
	const hasGap = (node) => node.gap || node.children.some(hasGap);
	if (!hasGap(tree)) return "designed";
	return tree.children.length === 0 ? "not-designed" : "partial";
}

// Every tier-1 class's tree, and the classes none of them reach yet.
function classForest(classes) {
	const roots = classes.filter((entry) => entry.tier === 1).map((entry) => promotionTree(classes, entry.id));
	const reached = new Set();
	const walk = (node) => {
		reached.add(node.id);
		node.children.forEach(walk);
	};
	roots.forEach(walk);
	return { roots, orphans: classes.filter((entry) => !reached.has(entry.id)) };
}

// Per box, {candidate, owner}: the art's own file, else whatever the class it
// promotes from shows. `owner` is whose art it is, for the "= Squire" badge.
function resolveBoxes(owner, shown, parentResolved = {}) {
	const resolved = {};
	for (const requirement of owner.requirements) {
		const own = shown[requirement.id];
		resolved[requirement.id] = own ? { candidate: own, owner } : parentResolved[requirement.id] || null;
	}
	return resolved;
}

// Needed boxes (extras aside) that have the variant's own art.
function variantProgress(variant, evaluation) {
	const needed = variant.requirements.filter((requirement) => requirement.needed && requirement.tier !== "extra");
	return { drawn: needed.filter((requirement) => evaluation.shown[requirement.id]).length, total: needed.length };
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
	NEXT_TIER, TOP_TIER, frameCount, shownCandidate, isStandIn, boxState, evaluateCharacter, promotionTree,
	treeStatus, classForest, resolveBoxes, variantProgress, sortCharacters, pendingRenames, folderName,
	renameInstruction, deliveryHint, boxHint, keyframeIndex, frameDurations, spriteGeometry, lineArtGeometry,
};
if (typeof module !== "undefined") module.exports = logic;
else global.ArtBoardLogic = logic;

})(typeof window !== "undefined" ? window : globalThis);
