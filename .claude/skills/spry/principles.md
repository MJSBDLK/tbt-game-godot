# SPRY, rewritten for this project

The point of this project is making something we think is cool. The point of
SPRY here is keeping the codebase cheap to change — for an AI agent first, for
a human reader second — so that making cool things stays fast as the game
grows. Nothing here is about business value. Polish, feel, and animation are
the product, never overhead.

## The two questions

Every substantive change should answer yes to at least one:

1. **Cooler** — does it make the game better for the player?
2. **Cheaper** — does it make the next change cheaper for whoever makes it?

Neither: it shouldn't be in the diff. Cooler but more expensive: that's a real
trade-off. State it in the commit message; don't hide it.

## Context is the budget

An agent's working memory is the set of files it must read to make a change
safely. That set is the cost of the change, and it is what these principles
protect. Four things grow it:

- **Long files.** A file an agent reads whole should fit one read. ~1000 lines.
- **Fan-out.** One game concept spread across many files, or reached through a
  relay (manager → signal → manager → node) that must be traced to be
  understood. Wiring that lives in a `.tscn` the script never mentions counts.
- **Globals.** Every autoload is state every file can reach. Understanding one
  function can mean reading several autoloads.
- **Duplicate narrative.** The same story told in a commit message, a todo
  entry, and a block comment is three things to reconcile and three to drift.

## Principles

1. **Earn complexity.** Abstraction after the second place in the code that
   needs it, not before. A setting, toggle, or mode only when two behaviors both need to
   survive a playtest — and then delete the loser (Walk vs Ghost, 2026-09-10).
   A new autoload needs a reason a plain `class_name` can't meet.
2. **Remove before add.** Every diff should be able to say what it deleted.
   Look for: toggles made unconditional with the machinery kept "for a cheap
   re-audition"; comments describing code that's gone; tests pinning behavior
   that's gone; parked features nobody has asked about in a month.
3. **Keep it local.** A change to one game concept touches few files. Prefer a
   direct call, or a signal on the thing itself, to a relay through a manager.
   Put the code next to the concept it implements.
4. **Files under ~1000 lines.** Over-cap files are listed below. Don't grow
   them. A substantial change to one carries a split proposal.
5. **Names in game language.** `truncate_waypoints_to`, not
   `handle_marker_press_alt`. A designer should recognize the name. No pattern
   nouns (Handler, Strategy, Factory) unless the pattern is the point.
6. **Verifiable without F5.** The agent can't eyeball a build. Pure static
   functions, GUT tests, runtime asserts, and headless probes are its eyes —
   sanctioned, not tax. But tests are context too: one contract per test, no
   fixture towers, and delete tests that pin deleted behavior.
7. **Docs next to code.** The central type's class header is the living map.
   A block comment sits at the non-obvious dispatch point. Planning docs are
   checklists with pointers, not narratives. Pick one home for each story.
8. **Check length before accepting it.** Long is fine when it's better. Before
   accepting a long file, function, comment, or doc entry, ask what a reader
   would lose at half the length. "Nothing" → cut. A specific answer → keep,
   and say why. The common "nothing" is history in a comment (see Comments).

## Comments

Comments are part of the prompt: every one is read on every load. They are
encouraged at any spot that looks wrong but isn't — that is the cheapest
guardrail against the next agent "fixing" it. Keep them terse: one or two
lines, the conclusion, not the reasoning. Four kinds earn their place:

- **Guardrail.** "Looks like X, isn't: reason. Don't <the tempting fix>."
  Highest value per token in the repo.
- **Contract at a seam.** What must be true here, next to the assert that
  checks it. One line.
- **Tuned value.** "Tinker knob; 135 ≈ 0.12 s/tile." The unit conversion,
  not the tuning history.
- **Class header as map** for a central type. The one place a paragraph is
  earned.

Cut: dates, who decided, what it used to be, alternatives rejected. That is
the commit message's job, and git blame keeps it. The exception is a
present-tense consequence ("an old settings.cfg may still carry this key; it
is ignored") — a fact about now, not a story about then. If a guardrail needs
a paragraph, the name or the structure is doing too little.

## Not dogma

Every principle has an exception. A flag with a stated reason is a waiver, not
a failure. The review's job is to make the reason explicit, not to block.
This is a 2026-09-10 baseline; revise a rule when it bites.

## Exit clause

If SPRY reviews start making results worse — for whatever reason — rip it out
and forget it. Tells: reviews that are mostly waivers, a review that pushed a
change which made the code harder to work with, or sessions slowed with no
deleted code to show for it. Don't refine past that point.

It stays shallow-rooted on purpose: no hook, no reference from code or tests,
no doc outside this directory. Removal is three steps:

1. `rm -r .claude/skills/spry`
2. Delete step 1 of "Before Committing" in `CLAUDE.md` (step 2 stays).
3. The agent deletes its `spry-before-commit` memory and index line.

The Comments section stands on its own — move it into CLAUDE.md's Code Style
if the rest goes.

## Project facts the reviewer needs

**Earned abstractions — don't flag:** `CombatEffect` (24 subclasses),
`CombatPresenter` (3), `GameColorPalette`, and the static pure-function
modules (`HintBarCommands`, `ZIndexCalculator`, and kin).

**Sanctioned infrastructure — don't flag:** GUT tests in `tests/unit/`,
`assert()` at fragile seams, `DebugConfig` flag-gated logging, `tools/diag/`
probes, `addons/aseprite_tag_exporter/`, the SceneRouter + HUDViewport dual
render pipeline, the versioned pre-commit hook.

**Over-cap files (2026-09-10) — don't grow; split when substantially touched:**

| File | Lines |
|---|---|
| `scripts/units/unit.gd` | 2164 |
| `scripts/ui/panels/unit_detail_panel.gd` | 1452 |
| `scripts/ui/ui_manager.gd` | 1101 |
| `scripts/managers/input_manager.gd` | 1096 |
| `scripts/ui/components/unit_workbench.gd` | 1075 |

Third-party addons (`gut`, `AsepriteWizard`, `importality`) are exempt. Update
this table when a file crosses the line in either direction.

**Globals (2026-09-10):** 20 autoloads; 24 `get_node("/root/...")` absolute
lookups. A new one of either needs a stated reason.

**Comment baseline (2026-09-10):** 24% of `scripts/` lines are comments
(`unit.gd` 28%); 170 dated history notes ("RQD 2026-08-11", "was 88",
"RETIRED"). Take those out of any hunk you're already editing; don't add new
ones.

**Planning docs are context too.** `.claude/todo.md` (~81 KB) and
`todo-archive.md` (~159 KB) are the largest single reads in the repo. Apply
principle 8 to every entry added there: what would the next reader lose at
half? The commit message already holds the narrative; the entry can point at
it.
