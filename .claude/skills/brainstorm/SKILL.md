---
name: brainstorm
description: Brainstorms a character's moves and passives with RQD, starting from their character brief, then lands the agreed kit as their class's schedule. Use when user says "/brainstorm", "/brainstorm <character>", "brainstorm <character>", or wants to design a character's or class's kit, moves, passives or schedule.
---

# Brainstorm a kit

A conversation with RQD, not a report. In: his character brief, free-form
answers to `tools/art_dashboard/notes/briefs/template.md`. Out: a class
schedule (`data/classes/README.md`; rules: §9 of
`data/design/class-and-promotion.md`). Characters are keyed by their JSON file
name in `data/characters/`. Several names = one session that compares kits.

## 0. No character named

List `tools/art_dashboard/notes/briefs/<id>.md` in `tools/art_dashboard/ranking.js`
order: filled, thin (sections empty), or none, and whether its base class has a
`schedule` yet. Suggest the first ranked one that's filled with no schedule. Stop.

## 1. Read

- The brief (missing or thin: step 2).
- `data/characters/<id>.json`: stats, growths, types, `currentClass`, `animations`.
- `data/classes/trees/<id>.json` and each of its classes in `data/classes/pool/`.
- §9, and the header, Rules and "Mechanics no move can use yet" of
  `data/design/moves-and-passives.md`.

Look up, don't read whole: `data/moves/basic_move_bank.json` (castable, keyed by
name; field reference in the `MoveData` header), `data/passives.json` +
`PassiveRegistry` (a passive needs a handler to do anything), the wishlist
(`grep` a name before inventing it), and other classes' schedules (`grep` the
name in `data/classes/pool/`) for who else learns it.

## 2. Fill the gaps

No brief, or an empty section this class needs (a support class with no "help
or hinder"): ask that question in chat, one or two at a time. Save his answers
into `briefs/<id>.md` in the template's shape, in his words. Skip what he left
blank on purpose.

## 3. Propose

Open with two or three lines on who the character is, in the brief's terms.
Then one table: the kit, then the lists dealt onto levels by the tier-1 rhythm
in §9 (tiers 2-3: list order only, their rhythm isn't laid out).

| Lv | Move / passive | Spec | From the brief |

- Spec: `Element/Kind pN rN accN, secondary` for moves; trigger then effect
  for passives. Mark `(needs X)` for a mechanic the engine lacks.
- From the brief: the answer it grew from ("misses, gets salty"). Nothing
  backs it: cut it or say why it stays.
- The north star (Rules): name the choice each passive and secondary creates.
  A kit that's mostly number changes is the wrong shape; rework before showing it.
- Reuse before inventing. Say whether a new move should spread wide (Shank:
  most bladed enemies) or stay narrow.
- Enemies field a random 4 of what they've learned (§9), so each move has to
  work without the others.
- The clip each move plays: melee (reach 1), ranged (2+), cast (Support), as
  `UnitAnimationResolver` decides. Flag a clip the character has no art for:
  that's Lawrence's queue.
- Numbers: damage is attack + power - defense, so power matters most early;
  keep it conservative. Hit is one roll, so 95 reads as sure and 80 as risky.
  Skill scales a secondary's chance by (1 + skill/100). Uses come from power
  (`Move.calculate_max_uses_from_power`).

## 4. Iterate

He answers in loose notes. Keep what he approved, rework the rest, never bring
back a cut idea. Each round is one updated table, not a new essay.

## 5. Land it, only when he says so

- The class file's `schedule`: kit, then moves and passives in learning order.
- Each new move or passive: a row in `moves-and-passives.md` under its
  element/kind, in the doc's row format. The schedule says who learns it.
  The art board reads an unbuilt move's clip from that row (the heading's
  kind, a leading `Support`, `rN`), so write them.
- One line in the tree's `notes`: why the kit is what it is.
- Regenerate the art board, which lists the kit and draws its needs from it:
  `godot-4 --headless --path . -s tools/art_dashboard/game_data_generator.gd`.
- Then `node --test tools/art_dashboard/class_tree_test.js` and GUT
  `test_class_trees` and `test_art_dashboard_data`. Building moves and
  handlers is separate work. Don't commit.
