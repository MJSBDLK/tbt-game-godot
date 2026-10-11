# Art board

`index.html` in this folder, opened straight from disk (bookmark it): every
character's art, what's done, and what's next. Notes left on the board live in
`notes/`. The game-side facts come from `game_data.js`, written by
`game_data_generator.gd` (its header says when to re-run it); the rules
themselves are `board_logic.js`.

## What each character needs

| Character asset                                  | If missing, the game shows          | Needed for |
|--------------------------------------------------|-------------------------------------|------------|
| Idle still frame, pivot checked                  | nothing: the unit can't appear      | orange     |
| Idle animation                                   | the still (all the game plays today)| orange     |
| Line art + square portrait crop                  | a crop of the sprite's head         | orange     |
| Melee clip, if any move hits from 1 tile         | its ranged clip, else the nudge     | yellow     |
| Ranged clip, if any move hits from 2+ tiles      | its melee clip, else the nudge      | yellow     |
| Physical/special clip per reach its moves use    | the same reach's other-kind clip    | green      |
| cast, if it has support moves                    | its melee clip, then ranged (open*) | green      |
| hurt / dodge / death                             | a code-drawn flash or fade          | green      |
| Crit clip per reach its moves use                | the normal attack clip              | extra      |
| 92×92 pixel portrait                             | the line-art crop                   | retired    |
+ Red = short of orange: no idle animation or no line art (a still alone
  stays red; so does `placeholder_unit.png`). Orange = idle animation + line
  art, short of yellow. Yellow = good enough, ships in alpha. Green = done.
  Extra = its own box on the board, never counted: nothing plays crits yet.
  Two reaches in code: 1 tile = melee, 2+ = ranged. "Its moves" = the whole
  basePoolMoves, not the 4 equipped, so a swap never changes a color. A plain
  `melee`/`ranged` clip covers both kinds: each kind has its own box, and the
  plain clip fills it dimmed with an "= Melee" badge (counts; draw its own
  only if it should look different).
+ Layout: one collapsible row per character. Closed = a pip per box, so rows
  line up like a grid; open = the boxes grouped by the color that needs them.
  First visit opens the next-up character; after that the board remembers.
+ Class variants (not needed for alpha, never counted): the character redrawn
  for each class it can promote into, mostly recolors. Each variant needs
  every box, because a recolor shows in every clip. Its files are
  `<id>_<class>` (`spaceman_jetpack.aseprite`, `art/lineart_fullres/spaceman_jetpack.png`).
  A missing box shows, dimmed, the art of the class it promotes from
  ("= Squire"). Trees come from `promotes_to` in `Enums.CLASS_INFO`. The
  board has a collapsible "Class trees" panel (every tree, undesigned gaps
  dashed) and, in each open row, a collapsible tree of that character's
  classes. Click a class to see its boxes.
+ Characters are keyed by their JSON file name (`spaceman`, `maam`), never
  `characterId`. JSON files are never renamed: saves store their paths.
+ The board tracks the renames: any file whose declared path isn't the
  convention path shows up with its target name, and drops off once renamed.
  Renames happen in Aseprite (tags + file names); the exporter rebuilds file
  names from tags, so renaming a PNG gets undone.
+ Unused line art (battle chicken's, etc.) isn't flagged. Mounts are concept art.
+ Placeholders: art that's in the game but not good enough yet (paper photos
  so far) is listed in `tools/art_dashboard/placeholders.js` with the reason.
  The box shows it with a red "placeholder" badge and the reason, and it
  doesn't count toward a color.
+ Every checked box shows a keyframe: attacks and reactions their hit frame
  (the exporter's marker, else the middle frame), idle its first frame, line
  art its portrait crop. Frame count comes live from the strip's width ÷
  height (every character canvas is square), so a fresh export shows without
  waiting on regenerated data. Hovering a box plays the clip.
+ *Open question for RQD (todo.md # Claude): your old row said "nothing, use
  particles on map"; the code plays the melee clip (Ernesto/Keener/Spaceman/
  Grasker swing for Focus today). Which is right?
