// The clips an .aseprite file would export, read from its bytes, so the art
// board can show a tag Lawrence drew before anyone exports it. Mirrors the
// tag exporter (addons/aseprite_tag_exporter/context_menu.gd): same tags
// chunk, same marker tags skipped, same file names. Format: Aseprite's
// docs/ase-file-specs.md. Runs in the page and in node.
"use strict";

(function (global) {

const FILE_MAGIC = 0xA5E0;
const FRAME_MAGIC = 0xF1FA;
const HEADER_SIZE = 128;
const FRAME_HEADER_SIZE = 16;
const TAGS_CHUNK = 0x2018;
const TAG_FIXED_SIZE = 17;  // from, to, direction, repeat, reserved, color, extra

// [{name, from, to}] from the first tags chunk, or null when the bytes
// aren't an .aseprite file. Aseprite writes the chunk in frame 0, but the
// exporter walks every frame for it, so this does too.
function asepriteTags(bytes) {
	const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
	if (bytes.byteLength < HEADER_SIZE || view.getUint16(4, true) !== FILE_MAGIC) return null;
	const frameCount = view.getUint16(6, true);
	const decoder = new TextDecoder();
	let frameStart = HEADER_SIZE;
	for (let frame = 0; frame < frameCount && frameStart + FRAME_HEADER_SIZE <= bytes.byteLength; frame++) {
		if (view.getUint16(frameStart + 4, true) !== FRAME_MAGIC) return null;
		const frameEnd = Math.min(bytes.byteLength, frameStart + view.getUint32(frameStart, true));
		// The old 16-bit count is 0xFFFF past its range; the new one is 0 in old files.
		const chunkCount = view.getUint32(frameStart + 12, true) || view.getUint16(frameStart + 6, true);
		let chunkStart = frameStart + FRAME_HEADER_SIZE;
		for (let chunk = 0; chunk < chunkCount && chunkStart + 6 <= frameEnd; chunk++) {
			const chunkSize = view.getUint32(chunkStart, true);
			if (view.getUint16(chunkStart + 4, true) === TAGS_CHUNK) {
				const tags = [];
				let tagStart = chunkStart + 16;  // chunk header, count, 8 reserved
				for (let index = view.getUint16(chunkStart + 6, true); index > 0; index--) {
					const nameLength = view.getUint16(tagStart + TAG_FIXED_SIZE, true);
					const nameStart = tagStart + TAG_FIXED_SIZE + 2;
					tags.push({
						name: decoder.decode(bytes.subarray(nameStart, nameStart + nameLength)),
						from: view.getUint16(tagStart, true),
						to: view.getUint16(tagStart + 2, true),
					});
					tagStart = nameStart + nameLength;
				}
				return tags;
			}
			if (chunkSize < 6) break;
			chunkStart += chunkSize;
		}
		frameStart = frameEnd;
	}
	return [];
}

// `hit`, `hit_<clip>`, `<clip>_hit` pin a clip's impact frame; never exported.
function isMarkerTag(name) {
	const lower = name.trim().toLowerCase();
	return lower === "hit" || lower.startsWith("hit_") || lower.endsWith("_hit");
}

// The PNG name a tag exports as: a `_WxH` footprint suffix dropped,
// lowercased, anything but letters, digits, _ and - made _.
function exportedName(tagName) {
	const footprint = tagName.match(/^(.+)_\d+x\d+$/);
	return (footprint ? footprint[1] : tagName).trim().toLowerCase().replace(/[^a-z0-9_-]/g, "_");
}

// {exported file stem → frames} for the clips a file would export, or null
// when it isn't an .aseprite file. Two tags with one name: the later one
// wins, as its export overwrites the earlier one's.
function exportedClips(bytes) {
	const tags = asepriteTags(bytes);
	if (!tags) return null;
	const clips = {};
	for (const tag of tags) {
		if (!isMarkerTag(tag.name)) clips[exportedName(tag.name)] = tag.to - tag.from + 1;
	}
	return clips;
}

const tags = { asepriteTags, isMarkerTag, exportedName, exportedClips };
if (typeof module !== "undefined") module.exports = tags;
else global.AsepriteTags = tags;

})(typeof window !== "undefined" ? window : globalThis);
