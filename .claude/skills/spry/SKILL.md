---
name: spry
description: Reviews a diff for agent-context cost — unearned abstractions, things that should have been deleted, files over the ~1000-line cap, fan-out through relays, duplicate narrative. Runs before every commit. Use when user says "/spry", "spry review", "is this spry".
---

# SPRY Review

Read `.claude/skills/spry/principles.md` first, always. It's short and holds
the project facts: earned abstractions, over-cap files, what not to flag.

## 1. Get the diff

| Situation | Command |
|---|---|
| Default | `git diff HEAD` |
| `--staged` | `git diff --staged` |
| Feature branch about to squash | `git diff rqd--main...HEAD` |
| Clean tree on rqd--main | `git diff HEAD~1` |
| Commit ref argument | `git diff <ref>~1..<ref>` |
| Path argument | append `-- <path>` |

Untracked files don't appear in a diff: `git status --porcelain | grep '^??'`
and read new ones whole. New class files are exactly what this review is for.

Skip `tile_map_data` blobs and `.import`/`.uid` churn. Over ~1500 lines of
diff: review per subsystem path (`scripts/combat/`, `scripts/ui/`, …) and
report per path.

## 2. Evaluate

Answer each against the actual diff, citing `file:line`. Grep for call sites when
counting them; don't guess. Say "n/a" when nothing applies — don't pad.

1. **Cooler or cheaper?** Which question does each substantive hunk answer?
   Flag anything answering neither.
2. **Earned?** New class, abstraction, setting, mode, or autoload: how many
   places in the code use it right now? Fewer than two → flag unless the diff
   states the reason.
3. **Deleted?** What did the diff remove? If nothing, was there really
   nothing? Look for toggles made unconditional with machinery kept, comments
   describing gone code, tests pinning gone behavior, history comments in a
   hunk the diff already edits.
4. **Local?** For each game concept changed, count the files touched. Spread
   over more than ~3 → is the spread inherent, or is there a relay layer?
   Wiring in a `.tscn` the script never mentions counts as a file to read.
5. **Under cap?** Did an over-cap file grow? Did any file cross ~1000?
6. **Game language?** New identifiers a designer would recognize. No
   abbreviations, no pattern nouns for their own sake.
7. **Verifiable?** New logic with no test. New fragile seam with no assert.
   A test that asserts rendering (wrong layer). A test left pinning deleted
   behavior.
8. **Length checked?** Same narrative in more than one place? Standalone
   `.md` duplicating a class header? History in a comment — dates, "was X",
   what got deleted, alternatives rejected — that belongs in the commit
   message? For anything long — file, function, comment, doc entry — what
   would a reader lose at half?

## 3. Output

```
## SPRY Review — <diff source>: <N> files, +<A>/−<D>

**Verdict:** Clean | Trim | Rethink

### Flags
- <what> — `file:line` — <do this instead>
(or "none")

### Waivers
- <flag> — <reason the diff or commit message gives>
(flags with a stated reason are fine; list them so the reason is on record)

### Deleted
<what the diff removed, or "nothing — <what could go, or why nothing should>">

### Next step
<one concrete action>
```

Under ~40 lines. Praise is one line, not a section. **Trim** = keep the
design, cut something. **Rethink** = a principle is broken with no reason
given and the fix changes shape.
