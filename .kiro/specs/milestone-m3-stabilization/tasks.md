# Implementation Plan: Milestone M3 — Stabilization

## Overview

Every task below is scoped to touch **at most 2 files** and has an explicit, mechanical
verification step you must run and report the result of before moving to the next task. Do not
batch multiple tasks into one change — this milestone exists specifically to be a template for
small, verifiable units of work (see `docs/07_AI_AGENT_WORKFLOW.md`).

Before task 1: read `docs/05_CURRENT_SYSTEMS.md` in full. It is the ground truth for every system
referenced below.

---

## Tasks

- [ ] 1. Remove ScreenshotHarness from production autoloads
  - Open `project.godot`, delete the line `ScreenshotHarness="*res://scripts/tests/ScreenshotHarness.gd"` from `[autoload]`
  - Add a one-line comment at the top of `scripts/tests/ScreenshotHarness.gd` noting it must be run manually via `godot --headless -s res://scripts/tests/ScreenshotHarness.gd`, not as an autoload
  - **Verify:** run `godot --headless --check-only` — must exit with no new errors. Boot the game once (`godot` normally or `--headless` with a scene check) and confirm Boot → MainMenu still works.
  - _Requirements: 4.1, 4.2, 4.3_

- [ ] 2. Fix duplicate EventManager instance
  - Open `scenes/world/World.tscn`, remove the scene-local `Systems/EventManager` node (the one with the same script as the `EventManager` autoload)
  - Open `scripts/managers/WorldManager.gd`, find every call site using `get_node_or_null("../EventManager")` (or similar relative lookup) and change it to call the global `EventManager` autoload directly (e.g. `EventManager.some_method(...)`)
  - **Verify:** grep `World.tscn` for `EventManager` — should show it only in autoload-implied references, not as a scene node. Boot the game, dock at an island, confirm a docking event still fires (check console/log output or in-game feedback).
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [ ] 3. Create PlayerFaction.tres
  - Read `resources/factions/PirateClans.tres` to see its exact structure/fields
  - Create `resources/factions/PlayerFaction.tres` with the same `FactionData` schema: a distinct `id` (e.g. `"player"`), `name` (e.g. `"Your Fleet"` or similar — pick something consistent with existing faction naming), `is_hostile = false`, and sail/hull colors visually distinct from all 4 existing factions
  - **Verify:** in a headless script or the Godot editor, call `load("res://resources/factions/PlayerFaction.tres")` and confirm it returns a non-null `FactionData` instance with the expected `id`
  - _Requirements: 2.1_

- [ ] 4. Wire PlayerFaction.tres into FactionManager
  - Open `scripts/managers/FactionManager.gd`, confirm `get_player_faction()` now successfully loads `PlayerFaction.tres` (it already points at this path — no path change should be needed after Task 3)
  - **Verify:** in-game, colonize a NEUTRAL island (e.g. dock at one with the required gold) and confirm ownership transfers without a script error in the console. Then defeat an ENEMY island's defenders and confirm auto-capture also works.
  - _Requirements: 2.2, 2.3, 2.4, 2.5_

- [ ] 5. Fix GhostShipStats.tres property names
  - Read the full `@export` property list in `scripts/world/ShipStats.gd`
  - Rewrite `resources/enemies/GhostShipStats.tres`, replacing `ship_name`/`ship_tier`/`speed`/`turn_speed`/`reload_time` with the real property names (`max_speed`, `turn_rate`, `fire_rate`, and drop any property that has no real equivalent), keeping `max_health=2500`, `cannon_damage=80`, `cannon_range=150`
  - Choose boss-appropriate values for `max_speed` (slower than a Galleon) and `fire_rate` (slow, deliberate)
  - **Verify:** load `GhostShipStats.tres` and print/inspect every property — confirm none are silently falling back to `ShipStats`'s class defaults for values you intended to override
  - _Requirements: 3.1, 3.2, 3.3_

- [ ] 6. Rewrite SaveManager.gd documentation header
  - Open `scripts/managers/SaveManager.gd`, replace the doc header's claim that it's an M1 no-op stub with an accurate description: complete JSON save/load covering player position/health, economy, per-island built buildings, fleet, tech, and faction reputation; auto-saves every 60s and on dock completion
  - Do not change any code below the header
  - **Verify:** diff the file — only the header comment block should have changed
  - _Requirements: 6.1, 6.2_

- [ ] 7. Delete dead code — ScenePaths and UIConstants
  - Grep the whole repo for `ScenePaths` and `UIConstants` (case-sensitive, whole word) — confirm the only matches are inside `scripts/core/ScenePaths.gd` and `scripts/core/UIConstants.gd` themselves
  - Delete both files
  - **Verify:** run `godot --headless --check-only` — must exit with no new errors (confirms nothing was actually depending on them)
  - _Requirements: 5.1, 5.2_

- [ ] 8. Delete orphaned resources
  - Grep the whole repo for `resources/world/ShipStats.tres` and `resources/world/IslandData.tres` — confirm no `.tscn` or `.gd` file references either path
  - Delete both files
  - **Verify:** run `godot --headless --check-only` — must exit with no new errors
  - _Requirements: 5.3, 5.4_

- [ ] 9. Checkpoint — core fixes sanity pass
  - Boot the game fully: Boot → MainMenu → World
  - Sail to an island, dock, colonize it, undock
  - Confirm no new console errors appeared during any of the above compared to before this milestone started
  - Do not proceed to Task 10 until this checkpoint passes cleanly

- [ ] 10. Add gamepad input bindings
  - Open `project.godot`'s `[input]` section
  - For each of `ship_forward`, `ship_backward`, `ship_left`, `ship_right`, `dock`, `interact`, `pause`, `camera_zoom_in`, `camera_zoom_out`, `camera_rotate_left`, `camera_rotate_right`, add an appropriate `InputEventJoypadButton` or `InputEventJoypadMotion` event alongside the existing keyboard/mouse event (do not remove existing events)
  - Reassign `interact` off of key `E` (currently conflicts with `camera_rotate_right`) to an unused key (e.g. `G`)
  - **Verify:** with a gamepad connected, confirm each action triggers in Godot's Input Map debug view (Project Settings → Input Map) or via a quick in-game test
  - _Requirements: 9.1, 9.2, 9.3_

- [ ] 11. Add camera collision to CameraRig
  - Open `scenes/world/CameraRig.tscn` / `scripts/world/CameraRig.gd`
  - Configure the `SpringArm3D`'s collision `shape` and `collision_mask` so it shape-casts against island/terrain geometry and retracts on obstruction
  - **Verify:** sail close to an island such that the camera would normally clip through it — confirm the camera pulls in instead of showing the interior of island geometry
  - _Requirements: 8.1_

- [ ] 12. Resolve ORBIT/LOOK camera mode stubs
  - Open `scripts/world/CameraRig.gd`, inspect the ORBIT/LOOK enum branches
  - Either implement genuinely distinct behavior for each mode, OR collapse the enum to FOLLOW-only and add a code comment: `# ORBIT and LOOK modes are deferred — tracked for a future milestone`
  - **Verify:** switching camera mode (if still exposed) produces visibly different behavior, or the modes are no longer reachable/exposed if collapsed
  - _Requirements: 8.2, 8.3_

- [ ] 13. Align ocean shader uniforms with OceanController
  - Open `resources/shaders/water.gdshader` and list every `uniform` it declares
  - Open `scripts/world/OceanController.gd`'s `_apply_settings()` and list every `set_shader_parameter()` call
  - Fix every name mismatch (rename on whichever side is wrong — prefer renaming the shader-call side unless the shader name is used elsewhere)
  - **Verify:** change a value in `OceanSettings.tres` (e.g. `wave_height`), run the game, and visually confirm the ocean's rendered waves actually change
  - _Requirements: 10.1_

- [ ] 14. Sync WaveGenerator with OceanSettings
  - Open `scripts/world/WaveGenerator.gd`, confirm whether its wave height/length/speed/wind parameters are hardcoded or read from `OceanSettings.tres`
  - If hardcoded, change it to read from the same `OceanSettings` resource the shader uses, so CPU buoyancy calculations and GPU wave rendering share one source of truth
  - **Verify:** visually confirm (running the game) that the player ship's pitch/roll now visually tracks the rendered wave surface beneath it, not just that the code compiles
  - _Requirements: 10.2, 10.3_

- [ ] 15. Checkpoint — visual/feel pass
  - Boot the game, sail near an island (confirm camera behavior from Task 11/12), sail through open water (confirm ship motion matches waves from Task 13/14), test with a gamepad if available (Task 10)
  - Do not proceed to Task 16 until this checkpoint passes cleanly

- [ ] 16. Implement test_ship_properties.gd
  - Implement Properties 4, 5, 6, 7, 9 from `.kiro/specs/milestone-m2-playable-world/design.md` §6, following the GUT test pattern already used in `tests/test_settings_manager.gd`
  - Minimum 20 generated input cases per property
  - **Verify:** `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` — all tests pass, this file is no longer 0 bytes
  - _Requirements: 7.1, 7.2, 7.3_

- [ ] 17. Implement test_camera_properties.gd
  - Implement Properties 1, 2, 3 from the M2 design doc §6
  - **Verify:** same GUT command as Task 16, all tests pass
  - _Requirements: 7.1, 7.2, 7.3_

- [ ] 18. Implement test_docking_properties.gd
  - Implement Properties 10, 11, 12, 13 from the M2 design doc §6
  - **Verify:** same GUT command, all tests pass
  - _Requirements: 7.1, 7.2, 7.3_

- [ ] 19. Implement test_input_properties.gd
  - Implement Properties 8, 14, 15, 23, 24, 25 from the M2 design doc §6
  - **Verify:** same GUT command, all tests pass
  - _Requirements: 7.1, 7.2, 7.3_

- [ ] 20. Implement test_ocean_properties.gd
  - Implement Properties 19, 20, 21, 22 from the M2 design doc §6
  - **Verify:** same GUT command, all tests pass
  - _Requirements: 7.1, 7.2, 7.3_

- [ ] 21. Final checkpoint — full M3 verification
  - Run the full GUT suite (`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`) — all tests across M1, M2, and the new M3 property tests pass
  - Run `godot --headless --check-only` — zero errors
  - Manually re-verify: Boot → MainMenu → World → sail → dock → colonize → undock → combat with one enemy ship → ship destroyed → loot drop → death/respawn (if player) all still work
  - Update `docs/05_CURRENT_SYSTEMS.md` §2's defect table: mark D1–D11 as fixed (strike through or move to a "Resolved" section with the fix commit/date); D12 (no test coverage for combat/economy/fleet/tech/factions) remains open and is tracked as a follow-up, not blocking M4
  - Confirm every modified `.gd` file still has an accurate documentation header per AGENTS.md

## Notes

- Tasks 1–9 are pure bugfixes with no visual/feel judgment calls — highest confidence, do these
  first.
- Tasks 10–15 involve visual/feel verification that cannot be fully confirmed by reading code —
  budget time to actually run the game, not just check compilation.
- Tasks 16–20 are mechanical test-writing against already-specified properties — no design
  judgment needed, just faithful implementation.
- If any task reveals the defect is more complex than described here (e.g., the shader mismatch
  in Task 13 turns out to require a shader rewrite, not a rename), stop and flag it rather than
  improvising a larger fix — re-scope as a new task instead of silently expanding this one.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2", "3", "5", "6", "7", "8"] },
    { "id": 1, "tasks": ["4"] },
    { "id": 2, "tasks": ["9"] },
    { "id": 3, "tasks": ["10", "11", "12", "13"] },
    { "id": 4, "tasks": ["14"] },
    { "id": 5, "tasks": ["15"] },
    { "id": 6, "tasks": ["16", "17", "18", "19", "20"] },
    { "id": 7, "tasks": ["21"] }
  ]
}
```
