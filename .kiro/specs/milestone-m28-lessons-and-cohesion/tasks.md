# Implementation Plan: Milestone M28 — Lessons & Campaign Cohesion

## Overview

Depends on M25 Checkpoint B (`db05810`). Read `docs/05_CURRENT_SYSTEMS.md` (Campaign,
TutorialManager), `docs/13_CAMPAIGN_LEVELS_1-5.md` and this spec's `design.md` before Task 1.

**Runs in parallel with M26 and M27** — see Notes for file ownership. Work in its own worktree
(`git worktree add ../pg-m28 -b m28-lessons`), rebase on `main` before each checkpoint.

**Verification command:**
```
.godot-tools/Godot_v4.3-stable_win64_console.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
Baseline entering this milestone (2026-09-29, post-M25): **121 scripts, 828 tests, 828 passing.**

## Tasks

- [ ] 1. Fix `TutorialManager._UNLOCK_ON_OBJECTIVE` to point at the objectives it describes (recruit = 1.8, combat = 1.6); confirm against `docs/13` §3
  - **Verify:** new test — completing Ch1's recruit objective unlocks `tab_fleet`, its combat objective unlocks `tab_research`; building the tavern unlocks neither.
  - _Requirements: 2.5_
- [ ] 2. `LessonData` + `ChapterData.lessons`; `TutorialManager` `lessons_enabled`, seen set, `mark_seen`/`has_seen`/`replay_lessons`, save data (old saves default to enabled)
  - **Verify:** `tests/test_lessons.gd` — seen set round-trips; a save without the new keys loads enabled with nothing seen.
  - _Requirements: 1.1, 1.2, 1.4, 3.4_
- [ ] 3. `CampaignManager` lesson firing — `_fire_trigger`, `lesson_requested`, all `Trigger` sources incl. optional `ScheduleManager.job_started`; unknown lesson id `push_error`s
  - **Verify:** a lesson fires once for its trigger in its chapter, never in another chapter, never when disabled; with no `ScheduleManager` autoload the suite shows no error.
  - _Requirements: 1.3, 1.5, 4.1, 4.2_
- [ ] 4. `LessonCoachCard` — non-modal, queued, waits for `TutorialDialogue.is_blocking()`, highlight pulse, placed in HUD container layout
  - **Verify:** showing a lesson does not set `get_tree().paused`; two lessons queue; a blocking dialogue defers the card; headful capture shows it clear of the dialogue and resource bar.
  - _Requirements: 1.6_
- [ ] 5. **Checkpoint A** — full suite, `checkpoint-reviewer` on Tasks 1-4, commit+push.
- [ ] 6. New `ObjectiveData.Condition` values (appended) and their tracking in `CampaignManager`
  - **Verify:** `tests/test_new_objective_conditions.gd` — each condition progresses from its signal and only while its chapter is current; `SWAP_AMMO` ignores load-time `set_ammo`; every existing chapter `.tres` still resolves the same condition for every existing objective (compare ints before/after).
  - _Requirements: 2.2, 2.3, 2.4_
- [ ] 7. Author content — ~20 lessons, the new objectives in Ch1-4 (appended ids), hand-off lines between chapters
  - **Verify:** `tests/test_campaign_coverage.gd` — the coverage table: every system has ≥1 lesson and ≥1 objective in Ch1-5 (timers marked pending until `ScheduleManager` exists; Maelstrom lesson-only); every new objective is reachable; `test_content_gate_integrity.gd` passes.
  - _Requirements: 2.1, 2.6_
- [ ] 8. Skip / replay — New Game prompt in `MainMenu`, "Replay lessons" in `SettingsMenu`
  - **Verify:** "I know these waters" → no lesson fires during a scripted Ch1, all tabs unlocked, Ch1 objectives still complete and grant rewards; "Replay lessons" re-enables.
  - _Requirements: 3.1, 3.2, 3.3_
- [ ] 9. Docs — `docs/13_CAMPAIGN_LEVELS_1-5.md` final objective + lesson list per chapter, `docs/05_CURRENT_SYSTEMS.md` M28 section (own section only)
  - **Verify:** `sync-systems-doc` reports nothing undocumented for the files above.
  - _Requirements: 2.6_
- [ ] 10. **Checkpoint B (final)** — rebase on `main`, full suite, `checkpoint-reviewer`, headful capture of a lesson card + the New Game prompt reviewed, commit+push.

## Notes

- **Parallel with M26/M27 (user decision, 2026-09-29).** File ownership:
  - **M28 owns:** `LessonData.gd`, `ChapterData.gd`, `ObjectiveData.gd`, `CampaignManager.gd`,
    `TutorialManager.gd`, `TutorialDialogue`, `LessonCoachCard`, `SettingsMenu.gd`,
    `resources/campaign/**`, `docs/13`.
  - **Shared, additive only:** `MainMenu.gd`/`.tscn` (M26 adds a Maelstrom button),
    `WorldHUD.gd` (M27 adds an Eights chip), `docs/05` (own section only).
  - **Read-only dependency on others:** signals only — `ShipCombat.ammo_changed` (on `main`
    since M25 Checkpoint B), `ScheduleManager.job_started` (M27; optional until it lands),
    `EnemySpawner.enemy_spawned` (exists; M26 edits the file but not that signal).
- **When M27 merges:** un-pend timers in the coverage test and confirm the timer lesson fires.
  That's part of the joint wrap-up check, not this milestone's checkpoint.
- **`Condition` and `Trigger` are int-serialized.** Append only. Task 6's verify step exists
  because inserting one value would silently re-target every objective after it.
- **Don't renumber objective ids.** Saves and `TutorialManager` reference them by string.
- **Not verifiable here:** whether the lessons are *well-timed* for a real new player, and
  touch feel of the coach card on a phone.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2"] },
    { "id": 1, "tasks": ["3", "4"] },
    { "id": 2, "tasks": ["5"] },
    { "id": 3, "tasks": ["6"] },
    { "id": 4, "tasks": ["7", "8"] },
    { "id": 5, "tasks": ["9", "10"] }
  ]
}
```
