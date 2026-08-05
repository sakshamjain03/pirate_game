# Implementation Plan: Milestone M4 — Empire Escalation

## Overview

This milestone depends on milestone-m3-stabilization being complete (in particular, the
colonize/capture flow must already work). Do not start Task 1 until M3's Task 21 checkpoint has
passed.

As with M3, every task touches a small number of files and has an explicit verification step.
Read `docs/05_CURRENT_SYSTEMS.md` and this spec's `design.md` in full before Task 1 — several
tasks depend on understanding exactly how `Island.gd`, `FactionManager`, and `EnemySpawner`
already work, so you extend them correctly instead of duplicating their logic.

---

## Tasks

- [ ] 1. Add is_empire field to FactionData
  - Open `scripts/world/FactionData.gd`, add `@export var is_empire: bool = false`
  - Open `resources/factions/RoyalNavy.tres`, set `is_empire = true`
  - **Verify:** load `RoyalNavy.tres` and confirm `is_empire == true`; load `PirateClans.tres` and confirm `is_empire == false` (default)
  - _Requirements: 1.1, 1.2, 1.4_

- [ ] 2. Create SpanishEmpire faction
  - Create `resources/factions/SpanishEmpire.tres` following the exact structure of `RoyalNavy.tres`, with a distinct `id`, `name`, sail/hull colors, and `is_empire = true`
  - **Verify:** load the resource, confirm all fields are populated and colors are visually distinct from the other 4 factions (compare RGB values, not just "looks different")
  - _Requirements: 1.3_

- [ ] 3. Create RegionData resource class
  - Create `scripts/world/RegionData.gd` as a `Resource` with fields: `id: String`, `display_name: String`, `tier: int`, `dominant_faction: String`, `activation_notoriety_threshold: float`, `island_ids: Array[String]`
  - **Verify:** the class compiles and can be instantiated with `RegionData.new()` in a test script
  - _Requirements: 2.1_

- [ ] 4. Create the 3 RegionData instances
  - Create `resources/world/regions/BeginnerWaters.tres` (tier 1, dominant_faction matching whichever of PirateClans/MerchantGuild you choose, threshold 0, island_ids = [PortRoyal's id, Tortuga's id])
  - Create `resources/world/regions/ContestedWaters.tres` (tier 2, dominant_faction = RoyalNavy's id, threshold e.g. 60, island_ids = [SkullCove's id, FrozenIsland's id])
  - Create `resources/world/regions/ImperialWaters.tres` (tier 3, dominant_faction = SpanishEmpire's id, threshold e.g. 150, island_ids = [VolcanoIsland's id, the new island from Task 5])
  - **Verify:** load all 3, confirm every existing `IslandData` id appears in exactly one region's `island_ids` (cross-check against the 6 island ids from `docs/05_CURRENT_SYSTEMS.md` §3)
  - _Requirements: 2.2, 2.3, 2.4_

- [ ] 5. Author a second Region 3 island
  - Create a new `IslandData` instance (e.g. `resources/islands/CartagenaOutpost.tres`) of type ENEMY, owned by SpanishEmpire, following the same schema as `VolcanoIsland.tres`
  - Add a corresponding island placement in `scenes/world/World.tscn` (reuse the `Island.tscn` template as existing islands do) at a position in open water distinct from all existing islands
  - Add this island's id to `ImperialWaters.tres`'s `island_ids` (should already be done in Task 4 if sequenced correctly — otherwise fix it now)
  - **Verify:** boot the game, confirm the new island renders in the world at its placed position
  - _Requirements: 2.2 (Region 3 island count)_

- [ ] 6. Create EmpireManager autoload — notoriety core
  - Create `scripts/managers/EmpireManager.gd` as a new autoload with: `signal notoriety_changed(new_value)`, `var notoriety: float = 0.0`, `func add_notoriety(amount: float)` (increments, clamps to ≥0, emits signal)
  - Register it in `project.godot`'s `[autoload]` section, after `FactionManager`
  - Add a documentation header per AGENTS.md conventions
  - **Verify:** call `EmpireManager.add_notoriety(10.0)` from a test script, confirm `notoriety == 10.0` and the signal fired with `10.0`
  - _Requirements: 3.1, 3.5_

- [ ] 7. Wire notoriety gains to combat and colonization
  - In `scripts/world/ShipCombat.gd`'s death handling (or `EnemyAI`/`ShipController`, whichever already knows the destroyed ship's faction), call `EmpireManager.add_notoriety(5.0)` if the destroyed ship's faction has `is_empire == true`, else `add_notoriety(1.0)`
  - In `scripts/world/Island.gd`'s `capture_island()`, call `EmpireManager.add_notoriety(15.0)`
  - **Verify:** destroy one Royal Navy ship in-game, confirm notoriety increases by 5.0 (add a temporary print statement or check via the HUD once Task 15 exists); colonize an island, confirm +15.0
  - _Requirements: 3.2, 3.3_

- [ ] 8. Add idle notoriety decay
  - In `EmpireManager.gd`, track `_last_gain_unix: int` (updated whenever `add_notoriety` is called with a positive amount), and in `_process()` or a periodic timer, if more than 10 real-time minutes have passed since `_last_gain_unix`, decrease `notoriety` at a slow rate (e.g. 1.0 per minute), clamped to `0.0`
  - **Verify:** write a unit test (or manually adjust the idle threshold to 10 seconds temporarily) confirming notoriety decreases after the idle period and never goes below 0
  - _Requirements: 3.4_

- [ ] 9. Region loading and activation checking
  - In `EmpireManager.gd`'s `_ready()`, load all 3 `RegionData` resources from `resources/world/regions/` into `_regions: Array[RegionData]`, initialize `_region_active: Dictionary` with Region 1 = `true`, Regions 2/3 = `false`
  - Implement `func is_region_active(region_id: String) -> bool` and `func get_region_for_island(island_id: String) -> RegionData`
  - Connect `notoriety_changed` to a `_check_region_activation()` method: for each dormant region, if `notoriety >= activation_notoriety_threshold`, set it active and emit `region_activated(region_id)`
  - **Verify:** starting from `notoriety = 0`, confirm Region 1 is active and Regions 2/3 are not; programmatically call `add_notoriety(60)` and confirm Region 2 activates (assuming threshold 60) and `region_activated` fires exactly once
  - _Requirements: 4.1, 4.4, 4.5_

- [ ] 10. Gate Island.gd defender spawning and capture on region activation
  - In `scripts/world/Island.gd`, add a private helper `_should_be_active() -> bool` per design.md §4 (returns `true` if the island's region is null or active)
  - Guard the existing defender-spawn logic and the start of `capture_island()` with this check
  - In `scripts/ui/IslandMenu.gd`, disable the Colonize button (with a tooltip like "This region has not yet drawn attention") when `_should_be_active()` is false for the selected island
  - **Verify:** with Region 2 dormant, dock at SkullCove — confirm no defenders spawn and the Colonize button is disabled; raise notoriety past Region 2's threshold and confirm defenders now spawn and Colonize becomes available
  - _Requirements: 4.2, 4.3_

- [ ] 11. Checkpoint — activation flow sanity pass
  - From a fresh save: verify Region 1 fully playable, Regions 2/3 dormant per Task 10
  - Manually raise notoriety (temporary debug command or by grinding kills/colonization) past each threshold in turn and confirm each region activates once, in order, with the HUD/console reflecting it
  - Do not proceed to Task 12 until this passes cleanly

- [ ] 12. Empire spawn scaling
  - In `scripts/world/EnemySpawner.gd`, add `func compute_spawn_multiplier(region_tier: int) -> float` per design.md §5's formula intent (pure function of tier and `EmpireManager.notoriety`, e.g. `1.0 + (region_tier - 1) * 0.3 + notoriety * 0.002`, tuned so tier 2 ≥ +25% and tier 3 ≥ +60% at representative notoriety values)
  - At the spawn call site, when spawning an `is_empire == true` faction's ship, apply this multiplier to the spawned ship's effective `max_health` and `cannon_damage` (do not mutate the shared `ShipStats` resource in place — apply the multiplier at instantiation time to the instance's runtime values, since `ShipStats` resources are shared across all ships of that tier)
  - **Verify:** spawn the same faction's ship in a tier-1 region and a tier-3 region (may require temporarily forcing a spawn location), compare effective health/damage — tier 3 should show the expected increase; write a small unit test asserting `compute_spawn_multiplier` is non-decreasing in tier for a fixed notoriety and returns identical output for identical inputs (Property M4-5)
  - _Requirements: 5.1, 5.2, 5.3_

- [ ] 13. Confirm non-empire spawns are unaffected
  - Verify (by reading `EnemySpawner.gd`) that the multiplier from Task 12 is only applied when the spawned faction has `is_empire == true` — non-empire spawns (Pirate Clans, Merchant Guild) must use multiplier `1.0` unconditionally
  - **Verify:** write a unit test asserting this — spawn parameters for a non-empire faction are identical regardless of region tier or notoriety passed in
  - _Requirements: 5.4_

- [ ] 14. Checkpoint — combat scaling sanity pass
  - Boot the game with notoriety high enough for Region 3 to be active, fight an empire ship there vs. an empire ship in Region 1 (or compare printed stat values if a live side-by-side isn't practical) — confirm a real difference
  - Do not proceed to Task 15 until this passes cleanly

- [ ] 15. Home island tracking and defense score
  - In `EmpireManager.gd`, add `var home_island_id: String = ""`, set it the first time `capture_island()` succeeds anywhere in the game (hook into the same call site as Task 7's notoriety gain, guarded by `if home_island_id.is_empty()`)
  - Add `func _compute_defense_score() -> float` reading the home island's built Fortress/Watchtower tier from `Island.gd`'s `built_buildings` and any `FleetManager` ships flagged "Defend Home" (see Task 18 for the flag itself — if sequenced before Task 18, treat the ship bonus as 0 for now and revisit)
  - **Verify:** with no defensive buildings built, defense score is a known baseline (likely 0); build a Fortress and confirm the score increases by the expected amount
  - _Requirements: 6.1, 6.2 (first half)_

- [ ] 16. Attack score and raid probability check
  - Add `func _compute_attack_score() -> float` using the highest-tier active region's tier and current notoriety per design.md §5's formula
  - Add a periodic check (a `Timer` node or `_process` accumulator, 15-minute default) plus an on-load check comparing `Time.get_unix_time_from_system()` against a persisted `_last_raid_check_unix`, that rolls a raid attempt using the probability formula in Requirement 6.3
  - **Verify:** temporarily lower the interval and raise the probability floor for local testing; confirm raid attempts occur at roughly the expected rate over several minutes of play, then revert the debug values before committing
  - _Requirements: 6.2 (second half), 6.3_

- [ ] 17. Raid resolution
  - Implement `func _resolve_raid(attacking_faction: FactionData, region: RegionData) -> Dictionary` per design.md §5's exact formula, returning the `RaidReport` shape specified there
  - IF not repelled, deduct the stolen amounts via `ResourceManager.spend_resource()` (or equivalent existing method) for each resource in the report
  - Store the report as `EmpireManager`'s pending unshown report (overwriting any previous unshown report per Property M4-9)
  - Emit `raid_resolved(report)`
  - **Verify:** write unit tests for `_resolve_raid` covering: defense ≥ attack → repelled with empty `stolen`; defense < attack → not repelled with `stolen` amounts ≤ current resource amounts (Property M4-8) and identical output for identical inputs (Property M4-7)
  - _Requirements: 6.4, 6.5, 6.6_

- [ ] 18. Defend Home fleet assignment
  - In `scripts/managers/FleetManager.gd`, add a per-ship boolean flag (or a dedicated `defend_home_ship_ids: Array`) settable via a new small UI control in `IslandMenu.gd`'s existing Fleet tab
  - Update `EmpireManager._compute_defense_score()` from Task 15 to include the bonus for ships flagged this way, excluding the currently player-piloted ship and any ship on an active trade/patrol mission (per Requirement 6.1's exclusions)
  - **Verify:** flag a ship as Defend Home, confirm defense score increases by the expected per-ship amount; confirm the player's active ship never counts even if flagged
  - _Requirements: 6.1_

- [ ] 19. RaidReportScreen UI
  - Create `scenes/ui/RaidReportScreen.tscn` + `scripts/ui/RaidReportScreen.gd` following `DeathScreen`'s `CanvasLayer → Control (FULL_RECT)` structure, displaying faction name, repelled/not-repelled outcome, and stolen resource amounts if applicable, with a single dismiss button
  - Wire it into `World.gd`/`WorldManager.gd` so it auto-shows on World scene load if an unshown `RaidReport` exists in `EmpireManager`, and clears/marks it shown on dismiss
  - **Verify:** manually trigger a raid (Task 16's debug values), reload the World scene, confirm the report displays correctly and dismissing it doesn't re-show on the next load
  - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ] 20. HUD notoriety display
  - In `scripts/ui/WorldHUD.gd`, add a label showing current `notoriety` (subscribe to `EmpireManager.notoriety_changed`), and when a dormant region exists, show the remaining amount until its threshold
  - Subscribe to `EmpireManager.region_activated` and show a one-time dismissable notification naming the region and its dominant faction (reuse `FloatingDamage.gd`'s tween-based transient-text pattern if convenient, or a simple popup panel)
  - **Verify:** boot the game, confirm the notoriety label updates live as notoriety changes, and a region-activation notification appears once when a region crosses its threshold
  - _Requirements: 8.1, 8.2, 8.3_

- [ ] 21. Persistence — save/load all new state
  - In `scripts/managers/SaveManager.gd`, add persistence for: `EmpireManager.notoriety`, per-region active/dormant flags, `home_island_id`, `_last_raid_check_unix`, and the pending unshown `RaidReport` (or null if none)
  - **Verify:** set all of these to non-default values, save, reload the game (or call `load_game()` directly in a test), confirm every value round-trips exactly — write this as an automated test if a save/load test harness already exists for other systems, otherwise verify manually and note in the PR that automated coverage is a follow-up
  - _Requirements: 3.6, 4.6, 6.6_

- [ ] 22. Final checkpoint — full M4 verification
  - Run the full GUT suite — all M1/M2/M3 tests plus any new M4 unit tests pass
  - Run `godot --headless --check-only` — zero errors
  - Full playthrough from a fresh save: confirm Region 1 active/playable immediately, gain notoriety through kills and colonization, watch Region 2 then Region 3 activate in order, confirm empire ships in higher regions are tougher, trigger and observe a raid + RaidReportScreen, confirm save/load preserves everything
  - Update `docs/05_CURRENT_SYSTEMS.md` to add a new §5 "Empire Escalation (M4)" section summarizing `EmpireManager`, `RegionData`, and the raid system, so this milestone doesn't become the next "undocumented system" the audit has to rediscover
  - Confirm every new/modified `.gd` file has an accurate documentation header per AGENTS.md

## Notes

- Tasks 1–5 are pure data/schema additions — no runtime behavior changes yet, safest to do first.
- Tasks 6–11 build and verify the notoriety/activation core before anything depends on it.
- Tasks 12–14 add difficulty scaling on top of a working activation system.
- Tasks 15–19 add the raid simulation and its UI — the most novel logic in this milestone;
  budget the most review attention here.
- Tasks 20–21 are polish/persistence that should not be skipped — an escalation system that
  doesn't survive a save/load or isn't visible to the player fails the actual design goal even if
  the underlying math is correct.
- If Task 12's stat-scaling approach turns out to require mutating shared `ShipStats` resources
  (rather than applying multipliers at spawn time), stop and flag it — mutating a shared Resource
  used by multiple ship instances would corrupt every ship using that tier, and needs a
  deliberate fix (e.g. `ShipStats.duplicate()` per spawn), not a quick patch.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2", "3"] },
    { "id": 1, "tasks": ["4", "6"] },
    { "id": 2, "tasks": ["5", "7", "9"] },
    { "id": 3, "tasks": ["8", "10"] },
    { "id": 4, "tasks": ["11"] },
    { "id": 5, "tasks": ["12", "13"] },
    { "id": 6, "tasks": ["14"] },
    { "id": 7, "tasks": ["15", "16"] },
    { "id": 8, "tasks": ["17", "18"] },
    { "id": 9, "tasks": ["19", "20", "21"] },
    { "id": 10, "tasks": ["22"] }
  ]
}
```
