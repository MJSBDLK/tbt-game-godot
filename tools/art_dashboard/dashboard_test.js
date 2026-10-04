// The art board's page logic, outside the browser: node --test tools/art_dashboard/dashboard_test.js
// (GUT can't run JavaScript; the data side is tests/unit/test_art_dashboard_data.gd.)
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const os = require("node:os");
const zlib = require("node:zlib");
const board = require("./dashboard.js");
const { topCornerAlphas } = require("./check_on_disk.js");

const exists = (width, height) => ({ exists: true, width, height });
const candidate = (filePath, declared, convention, renameTo, clip) =>
	({ path: filePath, declared, convention, ...(renameTo ? { rename_to: renameTo } : {}), ...(clip ? { clip } : {}) });

function character(requirements) {
	return { id: "hero", name: "Hero", clips: {}, requirements };
}

function requirement(id, tier, needed, candidates, extra = {}) {
	return { id, tier, needed, candidates, ...extra };
}

const IDLE = [candidate("sprites/hero/idle.png", true, true)];
const HERO = character([
	requirement("idle", "orange", true, IDLE),
	requirement("idle_animation", "orange", true, IDLE, { min_frames: 2 }),
	requirement("melee", "yellow", true, [candidate("sprites/hero/melee.png", false, true)]),
	requirement("ranged", "yellow", false, [candidate("sprites/hero/ranged.png", false, true)]),
	requirement("hurt", "green", true, [candidate("sprites/hero/hurt.png", false, true)]),
]);


test("no idle is red, and an idle still alone stays red", () => {
	assert.equal(board.evaluateCharacter(HERO, {}).tier, "red");
	const still = { "sprites/hero/idle.png": exists(64, 64) };
	assert.equal(board.evaluateCharacter(HERO, still).tier, "red", "min_frames 2 wants an animation");
});

test("tiers climb as boxes fill, skipping what the moves never play", () => {
	const probes = { "sprites/hero/idle.png": exists(256, 64) };
	assert.equal(board.evaluateCharacter(HERO, probes).tier, "orange");
	probes["sprites/hero/melee.png"] = exists(640, 64);
	const yellow = board.evaluateCharacter(HERO, probes);
	assert.equal(yellow.tier, "yellow", "ranged isn't needed");
	assert.deepEqual(yellow.missingForNext.map((entry) => entry.id), ["hurt"]);
	probes["sprites/hero/hurt.png"] = exists(192, 64);
	assert.equal(board.evaluateCharacter(HERO, probes).tier, "green");
});

test("a plain clip stands in for a kind's own box: it counts, and says so", () => {
	const kindBox = requirement("melee_physical", "green", true, [
		candidate("sprites/hero/melee_physical.png", false, true, null, "melee_physical"),
		candidate("sprites/hero/melee.png", false, true, null, "melee"),
	]);
	const hero = character([requirement("idle", "orange", true, IDLE), kindBox]);
	const probes = { "sprites/hero/idle.png": exists(64, 64), "sprites/hero/melee.png": exists(640, 64) };
	const evaluation = board.evaluateCharacter(hero, probes);
	assert.equal(evaluation.tier, "green");
	assert.equal(board.boxState(kindBox, evaluation.shown.melee_physical), "stand-in");
	probes["sprites/hero/melee_physical.png"] = exists(640, 64);
	assert.equal(board.boxState(kindBox, board.shownCandidate(kindBox, probes)), "shown", "its own clip wins");
	assert.equal(board.boxState(requirement("idle", "orange", true, IDLE), IDLE[0]), "shown", "no clip, never a stand-in");
});

test("extras show as optional and never lower the tier", () => {
	const crit = requirement("crit_melee", "extra", true, [candidate("sprites/hero/crit_melee.png", false, true, null, "crit_melee")]);
	const hero = character([requirement("idle", "orange", true, IDLE), crit]);
	const evaluation = board.evaluateCharacter(hero, { "sprites/hero/idle.png": exists(64, 64) });
	assert.equal(evaluation.tier, "green");
	assert.deepEqual(evaluation.missingForNext, []);
	assert.equal(board.boxState(crit, null), "optional");
	assert.equal(board.boxState({ ...crit, needed: false }, null), "not-needed");
	assert.equal(board.boxState({ ...crit, tier: "green" }, null), "missing");
});

test("a placeholder shows on its box but never counts", () => {
	const lineArt = requirement("line_art", "orange", true, [candidate("lineart/hero.png", true, true)]);
	const hero = character([requirement("idle", "orange", true, IDLE), lineArt]);
	const probes = { "sprites/hero/idle.png": exists(64, 64), "lineart/hero.png": exists(3024, 4032) };
	assert.equal(board.evaluateCharacter(hero, probes).tier, "green");
	const marked = board.evaluateCharacter(hero, probes, { "lineart/hero.png": "a paper photo" });
	assert.equal(marked.tier, "red");
	assert.deepEqual(marked.missingForNext.map((entry) => entry.id), ["line_art"]);
	assert.equal(marked.placeholders.line_art.path, "lineart/hero.png");
	assert.equal(board.boxState(lineArt, marked.shown.line_art, marked.placeholders.line_art), "placeholder");
});

test("every placeholder names a file some box looks for", () => {
	const sandbox = { window: {} };
	for (const file of ["game_data.js", "placeholders.js"]) {
		vm.runInNewContext(fs.readFileSync(path.join(__dirname, file), "utf8"), sandbox);
	}
	const looked = new Set(sandbox.window.ART_DASHBOARD_DATA.characters.flatMap((entry) =>
		entry.requirements.flatMap((need) => need.candidates.map((option) => option.path))));
	for (const placeholderPath of Object.keys(sandbox.window.ART_DASHBOARD_PLACEHOLDERS)) {
		assert.ok(looked.has(placeholderPath), `${placeholderPath} is a path the board checks`);
	}
});

// A minimal PNG: IHDR, one IDAT, IEND. CRCs are zero; the reader skips them.
function writePng(folder, name, width, colorType, rows) {
	const chunk = (type, body) => {
		const length = Buffer.alloc(4);
		length.writeUInt32BE(body.length);
		return Buffer.concat([length, Buffer.from(type, "latin1"), body, Buffer.alloc(4)]);
	};
	const header = Buffer.alloc(13);
	header.writeUInt32BE(width, 0);
	header.writeUInt32BE(rows.length, 4);
	header[8] = 8;
	header[9] = colorType;
	const file = path.join(folder, name);
	fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", header),
		chunk("IDAT", zlib.deflateSync(Buffer.from(rows.flat()))), chunk("IEND", Buffer.alloc(0))]));
	return file;
}

test("corner alphas come from the first scanline, whatever its filter", () => {
	const folder = fs.mkdtempSync(path.join(os.tmpdir(), "art-board-"));
	// Three RGBA pixels, alpha 0 / 255 / 128. Sub stores each byte minus the pixel to its left.
	const plain = writePng(folder, "none.png", 3, 6, [[0, 9, 9, 9, 0, 9, 9, 9, 255, 9, 9, 9, 128]]);
	assert.deepEqual(topCornerAlphas(plain), { left: 0, right: 128 });
	const sub = writePng(folder, "sub.png", 3, 6, [[1, 9, 9, 9, 0, 0, 0, 0, 255, 0, 0, 0, 129]]);
	assert.deepEqual(topCornerAlphas(sub), { left: 0, right: 128 }, "255 + 129 wraps to 128");
	const photo = writePng(folder, "photo.png", 2, 6, [[4, 200, 200, 200, 255, 0, 0, 0, 0]]);
	assert.deepEqual(topCornerAlphas(photo), { left: 255, right: 255 }, "Paeth on row 0 adds the left byte");
	assert.equal(topCornerAlphas(writePng(folder, "rgb.png", 1, 2, [[0, 1, 2, 3]])), null, "no alpha channel");
	fs.rmSync(folder, { recursive: true });
});

test("a convention file beats the declared one: it's the newer art", () => {
	const renamed = requirement("idle", "orange", true, [
		candidate("sprites/max/idle.png", true, false, "sprites/spaceman/idle.png"),
		candidate("sprites/spaceman/idle.png", false, true),
	]);
	const both = { "sprites/max/idle.png": exists(64, 64), "sprites/spaceman/idle.png": exists(64, 64) };
	assert.equal(board.shownCandidate(renamed, both).path, "sprites/spaceman/idle.png");
	assert.equal(board.shownCandidate(renamed, { "sprites/max/idle.png": exists(64, 64) }).path, "sprites/max/idle.png");
});

test("renames list declared files whose convention twin doesn't exist yet", () => {
	const hero = character([requirement("idle", "orange", true, [
		candidate("art/sprites/characters/max/meleeside.png", true, false, "art/sprites/characters/spaceman/melee.png"),
		candidate("art/sprites/characters/spaceman/melee.png", false, true),
	])]);
	const before = { "art/sprites/characters/max/meleeside.png": exists(640, 64) };
	const renames = board.pendingRenames([hero, hero], before);
	assert.equal(renames.length, 1, "listed once");
	assert.equal(renames[0].how, 'In Aseprite: max.aseprite → spaceman.aseprite, tag "meleeside" → "melee", then re-export.');
	const after = { ...before, "art/sprites/characters/spaceman/melee.png": exists(640, 64) };
	assert.equal(board.pendingRenames([hero], after).length, 0);
});

test("rename instructions: tag only, and plain files outside sprites", () => {
	assert.equal(board.renameInstruction("art/sprites/characters/keener/shootside.png", "art/sprites/characters/keener/ranged.png"),
		'In Aseprite: tag "shootside" → "ranged", then re-export.');
	assert.equal(board.renameInstruction("art/lineart_fullres/big_troll.png", "art/lineart_fullres/ogre.png"),
		"Rename big_troll.png to ogre.png.");
});

test("delivery hints: a tag in the character's .aseprite, or a file to save", () => {
	assert.equal(board.deliveryHint("art/sprites/characters/maam/melee_physical.png"),
		'Tag "melee_physical" in maam.aseprite, then Export Tags as PNGs');
	assert.equal(board.deliveryHint("art/sprites/characters/maam/idle.png", 2),
		'Tag "idle" with 2+ frames in maam.aseprite, then Export Tags as PNGs');
	assert.equal(board.deliveryHint("art/lineart_fullres/maam.png"), "Save as art/lineart_fullres/maam.png");
	const lineArt = { convention: "art/lineart_fullres/{id}.png" };
	assert.equal(board.boxHint(lineArt, "spaceman"), "Save as art/lineart_fullres/spaceman.png");
	assert.equal(board.boxHint(lineArt, null), "Save as art/lineart_fullres/<id>.png", "the box key's generic form");
});

test("keyframes: idles show frame 0, clips their hit frame, else the middle", () => {
	assert.equal(board.keyframeIndex("idle_animation", { hit_frame: 3 }, 8), 0);
	assert.equal(board.keyframeIndex("melee", { hit_frame: 5 }, 10), 5);
	assert.equal(board.keyframeIndex("melee", {}, 10), 5);
	assert.equal(board.keyframeIndex("melee", undefined, 7), 3);
	assert.equal(board.keyframeIndex("melee", { hit_frame: 40 }, 10), 9, "clamped");
});

test("frame durations: the sidecar when it matches the strip, else fps", () => {
	assert.deepEqual(board.frameDurations({ frame_durations_ms: [80, 120] }, 2), [80, 120]);
	assert.deepEqual(board.frameDurations({ frame_durations_ms: [80], fps: 10 }, 2), [100, 100]);
	assert.deepEqual(board.frameDurations(undefined, 3), [1000 / 12, 1000 / 12, 1000 / 12]);
});

test("sprites scale by whole device pixels", () => {
	const small = board.spriteGeometry(exists(640, 64), 5, null, 2);
	assert.equal(small.width, 64, "64 px frames at 2 device px each");
	assert.deepEqual(small.position, [-320, -0]);
	assert.equal(board.spriteGeometry(exists(96, 96), 0, null, 2).width, 48, "96 px frames can't double inside 64 CSS px");
	const cropped = board.spriteGeometry(exists(64, 64), 0, { left: 19, top: 8, right: 43, bottom: 42 }, 2);
	assert.deepEqual([cropped.width, cropped.height], [42, 57], "art bounds + 2 px, tripled");
});

test("line art uses the portrait crop only when it's on the same file", () => {
	const crop = { atlas: "art/lineart_fullres/ernesto.png", x: 990, y: 400, width: 1000, height: 1000 };
	const geometry = board.lineArtGeometry(exists(3024, 4032), crop, "art/lineart_fullres/ernesto.png");
	assert.equal(geometry.width, 64);
	assert.ok(Math.abs(geometry.position[0] + 63.36) < 1e-9);
	const uncropped = board.lineArtGeometry(exists(3024, 4032), crop, "art/lineart_fullres/other.png");
	assert.equal(uncropped.height, 64);
});

test("the real generated data evaluates: nothing on disk is red, everything is green", () => {
	const source = fs.readFileSync(path.join(__dirname, "game_data.js"), "utf8");
	const sandbox = { window: {} };
	vm.runInNewContext(source, sandbox);
	const data = sandbox.window.ART_DASHBOARD_DATA;
	assert.ok(data.characters.length > 0);
	for (const entry of data.characters) {
		assert.equal(board.evaluateCharacter(entry, {}).tier, "red", entry.id);
		const everything = {};
		for (const need of entry.requirements) {
			for (const option of need.candidates) everything[option.path] = exists(128, 64);
		}
		assert.equal(board.evaluateCharacter(entry, everything).tier, "green", entry.id);
	}
});
