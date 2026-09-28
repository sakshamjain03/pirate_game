# Implementation Plan: Milestone M26 — The Maelstrom

## Overview

Depends on M25 Checkpoint B (`db05810`). Read `docs/05_CURRENT_SYSTEMS.md` (Combat, M8 encounter
rework, M25) and this spec's `design.md` before Task 1.

**Runs in parallel with M27 and M28** — see Notes for file ownership. Work in its own worktree
(`git worktree add ../pg-m26 -b m26-maelstrom`), rebase on `main` before each checkpoint.

**Verification command:**
```
.godot-tools/Godot_v4.3-stable_win64_console.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
Baseline entering this milestone (2026-09-29, post-M25): **121 scripts, 828 tests, 828 passing.**

## Tasks

- [x] 1. Game mode flag — `SceneManager.GameMode`, `game_mode`, `is_campaign()`
  - **Verify:** new test asserts default is `CAMPAIGN` and `is_campaign()` flips with the flag.
  - _Requirements: 1.2, 1.4_
- [x] 2. Isolation guards — `ShipController._on_died()` (notoriety, `_spawn_loot`) and `LootDrop._collect()` (grant loop) check `SceneManager.is_campaign()`
  - **Verify:** `tests/test_maelstrom_isolation.gd` — killing an enemy with the mode set leaves notoriety and resources unchanged; with the mode unset the old behaviour holds (existing loot/notoriety tests still pass).
  - _Requirements: 2.1, 2.2_
- [x] 3. Data layer — `MaelstromBandData`, `MaelstromCurveData` (`band_at`, `xp_for_level`, `eights_for`), `resources/balance/MaelstromCurve.tres`
  - **Verify:** `tests/test_maelstrom_curve.gd` — `band_at` boundaries incl. 0 and past the last band; `eights_for` sums reached milestones and respects the cap; bands sorted.
  - _Requirements: 3.1, 5.1, 6.2_
- [x] 4. `EnemySpawner.spawn_profile_override`
  - **Verify:** with the override set, `get_active_max_enemies()`/`get_active_spawn_interval()` return the profile; unset, the M25 heat tests pass unchanged; strength still duplicates `ShipStats`.
  - _Requirements: 3.2, 3.5_
- [x] 5. **Checkpoint A** — full suite, `checkpoint-reviewer` on Tasks 1-4, commit+push.
- [ ] 6. `MaelstromRun` core — elapsed, band tracking, boss-at-band-start, kill → drops, pickup routing (plunder/repair/powerup/keg), level queue, `upgrade_offer_requested` + `apply_upgrade_choice`
  - **Verify:** `tests/test_maelstrom_run.gd` — scripted kills produce drops; plunder crossing two thresholds queues two offers shown one at a time; repair calls `repair_pool`; offered choices all pass `can_apply()`.
  - _Requirements: 3.3, 3.4, 4.1, 4.2, 4.3, 5.2, 5.4_
- [ ] 7. Upgrades — new `CombatModifiers` keys (pickup radius, regen, extra projectile, ram damage), new `Effect` values appended at the enum's end, ≥ 12 new `.tres`, pickup magnet
  - **Verify:** every file in `resources/combat/upgrades/` loads as `BattleUpgradeData` with a unique `upgrade_id` (count ≥ 18); each new effect key changes the stat it names; existing 6 upgrade `.tres` still resolve to the same effect.
  - _Requirements: 4.4, 5.3_
- [ ] 8. Run end — results panel, Eights grant, `MaelstromRecord`, `maelstrom` save section (omitted when empty), the explicit end-of-run save **without** writing the Maelstrom ship into the `player` section
  - **Verify:** isolation test snapshots every manager's `get_save_data()` + the `player` section before a scripted run and after `_end_run()`; only `maelstrom` and `economy.eights` differ; a fresh save has no `maelstrom` key.
  - _Requirements: 2.5, 6.1, 6.2, 6.3, 6.4_
- [ ] 9. Scene + entry — `scenes/modes/Maelstrom.tscn` (root `Maelstrom`, `Run/` not `Systems/`, storm wall), Main Menu button, Retry / Main Menu flow resetting the mode
  - **Verify:** a test loads the scene and asserts no `Systems/EnemySpawner` path and root name ≠ `World`; headful capture of the scene at t≈0/3/12 s reviewed.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.3, 2.4_
- [ ] 10. Docs — `docs/05_CURRENT_SYSTEMS.md` M26 section (own section only), `docs/04_GAME_LOOP.md` mode entry
  - **Verify:** `sync-systems-doc` reports nothing undocumented for the files above.
- [ ] 11. **Checkpoint B (final)** — rebase on `main`, full suite, `checkpoint-reviewer`, headful capture reviewed, commit+push.

## Notes

- **Parallel with M27/M28 (user decision, 2026-09-29).** This departs from the default
  one-milestone-at-a-time rule deliberately; file ownership is what makes it safe:
  - **M26 owns:** `scenes/modes/*`, `scripts/modes/*`, `EnemySpawner.gd`, `LootDrop.gd`,
    `CombatModifiers.gd`, `BattleUpgradeData.gd`, `ShipController.gd`, `SceneManager.gd`,
    `resources/combat/upgrades/*`, `resources/balance/MaelstromCurve.tres`.
  - **Shared, additive only:** `MainMenu.gd`/`.tscn` (M28 also adds a New Game prompt),
    `SaveManager.gd` (M27 also adds a `schedule` section), `docs/05` (own section only).
    Add a function/section; don't reformat existing code.
- **Task 8's save hazard is the likeliest real bug.** `SaveManager.save_game()` reads the
  `player_ship` group; the Maelstrom ship is in it. A naive end-of-run save would teleport the
  campaign ship to the run's coordinates and copy its damage. The isolation test must compare the
  `player` section too.
- `ShipController.gd` is next to fragile code (buoyancy/stability is in `ShipMovement`/
  `BuoyancySimulator`, not here — but don't wander). Only `_on_died()` changes.
- `BattleUpgradeData.Effect` is int-serialized: **append only**.
- **Not verifiable here:** phone frame rate at 10 enemies + pickups, whether the curve paces
  well, whether the magnet *feels* right. Say so in the checkpoint.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "3"] },
    { "id": 1, "tasks": ["2", "4"] },
    { "id": 2, "tasks": ["5"] },
    { "id": 3, "tasks": ["6", "7"] },
    { "id": 4, "tasks": ["8", "9"] },
    { "id": 5, "tasks": ["10", "11"] }
  ]
}
```
