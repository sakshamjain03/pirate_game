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

**Firing is automatic on arc alignment (M8).** The player does not tap to shoot — they position.
See `docs/navalCombat.md` §4/§5 for the locked design.

- `FiringSolver.gd` — **the single source of truth for "is a hostile in this side's arc?"** Owns
  the arc geometry (`get_broadside_angle`), side selection, range gate, and target choice
  (nearest valid hull per side, wrecks excluded). Its `static are_hostile()` is also what
  `Cannonball._is_friendly()` calls, so the solver can never lock onto a hull its own shot would
  refuse to damage. `target_groups` is exported so a future friendly consort gets a different
  candidate scope rather than a second targeting implementation.
  *This logic used to live privately inside `EnemyAI._get_broadside_angle()`; it was moved here
  and `EnemyAI` now consumes it, so player and AI cannot disagree about "aligned".*
- `ShipCombat.gd` — damage forwarding, per-side reload, `died`, plus the M8 auto-fire loop
  (`_physics_process` fires a side the instant the solver locks and the reload is up),
  `arc_lock_changed` (drives the broadside indicator), and `fire_special_broadside()` — the
  player-timed full volley on both sides at a damage premium, gated on its own longer cooldown.
  Applies captain + tech + `CombatModifiers` to damage.
- `CombatModifiers.gd` — per-ship runtime multipliers (damage / reload / speed / range / arc /
  special cooldown) in two layers: a **battle-long** layer for temporary upgrades and a **timed**
  layer for captain abilities. **Never mutates a `ShipStats` resource** — a `.tres` is shared by
  every hull of its class, so an in-place buff would apply to every Sloop in the game and persist
  into saves. Same duplicate-never-mutate rule as `EnemySpawner.compute_spawn_multiplier()`.
- `EncounterManager.gd` (`World/Systems`) — **the battle boundary.** `start_encounter(EncounterData)`
  spawns a composition, pauses ambient spawning, tracks the objective off existing signals,
  drives the upgrade-offer cadence, resolves victory / defeat / escape, grants rewards, and
  clears all temporary modifiers. Also schedules ambient encounters from an authored pool.
  **Replaced and deleted `WorldEventManager`**, whose whole job was a 5-minute boss timer — the
  boss is now just a Boss-kind `EncounterData`.
- `CaptainAbility.gd` — the player's captain ability button. Reads the *active captain's*
  `active_ability`, so swapping captains swaps the verb and resets the cooldown.
- `Cannonball.gd` — `RigidBody3D` projectile, straight-line velocity, despawns on contact or timeout.
- `EnemyAI.gd` — state machine (IDLE/PATROL/CHASE/ATTACK/FLEE), checks `FactionManager`
  hostility, flees at low HP, three-feeler terrain avoidance. `AIProfileData` governs aggression,
  distance, flee threshold and ammo preference; its `broadside_angle_tolerance` now feeds the
  shared `FiringSolver` as a per-profile arc override. **The AI no longer fires directly** — it
  manoeuvres, and the same auto-fire loop the player uses pulls the trigger. Its old
  `attack_range` (a second, independent firing range of 40 that disagreed with the authored
  `ShipStats.cannon_range`) is gone, replaced by `attack_range_fraction` of the hull's real range.
- `EnemySpawner.gd` — spawns/caps enemy population, weights faction selection by reputation,
  exposes `spawn_hunter()`, and `spawning_enabled` (paused during an encounter).
- `LootDrop.gd` / `LootTableData.gd` / `BoardingSystem.gd` — death drops and boarding rewards
  rolled from a faction/boss-specific loot table, scaled by the destroyed ship's class
  (`max_crew`) and current empire `notoriety`.
- `ShipDamage.gd` — hull/sails/crew pools, stern-arc crits, and (M8) the **write** side:
  `repair(pool, amount)`, `restore_all()`, `get_pool_maximum()`, and a timed speed penalty fed by
  `AmmoData.speed_penalty` (authored on ChainShot since M6 and read by nothing until now).
- **Chaser mounts (bow/stern, M8 Phase 2).** `FiringSolver` gained `SIDE_BOW`/`SIDE_STERN`
  alongside the broadside sides — a narrow, longer-range cone centred on the hull's forward/aft
  axis rather than the beam. Gated on `ShipStats.has_bow_chaser`/`has_stern_chaser` (most hulls
  have neither, per `docs/navalCombat.md` §3), not on marker presence — `PlayerShip`/`EnemyShip`/
  `BossShip` all carry a `BowMarker`/`SternMarker` regardless of the currently equipped
  `ShipStats`, since a hull's stats swap at runtime while its scene doesn't.
- **Hull damage visuals (M8 Phase 2).** `ShipVisuals` now listens to `ShipDamage.pool_changed`:
  below `hull_damaged_threshold` a procedural smoke `GPUParticles3D` fades in, below
  `hull_critical_threshold` every surface's toon-shader `albedo` blends toward
  `scorch_tint_color`. Clean colors are cached once per surface right after
  `KenneyMaterialApplier` runs, so repeated damage/repair cycles always blend from the true
  original rather than compounding. Closes `docs/navalCombat.md` §7's one remaining open item.
- **Enemy roles (M8 Phase 2).** `AIProfileData.role` (`Raider`/`Artillery`/`Tank`/`Support`/
  `Boss`/`Balanced`) is a content tag, not a second numeric system — a Raider is fast/aggressive
  because its profile authors those values, not because code multiplies a "Raider bonus" into
  them. The one thing `role` *does* drive in code: a `SUPPORT`-role `EnemyAI` finds the nearest
  wounded ally below `support_heal_threshold` and repairs it (via the same `ShipDamage.repair()`
  Slice 0 built) instead of attacking, once nothing needs healing it fights normally.
- **AI support ships (M8 Phase 2).** `EncounterData.ally_scene`/`ally_count`/`ally_profile` let an
  encounter (currently `Defense.tres`) spawn real, fighting AI allies — unlike the escort below,
  they keep their `EnemyAI` and auto-fire. Allies join a `friendly_ship` group rather than
  `player_ship` (which `BoardingSystem`/`CameraRig` assume has exactly one member), and
  `FiringSolver.are_hostile()` was extended to treat `friendly_ship` the same as `player_ship` for
  hostility purposes. `EnemyAI._find_player()` (despite the name) now resolves to "my current
  hostile target" — the human player for an ordinary enemy, or the nearest live `enemy_ship` hull
  for a `friendly_ship`-grouped ally — so one code path drives both without a second targeting rule.
- **Real per-kind encounters (M8 Phase 2).** `EncounterData.Kind.DEFENSE` now has an authored
  `.tres` and a genuine `PROTECT_TARGET` objective: `EncounterManager` spawns an `escort_scene`
  hull with its AI/auto-fire stripped (a target, not a combatant) and resolves `DEFEAT` if it sinks
  before the raiders do — previously `PROTECT_TARGET` silently aliased `DESTROY_ALL` with nothing
  to actually protect. `CONVOY`/`ELITE`/`BOSS` already diverged meaningfully via
  `strength_multiplier`/rewards/`upgrade_offers`; only `DEFENSE` needed new code.

**Combat data:** `resources/combat/encounters/*.tres` (6 encounter types),
`resources/combat/upgrades/*.tres` (10 battle upgrades),
`resources/captains/abilities/*.tres` (20 captain abilities, one per captain),
`resources/combat/ai_profiles/*.tres` (6 AI profiles covering all 5 combat roles).

**Known gaps:** no cannonball arcing (straight-line only), no armor/hull-facing variance beyond the
existing stern-crit arc, no region-specific mixed-role compositions beyond `EliteHunters.tres`.

## Economy & Buildings — fully working
`scripts/managers/ResourceManager.gd` + `scripts/world/Island.gd` + `scripts/world/BuildingData.gd`

- `ResourceManager` (autoload): gold/wood/iron/rum/research, per-resource storage caps, a global
  10-second economy tick signal, `add_resource` / `spend_resource` / `can_afford`. Dynamically recalculates `max_storage` by summing `storage_bonus` across all constructed buildings.
- `Island.gd`: tracks `built_buildings` per island, listens to the economy tick, produces
  resources per building. `build_structure()` / `upgrade_structure()` spend resources and swap
  in the next `BuildingData` tier. Restores buildings dynamically via name convention (`<BuildingName>_L<Level>.tres`). Includes `get_island_tier()` derived from average building levels.
- 10 populated `BuildingData` chains exist: Academy, Farm, Fortress, LumberMill, Market, Mine,
  Shipyard, Tavern, Warehouse, Watchtower. Each has 5 authored level resources (`_L1.tres` to `_L5.tres`) with geometric cost/production scaling.
- **Offline catch-up (M5):** `SaveManager` persists `last_saved_unix` on every save; on load it
  computes elapsed real time (capped at 4h), then directly calls each loaded island's
  `_on_economy_tick()` and `FleetManager._on_economy_tick()` once per offline tick — deliberately
  *not* by re-emitting `global_economy_tick`, since `FactionManager` also subscribes to that
  signal for hunter-ship dispatch and would misfire at absurd rates if replayed hundreds of times.
  `WorldHUD` shows a one-time "while you were away" notice via the existing `announce_event()`.

**Known gaps:** fixed building slots (no free placement), only 10 building types (no deep
production chains), colonize/capture flow is broken (see §2).

## Fleet, Captains, Tech — fully working
`scripts/managers/FleetManager.gd`, `scripts/world/CaptainData.gd`, `scripts/managers/TechManager.gd`

- `FleetManager`: owned ships/captains rosters, active ship/captain index, background trade/patrol
  missions that tick gold/reputation on a timer, save/load.
- **Ship level + modules (M8 Phase 2, `docs/navalCombat.md` §13).** `owned_ships` is now
  `Array[OwnedShipData]` rather than a bare `Array[ShipStats]` — a `ShipStats` `.tres` is shared by
  every hull of its class, so two owned Sloops could not otherwise each carry their own level/
  module state without a shared-mutable-record bug. `OwnedShipData.get_effective_stats()` applies
  level (flat +5%/level to health/damage/speed, max level 5) and up to one module per slot (Hull/
  Cannon/Sail/Utility/Special, 10 authored in `resources/modules/*.tres`) to a **duplicated**
  `ShipStats` — the template itself is never touched, same rule `EncounterManager._apply_strength()`
  and `CombatModifiers` already follow. `FleetManager.get_active_ship()` keeps returning a plain
  `ShipStats` (now the effective one) so every existing caller — `IslandMenu`'s ship-switch,
  `SaveManager`'s fleet load — needed no change. `IslandMenu`'s Fleet tab gained a level-up row and
  a per-slot module row per owned ship. Save format is backward-compatible: a pre-M8 flat array of
  ship paths loads as level-1, no-modules `OwnedShipData` entries.
- `CaptainData`: XP/level curve with computed speed/turn/damage/health modifiers, plus a
  `hire_cost_gold` field (M5) so recruitment cost scales with roster depth. 20 populated
  captains (Redbeard, Anne, Bartholomew, Jack, Mary, Isabela, Diego, Grace, OldTom, Fiona,
  Cutlass, Whistler, Marguerite, Ezra, Rook, Selene, Barnaby, Constance, Yusuf, Ophelia).
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

Tabbed, fully code-built UI: Buildings (build/upgrade, gated by `required_island_tier`), Shipyard (buy ships, gated on owning a Shipyard), Tavern (hire captains, gated on owning a Tavern), Fleet (assign missions), Research (unlock tech), Trade (sell resources), and a "Colonize (1000 Gold)" button for neutral islands.

`SettingsMenu.tscn` / `SettingsMenu.gd`: includes a Controls tab for input rebinding via `InputManager.rebind_action()` (persisted through `SettingsManager`). `WorldHUD` tints resource limits red when caps are reached.

## World/ships/ocean — M2 scope, functional with documented gaps
`ShipController`, `ShipMovement`, `ShipVisuals`, `BuoyancySimulator`, `WaveGenerator`,
`OceanController`, `CameraRig` (includes smooth `enter_docked_view()` / `exit_docked_view()` transitions driven by `DockingSystem` signals), `DockingSystem`, `EnvironmentController`, `WorldManager`. See
§2 below for open gaps (M2's own bug-fix history is condensed in `docs/16_MILESTONE_HISTORY.md`).

---

# 2. Known defects (fix in milestone-m3-stabilization)

These were confirmed by direct code inspection on 2026-08-03, then re-verified against actual
code changes (not self-reported checkbox status) during the milestone-m3-stabilization
checkpoint reviews on 2026-08-03.

| # | Defect | Status |
|---|--------|--------|
| D1 | `EventManager.gd` ran as both a global autoload **and** a scene-local node in `World.tscn`. | **Resolved.** Scene-local node removed from `World.tscn`; `WorldManager.gd` now calls the `EventManager` autoload directly instead of `get_node_or_null("../EventManager")`. |
| D2 | `FactionManager.get_player_faction()` loaded a nonexistent `PlayerFaction.tres`, breaking colonize/capture. | **Resolved.** `resources/factions/PlayerFaction.tres` created (`faction_id="player"`, `is_hostile_to_player=false`, distinct colors). Verified: colonizing a NEUTRAL island and auto-capturing a defeated ENEMY island both complete without error. |
| D3 | `GhostShipStats.tres` set property names that don't exist on `ShipStats` (`ship_name`, `speed`, `turn_speed`, `reload_time`, ...), silently dropped on load. | **Resolved.** Rewritten with real property names (`max_speed=15.0`, `turn_rate=0.5`, `fire_rate=0.5`); `max_health`/`cannon_damage`/`cannon_range` preserved. |
| D4 | `ScreenshotHarness.gd` (dev diagnostic) was registered as a production autoload. | **Resolved.** Removed from `project.godot`'s `[autoload]`; header now documents manual invocation via `godot --headless -s res://scripts/tests/ScreenshotHarness.gd`. |
| D5 | `ScenePaths.gd` / `UIConstants.gd` were dead code. | **Resolved.** Both deleted after confirming zero references. |
| D6 | Orphaned `resources/world/ShipStats.tres` / `IslandData.tres`, the former with a dangling reference to a nonexistent material. | **Resolved.** Both deleted. |
| D7 | `SaveManager.gd`'s doc header claimed it was an M1 no-op stub; it's actually a complete save/load system. | **Resolved.** Header rewritten to match reality; no code changes. |
| D8 | Five M2 property-test files were genuinely empty (`test_camera_properties.gd`, `test_docking_properties.gd`, `test_input_properties.gd`, `test_ocean_properties.gd`, `test_ship_properties.gd`). | **Resolved.** All 5 implemented, living flat under `tests/*.gd` (not `tests/world/` as the M2/M3 spec text assumed — GUT's `-gdir=res://tests` doesn't recurse into subdirectories with this project's config, so `tests/world/` is a dead end for test discovery; moved to match the working convention). 24/25 of the underlying properties pass. The one failure (`test_property_21_lod_distance_transitions`) correctly detects that no LOD system exists in `OceanController` — a real gap, not a test bug, tracked as a new follow-up rather than fixed here (building an LOD system is a feature, out of scope for a stabilization pass). |
| D9 | *(Original claim: no `SpringArm3D` collision configured, ORBIT/LOOK are dead stubs.)* | **Superseded — see D31.** This entry previously concluded the `collision_mask=3` spring arm was "already working before M3 started". That is now known to be wrong: masking layer 1 made the arm collide with the very ship it is attached to, burying the camera inside the hull. Corrected in D31. The ORBIT/LOOK part *was* a real stub — fixed with an explicit "deferred" comment in `CameraRig.gd`; no new mode logic was implemented (`set_mode()` still accepts them, they just run FOLLOW behavior for now). |
| D10 | No gamepad bindings; `interact` and `camera_rotate_right` both bound to `E`. | **Resolved.** Joypad button/motion events added to all 11 relevant actions in `project.godot`; `interact` reassigned to `G`. |
| D11 | *(Original claim: `WaveGenerator`'s CPU wave function and the GPU shader are independent/out of sync.)* | **Corrected — the real bug was different.** `OceanController._setup_material()` was loading the shader from a stale duplicate at `resources/materials/water.gdshader` instead of the real one at `resources/shaders/water.gdshader`. Once fixed, all 7 `set_shader_parameter()` names already matched the shader's real `uniform` declarations exactly. Separately (and already correct before this milestone, contrary to the original claim): `Ocean.tscn` assigns the same `OceanSettings.tres` to both `OceanController` and its child `WaveGenerator`, and `OceanController._apply_settings()` re-pushes it to `WaveGenerator` on every settings change — CPU buoyancy and GPU rendering already share one source of truth. |
| D12 | No test coverage exists for combat, economy, fleet, tech, or factions — the systems in §1 that make up most of the actual gameplay. | **Resolved 2026-08-03.** Added `tests/test_ship_combat.gd` (5 tests), `tests/test_resource_manager.gd` (9), `tests/test_fleet_manager.gd` (7), `tests/test_tech_manager.gd` (6), `tests/test_faction_manager.gd` (7) — 34 new GUT tests, all passing. Writing these caught a real bug: `FleetManager.get_save_data()` returned the live `active_missions` Dictionary by reference instead of a duplicate (every other manager's `get_save_data()` returns a safe copy) — a save/load cycle that mutated `active_missions` between snapshotting and serializing would have silently corrupted the saved data. Fixed to `active_missions.duplicate(true)`. Full GUT suite: 86 tests, 83 passing; the 2 new failures beyond the pre-existing LOD gap are in `tests/test_empire_scaling.gd` (an M4-in-progress test file, not part of this defect) — `EnemySpawner.spawn_hunter()` does not yet duplicate/scale `ShipStats` per-instance for empire factions, i.e. M4 Task 12 (empire spawn scaling) is written as a test but not yet implemented. Left unfixed here as out of scope for D12; tracked under M4. |
| D13 | `EnemySpawner._initialize()` (`scripts/combat/EnemySpawner.gd:53`) and `WorldHUD._find_ship()` (`scripts/ui/WorldHUD.gd:56`) both called `get_tree().current_scene.get_node_or_null(...)` without a null guard on `current_scene` — harmless in normal play but throws real runtime errors in the GUT test harness (surfaced by `test_region_gates.gd`, introduced by early M4 work). | **Resolved 2026-08-05** (M4 final checkpoint). Both now guard `current_scene` for null before calling `get_node_or_null()` on it. |
| D14 | All 5 `resources/captains/*.tres` files set `speed_modifier`/`turn_rate_modifier`/`damage_modifier`/`health_modifier` directly — but `CaptainData.gd` only exposes those as getter-only computed properties (`base_X_modifier + (level-1)*rate`); there is no exported setter, so every captain's intended stat differentiation was silently inert (all 5 behaved identically, differing only in name/background/XP curve). Found while scoping the M5 captain-roster expansion. | **Resolved 2026-08-05.** All 5 files rewritten to set the real `@export`ed `base_*_modifier` fields instead. Verified by loading each resource directly: Anne now speed=1.15/turn=1.2, Bartholomew hp=1.3, Mary speed=1.1/dmg=1.1/hp=0.9, Redbeard dmg=1.2/hp=0.8, Jack a flat +0.05 across all four — matching each captain's narrative flavor text for the first time. |

### Post-M5 static bug sweep (2026-08-07)

M1–M5 were all functionally complete per their specs, but no interactive playthrough had ever
verified them end-to-end (no display/Godot CLI available in this environment). This pass is a
line-by-line static read of the systems not previously scrutinized this closely, done by three
parallel review agents (combat/movement/docking, economy/save/empire, UI screens) with every
finding independently re-verified against the live code before being fixed — the same
never-trust-a-self-report discipline this doc's own D9/D11 lesson calls for.

| # | Defect | Status |
|---|--------|--------|
| D15 | `WorldManager.initialize_world()` and `WorldHUD._check_offline_return()` both ran synchronously in `_ready()`, checking `EmpireManager.pending_raid_report` / `SaveManager._pending_offline_ticks` immediately. But `SaveManager.load_game()` — the only thing that populates either from a save file — only runs via `World.gd`'s `call_deferred("load_game")`, strictly *after* both checks already ran and found nothing. Two entire M4/M5 features (the raid-report popup and the "while you were away" offline banner) were silently dead on every real Continue-from-save load; both had only ever been checkpoint-verified with headless scripts that call the check function directly, never through the actual boot sequence. | **Resolved.** Added a `SaveManager.game_loaded` signal, emitted at the end of `load_game()` (including its early-return paths). `WorldManager` and `WorldHUD` now also connect to it and re-run their checks when it fires, in addition to their original immediate check (which still covers the no-save-to-load case). |
| D16 | `ResourceManager.recalculate_storage_capacity()` hardcoded gold's `base_storage` to 1000, while the actual starting `max_storage["gold"]` is 5000. The function runs on every `build_structure()`/`upgrade_structure()`/island-restore-on-load call, and its own cap-enforcement loop immediately deletes any gold above the new (wrong) cap. A player with more than 1000 gold building their very first structure would silently lose the excess. | **Resolved.** `base_storage["gold"]` corrected to 5000 to match the real starting cap. |
| D17 | `ResourceManager.load_save_data()` restored `current_resources` from a save with no cap enforcement (unlike `add_resource()`, which does clamp). A save/load cycle could leave a resource above its `max_storage` cap until the next mutating call happened to re-clamp it. | **Resolved.** `load_save_data()` now clamps each restored value to its `max_storage` cap, same as `add_resource()`. |
| D18 | `IslandMenu._on_make_active_pressed()` set `FleetManager.active_ship_index` but never `active_captain_index`, while the Fleet tab's row display (`_create_fleet_entry`) pairs ship `index` with captain `index` (falling back to 0). Clicking "Make Active" on a ship the UI showed paired with Captain C could silently apply a stale, unrelated captain (e.g. Captain A) to the player's ship and health calculation instead. | **Resolved.** `_on_make_active_pressed()` now also sets `active_captain_index` to match, using the same fallback rule the display already uses. |
| D19 | `DockingSystem._process_alignment()`'s docking-rotation slerp used `alignment_speed * delta` directly as the interpolation weight with no clamp to `[0,1]`. Since `alignment_speed` is an editor-exposed `@export`, any value where `alignment_speed * delta > 1.0` (e.g. `alignment_speed` ≳ 60 at 60fps) would make `Quaternion.slerp` extrapolate past the target orientation instead of easing into it, causing the ship to overshoot/oscillate while docking. | **Resolved.** The slerp weight is now `clamp(alignment_speed * delta, 0.0, 1.0)`. |
| D20 | `FleetManager._on_economy_tick()` indexed `owned_captains[cap_idx]` with no bounds check, unlike the bounds-checked `get_active_captain()`. `load_save_data()` can load fewer captains than a save's `active_missions` entries expect (a captain `.tres` deleted from disk since the save was made is silently skipped via `ResourceLoader.exists()`), so a stale mission referencing that captain's old index would throw and abort the entire tick handler — stopping *all* ships' trade/patrol income, not just the affected one. | **Resolved.** Added a bounds check that skips (rather than crashes on) a mission whose `captain_index` no longer resolves. |
| D21 | Two related unguarded property accesses/nulls, both cross-referenced with `docs/05_CURRENT_SYSTEMS.md`'s D2 fix (direct `.faction_id`/`.faction_name` access instead of the safer `.get()` pattern already used elsewhere in the same functions): `ShipController._spawn_loot()` used `self.faction.faction_id` directly (would throw if `faction` were ever a bare `Resource` without that property); `EnemySpawner.spawn_hunter()`'s closing `print` used `faction.faction_name` with no null guard, and its only caller (`FactionManager._on_economy_tick`) passed a `load()` result straight through without checking it succeeded. | **Resolved.** `ShipController` now uses `self.faction.get("faction_id")`; `EnemySpawner.spawn_hunter()` guards the final print behind `if faction:` and uses `.get("faction_name")`; `FactionManager` now checks the loaded `RoyalNavy.tres` isn't null before calling `spawn_hunter()`. |
| D22 | `EmpireManager.load_save_data()` called `data["region_active"].duplicate()` with no type check, unlike `ResourceManager`'s established `typeof(data) != TYPE_DICTIONARY` guard pattern — a malformed/corrupted save value here would throw instead of failing gracefully. Separately, a leftover `print("KEYDEBUG: ...")` in `InputManager._unhandled_input()` fired on every single keypress with no debug flag guarding it, flooding the console during normal play. | **Resolved.** Added the same `typeof(...) == TYPE_DICTIONARY` guard used elsewhere before the `.duplicate()` call; removed the `KEYDEBUG` print entirely. |

**Known gap, not fixed in this pass (design judgment, not a mechanical bug fix):** `ShipCombat.current_health` is only ever clamped downward when `max_health` changes (via a tech upgrade or captain swap after initial spawn) — it's never rescaled proportionally, and never scaled up. A player who buys a health-boosting tech upgrade mid-game won't see current HP increase proportionally; repeated small upgrades can leave current HP permanently below where its ratio to max should be. Fixing this requires deciding the intended behavior (rescale proportionally? refill to full? something else?) rather than a mechanical correctness fix, so it's flagged here for a future milestone instead of guessed at.

Lesson from this pass, worth remembering for future checkpoints: two of the original defects
(D9's collision claim, D11's sync claim) turned out to be **wrong on re-inspection of actual
scene wiring**, not just wrong on Gemini's side — the original code-reading audit missed that
`.tscn` files already had the necessary configuration. Static code review of `.gd` files alone
can miss behavior that only exists in scene-file wiring (`@export` values assigned in the
editor, not in the script). Checkpoint reviews should check `.tscn` contents directly, not just
the scripts they reference.

### Visual/material pass (2026-08-09)

The first pass where rendered output was actually *looked at* rather than reasoned about. A
Godot binary is now available on the dev machine, so models can be rendered to PNG headfully via
a throwaway `extends SceneTree` script (`-s`, no `--headless` — the dummy renderer produces empty
images) and compared A/B. Both defects below had been invisible to every prior static review and
to the whole GUT suite, which asserts no color or material state at all.

| # | Defect | Status |
|---|--------|--------|
| D23 | `KenneyMaterialApplier._build_toon_material()` multiplied every surface's albedo by the authored `material_path` color unconditionally. Every model this component runs on is a Kenney GLB whose color comes entirely from the shared `colormap.png` atlas — the atlas *is* the per-part authored color — so this dragged whole models toward one hue: `wood_light`'s `(0.85, 0.55, 0.25)` turned white sails and skull emblems bright orange, `wood_dark`'s `(0.38, 0.2, 0.12)` muddied everything to brown. Confirmed by rendering the same GLB with and without the applier. | **Resolved.** Tinting is now opt-in via an `@export_range` `tint_strength`, default `0.0` (atlas untouched), and blends (`Color.lerp`) toward the authored color instead of multiplying — multiplication can only ever darken, so it compounded. Surface properties (metallic/roughness) still come from the authored material at any strength, since those carry none of the color problem. |
| D24 | `KenneyMaterialApplier.override_material_path()` — the entire mechanism behind `Island.gd._apply_terrain_theme()`'s volcanic/frozen island variants — had never worked. It re-ran `_apply_to_children()`, but that method skips any surface whose override is already set, and `_ready()` has by then set one on every surface. The re-apply was a silent no-op, so themed islands always rendered identical to tropical ones. | **Resolved.** `_apply_to_children()` takes a `force` flag that `override_material_path()` passes. The seed is always re-read from the mesh's built-in material (which `set_surface_override_material` never mutates), so repeated calls don't compound. Verified by rendering the frozen override and confirming the result now differs from the untinted baseline. |

Also corrected: `ShipStats.material_path` defaulted to `res://resources/materials/ShipMaterial.tres`,
which does not exist in the project. Any `ShipStats` not overriding it (the `.tres` files all do,
so this was latent) would make `_resolve_material()` fail its `load()`, return null, and skip the
toon/outline pass entirely rather than falling back. Default is now `""`, which
`_resolve_material()` already handles. `ShipStats.model_path`'s default
(`res://assets/models/ships/player_ship.glb`) is **also** a non-existent path and is left as-is —
flagged here as an unverified follow-up, since `ShipVisuals` has its own `DEFAULT_MODEL_PATH`
const and the interaction between the two wasn't traced in this pass.

| # | Defect | Status |
|---|--------|--------|
| D25 | **The ocean was almost entirely invisible.** `Island.tscn`'s four sand patches were scaled `14` on X/Z. The `patch-sand-foliage.glb` source model measures 7.74 × 6.04 units, so each patch rendered 108 × 84 units and the four together formed a beach roughly 120 units across — against island spacing of only 50–120 units in `World.tscn`. Every island's beach merged into its neighbours' into one continuous landmass that covered the whole playable area; what looked like a blown-out white ocean was opaque sand terrain, with real water visible only at the screen edges. The visual terrain was ~5× every other authored element on the same scene: the island's own collision cylinder is radius 11, its dock sits at x=16, and its building slots all fall within radius 9.5. Latent since the original scene was authored, but only became visible in `a4a3d8d`, which raised the terrain from y=0.1 to y=0.9 to clear the wave crests — at the old height the oversized patches sat below the waterline and were hidden by the water surface. | **Resolved.** Sand patches scaled `14` → `2` (union radius ≈13.7, so the beach lands just inside the dock at x=16 and just outside the radius-11 collision cylinder). Grass mounds rescaled in proportion — `10` → `1.43` and `7` → `1` on X/Z, with their Y scales brought down from 2.5/2.0 to 1.2/1.0 so they stay mounds rather than becoming towers. Verified by rendering World.tscn and confirming open water, separated islands, and props still seated on the terrain. |
| D26 | **Every toon-shaded surface rendered with albedo *squared*.** `toon.gdshader` supplies its own `light()`, and multiplied its diffuse and ambient terms by `ALBEDO`. But Godot multiplies `DIFFUSE_LIGHT` by `ALBEDO` itself once `light()` returns, so the albedo was applied twice. Squaring barely moves a surface's dominant channel while crushing the other two, so it read as a large hue/saturation shift rather than a brightness error, which is why it survived several passes: sand rendered `(255,175,141)` against a correct `(255,229,202)`, palm fronds `(52,206,149)` against `(125,237,196)`. Everything wooden or stone converged on the same saturated orange. The ocean was unaffected throughout — `water.gdshader` has no custom `light()` — which is exactly why fixing the water didn't touch it. | **Resolved.** `ALBEDO` removed from both terms in `light()`; the engine's own multiply is now the only one. `SPECULAR_LIGHT` is not albedo-multiplied by the engine, so the specular term was already correct and is unchanged. |
| D27 | The same `light()` used `LIGHT_COLOR` raw. Godot pre-multiplies `LIGHT_COLOR` by `energy * PI` (the `PI` is there for the built-in Lambert BRDF to divide back out), so every lit surface was ~3.14× overexposed *per light* — roughly 4–5× with the sun at energy 1.3 plus the fill at 0.35. That pushed the whole frame past the top of the filmic tonemap curve, desaturating toward a warm white and carrying the sun's `(1.0, 0.9, 0.72)` tint with it, and put nearly every pixel above `glow_hdr_threshold = 1.3` so the entire image bloomed. | **Resolved.** `light()` now divides `LIGHT_COLOR` by `PI` once, up front. |
| D28 | The toon specular cutoff, `step(1.0 - ROUGHNESS * 0.45, NdotH)`, ran *inverted*: rougher surfaces got a **wider** highlight. At `roughness = 0.9` (wood, sailcloth, sand) the threshold bottomed out at `0.595`, i.e. a solid white blowout across everything within ~53° of the half-vector — the flared-out ship sails. | **Resolved.** Cutoff is now `step(mix(0.85, 0.995, ROUGHNESS), NdotH)`, so rough surfaces get a highlight only near dead-on and smooth ones (brass) get a broad hard patch. |

D26–D28 were isolated by rendering the same frame through the toon path and through the stock
GLB materials and diffing pixels, then bisecting. Two intermediate results are worth keeping,
because both killed plausible theories outright: rendering both paths **unshaded** produced
pixel-identical output, proving `KenneyMaterialApplier` hands over exactly the right color and
that the entire fault was inside `light()`; and emitting a *constant* `LIGHT_COLOR` from `light()`
still produced per-surface colors that tracked each surface's own hue, which is what pinned the
double-albedo. Useful correction for future probes: `World.tscn` sets `ambient_light_source = 3`
(Sky), under which `ambient_light_color`/`ambient_light_energy` are ignored entirely — driving
those two alone proves nothing about ambient.

Also worth recording: these GLBs carry **no texture at all** (`albedo_texture` is null on every
surface); their color is per-surface `albedo_color`. The `colormap.png` atlas that
`KenneyMaterialApplier`'s header and D23 both reason about is not in play for the ship and island
models, so `texture_albedo` stays at its default white and only the `albedo` uniform matters.

Method note, since this one cost several wrong turns: the cause was only found by painting the
water shader's output a flat debug color to see which pixels were actually ocean. Every prior
hypothesis (tint, foam, `depth_draw_always`, depth reconstruction, lighting blowout) was tested
against a render and disproved. On a visual bug, identify *which surface* you are looking at
before reasoning about why its color is wrong — the whitened area was never the water.

Note on engine version: the only Godot on the dev machine is **4.7.1**, while `project.godot`
declares `config/features=PackedStringArray("4.3", ...)`. Everything above was verified under
4.7.1. The version gap has not been audited for rendering differences and is a plausible source
of further visual discrepancies independent of these two defects.

Two Gemini sessions also marked tasks `[x]` in `tasks.md` with **zero corresponding file
changes** (this milestone's Tasks 11 and 14, before re-verification) — always cross-check
`git diff` against a task's claimed completion before trusting the checkbox.

**Tooling note:** `godot --headless --path . --check-only` does not reliably exit on its own in
this project on Godot 4.3 — with `run/main_scene` configured, it boots straight into real
gameplay (Boot → MainMenu) and then idles forever rather than quitting, which caused repeated
false "hangs" during this milestone's verification (every process had to be killed manually).
Use the GUT suite (`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`) as the
standard verification command instead — it calls `-gexit` and reliably terminates, and it
already proves every test script parses correctly (GUT cannot run tests from a script that fails
to compile), which was the main value `--check-only` was being used for anyway.

D13 and D14 (above) were both found and fixed during the M4 final-checkpoint pass on 2026-08-05,
after M3's own closure — logged here rather than in a separate ledger so this table stays the
single source of truth for defect status.

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

Re-read directly from `project.godot` on 2026-08-25 (M7 campaign spine). `InputManager` (D57) and
`CampaignManager` (M7 Task 9) were both newly promoted to/created as autoloads this pass;
`WorldEventManager` was deleted outright (its one job — a timer that spawned ambient ocean events
— was absorbed into `EventManager`).

```
SaveManager, SceneManager, SettingsManager, InputManager, AudioManager, ResourceManager,
FleetManager, TechManager, EventManager, FactionManager, EmpireManager, CampaignManager,
TutorialManager
```

`ScreenshotHarness` (D4) has been removed from `[autoload]`; it's now invoked manually only,
per its own header comment.

**Not autoloads — scene-local nodes** under `World/Systems` in `scenes/world/World.tscn`. This
distinction matters: anything outside the World scene that tries to reach one of these via
`get_tree().root.get_node_or_null(...)` gets null (see D55). `InputManager` moved out of this list
(see D57); `EncounterManager` (M8) and `BoardingSystem` are the two combat-era additions.

```
WorldManager, DockingSystem, EnemySpawner, BoardingSystem, EncounterManager
```

## Campaign spine (M7, 2026-08-25)

Superseded by the "M7 — Campaign Spine" section at the end of this document. `TutorialManager`'s 8
hardcoded steps were retired in favor of `CampaignManager` + authored `ChapterData` resources;
`IslandData.discovered` now has a real write path off the `player_docked` signal.

---

# 5. Empire Escalation (M4)

`scripts/managers/EmpireManager.gd` (autoload, registered after `FactionManager`) +
`scripts/world/RegionData.gd` + `resources/world/regions/*.tres` +
`scenes/ui/RaidReportScreen.tscn`

This is the system that delivers the "escalating danger" fantasy referenced in
`milestone-m4-empire-escalation/requirements.md` — the world gets more dangerous, and pushes
back, as the player expands.

## Notoriety

A single float (`EmpireManager.notoriety`, `notoriety_changed` signal) that only goes up through
player action:
- **+1** for destroying a non-empire faction's ship, **+5** for an empire faction's ship
  (`ShipController._on_died()`, gated on `faction.is_empire`)
- **+15** for capturing/colonizing an island (`Island.gd`'s `capture_island()`)

It decays slowly (1.0/minute) after 10 real-time minutes with no gain (`_process()`, gated on
`_last_gain_unix`), clamped to 0 — so notoriety reflects recent activity, not a permanent
high-water mark.

## Regions and activation

3 `RegionData` resources exist under `resources/world/regions/`: **Beginner Waters** (tier 1,
threshold 0, always active), **Contested Waters** (tier 2, dominant faction Royal Navy,
threshold 60), **Imperial Waters** (tier 3, dominant faction **Spanish Empire** — a new 5th
faction added in this milestone, `is_empire = true`, `resources/factions/SpanishEmpire.tres`,
threshold 150). Imperial Waters' second island, `resources/world/CartagenaOutpost.tres`
(`cartagena_outpost`), was authored new for this milestone alongside the existing
`volcano_island`.

`EmpireManager` loads all 3 on `_ready()`, tracks each as active/dormant in `_region_active`, and
activates a dormant region exactly once (`region_activated` signal) the moment notoriety crosses
its threshold. `Island.gd`'s `_should_be_active()` gates both defender spawning and
`capture_island()` on the island's region being active — an island in a dormant region has no
defenders and its Colonize button is disabled (`IslandMenu.gd`) until the region activates.

## Difficulty scaling

`EnemySpawner.compute_spawn_multiplier(region_tier)` = `1.0 + max(0, tier-1)*0.3 +
notoriety*0.002`, applied only to `is_empire == true` faction spawns, at spawn time to a
duplicated `ShipStats` instance (never mutating the shared resource other ships of that tier
use). Non-empire spawns are always multiplier 1.0 regardless of region/notoriety.

## Raids

Every 15 real-time minutes (`_process()`, persisted via `_last_raid_check_unix` so a check also
fires once on load if that much time has passed), a raid attempt is rolled with probability
`clamp(notoriety/200.0, 0.05, 0.25)`. If triggered, `_resolve_raid()` compares:
- **Defense score** = home island's Fortress/Watchtower presence (`Island.built_buildings`) +
  a per-ship bonus for any `FleetManager` ship flagged "Defend Home" (excluding the player's
  active ship and any ship on a mission)
- **Attack score** = `highest_active_region_tier * 25 + notoriety * 0.3`

If defense ≥ attack, the raid is repelled (no losses). Otherwise a fraction of stored resources
is stolen via `ResourceManager.spend_resource()` and the result is stored as
`EmpireManager.pending_raid_report` (overwriting any previous unshown report), then
`raid_resolved` emits. `WorldManager.gd` auto-instantiates `RaidReportScreen.tscn` on World scene
load whenever a pending report exists, and clears it on dismiss.

## Persistence

`SaveManager.gd` round-trips `EmpireManager`'s full state (`notoriety`, per-region active flags,
`home_island_id`, `_last_raid_check_unix`, `pending_raid_report`) via
`get_save_data()`/`load_save_data()`.

## Known gaps

No region-specific enemy *types* yet (only stat scaling — `EnemySpawner`'s own TODO still lists
this for a future milestone), and no named/scripted empire captains. The Defend Home fleet bonus
and Fortress/Watchtower defense contributions are currently binary (built or not), not scaled by
building upgrade tier.

---

## Visual & physics defect sweep (screenshot-driven)

Worked through `docs/09_VISUAL_BUG_TRACKER.md`, which holds the full per-bug
detail, the numeric verification, and the wrong diagnoses. Summary of what
changed in the systems this doc covers:

| ID | Defect | Resolution |
|---|---|---|
| D31 | **Camera buried inside the player hull.** `CameraRig.tscn`'s `SpringArm3D` had `collision_mask=3` (layers 1+2 = player + enemy ships). The rig rides at the target's origin (`EYE_HEIGHT=0.0`), so the arm's 1.5-radius sphere starts *inside* the followed ship's own collision shape, collides immediately and collapses to ~0. The mask included ships because `Island.tscn`'s `StaticBody3D` declared no `collision_layer` and so defaulted to layer 1 — indistinguishable from the player ship. This also directly caused D32. Supersedes D9's "already working" conclusion. | **Resolved.** Islands → `collision_layer=17` (layer 1 so ships still collide with them, plus new layer 5 = terrain). Spring arm → `collision_mask=16` (terrain only). `CameraRig._exclude_target_from_spring_arm()` additionally excludes the followed body by RID so the fix survives a ship changing layers. `test_camera_properties.gd` Property 2 updated: it created its obstacle on `collision_layer=3`, pinned by comment to the arm's old mask. |
| D32 | **4× `Parameter "material" is null` at every startup**, from `material_casts_shadows` / `material_is_animated` / `material_get_instance_shader_parameters` / `material_update_dependency`. Previously bisected to "runtime composition, not any scene file" and left unlocated. | **Resolved as a side effect of D31** — it was the spring arm's shape cast querying ship hull geometry. A full capture run now reports **0 errors**. The null guard in `KenneyMaterialApplier` is *not* what fixed it (measured: count unchanged at 4); it stays as defensive-only, commented as such. |
| D33 | **Ships capsized and tumbled indefinitely.** Four independent causes stacked: (1) sign-inverted restoring torque in `BuoyancySimulator`; (2) **no ship declared `center_of_mass`**, so Godot placed it at the collision shape's centre `y=+1.0` while all float points sit at `y=0.0` — buoyancy pushing up from below the COM makes the hull an inverted pendulum, which no restoring torque can beat; (3) `ShipMovement` did `body.angular_velocity.y = lerp(...)`, overwriting the whole world-Y component every frame — exactly the component self-righting needs, so continuously-steering AI ships never recovered while the player ship did; (4) `up.cross(Vector3.UP)` has magnitude `sin(tilt)`, which *falls away* past 90° (0.087 at 175°), so a hull knocked past horizontal stayed capsized forever. | **Resolved.** (1) → `up.cross(Vector3.UP)`. (2) → explicit ballasted `center_of_mass` below the float points on all three ship scenes. (3) → servo the yaw component only, preserving roll/pitch. (4) → backstop past 60° using a `1-cos(tilt)` gain (1.996 at 175°), verified numerically. Also: `EnemySpawner` set `global_rotation.y` *after* `add_child`, and assigning one Euler component to a RigidBody3D recomposes the whole basis, folding existing roll/pitch back in — replaced with a single `Transform3D(Basis(UP, yaw), pos)` plus velocity reset. `BossShip` was missing `can_sleep=false`, so a settled boss stopped receiving buoyancy. |
| D34 | **`ship_stats.angular_damp` was never applied to anything.** `ShipController` deliberately skips it (body-wide damping would fight the yaw servo), which left roll/pitch with no damping at all. | **Resolved.** Applied inside `BuoyancySimulator`'s stability term, on the roll/pitch axes only — where it was always meant to act, and without touching yaw. |
| D35 | **Sky was a permanent sunset.** The obvious cause (`EnvironmentController` rewriting the sky every frame from `EnvironmentSettings`, whose `sky_horizon_noon` was orange) was only half of it — fixing every sky keyframe left the horizon just as orange. The dominant cause was `World.tscn`'s `fog_light_color = (0.9, 0.72, 0.52)`, a warm orange that **nothing ever updated**, tinting the whole distance at every time of day. `ground_horizon_color` had the same problem. | **Resolved.** Noon/morning horizon retuned to daylight blues (only morning/evening stay warm); all sky + ambient keyframes pinned explicitly in `EnvironmentSettings.tres` so it is the single source of truth; `EnvironmentController` now drives `ground_horizon_color` and `fog_light_color` from the same computed horizon colour so the three cannot disagree. **Decision: `EnvironmentController` + `EnvironmentSettings.tres` win; `World.tscn`'s sky values are only the frame-0 seed.** |
| D36 | **HUD layout defects** (both found by screenshot, neither reported). `WorldHUD._create_notoriety_label()` used `PRESET_TOP_RIGHT` + `position.x -= 300`, anchoring only the label's *left* edge to the screen edge — text ran off-screen *and* printed on top of the resource bar. `announce_event()` used `PRESET_CENTER` (a zero-width rect), so long announcements grew off the right edge; its tween also faded `modulate:a` from 1.0 *to* 1.0, a no-op "fade in". | **Resolved.** Notoriety label right-aligned in an explicitly-offset rect that grows leftwards, positioned below the resource bar. Announcement banner spans full width with `AUTOWRAP_WORD_SMART`, starts transparent, and actually fades. |
| D37 | **`ManOWar.tres` set `stability_torque_multiplier = 25.0` against `@export_range(0.0, 20.0)`.** The authored ships form a deliberate ladder scaling with hull size (Dinghy 8 → Galleon 20 → ManOWar 25), so 25 is intended and the *range* was wrong. Out-of-range values load fine at runtime, but the inspector would have snapped it to 20 the first time anyone opened ManOWar in the editor. | **Resolved.** Range widened to `0.0, 30.0`. |
| D38 | **`project.godot` referenced a nonexistent `res://icon.svg`**, logging an error on every single launch. | **Resolved.** Project icon added rather than removing the setting, since an exported build needs one. |
| D39 | **Ships beach themselves on island terrain** and end up stranded and tipped. Not a buoyancy problem — the hull is resting on static geometry (the island collision cylinder sits at `y=+2.0`, above the waterline). `EnemyAI` steers straight at its target with no obstacle avoidance. | **Fixed 2026-08-09.** `EnemyAI` gained a three-feeler whisker probe (`_get_avoidance_turn()`/`_probe()`) masking layer 5 (terrain) only, so enemies steer around islands without swerving around each other. Avoidance overrides the navigation turn unconditionally — running aground is always worse than missing a waypoint, and a beached hull is unrecoverable. Patrol waypoints are also pushed back to open water via `_push_to_open_water()`, since a waypoint generated inside an island was unreachable and made ships grind along the shore forever. Tuning is exported (`avoid_probe_distance`, `avoid_feeler_angle`, `avoid_collision_mask`, `avoid_turn_strength`). |
| D40 | **`Sloop.tres` points at `pirate-sloop-lvl1.glb`, one of only two models in `assets/models/` with no texture** (0 images; colour carried purely in `baseColorFactor`), against 72 stock Kenney models that all use the `colormap` atlas. Sloop is the default enemy ship, so this path is active, not latent as previously recorded. Any change to `KenneyMaterialApplier` affects the two groups differently. | **Fixed 2026-08-09.** Scope was wider than recorded: the two untextured models backed **three** ships (Sloop, Dinghy, Brigantine), and the other five shared just two Kenney models, so the fleet had almost no silhouette variety. All 8 `resources/ships/*.tres` were remapped onto textured stock models graded by tier (boat-row-small → ship-small → ship-pirate-small → ship-medium → ship-pirate-medium → ship-large → ship-pirate-large). Both untextured `.glb` files and the now-empty `assets/models/ships/` directory were deleted after confirming zero remaining references. |
| D41 | **`SettingsManager.load_settings()` rewrote the global `InputMap` on every call**, erasing and re-adding key events for 11 actions. `InputMap` is process-global but a `SettingsManager` is an ordinary object, and `tests/test_settings_manager.gd` constructs 50+ throwaway managers per property test. The file went from 3.2s to **over 60s** (the whole suite stopped terminating), and actions were left progressively stripped of their events. | **Fixed 2026-08-09.** Input application is now opt-in via `apply_input_bindings_on_load`, set true in `_ready()` only for the real autoload singleton; the logic moved to `load_input_bindings()`. Also added the `has_action()` guard the load path lacked (save already had it), made an empty stored array mean "nothing authored" rather than "unbind", and replaced the action list duplicated across save/load with the `REBINDABLE_ACTIONS` constant. |
| D42 | **Wave 3's three tests were written to `test/unit/`, not `tests/`** — so GUT never ran them despite Task 23 being ticked. The spec warns twice that `-gdir=res://tests` does not recurse. | **Fixed 2026-08-09.** Moved to `tests/`; all three pass (`test_building_levels.gd` alone carries 230 asserts). |
| D43 | **`EnemyAI.gd` failed to parse** — `min()`/`clamp()` return Variant and this project promotes "inferred from Variant" to an error, so `test_empire_scaling.gd` could not load the script at all. | **Fixed 2026-08-09.** Explicit `: float` annotations on `nearest` and `urgency`. |
| D44 | **`Island._recalculate_tier()` called `get_tree()` unguarded.** Tier is recalculated from `restore_buildings()`, which can run before the island enters the tree — `get_tree()` is null there and the crash aborted the whole restore. | **Fixed 2026-08-09.** Announcement guarded on `is_inside_tree()`. |
| D45 | **`CameraRig._connect_to_docking_system()` dereferenced a null `get_tree()`.** It runs deferred, so the rig may have left (or never entered) the tree by the time it lands. | **Fixed 2026-08-09.** Early return on `not is_inside_tree()`. |
| D46 | **Two GUT API misuses in `tests/test_boarding.gd`** — `get_signal_parameters()` already returns the parameter array so `signal_args[0][0]` double-indexed into a bool; and `assert_signal_emitted_with_parameters()`'s 4th argument is an emission *index*, but a String was passed, causing a `String == int` comparison and a deep-diff against null. Also `Resource.free()` on a RefCounted in `test_island_tier.gd`. | **Fixed 2026-08-09.** Correct indexing, index argument dropped, manual `free()` removed. |
| D47 | **Ship scenes were geometrically mismatched to their models**, which is what made ships render as scattered debris. The 2026-08-09 remap pointed all 8 classes at Kenney hulls spanning `x = -2.40..2.40` with masts to `y = 9.96`, but the scenes still carried transforms authored for a much smaller retired hull: cannon markers at `x = +/-2.0, y = 1.8` sat *inside* the planking, and separate `PirateFlag`/`MastRopes` props at `y = 3.5` floated in mid-air beside rigging the GLBs already contain. | **Fixed 2026-08-09.** Across `PlayerShip`/`EnemyShip`/`BossShip`: duplicate flag/rope props removed (the models ship their own), cannon markers moved to `x = +/-2.5, y = 1.6` and spread over the true ~9-unit hull length, hull `BoxShape3D` corrected to `4.6 x 2.0 x 9.0`, and float points widened `+/-1.5 -> +/-1.9` for a longer righting lever arm. Unused `ext_resource` entries and `load_steps` fixed. |
| D48 | **Toon shader had no mid-tones — the "chalky/cardboard" look.** `diff = smoothstep(0.0, 0.02, NdotL)` is a near-binary ramp, so every surface facing the light snapped to full brightness and every surface facing away snapped to fill, with nothing between; a flat `0.15` neutral ambient then lifted shadows toward that same pale value. Hulls, sails and terrain all rendered as one washed-out tone regardless of angle. | **Fixed 2026-08-09.** Replaced with a three-band cel ramp (shadow / mid / full) exposed as `toon_band_1/2` + `toon_shade_low/mid` uniforms, keeping the hard cel edges while restoring tonal separation. Ambient deepened and cooled (`0.15` -> `0.10`, bluer) so lit faces read as lit. Values are uniforms, not hardcoded, per AGENTS.md. |
| D49 | **Double-boarding exploit.** `BoardingSystem.attempt_boarding()` zeroed `hull` and emitted `destroyed` directly, leaving `ShipDamage._is_destroyed` false, and never cleared `_eligible_enemy` — so a second call against the same wreck re-rolled the loot table and re-granted the full payout. | **Fixed 2026-08-09.** Added `ShipDamage.mark_destroyed()` (idempotent) and `is_destroyed()`; `attempt_boarding()` now refuses an already-destroyed hull and clears eligibility on both outcomes. Guarded by `test_boarding.gd::test_boarding_a_wreck_twice_grants_loot_only_once`. |
| D50 | **`ResourceManager.recalculate_storage_capacity()` dropped the `research` cap.** The function rebuilds `max_storage` from a literal that omitted `research`, so the 9999 cap set at init fell through to the 999999 default as soon as any building was constructed. | **Fixed 2026-08-09.** `research` added to `base_storage` with a comment explaining that the dictionary is rebuilt, not amended. |
| D51 | **The "chalky/cardboard" look was channel clipping from an overbright sun, not a material or shader-ramp problem.** `EnvironmentController` hardcoded the sun energy curve as `(0.3, 0.9, 1.3, 0.9)`. At noon (1.3) the Kenney colormap's warm wood tones — which peak near RGB(241,151,108) — computed to `0.945 * 1.0 * 1.3 = 1.23` in red and **clipped to 1.0**. Warm surfaces lost all red-channel detail and collapsed toward one washed-out salmon, while cooler surfaces (sails, water) stayed correct — exactly why hulls, palm trunks, rocks, docks and sand all read as the same flat orange while grey-blue sails looked fine. Verified by decoding `colormap.png` and computing final lit values; the atlas, the import settings, `KenneyMaterialApplier` and the material pipeline were all confirmed **correct** (runtime probe showed `albedo=(1,1,1)` + atlas texture bound on every surface). | **Fixed 2026-08-09.** Sun energy moved out of the script into `EnvironmentSettings` as `sun_energy_night/morning/noon/evening` (data-driven per AGENTS.md) and retuned to `(0.25, 0.75, 1.0, 0.75)`, which keeps the brightest atlas pixel just under clipping. `World.tscn`'s authored light also corrected (`1.3 -> 1.0`, colour de-orangeed) so the scene matches before the controller's first tick. |
| D52 | **Cannon props rendered as oversized grey blocks floating beside the decks.** `cannon.glb` is a ~2-unit cube with a centred pivot; `ShipCombat._spawn_cannon_models()` instanced it at identity scale onto each marker, so on a 4.6-wide hull each cannon was nearly half the beam and half-buried below the deck. | **Fixed 2026-08-09.** Cannons scaled to 0.45 and lifted by half their scaled height so they rest on the deck; markers normalized across all three ship scenes to `x = +/-2.05, y = 1.7`, `z = -2.4/0/+2.4`, just inside the bulwark. |

**Verification:** GUT suite at **103 tests, 102 passing, 1 failing** — the single
failure is `test_property_21_lod_distance_transitions`, the known/accepted
pre-existing gap. Baseline restored, no regression. Rendered validation came
from `scenes/debug/CaptureHarness.tscn`, which captures the real viewport at
≈0/1/3/7/12s; per `CLAUDE.md`, sailing *feel* still needs a human at the controls.

> **Baseline correction (2026-08-14).** The `103 tests / 102 passing` figure above — repeated in
> the M6 spec header and used as the regression guard ever since — is **stale by 15 tests**. A
> real run on this date measured **118 tests, 117 passing, 1 failing** (the same known LOD
> failure). Wave 3's three test files were never folded into the count. **118 / 117 is the number
> to regress against.** The engine binary is at
> `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.7.1-stable_win64.exe`
> — the same path `Play Pirate Empire.cmd` has always used — so "binary unavailable" is not a
> valid reason to skip a checkpoint run.

---

## M8 Combat Identity Rework (2026-08-14)

Implemented against `docs/navalCombat.md`. **Suite: 126 → 214 tests, 213 passing, still exactly
one known LOD failure** (`test_property_21_lod_distance_transitions`). Note the pre-M8 baseline
measured 126, not the 118 recorded in `docs/14_SYSTEM_INVENTORY.md` §0 — that figure was itself
stale. **214 / 213 is the number to regress against.**

### Defects found and fixed during the audit (D60–D63)

| # | Defect | Resolution |
|---|--------|------------|
| D60 | 🔴 **The entire damage-model write path was dead.** M6 made `ShipCombat.current_health` a getter-only proxy onto `ShipDamage.hull` and left **five** callers assigning to it — `ShipController.respawn()`, `ShipController._apply_tech_modifiers()`, `DockingSystem._process_healing()`, `SaveManager.load_game()` and `IslandMenu`'s ship-purchase path. All five wrote to nothing. Consequences: **respawn left hull at 0 *and* `_is_destroyed` true, so the respawned player was an invulnerable wreck**; **shipyard repair did nothing**; loading a save did not restore hull. `docs/navalCombat.md` §17 describes this defeat→repair→retry loop as "already the shipped behaviour" — it was entirely non-functional. | **Fixed.** `ShipDamage` gained `repair()` / `restore_all()` / `get_pool_maximum()`; `current_health` gained a forwarding setter so all five callers work; `respawn()` now calls `restore_all()`; shipyard repair repairs hull *and* sails (crew is deliberately excluded — it is bought at a Tavern). Guarded by 8 new tests in `test_damage_model.gd`. |
| D61 | 🟡 **`ShipDamage.get_save_data()` / `load_save_data()` had no callers.** Built in M6 Task 3, never wired into `SaveManager`, so **sails and crew were not persisted at all** and hull went through the dead `current_health` write. M6 Req 2.7 passed only in isolation. | **Fixed.** `SaveManager` now round-trips a `player.damage` section through `ShipDamage`'s own pair, falling back to the legacy hull-only `player.health` key for pre-M8 saves. |
| D62 | 🟡 **`AmmoData.speed_penalty` / `speed_penalty_duration` were read by nothing.** `ChainShot.tres` authored `0.5 / 10.0`; `apply_hit()` ignored both, so chain shot's "cripple mobility" effect was only its sail damage. M6 `design.md` §A3 specified a `chain_debuff` term that was never implemented. D14 class. | **Fixed.** `ShipDamage` applies a timed penalty folded into the existing `get_speed_multiplier()` (so `ShipMovement` needed no change), still floored at `min_speed_fraction` so a crippled ship can always limp away. |
| D63 | 🟡 **A captain's health bonus was shaved off on the first hit.** `_ready()` filled hull from `get_effective_max_health()` (captain/tech modified) but `apply_hit()` clamped to the raw `ship_stats.max_health`, and reported that wrong maximum to the HUD. | **Fixed.** `get_pool_maximum()` is now the single source of truth for every pool ceiling. |

### Balance correction — `cannon_range` was unreachable

`cannon_range` was authored at **150–400** across the fleet. A cannonball leaves the gun port at
y≈1.7 with `gravity_scale = 0.5`, so it splashes down after ~0.83 s and travels roughly
`cannon_speed * 0.83` — **65–125 units**. Harmless while firing was a manual key press; fatal for
auto-fire, which would have fired endlessly at hulls it could never reach. All 10 ship/enemy
`ShipStats` were re-authored to their real ballistic reach, preserving the size ladder
(Dinghy 100 → ManOWar 125, EnemyShip 66). `test_combat_integration.gd` now asserts this
relationship holds, so the two numbers cannot drift apart again.

### D55 closed as a side effect

`base_boarding_modifier` was authored on **0 of 20** captains, so `BoardingSystem`'s live read
always returned the 1.0 default and captain choice had no effect on boarding. Now authored on all
20 to the values in `docs/12_CHARACTER_BIBLE.md` §5, so `"Cutlass" Kane` — whose entire authored
personality is *"prefers boarding actions to broadsides"* — is finally mechanically the best
boarder. (`hire_cost_gold`, D56, is untouched: economy, not combat. Still open for M7.)

### Systems removed rather than left as duplicates

- **`scripts/managers/WorldEventManager.gd` — deleted.** Its whole job was a 5-minute boss timer;
  the boss is now `resources/combat/encounters/GhostShipBoss.tres`.
- **`EnemyAI._get_broadside_angle()` — removed**, moved into the shared `FiringSolver`.
- **`EnemyAI.attack_range` — removed**, a second firing range that disagreed with `cannon_range`.
- **`Cannonball._is_friendly()`'s duplicate faction logic — removed**, delegates to
  `FiringSolver.are_hostile()`.
- **Manual per-side fire is deprecated, not deleted.** `fire_port`/`fire_starboard` still work as
  an escape hatch while auto-fire is verified on real hardware (the `docs/15_MASTER_PLAN.md` §5
  risk-register mitigation). `ShipCombat.auto_fire_enabled` toggles the new path off entirely.

### New input actions

`special_broadside` (Space / joypad 0) and `captain_ability` (R / joypad 1), both added to
`SettingsManager.REBINDABLE_ACTIONS`.

### Not verifiable headlessly

Auto-fire *feel*, broadside-indicator legibility, upgrade-card pacing, and whether encounters land
in `docs/navalCombat.md` §13's 2–5 / 5–8 / 5–12 minute bands all need a human at the controls.
The loop's *mechanics* are covered by `test_combat_loop_end_to_end.gd`, which drives
World → battle → ability → auto-fire → upgrade choice → victory → rewards → world through the real
`PlayerShip.tscn` and `EnemyShip.tscn`. **Balance is unvalidated by playtest.**

---

## Pre-M7 audit (2026-08-14)

Found while writing `docs/06_NARRATIVE_AND_WORLD.md` and `docs/11`–`15`, by direct inspection of
the resource files and UI scripts that no previous pass had cross-checked against each other.
None of these were known before. Full context for each is in `docs/14_SYSTEM_INVENTORY.md` §7.

Also confirmed in this pass, and now fixed in this document: §4's autoload registry was stale
(listed the deleted `GameManager`, omitted the registered `TutorialManager`).

| # | Defect | Status |
|---|--------|--------|
| D53 | 🔴 **Ship prices are computed from hull `mass`, in a UI script.** `IslandMenu.gd:357-359` derives `cost_gold = int(ship.mass / 100)`, `cost_wood = mass / 200`, `cost_iron = mass / 400`. The resulting ladder is catastrophically cheap: **Man O'War = 300 gold / 150 wood / 75 iron** (600 HP, 50 damage) against a starting purse of 200 gold and a level-5 Farm at **1350 gold**. Every hull is also affordable within the starting storage caps, so nothing gates it. This defeats **M6 Requirement 8 in full** — the circular economy in which combat loot funds the empire and the empire funds a better ship — because the ship half of that circle is free. It additionally violates `AGENTS.md` ("hardcoded values are forbidden"; "balance belongs inside Resources") *and* couples balance to physics: any future change to a hull's `mass` for buoyancy reasons silently re-prices it. | **Fixed 2026-08-16.** `ShipStats` gained `cost_gold`/`cost_wood`/`cost_iron`/`cost_rum`, authored on all 8 hulls to the ladder in `docs/13_CAMPAIGN_LEVELS_1-5.md` §2; the mass formula in `IslandMenu.gd` is deleted. |
| D54 | `ShipStats` has no `ship_id`, no `display_name`, and no `ship_class`. `IslandMenu._create_ship_entry()` therefore derives the shown name from the **filename** (`ship.resource_path.get_file().split(".")`), so the Shipyard reads "ManOWar" and no hull can be renamed, re-skinned, or localised. The missing class field is also why M6 Requirement 8.4 (enemy hulls trend larger as notoriety rises) has to approximate tier via `max_crew`. | **Fixed 2026-08-16.** `ShipStats` gained `ship_id`/`display_name`/`ship_class` (1–5), authored on all 8 player hulls plus the enemy raider and ghost-ship boss stats. |
| D55 | **`base_boarding_modifier` is authored on 0 of 20 captains.** `CaptainData.gd:21` exports it and `BoardingSystem.gd:80` reads `boarding_modifier` off the active captain, so the code path is live — but with no captain setting it, every captain returns the `1.0` default and **captain choice has no effect on boarding at all**. M6 Requirement 3.2 ("modified by captain traits") is half-dead. Exactly the D14 failure mode: schema exists, data was never authored, feature silently inert. Also a flavour/mechanics contradiction — `Cutlass.tres`'s entire authored personality is *"Prefers boarding actions to broadsides"* and he is mechanically no better at it than any other captain. | **Fixed** (closed during the M8 combat rework — see above). |
| D56 | `hire_cost_gold` is set on only **15 of 20** captains; the other five silently fall through to the `500` default, so they are mispriced relative to their stats. The field was added in M5 specifically so recruitment cost scales with roster depth. | **Fixed 2026-08-16.** Authored on Anne, Bartholomew, Jack, Mary, Redbeard, matching the tier the other 15 already establish. |
| D57 | **Input rebinding is silently dead.** `SettingsMenu.gd:104` and `:118` resolve the rebinding target with `get_tree().root.get_node_or_null("InputManager")` — i.e. as an autoload. `InputManager` is **not** an autoload; it is a scene-local node at `World/Systems/InputManager`. Both lookups always return null, both are null-guarded, so pressing a key in the rebind flow swallows the input (`set_input_as_handled()`), clears `_awaiting_rebind`, and re-renders the *old* binding — no error, no crash, no rebinding. **M6 Requirement 9.2 / Task 27 does not work.** Same class as D15: a feature checkpoint-verified in isolation but dead in the real tree. | **Fixed 2026-08-25.** `InputManager` promoted to a real autoload (registered after `SettingsManager`); `WorldManager`'s sibling lookup and `SettingsMenu`'s two dead root lookups now reference it directly. `tests/test_input_rebinding.gd` pins a real rebind reaching `InputMap`. |
| D58 | **Cold start is unplayable by construction.** `ResourceManager` starts the player on **200 gold**; `IslandMenu`'s colonize button costs **1000**; and `EmpireManager.home_island_id` is only ever assigned by `Island.gd:124` on a successful capture. A new player therefore owns no island, has no production, and must grind 800 gold from combat loot alone before the game's central verb (building) becomes available. | **Fixed 2026-08-25.** `World._seed_port_royal_as_home()` grants Port Royal as an owned `CAPITAL` and sets `EmpireManager.home_island_id`, guarded on "no save file exists" (a genuinely new game), never on "home_island_id happens to be empty" — an existing save with a different home island is never overwritten. `tests/test_cold_start.gd`. |
| D59 | **Map ring ordering is inverted.** In `scenes/world/World.tscn`, tier-2 `skull_cove` sits **54 u** from the home island while tier-1 `tortuga` sits **94 u**, so the first thing a new player sails toward is the tier-2 pirate stronghold. Distance stops signalling danger, which is the map's primary spatial read. | **Fixed 2026-08-14** — see the map-layout entry below. |

---

## M8 Combat Identity Rework — Phase 2 (2026-08-16)

Everything Phase 1 deferred: the M7 economy correction (D53/D54/D56, a hard prerequisite for ship
modules) and the four remaining `docs/navalCombat.md` §15 items — real per-kind encounter
behavior, enemy roles, bow/stern chasers, hull damage visuals, AI support ships, and ship level +
modules. **Suite: 214 → 249 tests, 248 passing, still exactly one known LOD failure**
(`test_property_21_lod_distance_transitions`). **249 / 248 is the number to regress against.**

Sequenced as seven waves — M7 first (Slice 8 depends on it), then cheapest/most-contained to
riskiest, so a course correction after any wave wouldn't waste work on the biggest ones:

1. **M7 economy correction** — closed D53/D54/D56, see the table above.
2. **Real per-kind encounters** — `DEFENSE`/`PROTECT_TARGET`, see the Combat section above.
3. **Enemy roles** — `AIProfileData.role` + Support behavior, see the Combat section above.
4. **Bow/stern chasers** — see the Combat section above.
5. **Hull damage visuals** — see the Combat section above.
6. **AI support ships** — see the Combat section above and the `friendly_ship` group note.
7. **Ship level + modules** — see the Fleet section above.

### A design correction made mid-plan

The approved plan for Wave B assumed `Objective.PROTECT_TARGET` belonged on `ConvoyRaid.tres`.
Re-reading `EncounterData.Kind`'s own doc comments caught the mismatch before implementation:
`CONVOY` is annotated *"merchant fleet to break"* (the player raids it for loot — already
`DESTROY_ALL`/`DESTROY_COUNT`, needed no change) while `DEFENSE` is *"protect a friendly hull or
island"* — the actual match for an escort objective. `PROTECT_TARGET` and the new `escort_scene`
went on `Defense.tres` instead.

### A second correction: `friendly_ship`, not `player_ship`

The approved plan for Waves B/F called for adding escorts/allies to the `player_ship` group.
Before implementing, a check of every `get_first_node_in_group("player_ship")` /
`get_nodes_in_group("player_ship")` call site found two that assume the group has **exactly one**
member: `CameraRig._ready()`'s fallback target, and `BoardingSystem`'s `players[0]` lookups (twice).
Joining an escort or ally to `player_ship` risked the camera or a boarding prompt silently latching
onto a support ship instead of the real player. Escorts/allies join a new `friendly_ship` group
instead, and `FiringSolver.are_hostile()` was extended to treat it identically to `player_ship` for
hostility purposes — the literal group stays single-member everywhere else in the codebase.

### Not verifiable headlessly

Whether the damage-visual thresholds actually read as "damaged" to a player, whether an AI ally
feels helpful rather than chaotic, and whether the module/level UI's pricing and pacing feel right
all need a human at the controls, same caveat as Phase 1's auto-fire feel.

---

## M7 — Campaign Spine (2026-08-25)

Closes D57/D58 (see §2's table) and replaces `TutorialManager`'s 8 hardcoded steps with a real,
data-driven, 5-chapter campaign. **Suite: 249 → 320 tests, 319 passing, still exactly one known
LOD failure** (`test_property_21_lod_distance_transitions`). **320 / 319 is the number to regress
against.**

### New data model — `scripts/world/`

- `DialogueBeatData.gd`: `speaker_id`, `speaker_name`, `portrait_path`, `text` (multiline),
  `Mood` enum (NEUTRAL/WARM/GRIM/ANGRY/AMUSED).
- `ObjectiveData.gd`: `objective_id`, `description`, `condition` (a 15-value `Condition` enum —
  `BUILD_STRUCTURE`, `UPGRADE_STRUCTURE_TO_LEVEL`, `REACH_ISLAND_TIER`, `DESTROY_SHIPS`,
  `BOARD_SHIPS`, `DEFEAT_BOSS`, `CAPTURE_ISLAND`, `DISCOVER_ISLAND`, `DOCK_AT_ISLAND`,
  `RECRUIT_CAPTAIN`, `OWN_SHIP_CLASS`, `UNLOCK_TECH`, `ACCUMULATE_RESOURCE`, `REACH_NOTORIETY`,
  `SURVIVE_RAID`), `target_id`, `target_count`, `target_value`, `is_optional`, `hint_text`.
  `REACH_ISLAND_TIER`/`REACH_NOTORIETY`/`ACCUMULATE_RESOURCE` are **level checks, not counters** —
  progress is set to the current absolute value, not incremented.
- `ChapterData.gd`: `chapter_id`, `chapter_number`, `title`, `log_summary`, `required_region_id`,
  `required_previous_chapter`, `opening_beats`/`closing_beats` (`Array[DialogueBeatData]`),
  `objectives` (`Array[ObjectiveData]`), `reward_gold`/`reward_captain_id`/`reward_ship_id`/
  `reward_tech_id`. `required_notoriety` was deliberately dropped — a region's activation
  threshold already lives in `RegionData`, and keeping it in two places invites drift.

### `CampaignManager` (new autoload, registered after `EmpireManager`)

`scripts/managers/CampaignManager.gd` — loads every `resources/campaign/chapters/*.tres` via a
`DirAccess` scan (mirrors `EmpireManager`'s region loading), sorted by `chapter_number`. Gates the
next chapter on `_gate_satisfied()` (region-active via `EmpireManager.is_region_active()`, or the
previous chapter's completion), and cascades through any number of already-satisfied gates in one
pass (`_catch_up()`) rather than advancing one chapter per signal. Listens to the same real
gameplay signals `TutorialManager` used to (docking, structure changes, ship destruction, boarding
resolution, captain recruitment, fleet changes, tech unlocks, island capture/tier change,
notoriety change, resource change, raid resolution) and dispatches them against the active
chapter's objectives by `Condition`. `get_save_data()`/`load_save_data()` return duplicates, never
live containers (the established `FleetManager` D12 convention).

Two content-authoring bugs the objective-integrity test (`tests/test_campaign_content.gd`) exists
specifically to catch: `BuildingData.building_id` is **level-suffixed** (`"farm_l1"`, not
`"farm"`), and a `BOARD_SHIPS` objective can target either a faction id or a dedicated boss
`ship_id` — the registry-selection logic must union both id pools, not faction-only.

### `TutorialManager` reduced to a thin wrapper

Kept (not retired outright) specifically so `tests/test_tutorial_manager.gd`'s coverage isn't
lost — a drop in total test count is treated as a regression in this project. Now just:
`_UNLOCK_ON_OBJECTIVE`/`_UNLOCK_ON_CHAPTER_COMPLETE` maps from `CampaignManager` signals to
`is_ui_unlocked()` flags, plus the `user://tutorial_state.json` completion-flag file I/O that
suppresses a replay for existing players. `TutorialDialogue.gd` now listens to
`CampaignManager.chapter_started`/`chapter_completed` directly and advances through a chapter's
`opening_beats`/`closing_beats` array on Continue.

### D57 — `InputManager` promoted to an autoload

`MainMenu.gd`'s Settings button is a **full scene change** (`SceneManager.change_scene_with_fade`),
so no `World` scene exists when `SettingsMenu` is open — a scene-local `InputManager` was
unreachable from there by construction, not just by a wrong lookup path. `InputManager` had no
scene-local dependency to begin with (`rebind_action()`/`reset_to_defaults()` only touch
`InputMap`/`SettingsManager`), so promotion cost nothing. `WorldManager.gd`'s sibling lookup and
`SettingsMenu.gd`'s two dead `get_tree().root.get_node_or_null("InputManager")` calls now reference
the autoload directly. `SettingsMenu` also gained sensitivity/dead-zone sliders (M2 Task 6.3),
persisted through `SettingsManager` and applied via `InputMap.action_set_deadzone()` — deliberately
**not** post-hoc filtering inside `get_movement_vector()`, which clips the exact
key-press-to-strength values `test_input_properties.gd`'s keyboard-precision property pins down.

### D58 — cold start

`World._seed_port_royal_as_home()`, called deferred from `World.gd._ready()` and guarded on
`not SaveManager.has_save_data()` (a genuinely new game only — an existing save with a different
home island is never touched), grants Port Royal as an owned `CAPITAL` and sets
`EmpireManager.home_island_id`. The old tutorial-driven "capture Port Royal" step is removed;
Chapter 1's objectives start from ownership already established.

### Content — 5 chapters, `resources/campaign/chapters/*.tres`

Authored verbatim against `docs/13_CAMPAIGN_LEVELS_1-5.md` §3-§7: **Ch1 The Drowned Port** (no
gate — starts immediately), **Ch2 Blood in the Shallows** (`required_previous_chapter = ch1`),
**Ch3 The King's Answer** (`required_region_id = "contested_waters"`), **Ch4 The Admiral's Gambit**
(`required_previous_chapter = ch3`), **Ch5 The Silver Fleet**
(`required_region_id = "imperial_waters"`). ~40 objectives, ~15 dialogue beats total. All 20
captains' `unlock_chapter_id` authored per `docs/12_CHARACTER_BIBLE.md` §4;
`IslandMenu._refresh_captains()` now hides a captain until `CampaignManager.is_chapter_completed()`
for their unlock chapter. One deliberate simplification: Chapter 3's objective 3.5 checks
`OWN_SHIP_CLASS` only, not also a "Defend Home" flag — extending the fixed `Condition` enum for one
objective wasn't judged worth it.

Two bosses got **fully dedicated** `ShipStats`/AI profile/scene/`EncounterData` (HMS Intransigent,
Cárdenas' escort) rather than reusing a shared template — `CampaignManager.DEFEAT_BOSS` matches by
`ShipStats.ship_id`, and a player-owned copy of a shared class (e.g. `ManOWar.tres`) would have
falsely satisfied the objective. **Neither boss encounter is wired into `World.tscn`'s ambient
encounter pool** — there's no in-world trigger mechanism (location/chapter-gated spawn) yet, so
they're reachable only via a manual `EncounterManager.start_encounter()` call. Building a real
trigger is a system, not content, and is out of this pass's scope. Chapter 4's "two escort
Corvettes" and Chapter 5's "screen + shore guns" multi-stage fights are both simplified to
single-boss encounters for the same reason.

### UI — Captain's Log, HUD objective feedback

`scripts/ui/CaptainsLog.gd` + `scenes/ui/CaptainsLog.tscn`: lists completed chapters (with their
`log_summary`) and the active chapter's objectives with live progress, optional objectives in a
visually distinct section. Opened from a new `WorldHUD` button, dynamically positioned top-right
(anchored inward, not squeezed into the already-tightly-sized `TopBar`). `WorldHUD` connects to
`CampaignManager.objective_completed`/`chapter_completed`/`chapter_started`/`objective_progressed`
and routes through the existing `announce_event()` — no new announcement system — including an
objective-stall hint (`hint_text`) after 90s of no progress.

### Exit criterion verified

A throwaway `Ch6_Throwaway.tres` (a `ChapterData` with one objective) was authored, confirmed to
load and be picked up by `CampaignManager._load_chapters()` with **zero script changes**, then
deleted. The data model is real, not just sufficient for the 5 authored chapters.

### Two latent test-isolation bugs found and fixed while writing this pass's tests

Both `tests/test_cold_start.gd` and (a pre-existing) `tests/test_region_gates.gd` instantiate a
real `World.gd`/`World.tscn`, whose `_ready()` unconditionally defers a real
`SaveManager.load_game()` call — so whatever save happens to be on disk (e.g. leftover manual-test
progress) gets applied to the real `EmpireManager`/`SaveManager` autoloads. Region activation is
sticky (`EmpireManager._check_region_activation()` only ever sets a region *to* active, never back
to dormant), so a stale save with real notoriety would silently and permanently activate a region
for every test that ran afterward in the same suite. Separately, `test_region_gates.gd` also tried
to construct an "isolated" `EmpireManager` node and `add_child()` it under `get_tree().root` with
`name = "EmpireManager"` — Godot rejects the colliding name on the **new** node rather than
renaming the pre-existing one (confirmed empirically), so this "isolated" instance was always
inert and every lookup, including the test's own `after_each()` `queue_free()` call, was actually
targeting the real autoload. Both files now back up/restore the real save file around their run
and save/restore `EmpireManager.notoriety`/`_region_active` directly instead of trying to shadow
the autoload.

---

## M7.5 Stabilization Pass (2026-08-25)

Found by actually running the game headfully (`scenes/debug/CaptureHarness.tscn`, which boots
straight into `World.tscn`) and looking at the rendered screenshots, not by reading code — the
same discipline the 2026-08-09 visual pass established. Both defects below were invisible to
every prior static review and to the whole GUT suite, which asserts no rendered-frame state at
all. **Suite: 320 → 323 tests, 322 passing, still exactly one known LOD failure**
(`test_property_21_lod_distance_transitions`). **323 / 322 is the number to regress against.**

| # | Defect | Resolution |
|---|--------|------------|
| D64 | 🔴 **A save with no player position silently teleported the ship into Port Royal's own collision.** `SaveManager.save_game()` wrote `"player": {}` whenever it ran with no `player_ship` group member in the tree (e.g. a test/verification harness without a full `World` scene — exactly what produced the corrupted local save this defect was found through). On load, `load_game()` couldn't distinguish "no position was ever recorded" from "recorded, and it's `{}`" — `data.has("player")` was true either way — so `player_data.get("pos_x", 0.0)`/`get("pos_y", 1.0)`/`get("pos_z", 0.0)` defaulted the ship to `Vector3(0, 1, 0)`. That default was harmless until M7 made Port Royal (which sits at that exact world origin, ~13.7-unit collision radius) the home island: loading such a save now embeds the ship in the island's own terrain, and `CameraRig`'s `SpringArm3D` (collision mask includes terrain, D31) collapses toward it, pinning the camera at the ship's own height aimed steeply into the hull/terrain — the 3D viewport renders solid black while the HUD keeps working normally (confirmed via instrumented diagnostics: sun energy, ambient light, active camera, and encounter state were all reported as completely healthy the entire time; only the camera's actual world position had collapsed toward the target). | **Resolved.** `save_game()` no longer writes a `"player"` key at all when no player node exists to read from (instead of an empty dict); `load_game()` only restores position/rotation when the save actually recorded `pos_x`, otherwise leaves the ship at the scene's authored spawn transform. Guarded by the existing `SaveManager`/`CampaignManager` test suites (no regression) — the fix is defensive-default correctness, not new behavior to unit-test in isolation. Full screenshot-driven repro, the three disproved theories tried first, and validation renders: `docs/09_VISUAL_BUG_TRACKER.md` V12. |
| D65 | 🟡 **Chapter 4/5's dedicated bosses had no in-world trigger.** HMS Intransigent (Ch4) and Cárdenas' flagship (Ch5) each got a fully dedicated `ShipStats`/scene/`EncounterData` (confirmed necessary — see the M7 section above), and each chapter's real `DEFEAT_BOSS` objective (Ch4 `4.6`, Ch5's equivalent) targets that dedicated `ship_id` — but neither `EncounterData` was in `World.tscn`'s ambient `encounter_pool`, so neither chapter was actually completable by a real player; only a manual `EncounterManager.start_encounter()` call could reach them. Honestly flagged as a known gap when M7 shipped, not silently left broken. | **Resolved.** `EncounterData` gained `required_chapter_id: String = ""` — empty means always eligible (every pre-existing encounter), non-empty gates it to only draw while `CampaignManager.is_chapter_current()` (new public helper, mirrors the existing `is_chapter_completed()`) reports that chapter as the one in progress. `IntransigentBoss.tres`/`CardenasBoss.tres` set it to `"ch4_the_admirals_gambit"`/`"ch5_the_silver_fleet"` and both were added to `World.tscn`'s `encounter_pool`. `EncounterManager._start_random_ambient()` filters candidates through the gate before picking one — a Chapter 1 player still cannot stumble into a Chapter 4 boss, and a Chapter 4 player now can reach it without a scripted trigger system. `tests/test_encounters.gd` gained 3 tests pinning the gate (excluded before the chapter, eligible once current, both authored bosses carry the right id) and extended `test_every_authored_encounter_is_loadable_and_coherent`'s path list to actually cover both boss `.tres` files, which it had never done. |

**Not fixed in this pass, noted for whoever picks up the map/discovery work in M9**: the boss fight
still has no *location* — it's a floating chance in the ambient pool for the duration of its
chapter, not "sail to Frostbite Reef and it's there," which is what Chapter 4's own opening beat
describes. A location-anchored trigger (spawn only within some radius of a named point, once)
would read better but needs the discovery/waypoint system M9 is already scoped to build; gating by
chapter alone is the smallest change that makes the fight reachable at all today.

### Checkpoint correction (2026-08-26)

The M7.5 checkpoint above self-reported "323 tests, 322 passing" and D64/D65 both fully resolved.
Re-verifying it against actual code and a real GUT run (not the recorded self-report — the exact
discipline D15/D42/D57 exist to enforce) found the code for D64/D65 correctly implemented, but
surfaced two further defects the checkpoint missed. **Suite: 323 → 324 tests, 323 passing, still
exactly one known LOD failure. 324 / 323 is the number to regress against.**

| # | Defect | Resolution |
|---|--------|------------|
| D66 | 🔴 **D65's own fix can be silently defeated by the pre-existing chapter "overshoot" catch-up mechanic.** `CampaignManager._catch_up()` (runs at boot and after every save load) walks `current_chapter_index` forward through any chapter whose gate is satisfied, but only ever checks the *next* chapter's gate — never whether the chapter currently in progress has actually been completed. Chapters 3 and 5 are gated purely by region activation (no `required_previous_chapter`), and region activation tracks notoriety, which rises continuously from ordinary combat throughout every chapter, including the one whose boss hasn't been drawn/beaten yet. A player who keeps fighting while genuinely mid-Chapter-4 can easily cross Imperial Waters' notoriety threshold before defeating HMS Intransigent; the next boot or save load then jumps `_catch_up()` straight to Chapter 5. Chapter 4 is never marked complete, its objectives freeze (dispatch only ever targets `_current_chapter()`), its reward is never granted, and — because of D65's new `required_chapter_id` gate — HMS Intransigent becomes **permanently unreachable** in the ambient pool, since `is_chapter_current("ch4_...")` no longer matches. This is the exact "boss unreachable through normal play" failure D65 was written to close, reintroduced through a different path; the live/mid-play advancement path (`_advance_to_next_chapter()`) already guarded against this, `_catch_up()` was the one caller that didn't. | **Resolved.** `_catch_up()` now stops instead of advancing whenever `current_chapter_index` still points at a real, not-yet-completed chapter (`_current_chapter() != null`) — mirroring the safety `_advance_to_next_chapter()` already had. Verified against all 4 existing catch-up tests (unaffected) plus a new one pinning the exact failure mode: `test_catch_up_does_not_abandon_an_in_progress_chapter_for_a_region_gated_next_chapter` in `tests/test_campaign_manager.gd`. |
| D67 | 🟡 **The checkpoint's recorded "323/322" GUT result does not reproduce.** A fresh full-suite run measured **323 tests, 321 passing, 2 failing** — the known LOD gap plus `test_destroying_the_composition_wins_and_pays_out` (`tests/test_encounters.gd`), which failed with gold before and after a reward grant both already pinned at the 5000 storage cap. `ResourceManager.current_resources` is a real autoload value nothing resets between test files; running `test_encounters.gd` alone passed cleanly (32/32), confirming pure cross-file state leakage — gold accumulated by earlier tests in the full run — not a defect in reward-crediting itself. Same defect class as the M7 pass's two prior `SaveManager`/`EmpireManager` test-isolation fixes, a third instance, previously undetected only because the full suite hadn't tipped gold over the cap until now. | **Resolved.** `tests/test_encounters.gd` now backs up `ResourceManager.current_resources` in `before_each()`, resets it to a known cap-safe baseline, and restores the backup in a new `after_each()` — the same backup/restore discipline `test_cold_start.gd`/`test_region_gates.gd` already use. Re-verified: full suite now reproduces cleanly at 324/323. |

---

## Presentation audit (2026-08-26) — D32 and D36 reopened, now resolved (M9)

Found by actually running the game (`scenes/debug/CaptureHarness.tscn`, headful, zero input) and
reading the resulting screenshots directly, then cross-checking the UI scene/script source — not
by re-reading the fix descriptions below and trusting them. Both defects below were previously
recorded as "Resolved" in this same document, under "Visual & physics defect sweep" above.
**Neither reproduction used any input or unusual state — this is default fresh-run behavior.**
M9 (Presentation Pass) closed all seven rows below; see `.kiro/specs/milestone-m9-presentation-pass/`
for the full requirements/design/task record.

| # | Defect | Status |
|---|--------|--------|
| D32 | Previously "Resolved" (0 errors claimed), then reopened 2026-08-26 (4 `Parameter "material" is null` startup errors reproduced). | **Resolved (M9), real root cause traced.** Not the camera spring arm (D31's fix is confirmed still correctly in place and was never the explanation) and not an ambient encounter/combat spawn path (disproved by disabling `EncounterManager.ambient_enabled` and `EnemySpawner.initial_enemies` — errors persisted regardless). Bisected via ~15 headful reproductions, narrowing by removing whole subsystems from a live `World.tscn` load (Camera → clean removal, no change; Systems managers → no change; WorldUI → no change; Islands → no change; Enemies → no change) until only `Ocean` + `PlayerShip` remained — and even that pairing only reproduced when loaded through the real `World.tscn`, not a synthetic recreation. The actual trigger: `World.gd._ready()` calls `SaveManager.call_deferred("load_game")`; when a save file exists (confirmed by moving `save_data.json` aside — 0 errors — then restoring it — 4 errors, every time), `load_game()` reassigns `player.ship_stats = FleetManager.get_active_ship()` (`SaveManager.gd` line ~220). `ShipController.ship_stats`'s setter (`ShipController.gd` line ~16) emits `ship_stats_changed` once the ship is `is_inside_tree()` — true by the time this deferred call runs — which re-triggers `ShipVisuals._rebuild_model()` a second time, freeing and rebuilding the hull model on a frame after the ship's own `_ready()`-time model (with correctly-applied materials) has already been submitted for that same frame's render. The renderer's dirty-material sync catches the old/new model mid-swap during that single transition. Confirmed harmless: every captured screenshot (including the very first frame) shows the ship correctly modeled and materialed; no test failure, no visible glitch, no gameplay impact — purely a one-time startup log artifact from a legitimate save-triggered model rebuild. Left undisturbed per Requirement 2 AC2's explicit allowance for a conclusively-traced harmless cause, rather than restructuring `ShipVisuals`/`KenneyMaterialApplier`'s rebuild timing for a cosmetic log line. |
| D36 | Previously "Resolved", then reopened 2026-08-26 (notoriety/escalation label visibly overlapping the resource bar). | **Resolved (M9).** Root cause: `WorldHUD._create_notoriety_label()`'s `offset_top = 52.0` and `ResourceBar`'s own `offset_bottom = 52.0` were two independently-hardcoded constants with no structural link; `ResourceBar`'s actual rendered height (driven by real content) could exceed its authored rect. Fixed by wrapping `ResourceBar`, the notoriety label, and the Captain's Log/World Map buttons together inside a new `TopRightPanel` `VBoxContainer` (`WorldHUD.tscn`) — Godot's own container layout, not a hand-typed offset, now guarantees they can't overlap regardless of content height. A first version of this fix cleared the resource-bar/notoriety-label overlap but silently introduced a *new* one between the notoriety label and the Captain's Log button (which still used an independent hardcoded `offset_top = 100.0` calibrated against the label's old, shorter position) — caught by a fresh headful capture, not by the new GUT test alone, which only checked the original pair. Fixed by moving the Log button into the same `TopRightPanel` stack. `tests/test_world_hud_layout.gd` now checks all three pairwise combinations (resource bar, notoriety label, Log button) at two viewport sizes. |

**New findings from the same pass, now resolved (M9):**

| # | Defect | Status |
|---|--------|--------|
| D68 | `announce_event()` rendered its banner as large, unframed, raw red `Label` text directly over the 3D world. | **Resolved (M9).** `WorldHUD.announce_event()` now wraps the label in a themed `PanelContainer` (dark-navy `StyleBoxFlat`, gold border, matching `PauseMenu`/`DeathScreen`). Added `is_warning: bool = false`; default color is gold/cream (`PirateThemeBuilder.COLOR_GOLD_BRIGHT`), the original alarm-red is now opt-in (`_on_dock_speed_exceeded()`, `_on_save_load_failed()`). Full-width auto-wrap and fade tween preserved. |
| D69 | Tutorial dialogue, the combat cannon-cooldown panel, and ambient encounters rendered with no arbitration between them. | **Resolved (M9).** `TutorialDialogue.gd` joins a `"tutorial_dialogue"` group (mirroring `WorldHUD`'s existing `"hud"` group lookup) and exposes `is_blocking()`. `WorldHUD.gd` connects to its `visibility_changed` signal and dims `CannonsContainer` (`modulate.a = 0.35`) while it's open. `EncounterManager._start_random_ambient()` returns early if a blocking tutorial dialogue is open — a second boolean gate alongside the existing `required_chapter_id` check, not a general focus-stack system. |
| D70 | `SettingsMenu.tscn`/`CreditsScreen.gd` never called `PirateThemeBuilder.build()`, the only two unthemed screens in `scenes/ui/`. | **Resolved (M9).** Both now apply the theme to their root `Control` child in `_ready()` (their `CanvasLayer` roots can't carry a theme directly, matching `MainMenu.gd`'s existing pattern), and both `.tscn`s gained a `ColorRect(0,0,0,0.7)` background overlay copied from `PauseMenu.tscn`. No settings-functionality changes; `tests/test_settings_menu.gd`'s dependency-injection pattern (`settings_manager`/`audio_manager` exports) is untouched. |
| D71 | `MainMenu.tscn`'s title had no font-size hierarchy; 2 of 5 buttons were inconsistently styled; a `VignetteOverlay` was authored but dead. | **Resolved (M9).** `TitleLabel` → 56px, `SubtitleLabel` → 20px (title > subtitle > body hierarchy). `CreditsButton`/`QuitButton` now carry the same 28px override as the other three buttons; their emoji prefixes were stripped to match. `VignetteOverlay` deleted (confirmed zero code references first). `MainMenu.gd` navigation logic untouched. |
| D72 | `IslandMenu.tscn`'s main panel was a hardcoded `custom_minimum_size = Vector2(600, 400)`, not responsive. | **Resolved (M9).** Removed the `CenterContainer` wrapper (which ignored its child's anchors entirely) and reparented `Panel` directly under the root `Control`, with `anchor_left/top = 0.1`, `anchor_right/bottom = 0.9`, and a `Vector2(480, 320)` minimum-size floor. `IslandMenu.gd` resolves every node via `%UniqueName`, so the reparent needed no script changes; all six tabs already used `SIZE_EXPAND_FILL` with no fixed-width assumption. |

**Requirement 8 (portrait fallback) — premise didn't match the codebase.** The M9 spec described
"a generic purple skull-and-crossbones icon for any character with no portrait" as the problem to
fix. No skull icon existed anywhere in the codebase. The actual state: `TutorialDialogue.tscn`'s
`PortraitLabel` was hardcoded to the same 🏴‍☠️ emoji for *every* speaker regardless of
`portrait_path` (`CaptainData.gd`/`DialogueBeatData.gd`), which was otherwise completely unread by
any code. Fixed the real underlying problem instead: added `scripts/ui/PortraitFallback.gd`
(`apply_to_label()`/`apply_to_texture_rect()`) — loads a real portrait if `portrait_path` resolves,
otherwise renders a themed monogram (the speaker's initial, gold-on-navy) so each character reads as
a distinct, deliberate design choice rather than one static glyph standing in for all 27. Wired into
`TutorialDialogue.gd._render_current_beat()`, replacing the static hardcoded emoji. (M11 later added
real `portrait_path` assets for the 20 captains, exercising the "real portrait" branch for the first
time; the 7 named cast still fall through to the monogram.)

**Unplanned, found during M9's own verification pass — D73, a pre-existing GUT-suite crash:** the
full suite segfaulted ("Lambda capture ... was freed") partway through, reproducing identically on
the pre-M9 codebase (confirmed via `git stash`) — not caused by any M9 change. Root cause: 15 test
files (`test_ammo_properties.gd`, `test_battle_upgrades.gd`, `test_boarding.gd`,
`test_captain_abilities.gd`, `test_cartagena_buildable.gd`, `test_combat_integration.gd`,
`test_combat_loop_end_to_end.gd`, `test_damage_model.gd`, `test_empire_scaling.gd`,
`test_encounters.gd`, `test_enemy_roles.gd`, `test_firing_solver.gd`, `test_ship_combat.gd`,
`test_ship_damage_visuals.gd`, `test_ship_progression.gd`) share an identical
`if not get_tree().current_scene: create a "TestScene" node` pattern with no matching cleanup —
whichever file runs last (alphabetically) before `test_navigation_integration.gd` leaks a node that
corrupts that file's later real `get_tree().change_scene_to_file()` call. **Resolved.** All 15 now
track the node they created (`_created_test_scene`) and free it / restore `current_scene` to `null`
in `after_each()`. Same defect class as D67 (`ResourceManager.current_resources` leaking across
test files) — a fourth instance of tests polluting global engine/tree state for whichever file
happens to run afterward.

**Not a defect, worth recording:** `PirateThemeBuilder.gd` itself (gold/navy palette matching the
concept art, `Cinzel`/`PirataOne` fonts, bordered `StyleBoxFlat` panels) is a competent, intentional
theme already applied to every screen (MainMenu, IslandMenu, DeathScreen, PauseMenu, CaptainsLog,
RaidReportScreen, TutorialDialogue, UpgradeChoiceScreen, WorldHUD, and now SettingsMenu/
CreditsScreen). D68–D72 were composition/consistency/regression problems, not a wrong visual
language — a bounded fixing pass, not a redesign. Full audit and the resulting roadmap change (new
milestone M9 — Presentation Pass, inserted ahead of the world-expansion work):
`docs/15_MASTER_PLAN.md` §8.

**Lesson, consistent with D9/D11/D15/D42/D57/D66/D67 above:** this is the third distinct class of
"verified, then didn't hold up" in this project's history — static code review missed scene-file
wiring (D9/D11), self-reported checkpoints missed real runtime state (D15/D42/D57/D66/D67), and now
an automated screenshot at fixed timestamps with zero input missed HUD composition problems a
human looks at once and immediately sees. All three are real gaps in verification method, not
one-off mistakes — each closed by *changing what "verified" means* for that category of defect, not
by trying harder at the same method. **M9 adds a fourth instance of the same pattern**, this time
inside the fix itself: Task 1's own first attempt (the resource-bar/notoriety-label pair) passed its
own new GUT test and looked correct in isolation, but a fresh headful capture caught a second,
narrower overlap (notoriety label vs. the Captain's Log button) that the test's original scope
didn't check. A property test only proves what it actually asserts — widening it to cover every
sibling in the same layout cluster, not just the two elements named in the original bug report, is
what actually closed it.

**New, found but not fixed — `CaptureHarness.tscn` hangs, not part of M9's scope.** While capturing
this milestone's own checkpoint screenshots, `godot --path . scenes/debug/CaptureHarness.tscn
--capture-dir=<dir>` hung reproducibly (twice, ~15-60 minutes each with declining then near-zero CPU
usage, zero PNGs written — earlier in the same session, before this started happening, the same
command had completed normally in ~13 minutes). Isolated: `scenes/world/World.tscn` loaded directly
via a `-s <script>` `SceneTree` script (bypassing `CaptureHarness.tscn`/`ScreenshotCapture.gd`
entirely) ran cleanly through all 720 frames every time, including at full scale with every M9/M10/
M11 system present. The hang is specific to the `CaptureHarness.tscn`-as-declared-main-scene path,
not `World.tscn` itself. Root cause not diagnosed — out of M9's scope, and chasing it further would
have meant debugging pre-existing project tooling (`ScreenshotCapture.gd`/`CaptureHarness.tscn`),
not a presentation-pass defect. Worked around for this milestone's checkpoint by taking the same
screenshots via a `-s` script instead. Worth a real diagnosis before the next milestone that needs
`CaptureHarness` for its own checkpoint.

---

## M10 — The Legible World (2026-08-27)

Implemented against `.kiro/specs/milestone-m10-legible-world/`, in parallel with M9 in the same
working tree (M9 owned presentation/UI-composition files; M10 avoided editing `WorldHUD.gd`/
`EncounterManager.gd` until M9's own edits to them had settled, then added one small,
additive change to each). Re-verified the spec's assumptions against the actual codebase before
starting per the spec's own instruction to do so — several had already drifted (see "Corrections
found" below).

**Verification status: engine-verified, 2026-08-27.** No Godot 4.3 binary existed anywhere on the
development machine initially (thorough search: project root, PATH, common install/download
locations, a full filesystem sweep) — the only one found was a WinGet-installed **4.7.1**, which
fails outright on this project (`CampaignManager.gd`, `TutorialManager.gd`, and the GUT addon
itself all fail to parse under it — a real cross-version GDScript incompatibility, not a fixable
one-liner). Installed a real 4.3 side-by-side (`winget install --id GodotEngine.GodotEngine
--version 4.3 --force`) and used it to actually run both required checks:
- **GUT suite: 326/326 passing, 0 failures** — the first 0-known-failures result in the project's
  history, closing `test_property_21_lod_distance_transitions` for real. Getting here required
  fixing two real bugs the run itself caught (a GDScript static-typing parse error in
  `WorldMapScreen.gd`; a stale `.godot` global-class cache from the earlier failed 4.7.1 attempt,
  which needed a full headless-editor rescan — `godot --headless --editor --quit-after 4000` —
  not just deletion, to rebuild correctly) and updating a pre-existing test file
  (`tests/test_world_map_layout.gd`) that still hardcoded the pre-Expanded ring bands and the
  original 6-island count.
- **Headful `CaptureHarness`: run and reviewed** (5 frames across the default Chapter 1 boot
  sequence). Confirmed: no HUD element overlaps another (including the new "Map" button), the
  ocean renders continuously with no visible LOD seam, tutorial dialogue and its fade-out tween
  work, live combat HUD updates correctly, the Expanded map's greater scale reads visually (several
  islands visible on the horizon from a single vantage point). **Not exercised by this particular
  capture** (it runs the game's default boot sequence, not a scripted tour): opening
  `WorldMapScreen` itself, an actual LOD near/far ring boundary crossing on screen, a per-region
  weather change, the new ship-sinking visual state. Each of those is backed by a passing unit
  test but wants a longer manual playthrough to actually see rendered.

### Corrections found during re-verification (spec assumptions vs. actual code)

The spec (written 2026-08-26, before M9 shipped) assumed several things that had already changed
or were never quite accurate:
- `IslandData.world_position`/`region_id` already existed (at Compact-layout values) before M10
  started — only Wave 2's task 6 ("add the fields") was already done; the *values* still needed
  moving to Expanded, and `World.tscn`'s node transforms still needed wiring to read from the data.
- `EnemySpawner`'s spawn box was already **not** the ±100 world-origin box the spec described — it
  had already been converted to player-relative `min_spawn_distance`/`max_spawn_distance`
  `@export`s, which self-scale with map size with no change needed.
- The "three authored ambient-enemy spawn regions" the spec asked to move don't exist as a
  literal entity — reinterpreted as scaling `World.tscn`'s `PlayerShip`/`EnemyShip1-3` placeholder
  transforms by the same ×2.5 as the islands.
- `WorldManager` already had a scaffolded-but-dead `island_discovered` signal, and
  `CampaignManager` already had a `DISCOVER_ISLAND` dispatch path (wired to docking only) — Wave 4
  was mostly "add the proximity check that finally calls what already existed," not new plumbing.
- Building-model art (Wave 8) was already ~90% done (45 of 50 `resources/buildings/*.tres` already
  had real vendored Kenney models assigned, from an earlier undocumented pass) — the spec's
  "currently 0 of 54 models" framing was stale. Only the Farm chain (actually the Rum Distillery —
  an id-naming holdover, see below) had no `model_path` set.

### Requirement 1 — Ocean LOD

Closes the project's one long-standing failing test. `scenes/world/Ocean.tscn`'s single
14,641-vertex `PlaneMesh` (`600×600`, `120×120` subdivisions, uniformly dense everywhere) is now
two concentric rings sharing one `ShaderMaterial`: `WaterMeshNear` (`300×300`, `60×60` subdiv —
same per-quad density as the old mesh) and `WaterMeshFar` (`1200×1200`, `40×40` subdiv, offset
`-0.05` on Y to avoid z-fighting where the two overlap). Both recenter under the camera together
every frame exactly as the old single mesh did (`OceanController._follow_camera()`, unchanged) —
so there's no runtime LOD-level switching and thus nothing to visually pop; it's a fixed
camera-relative density gradient, not a distance-band transition. `OceanController.get_lod_level(
distance) -> int` reports which ring a distance falls in (closes
`test_property_21_lod_distance_transitions`, which only checks for this method's existence).
`WaveGenerator.get_water_height_at()` (the CPU sampling `BuoyancySimulator` floats ships on) is
untouched — it's pure math over world position, never mesh geometry, so LOD only affects what's
drawn.

### Requirement 2 — Expanded map layout

All 6 original islands' `world_position` moved to the Expanded coordinates (Compact × 2.5,
`docs/11_WORLD_MAP.md` §4b): Port Royal (0,0), Tortuga (−175, 137.5), Skull Cove (100, −375),
Frostbite Reef (375, 150), Mount Brimstone (−450, −375), Cartagena Outpost (−500, 400).
`Island.gd::_ready()` now writes the node's `global_position` from `island_data.world_position`
(XZ only, Y stays whatever the scene authored) whenever `island_data` was actually assigned —
making the data authoritative rather than agreeing with `World.tscn`'s hand-placed transforms only
by convention. `World.tscn`'s transforms were also updated to the same values (for accurate editor
preview) plus `PlayerShip`/`EnemyShip1-3`'s placeholder transforms scaled the same ×2.5.
`EnemySpawner`'s spawn distances needed no change (see "Corrections" above).

### Requirement 3 — World map UI

New `scenes/ui/WorldMapScreen.tscn` + `scripts/ui/WorldMapScreen.gd`: three concentric region rings
drawn via `Control._draw()` at radii from the new `RegionData.display_ring_radius` field (275 /
450 / 675 u), island markers from `IslandData.world_position` for discovered islands only
(undiscovered islands are omitted entirely, not shown as a "?" — real fog of war, matching
`docs/00_VISION.md`'s Explore-pillar framing more than a spoiler-y placeholder pin would), a player
position/heading triangle reusing the same ship `global_position`/`global_rotation_degrees.y`
`WorldHUD`'s compass needle already reads, and a "View Log" button opening the existing
`CaptainsLog` rather than duplicating its objective list. Opened via a `WorldHUD` "Map" button
built with the exact same dynamic-positioning pattern as `_create_captains_log_button()` (a fourth
child of `TopRightPanel`, container-positioned).

### Requirement 4 — Discovery / fog of war

`WorldManager._check_island_discovery()` (new, called from `_process()`) checks the player's
distance to every undiscovered island in `active_islands` against a configurable
`@export var discovery_radius: float = 80.0`, and on first entry emits the previously-scaffolded-
but-never-called `island_discovered` signal. `CampaignManager` now connects to it (mirroring how it
already connects to `player_docked`) via a new `_on_island_discovered()` handler, factored out of
`_on_player_docked()` so both the dock path and the new proximity path share the same
`_mark_discovered()` write and `DISCOVER_ISLAND` objective dispatch without duplicating either.

**Real bug found and fixed along the way:** `IslandData.discovered` was never actually persisted —
`SaveManager.save_game()`'s `"islands"` section only ever stored each island's built-building-id
array, nothing else, so `discovered` silently reset to `false` on every load regardless of how it
was set at runtime. Now saved as `{"buildings": [...], "discovered": bool}`, with `load_game()`
handling both the old flat-array format (pre-M10 saves) and the new dict format for backward
compatibility.

### Requirement 5 — Per-region weather and enemy types

`RegionData` gained `wave_intensity_multiplier`/`fog_density_multiplier` (Beginner 1.0/1.0,
Contested 1.3/1.2, Imperial 1.6/1.4) and `enemy_ship_pool: Array[ShipStats]`. `EnvironmentController`
tracks the player's nearest-island region once a second and, on change, scales
`OceanSettings.wave_height`/`wave_speed` from cached pristine base values (not from the live shared
resource — see the note below) by `wave_intensity_multiplier`; `fog_density_multiplier` is
authored but not yet wired to any shader parameter (the water shader's fog is horizon-color tinting,
not a density value — no hook exists yet). `EnemySpawner._spawn_enemy()`/`spawn_hunter()` pick a
random `ShipStats` from the current region's `enemy_ship_pool` (Beginner: Sloop/Dinghy, Contested:
Schooner/Brigantine/Corvette, Imperial: Frigate/Galleon) before applying `compute_spawn_multiplier()`
on top, falling back to the old single-default-hull behavior when a region's pool is empty. New
`scripts/world/EventData.gd` resource (`event_id`, `display_text`, `weight`, `min_region_tier`) with
one `.tres` per existing hardcoded `EventManager` event under `resources/world/events/`, loaded via
the same `DirAccess`-scan pattern `EmpireManager` uses for regions; `_trigger_random_ocean_event()`
now does a weighted-random pick gated by the player's current region tier instead of a flat
`randi() % 3`.

*(This requirement's implementation was drafted by a background agent in an isolated worktree, then
merged into the main working tree by hand rather than copied verbatim — the worktree branched from
the last commit and so didn't see this same session's other in-progress M10 changes. Two real bugs
were caught and fixed during that merge, not present in what shipped: (1) the event-selection
fallback branch appended to `eligible_events` without a matching `weights` entry, which would have
thrown an index-out-of-bounds if every loaded event's `min_region_tier` ever exceeded the player's
current tier; (2) `EnvironmentController` originally cached `_base_ocean_settings` as a reference to
the same shared `OceanSettings` resource `OceanController` mutates, not a copy — so the "base" value
would have been overwritten by the first region's multiplier, and a second region change would have
compounded on top of the first instead of applying fresh. Fixed by caching `_base_wave_height`/
`_base_wave_speed` as plain floats instead.)*

### Requirement 6 — Ship damage visuals follow-up

`ShipVisuals` gained a `hull_sinking_threshold` (default 0.10, below `hull_critical_threshold`'s
0.25) — the last open item from `docs/navalCombat.md` §7. Below it: heavier smoke (the existing
particle system's velocity/scale bumped, not a second system) and a `sinking_list_degrees` (9°)
roll applied to `_model_instance` only, never the parent `ShipController`'s own transform — so
`BuoyancySimulator`'s physics and `FiringSolver`'s arc geometry (both of which read the real hull
transform) are unaffected. Same `ShipDamage.pool_changed` signal M8's damaged/critical states
already use, same cached-clean-state repair-restores-exactly pattern. New test:
`tests/test_ship_damage_visuals.gd::test_sinking_damage_lists_the_hull_and_heals_upright`.

### Requirement 7 — 2–4 new islands

Three new islands, one per existing region (not a new region): Pelican Cay (Beginner, neutral —
a resource-stop island), Blackwater Shoal (Contested, enemy — Royal Navy waystation), Isla del Rey
(Imperial, enemy — Spanish garrison). Full dossiers in `docs/11_WORLD_MAP.md` §6. All placed within
their region's Expanded ring band, ≥ 100 u clear of every neighbour (well past the 40 u physical
minimum). No new mechanics — same shared `Island.tscn`, same `DockingSystem`.

### Requirement 8 — Building-model art sourcing

Closed as a full 50/50 assignment, not a partial one. 45 of 50 `resources/buildings/*.tres` already
had real vendored Kenney models from an earlier undocumented pass (Watchtower → `tower-watch.glb`,
Fortress → `tower-complete-large.glb`, Academy → `tower-middle-windows.glb`, Mine →
`tower-base.glb`, Warehouse → `tower-complete-small.glb`, Market → `structure-platform-small.glb`,
Lumber Mill → `structure-platform.glb`, Shipyard → `structure-platform-dock-small.glb`, Tavern →
`castle-door.glb`). The remaining 5 (`Farm_L1..L5.tres` — actually the **Rum Distillery** chain, an
id-naming holdover unrelated to farming; `building_name`/`description`/`produces_resource` all say
"rum") got `crate-bottles.glb`, matching the same one-model-per-whole-chain convention every other
chain already uses. `docs/10_ASSET_REQUESTS.md` updated with a status callout — the custom-art
generation prompts it contains were never used.

### Requirement 9 — Minimal save-schema version stamp

`SaveManager.SAVE_SCHEMA_VERSION := 1`, written as `save_schema_version` at the top level of
`save_game()`'s dict, read (not migrated) by `load_game()` defaulting absent values to `0`. Purely
additive, no other save/load behavior changed.

### Test suite

**326 tests, 326 passing, 0 known failures** — confirmed by a real Godot 4.3 GUT run (see the
verification-status callout at the top of this section). First 0-known-failures result in the
project's history; **326/326 is the new number to regress against.** Two new tests were added
during M10 (`test_ship_damage_visuals.gd`'s sinking-list test for Requirement 6;
`tests/test_world_map_layout.gd` gained the 3 new islands and Expanded ring bands rather than a
net-new test file). No existing test's behavior changed.

## M11 — Depth (2026-08-28)

Implemented against `.kiro/specs/milestone-m11-depth/`, entirely in this session (no second
implementing agent, per `docs/07_AI_AGENT_WORKFLOW.md`). Started only after independently
re-verifying M10's checkpoint (326/326 GUT, headful capture reviewed) had actually passed, per
Rule 8. Two spec-drift corrections made with direct evidence before implementing, not guesses: the
boss-count arithmetic in `requirements.md` ("bringing the total to 3") was stale — 3 boss
`EncounterData` files already existed pre-M11 (Ghost Ship, Intransigent, Cárdenas), not 1 — so the
literal "2 new dedicated bosses" acceptance criterion was followed as written, landing at 5 total;
and the content-volume table in `docs/14_SYSTEM_INVENTORY.md` was refreshed in full (not just the
M11-owned rows), since several unrelated rows (Chapters, Islands) had been stale since before M7/M10.

**Verification status: engine-verified, 2026-08-28.** Full GUT suite run for real at the final
checkpoint; the headful `CaptureHarness` capture is from mid-milestone (a final re-run hung — see
below), not self-reported in either case:
- **GUT suite: 391/391 passing, 0 failures.** Entered the milestone at M10's verified 326/326
  baseline; every test added across all 9 waves is additive (65 new tests), no existing test's
  expected behavior changed except where Wave 3's armor-facing change made an existing test's
  premise genuinely obsolete (see Requirement 4 below — updated, not weakened). Two real
  regressions were caught and fixed mid-implementation by this same GUT discipline: a storage-cap
  interaction that silently zeroed a trade-route gold-gain assertion (`ResourceManager.max_storage
  ["gold"] = 5000`, and the test's own `before_each()` was topping gold up to exactly that cap —
  fixed by draining to a known baseline before measuring a delta, not by raising the cap), and a
  pre-existing `test_combat_loop_end_to_end.gd` gold-increase assertion that was order-dependent on
  ambient economy-tick timing across the full suite (fixed by pinning gold to a known-low value
  before capturing `gold_before`, the same fix category).
- **Headful `CaptureHarness`: run and reviewed mid-milestone (after Wave 3), not successfully
  re-run at the final checkpoint** (5 frames across the default Chapter 1 boot sequence, same
  harness M10 validated). Confirmed at that point: world/ship/island rendering intact, no new
  script errors from Waves 1–4's changes (including wind/arcing/armor), ocean/HUD render
  correctly. A final re-capture attempt after Waves 5–9 hung indefinitely (~8 minutes, unlike
  every other run this session) for an unresolved reason and was killed rather than left
  blocking — Waves 5–9 are content authoring/UI/asset wiring, covered by the 391/391 GUT suite,
  not a second category of rendering risk the way Wave 3 was. **Not exercised by either capture**
  (the tutorial dialogue blocks headless progression past the opening beat, and this project has no
  scripted-input capture tool): the wind indicator's actual on-screen rotation, a live cannon shot's
  visible arc, hull-facing armor's effect on the damage-tint threshold, and the new captain
  portraits in the Tavern tab. Each is covered by a passing unit test (wind direction/speed math,
  cannonball flight-time-to-splash, facing-multiplier composition, portrait asset resolution) but
  genuinely wants a human playtest to see rendered — flagged explicitly rather than claimed, per
  this project's established "needs a human at the controls" discipline for camera/gamepad/shader
  work. **Wave 7 (audio) is the one item in this milestone verifiable by ear, not by screenshot or
  test** — a human listening pass has not happened.
- A custom combat-specific capture harness (spawn an enemy, wait for auto-fire, catch a cannonball
  mid-flight on screen) was attempted and abandoned — it hung indefinitely even after fixing an
  obvious cause (duplicate node names), for a reason not root-caused given the milestone's scope.
  The files were deleted rather than left as broken debug tooling in the tree.

### Requirement 1 — Tech tree expansion

`TechData.gd` gained `required_island_tier: int` (mirrors `BuildingData`'s existing tier-gate
pattern exactly) and `required_prerequisite_tech_id: String`. `TechManager.gd` gained
`can_research(tech, island_tier) -> bool`, the single gate check both the tier and prerequisite
conditions route through — `IslandMenu.gd`'s Research tab calls it rather than duplicating the
tier/prerequisite comparison inline, so there's one source of truth for "can this be researched"
tested independently of the UI (`tests/test_tech_gating.gd`). Tech loading switched from a
hardcoded filename list to a `DirAccess` scan of `resources/techs/` (the same pattern
`EventManager` already used for `resources/world/events/`), so adding a tech no longer requires a
matching code edit.

11 new techs authored (2 → 13 total, within the 12–15 target), forming two real 4-deep
prerequisite chains rather than a flat unlock-anything list (Requirement 1.2's explicit "not all
available from game start"): a health chain (`reinforced_hulls` → `sturdier_hulls` →
`heavy_plating` → `mastercraft_hulls`) and a damage chain (`advanced_cannons` → `cannon_mastery` →
`powder_efficiency` → `siege_cannons`), plus a shorter storage chain (`larger_storage` →
`deep_hold` → `grand_cargo`) and a 2-deep speed chain (`swifter_sails` → `copper_plating`). No 5th
modifier category was added — every new tech expresses its effect through the 4 categories
`TechManager` already applies (health/damage/speed/storage). Costs authored against
`docs/BALANCE_MODEL.md`'s tier bands (see Requirement 10).

### Requirement 2 — Wind and sail-trim mechanic

`RegionData.gd` gained `wind_strength: float` (0–1) and `wind_direction_degrees: float`, authored
per region on the same calm-to-harsh escalation M10 already established for
`wave_intensity_multiplier` (Beginner 0.2, Contested 0.5, Imperial 0.8). `ShipMovement.gd`'s
existing multiplicative `speed_mod` chain (captain ability → sail-damage penalty → battle-upgrade
`speed_mult`) gained wind as one more term — a ship heading the same way the wind blows (dot +1)
runs fastest, heading into it (dot −1) is slowest, `lerp(0.85, 1.15, ...)` scaled by the region's
`wind_strength`. Applies to every ship, player and AI. Deliberately never touches
`BuoyancySimulator` or the yaw servo — this project's own fragility note on ship stability (4
stacked historical root causes) made that a hard constraint, not a suggestion.

Wind is discovered via a new `"environment_controller"` group (`EnvironmentController.gd` joins it
in `_ready()`) and a new `get_current_region() -> RegionData` accessor, looked up once per
`ShipMovement`/`WorldHUD` instance rather than every physics frame. **Real bug found while wiring
this**: `if node:` truthy checks on a cached-but-since-freed node reference don't catch a freed
instance in GDScript (a freed `Object` isn't `null`, just invalid) — this threw "previously freed
instance" errors across unrelated test files once a fake `EnvironmentController` in one test's
`after_each()` was freed while another cached reference still pointed at it. Fixed with
`is_instance_valid()` in both `ShipMovement.gd` and `WorldHUD.gd`.

Visual legibility: `WorldHUD.tscn`'s `CompassPanel`/`CompassNeedle` gained a `WindArrow` label
nested inside `CompassNeedle` (inherits the same ship-yaw rotation the N/S/E/W letters get "for
free," so its own local rotation only needs to add the wind's bearing on top), visible only when
`wind_strength > 0`, opacity scaled by strength.

### Requirement 3 — Cannonball arcing

`Cannonball.tscn`'s `gravity_scale` raised from 0.5 to 0.7 — real, more pronounced curvature than
the near-flat 0.5 M8 shipped, quantitatively verified (`tests/test_cannonball_arcing.gd` asserts
the ball drops further at a fixed elapsed time than the old gravity_scale would have, not just
"some gravity exists"). Rather than accept the resulting ~29% shorter flight time as a stealth
range nerf across every ship (Requirement 3.3's explicit "shall not regress cannon_range's
already-balanced reach"), every ship's `cannon_speed` was raised by the exact compensating factor
(`old_flight_time / new_flight_time ≈ 1.41`) so authored `cannon_range` values didn't need to
change at all — reach is preserved, only flight time and visual arc changed. `cannon_range`/
`chaser_range` values across all 11 ship resources are untouched.
`test_combat_integration.gd`'s reachability assertion (`FALL_TIME`) updated from 0.83 to 0.70 to
match the real new physics, re-verified against every ship, not weakened. `FiringSolver.gd` needed
no changes — its range gates are pure distance/angle, no ballistics in the solver itself.

### Requirement 4 — Hull-facing armor variance

`ShipStats.gd` gained `bow_armor_multiplier` (default 0.75 — thick forward timbers *reduce*
damage, unlike `stern_crit_multiplier` which *increases* it because the stern is the exploitable
weak point) and `bow_arc_degrees` (**defaults to 0 — off**, not the stern arc's 60°). This was a
deliberate choice, not an oversight: a nonzero default would have silently changed the damage
taken by every existing test that reuses `Vector3.FORWARD` as a generic "any direction" hit vector
(a real, wide-established idiom across 8+ pre-existing test files, since only the stern used to be
special-cased). `ShipDamage.apply_hit()` now computes facing once — stern arc takes priority
(unchanged behavior) over bow, anything outside both arcs takes the `broadside_armor_multiplier`
baseline (default 1.0) — applied before the existing ammo-type multipliers, extending the stack
rather than replacing the stern-crit line.

`bow_arc_degrees`/`bow_armor_multiplier` were then explicitly authored onto every real ship
resource (all 8 player ships, `EnemyShipStats`, `GhostShipStats`, `CardenasEscortStats` at the
standard 60°/0.75; **HMS Intransigent at a wider 70°/0.5** — making the boss's established "heavy
front armour" flavor text from `docs/13_CAMPAIGN_LEVELS_1-5.md` §6 an actual mechanical incentive
to out-turn her and work the stern arc, not just narration). One pre-existing test
(`test_ship_damage_visuals.gd`, 4 assertions tuned to exact hull-fraction thresholds) switched its
hit vector from `Vector3.FORWARD` to `Vector3.RIGHT` (squarely broadside) since `EnemyShipStats`
now has real bow armor and a frontal hit would no longer deal the fraction those thresholds were
authored against — a real, documented behavior change, not a weakened test.

### Requirement 5 — 2 more bosses

**The Iron Vulture** (`resources/enemies/IronVultureStats.tres`, 220 HP, class 3) — an artillery
specialist: `AIProfileData` role BOSS, `ammo_preference = "ChainShot"` (crippling sails, teaching
mobility over volume of fire), `cannon_range` authored at ~85% of reachable distance rather than
every standard hull's ~75%, giving her a genuine outranging advantage that backs the AI flavor with
real mechanical teeth. Ambient, Contested Waters (`min_region_tier = 2`).

**Fortune's Toll** (`resources/enemies/FortunesTollStats.tres`, 350 HP, class 4) — a balanced
privateer with `has_bow_chaser = true`, a positioning threat distinct from Intransigent's tanking
and Cárdenas' multi-stage escalation. Ambient, Imperial-adjacent (`min_region_tier = 3`).

Both follow the dedicated-scene pattern (`IronVultureBoss.tscn`/`FortunesTollBoss.tscn`, cloned
from `BossShip.tscn`'s structure with only `ship_stats`/`ai_profile` swapped) rather than reusing
the generic `BossShip.tscn` — **a real architecture finding along the way**: `BossShip.tscn`
hardcodes `ship_stats = ManOWar.tres` in the scene file itself, and ambient bosses (Ghost Ship)
don't route through `EncounterData`/`EncounterManager` at all despite `GhostShipBoss.tres`
(`resources/combat/encounters/`) existing — the real ambient-spawn mechanism is a hardcoded
`event_id` match-case in `EventManager.gd` calling a dedicated `_spawn_*_boss()` function per boss.
`GhostShipBoss.tres`'s `EncounterData` file is effectively dead data for the ambient path (only
chapter-gated bosses actually consume `EncounterData` via `EncounterManager`). Both new bosses
follow the *real*, working mechanism (`EventData` + a dedicated `_spawn_iron_vulture_boss()`/
`_spawn_fortunes_toll_boss()` function in `EventManager.gd`) rather than authoring more dead
`EncounterData` files to match the existing (inconsistent) precedent.

### Requirement 6 — Diplomacy and trade routes

**Tribute**: `FactionManager.pay_tribute(faction_id) -> bool` — spends `TRIBUTE_COST_GOLD` (500) for
`TRIBUTE_REPUTATION_GAIN` (+15) reputation, gated by a 300-second per-faction cooldown
(`_tribute_cooldown_remaining`, ticked in a new `_process()`). Surfaced in `IslandMenu.gd`'s Trade
tab as a "Pay Tribute" entry per faction, disabled while on cooldown or unaffordable. Save format
kept **flat** (reputation scores directly at the dict's top level, cooldowns under one namespaced
`_tribute_cooldown_remaining` key) specifically to avoid breaking `test_faction_manager.gd`'s
existing round-trip test, which reads `saved[faction_id]` directly — a nested
`{"reputation_scores": {...}}` shape was tried first and reverted once that test caught it.

**Trade routes**: `FleetManager.assign_trade_route(ship_index, captain_index, route_name,
region_tier)` — a named, region-tied variant of the existing `"trade"` mission using the exact same
`active_missions` dict and economy-tick mechanism (Requirement 6.2's own framing: "the tick logic
doesn't need to change, only how it's exposed"), scaled by `region_tier` so a route into more
dangerous waters pays more. `IslandMenu.gd`'s Fleet tab's old flat "Trade" button now reads
"Trade Route" and derives the route's name/tier from the island it's opened at
(`EmpireManager.get_region_for_island()`), and the fleet-status line now shows the route's actual
name instead of a generic "Trade" label.

### Requirement 7 — World events expansion

6 new `EventData` resources (3 → 9 "variety" events, within the 8–10 target; 11 total files in
`resources/world/events/` once the 2 boss ambient events from Requirement 5 are counted, though
those track the boss target, not this one): **Drifting Wreckage**/**Smugglers' Cache** (small/large
loot spawns, sharing a new parameterized `_spawn_loot()` helper with the existing
`_spawn_floating_treasure()`), **Pirate Raiding Party**/**Royal Navy Patrol** (hostile ship
spawns, sharing a new parameterized `_spawn_hostile_ships()` helper with the existing
`_spawn_merchant_convoy()`), and **Favorable Winds**/**Becalmed** — a direct tie-in to Requirement
2's new wind mechanic: `EventManager._apply_temporary_wind_modifier(multiplier, duration)`
temporarily scales the player's current region's live `wind_strength` (a shared `Resource`, same
instance `ShipMovement`/`WorldHUD` read) and restores the exact original value on a timer, the same
non-compounding caution `EnvironmentController`'s own per-region weather code already documents.

### Requirement 8 — Full SFX pass and music

`AudioManager.play_sound()` now checks `.ogg` before `.wav` (Kenney's CC0 packs — this project's
established asset-sourcing precedent for 3D models — ship as `.ogg`; `.wav` stays supported for
any hand-authored/Bfxr-exported asset). New `play_music(track_name, loop)`/`stop_music()` — a
persistent `AudioStreamPlayer` on the `Music` bus, idempotent for an already-playing track,
correctly branching `AudioStreamOggVorbis`'s plain `loop` bool vs. `AudioStreamWAV`'s `loop_mode`
enum (they are not interchangeable properties).

**25 SFX cues + 2 music tracks sourced and placed** (0 → 25, within the 25–30 target), all
CC0/CC-BY licensed, real attribution added to `CreditsScreen.tscn`: Kenney's UI Audio/Impact
Sounds/RPG Audio/Music Jingles packs (CC0, kenney.nl) for SFX and short stingers; "Drunken Sailor"
(OPL2 rendering, CC0, opengameart.org) for main-menu music; "Pirates!" by Eric Matyas/Soundimage.org
(CC-BY 4.0, credited) for in-world sailing music. **21 real call sites wired** across the codebase
covering every category Requirement 8.1 lists — cannon fire and explosion were already wired
(just silent until now); this pass added building construct/upgrade (`Island.gd`), boarding
start/success/fail (`BoardingSystem.gd`), victory/defeat (`EncounterManager.gd`), resource
collection (`LootDrop.gd`), gold-gain-adjacent tech/ship/captain purchases, docking
(`DockingSystem.gd`), island discovery (`WorldManager.gd`), treasure-found and wind-shift
(`EventManager.gd`), ship level-up (`FleetManager.gd`), and 5 UI interaction cues (`IslandMenu.gd`
tab-switching, close, tribute confirm/error). `ui_cancel` has an asset file but no call site yet —
the only authored-but-unwired cue.

**Found and fixed 3 real pre-existing syntax bugs along the way**: `IslandMenu.gd` had three
locations with broken indentation (an extra or missing tab breaking the surrounding `if`/`elif`
block) left over from an earlier, unrelated internationalization pass that wrapped UI strings in
`tr()` — a hard parse error, not a style issue, cascading into `WorldHUD.gd` failing to load too
(it references `IslandMenu` as a static type). Found via the GUT suite itself once this session's
own edits to the same file surfaced them; fixed as straightforward indentation corrections, the
`tr()` wrapping itself left untouched.

**Human listening pass not done** — no tool available in this environment can confirm audio
actually sounds right, matching this project's own established discipline for anything only a
human ear/eye can verify.

### Requirement 9 — Portrait sourcing/integration

`PortraitFallback.gd` gained `apply_to_texture_rect(texture_rect, fallback_label, portrait_path,
display_name)` — the upgrade path its own doc comment had anticipated since M9: shows real art via
a `TextureRect` when `portrait_path` resolves, otherwise hides it and falls through to the
existing monogram `Label` treatment, one shared contract instead of two decision paths per caller.
`apply_to_label()` (the original, Label-only contract) is unchanged and still used by
`TutorialDialogue.gd` for the 7 named cast, none of which have portrait art in this pass.

**20 of 27 characters got real portraits** — the 20 captains, not the 7 named cast. Since no
free, single-download, pirate-themed character-portrait asset pack was found (the one good match,
itch.io's "50 Avatar Pirate Icons," requires a paid purchase this session didn't have authorization
to make), portraits are **originally-generated flat-color icon busts** — a solid background color
+ a simple silhouette bust shape + the character's initial, as SVG (Godot imports SVG natively;
the project's own `icon.svg` already proved this) — exactly the "simple programmatic/stylized
portraits... if bespoke character art isn't feasible" substitute Requirement 9.2 itself names as
acceptable, not an invented workaround. 20 distinct files in `assets/portraits/`, each captain's
`portrait_path` wired, `IslandMenu.gd`'s Tavern tab (`_create_captain_entry`) upgraded with a
`TextureRect`+fallback-`Label` pair via the new `apply_to_texture_rect()` — the first UI surface
where a captain portrait actually renders. The 7 named cast keep M9's intentional monogram
fallback, per Requirement 9.3's explicit allowance that this is a legitimate close-of-milestone
state, not a regression.

**Discovered along the way**: newly-added binary asset files (audio, SVG portraits) are invisible
to `ResourceLoader.exists()`/`load()` in a headless GUT run until Godot actually imports them —
copying files into `assets/` isn't sufficient by itself. Fixed by running
`<godot-binary> --headless --import --path .` once after adding new assets, which generates the
`.import` sidecar files the resource system needs; this is now a known step for any future asset
drop, not just this milestone's.

### Requirement 10 — Balance model

New `docs/BALANCE_MODEL.md`, anchored to the one balance ladder this project has real numbers for
(`docs/13_CAMPAIGN_LEVELS_1-5.md` §2's ship-cost ladder, verified directly against the live
`resources/ships/*.tres` `cost_gold`/`cost_wood`/`cost_iron` values — they match exactly). Covers
tech tier cost bands (T1 existing anchors, T2–T5 derived), boss loot tiers (existing Intransigent/
Cárdenas rewards as the anchor, the 2 new bosses scaled below), and world-event outcome bands
(expressed as a percentage of the region-tier-appropriate ship cost, not an isolated guess) — the
exact discipline the D53 pricing incident (`docs/13_CAMPAIGN_LEVELS_1-5.md` §2) skipped the first
time.

### Test suite

**391 tests, 391 passing, 0 known failures** — confirmed by a real Godot 4.3 GUT run. Entered this
milestone at M10's verified 326/326; 65 new tests added across all 9 waves
(`test_tech_gating.gd`, `test_wind_system.gd`, `test_cannonball_arcing.gd`, `test_armor_facing.gd`,
`test_boss_ai_profiles.gd`, `test_diplomacy_and_trade_routes.gd`, `test_world_events_expansion.gd`,
`test_audio_sfx_and_music.gd`, `test_portraits.gd`). Two pre-existing tests were updated to match a
real, deliberate behavior change (not weakened): `test_damage_model.gd`'s stern-crit test and
`test_ship_damage_visuals.gd`'s hull-threshold tests both switched from `Vector3.FORWARD` to a
broadside-safe hit vector now that bow-facing armor is real. **391/391 is the new number to regress
against.**

## M12 — Playtest & Instrumentation (2026-08-28)

Built concurrently with M11 in the same uncommitted working tree — same caveat M10's entry above
already recorded for its own overlap with M9: check `git status`/`git diff` before assuming a file
matches this description.

### Requirement 1 — Analytics

New `AnalyticsManager` autoload (`scripts/managers/AnalyticsManager.gd`). No maintained Firebase/
Godot integration exists in this repo, so — per its own documented decision, not a workaround —
events go to an append-only, size-rotated (256KB, one previous-file rotation) JSON-lines log under
`user://telemetry/funnel.jsonl`. Single public boundary: `log_event(name, params)`, sanitizing to
primitives only (`_sanitize_params` drops anything else with a warning, never identifying data).
`log_first_event(name, params)` records a one-time funnel milestone (`first_colonize`,
`first_raid_survived`/`first_raid_lost`, `first_boss_defeat`, `new_game_started`) via a small
persisted `first_events.json` so repeats don't reappear. Wired to existing signals only —
`CampaignManager.chapter_started`/`chapter_completed`, `EmpireManager.island_captured`/
`raid_resolved`, plus `EncounterManager.encounter_started`/`encounter_ended` via `on_world_ready()`
(scene-local systems don't exist at autoload `_ready()` time) — no call sites were instrumented a
second time. A future consented backend can replace the local-log body of `log_event()` without
touching any caller. Focused test: `test_analytics_manager.gd` (3/3).

### Requirement 2 — Crash reporting

New `CrashReporter` autoload (`scripts/managers/CrashReporter.gd`). A session marker file is
written on start and removed on `mark_clean_shutdown()` (called from `MainMenu._on_quit_pressed()`);
finding the marker still present on next boot means the previous session ended abnormally, which
creates a bounded, non-identifying report bundle (`report_version`, `reason` — no player id, no
telemetry cross-reference) and exposes `has_pending_report`. `MainMenu._show_crash_report_notice()`
shows an opt-in `AcceptDialog` disclosing the report's existence without blocking play; nothing is
sent anywhere automatically — there is no configured support endpoint in this repo to send it to,
so an honest local-only bundle is the implemented state, not a stopgap. Focused test:
`test_crash_reporter.gd` (2/2).

### Requirement 3 — Save versioning, backup, migration

`SaveManager.SAVE_SCHEMA_VERSION` (1) built on M10's `save_schema_version` field.
`_migrate(data, from_version)` (line ~338) runs one `match` arm per historical transition — today
just `0 → 1`, converting M10's flat per-island building arrays into the
`{"buildings": [...], "discovered": false}` record shape it later needed for discovery state,
intentionally not rebalancing anything else. `_backup_existing_save()` copies the current
`user://save_data.json` to `user://save_data.json.bak` before every overwrite (a single rotating
backup, not a history). `load_game()` now tries the primary file, falls back to the `.bak` copy on
failure, and only then gives up and starts fresh — extending the existing `save_load_failed` signal
path (M2 Task 12.3) rather than adding a new one. `MainMenu` now checks
`SaveManager.has_recoverable_save_data()` (not the old `has_save_data()`) so the Continue button
reflects backup-recoverable state too. Focused test: `test_save_migration.gd`.

### Requirement 4 — Localization

Godot's built-in `.csv`/`tr()` translation system, scoped to UI-chrome literals (labels, buttons,
tooltips, format templates) in `MainMenu.gd`, `WorldHUD.gd`, `IslandMenu.gd`, `SettingsMenu.gd`,
`CaptainsLog.gd`, plus `CodexScreen.gd` and the raid-outcome text shared between
`RaidReportScreen.gd`/`LocalNotificationManager.gd` (Requirement 8's own fix touched this too).
`translations/en.csv` (~150 keys) compiles via Godot's `csv_translation` importer to
`translations/en.en.translation`, now actually registered via a `[internationalization]` section in
`project.godot` — that section didn't exist before this milestone, so no `tr()` call resolved
anything regardless of how much wrapping existed. Every dynamic string follows
"translate the template, then interpolate" (`tr("Notoriety: %.1f") % val`), never the reverse.
Explicitly out of scope: strings sourced from `.tres` Resource data (building/tech/captain names &
descriptions) — localizing game content is a separate, much larger effort with no pipeline decided
yet. Focused test: `test_localization.gd` (3/3, covers the translate-then-interpolate convention
and that the compiled resource actually loads/registers).

### Requirement 5 — Playtest protocol

`docs/PLAYTEST_PROTOCOL.md` (new, unnumbered like `docs/BALANCE_MODEL.md` — the sequential `00`–`21`
numbering is already fully occupied by later milestones' own planning docs). Covers recruitment
(informal is legitimate for a first round), session structure, when to intervene vs. observe, what
to record (centered on M7's still-unverified "does Chapter 1 complete without a wiki" question),
and per-participant/round-summary logging templates with an explicit rule against rounding up or
asserting the ≥10-participant target without evidence.

**No real round has been run.** This requires recruiting and observing actual external humans,
which no session working on this repo has a channel to do — the same category of gap as M11's
Task 13 (human audio listening pass). Real participant count as of this writing: **0**. The
protocol is ready for the project owner to run; this is flagged honestly rather than asserted.

### Requirement 6 — Balance spreadsheet

`docs/BALANCE_MODEL.md` extended (§5–§9) to cover every remaining resource/encounter category with
a real cost or reward field: buildings (a uniform 3.5×/18× per-level cost curve confirmed across 4
building types), ship modules (two price bands by modifier strength/count), captains (cost ranges
by unlock chapter, cross-referenced against the ship-cost ladder), the raid theft fraction (the
actual `EmpireManager._resolve_raid()` formula, previously undocumented anywhere), and the
loot-table-to-encounter mapping (verified each encounter's `loot_table` `ExtResource` reference
resolves to the intended tier, not just an identically-named local id). Ammo, battle upgrades, and
AI profiles were confirmed to have no cost/reward fields and are correctly out of scope for an
economy model.

### Requirement 7 — Codex / lore browser

New `scenes/ui/CodexScreen.tscn`/`scripts/ui/CodexScreen.gd`, opened via a `WorldHUD`-owned
dynamically-positioned button (`_create_codex_button()`, same container-owned placement pattern as
the Log/Map buttons beside it). Reuses existing data and gating wholesale — no new "have I met
this" tracking: completed chapters via `CampaignManager.is_chapter_completed()` +
`ChapterData.log_summary`, captains via the same `unlock_chapter_id`/owned-roster check
`IslandMenu`'s Tavern already used, factions derived from the encountered-captain roster's
`allegiance_faction_id`. Needs a visual capture at checkpoint to confirm on-screen legibility (not
verifiable headlessly).

### Requirement 8 — Push notifications

`LocalNotificationManager` autoload — a no-op-safe adapter for an optional
`PirateLocalNotifications` Android engine singleton; no such plugin is bundled in this milestone,
so every call degrades to a harmless no-op on desktop/unconfigured exports. Re-scoped on verified
evidence rather than the requirement's original assumption: building/upgrading is instant-on-
purchase (no timer), fleet missions are recurring/indefinite with no completion event
(`FleetManager._on_economy_tick()` — confirmed by reading the code, not assumed), and raids are a
stochastic per-`_process`-tick re-roll (`EmpireManager._check_raid()`, ~900s cadence) with no fixed
future resolution timestamp to schedule against in advance. The only genuine "resolves whether or
not you're watching" event is raid resolution, wired reactively via `EmpireManager.raid_resolved`.
`EmpireManager.describe_raid_outcome(report)` is now the single source of truth for the outcome
sentence, used by both `RaidReportScreen.gd` (the real raid-outcome UI — not `WorldHUD.announce_event()`,
which doesn't compose raid text at all, contrary to the original design assumption) and
`LocalNotificationManager.get_raid_notification_body()`, closing a real wording-drift gap between
the two surfaces. Permission flow (`_ensure_permission_or_plugin()`) requests lazily, persists a
"requested" flag so a denial is never re-prompted, and always live-checks `has_permission()` so a
later OS-settings grant is picked up. Focused test: `test_local_notification_manager.gd` (4/4,
including a fake-plugin test asserting exactly one permission request across three calls).
**Device-level verification of the real Android permission dialog has not been done** — no Android
device/export was available in this environment; flagged rather than assumed passing.

### Test suite

**396 tests, 396 passing, 0 known failures** — confirmed by a real Godot 4.3 GUT run. Entered this
milestone at M11's 391/391 (which, per this run, now includes a previously-flagged LOD test
passing that M11's own doc entry above still lists as 0 known failures at 391 — LOD work appears to
have landed in the shared working tree since that entry was written; M11 owns updating its own
section). 5 new tests added: `test_localization.gd` (3) and two additions to
`test_local_notification_manager.gd` (raid-wording drift guard, permission-request-once guard).
**396/396 is the new number to regress against.**
