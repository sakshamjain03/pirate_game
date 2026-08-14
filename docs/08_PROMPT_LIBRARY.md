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

Completed milestones' prompts have been removed. M3 and M4 are done and verified — their
prompts were dead weight and are recoverable from git history if ever needed. This file always
describes **only the milestone currently being built**.

**Current milestone: M7 — Campaign Spine & Economy Correction**
Spec: `.kiro/specs/milestone-m7-campaign-spine/`

---

# 1. THE MASTER PROMPT — type this in Antigravity chat

This is all you type. Everything else is in this file, which the prompt tells Gemini to read.

```
Read docs/08_PROMPT_LIBRARY.md and follow section 1.1 (Operating Contract) exactly.
Work milestone M7 autonomously from the lowest incomplete task. Halt at the first 🛑.
```

That's it. If Gemini ever loses the thread mid-session (new session, context reset), retype the
same two lines — it re-reads the contract and resumes from the lowest unticked task, because
task state lives in `tasks.md` checkboxes rather than in the chat.

**To resume after a checkpoint passes**, type:

```
Read docs/08_PROMPT_LIBRARY.md section 1.1. The checkpoint has passed — continue M7 from the
next task. Halt at the next 🛑.
```

---

## 1.1 Operating Contract — Gemini reads this

Everything below this line is addressed to the agent, not the human.

```
You are working in the Godot 4.3 project at d:\Pirate-game ("Pirate Empire"), a mobile-first
pirate empire-building game in GDScript.

## Your assignment

Work through Milestone M7 autonomously, ONE TASK AT A TIME, IN NUMERIC ORDER, starting at the
lowest-numbered task that is not yet complete.

The authoritative task list is:
  .kiro/specs/milestone-m7-campaign-spine/tasks.md

Per-task implementation notes, warnings, and acceptance criteria are in section 3 of:
  docs/08_PROMPT_LIBRARY.md
(this file). Read the section 3 entry for a task BEFORE you start that task.

## Required reading, in this exact order, before your first task

1. agents.md                  <- the project constitution, overrides everything else
2. docs/05_CURRENT_SYSTEMS.md <- ground truth on what actually exists today
3. .kiro/specs/milestone-m7-campaign-spine/requirements.md
4. .kiro/specs/milestone-m7-campaign-spine/design.md
5. .kiro/specs/milestone-m7-campaign-spine/tasks.md
6. docs/08_PROMPT_LIBRARY.md section 2 (Standing Rules) and section 3 (per-task notes)

Wave 1 (Tasks 1-7, economy correction) is the priority pass covered in detail below — every
other wave in M7 depends on Wave 1's corrected ship/captain data being in place first. Do not
skip ahead to Wave 2+ content even if you find it faster to implement; Task 7's checkpoint must
pass first.

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
6. **`IslandMenu`'s ship pricing was computed from hull `mass`** (`cost_gold = mass / 100`),
   which is exactly why M7 exists — it made every ship nearly free. If you find yourself
   reaching for a physics property to derive a gameplay cost, stop; costs are authored data
   (M7 Task 1), never derived from unrelated stats.
7. **`TutorialManager`'s 8 hardcoded steps are being replaced by M7**, not duplicated. If a task
   asks you to touch narrative/onboarding content, check whether `CampaignManager` (M7) already
   owns it before adding a second system.

## What you cannot verify

Manual/visual behaviour cannot be checked headlessly in this environment: camera feel, gamepad
input, shader appearance, boarding prompt feel, building model changes, HUD legibility, timed
offline-return prompts. **Say so explicitly rather than claiming a visual check passed.** There
is repeated precedent for this in the milestone specs.

## When you change a documented system

Update its entry in `docs/05_CURRENT_SYSTEMS.md` **in the same change**. That file is the living
ground-truth doc and exists specifically to stop systems from being silently reimplemented.

---

# 3. Per-task notes — M7

Numbering matches `.kiro/specs/milestone-m7-campaign-spine/tasks.md` exactly. Read the entry for
a task before starting it. Tasks with no extra notes below carry no hazards beyond the standing
rules — implement them straight from `tasks.md` and `design.md`.

## Wave 1 — Economy correction (Tasks 1–7)

**Nothing in Waves 2–4 should start until this wave's checkpoint (Task 7) passes.** Every
chapter authored later is tuned against the corrected ship ladder this wave produces.

### Task 1 — Extend ShipStats with identity and cost fields
⚠️ **Only ADD fields.** Do not change any existing property or physics value in `ShipStats.gd`
or in the 8 `resources/ships/*.tres` — hazard #1, the buoyancy/stability numbers are
load-bearing and unrelated to this task.
Before authoring the 8 `.tres` files, confirm `ship_id`/`display_name`/`ship_class`/
`cost_gold`/`cost_wood`/`cost_iron`/`cost_rum` are real `@export`ed properties on the script you
just edited — a mismatch fails silently.
Use the exact ladder table in `design.md` Part A1. Do not invent different numbers even if they
seem more "balanced" — this table is derived from the level-5 Farm cost (1350 gold) specifically
so the ship ladder and the building ladder stay in the same economic universe.

### Task 2 — Fix IslandMenu's ship pricing and naming
⚠️ Delete the `mass`-derived formula entirely — see hazard #6. Do not leave it as a fallback for
ships missing the new fields; Task 1 already authors all 8.
Verify manually (this is the one non-mechanical check in this wave, call it out explicitly in
your report): open the Shipyard in-game and read the displayed prices — a level-5 Farm should
cost less than the cheapest ship, and the Man O'War should cost more than any single building.

### Task 3 — Author captain boarding modifier and hire cost
Purely data — no script change. `base_boarding_modifier` and `hire_cost_gold` already exist as
`@export`ed fields on `CaptainData.gd`; they were simply never set on most of the 20 files.
Use the suggested values in `docs/12_CHARACTER_BIBLE.md` §5 (C1), or an ordering that preserves
the same relative ranking if you have a design reason to deviate — report which you did.

### Task 4 — Add captain identity fields
⚠️ Every `home_island_id` / `allegiance_faction_id` value you author must match a real
`island_id` / `faction_id` from the actual `.tres` files in `resources/world/` and
`resources/factions/` — do not guess spellings from `docs/12_CHARACTER_BIBLE.md`'s prose, check
the source files.
Leave `unlock_chapter_id` and `portrait_path` at their script defaults for now — chapter ids
don't exist until Wave 2 authors them (Task 13 fills these in later).

### Task 5 — Fix input rebinding (D57)
⚠️ Read `scripts/ui/SettingsMenu.gd` and `scenes/world/World.tscn` fully before choosing between
the two approaches in `design.md` A5. This is a "check the actual scene tree before deciding"
task per the project's D9/D11 lesson — do not assume `InputManager`'s location from the script
alone.
The test you write (`tests/test_input_rebinding.gd`) is the point of this task as much as the
fix itself: this defect shipped in M6 specifically because no test exercised the rebind flow
through the real UI, only the underlying `InputManager.rebind_action()` in isolation.

### Task 6 — Fix cold start
⚠️ Guard this on "is this a new game", not "is `home_island_id` empty" — an existing save with
a different home island must never be overwritten. Find the actual new-game code path rather
than assuming; `TutorialManager.gd`'s own comments about `SaveManager.delete_save()` are a
starting point, not the final answer.

### 🛑 Task 7 — CHECKPOINT: economy correction
**HALT. Do not attempt this task.** A human verifies it in Claude Code using the review prompt
in section 4.

## Wave 2 — Campaign data model (Tasks 8–12)

### Task 8 — Create DialogueBeatData, ObjectiveData, ChapterData
Use the schemas in `design.md` Part B1 exactly as written — do not add fields "for later." The
schema is deliberately the smallest one that covers all 5 authored chapters.

### Task 9 — Create the CampaignManager autoload
⚠️ This is the largest single task in the milestone. Read `scripts/managers/TutorialManager.gd`
in full before writing anything — its `wait_for` / `_check_condition()` pattern is what you are
reusing, not reinventing (hazard #7).
Register the new autoload in `project.godot` in the exact position `design.md` B2 specifies:
immediately after `EmpireManager`, before `TutorialManager`.
`get_save_data()` must return **duplicates**, never the live `Array`/`Dictionary` — this exact
mistake in `FleetManager` was a real bug (`docs/05_CURRENT_SYSTEMS.md` D12).
Check whether `EmpireManager` already exposes a way to ask "is region X active" before adding a
new method — `design.md` flags this as something to verify, not assume.

### Task 10 — Generalize TutorialManager
⚠️ This task requires a judgment call `design.md` Part C deliberately leaves to you: retire
`TutorialManager`'s step logic outright, or reduce it to a thin wrapper. Before choosing, search
the codebase for every caller of `TutorialManager.is_ui_unlocked()` and similar methods — if
that search comes back large, report it and prefer the wrapper approach rather than a risky
large deletion.
Whatever you choose, `user://tutorial_state.json`'s completion flag must still work — test this
explicitly, not just by reading the code.

### Task 11 — Small enablers: boss id, discovery write path
Check whether bosses already carry an identifiable id (e.g. via `ShipStats.ship_id` from Task 1)
before adding a second id field for this purpose.

### 🛑 Task 12 — CHECKPOINT: campaign data model
**HALT.**

## Wave 3 — Content authoring (Tasks 13–21)

### Tasks 14–18 — Author Chapters 1–5
⚠️ These are content-authoring tasks, not coding tasks, but the same "fails silently" rule
applies to every `target_id` in every `ObjectiveData` — it must match a real building/island/
faction/captain id, checked against the actual resource file, not typed from memory of
`docs/13_CAMPAIGN_LEVELS_1-5.md`'s prose.
Task 14 (Chapter 1) specifically replaces `TutorialManager`'s 8 old steps — do not leave both
systems' content live simultaneously.
Chapters 3 and 5 gate on `required_region_id`, **not** a raw notoriety number authored a second
time — `design.md` Part B1 explains why duplicating the threshold is a drift risk.

### Task 19 — Verify Cartagena as a second buildable island
This is a verification task that may turn into a fix task. If `IslandMenu` or `Island.gd` turns
out to assume "there is only one buildable island" somewhere non-obvious, fix it here and report
exactly what you found — this is exactly the kind of assumption Rule 5
(`docs/07_AI_AGENT_WORKFLOW.md`) says to report rather than silently patch around if it looks
like an architecture decision, not a bug.

### Task 20 — Objective-integrity test
This test is the automated version of the "check every id" warning repeated above — write it to
actually fail if a bad id slips through, not just to exist.

### 🛑 Task 21 — CHECKPOINT: content authoring
**HALT.**

## Wave 4 — UI and polish (Tasks 22–26)

### Task 24 — Dialogue beat queue support
Check whether `TutorialDialogue.gd` already supports advancing through multiple beats before
assuming it needs extending — it may already be closer to what's needed than `design.md` D3
guesses.

### Task 25 — Update docs/05_CURRENT_SYSTEMS.md
Document `CampaignManager`, the corrected autoload registry, and mark D53–D58 resolved.

### 🛑 Task 26 — CHECKPOINT: M7 complete
**HALT.**

---

# 4. Checkpoint review prompt — for the human, in Claude Code

Do **not** paste this to Antigravity. When Gemini halts at a 🛑, open Claude Code and paste:

```
Review the milestone-m7 work completed since the last checkpoint in the Godot project at
d:\Pirate-game.

Read .kiro/specs/milestone-m7-campaign-spine/tasks.md and find the checkpoint task Gemini halted
at. Verify its criteria are ACTUALLY met — run the GUT suite yourself
(--headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit) rather than trusting Gemini's
self-report, and read the real diff.

Do not trust a hardcoded baseline number from an old prompt — read the count recorded at this
milestone's own last verified checkpoint (or, if this is the first checkpoint, the 126 tests /
125 passing / 1 known LOD failure baseline recorded in docs/05_CURRENT_SYSTEMS.md as of
2026-08-14) and compare against that. Any new failure, or a drop in the total count, is a
regression.

Also confirm Gemini did not regress any of the known-fragile areas listed in
docs/08_PROMPT_LIBRARY.md section 2: ship stability, hull-basis cannon direction, enemy obstacle
avoidance, test_ship_combat.gd passing unmodified, and — new to M7 — that no ship's price still
derives from `mass` and that TutorialManager's content was replaced, not duplicated alongside
CampaignManager.

Fix anything broken before the milestone continues, then tell me whether Wave N+1 is cleared to
start.
```

---

# 5. Starting the next milestone

When M6 is complete and its final checkpoint has passed:

1. Delete section 3 (the M6 per-task notes).
2. Write the new milestone's `.kiro/specs/milestone-mN-<name>/{requirements,design,tasks}.md`.
3. Re-point section 1.1's spec path at the new milestone and author a fresh section 3.
   The two lines you type in chat do NOT change — only the milestone name in them.
4. Carry section 2 forward unchanged, adding any new "has broken before" hazards discovered
   during the completed milestone.

The Operating Contract and Standing Rules are milestone-agnostic by design — only 1.1's spec
path and section 3 change between milestones. That is the whole point of the split: the thing
you type stays stable, the thing you edit stays in version control.
