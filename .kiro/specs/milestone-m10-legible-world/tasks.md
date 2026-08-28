# Implementation Plan — M10 The Legible World

> **Read before starting:** `docs/15_MASTER_PLAN.md`'s M10 entry and §8, this spec's
> `requirements.md`/`design.md`, and `docs/11_WORLD_MAP.md` (Compact/Expanded coordinates,
> per-region specs — the exact numbers this milestone implements against).
>
> **Re-verify scope before starting.** This spec was written 2026-08-26, before M9 (Presentation
> Pass) had been implemented. Confirm against the then-current `docs/05_CURRENT_SYSTEMS.md` that
> nothing in M9's actual implementation changed an assumption this spec makes (e.g. `WorldHUD`
> structure, if M9's HUD-arbitration work touched files this milestone also touches).
>
> **Done, 2026-08-27 — several assumptions above had already drifted by the time this milestone
> started; see `docs/05_CURRENT_SYSTEMS.md`'s "M10 — The Legible World" section, "Corrections
> found during re-verification," for the full list** (IslandData already had world_position/
> region_id fields at Compact values; EnemySpawner's spawn box was already player-relative, not a
> world-origin box; the "spawn regions" the spec describes don't exist as a literal entity;
> WorldManager already had a scaffolded discovery signal; building art was ~90% already assigned).
>
> **Verification commands:**
> ```
> <godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
> <godot-binary> --path d:/Pirate-game scenes/debug/CaptureHarness.tscn --capture-dir=<abs path>
> ```
> The second command is required at checkpoint, not optional — this milestone is fundamentally
> visual/experiential (map, discovery, weather), and M9 established that a passing test suite
> alone is not sufficient sign-off for that category of work.
>
> **Update, same day:** Godot 4.3 was not present in the implementing environment (only a
> WinGet-installed 4.7.1, which fails outright on this project — `CampaignManager.gd`,
> `TutorialManager.gd`, and the GUT addon itself fail to parse under it, a real
> version-incompatibility, not a fixable one-liner). Installed a real 4.3 side-by-side via
> `winget install --id GodotEngine.GodotEngine --version 4.3 --force`. **The GUT suite has now
> actually been run: 326/326 passing, 0 failures — first 0-known-failures result in the project's
> history**, closing `test_property_21_lod_distance_transitions` for real. Verification caught and
> fixed two real bugs before this result (a GDScript static-typing parse error in
> `WorldMapScreen.gd`, and a stale `.godot` global-class cache from the earlier failed 4.7.1 run
> that needed a full headless-editor rescan, not just deletion, to rebuild correctly) plus updated
> a pre-existing test file (`test_world_map_layout.gd`) that still hardcoded the pre-Expanded ring
> bands and the original 6-island count. See the full run detail in this file's task entries below.
>
> **Headful `CaptureHarness` also run** (5 frames, t=0s/1s/3s/7s/12s of the game's default Chapter 1
> boot sequence, reviewed by a human): HUD elements never overlap (including the new "Map" button —
> sits cleanly below "Log", no collision with the resource bar), tutorial dialogue displays and its
> fade-out tween works, live combat HUD (cannon reload state) updates correctly, ocean renders
> continuously with no visible seam or pop at the near/far ring boundary, multiple islands visible
> on the horizon confirming the Expanded map reads as a bigger world. **This harness runs the
> game's default boot sequence, not a scripted tour of M10 features** — it did NOT exercise
> opening `WorldMapScreen` itself, crossing far enough from the ship to see the LOD far-ring
> distinctly, crossing into a different region to see a weather-multiplier change, or a hull
> damaged past the new sinking threshold. Those remain visually unconfirmed (though each is backed
> by a passing unit-level GUT test) — a deliberate, longer manual playthrough would be needed to
> see them on screen.

Sequenced as waves — Ocean LOD first since it gates the map-coordinate wave; the remaining waves
touch disjoint systems and can run in any order or in parallel if multiple tracks are available.

---

## Wave 1 — Ocean LOD (gates everything else)

- [x] 1. Read `test_property_21_lod_distance_transitions` in full before designing anything — it
      may already specify the exact distance-band/transition API expected.
  - **Done.** It only asserts `OceanController.has_method("get_lod_level")` — a thin contract, not
    a rich distance-band spec. The real quality bar for "not visually abrupt" (AC 1.2) is the
    headful capture review, which has not happened (see the verification-status note above).
  - _Requirements: 1.1_
- [x] 2. Implement distance-based LOD for the ocean's rendered mesh (ring-based mesh density
      reduction, per `design.md`), without changing `WaveGenerator`'s CPU sampling path that
      `BuoyancySimulator` depends on.
  - **Done.** `scenes/world/Ocean.tscn`'s single 14,641-vert `PlaneMesh` split into two concentric
    rings sharing one `ShaderMaterial`: `WaterMeshNear` (300×300, 60×60 subdiv, same density as
    before) and `WaterMeshFar` (1200×1200, 40×40 subdiv, Y-offset −0.05 to avoid z-fighting where
    they overlap). Both recenter under the camera together every frame via the existing
    `OceanController._follow_camera()`, unchanged — so there's no runtime LOD-level switching and
    nothing to visually pop. `OceanController.get_lod_level(distance) -> int` added.
    `WaveGenerator.get_water_height_at()` untouched.
  - _Requirements: 1.1, 1.3_
- [x] 3. Verify buoyancy correctness is unaffected at any distance from camera — run the existing
      buoyancy property tests unmodified; they should still pass.
  - **Confirmed.** `test_ship_properties.gd`'s buoyancy/wave-interaction properties (5/5) and
    `test_ocean_properties.gd` (5/5) both pass in the real GUT run.
  - _Requirements: 1.3_
- [x] 4. Verify the LOD transition isn't visually abrupt at cruise speed via a headful capture
      crossing a boundary, reviewed by a human.
  - **Partially confirmed.** The 5-frame `CaptureHarness` capture (reviewed) shows continuous,
    seamless ocean with no visible crack/pop at any point — but the ship never sails far enough
    from camera in this short default-boot capture to cross the near/far ring boundary (150u)
    on screen. The design itself structurally can't produce a "pop" (both rings are always
    rendered together, recentered under the camera every frame — there's no runtime LOD-level
    switching to pop, per `docs/05_CURRENT_SYSTEMS.md`'s M10 section), so this is graded
    confirmed-by-design plus partial visual confirmation, not a full boundary-crossing capture.
  - _Requirements: 1.2_
- [x] 5. Confirm `test_property_21_lod_distance_transitions` now passes — this closes the
      project's one standing test failure.
  - **Confirmed.** Real GUT run: 326/326 tests passing, 0 failures — the first 0-known-failures
    result in the project's history.
  - _Requirements: 1.1_

## Wave 2 — Expanded map layout

- [x] 6. Add `world_position`/`region_id` fields to `IslandData.gd`; author them on all 6 existing
      islands using `docs/11_WORLD_MAP.md` §4b's Expanded coordinates.
  - **Done, with correction.** The fields already existed (at Compact values) before this
    milestone started — only the 6 islands' *values* needed updating to Expanded (×2.5 of
    Compact, confirmed exact match against `docs/11_WORLD_MAP.md` §4b's table).
  - _Requirements: 2.1, 2.3_
- [x] 7. Make `World.tscn`'s island node transforms read from `IslandData.world_position` at scene
      setup (single source of truth going forward) rather than maintaining both independently.
  - **Done.** `Island.gd::_ready()` now writes `global_position.x`/`.z` from
    `island_data.world_position` whenever real `island_data` was assigned (skipped for the
    placeholder `IslandData.new()` fallback, which has no real position). `World.tscn`'s authored
    transforms were also updated to the same values, kept in sync for accurate editor preview.
  - _Requirements: 2.1, 2.3_
- [x] 8. Move the player spawn point and the three authored ambient-enemy spawn regions to match
      the new island positions.
  - **Done, reinterpreted.** No literal "spawn region" entity exists (see the drift note at the
    top of this file) — `PlayerShip`'s spawn transform and the 3 `EnemyShip1-3` placeholder
    transforms in `World.tscn` were scaled ×2.5 along with the islands instead.
  - _Requirements: 2.2_
- [x] 9. Replace `EnemySpawner`'s hardcoded ±100 fallback spawn box with an `@export`ed value, set
       to the Expanded-appropriate extent on the scene instance, not the script default.
  - **Already done before this milestone.** `min_spawn_distance`/`max_spawn_distance` are already
    `@export`ed and computed relative to the player's live position, not the world origin — this
    self-scales with map size with no change needed. The spec's premise (a world-origin-centered
    ±100 box) no longer matched the code.
  - _Requirements: 2.4_
- [x] 10. Verify ring ordering (tier-1 closer than tier-2, tier-2 closer than tier-3) still holds
       at the new coordinates, and that a deepest voyage measures ≈55s at cruise speed.
  - **Confirmed via `tests/test_world_map_layout.gd`** (updated for Expanded's bands and the 3
    new islands, then re-run — all 8 tests in the file pass): ring-band membership, strict
    tier-ordering, ≥40u spacing (all pairs, including the 3 new islands), and the two-way
    island↔region relationship all hold. Actual in-game sail-time-in-seconds not separately
    stopwatched, but the coordinate math is exact (×2.5 uniform scale of Compact, matching
    `docs/11_WORLD_MAP.md` §4b's stated bands and the ≈55s target derived from cruise speed).
  - _Requirements: 2.5, 2.6_

## Wave 3 — World map UI

- [x] 11. Build `scenes/ui/WorldMapScreen.tscn`/`.gd`: concentric region rings, island markers from
       `IslandData.world_position`, themed via `PirateThemeBuilder.build()`.
  - **Done.** Ring radii from new `RegionData.display_ring_radius` field (275/450/675u) rather
    than hardcoded in UI script, per `AGENTS.md`'s data-over-code rule.
  - _Requirements: 3.1_
- [x] 12. Player position/heading marker, reusing `WorldHUD`'s existing compass data source rather
       than re-deriving heading independently.
  - **Done.** Same `player_ship` group lookup + `global_position`/`global_rotation_degrees.y` data
    WorldHUD's compass needle reads, snapshotted at `open()` time (the screen pauses the game the
    same way `CaptainsLog` does, so a live per-frame update isn't needed).
  - _Requirements: 3.3_
- [x] 13. "View Log" button opening the existing `CaptainsLog` screen, satisfying the
       objectives-visible requirement without duplicating that UI.
  - **Done.**
  - _Requirements: 3.4_
- [x] 14. HUD button to open the map, built via the same dynamic-positioning pattern
       `WorldHUD._create_captains_log_button()` already establishes.
  - **Done.** `_create_world_map_button()`, a fourth child of `TopRightPanel`.
  - _Requirements: 3.5_

## Wave 4 — Discovery / fog of war

- [x] 15. Add a continuous proximity check (reusing `DockingSystem`'s existing range-check
       pattern) that flips `IslandData.discovered` to `true` within a configurable radius of an
       undiscovered island, independent of docking.
  - **Done.** `WorldManager._check_island_discovery()` (called from `_process()`), configurable
    `@export var discovery_radius: float = 80.0`.
  - _Requirements: 4.1_
- [x] 16. Undiscovered islands render hidden or as an unrevealed marker on the Wave 3 map screen.
  - **Done.** Hidden entirely (not a "?" marker) — see the design note in `WorldMapScreen.gd`.
  - _Requirements: 4.2_
- [x] 17. Confirm discovery state round-trips through `SaveManager` using the existing
       `IslandData`/`Island` save path (no new persistence mechanism).
  - **Done, with a real bug found and fixed.** It did NOT already round-trip — `discovered` was
    never actually written to the save dict at all (only built-building ids were), so it silently
    reset to `false` on every load regardless of runtime state. Fixed: `"islands"` entries are now
    `{"buildings": [...], "discovered": bool}`; `load_game()` handles both the old flat-array
    format (pre-M10 saves) and the new dict format.
  - _Requirements: 4.3_
- [x] 18. Wire the new discovery signal to dispatch `CampaignManager`'s existing `DISCOVER_ISLAND`
       objective condition.
  - **Done.** Factored the existing (dock-only) discovery-dispatch logic out of
    `_on_player_docked()` into a shared `_on_island_discovered()`, now connected to both
    `player_docked` and the new `island_discovered` signal.
  - _Requirements: 4.4_

## Wave 5 — Per-region weather and enemy types

- [x] 19. Add weather-relevant fields to `RegionData` (fog/wave-intensity multipliers or
       equivalent); `EnvironmentController` reads them on region change.
  - **Done.** `wave_intensity_multiplier`/`fog_density_multiplier` (Beginner 1.0/1.0, Contested
    1.3/1.2, Imperial 1.6/1.4). Wave intensity scales `OceanSettings.wave_height`/`wave_speed` on
    region change (checked once/second, not per-frame); fog density is authored but has no shader
    hook to apply to yet (the water shader's fog is horizon-color tinting, not a density param).
  - _Requirements: 5.1_
- [x] 20. New `EventData` resource; author one `.tres` per existing hardcoded `EventManager`
       event; `EventManager` loads/rolls from `resources/world/events/*.tres` using the same
       `DirAccess`-scan pattern `EmpireManager`/`CampaignManager` already use.
  - **Done.** `scripts/world/EventData.gd` + 3 `.tres` (`MerchantConvoy`/`FloatingTreasure`/
    `GhostShipBoss`, the last with lower weight and `min_region_tier: 2`). Weighted-random pick
    gated on the player's current region tier, replacing the old flat `randi() % 3`.
  - _Requirements: 5.2_
- [x] 21. Per-region enemy-type roster (via `RegionData` or `AIProfileData`, per `design.md`);
       `EnemySpawner` selects from it instead of always spawning the same base enemy.
  - **Done.** `RegionData.enemy_ship_pool: Array[ShipStats]` (Beginner: Sloop/Dinghy, Contested:
    Schooner/Brigantine/Corvette, Imperial: Frigate/Galleon). `_spawn_enemy()`/`spawn_hunter()`
    pick randomly from the current region's pool before applying the existing
    `compute_spawn_multiplier()` on top; falls back to old behavior if a region's pool is empty.
  - _Requirements: 5.3_
  - **Process note:** this wave's implementation was drafted by a background agent in an isolated
    git worktree (it doesn't share this session's other uncommitted changes), then merged into the
    main working tree by hand. Two real bugs were caught during that merge and fixed before
    landing: an index-out-of-bounds risk in the event-selection fallback branch, and a
    shared-Resource aliasing bug in `EnvironmentController` that would have made successive
    region-weather changes compound instead of applying fresh. See
    `docs/05_CURRENT_SYSTEMS.md`'s M10 section, Requirement 5, for detail.

## Wave 6 — Ship damage visuals follow-up

- [x] 22. Add a hull-sinking visual threshold band below the existing M8 critical state (heavier
       smoke, visual-only list/tilt), same `ShipDamage.pool_changed` signal and cached-clean-state
       pattern M8 established.
  - **Done.** `ShipVisuals.hull_sinking_threshold` (0.10, below `hull_critical_threshold`'s 0.25):
    heavier smoke via the existing particle system's velocity/scale (not a second system), plus a
    `sinking_list_degrees` (9°) roll on `_model_instance` only — never the parent `ShipController`
    transform, so `BuoyancySimulator`/`FiringSolver` are unaffected. New test:
    `test_ship_damage_visuals.gd::test_sinking_damage_lists_the_hull_and_heals_upright`
    (not run — no working binary — but follows the exact pattern of the two existing passing
    tests in the same file).
  - _Requirements: 6.1, 6.2_

## Wave 7 — 2–4 new islands

- [x] 23. Author 2–4 new `IslandData` resources across the existing three regions, following the
       established dossier format (name, type, region, rumor/flavor hook), placed in the Wave 2
       coordinate space.
  - **Done.** Three new islands, one per region: Pelican Cay (Beginner, neutral), Blackwater Shoal
    (Contested, enemy — Royal Navy), Isla del Rey (Imperial, enemy — Spanish Empire). Full
    dossiers added to `docs/11_WORLD_MAP.md` §6; each region's `.tres` `island_ids` array updated;
    all placed ≥100u clear of every neighbour (well past the 40u physical minimum), within their
    region's Expanded ring band.
  - _Requirements: 7.1, 7.2_

## Wave 8 — Building-model art sourcing

- [x] 24. Survey available Kenney-style stock asset packs (check for any already-vendored but
       unused packs first, then externally available ones) for building/structure models
       suitable for the 10 chains × 5 levels.
  - **Done.** 45 of 50 building-level combinations already had real vendored Kenney models
    assigned from an earlier undocumented pass (predates this milestone). Only the Farm chain (5
    files) had none. Searched `assets/models/` for a fit and found `crate-bottles.glb` —
    appropriate once the actual building was identified as the Rum Distillery (an id-naming
    holdover; `building_name`/`produces_resource` both say rum, not farming).
  - _Requirements: 8.1_
- [x] 25. If suitable assets found: integrate via `BuildingData.model_path` for as many
       level/building combinations as reasonably covered (a 3-stage reuse pattern is an
       acceptable partial outcome).
  - **Done, full coverage.** All 50 of 50 now have `model_path` set — better than the
    "partial/3-stage" outcome the spec treated as acceptable. Still one shared model per whole
    chain (not 5 bespoke per-level models); `Island.gd`'s scale-up-by-1.2× remains the only
    per-level visual differentiator.
  - _Requirements: 8.2_
- [x] 26. If no suitable assets found: document the search and the negative result in
       `docs/10_ASSET_REQUESTS.md` rather than leaving it silently open.
  - **N/A — assets were found (task 25).** `docs/10_ASSET_REQUESTS.md` updated with a status
    callout regardless, documenting the actual resolution (stock reuse, not the custom-generation
    prompts the doc was originally written for) so it doesn't read as an open request anymore.
  - _Requirements: 8.3_

## Wave 9 — Minimal save-schema version stamp

- [x] 27. Add `SAVE_SCHEMA_VERSION` constant and `save_schema_version` field to
       `SaveManager.save_game()`/`load_game()`, defaulting absent values to `0`. No migration
       logic — field only.
  - **Done.** `SaveManager.SAVE_SCHEMA_VERSION := 1`.
  - _Requirements: 9.1, 9.2, 9.3_

## Wave 10 — Documentation and checkpoint

- [x] 28. Update `docs/05_CURRENT_SYSTEMS.md` (new "M10 — The Legible World" section),
       `docs/14_SYSTEM_INVENTORY.md` (status rows), `docs/15_MASTER_PLAN.md` (M10 exit criteria).
  - **Done.** Also updated `docs/11_WORLD_MAP.md` §7 (the "what's needed" gap table) and §3/§4
    (Expanded is now the live layout, not a future target) since they were directly touched by
    this milestone's own work.
  - _Requirements: 10.1, 10.2, 10.3_
- [x] 29. **Checkpoint — M10 complete**
  - **Done, 2026-08-27.** A real Godot 4.3 binary was installed (`winget install --id
    GodotEngine.GodotEngine --version 4.3 --force`, side-by-side with the 4.7.1 that was already
    present and fails to even parse this project) and used to actually run both required
    verification commands, not self-reported:
    - GUT suite: **326/326 passing, 0 failures** — the first 0-known-failures result in the
      project's history, closing `test_property_21_lod_distance_transitions`. Two real bugs were
      found and fixed to reach this (a GDScript static-typing error in `WorldMapScreen.gd`, a
      stale global-class cache needing a full headless-editor rescan) plus a stale pre-existing
      test file updated for the Expanded layout and 3 new islands. See the note near the top of
      this file for the full story.
    - Headful `CaptureHarness`: run and reviewed (5 frames spanning the default Chapter 1 boot
      sequence). No HUD element overlaps another (including the new "Map" button), the
      previously-unthemed-then-fixed screens weren't touched by this milestone so weren't
      re-checked here, ocean renders continuously with no LOD seam, tutorial dialogue and its
      fade animations work, live combat HUD updates correctly. **Did not** exercise
      `WorldMapScreen` itself, an actual LOD-ring boundary crossing, a region-weather change, or
      the new ship-sinking visual state — see the capture-review note near the top of this file.
  - No stray Godot processes left running (checked after every run in this session); capture
    output written to session scratch space, not committed to the repo.
  - **What this checkpoint does NOT cover:** the map/discovery/weather/sinking-visual features
    that only a longer manual playthrough would put on screen. Recommend a human (or a follow-up
    session) actually opens the map, sails to a ring boundary and into a different region, and
    fights a ship down to near-zero hull at least once before fully trusting this milestone's
    visual claims — the code and unit tests support it, but "reviewed by a human" per this
    project's own established discipline (`docs/07_AI_AGENT_WORKFLOW.md`) should mean *that*,
    not just the default boot sequence this capture happened to run.

## Notes

- Waves 5–9 are independent of Waves 1–4 and of each other — reorder or parallelize freely if
  multiple implementation tracks are available, per `docs/15_MASTER_PLAN.md` §4's note on M8/M10
  historically running against disjoint systems. (In practice: Wave 5 ran as a background agent in
  an isolated worktree while Waves 1/2/4/6/7/8/9 ran directly in the main session; Wave 3's HUD
  button was deferred until M9's concurrent edits to `WorldHUD.gd` had settled, to avoid a
  lost-update race on a shared uncommitted file.)
- Wave 8 (building art) may close with "no suitable assets found" as a legitimate, documented
  outcome — do not let it block the rest of the milestone, and do not attempt to generate or
  commission original 3D art as a substitute; that's outside what this milestone can respons­ibly
  scope. (In the event, assets *were* found — full 50/50 coverage — so this didn't come up.)
- **This milestone's implementation happened in parallel with M9 in the same working tree,
  uncommitted.** If you're picking this up fresh: check `git status`/`git diff` before assuming
  any file is in the state this document describes — both milestones' changes are still sitting
  as uncommitted working-tree edits as of this writing, not separate commits or branches.
