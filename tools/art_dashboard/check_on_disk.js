// What the art board shows, from the terminal: node tools/art_dashboard/check_on_disk.js
// Same logic as the page (dashboard.js), with fs standing in for image loads.
// Prints each character's tier, art that's drawn but not wired in, renames,
// and whether each placeholder (placeholders.js) is still what it was marked for.
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const zlib = require("node:zlib");
const board = require("./dashboard.js");

const repositoryRoot = path.join(__dirname, "..", "..");
// Enough compressed data for a first scanline many times over, so a line-art
// sheet (~48 MB decoded) is never inflated whole.
const FIRST_ROW_READ_LIMIT = 256 * 1024;

// Width and height from the PNG header, like an <img> load reports them.
function probe(relativePath) {
	const full = path.join(repositoryRoot, relativePath);
	if (!fs.existsSync(full)) return { exists: false, width: 0, height: 0 };
	const header = Buffer.alloc(24);
	const descriptor = fs.openSync(full, "r");
	fs.readSync(descriptor, header, 0, 24, 0);
	fs.closeSync(descriptor);
	return { exists: true, width: header.readUInt32BE(16), height: header.readUInt32BE(20) };
}

// Alpha of the two top corners, from the first scanline only. null when the
// PNG isn't 8-bit RGBA or gray+alpha: nothing here reads other layouts.
function topCornerAlphas(fullPath) {
	const descriptor = fs.openSync(fullPath, "r");
	const read = (length, position) => {
		const buffer = Buffer.alloc(length);
		fs.readSync(descriptor, buffer, 0, length, position);
		return buffer;
	};
	try {
		const header = read(26, 0);
		const width = header.readUInt32BE(16);
		const channels = { 4: 2, 6: 4 }[header[25]];
		if (!channels || header[24] !== 8) return null;
		const fileSize = fs.fstatSync(descriptor).size;
		const compressed = [];
		let collected = 0;
		for (let position = 8; position + 8 <= fileSize && collected < FIRST_ROW_READ_LIMIT;) {
			const chunk = read(8, position);
			const length = chunk.readUInt32BE(0);
			const type = chunk.toString("latin1", 4, 8);
			if (type === "IDAT") {
				const take = Math.min(length, FIRST_ROW_READ_LIMIT - collected);
				compressed.push(read(take, position + 8));
				collected += take;
				const rows = zlib.inflateSync(Buffer.concat(compressed), { finishFlush: zlib.constants.Z_SYNC_FLUSH });
				if (rows.length > width * channels) return firstRowCornerAlphas(rows, width, channels);
			}
			position += 12 + length;
		}
		return null;
	} finally {
		fs.closeSync(descriptor);
	}
}

// Undo the scanline filter for row 0, where the row above counts as zeros:
// Up is then a no-op, and Paeth always picks the left byte, like Sub.
function firstRowCornerAlphas(rows, width, channels) {
	const filter = rows[0];
	const row = new Uint8Array(width * channels);
	for (let index = 0; index < row.length; index++) {
		const left = index >= channels ? row[index - channels] : 0;
		const value = rows[1 + index];
		if (filter === 1 || filter === 4) row[index] = value + left;
		else if (filter === 3) row[index] = value + (left >> 1);
		else row[index] = value;
	}
	return { left: row[channels - 1], right: row[row.length - 1] };
}

const isOpaque = (alphas) => alphas !== null && alphas.left === 255 && alphas.right === 255;

function main() {
	const sandbox = { window: {} };
	for (const file of ["game_data.js", "ranking.js", "placeholders.js"]) {
		vm.runInNewContext(fs.readFileSync(path.join(__dirname, file), "utf8"), sandbox);
	}
	const data = sandbox.window.ART_DASHBOARD_DATA;
	const ranking = sandbox.window.ART_DASHBOARD_RANKING || [];
	const placeholders = sandbox.window.ART_DASHBOARD_PLACEHOLDERS || {};

	const probes = {};
	for (const character of data.characters) {
		for (const requirement of character.requirements) {
			for (const candidate of requirement.candidates) {
				probes[candidate.path] = probe(candidate.path);
				if (candidate.rename_to) probes[candidate.rename_to] = probe(candidate.rename_to);
			}
		}
	}

	for (const character of board.sortCharacters(data.characters, ranking)) {
		const evaluation = board.evaluateCharacter(character, probes, placeholders);
		const missing = evaluation.missingForNext.map((requirement) => requirement.id).join(", ");
		console.log(`${evaluation.tier.padEnd(7)}${character.id}${missing ? `  (next needs: ${missing})` : ""}`);
		// A plain clip standing in for its kind boxes would print once per box.
		const unwired = new Set(Object.values(evaluation.shown).filter((shown) => shown && !shown.declared).map((shown) => shown.path));
		for (const unwiredPath of unwired) console.log(`       new, not wired: ${unwiredPath}`);
	}
	const renames = board.pendingRenames(data.characters, probes);
	if (renames.length > 0) console.log(`\nRenames to do (${renames.length}):`);
	for (const rename of renames) console.log(`  ${rename.from} → ${rename.to}\n    ${rename.how}`);

	// Paper photos are the placeholders so far; opaque corners mean one still is.
	console.log("\nPlaceholders:");
	for (const placeholderPath of Object.keys(placeholders)) {
		const full = path.join(repositoryRoot, placeholderPath);
		if (!fs.existsSync(full)) console.log(`  ${placeholderPath}: gone, remove its line`);
		else if (isOpaque(topCornerAlphas(full))) console.log(`  ${placeholderPath}: corners still opaque, keep it`);
		else console.log(`  ${placeholderPath}: corners transparent now: if that was the problem, remove its line`);
	}
	const lineArt = new Set();
	for (const character of data.characters) {
		const requirement = character.requirements.find((candidate) => candidate.id === "line_art");
		for (const candidate of requirement.candidates) {
			if (probes[candidate.path].exists && !(candidate.path in placeholders)) lineArt.add(candidate.path);
		}
	}
	for (const lineArtPath of lineArt) {
		if (isOpaque(topCornerAlphas(path.join(repositoryRoot, lineArtPath)))) {
			console.log(`  ${lineArtPath}: opaque corners but not marked: a paper photo? Mark it in placeholders.js`);
		}
	}
}

module.exports = { topCornerAlphas };
if (require.main === module) main();
