# Art board notes

Notes left on the art board (`tools/art_dashboard/index.html`), one JSON file
per note so two branches never edit the same file. Nothing here is required.
The board checks this README exists to confirm the right folder was picked,
so keep it.

File name = what the note is on:

- `board.json`: the whole board
- `character--<id>.json`: a character row (`<id>` = its JSON file name)
- `column--<column>.json`: a column (`idle`, `melee`, ...)
- `cell--<id>--<column>.json`: one box

Shape:

```json
{
	"target": {"kind": "cell", "character": "ernesto", "column": "melee"},
	"text": "What the note says.",
	"updated": "2026-09-27T20:15:00.000Z",
	"replies": [{"author": "Claude", "text": "An answer.", "date": "2026-09-28T09:00:00.000Z"}]
}
```

Claude reads these when it syncs the board and answers inside `replies`, so
the answer shows up on the board. Delete a note once it's handled.
