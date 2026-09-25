# Implementation Plan: Milestone M23 — Naval Dynamics

## Overview

Runs alongside M22 (UI overhaul, in progress in another session) — no shared files except the one
`SettingsMenu.gd` hunk. Read `docs/05_CURRENT_SYSTEMS.md` (Combat, World/ships sections) and this
spec's `design.md` before Task 1.

**Verification command:**
```
.godot-tools/Godot_v4.3-stable_win64_console.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
Baseline entering this milestone (2026-09-25, with M22's uncommitted working tree): **661 tests,
657 passing, 4 failing** — `test_combat_loop_end_to_end` ("hostile off the beam must lock the
starboard battery"), `test_ad_manager`-area ad request, `test_store_screen` content/close overlap,
`test_touch_target_audit` MainMenu buttons. All pre-existing; none may get worse.

## Tasks

- [x] 1. Data resources: `RamConfigData`, `CannonConfigData`, physics materials, `ShipStats` new exports
  - **Verify:** new `.tres` load in a GUT test; suite count unchanged otherwise.
  - _Requirements: 1.2, 2.8, 5.8_
- [x] 2. `ShipCollisionHandler` — prism, material, contact yaw grace, watchdog; `ShipMovement.notify_contact`; auto-add in `ShipController`
  - **Verify:** `tests/test_ship_collision.gd` — overlapping hulls separate; hull shape is convex with the box AABB.
  - _Requirements: 1.1, 1.2, 1.4, 1.5_
- [x] 3. Enemy masks 5→7, Island material, soft world-edge spring, EnemyAI ship whiskers
  - **Verify:** `grep collision_mask scenes/world/*Boss*.tscn scenes/world/EnemyShip.tscn` all 7; existing world-bounds and avoidance tests pass.
  - _Requirements: 1.3, 1.6, 1.7_
- [x] 4. Ram damage — zones, formula, `ShipDamage.apply_impact`, knockback, feedback
  - **Verify:** `tests/test_ram_damage.gd` (zones, matrix, threshold, friendly, stats scaling, apply_impact).
  - _Requirements: 2.1–2.9_
- [x] 5. **Checkpoint A** — full suite, `checkpoint-reviewer`, headful CaptureHarness, commit+push.
- [x] 6. Cannon fire — gun count/generated markers, ripple, misfire, aim spread, glancing hits
  - **Verify:** `tests/test_cannon_fire.gd`; `tests/test_ship_combat.gd` unmodified and passing.
  - _Requirements: 5.2–5.6, 5.8_
- [x] 7. Rebalance `fire_rate`/`cannon_damage`, author `cannons_per_side` on all ship/enemy `.tres`
  - **Verify:** script-printed table of old→new; suite passes.
  - _Requirements: 5.1_
- [x] 8. AI difficulty — `AIDifficultyData` ×4, `SettingsManager.ai_difficulty`, ShipCombat/EnemyAI terms, SettingsMenu option
  - **Verify:** `tests/test_ai_difficulty.gd` (persist round-trip, multipliers apply only to hostile ships, live change).
  - _Requirements: 6.1–6.5_
- [x] 9. **Checkpoint B** — full suite, reviewer, commit+push (SettingsMenu hunk only).
- [x] 10. Components — `ShipComponentData` ×5, `ShipProgressionConfig`, `OwnedShipData` gating/save/migration, `FleetManager.upgrade_component`
  - **Verify:** `tests/test_ship_components.gd`; `tests/test_ship_progression.gd` passes.
  - _Requirements: 3.1–3.7, 5.7_
- [x] 11. IslandMenu component rows + disabled-reason hints
  - **Verify:** headful sweep / manual screenshot of the fleet panel.
  - _Requirements: 3.8_
- [x] 12. AI ramming — `AIProfileData.ram_tendency`, EnemyAI RAM run, profile authoring
  - **Verify:** `tests/test_ai_ramming.gd` (commit conditions, abort on timeout/flee).
  - _Requirements: 4.1–4.4_
- [x] 13. Docs — `05_CURRENT_SYSTEMS.md` M23 section, `navalCombat.md` §13 stale text, CLAUDE.md fragile-list note
- [x] 14. **Checkpoint C (final)** — full suite, reviewer, commit+push.

## Notes

- **Checkpoint record (2026-09-25):** tasks 1–13 were implemented in one pass, so Checkpoints A/B/C
  were run as one consolidated checkpoint — `checkpoint-reviewer` PASS, full suite 714 tests /
  711 passing / 3 pre-existing failures (none M23-caused), `test_ship_combat.gd` unmodified and
  passing, `BuoyancySimulator.gd` untouched, headful `CombatCaptureHarness` shows hulls upright and
  the new reload ("RELOADING 52%") live. One test expectation changed:
  `test_combat_loop_end_to_end.gd` re-opens the reload gate instead of relying on the old 0.5 s
  reload (its own comment tied the wait to that value).

- Task 2 touches the fragile yaw servo — the only change allowed is the `yaw_t` scalar.
- Task 7 changes authored balance; feel cannot be verified headlessly — say so.
- Tasks 6–8 and 10–12 are independent of each other; 4 depends on 2.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1"] },
    { "id": 1, "tasks": ["2", "3"] },
    { "id": 2, "tasks": ["4", "5"] },
    { "id": 3, "tasks": ["6", "7", "8", "9"] },
    { "id": 4, "tasks": ["10", "11", "12", "13", "14"] }
  ]
}
```
