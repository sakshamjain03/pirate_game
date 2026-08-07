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
| D9 | *(Original claim: no `SpringArm3D` collision configured, ORBIT/LOOK are dead stubs.)* | **Corrected, not a real defect (collision part).** `CameraRig.tscn`'s `SpringArm3D` already had a real `SphereShape3D` + `collision_mask=3` covering both islands (`collision_layer=1`, default) and enemy ships (`collision_layer=2`) — this was already working before M3 started; the original audit was wrong here. The ORBIT/LOOK part *was* a real stub — fixed with an explicit "deferred" comment in `CameraRig.gd`; no new mode logic was implemented (`set_mode()` still accepts them, they just run FOLLOW behavior for now). |
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

```
GameManager, SaveManager, SceneManager, SettingsManager, AudioManager,
ResourceManager, FleetManager, TechManager, EventManager, FactionManager,
EmpireManager
```

`ScreenshotHarness` (D4) has been removed from `[autoload]`; it's now invoked manually only,
per its own header comment.

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
