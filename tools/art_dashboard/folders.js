// The repo folders the art board may open, through the File System Access
// API (Brave: brave://flags/#file-system-access-api). Each is picked once,
// and the board works without either:
// - tools/art_dashboard/notes, read and write: notes (dashboard.js Notes).
// - art/sprites/characters, read only: the .aseprite files, so a box can say
//   its tag is drawn but not exported (Sources, below).
// Handles survive reloads in IndexedDB; the browser still asks once per
// session, on a click, before the page may use one again.
"use strict";

(function (global) {

const supported = typeof global.showDirectoryPicker === "function";

function database() {
	return new Promise((resolve, reject) => {
		const request = global.indexedDB.open("tbt-art-board", 1);
		request.onupgradeneeded = () => request.result.createObjectStore("handles");
		request.onsuccess = () => resolve(request.result);
		request.onerror = () => reject(request.error);
	});
}

async function storedHandle(key) {
	try {
		const store = (await database()).transaction("handles").objectStore("handles");
		return await new Promise((resolve) => {
			const request = store.get(key);
			request.onsuccess = () => resolve(request.result || null);
			request.onerror = () => resolve(null);
		});
	} catch (error) {
		return null;
	}
}

// Best effort: without it (a private window) the folder works this session,
// and the board just asks again next time.
async function storeHandle(key, handle) {
	try {
		(await database()).transaction("handles", "readwrite").objectStore("handles").put(handle, key);
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

// The folder picked last time and whether the page may use it without a click.
async function rememberedFolder(key, mode) {
	const handle = await storedHandle(key);
	return { handle, granted: Boolean(handle) && (await handle.queryPermission({ mode })) === "granted" };
}

// On a click: permission for the remembered folder, else the picker.
// `isRight(handle)` false alerts `wrongFolder`. null when nothing was granted.
async function connectFolder(key, remembered, { mode, isRight, wrongFolder }) {
	if (remembered && (await remembered.requestPermission({ mode })) === "granted") return remembered;
	let handle;
	try {
		handle = await global.showDirectoryPicker({ id: `tbt-art-${key}`, mode });
	} catch (error) {
		if (error.name === "AbortError") return null;
		throw error;
	}
	if (!(await isRight(handle))) {
		global.alert(wrongFolder);
		return null;
	}
	await storeHandle(key, handle);
	return handle;
}

// ------------------------------------------------------- .aseprite files ----

const SPRITES_PATH = "art/sprites/characters/";

const Sources = {
	supported,
	folder: null,
	granted: false,
	// .aseprite path → {exported name → frames}. Kept from the last read when
	// the page can't read now; dashboard.js caches it with the probes.
	clips: {},

	async restore() {
		if (!supported) return;
		({ handle: this.folder, granted: this.granted } = await rememberedFolder("sprites", "read"));
	},

	// On a click, only when it can't read yet.
	async connect() {
		if (!supported || this.granted) return;
		try {
			const handle = await connectFolder("sprites", this.folder, {
				mode: "read",
				isRight: async (picked) => picked.name === "characters" && (await asepriteNames(picked)).length > 0,
				wrongFolder: "Pick the folder art/sprites/characters inside the game's repo.",
			});
			if (!handle) return;
			this.folder = handle;
			this.granted = true;
		} catch (error) {
			global.alert(`Couldn't open the .aseprite folder: ${error.message}`);
		}
	},

	// Re-reads every .aseprite file. False when it can't (no grant this session).
	async read() {
		if (!this.granted) return false;
		const clips = {};
		try {
			for (const name of await asepriteNames(this.folder)) {
				const file = await (await this.folder.getFileHandle(name)).getFile();
				const parsed = global.AsepriteTags.exportedClips(new Uint8Array(await file.arrayBuffer()));
				if (parsed) clips[SPRITES_PATH + name] = parsed;
			}
		} catch (error) {
			// Permission withdrawn, or the folder moved: ask again on the next click.
			this.granted = false;
			return false;
		}
		this.clips = clips;
		return true;
	},
};

async function asepriteNames(folder) {
	const names = [];
	for await (const [name, entry] of folder.entries()) {
		if (entry.kind === "file" && name.endsWith(".aseprite")) names.push(name);
	}
	return names;
}

global.ArtBoardFolders = { supported, rememberedFolder, connectFolder, hasFile, Sources };

})(window);
