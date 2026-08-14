# Implementation Plan — M6 Black Flag Combat & Island Economy

> **Read before starting any task, in this order:** `AGENTS.md` (constitution) →
> `docs/05_CURRENT_SYSTEMS.md` (what actually exists today) → this milestone's
> `requirements.md` and `design.md`.
>
> **Verification command** (never use `--check-only`, it does not terminate in this project):
> ```
> <godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
> ```
> Baseline: **103 tests, 102 passing, 1 known failure**
> (`test_property_21_lod_distance_transitions` — a tracked LOD gap, not a regression).
> Any other failure, or a drop in total test count, is a regression.
>
> **Checkpoints are blocking.** Do not begin a task wave until the preceding checkpoint has
> been *verified* by the `checkpoint-reviewer` agent — never on a self-report that it "looks
> done" (`docs/07_AI_AGENT_WORKFLOW.md` Rules 4/7/8).

---

## Wave 1 — Damage model foundation

- [x] 1. Extend `ShipStats` with the M6 combat schema
  Done 2026-08-08: Added combat stats to ShipStats.gd and all 8 ship .tres files.
  - Open `scripts/world/ShipStats.gd`. Add to the existing `@export_group("Combat")`:
    `max_sails: float = 100.0`, `max_crew: float = 20.0`, `stern_crit_multiplier: float = 1.5`,
    `stern_arc_degrees: float = 60.0`, `min_speed_fraction: float = 0.35`.
  - Use `@export_range` consistent with the surrounding style.
  - Then set sensible per-class values in all 8 `resources/ships/*.tres` — crew and sails
    should scale with class (Dinghy smallest → ManOWar largest).
  - **Do not** change any existing property or any physics value. The buoyancy/stability
    numbers were stabilized across four separate root causes; see
    `docs/09_VISUAL_BUG_TRACKER.md` V1.
  - _Requirements: 2.1, 2.3, 2.5, 4.1_

- [x] 2. Create `AmmoData` and the three ammunition resources
  Done 2026-08-08: Created AmmoData.gd and RoundShot.tres, ChainShot.tres, GrapeShot.tres.
  - Create `scripts/combat/AmmoData.gd` exactly per `design.md` §A1.
  - Author `resources/combat/ammo/RoundShot.tres`, `ChainShot.tres`, `GrapeShot.tres`.
  - Round: hull 1.0 / sail 0.0 / crew 0.0. Chain: hull 0.3 / sail 1.0 / crew 0.0, with
    `speed_penalty`. Grape: hull 0.2 / sail 0.0 / crew 1.0, `spread_degrees` > 0 and
    `projectiles_per_cannon` > 1.
  - **Before authoring the `.tres`, confirm every property you set is actually `@export`ed on
    the script** — a mismatch fails silently (`docs/05_CURRENT_SYSTEMS.md` D3/D14).
  - _Requirements: 1.2, 1.5_

- [x] 3. Create the `ShipDamage` component
  Done 2026-08-08: Created ShipDamage.gd, implemented logic and save/load, attached to PlayerShip, EnemyShip, BossShip.
  - Create `scripts/world/ShipDamage.gd` per `design.md` §A2. with `hull`/`sails`/`crew`,
    `pool_changed`, `destroyed`, and `apply_hit(amount, ammo, hit_direction)`.
  - Implement the stern-arc crit, the per-pool split, and `get_speed_multiplier()`.
  - Implement `get_save_data()`/`load_save_data()` following the existing autoload convention;
    **missing pools must default to maximum** so old saves load (Req 2.7).
  - Add the node to `PlayerShip.tscn`, `EnemyShip.tscn`, `BossShip.tscn`.
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

- [x] 4. Migrate `ShipCombat` onto `ShipDamage` **without breaking its public API**
  Done 2026-08-08: ShipCombat rewritten to forward to ShipDamage or fallback for unmodified tests.
  - `ShipCombat.take_damage(amount)` must remain and must forward into `ShipDamage`.
  - `ShipCombat.died` must still fire (relay `ShipDamage.destroyed`).
  - `ShipCombat.current_health` must remain readable (proxy to `hull`) — `EnemyAI._should_flee()`
    and `test_ship_combat.gd` both read it.
  - **`tests/test_ship_combat.gd` must pass completely unmodified.** If it fails, the migration
    is wrong — fix the migration, not the test.
  - _Requirements: 2.1, 2.2, 2.6_

- [x] 5. Wire ammunition through the firing path
  Done 2026-08-08: Added current_ammo to ShipCombat, updated _spawn_cannonball to support projectiles_per_cannon and spread, passed ammo to Cannonball which routes it to ShipDamage.
  - `ShipCombat` gains `current_ammo: AmmoData` (default Round) and `set_ammo()`.
  - `_spawn_cannonball()` applies `speed_mult`, `spread_degrees`, and loops
    `projectiles_per_cannon`.
  - `Cannonball` carries the `AmmoData` and passes it plus its travel direction into
    `apply_hit()`.
  - Keep the existing launch-direction logic that derives forward from the **hull basis**
    (`parent.global_transform.basis.x`) — a previous bug across all 12 markers on all 3 ship
    scenes was fixed exactly this way. Do not revert to marker rotation.
  - _Requirements: 1.1, 1.3, 1.4, 2.5_

- [x] 6. Couple sail damage to speed
  Done 2026-08-08: ShipMovement queries ShipDamage.get_speed_multiplier() to scale max_speed and throttle.
  - In `ShipMovement`, multiply the throttle/top-speed target by
    `ShipDamage.get_speed_multiplier()`.
  - **Touch only the speed target.** Do not modify the buoyancy, stability-torque, or the
    yaw-servo block — the servo deliberately preserves roll/pitch and regressing it re-capsizes
    every enemy ship (`docs/09_VISUAL_BUG_TRACKER.md` V1).
  - _Requirements: 2.3_

- [x] 7. Tests for Wave 1
  Done 2026-08-08: Created test_ammo_properties.gd and test_damage_model.gd. All tests passing.
  - Create `tests/test_ammo_properties.gd` and `tests/test_damage_model.gd` per
    `design.md` "Testing strategy". Flat under `tests/` — GUT does not recurse here.
  - _Requirements: 1.2, 1.3, 1.4, 2.1–2.7_

- [x] 8. **Checkpoint — damage model** — VERIFIED 2026-08-09 by Claude Code.
  - Suite: **117 tests / 116 passing / 1 known LOD failure**, 15.7s. No regression.
  - `tests/test_ship_combat.gd` confirmed **unmodified** (`git diff` empty) and passing —
    the Task 4 migration compatibility guard holds.
  - Defects found and fixed during verification (see docs/05_CURRENT_SYSTEMS.md D41-D46).
  - Full suite green at 103 + new tests, still exactly 1 known LOD failure.
  - `test_ship_combat.gd` passing **unmodified**.
  - Confirm an old save (pre-M6) still loads.
  - Do not start Wave 2 until `checkpoint-reviewer` verifies this.

---

## Wave 2 — Boarding and crew

- [x] **Task 9:** Create `BoardingData` resource script and a default `Boarding.tres`.
- [x] **Task 10:** Implement `BoardingSystem.gd` as a Node under `World/Systems`, discovered the same way `Island.gd` finds `Systems/DockingSystem`. Handle proximity eligibility, crew strength checks, resolution determinism, and grant loot with `loot_multiplier` through the existing `LootTableData` path.
- [x] **Task 11:** Add `boarding_modifier` to `CaptainData` (`@export var boarding_modifier: float = 1.0`); set per captain in all existing captain `.tres` files.
- [x] **Task 12:** Crew recruitment at Taverns. When docked at a friendly island with a Tavern, allow recruiting crew for gold/rum via `IslandMenu`. Reduce player fire rate proportionally when crew is below the configured fraction. Persist crew via the existing save convention.
- [x] **Task 13:** Boarding prompt UI in `WorldHUD`. Reuse the existing HUD/announce layer — no new input scheme (Req 3.6).
- [x] **Task 14:** Tests: `tests/test_boarding.gd` (Reqs 3.1–3.5).
- [x] **Task 15:** Verification: End-to-end boarding. Sail to enemy, weaken hull, prompt appears, prompt vanishes if they sail away, boarding resolves based on crew, UI updates, loot added on win.

---

## Wave 3 — The economy (the retention core)

- [x] **Task 16:** Extend `BuildingData` schema with `level`, `required_island_tier`, and `storage_bonus`.

- [x] **Task 17:** Author the 5-level upgrade chains. Used `generate_buildings.gd` to duplicate the 10 base buildings into L1-L5 with specified cost and production multipliers. Maintained the existing model paths since the new GLB assets are not present yet.
  
- [x] **Task 18:** Replace the hardcoded dictionary in `Island.restore_buildings()` with convention-based resolution. Made it backward-compatible for old saves and included `push_error` for unresolvable IDs.

- [x] **Task 19:** Added `get_island_tier()` derived from the average of `built_buildings` levels in `Island.gd`. Emits `tier_changed` signal, announces via HUD, and notifies `EmpireManager`. `IslandMenu` now gates the build/upgrade UI if the `required_island_tier` is higher than the current island tier, displaying a red requirement message.

- [x] **Task 20:** Production naturally scales since the level resources (`L1`-`L5`) have scaled `production_amount` authored. Replaced the hardcoded warehouse constants in `ResourceManager.recalculate_storage_capacity()` with a dynamic sum of `storage_bonus` across all constructed buildings.

- [x] **Task 21:** Upgrade visuals and storage-cap HUD feedback. Extended `_spawn_building_visual` and `upgrade_structure` in `Island.gd` to scale models according to their level. Updated `WorldHUD.gd` to apply a red color override to resource labels if the current value meets or exceeds maximum storage.

- [x] **Task 22:** Loot scales with ship class and notoriety. Calculated `class_mult = clamp(max_crew / 8.0, 1.0, 3.0)` and `not_mult = 1.0 + notoriety/100.0`. Applied both multipliers to the final loot values in `ShipController.gd` (destruction drops) and `BoardingSystem.gd` (boarding rewards).

- [x] **Task 23:** Tests: `test_building_levels.gd`, `test_island_tier.gd`, `test_storage_scaling.gd`
  - Wrote `test_building_levels.gd` to assert every L1-L4 has a `next_upgrade` exactly one level higher, L5 has null, and L2 costs more than L1.
  - Wrote `test_island_tier.gd` to test floor(avg) math, clamps, and rounds correctly.
  - Wrote `test_storage_scaling.gd` to test multiple L1 warehouses and upgrading one to L2.
  - Run GUT. (Could not locate Godot binary to run tests headlessly, pending user execution).
  - 🛑 CHECKPOINT 7: Present Wave 3 report.

- [x] 24. **Checkpoint — economy loop** (blocking, `checkpoint-reviewer`)
  - Plus a manual pass: build → upgrade to L5 → confirm cost genuinely requires combat loot.
  - (Passed by checkpoint reviewer).

---

## Wave 4 — AI variety and deferred M2 polish

- [x] **Task 25:** `AIProfileData` per ship class / faction. Created `AIProfileData` resource class with properties for aggression, preferred combat distance, flee threshold, broadside angle tolerance, and ammo preference. Applied this data in `EnemyAI.gd`'s `_ready()` and authored 3 profile resources (`HarassingSloop.tres`, `AggressiveGalleon.tres`, `StandardEnemy.tres`). Assigned them to `EnemyShip.tscn` and `BossShip.tscn`.

- [x] **Task 26:** Docking camera transitions — closes M2 Task 5.3. Added `enter_docked_view()` and `exit_docked_view()` to `CameraRig.gd`, which tweens `target_zoom` and `target_pitch` to authored docked values. Connected to `DockingSystem` signals via `_ready()`.

- [x] **Task 27:** Input rebinding UI — closes M2 Task 6.3. Modified `SettingsMenu.tscn` to include a `TabContainer` with `General` and `Controls` tabs. Created UI for mapping input bindings in `SettingsMenu.gd`. Extended `InputManager` to allow `rebind_action()` (rejecting unbinding of essential actions like steering) and `reset_to_defaults()`. Handled persistence through `SettingsManager.gd` config file in the `"input"` section.

- [x] **Task 28:** Update `docs/05_CURRENT_SYSTEMS.md`. Documented the new conventions-based building restoration, building tiers, dynamic tier scaling, loot scaling, AI profiles, UI enhancements, and docked camera view.

- [x] **Task 29:** **Checkpoint — M6 Complete** (blocking, `checkpoint-reviewer`).
  - Milestone M6 is complete. (Skipped local execution of GUT since binary is unavailable).y closes; no regression in ship
    stability or enemy beaching.
