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
const TOP_TIER = 3;  // class tier; tier 3 promotes into nothing (data/classes/README.md)
const CHOICES = 2;  // each class below the top tier promotes into two

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
// "unexported": its tag is drawn in the .aseprite but no PNG exists yet, so
// it doesn't count either: the game only reads PNGs.
function boxState(requirement, shown, inherited, placeholder, unexported) {
	if (shown) return isStandIn(requirement, shown) ? "stand-in" : "shown";
	if (placeholder) return "placeholder";
	if (unexported) return "unexported";
	if (!requirement.needed) return "not-needed";
	if (inherited) return "inherited";
	return requirement.tier === "extra" ? "optional" : "missing";
}

// Tier = one below the lowest tier with an unmet, needed requirement.
// "extra" requirements sit outside the ladder, so they never lower it.
// `placeholders` (path → why) and `sources` (unexported tags) never count;
// they're kept to show on the box.
function evaluateCharacter(character, probes, placeholders = {}, sources = {}) {
	const shown = {};
	const placeholderShown = {};
	const unexported = {};
	for (const requirement of character.requirements) {
		const counted = requirement.candidates.filter((candidate) => !(candidate.path in placeholders));
		shown[requirement.id] = shownCandidate({ ...requirement, candidates: counted }, probes);
		if (shown[requirement.id]) continue;
		placeholderShown[requirement.id] = shownCandidate(requirement, probes);
		unexported[requirement.id] = unexportedCandidate(requirement, sources);
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
		unexported,
		unmet,
		tier,
		missingForNext: nextTier ? unmet.filter((requirement) => requirement.tier === nextTier) : [],
	};
}

// A character's promotion tree, from its `tree` in game_data.js:
// {id, name, tier, art, children, gap}, or null when its base isn't a pool
// class. `gap`: a class below the top tier with a slot not designed yet.
// Nothing under an empty slot is drawn: no unit can promote through it. A
// tier-3 class under both branches shows under each, but it's one variant.
function unitTree(classes, character) {
	const byId = new Map(classes.map((entry) => [entry.id, entry]));
	const grow = (slot, tier) => {
		const designed = (slot.promotions || []).filter((child) => byId.has(child.class));
		return {
			id: slot.class, name: byId.get(slot.class).name, tier, art: slot.art || null,
			children: designed.map((child) => grow(child, tier + 1)),
			gap: tier < TOP_TIER && designed.length < CHOICES,
		};
	};
	return byId.has(character.tree.class) ? grow(character.tree, 1) : null;
}

// "designed": every branch reaches the top tier. "not-designed": no promotions.
function treeStatus(tree) {
	const hasGap = (node) => node.gap || node.children.some(hasGap);
	if (!hasGap(tree)) return "designed";
	return tree.children.length === 0 ? "not-designed" : "partial";
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

// Where the exporter gets a sprite PNG: <folder>.aseprite beside the folder,
// the tag named after the file. null for files that aren't exported sprites.
function asepriteSource(path) {
	if (!path.startsWith("art/sprites/")) return null;
	const parts = path.split("/");
	const file = [...parts.slice(0, -2), `${folderName(path)}.aseprite`].join("/");
	return { file, clip: fileStem(path) };
}

// A box with no PNG whose tag is drawn: {candidate, file, clip, frames}, or
// null. `sources`: .aseprite path → its exportedClips (aseprite_tags.js).
function unexportedCandidate(requirement, sources) {
	const minimumFrames = requirement.min_frames || 1;
	const drawn = [];
	for (const candidate of requirement.candidates) {
		const source = asepriteSource(candidate.path);
		const frames = source && sources[source.file] ? sources[source.file][source.clip] : 0;
		if (frames >= minimumFrames) drawn.push({ candidate, ...source, frames });
	}
	return drawn.find((entry) => entry.candidate.convention) || drawn[0] || null;
}

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
// `bounds` (the idle's art_bounds) crops to the figure so it reads bigger. A
// crop too big for the box even at one device pixel per pixel keeps its
// middle: a big canvas shows the figure at its centre, never a corner.
function spriteGeometry(probe, frameIndex, bounds, deviceRatio, size = THUMBNAIL_SIZE) {
	const frameSize = probe.height;
	const padding = 2;
	const crop = bounds
		? {
			left: Math.max(0, bounds.left - padding), top: Math.max(0, bounds.top - padding),
			right: Math.min(frameSize, bounds.right + padding), bottom: Math.min(frameSize, bounds.bottom + padding),
		}
		: { left: 0, top: 0, right: frameSize, bottom: frameSize };
	const deviceScale = Math.max(1, Math.floor((size * deviceRatio) / Math.max(crop.right - crop.left, crop.bottom - crop.top)));
	const scale = deviceScale / deviceRatio;
	const fits = Math.floor((size * deviceRatio) / deviceScale);
	[crop.left, crop.right] = keepMiddle(crop.left, crop.right, fits);
	[crop.top, crop.bottom] = keepMiddle(crop.top, crop.bottom, fits);
	const cropWidth = crop.right - crop.left;
	const cropHeight = crop.bottom - crop.top;
	return {
		width: cropWidth * scale,
		height: cropHeight * scale,
		size: [probe.width * scale, probe.height * scale],
		position: [-(frameIndex * frameSize + crop.left) * scale, -crop.top * scale],
		frameStep: frameSize * scale,
	};
}

// The middle `length` of [start, end), or the span itself when it's no longer.
function keepMiddle(start, end, length) {
	if (end - start <= length) return [start, end];
	const from = Math.floor((start + end - length) / 2);
	return [from, from + length];
}

// A clip in its own contact box (column.contact: melee, ranged, cast...)
// with no `hit` tag from Lawrence: the game strikes on its middle frame
// until he marks the contact. A stand-in is flagged in its own box only.
function needsHitMarker(column, shown, timing) {
	return Boolean(column.contact && shown && shown.clip === column.id && !(timing && timing.hit_marker));
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
	NEXT_TIER, TOP_TIER, frameCount, shownCandidate, isStandIn, boxState, evaluateCharacter, unitTree,
	treeStatus, resolveBoxes, variantProgress, sortCharacters, pendingRenames, folderName, asepriteSource,
	renameInstruction, deliveryHint, boxHint, keyframeIndex, frameDurations, spriteGeometry, lineArtGeometry,
	needsHitMarker,
};
if (typeof module !== "undefined") module.exports = logic;
else global.ArtBoardLogic = logic;

})(typeof window !== "undefined" ? window : globalThis);
