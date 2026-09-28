// What the art board shows, from the terminal: node tools/art_dashboard/check_on_disk.js
// Same logic as the page (dashboard.js), with fs standing in for image loads.
// Prints each character's tier, art that's drawn but not wired in, and renames.
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const board = require("./dashboard.js");

const repositoryRoot = path.join(__dirname, "..", "..");
const sandbox = { window: {} };
for (const file of ["game_data.js", "ranking.js"]) {
	vm.runInNewContext(fs.readFileSync(path.join(__dirname, file), "utf8"), sandbox);
}
const data = sandbox.window.ART_DASHBOARD_DATA;
const ranking = sandbox.window.ART_DASHBOARD_RANKING || [];

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
	const evaluation = board.evaluateCharacter(character, probes);
	const missing = evaluation.missingForNext.map((requirement) => requirement.id).join(", ");
	console.log(`${evaluation.tier.padEnd(7)}${character.id}${missing ? `  (next needs: ${missing})` : ""}`);
	// A plain clip standing in for its kind boxes would print once per box.
	const unwired = new Set(Object.values(evaluation.shown).filter((shown) => shown && !shown.declared).map((shown) => shown.path));
	for (const unwiredPath of unwired) console.log(`       new, not wired: ${unwiredPath}`);
}
const renames = board.pendingRenames(data.characters, probes);
if (renames.length > 0) console.log(`\nRenames to do (${renames.length}):`);
for (const rename of renames) console.log(`  ${rename.from} → ${rename.to}\n    ${rename.how}`);
