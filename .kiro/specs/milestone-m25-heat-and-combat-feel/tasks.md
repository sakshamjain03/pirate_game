# Implementation Plan: Milestone M25 — Heat & Combat Feel

## Overview

Read `docs/05_CURRENT_SYSTEMS.md` (Combat, Empire Escalation), `docs/00_VISION.md` §19.2 and this
spec's `design.md` before Task 1.

**Verification command:**
```
.godot-tools/Godot_v4.3-stable_win64_console.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
The engine binary is gitignored and lives in `.godot-tools/`, **not** the project root or PATH.

Baseline entering this milestone (2026-09-28, post-M24): **117 scripts, 767 tests, 767 passing, 0
failing.** Any failure is a regression.

## Tasks

- [x] 1. Data layer — `HeatTierData`, `HeatConfigData`, `resources/balance/HeatCurve.tres` with the six authored tiers
  - **Verify:** `tier_for()` returns the right tier at every boundary including 0 and above 220; tiers are sorted and contiguous; boundaries sit on 60 and 150.
  - _Requirements: 3.2, 3.3, 5.1_
- [x] 2. Eights currency — `ResourceManager` key, production guard that `push_error`s, `ChapterData.reward_eights`, `CampaignManager` grant
  - **Shipped without the first-boss-kill grant.** "First time" needs a persisted set of defeated bosses, which is new save state and belongs with M31's achievement tracking rather than being bolted on here. Chapter rewards alone already satisfy Requirement 4.3's real intent — a zero-spend player holds Eights before ever seeing a purchase prompt — and `test_eights_currency.gd` pins that.
  - **Verify:** `tests/test_eights_currency.gd` — a building authored to produce eights errors and mints nothing; chapter completion grants; save round-trips.
  - _Requirements: 4.1, 4.2, 4.3_
- [x] 3. `EmpireManager` heat — tier derivation, `heat_tier_changed` signal, authored per-tier decay with grace, faster decay while docked at an owned island, `spend_to_reduce_heat()`
  - **Verify:** `tests/test_heat_system.gd` — tier changes fire once per crossing; decay reaches tier 0 unaided; paid clear drops exactly one tier and refuses when unaffordable; no new save section.
  - _Requirements: 3.1, 3.7, 3.8, 3.10, 4.4_
- [x] 4. `EnemySpawner` reads the tier — cap, interval, strength multiplier; delete the hardcoded `max_enemies`/interval tuning
  - **Verify:** changing tier changes the live cap; `grep` shows no ambient tuning constant left in the script.
  - _Requirements: 3.4, 5.2_
- [x] 5. Passive-until-provoked — `EnemyAI` engage gate, per-ship `provoke()`, provocation from player damage/ram/board
  - **Verify:** `tests/test_enemy_provocation.gd` — a tier-0 enemy never chases an idle player; firing on it makes that one ship (not its neighbours) engage; an already-hostile faction engages regardless of tier; **avoidance still runs while passive**.
  - _Requirements: 3.5, 3.6_
- [ ] 6. **Checkpoint A** — full suite, `checkpoint-reviewer`, commit+push.
- [ ] 7. Manual fire — `auto_fire_enabled` default false, `SettingsManager.auto_fire` persisted, `SettingsMenu` accessibility toggle
  - **Verify:** `tests/test_manual_fire.gd` — no shot without input; arc-lock still gates; toggle restores old behaviour and round-trips. **`tests/test_ship_combat.gd` unmodified and passing.**
  - _Requirements: 1.1, 1.2, 1.3_
- [ ] 8. Ammo swap — `MobileControls` button cycling round/chain/grape, active type shown; swap must not reset an in-progress reload
  - **Verify:** cycling mid-cooldown leaves `can_fire_*` and timers untouched.
  - _Requirements: 1.4, 1.5_
- [ ] 9. Damage-pool legibility — `EnemyHealthBarWidget` three segments from `pool_changed`, crippled markers, pool-coloured floating damage, HUD ammo + per-side reload
  - **Verify:** headful `CombatCaptureHarness` at phone width — read the segments in the actual image, do not infer from code. Non-colour-only differentiation per `docs/18_ACCESSIBILITY.md`.
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
- [ ] 10. Heat HUD — current tier indicator, tier-change announcement, paid-clear entry point
  - **Verify:** headful capture at phone width; tier change is legible without reading a number.
  - _Requirements: 3.9_
- [ ] 11. Dev console — heat tab (set tier, force provoke, grant Eights)
  - **Verify:** `tests/test_no_shipping_reference_to_debug.gd` still passes; console still parses.
- [ ] 12. Docs — `docs/05_CURRENT_SYSTEMS.md` M25 section (rewrite §5's escalation text, do not append), `docs/04_GAME_LOOP.md` heat beat, `docs/17_MONETIZATION.md` heat-clear SKU note
- [ ] 13. **Checkpoint B (final)** — full suite, `checkpoint-reviewer`, headful capture reviewed, commit+push.

## Notes

- **The §19.2 line is the acceptance criterion that matters most.** Heat must never gate sailing,
  combat or boarding — it changes how many ships exist and whether they engage first. If a review
  cannot tell heat from an energy meter, the design has failed regardless of what the tests say.
- Task 7 changes a default that every combat test implicitly relies on. Tests may legitimately need
  an explicit `fire_broadside()` call; a test that starts **asserting less** is a red flag.
- Task 5 sits next to the fragile avoidance code. The gate goes on the *engage decision only* —
  `_get_avoidance_turn`, `_probe` and `_push_to_open_water` are not to be edited.
- Tier 5's cap of 8 ambient hulls is a **phone performance** question as much as balance. Flag it as
  unverified until it runs on a device.
- **Not verifiable here:** whether manual fire *feels* better than auto-fire, whether the heat curve
  paces well, and on-device frame rate at tier 5. Say so rather than claiming a pass.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2"] },
    { "id": 1, "tasks": ["3", "4", "5"] },
    { "id": 2, "tasks": ["6"] },
    { "id": 3, "tasks": ["7", "8"] },
    { "id": 4, "tasks": ["9", "10", "11", "12"] },
    { "id": 5, "tasks": ["13"] }
  ]
}
```
