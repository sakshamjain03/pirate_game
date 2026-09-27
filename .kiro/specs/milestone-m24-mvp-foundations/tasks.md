# Implementation Plan: Milestone M24 — MVP Foundations

## Overview

**Status: COMPLETE (2026-09-28).** Commits `6c8c820` (tasks 1-6) and `a137563` (task 8).

Foundation pass for the freemium-mobile MVP: decide what ships, rewrite the rules that forbade the
business model, and add the tooling later milestones need. No gameplay behaviour changed.

Read `AGENTS.md`, `docs/00_VISION.md` §19 and this spec's `design.md` before Task 1.

**Verification command:**
```
.godot-tools/Godot_v4.3-stable_win64_console.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
The engine binary is gitignored and lives in `.godot-tools/` — **not** the project root and not on
PATH, despite what `CLAUDE.md` says. Use the `_console` variant; output buffers until exit, so an
empty log mid-run does not mean it hung.

Baseline entering this milestone (measured clean, 2026-09-28): **115 scripts, 756 tests, 756
passing, 0 failing.** The "one accepted failure"
(`test_property_21_lod_distance_transitions`) still cited in `AGENTS.md`/`CLAUDE.md` is **stale** —
`docs/05_CURRENT_SYSTEMS.md` §0 already says the suite has had zero known failures since M10. Any
failure is a regression.

Exit state: **117 scripts, 767 tests, 767 passing.**

## Tasks

- [x] 1. Amend the constitution — `AGENTS.md` monetization rules + PR checklist (monetization gate rewritten, dev-tools gate added); `docs/00_VISION.md` §19 acceptable list, §19.1 rewritten, new §19.2 limits; `docs/17_MONETIZATION.md` §1/§3/§7
  - **Verify:** the three documents agree; each §19.2 limit is individually checkable by a reviewer.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
- [x] 2. `ResourceLookup.is_content_enabled()` + `content_enabled` export on `ChapterData`, `CaptainData`, `RegionData`, `IslandData`
  - **Verify:** defaults true; a resource type without the field still loads.
  - _Requirements: 2.1, 2.2_
- [x] 3. Wire the filter into every loader — `CampaignManager._load_chapters()`, `EmpireManager` regions, `WorldMapScreen`, `CodexScreen`, `IslandMenu` tavern list; `Island._ready()` frees gated islands before `add_to_group()`
  - **Verify:** no loader of the four gated types bypasses the filter; `World.tscn` untouched.
  - _Requirements: 2.3, 2.4, 2.5_
- [x] 4. Author `content_enabled = false` on 20 resources — 6 islands, 4 chapters, 2 regions, 8 captains
  - **Verify:** one-line diff per `.tres` (no line-ending churn); `[resource]` is the last section in each so the property lands in the right block.
  - _Requirements: 2.6_
- [x] 5. Rewrite `test_world_position_matches_the_scene_transform` onto authored `SceneState`; add `test_deferred_islands_are_gated_and_shipping_islands_are_not`
  - **Verify:** all 11 authored islands still checked, not 5 — the assertion must not be weakened to go green.
  - _Requirements: 2.9_
- [x] 6. Dev console — `scripts/debug/DevConsole.gd`, `scenes/debug/DevHarness.tscn`, `tests/test_no_shipping_reference_to_debug.gd`, `export_presets.cfg` exclude filter, `RELEASE_CHECKLIST.md` §4 step
  - **Verify:** guard test passes; console loads and instantiates (nothing imports it, so the suite would otherwise miss a parse error).
  - _Requirements: 3.1-3.8_
- [x] 7. **Checkpoint A** — full suite, `checkpoint-reviewer`, commit+push. *(Commit `6c8c820`; reviewer found the Task 8 defect.)*
- [x] 8. **Fix the checkpoint finding** — Ch4 4.1/4.7 and Ch5 5.1 retargeted to shipping islands; add `tests/test_content_gate_integrity.gd`; document in `docs/05` and `docs/13`
  - **Verify:** prove the new guard **fails** by re-introducing the `frozen_island` reference, then restore. A green test that cannot go red is not a guard.
  - _Requirements: 2.7, 2.8_
- [x] 9. **Checkpoint B (final)** — full suite 767/767, `checkpoint-reviewer` PASS, commit+push. *(Commit `a137563`.)*

## Notes

- **Checkpoint record (2026-09-28).** Checkpoint A shipped a real defect: gating six islands left
  three mandatory objectives in Ch4/Ch5 pointing at gated islands, making **both chapters
  uncompletable**. The full 762-test suite passed straight through it; `checkpoint-reviewer` caught
  it. This is the strongest available argument for not skipping that pass because "the diff looks
  done". Fixed in Task 8; Checkpoint B PASS on all seven criteria.

- **One test rewritten, deliberately:** `test_world_position_matches_the_scene_transform` changed
  mechanism (instantiation to `SceneState`) rather than expectation. Weakening it to expect 5
  islands would have let deferred island layouts rot while gated.

- **Deferred out of this milestone:** `resources/balance/DifficultyCurve.tres` had no reader until
  combat consumes it, and `AGENTS.md` forbids dead code. Moved to M25.

- **Not verified, stated rather than claimed:** nobody has pressed F1 and exercised the console's
  cheats. It parses, instantiates, and its harness scene loads — all under test — but actual
  interaction needs a headful run. No visual verification was needed otherwise: this milestone
  changed no rendering.

- **Concurrent-session hazard:** another session committed `db16705` to this repo mid-milestone.
  Staging was kept to explicit paths throughout; never `git add -A` here.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2"] },
    { "id": 1, "tasks": ["3", "4"] },
    { "id": 2, "tasks": ["5", "6"] },
    { "id": 3, "tasks": ["7"] },
    { "id": 4, "tasks": ["8", "9"] }
  ]
}
```
