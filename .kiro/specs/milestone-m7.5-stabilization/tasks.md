# Implementation Plan — M7.5 Stabilization Pass

> **Read before starting:** `docs/05_CURRENT_SYSTEMS.md`'s "M7.5 Stabilization Pass" section and
> this spec's `design.md` — both describe the same two defects (D64/D65) in full.
>
> **Verification command:**
> ```
> <godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
> ```
> Baseline entering this milestone: **320 tests, 319 passing, 1 known failure**
> (`test_property_21_lod_distance_transitions`).

---

## Tasks

- [x] 1. Diagnose the black-viewport bug via a real headful run
  - Done 2026-08-25. Ran `scenes/debug/CaptureHarness.tscn` headful (no `--headless`) with zero
    input; the 3D viewport rendered correctly at t=0/1/3s and went solid black from ~t=4s onward
    while the HUD kept updating normally. Temporarily instrumented `ScreenshotCapture.gd` with
    diagnostic prints (active camera, `WorldEnvironment`/sky/ambient state, day/night controller
    state, `CameraRig` target/position/pitch, tracked ship position/freeze/velocity) — every
    lighting/camera-target value was healthy the entire time; only the ship's actual
    `global_position` didn't match its scene-authored spawn. Found a stale `user://save_data.json`
    with `"player": {}`, confirming `SaveManager.load_game()`'s position-default path
    (`Vector3(0, 1, 0)`, which is Port Royal's own origin post-M7) as the root cause. Reverted the
    temporary instrumentation once confirmed — `ScreenshotCapture.gd` is back to its original form.
  - _Requirements: 1.4_

- [x] 2. Fix `SaveManager` save/load player-position handling (D64)
  - Done 2026-08-25. `save_game()` no longer writes a `"player"` key when no `player_ship` exists
    in the tree (was an always-present, sometimes-empty `{}`). `load_game()` only restores
    position/rotation when `player_data.has("pos_x")` — missing data now means "leave the ship at
    its scene-authored spawn," not "assume the origin." Re-ran the same headful capture with the
    same previously-corrupting save still on disk: the world now renders normally at t=7s/t=12s
    (ship sailing, full lighting, no camera collapse).
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 3. Add `EncounterData.required_chapter_id` and gate the ambient scheduler (D65)
  - Done 2026-08-25. `required_chapter_id: String = ""` added to `EncounterData.gd`.
    `CampaignManager.is_chapter_current(chapter_id)` added (mirrors `is_chapter_completed()`).
    `EncounterManager._start_random_ambient()` filters `encounter_pool` candidates through it
    before picking one.
  - _Requirements: 2.1, 2.3_

- [x] 4. Wire both chapter bosses into the ambient pool
  - Done 2026-08-25. `IntransigentBoss.tres.required_chapter_id = "ch4_the_admirals_gambit"`,
    `CardenasBoss.tres.required_chapter_id = "ch5_the_silver_fleet"`. Both added to `World.tscn`'s
    `EncounterManager.encounter_pool` (`load_steps` header count updated to match the two new
    `ext_resource` entries).
  - _Requirements: 2.2, 2.4, 2.5_

- [x] 5. Tests
  - Done 2026-08-25. `tests/test_encounters.gd` gained:
    `test_chapter_gated_encounter_is_excluded_before_its_chapter`,
    `test_chapter_gated_encounter_is_eligible_once_its_chapter_is_current`,
    `test_both_authored_chapter_bosses_are_gated_to_their_own_chapter`. Extended
    `test_every_authored_encounter_is_loadable_and_coherent`'s path list to include
    `IntransigentBoss.tres`/`CardenasBoss.tres`, which it had never covered despite both already
    existing.
  - _Requirements: 2.6_

- [x] 6. Update documentation
  - Done 2026-08-25. `docs/05_CURRENT_SYSTEMS.md` gained the "M7.5 Stabilization Pass" section
    (D64/D65, root cause, resolution, updated GUT baseline). `docs/14_SYSTEM_INVENTORY.md`'s §0
    test-count snapshot, §6 process table, and a new §7.5 defect table updated to match.
    `docs/15_MASTER_PLAN.md`'s M7 exit-criteria results corrected: the Ch4/Ch5 boss-trigger gap is
    now closed, not an open disclosed simplification.
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 7. **Checkpoint — M7.5 complete**
  - GUT: **323 tests, 322 passing, 1 known failure** (`test_property_21_lod_distance_transitions`),
    up from the 320/319 baseline entering this pass. No regressions.
  - Headful `CaptureHarness` re-verified: 3D world renders correctly through t=12s with the
    previously-corrupting save still present on disk.
  - No stray Godot processes left running; all capture output written to the session scratchpad
    (gitignored), not the repo.

## Notes

- This pass intentionally did **not** re-audit M1–M7's task-doc checkbox/process hygiene — a
  parallel session already did that (M7 itself, the M1/M2 tail, an M5 doc fix), independently
  checkpoint-verified before this milestone started. Re-doing it would have duplicated work.
- The Ch4/Ch5 boss fights still have no *location* — they're a chapter-gated chance in the ambient
  pool, not "sail to Frostbite Reef and it's there" as Chapter 4's own opening beat describes.
  Flagged in `docs/05_CURRENT_SYSTEMS.md` as a follow-up for whichever milestone builds the
  discovery/waypoint system (M9), not built here.

## Checkpoint correction (2026-08-26)

Task 7's recorded "323 tests, 322 passing" was re-verified against a real GUT run rather than
taken on self-report, per this project's own recurring lesson (D15/D42/D57). It did not
reproduce: the actual run measured 323/321. Two real defects were found and fixed — D66
(`CampaignManager._catch_up()` could silently abandon an in-progress chapter, defeating this
milestone's own D65 fix in the exact scenario D65 was written to close) and D67 (a
`ResourceManager` test-isolation leak across `tests/test_encounters.gd`, the same class as this
project's two prior `SaveManager`/`EmpireManager` isolation fixes). Full detail:
`docs/05_CURRENT_SYSTEMS.md`'s "Checkpoint correction" addendum and `docs/14_SYSTEM_INVENTORY.md`
§7.6. Verified baseline after both fixes: **324 tests, 323 passing**, still exactly the one known
LOD failure.
