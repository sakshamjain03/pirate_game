# 08_PROMPT_LIBRARY.md

> Version: 2.0
> Status: Living Document
> Owner: Project Lead

---

# Purpose

This file drives **Antigravity/Gemini** through the current milestone.

Unlike v1.0 (which held one hand-pasted prompt per task and required a human to paste each one),
this file is self-driving. You type **two lines** into Antigravity chat (section 1); the file
supplies the rest. Gemini works through the task list autonomously, one task at a time, in
order, halting at every checkpoint.

The split is deliberate: what you type stays short and never changes between milestones, while
everything that *does* change — the spec path, the per-task hazards, the baseline — lives here
and is edited as a file rather than retyped as a prompt.

Completed milestones' prompts have been removed. M3 through M7 are done and verified — their
prompts were dead weight and are recoverable from git history if ever needed. This file always
describes **only the milestone currently being built**.

**No milestone is currently active.** M7 (Campaign Spine) and the M7.5 stabilization pass are
both complete as of 2026-08-25 — see `docs/16_MILESTONE_HISTORY.md` for the condensed record of
every milestone through M7.5, and `docs/05_CURRENT_SYSTEMS.md`/`docs/14_SYSTEM_INVENTORY.md` for
what's actually implemented today. The next candidate per `docs/15_MASTER_PLAN.md` is **M9 — The
Legible World** (M8, Combat Identity Rework, was already completed ad hoc and is tracked in
`docs/05_CURRENT_SYSTEMS.md` rather than as a `.kiro/specs/` milestone). It has not been
scaffolded yet. Section 1.1's spec path and section 3 below are placeholders — follow section 5
before typing the master prompt into Antigravity.

---

# 1. THE MASTER PROMPT — type this in Antigravity chat

**Placeholder — no milestone is scaffolded right now.** Before this section is usable, follow
section 5 to scaffold the next milestone's spec and fill in `<MILESTONE>` below (section 1.1's
spec path and section 3 need the same substitution).

This is all you type. Everything else is in this file, which the prompt tells Gemini to read.

```
Read docs/08_PROMPT_LIBRARY.md and follow section 1.1 (Operating Contract) exactly.
Work milestone <MILESTONE> autonomously from the lowest incomplete task. Halt at the first 🛑.
```

That's it. If Gemini ever loses the thread mid-session (new session, context reset), retype the
same two lines — it re-reads the contract and resumes from the lowest unticked task, because
task state lives in `tasks.md` checkboxes rather than in the chat.

**To resume after a checkpoint passes**, type:

```
Read docs/08_PROMPT_LIBRARY.md section 1.1. The checkpoint has passed — continue <MILESTONE> from
the next task. Halt at the next 🛑.
```

---

## 1.1 Operating Contract — Gemini reads this

Everything below this line is addressed to the agent, not the human.

```
You are working in the Godot 4.3 project at d:\Pirate-game ("Pirate Empire"), a mobile-first
pirate empire-building game in GDScript.

## Your assignment

Work through Milestone <MILESTONE> autonomously, ONE TASK AT A TIME, IN NUMERIC ORDER, starting
at the lowest-numbered task that is not yet complete.

The authoritative task list is:
  .kiro/specs/milestone-<MILESTONE>/tasks.md

Per-task implementation notes, warnings, and acceptance criteria are in section 3 of:
  docs/08_PROMPT_LIBRARY.md
(this file). Read the section 3 entry for a task BEFORE you start that task.

## Required reading, in this exact order, before your first task

1. agents.md                  <- the project constitution, overrides everything else
2. docs/05_CURRENT_SYSTEMS.md <- ground truth on what actually exists today
3. .kiro/specs/milestone-<MILESTONE>/requirements.md
4. .kiro/specs/milestone-<MILESTONE>/design.md
5. .kiro/specs/milestone-<MILESTONE>/tasks.md
6. docs/08_PROMPT_LIBRARY.md section 2 (Standing Rules) and section 3 (per-task notes)

Note whichever task wave depends on an earlier wave's checkpoint having passed first — check the
task list's own dependency notes rather than assuming waves are independent.

Do not skip this. Most defects in this project's history came from an agent writing code that
duplicated a system that already existed.

## The loop you must run

For each task N, in order:

  1. Read the task N entry in tasks.md AND its section 3 entry in this file.
  2. Implement ONLY task N. Touch only the files that task names.
  3. Run the verification command (section 2, "Verification").
  4. Compare against the baseline (section 2, "Baseline"). If you caused a regression, FIX IT
     before moving on. Never advance with a regression outstanding.
  5. Tick task N's checkbox in tasks.md from "- [ ]" to "- [x]" and append a one-line note:
     "Done <YYYY-MM-DD>: <what changed>".
  6. Write a short report for task N (see "Reporting" below).
  7. Move to task N+1.

## STOP CONDITIONS — these are absolute

HALT immediately and wait for a human when ANY of these happen:

  A. You reach a task marked with 🛑 (a Checkpoint: tasks 7, 12, 21, 26).
     Do NOT attempt the checkpoint yourself and do NOT start the next task. Checkpoints are
     verified by a human running Claude Code. This is mandated by
     docs/07_AI_AGENT_WORKFLOW.md Rules 4/7/8 — a task wave must never begin before the
     preceding checkpoint has been verified by someone other than the agent that did the work.

  B. The verification run shows a regression you cannot fix in a reasonable attempt.

  C. A task's instructions contradict agents.md, design.md, or what you find in the actual
     code. Report the contradiction rather than guessing which is right.

  D. A task would require you to invent architecture that design.md does not specify.

When you halt, state clearly: which task you stopped at, why, and what you need.

## Standing rules (full text in section 2 — these are the ones most often broken)

- Touch only the files the current task names. No unrelated refactors, no opportunistic
  "cleanup", no reformatting of files you are not otherwise changing.
- Never invent architecture beyond what design.md specifies.
- Never duplicate an existing system. If something looks missing, search for it first — it is
  often present but unwired.
- All gameplay values go in .tres Resource files, never hardcoded in scripts.
- Before authoring any .tres, confirm every property you set is actually @export'ed on the
  corresponding .gd script. A mismatch fails SILENTLY.
- Run the real verification command and report its REAL output. Never claim a pass you did not
  observe. Never claim a visual/manual check passed — you cannot perform those; say so.
- NEVER run `godot --headless --path . --check-only`. It does not terminate in this project.

## Reporting

After each task, report concisely:
  - Task number and title
  - Files created / modified / deleted
  - The actual verification output (test counts: total / passing / failing)
  - Anything that did not match the spec's assumptions
  - Whether you are proceeding to the next task or halting, and why

Begin now: read the required reading, then start at the lowest incomplete task in tasks.md.
```

---

# 2. Standing rules (referenced by the Operating Contract)

## Verification

The only verification command. GDScript is interpreted, so there is no build step; a clean GUT
run also proves every test script — and everything it imports — parses correctly.

```
<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Single file, much faster, for checking one specific fix:

```
<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit
```

**Never run `godot --headless --path . --check-only`.** `project.godot` sets `run/main_scene`,
so it boots into real gameplay and idles forever, producing a false "hang" and orphaned
processes. If a run looks hung, check for a stray Godot process from a previously killed
attempt first — that is the usual cause.

The engine binary is gitignored and not vendored. Check the project root, then `where godot` /
`where godot4` on PATH. Ask rather than guess if neither is found.

## Baseline

**Do not hardcode a test count in a prompt you paste to Gemini.** The number changes every
milestone as tests are added — the `103` figure that used to live here was stale by 15 tests
before anyone noticed (`docs/05_CURRENT_SYSTEMS.md`'s 2026-08-14 baseline correction). Instead,
tell Gemini to **run the suite first and record the actual totals** before making changes, then
compare after: any new failure, or any drop in the total test count, is a regression. The one
standing exception is `test_property_21_lod_distance_transitions` — no LOD system exists yet, a
real tracked gap, not a regression.

New tests must go **flat under `tests/`**. GUT's `-gdir=res://tests` does not recurse into
subdirectories in this project.

## Architecture rules (from `agents.md` — non-negotiable)

- **Never duplicate systems.** Search before you build.
- **Data-driven balance.** Gameplay values live in `.tres` `Resource` files. `@export`ed fields
  on the `.gd` script define the schema. A `.tres` setting a property the script does not
  `@export` **fails silently** — this has caused real bugs (`docs/05_CURRENT_SYSTEMS.md`
  D3/D14). Always check the script's real exported properties first.
- **Composition over inheritance.** New behaviour becomes a focused component hung off the
  existing controller, not a deeper class hierarchy.
- **Signals over direct references.** Prefer connecting to an existing signal over adding a new
  direct call path.
- **Persistence convention.** New persistent state exposes `get_save_data()` / `load_save_data()`
  for `SaveManager` to round-trip. Do not invent a new persistence path.

## Things in this codebase that have broken before — do not regress them

These are not hypothetical; each was a real defect that cost real debugging time.

1. **Ship stability.** The buoyancy / stability-torque / yaw-servo code in
   `BuoyancySimulator.gd` and `ShipMovement.gd` was stabilized across **four separate root
   causes** (`docs/09_VISUAL_BUG_TRACKER.md` V1). The yaw servo deliberately preserves roll and
   pitch. Regressing it re-capsizes every enemy ship. Do not touch this code unless a task
   explicitly says to.
2. **Cannon firing direction** derives forward from the **hull basis**
   (`parent.global_transform.basis.x`), not from marker rotation. A bug across all 12 markers on
   all 3 ship scenes was fixed exactly this way. Do not revert it.
3. **Enemy obstacle avoidance** (`_get_avoidance_turn` / `_probe` / `_push_to_open_water` in
   `EnemyAI.gd`, added 2026-08-09) is what stops enemy ships beaching themselves on islands
   (D39). Do not modify or bypass it.
4. **`tests/test_ship_combat.gd`** is the compatibility guard on the `ShipDamage` migration. It
   must keep passing **unmodified**. If it fails, the migration is wrong — fix the migration,
   never the test.
5. **Silent skips on load destroy player data.** Any resource resolver must `push_error` on an
   unresolvable id, never skip quietly.
6. **Ship/building/captain costs are authored data, never derived from an unrelated stat.**
   `IslandMenu`'s ship pricing used to be computed from hull `mass` (`cost_gold = mass / 100`),
   which made every ship nearly free (D53) — fixed by authoring real `cost_*` fields on
   `ShipStats`. If you find yourself reaching for a physics property to derive a gameplay cost,
   stop.
7. **Narrative/onboarding content lives in `CampaignManager` + `ChapterData`, not
   `TutorialManager`.** `TutorialManager`'s old 8 hardcoded steps were retired in M7 in favor of
   chapter objectives; it now only tracks UI-tab-unlock flags and the completion file. If a task
   touches onboarding content, check whether `CampaignManager` already owns it before adding a
   second system.
8. **A save missing a section is not the same as a save with an empty section.** `SaveManager`
   used to write `"player": {}` whenever `save_game()` ran with no `player_ship` in the tree,
   and `load_game()` couldn't tell that apart from a real empty section — it defaulted the ship's
   position to `Vector3(0, 1, 0)`, which is Port Royal's own island origin post-M7, silently
   teleporting the ship into the home island's collision on load (D64,
   `docs/09_VISUAL_BUG_TRACKER.md` V12). Any optional save section needs the same discipline: omit
   the key entirely when there's nothing to write, and check for a specific expected field before
   trusting a default.
9. **New chapter-specific content needs a chapter gate, not just a `.tres` file.** Chapter 4/5's
   dedicated bosses were fully authored (dedicated `ShipStats`/scene/`EncounterData`) but had no
   in-world trigger at all — neither chapter was actually completable (D65). If new content is
   meant to appear only during a specific chapter, wire it through
   `CampaignManager.is_chapter_current()` (or the equivalent gate on whatever system schedules it)
   before considering the content "done."

## What you cannot verify

Manual/visual behaviour cannot be checked headlessly in this environment: camera feel, gamepad
input, shader appearance, boarding prompt feel, building model changes, HUD legibility, timed
offline-return prompts. **Say so explicitly rather than claiming a visual check passed.** There
is repeated precedent for this in the milestone specs.

## When you change a documented system

Update its entry in `docs/05_CURRENT_SYSTEMS.md` **in the same change**. That file is the living
ground-truth doc and exists specifically to stop systems from being silently reimplemented.

---

# 3. Per-task notes — \<MILESTONE\>

**Empty — to be authored when the next milestone is scaffolded (section 5).** M7's per-task
notes lived here through 2026-08-25 and were removed once M7 (and the M7.5 stabilization pass)
completed, per this section's own convention: only the milestone currently being built is kept
here. The condensed record of M7's per-task hazards, and every milestone before it, is in
`docs/16_MILESTONE_HISTORY.md`.

Numbering should match `.kiro/specs/milestone-<MILESTONE>/tasks.md` exactly. Read the entry for
a task before starting it. Tasks with no extra notes carry no hazards beyond the standing rules
— implement them straight from `tasks.md` and `design.md`.

---

# 4. Checkpoint review prompt — for the human, in Claude Code

Do **not** paste this to Antigravity. When Gemini halts at a 🛑, open Claude Code and paste:

```
Review the milestone-<MILESTONE> work completed since the last checkpoint in the Godot project
at d:\Pirate-game.

Read .kiro/specs/milestone-<MILESTONE>/tasks.md and find the checkpoint task Gemini halted at.
Verify its criteria are ACTUALLY met — run the GUT suite yourself
(--headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit) rather than trusting Gemini's
self-report, and read the real diff.

Do not trust a hardcoded baseline number from an old prompt — read the count recorded at this
milestone's own last verified checkpoint (or, if this is the first checkpoint, the most recent
baseline recorded in docs/05_CURRENT_SYSTEMS.md / docs/14_SYSTEM_INVENTORY.md §0) and compare
against that. Any new failure, or a drop in the total count, is a regression.

Also confirm Gemini did not regress any of the known-fragile areas listed in
docs/08_PROMPT_LIBRARY.md section 2 ("Things in this codebase that have broken before"), plus
anything specific to this milestone's own hazards.

Fix anything broken before the milestone continues, then tell me whether the next wave is
cleared to start.
```

---

# 5. Starting the next milestone

When a milestone is complete and its final checkpoint has passed (this is the current state —
see the note at the top of this file):

1. Delete section 3 (the completed milestone's per-task notes) — already done for M7/M7.5.
2. Write the new milestone's `.kiro/specs/milestone-mN-<name>/{requirements,design,tasks}.md`
   per `docs/15_MASTER_PLAN.md`'s roadmap (M9 — The Legible World is next).
3. Re-point section 1.1's spec path (replace every `<MILESTONE>` placeholder) at the new
   milestone and author a fresh section 3. The two lines typed in chat do NOT change — only the
   milestone name in them.
4. Carry section 2 forward unchanged, adding any new "has broken before" hazards discovered
   during the completed milestone (D64/D65 were added this way after M7.5).
5. Add the completed milestone's own condensed entry to `docs/16_MILESTONE_HISTORY.md` before
   moving on — that file is the durable record once this file's per-task detail is deleted.

The Operating Contract and Standing Rules are milestone-agnostic by design — only 1.1's spec
path and section 3 change between milestones. That is the whole point of the split: the thing
you type stays stable, the thing you edit stays in version control.
