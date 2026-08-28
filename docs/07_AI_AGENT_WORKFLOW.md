# 07_AI_AGENT_WORKFLOW.md

> Version: 2.0
> Status: Living Document
> Owner: Project Lead

---

# Purpose

**As of 2026-08-26, this project is built entirely by Claude Code — planning, implementation, and
verification all happen in the same agent.** Earlier versions of this document described a
two-agent split (Claude planning/reviewing, Antigravity/Gemini implementing); that workflow is
retired. If you find a doc, skill, or agent definition that still assumes a Gemini/Antigravity
handoff, that's stale — fix it rather than following it (see "What this replaced," below).

Retiring the second agent does not retire the discipline that workflow existed to enforce. The
failure mode this document exists to prevent is unchanged: writing a large, ambiguous diff that
"looks done," and discovering later that it duplicated an existing system (`AGENTS.md`'s explicit
warning), silently changed an unrelated file, or that a checkpoint was marked passed without the
verification command actually being re-run. **A single agent can self-report falsely just as
easily as two agents can miscommunicate** — this project's own history has already proven that
more than once (see the "known self-report failures" list below, several of which happened in a
single-Claude-session context, not a handoff). The rules below are what keep a solo agent honest
with itself.

---

# Rule 1: Every task is scoped before it's started

Before writing code, the unit of work should already exist as a numbered task in a
`.kiro/specs/<milestone>/tasks.md` file (see the `spec-new` skill for scaffolding a new milestone,
and the six milestones already scaffolded under `.kiro/specs/milestone-m9-presentation-pass/`
through `milestone-m14-live-operations/` for the current shape). A well-scoped task:

- Touches a small, explicitly-named set of files — if a task's implementation keeps pulling in
  more files than it named, that's a signal to stop and re-scope, not to keep going.
- Has a single, mechanical, explicitly-stated verification step (not "make sure it works" — an
  exact command to run or an exact in-game/in-editor action to perform and what to observe).
- Cites the exact requirement IDs it satisfies, traceable back to `requirements.md`.

If a task doesn't fit this shape, split it further in `tasks.md` before implementing it — sizing
work correctly is part of the job, not a step to skip because there's no second agent to hand it
to.

# Rule 2: Read before write

Before implementing any task, read, in order:
1. `AGENTS.md` — the repository's non-negotiable rules.
2. `docs/05_CURRENT_SYSTEMS.md` — what already exists. Never re-implement anything described
   there; extend it.
3. The specific milestone's `requirements.md` → `design.md` → `tasks.md`.

Most defects in this project's history came from skipping this and writing code that duplicated a
system that already existed.

# Rule 3: One task at a time; do not self-chain past a checkpoint

Work through a milestone's tasks in numeric order, one at a time. After each task: run its
verification step for real, tick its checkbox, and write a one-line note of what changed. This
still matters solo — a long autonomous session without a pause point is exactly how scope drifts
and how a later task's assumptions quietly stop matching what an earlier task actually built.

**Never skip or self-approve a Checkpoint task.** When a `tasks.md` reaches a task titled
"Checkpoint," stop implementing and switch into verification mode (Rule 4) before continuing to
the next wave — do not let the momentum of "it's probably fine" carry you past it.

# Rule 4: Checkpoints are independently re-verified, never trusted from memory

This is the rule this project has broken most often, and always the same way: an agent implements
a wave of tasks, remembers testing it, and ticks the checkpoint without re-running the actual
verification command against the current state of the tree.

**Known self-report failures in this project's history**, all caught only by someone actually
re-running the real command instead of trusting notes: D15, D42, D57 (features checkpoint-verified
in isolation but dead in the real scene tree); two tasks marked `[x]` in milestone-m4 with zero
corresponding file changes; M6's final checkpoint ticked with "Skipped local execution of GUT since
binary is unavailable" when the binary was available the whole time; D66/D67 (the M7.5
checkpoint's self-reported "323/322" test result did not reproduce on a fresh run); and, most
recently, **D32/D36** — two defects this very document once recorded as "Resolved" that reproduced
identically on a fresh headful capture on 2026-08-26, nine days after being marked fixed, with no
intervening code change to explain a regression (see `docs/05_CURRENT_SYSTEMS.md`'s "Presentation
audit" section). That last one happened with no second agent involved at all — a single verified
capture was treated as "fixed forever" instead of "fixed as of that one observation."

At every checkpoint:

1. Re-read every file changed since the last checkpoint (`git diff`/`git status`), and cross-check
   it against every task marked `[x]` in the range — a checked task with no corresponding change is
   not done.
2. **Actually run** the verification commands (see "Standing verification commands" below) — do
   not accept a remembered or assumed result.
3. For anything visual/interactive/feel-based, run a fresh headful `CaptureHarness` capture (see
   `docs/09_VISUAL_BUG_TRACKER.md`) and actually look at the images — a passing GUT suite is not
   sufficient evidence for that category of defect, proven twice now by D32/D36.
4. Fix any defect found before the next wave starts — do not let a broken checkpoint accumulate on
   the assumption "it'll get fixed later."
5. **When the stakes justify it** (a milestone's final checkpoint, or anything touching a
   previously-fragile area listed below), use the `checkpoint-reviewer` subagent for this pass
   instead of self-certifying in the same context that did the implementation — a fresh pass with
   no memory of "I already tested this" is structurally less likely to skip the actual re-run.

# Rule 5: Never invent architecture beyond what design.md specifies

If implementing a task surfaces a design decision `design.md` didn't already make (a new class, a
new signal, a new resource schema, a new autoload), stop and update `design.md` first, rather than
improvising a resolution inline. This is `AGENTS.md`'s "never invent architecture" rule, applied to
the moment it's most tempting to skip: mid-implementation, when the fix seems obvious. If a task's
assumptions turn out not to hold (a referenced file doesn't have the expected shape), that's a
signal to pause and fix the spec, not a signal to improvise around it and hope the spec catches up
later.

# Rule 6: Documentation is updated in the same pass as the code

Every milestone's final checkpoint task includes updating `docs/05_CURRENT_SYSTEMS.md` to reflect
what was actually built. This is not optional cleanup — it is the mechanism that prevents the exact
problem this project already hit once (a large commit that added most of the game's actual systems
with zero corresponding documentation, discovered only by a full codebase audit). Skipping this
step recreates that problem every milestone.

# Rule 7: Verify with the GUT suite, not `--check-only`

`godot --headless --path . --check-only` does not reliably exit on its own in this project — with
`run/main_scene` configured, it boots into real gameplay and then idles forever instead of
quitting, which produces false "hangs" and orphaned processes if you wait on it or poll it. Use the
GUT suite instead (see below) — it calls `-gexit` and reliably terminates, and a clean run already
proves every test script parses correctly, which covers what `--check-only` was being used for
anyway.

Always launch long-running verification commands with proper background execution and wait for the
actual completion signal — do not manually poll with sleep loops, and do not assume a command
"hung" and kill it without checking whether a leftover process from an earlier attempt is the
actual problem. Check for stray Godot processes before starting a new run
(`Get-Process | Where-Object {$_.ProcessName -like "*Godot*"}` on PowerShell).

# Rule 8: Milestones are sequential, not started in parallel

Do not start a new milestone's Task 1 until the prior milestone's final checkpoint has actually
passed (Rule 4). This still matters without a second agent: starting M11's work before M10's
checkpoint is truly verified means any regression M10 secretly shipped compounds invisibly under
M11's own changes, and untangling which milestone caused what gets harder with every task added on
top.

---

# Standing verification commands

The only verification command for correctness. GDScript is interpreted, so there is no build step;
a clean GUT run also proves every test script — and everything it imports — parses correctly.

```
<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Single file, much faster, for checking one specific fix:

```
<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit
```

**Never run `godot --headless --path . --check-only`** (Rule 7). The engine binary is gitignored
and not vendored — check the project root, then `where godot` / `where godot4` on PATH. Ask rather
than guess if neither is found.

For anything visual/physics/UI — proven repeatedly (D23–D28, D31–D38, D64/D65, and now D32/D36) to
be invisible to the GUT suite — run the headful screenshot harness and actually look at the output:

```
<godot-binary> --path <project-root> scenes/debug/CaptureHarness.tscn --capture-dir=<abs path>
```

Run headful (no `--headless` — the dummy renderer produces blank images), zero player input,
screenshots at t≈0/1/3/7/12s. See `docs/09_VISUAL_BUG_TRACKER.md` for the full history of what this
harness has caught that code review and automated tests both missed.

## Baseline discipline

**Do not hardcode a test count anywhere you might paste into a future session or doc.** The number
changes every milestone as tests are added — stale baselines have caused real confusion multiple
times in this project's history (a `103` figure that was stale by 15 tests; a `323/322` result that
didn't reproduce). Instead: **run the suite first and record the actual totals** before making
changes, then compare after. Any new failure, or any drop in the total test count, is a regression.
The one standing exception is `test_property_21_lod_distance_transitions` — no ocean LOD system
exists yet (M10 scope as of this writing), a real tracked gap, not a regression, until M10 closes
it.

New tests must go **flat under `tests/`** — GUT's `-gdir=res://tests` does not recurse into
subdirectories in this project.

---

# Architecture rules (from `AGENTS.md` — non-negotiable, repeated here because they're the ones
most often broken mid-implementation)

- **Never duplicate systems.** Search before you build.
- **Data-driven balance.** Gameplay values live in `.tres` `Resource` files. `@export`ed fields on
  the `.gd` script define the schema. A `.tres` setting a property the script does not `@export`
  **fails silently** — this has caused real bugs (`docs/05_CURRENT_SYSTEMS.md` D3/D14). Always
  check the script's real exported properties first.
- **Composition over inheritance.** New behavior becomes a focused component hung off the existing
  controller, not a deeper class hierarchy.
- **Signals over direct references.** Prefer connecting to an existing signal over adding a new
  direct call path.
- **Persistence convention.** New persistent state exposes `get_save_data()` / `load_save_data()`
  for `SaveManager` to round-trip. Do not invent a new persistence path.

# Things in this codebase that have broken before — do not regress them

These are not hypothetical; each was a real defect that cost real debugging time.

1. **Ship stability.** The buoyancy/stability-torque/yaw-servo code in `BuoyancySimulator.gd` and
   `ShipMovement.gd` was stabilized across **four separate root causes**
   (`docs/09_VISUAL_BUG_TRACKER.md` V1). The yaw servo deliberately preserves roll and pitch.
   Regressing it re-capsizes every enemy ship. Do not touch this code unless a task explicitly says
   to.
2. **Cannon firing direction** derives forward from the **hull basis**
   (`parent.global_transform.basis.x`), not from marker rotation. A bug across all 12 markers on
   all 3 ship scenes was fixed exactly this way. Do not revert it.
3. **Enemy obstacle avoidance** (`_get_avoidance_turn`/`_probe`/`_push_to_open_water` in
   `EnemyAI.gd`) is what stops enemy ships beaching themselves on islands (D39). Do not modify or
   bypass it.
4. **`tests/test_ship_combat.gd`** is the compatibility guard on the `ShipDamage` migration. It
   must keep passing **unmodified**. If it fails, the migration is wrong — fix the migration, never
   the test.
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
   used to write `"player": {}` whenever `save_game()` ran with no `player_ship` in the tree, and
   `load_game()` couldn't tell that apart from a real empty section — it defaulted the ship's
   position to `Vector3(0, 1, 0)`, silently teleporting the ship into the home island's collision
   on load (D64). Any optional save section needs the same discipline: omit the key entirely when
   there's nothing to write, and check for a specific expected field before trusting a default.
9. **New chapter-specific content needs a chapter gate, not just a `.tres` file.** Chapter 4/5's
   dedicated bosses were fully authored but had no in-world trigger at all — neither chapter was
   actually completable (D65). If new content is meant to appear only during a specific chapter,
   wire it through `CampaignManager.is_chapter_current()` (or the equivalent gate) before
   considering the content "done."
10. **A HUD element's position relative to a sibling panel needs a real structural guarantee, not
    two independently-hardcoded pixel offsets.** `WorldHUD`'s notoriety label and the resource bar
    each had their own hand-typed offset meant to keep them apart; they drifted back into overlap
    (D36 reopened 2026-08-26) with no code change in between that would explain it. Prefer
    container-driven layout (stacking in a shared `VBoxContainer`) over two constants that have to
    be kept in sync by convention.

## What cannot be verified in this environment

Manual/visual/feel behavior that genuinely needs a human hand at the controls or a real device:
camera *feel* (not just camera position, which the capture harness can show), gamepad input feel,
building-model visual changes' aesthetic quality, HUD legibility on a real screen size, timed
offline-return prompts experienced in real time, audio (this project has 0 audio files as of
2026-08-26 — even once SFX exist, "does it sound right" needs a human ear), and anything requiring
an actual Android device (touch target feel, on-device frame rate, notification permission flow).
**Say so explicitly rather than claiming a check passed that wasn't actually possible in this
environment.** There is repeated precedent for this honesty across this project's milestone specs
— keep it up.

## When you change a documented system

Update its entry in `docs/05_CURRENT_SYSTEMS.md` **in the same change** (Rule 6). That file is the
living ground-truth doc and exists specifically to stop systems from being silently reimplemented.

---

# Starting the next milestone

When a milestone's final checkpoint has passed:

1. Use the `spec-new` skill to scaffold the next milestone's
   `.kiro/specs/milestone-mN-<slug>/{requirements,design,tasks}.md`, per `docs/15_MASTER_PLAN.md`'s
   roadmap — six milestones (M9–M14) are already scaffolded as of 2026-08-26; confirm which is
   actually next and whether its spec needs a scope re-check against the then-current
   `docs/05_CURRENT_SYSTEMS.md` before starting (every M9–M14 `tasks.md` says this explicitly at
   the top).
2. Add any new "has broken before" hazard discovered during the completed milestone to this
   document's list above (D64/D65 and D32/D36 were both added this way).
3. Add the completed milestone's own condensed entry to `docs/16_MILESTONE_HISTORY.md`.

---

# What this replaced

Through 2026-08-25, this project used a two-agent split: Claude Code planned and reviewed, while
Antigravity/Gemini implemented one small task per session, halting at every checkpoint for Claude
to independently re-verify. `docs/08_PROMPT_LIBRARY.md` held the copy-paste prompts that drove
those Gemini sessions and has been deleted — its reusable content (verification commands, the
fragile-areas list, baseline discipline) was folded into this document above; its Gemini-specific
mechanics (the master prompt, the Antigravity "Operating Contract," per-task prompt templates) had
no equivalent need once there was no longer a second agent to brief. The `gemini-prompt` skill,
which generated those prompts on demand, was deleted for the same reason. Historical references to
Gemini/Antigravity elsewhere in `docs/05_CURRENT_SYSTEMS.md` (e.g. the M3 stabilization pass's
"wrong on Gemini's side" note) are accurate historical record of that era and are left as-is — only
this document, and anything describing *current or future* workflow, needed to change.

The `checkpoint-reviewer` subagent and the discipline in Rules 3/4/8 above are **not** retired —
they were never really about Gemini specifically. They were about not trusting a self-report,
which is exactly as necessary with one agent as with two, per this document's own list of failures
above (most of which involved no handoff at all).
