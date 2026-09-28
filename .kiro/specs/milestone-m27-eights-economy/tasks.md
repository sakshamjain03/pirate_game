# Implementation Plan: Milestone M27 — Timers & the Eights Economy

## Overview

Depends on M25 Checkpoint B (`db05810`). Read `docs/05_CURRENT_SYSTEMS.md` (Economy, Islands,
Store/Entitlements, M25 Eights), `docs/17_MONETIZATION.md` §1/§3, `AGENTS.md`'s monetization
section and this spec's `design.md` before Task 1.

**Runs in parallel with M26 and M28** — see Notes for file ownership. Work in its own worktree
(`git worktree add ../pg-m27 -b m27-eights-economy`), rebase on `main` before each checkpoint.

**Verification command:**
```
.godot-tools/Godot_v4.3-stable_win64_console.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
Baseline entering this milestone (2026-09-29, post-M25): **121 scripts, 828 tests, 828 passing.**

## Tasks

- [ ] 1. `ScheduleManager` autoload — jobs, `start_job`/`remaining`/`finish_now`/`finish_cost_eights`, completion guard (World loaded or `game_loaded`), idempotency record, `now_offset`, `schedule` save section (omitted when empty)
  - **Verify:** `tests/test_schedule_manager.gd` — a job completes once when time passes; a save/load round-trip with a finished job completes it exactly once; duration 0 completes immediately; no `schedule` key in a fresh save.
  - _Requirements: 1.1-1.5_
- [ ] 2. `EconomyPricingData` + `resources/balance/EconomyPricing.tres`; duration exports on `BuildingData`, `TechData`, `ShipStats` (default 0)
  - **Verify:** `effective_duration()` strictly decreases with level for every kind; all existing building/tech/ship `.tres` still load with 0 duration (instant).
  - _Requirements: 2.5, 3.1, 3.2, 3.3_
- [ ] 3. Timed building — `Island` build/upgrade start jobs, `_finish_build`/`_finish_upgrade`, `is_building()`, `get_building_level()`, `structure_completed`; `IslandMenu.structure_changed` re-emitted on completion
  - **Verify:** with a non-zero duration, building is absent until the job completes, then present with its visual; BUILD_STRUCTURE objective completes only on completion; with 0 duration existing island/campaign tests pass unchanged.
  - _Requirements: 2.1, 2.7_
- [ ] 4. Timed research, ships and repair — `TechManager.start_research`, `FleetManager.start_ship_construction`, repair job in `IslandMenu`
  - **Verify:** unlock/add_ship/repair happen on completion only; a second research job is refused; passive DockingSystem repair test unchanged.
  - _Requirements: 2.2, 2.3, 2.4, 2.7_
- [ ] 5. **Checkpoint A** — full suite, `checkpoint-reviewer` on Tasks 1-4, commit+push.
- [ ] 6. Eights sinks — `finish_now` pricing, `ResourceManager.shortfall`/`shortfall_cost_eights`/`cover_shortfall_and_spend`, `EightsConfirmDialog`, job rows (remaining + bar + Finish now) and Cover buttons in IslandMenu
  - **Verify:** `tests/test_eights_sinks.gd` — cost from remaining not total; min 1; refusal spends nothing; cover is atomic; refused when it would clamp at storage cap; refused for Eights costs.
  - _Requirements: 2.6, 4.1-4.4, 5.1-5.5_
- [ ] 7. Store consumables — `ProductData.grants_eights`, `IStoreBackend.consume`, stub implementation, Play TODO, `StoreManager` consumable branch + persisted order ids, 4 packs, StoreScreen Eights section, HUD Eights chip
  - **Verify:** `tests/test_eights_store.gd` — a stub purchase grants once; the same `order_id` delivered twice grants once; restore never grants; existing cosmetic/entitlement store tests unchanged.
  - _Requirements: 6.1-6.6_
- [ ] 8. Author durations on Ch1-5 path content; zero-spend gate tests; DevConsole economy tab
  - **Verify:** `tests/test_zero_spend_gate.gd` — no required cost contains Eights; every Ch1-2 required job is under the cap at the level those chapters reach; `tests/test_no_shipping_reference_to_debug.gd` still passes.
  - _Requirements: 7.1-7.3_
- [ ] 9. Docs — `docs/05_CURRENT_SYSTEMS.md` M27 section (own section only), `docs/17_MONETIZATION.md` pack table + pricing formula + consumable model, `docs/04_GAME_LOOP.md` timer beat
  - **Verify:** `sync-systems-doc` reports nothing undocumented for the files above.
- [ ] 10. **Checkpoint B (final)** — rebase on `main`, full suite, `checkpoint-reviewer`, headful capture of IslandMenu job rows, confirm dialogs and store Eights section reviewed, commit+push.

## Notes

- **Parallel with M26/M28 (user decision, 2026-09-29).** File ownership:
  - **M27 owns:** `ScheduleManager.gd`, `Island.gd`, `IslandMenu.gd`, `TechManager.gd`,
    `FleetManager.gd`, `ResourceManager.gd`, `BuildingData.gd`, `TechData.gd`, `ShipStats.gd`,
    `StoreManager.gd`, `StoreScreen.gd`, `scripts/core/*StoreBackend*`, `ProductData`,
    `DevConsole.gd`, `resources/store/*`, `resources/buildings|techs|ships/*` duration fields,
    `resources/balance/EconomyPricing.tres`.
  - **Shared, additive only:** `project.godot` (one autoload line), `SaveManager.gd` (M26 also
    adds `maelstrom`), `WorldHUD.gd` (M28 adds a lesson hook), `docs/05`/`docs/17` (own section).
  - **Contract M28 depends on:** `ScheduleManager.job_started(job: Dictionary)` with `job.kind`.
    M28 authors a timer lesson against it, gated off until this lands. Don't rename it.
- **Task 3 is the risky one.** Moving "building exists" from payment time to completion time
  changes what `structure_changed` means to `CampaignManager`. Grep every subscriber first.
- **This must not become an energy system.** Nothing here may gate sailing, combat, boarding,
  encounters or the Maelstrom. If a reviewer can't tell a timer from a stamina meter, it's wrong.
- **Not verifiable here:** real Play Billing, whether the durations feel fair, on-device
  notification when a job completes (`LocalNotificationManager.schedule_completion()` exists —
  wiring it is a stretch goal, not a requirement).

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2"] },
    { "id": 1, "tasks": ["3", "4"] },
    { "id": 2, "tasks": ["5"] },
    { "id": 3, "tasks": ["6", "7"] },
    { "id": 4, "tasks": ["8", "9"] },
    { "id": 5, "tasks": ["10"] }
  ]
}
```
