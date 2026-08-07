# 07_AI_AGENT_WORKFLOW.md

> Version: 1.0
> Status: Living Document
> Owner: Project Lead

---

# Purpose

This project uses two different AI coding agents for two different jobs. This document defines
the division of labor and the rules that make it work.

- **Antigravity / Gemini 3.1 Pro** — the primary code-writing workhorse. Strong at producing a
  correct, small, well-scoped chunk of code from a precise spec. Not to be trusted with
  large multi-file refactors, architecture decisions, or "figure out the best approach" work —
  it will produce *something* plausible-looking, but without a human/Claude review pass, drift
  and silent scope creep compound across a session.
- **Claude Code** — planning, spec-writing, review, integration verification, and fixing what
  Gemini gets wrong. Reads the whole codebase, writes/maintains the `.kiro/specs/*` documents,
  runs the actual game to verify behavior, and reviews every checkpoint before the next phase of
  Gemini work starts.

The failure mode this document exists to prevent: handing Gemini a big, ambiguous milestone,
getting back a large diff that "looks done," and discovering three sessions later that it
duplicated an existing system (`AGENTS.md`'s explicit warning), silently changed an unrelated
file, or claimed a test passed without running it.

---

# Rule 1: One task, one Gemini turn

Every unit of work handed to Gemini must already be broken down into a numbered task in a
`.kiro/specs/<milestone>/tasks.md` file, sized so that it:

- Touches at most 1–2 files (occasionally 3 for tightly-coupled scene+script pairs).
- Has a single, mechanical, explicitly-stated verification step (not "make sure it works" —
  an exact command to run or an exact in-game action to perform and what to observe).
- Cites the exact requirement IDs it satisfies, traceable back to `requirements.md`.

If a task doesn't fit this shape, it is not ready to hand to Gemini — split it further in
`tasks.md` first. This is Claude Code's job, not Gemini's: Gemini should never be asked to size
its own work.

# Rule 2: Read before write

Every Gemini prompt must point at, in order:
1. `agents.md` — the repository's non-negotiable rules.
2. `docs/05_CURRENT_SYSTEMS.md` — what already exists. Gemini must not re-implement anything
   described there; it must extend it.
3. The specific milestone's `requirements.md` → `design.md` → `tasks.md`.

See `docs/08_PROMPT_LIBRARY.md` for the exact copy-paste prompts that enforce this.

# Rule 3: Gemini stops after one task; it does not self-chain

Never instruct Gemini to "do all the tasks in this milestone" in one session. Each prompt
executes exactly one task and then stops, reporting: which files it changed, the literal output
of the verification step it ran, and anything in the codebase that didn't match what the spec
assumed (e.g., "the file described in design.md doesn't have the field the task expects").

This is what makes review tractable — a human or Claude Code can review one small diff per
checkpoint instead of untangling a multi-task session after the fact.

# Rule 4: Checkpoints are reviewed by Claude Code, not skipped

Every `tasks.md` in this project includes explicit "Checkpoint" tasks (see
milestone-m3-stabilization Task 9/15/21, milestone-m4-empire-escalation Task 11/14/22). At each
checkpoint:

1. Claude Code (or a human) reviews every file Gemini touched since the last checkpoint.
2. Claude Code actually runs the verification steps Gemini claimed to run — `godot --headless
   --check-only`, the GUT test suite, and a manual play pass for anything visual/feel-based.
3. Any defect found is fixed before the next phase starts — do not let broken checkpoints
   accumulate on the assumption "it'll get fixed later."
4. Only after a checkpoint passes does work proceed to the next wave of tasks.

# Rule 5: Never let Gemini invent architecture

If a task requires a design decision not already made in `design.md` (a new class, a new
signal, a new resource schema, a new autoload), that decision belongs in the spec, written by
Claude Code (with the user's input where it's a product decision), before the task is handed to
Gemini. Gemini's job is implementation against an already-decided design, not design itself —
per `agents.md`: *"Never invent architecture."*

If Gemini reports back that a task's assumptions don't hold (e.g., a referenced file doesn't
have the expected shape), that is a signal to pause and fix the spec, not to let Gemini
improvise a resolution.

# Rule 6: Documentation is updated in the same pass as the code

Every milestone's final checkpoint task includes updating `docs/05_CURRENT_SYSTEMS.md` to
reflect what was actually built. This is not optional cleanup — it is the mechanism that
prevents the exact problem this project already hit once (a large commit that added most of the
game's actual systems with zero corresponding documentation, discovered only by a full codebase
audit). Skipping this step recreates that problem every milestone.

---

# Rule 7: Verify with the GUT suite, not `--check-only`

`godot --headless --path . --check-only` does not reliably exit on its own in this project on
Godot 4.3 — with `run/main_scene` configured, it boots into real gameplay and then idles forever
instead of quitting, which produces false "hangs" and orphaned processes if you wait on it or
poll it. Use `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` instead — it
calls `-gexit` and reliably terminates, and it already proves every test script parses correctly
(GUT cannot run tests from a script that fails to compile), which covers what `--check-only` was
being used for anyway. When verifying a single fix rather than a whole milestone, target the
specific file with `-gtest=res://tests/<file>.gd` instead of the whole `-gdir` — much faster.

Always launch long-running verification commands with proper background execution and wait for
the actual completion signal — do not manually poll with sleep loops, and do not assume a command
"hung" and kill it without checking whether something else (another leftover process from an
earlier attempt) is the actual problem. Check for stray processes before starting a new run.

# Rule 8: Checkpoints must survive concurrent work

If another Antigravity/Gemini session is running milestone N+1 work while milestone N's
checkpoint is still being reviewed, the checkpoint reviewer is verifying a moving target — new
files can appear mid-review, test discovery can shift, and cross-test state pollution becomes
possible. Do not start a new milestone's Task 1 until the prior milestone's final checkpoint has
been reported as passing, even if the tools make it easy to keep going in parallel.

# How this maps to Antigravity in practice

Antigravity sessions with Gemini should be short-lived: one task in, one verified result out.
Use `docs/08_PROMPT_LIBRARY.md`'s ready-made prompts — paste the task's prompt, let Gemini work,
then bring the diff back to a Claude Code session (or a human review) before pasting the next
task's prompt. Do not queue up multiple tasks in a single Antigravity conversation.
