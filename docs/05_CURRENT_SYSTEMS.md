# 05_CURRENT_SYSTEMS.md

> Version: 1.0
> Status: Living Document — ground truth of what is actually implemented
> Owner: Project Lead

---

# Purpose

This document exists because a large amount of gameplay code was written in a single commit
(`3c36dc2`, ~526 files / ~92k insertions) with **no accompanying design docs**. Every other
document in `/docs` and `/Prd.md` describes intent; this document describes **what actually
runs today**, file by file, including known defects.

Read this before touching `scripts/world/`, `scripts/managers/`, `scripts/combat/`, or
`scripts/ui/IslandMenu.gd`. Per `AGENTS.md`: *"Never duplicate systems. Reuse existing code."*
If a system described here already does what you were about to build, extend it — do not
write a second one.

This document will go stale. When you change a system described here, update its entry in
the same pull request.

---

# 1. What already exists (do not rebuild these)

## Combat — fully working
`scripts/combat/` + `scripts/world/ShipCombat.gd`

- `ShipCombat.gd` — health, damage, broadside fire, fire-rate cooldown, `died` signal. Applies
  captain + tech modifiers to damage.
- `Cannonball.gd` — `RigidBody3D` projectile, straight-line velocity, despawns on contact or timeout.
- `EnemyAI.gd` — state machine (IDLE/PATROL/CHASE/ATTACK/FLEE), picks broadside side, checks
  `FactionManager` hostility, flees at low HP.
- `EnemySpawner.gd` — spawns/caps enemy population, weights faction selection by reputation
  (worse reputation with a faction → more of their ships spawn), exposes `spawn_hunter()`.
- `LootDrop.gd` / `LootTableData.gd` — death drops rolled from a faction/boss-specific loot table.

**Known gaps:** no cannonball arcing (straight-line only), no armor/hull-facing variance, no
boarding, no multi-ship fleet coordination.

## Economy & Buildings — fully working
`scripts/managers/ResourceManager.gd` + `scripts/world/Island.gd` + `scripts/world/BuildingData.gd`

- `ResourceManager` (autoload): gold/wood/iron/rum/research, per-resource storage caps, a global
  10-second economy tick signal, `add_resource` / `spend_resource` / `can_afford`.
- `Island.gd`: tracks `built_buildings` per island, listens to the economy tick, produces
  resources per building. `build_structure()` / `upgrade_structure()` spend resources and swap
  in the next `BuildingData` tier. Buildings snap into pre-authored `Marker3D` slots (**not**
  free placement). Persists built-building IDs through `SaveManager`.
- 10 populated `BuildingData` tiers exist: Academy, Farm, Fortress, LumberMill, Market, Mine,
  Shipyard, Tavern, Warehouse, Watchtower.

**Known gaps:** fixed building slots (no free placement), only 10 building types (no deep
production chains), colonize/capture flow is broken (see §2).

## Fleet, Captains, Tech — fully working
`scripts/managers/FleetManager.gd`, `scripts/world/CaptainData.gd`, `scripts/managers/TechManager.gd`

- `FleetManager`: owned ships/captains rosters, active ship/captain index, background trade/patrol
  missions that tick gold/reputation on a timer, save/load.
- `CaptainData`: XP/level curve with computed speed/turn/damage/health modifiers. 5 populated
  captains (Redbeard, Anne, Bartholomew, Jack, Mary).
- `TechManager`: unlocked `TechData` resources recalculate multiplicative global modifiers
  (health/damage/speed/storage). 2 populated techs (ReinforcedHulls, AdvancedCannons).

## Factions & world events — shallow but present
`scripts/managers/FactionManager.gd`, `scripts/world/FactionData.gd`, `scripts/managers/EventManager.gd`

- `FactionManager`: per-faction reputation (-100..100), `is_hostile()`, dispatches a "hunter" ship
  when Royal Navy reputation is very negative. This is the closest existing thing to a raiding
  mechanic — **it is the extension point for the new Empire Threat system (see M4 spec)**, not a
  system to replace.
- 4 populated factions: PirateClans, RoyalNavy, MerchantGuild, GhostFaction. The PRD's
  "Independent Cities" and "Ancient Order" do not exist yet.
- `EventManager` drives random ocean events (merchant convoys, floating treasure, a ghost-ship
  boss). **See known defect below — this script currently runs as two live instances at once.**

## Player-facing UI for all of the above
`scripts/ui/IslandMenu.gd` (largest UI file in the project)

Tabbed, fully code-built UI: Buildings (build/upgrade), Shipyard (buy ships, gated on owning a
Shipyard), Tavern (hire captains, gated on owning a Tavern), Fleet (assign missions), Research
(unlock tech), Trade (sell resources), and a "Colonize (1000 Gold)" button for neutral islands.
This already covers most of the PRD's colony/economy/fleet screens — extend this file rather
than building parallel UI.

## World/ships/ocean — M2 scope, functional with documented gaps
`ShipController`, `ShipMovement`, `ShipVisuals`, `BuoyancySimulator`, `WaveGenerator`,
`OceanController`, `CameraRig`, `DockingSystem`, `EnvironmentController`, `WorldManager`. See
`.kiro/specs/milestone-m2-playable-world/tasks.md` bug-fix notes and §2 below for open gaps.

---

# 2. Known defects (fix in milestone-m3-stabilization)

These were confirmed by direct code inspection on 2026-08-03. None of these are hypothetical —
each is a specific file and a specific broken behavior.

| # | Defect | File(s) | Effect |
|---|--------|---------|--------|
| D1 | `EventManager.gd` runs as both a global autoload **and** a separate scene-local node (`Systems/EventManager` in `World.tscn`, same script). | `project.godot` autoload list; `scenes/world/World.tscn` | Both instances run `_process()` independently while World is active — random ocean events (merchant convoys, treasure, ghost ship) likely schedule/fire twice concurrently. |
| D2 | `FactionManager.get_player_faction()` loads `res://resources/factions/PlayerFaction.tres`, which does not exist. | `scripts/managers/FactionManager.gd`; missing `resources/factions/PlayerFaction.tres` | Every call into the colonize/capture flow (`Island.gd`, `IslandMenu.gd`) gets `null` back and silently no-ops or errors — **island capture and colonization are currently broken.** |
| D3 | `GhostShipStats.tres` sets properties (`ship_name`, `ship_tier`, `speed`, `turn_speed`, `reload_time`) that do not exist on the `ShipStats` schema (real names: `max_speed`, `turn_rate`, `fire_rate`, ...). | `resources/enemies/GhostShipStats.tres` vs `scripts/world/ShipStats.gd` | Godot silently drops the unknown keys on load. The Ghost Ship boss gets default movement/turn/fire-rate instead of its intended boss-tier stats; only `max_health`, `cannon_damage`, `cannon_range` (property names that happen to match) apply. |
| D4 | `ScreenshotHarness.gd` (a dev diagnostic script that boots into World.tscn and drives synthetic input to capture screenshots) is registered as a production autoload. | `project.godot` `[autoload]`, last entry | Every real run of the game boots this debug scaffold alongside actual game managers. |
| D5 | `ScenePaths.gd` and `UIConstants.gd` are dead code — grepped, referenced nowhere outside their own file. | `scripts/core/ScenePaths.gd`, `scripts/core/UIConstants.gd` | Confusing to future readers/agents; violates "no dead code" in the AGENTS.md PR checklist. |
| D6 | Two orphaned default `.tres` resources exist and are loaded by nothing: `resources/world/ShipStats.tres`, `resources/world/IslandData.tres`. The former references `resources/materials/ShipMaterial.tres`, which does not exist anywhere. | `resources/world/ShipStats.tres`, `resources/world/IslandData.tres` | Harmless while unreferenced, but a landmine if anyone wires them in later — the dangling `ShipMaterial.tres` reference would break on load. |
| D7 | `SaveManager.gd`'s doc header says "M1: no persistent data is written / all methods are no-op stubs." The actual implementation is a complete JSON save/load system (position, health, economy, per-island buildings, fleet, tech, faction reputation, auto-save every 60s and on dock). | `scripts/managers/SaveManager.gd` | Misleading to any agent reading the header before the body — violates the "documentation must explain purpose/responsibilities accurately" rule. |
| D8 | Five M2 property-test files are genuinely empty (0 bytes): `test_camera_properties.gd`, `test_docking_properties.gd`, `test_input_properties.gd`, `test_ocean_properties.gd`, `test_ship_properties.gd`. | `tests/world/` | Zero regression protection for ship movement, camera, docking, ocean, or input — matches the M2 tasks.md bug-fix note, still unresolved. |
| D9 | `CameraRig`'s ORBIT and LOOK modes exist as enum values with no distinct behavior branch — only FOLLOW is implemented. No SpringArm3D collision configured. | `scripts/world/CameraRig.gd` | Camera can clip through islands; mode switch is cosmetic only (documented M2 gap, still open). |
| D10 | No gamepad axis bindings exist in `project.godot`'s `[input]` section despite `InputManager` detecting gamepad input. `interact` and `camera_rotate_right` are both bound to `E`. | `project.godot` | Gamepad is undetectable/unusable; keyboard has a real key conflict. |
| D11 | `BuoyancySimulator` uses a CPU-side Gerstner-style wave function (`WaveGenerator.gd`) to compute float-point heights, while `OceanController` drives a separate GPU shader (`water.gdshader`) with its own wave parameters. These two wave computations are independent implementations, not guaranteed to visually agree — ships may pitch/roll out of sync with the visible wave surface. | `scripts/world/WaveGenerator.gd`, `scripts/world/OceanController.gd`, `resources/shaders/water.gdshader` | Visual mismatch between hull motion and water surface (exact severity not measured — needs an in-editor visual check, not just a code read). |
| D12 | No test coverage exists for combat, economy, fleet, tech, or factions — the systems in §1 that make up most of the actual gameplay. | `tests/` | Any future change to `ShipCombat`, `Island.gd`, `ResourceManager`, etc. has no regression safety net. |

Zero test coverage for anything in §1 beyond audio/scene/settings (M1-era systems only).

---

# 3. Regions and islands — current mapping

6 populated `IslandData` instances exist today: PortRoyal, Tortuga, SkullCove, FrozenIsland,
VolcanoIsland, plus one orphaned generic default. The PRD's "World Structure" (§6) names 8
aspirational regions (Beginner Waters, Tropical Seas, Merchant Routes, Pirate Territory, Frozen
Sea, Volcanic Sea, Royal Navy Waters, Ancient Ocean) but **no region grouping or tiering concept
exists in code today** — every island is a peer, differentiated only by its `IslandType` enum
(NEUTRAL/FRIENDLY/ENEMY/CAPITAL/LEGENDARY) and owning faction. Region tiers are introduced by
milestone-m4-empire-escalation (see that spec's `RegionData` resource).

---

# 4. Autoload registry (current, for reference)

```
GameManager, SaveManager, SceneManager, SettingsManager, AudioManager,
ResourceManager, FleetManager, TechManager, EventManager, FactionManager,
ScreenshotHarness   <- D4: should not be here in production builds
```
