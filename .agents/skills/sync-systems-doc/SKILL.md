---
name: sync-systems-doc
description: Check whether docs/05_CURRENT_SYSTEMS.md still matches the real codebase after recent changes, and report what's undocumented. Use at the end of a milestone or checkpoint, before marking documentation complete.
---

# Sync Systems Doc

Checks whether `docs/05_CURRENT_SYSTEMS.md` — this project's single source of truth for "what
actually exists" — still matches the real codebase, per Rule 6 in `docs/07_AI_AGENT_WORKFLOW.md`
("Documentation is updated in the same pass as the code... not optional cleanup"). This doc exists
specifically because a ~526-file/~92k-insertion commit once landed with zero accompanying docs;
skipping this check recreates that problem one milestone at a time.

## Scope

Default scope: everything changed since `docs/05_CURRENT_SYSTEMS.md` itself was last modified
(`git log -1 --format=%H -- docs/05_CURRENT_SYSTEMS.md`, then diff from there to HEAD). If the
user names a specific milestone or task range instead, scope to that range's commits/diff.

## Steps

1. Get the changed-file list for the scope (`git diff --name-only <since>...HEAD`), filtered to
   `scripts/`, `resources/`, `scenes/`, and `project.godot` (autoloads).
2. Read `docs/05_CURRENT_SYSTEMS.md` in full.
3. For each changed file, check whether the doc actually reflects it:
   - **New autoload** in `project.godot`'s `[autoload]` section not listed in the doc's §4
     registry table.
   - **New/changed manager or system script** under `scripts/managers/`, `scripts/world/`,
     `scripts/combat/`, `scripts/ui/` whose behavior isn't described in §1, or whose description
     is now stale (a field/method the doc references no longer exists, or a "Known gaps" item the
     diff actually closed).
   - **New Resource type or populated `.tres` count** (captains, ships, buildings, factions,
     regions, techs) where the doc states a specific count ("20 populated captains") that the
     diff changed — these counts are exactly the kind of detail that silently rots.
   - **A defect in the §2 table** whose `Status` should flip (marked open but the diff clearly
     fixes it, or vice versa — a "Resolved" entry a later diff apparently reverted).
4. Do not silently patch the doc yourself with a best-guess sentence — this doc's voice and level
   of detail (concrete file:line references, exact defect numbering, dated entries) is deliberate.
   Instead, report a punch list: file/system, what changed, what the doc currently says (or that
   it says nothing), and a suggested edit for a human or the main session to apply.
5. Flag, but don't fail on, changes that are purely internal refactors with no behavior change —
   the doc describes *what runs*, not implementation detail; not every diff needs a doc update.

## Output shape

A short table: `File/System | What changed | Doc currently says | Suggested update`. End with an
explicit yes/no: "05_CURRENT_SYSTEMS.md is in sync" or "N items need updating before this
checkpoint closes" — mirroring the pass/fail discipline the project's own checkpoint rules already
use elsewhere; never a vague "looks mostly fine."
