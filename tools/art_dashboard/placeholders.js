// Art wired into the game as a stand-in that doesn't count on the board yet.
// Path → why, shown on its box. The art-board skill removes a line once the
// real art replaces the file (check_on_disk.js reports which ones).
const PAPER_PHOTO = "It's a photo of the paper page, not transparent ink, so the paper and pencil sketch show behind the portrait in the game. Re-export with only the ink and color layers visible, same file name.";

window.ART_DASHBOARD_PLACEHOLDERS = {
	"art/lineart_fullres/keener.png": PAPER_PHOTO + " The pixel-sprite reference in the corner goes too.",
	"art/lineart_fullres/robot.png": PAPER_PHOTO,
	"art/lineart_fullres/thumps.png": PAPER_PHOTO,
	"art/lineart_fullres/flamethrower_phoenix.png": PAPER_PHOTO,
	"art/lineart_fullres/squash.png": PAPER_PHOTO,
};
