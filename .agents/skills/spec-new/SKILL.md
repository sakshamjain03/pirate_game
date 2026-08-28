---
name: spec-new
description: Scaffold a new milestone spec (.kiro/specs/milestone-mN-<slug>/{requirements,design,tasks}.md) in this project's established format. Use when starting a new milestone after the previous one's final checkpoint has passed.
---

# New Milestone Spec

Scaffolds a new `.kiro/specs/milestone-<slug>/` spec (`requirements.md`, `design.md`, `tasks.md`)
in the shape this project's milestones use, so a new milestone doesn't reinvent structure or
accidentally drop a section the `checkpoint-reviewer` agent expects to find. This project is built
entirely by Codex (see `docs/07_AI_AGENT_WORKFLOW.md`) — these specs are read and implemented
directly, not handed off to a second agent.

M1 through M7 (and M8's ad-hoc combat rework) are done; their detailed spec files were
consolidated into `docs/16_MILESTONE_HISTORY.md` and removed from the tree to keep this project's
docs from becoming context noise for future agents — recoverable from git history if the full
play-by-play is ever needed. `.kiro/specs/milestone-m7.5-stabilization/` is the most recent
still-on-disk example of the shape below (a small stabilization spec, not a full feature
milestone with waves/checkpoints — read it for tone and the requirements/design/tasks split, but
don't expect wave structure there).

## Before writing anything

1. Read `docs/05_CURRENT_SYSTEMS.md` in full — a new milestone's requirements/design must extend
   what's already built, never duplicate it (per `agents.md`: "Never duplicate systems").
2. Read `docs/16_MILESTONE_HISTORY.md`'s entry for the most recently completed *full* milestone
   (not M7.5) for what that milestone covered and how it was scoped, and
   `.kiro/specs/milestone-m7.5-stabilization/` for the live structural reference — match the
   section shape below, not just the general vibe.
3. Confirm the prior milestone's final checkpoint has actually passed (check
   `docs/05_CURRENT_SYSTEMS.md`/`docs/16_MILESTONE_HISTORY.md` for a closing summary, or ask the
   user) before scaffolding the next one — this project's milestones are explicitly sequential,
   never parallel-started per Rule 8 in `docs/07_AI_AGENT_WORKFLOW.md`. Six milestones
   (`milestone-m9-presentation-pass` through `milestone-m14-live-operations`) are already
   scaffolded as of 2026-08-26 — check `.kiro/specs/` before assuming a new one is needed; the
   next likely task is implementing an already-scaffolded milestone, not creating another.

## Directory and naming

`.kiro/specs/milestone-m<N>-<short-slug>/`, continuing the existing numbering — see
`docs/16_MILESTONE_HISTORY.md` for every completed milestone and `docs/15_MASTER_PLAN.md`'s
roadmap (currently M9–M14) for what's already scaffolded. Confirm the number/slug with the user if
not obvious from context.

## `requirements.md` shape

```markdown
# Requirements Document

## Introduction

<1-2 paragraphs: what gap(s) this milestone closes, referencing the specific AGENTS.md pillar or
docs/05_CURRENT_SYSTEMS.md "Known gaps" entry it targets. State explicitly what is already met
and needs no further work — don't leave it implicit (see `docs/16_MILESTONE_HISTORY.md` for how
past milestones scoped this).>

## Glossary

<Any new terms this milestone introduces, defined precisely, even if there's only one term worth
defining — an ambiguous term used loosely across requirements/design/tasks is how scope drifts.>

## Requirements

### Requirement 1: <name>

**User Story:** As a <role>, I want <goal>, so that <benefit>.

#### Acceptance Criteria

1. <WHEN/IF/ON ... THE ... SHALL ...> — EARS-style, testable, one behavior per line.
2. ...

<repeat per requirement>

## Out of Scope

<Explicit list of adjacent things this milestone deliberately does NOT do, and why — never leave
this implicit, it's how scope creep starts.>
```

## `design.md` shape

```markdown
# Design Document: Milestone M<N> — <Name>

## 1. Why this design shape

<State the guiding principle — almost always "extend an existing system, don't add a new one,"
per agents.md. Name the specific existing file(s)/pattern being reused.>

## 2. New/changed files

| File | Change |
|------|--------|
| ... | ... |

## 3+. One section per non-trivial mechanism

<Exact formulas, exact integration points (which function, called from where, in what order),
exact field names — real code snippets showing the integration point, not just prose
description. Call out any known hazard explicitly (e.g. "this signal has another subscriber
with a side effect that must not be replayed" — the kind of thing that's obvious once you've
grepped for it and invisible if you haven't).>
```

## `tasks.md` shape

```markdown
# Implementation Plan: Milestone M<N> — <Name>

## Overview

<Dependency on the prior milestone's checkpoint, one line, plus a pointer to read
docs/05_CURRENT_SYSTEMS.md and this spec's design.md before Task 1.>

## Tasks

- [ ] 1. <Title>
  - <One or more implementation bullets, concrete enough that Rule 1's "1-2 files" sizing test
    holds — if a task needs a paragraph of design decisions, that decision belongs in design.md,
    not invented here.>
  - **Verify:** <one exact, mechanical, runnable/observable step — never "make sure it works.">
  - _Requirements: <IDs from requirements.md>_

<repeat, inserting explicit "Checkpoint" tasks after every 6-10 tasks — never let a milestone run
past ~10 tasks without one>

## Notes

<Anything genuinely risky, called out explicitly rather than left for the implementer to
discover mid-task, or which task groups are independent/parallelizable.>

## Task Dependency Graph

​```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "..."] }
  ]
}
​```
```

## Sizing discipline while drafting tasks

Every task must satisfy Rule 1 from `docs/07_AI_AGENT_WORKFLOW.md` before it's written down: a
small, explicitly-named set of files, one mechanical Verify step, explicit Requirement IDs. If a
feature doesn't decompose that small, that's a sign it needs its own `design.md` subsection first,
not a vaguer task. Actually check each drafted task against this shape rather than writing a list
that "looks complete" — sizing tasks correctly up front is what keeps a long implementation session
from drifting.

## After scaffolding

Implement directly against the scaffolded `requirements.md`/`design.md`/`tasks.md`, one task at a
time, per `docs/07_AI_AGENT_WORKFLOW.md`. Do not leave `requirements.md`/`design.md` as
placeholders — they should already hold real content before `tasks.md` is written, since tasks are
implemented straight from them.
