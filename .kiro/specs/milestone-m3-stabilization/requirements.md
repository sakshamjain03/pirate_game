# Requirements Document

## Introduction

Milestone M3 — Stabilization fixes the concrete defects documented in `docs/05_CURRENT_SYSTEMS.md`
§2 (D1–D12) and closes the remaining M2 gaps recorded in
`.kiro/specs/milestone-m2-playable-world/tasks.md`'s bug-fix notes. It adds **no new gameplay
features**. Every task in this milestone either fixes a specific broken behavior, removes dead
code, corrects a misleading doc comment, or fills in a missing test file.

This milestone exists because milestone-m4-empire-escalation builds directly on
`FactionManager`, `Island.gd`, and the ocean/camera/input systems this milestone repairs.
Building the new Empire Threat system on top of a broken colonize flow (D2) or a camera that
clips through islands (D9) would compound the problem. Fix the foundation first.

Every task in this milestone is intentionally small and independently verifiable — this
milestone is the reference example for how work should be sized for an AI coding agent with
limited context per turn (see `docs/07_AI_AGENT_WORKFLOW.md`). Each task touches at most one or
two files and has an explicit, mechanical verification step.

---

## Glossary

- **PlayerFaction**: The `FactionData` resource instance representing the player's own pirate
  faction, used by `FactionManager.get_player_faction()` when transferring island ownership.
- **Colonize flow**: The sequence triggered by `IslandMenu.gd`'s "Colonize" button →
  `Island.capture_island()` → `FactionManager.get_player_faction()`.
- **Production autoload**: An entry in `project.godot`'s `[autoload]` section that runs in every
  exported build, as opposed to editor-only or debug-only tooling.
- **Ocean event**: A randomly-timed spawn (merchant convoy, floating treasure, ghost-ship boss)
  driven by `EventManager.gd`'s internal timer.
- **Property test**: A GUT test that asserts a Correctness Property (see design.md) holds across
  many generated inputs, not just one hand-picked example.

---

## Requirements

### Requirement 1: Single EventManager instance

**User Story:** As a player, I want ocean events (merchant convoys, treasure, the ghost ship) to
occur at the intended frequency, so that the world doesn't feel like it's double-spawning things
or is too noisy.

#### Acceptance Criteria

1. THE `EventManager` SHALL run as exactly one live instance during gameplay — either the
   autoload singleton or a scene-local node, never both simultaneously.
2. WHEN `World.tscn` is the active scene, THE ocean-event timer (merchant convoy / treasure /
   ghost ship spawn logic currently in `EventManager._process()`) SHALL execute exactly once per
   timer interval, not once per instance.
3. IF the chosen fix removes the scene-local `Systems/EventManager` node from `World.tscn`, THEN
   `WorldManager.gd`'s existing calls that reference `get_node_or_null("../EventManager")` SHALL
   be updated to reference the autoload singleton (`EventManager.trigger_event(...)` /
   equivalent) instead, so docking-event wiring continues to work unchanged.
4. THE fix SHALL NOT change the observable behavior of docking-triggered events (island
   discovery/interaction events fired via `WorldManager` on dock-complete).

---

### Requirement 2: Working colonize / island-capture flow

**User Story:** As a player, I want to colonize a neutral island or capture an enemy island after
defeating its defenders, so that I can actually expand my empire — the core promise of the game.

#### Acceptance Criteria

1. THE `resources/factions/PlayerFaction.tres` file SHALL exist as a valid `FactionData`
   resource instance representing the player's own faction (non-hostile, distinct id/name/colors
   from PirateClans, RoyalNavy, MerchantGuild, and GhostFaction).
2. WHEN `FactionManager.get_player_faction()` is called, THE method SHALL return the loaded
   `PlayerFaction` resource, not `null`.
3. WHEN the player presses "Colonize" on a NEUTRAL island with sufficient gold, THE
   `Island.capture_island()` flow SHALL successfully transfer ownership to the player's faction
   and update `Island.gd`'s owner-faction state without error.
4. WHEN an ENEMY island's defenders are all destroyed, THE island SHALL automatically flip to the
   player's faction via the same `capture_island()` path, without error.
5. THE fix SHALL NOT introduce a new faction resource path that diverges from the existing
   `resources/factions/` naming convention (`PascalCase.tres`, matching PirateClans/RoyalNavy/etc).

---

### Requirement 3: Correct Ghost Ship boss stats

**User Story:** As a player, I want the Ghost Ship boss encounter to actually be a boss-tier
challenge, so that defeating it feels like a meaningful late-game event rather than an
accidentally-weak reskinned enemy.

#### Acceptance Criteria

1. THE `resources/enemies/GhostShipStats.tres` file SHALL set only property names that exist on
   the `ShipStats` schema (`scripts/world/ShipStats.gd`) — specifically `max_speed` (not
   `speed`), `turn_rate` (not `turn_speed`), `fire_rate` (not `reload_time`), and SHALL NOT set
   `ship_name` or `ship_tier` if those properties do not exist on `ShipStats`.
2. WHEN `GhostShipStats.tres` is loaded, THE resulting `ShipStats` instance's `max_speed`,
   `turn_rate`, and `fire_rate` SHALL reflect the intended boss-tier values (to be chosen by
   whoever fixes this — reasonable defaults: slower `max_speed` than a Galleon, slow `fire_rate`,
   high `max_health`/`cannon_damage`/`cannon_range` as already set correctly).
3. THE existing correctly-mapped properties (`max_health=2500`, `cannon_damage=80`,
   `cannon_range=150`) SHALL be preserved unless intentionally rebalanced.

---

### Requirement 4: No debug tooling in production autoloads

**User Story:** As a developer, I want production builds to boot straight into the real game
without debug scaffolding running alongside it, so that exported builds behave predictably and
don't waste startup time or resources on unrelated diagnostics.

#### Acceptance Criteria

1. THE `project.godot` `[autoload]` section SHALL NOT include `ScreenshotHarness` (or any other
   dev-only diagnostic script) as a production autoload.
2. IF `ScreenshotHarness.gd`'s screenshot-capture capability is still needed for development,
   THEN it SHALL be invoked via a Godot editor tool script, a command-line `--script` invocation,
   or a debug-build-only conditional — not a permanent autoload entry.
3. WHEN the game boots after this fix, THE existing gameplay flow (Boot → MainMenu → World)
   SHALL be unaffected.

---

### Requirement 5: Remove dead code

**User Story:** As a developer (human or AI agent), I want the codebase to contain only code
that is actually used, so that I don't waste time reading or extending scripts that have no
effect.

#### Acceptance Criteria

1. THE files `scripts/core/ScenePaths.gd` and `scripts/core/UIConstants.gd` SHALL either be
   deleted, or — if a maintainer determines they should be wired in — actually referenced from at
   least one other script.
2. IF deleted, THE deletion SHALL be verified by re-running a full-project grep for
   `ScenePaths` and `UIConstants` to confirm zero remaining references before removal.
3. THE orphaned resources `resources/world/ShipStats.tres` and `resources/world/IslandData.tres`
   SHALL either be deleted or given a real reference from a scene/script.
4. IF `resources/world/ShipStats.tres` is deleted, THE dangling reference it holds to the
   non-existent `resources/materials/ShipMaterial.tres` SHALL be removed along with it (no
   action needed if the file is simply deleted).

---

### Requirement 6: Accurate documentation headers

**User Story:** As a developer (human or AI agent) reading a script for the first time, I want
its documentation header to accurately describe what the script does, so that I don't make
incorrect assumptions about its state (e.g., believing a fully-implemented system is a stub).

#### Acceptance Criteria

1. THE `SaveManager.gd` documentation header SHALL accurately describe its actual current
   responsibilities: a complete JSON save/load system covering player position/health, economy,
   per-island built buildings, fleet, tech, and faction reputation, with auto-save on a timer and
   on dock completion.
2. THE header SHALL NOT claim `save_game()`/`load_game()` are no-op stubs or that M1 writes no
   persistent data.

---

### Requirement 7: M2 property test coverage

**User Story:** As a developer, I want the M2 ship/camera/ocean/docking/input systems to have
real regression tests, so that future changes (including the M3 fixes in this milestone) don't
silently break movement, camera, or docking behavior.

#### Acceptance Criteria

1. THE five empty files in `tests/world/` (`test_camera_properties.gd`,
   `test_docking_properties.gd`, `test_input_properties.gd`, `test_ocean_properties.gd`,
   `test_ship_properties.gd`) SHALL each contain real GUT test code implementing the
   corresponding Correctness Properties already defined in
   `.kiro/specs/milestone-m2-playable-world/design.md` §6 (Properties 1–25).
2. EACH property test SHALL run a minimum of 20 generated/varied input cases (matching the
   pattern established in the M1 property tests under `tests/`).
3. WHEN `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` is run, ALL new
   and existing tests SHALL pass.

---

### Requirement 8: Camera collision and mode differentiation

**User Story:** As a player, I want the camera to never clip through islands or terrain, so that
I can always see my ship clearly.

#### Acceptance Criteria

1. THE `CameraRig`'s `SpringArm3D` SHALL have collision detection configured against world
   geometry (islands, terrain) so the camera pulls in when an obstruction is between it and the
   ship.
2. THE ORBIT and LOOK camera modes SHALL each implement behavior distinct from FOLLOW mode, or
   — if out of scope for this milestone — SHALL be removed from the mode enum until implemented,
   rather than existing as dead enum values with no behavior.
3. IF ORBIT/LOOK are deferred, THE `CameraSettings` / `CameraRig` code SHALL contain a clear
   comment noting they are intentionally unimplemented and tracked for a future milestone.

---

### Requirement 9: Gamepad input bindings

**User Story:** As a player using a gamepad, I want ship movement, camera, and interaction
actions to actually respond to gamepad input, so that I can play without a keyboard.

#### Acceptance Criteria

1. THE `project.godot` `[input]` section SHALL include gamepad (joypad button/axis) events for
   `ship_forward`, `ship_backward`, `ship_left`, `ship_right`, `dock`, `interact`, `pause`,
   `camera_zoom_in`, `camera_zoom_out`, `camera_rotate_left`, `camera_rotate_right`, in addition
   to the existing keyboard/mouse bindings (bindings are additive, not replacements).
2. THE `interact` and `camera_rotate_right` actions SHALL NOT both be bound to the same keyboard
   key (`E`) — reassign one to a non-conflicting key.
3. WHEN a gamepad is connected, THE `InputManager`'s existing gamepad-detection logic SHALL
   correctly reflect gamepad as the active input method upon receiving a bound gamepad input.

---

### Requirement 10: Ocean/buoyancy visual consistency

**User Story:** As a player, I want my ship's pitching and rolling to visually match the ocean
surface beneath it, so that the water feels physically consistent rather than disconnected from
the ship.

#### Acceptance Criteria

1. THE shader parameters set by `OceanController._apply_settings()` SHALL match the actual
   uniform names declared in `resources/shaders/water.gdshader` (verify by reading both files
   side by side; fix whichever side is wrong).
2. THE CPU-side wave height function in `WaveGenerator.gd` (used by `BuoyancySimulator`) SHALL
   use the same wave parameters (height, length, speed, wind direction) as `OceanSettings.tres`
   applies to the GPU shader, so hull motion visually tracks the rendered wave surface.
3. THIS requirement SHALL be verified visually (running the game and observing the ship on
   water), not solely by code inspection — a mismatch can exist even when both sides compile and
   run without error.

---

## Out of Scope

- Any new gameplay feature (buildings, ships, factions, combat mechanics). That is
  milestone-m4-empire-escalation's job.
- Rebalancing existing ship/building/tech stats beyond what's needed to fix D3 (Ghost Ship).
- Adding new test coverage beyond the M2 property tests explicitly listed in Requirement 7
  (combat/economy/fleet/faction test coverage is tracked as a follow-up, not blocking M4).
- Free-placement building system, additional factions (Britain/Spain/Independent Cities/Ancient
  Order), region tiers — all deferred to M4.
