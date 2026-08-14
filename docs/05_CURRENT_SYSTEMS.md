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
  `FactionManager` hostility, flees at low HP. Assigns `AIProfileData` resources (e.g. `HarassingSloop.tres`, `AggressiveGalleon.tres`) to govern aggression, distance, flee threshold, and ammo preference.
- `EnemySpawner.gd` — spawns/caps enemy population, weights faction selection by reputation
  (worse reputation with a faction → more of their ships spawn), exposes `spawn_hunter()`.
- `LootDrop.gd` / `LootTableData.gd` / `BoardingSystem.gd` — death drops and boarding rewards rolled from a faction/boss-specific loot table. Rewards dynamically scale with the destroyed ship's class (`max_crew`) and current empire `notoriety`.

**Known gaps:** no cannonball arcing (straight-line only), no armor/hull-facing variance, no
boarding, no multi-ship fleet coordination.

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

Re-read directly from `project.godot` on 2026-08-14. The previous version of this section was
**stale**: it listed `GameManager`, which no longer exists (only an orphaned
`scripts/managers/GameManager.gd.uid` remains), and omitted `TutorialManager`, which *is*
registered.

```
SaveManager, SceneManager, SettingsManager, AudioManager, ResourceManager,
FleetManager, TechManager, EventManager, FactionManager, EmpireManager,
TutorialManager
```

`ScreenshotHarness` (D4) has been removed from `[autoload]`; it's now invoked manually only,
per its own header comment.

**Not autoloads — scene-local nodes** under `World/Systems` in `scenes/world/World.tscn`. This
distinction matters: anything outside the World scene that tries to reach one of these via
`get_tree().root.get_node_or_null(...)` gets null (see D55).

```
WorldManager, InputManager, DockingSystem, EnemySpawner, WorldEventManager, BoardingSystem
```

## No narrative, quest, or discovery system exists

As of 2026-08-14 there is no campaign, chapter, quest, or objective system of any kind. The only
narrative content in the project is the **8 hardcoded steps** in
`scripts/managers/TutorialManager.gd` (an `Array[Dictionary]` in the script body, not a
`Resource` — a standing `AGENTS.md` data-driven violation). `IslandData.discovered` is authored
on all 6 islands and **never written to by any code**, so there is no discovery or fog system
either. Both are M7/M8 scope; see `docs/06_NARRATIVE_AND_WORLD.md` and
`docs/14_SYSTEM_INVENTORY.md`.

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

## Pre-M7 audit (2026-08-14)

Found while writing `docs/06_NARRATIVE_AND_WORLD.md` and `docs/11`–`15`, by direct inspection of
the resource files and UI scripts that no previous pass had cross-checked against each other.
None of these were known before. Full context for each is in `docs/14_SYSTEM_INVENTORY.md` §7.

Also confirmed in this pass, and now fixed in this document: §4's autoload registry was stale
(listed the deleted `GameManager`, omitted the registered `TutorialManager`).

| # | Defect | Status |
|---|--------|--------|
| D53 | 🔴 **Ship prices are computed from hull `mass`, in a UI script.** `IslandMenu.gd:357-359` derives `cost_gold = int(ship.mass / 100)`, `cost_wood = mass / 200`, `cost_iron = mass / 400`. The resulting ladder is catastrophically cheap: **Man O'War = 300 gold / 150 wood / 75 iron** (600 HP, 50 damage) against a starting purse of 200 gold and a level-5 Farm at **1350 gold**. Every hull is also affordable within the starting storage caps, so nothing gates it. This defeats **M6 Requirement 8 in full** — the circular economy in which combat loot funds the empire and the empire funds a better ship — because the ship half of that circle is free. It additionally violates `AGENTS.md` ("hardcoded values are forbidden"; "balance belongs inside Resources") *and* couples balance to physics: any future change to a hull's `mass` for buoyancy reasons silently re-prices it. | **Open — M7 Wave 1, priority 1.** Add `cost_gold`/`cost_wood`/`cost_iron`/`cost_rum` to `ShipStats`, author per hull to the ladder in `docs/13_CAMPAIGN_LEVELS_1-5.md` §2, and delete the mass formula. |
| D54 | `ShipStats` has no `ship_id`, no `display_name`, and no `ship_class`. `IslandMenu._create_ship_entry()` therefore derives the shown name from the **filename** (`ship.resource_path.get_file().split(".")`), so the Shipyard reads "ManOWar" and no hull can be renamed, re-skinned, or localised. The missing class field is also why M6 Requirement 8.4 (enemy hulls trend larger as notoriety rises) has to approximate tier via `max_crew`. | **Open — M7 Wave 1.** |
| D55 | **`base_boarding_modifier` is authored on 0 of 20 captains.** `CaptainData.gd:21` exports it and `BoardingSystem.gd:80` reads `boarding_modifier` off the active captain, so the code path is live — but with no captain setting it, every captain returns the `1.0` default and **captain choice has no effect on boarding at all**. M6 Requirement 3.2 ("modified by captain traits") is half-dead. Exactly the D14 failure mode: schema exists, data was never authored, feature silently inert. Also a flavour/mechanics contradiction — `Cutlass.tres`'s entire authored personality is *"Prefers boarding actions to broadsides"* and he is mechanically no better at it than any other captain. | **Open — M7 Wave 1.** Suggested values in `docs/12_CHARACTER_BIBLE.md` §5. |
| D56 | `hire_cost_gold` is set on only **15 of 20** captains; the other five silently fall through to the `500` default, so they are mispriced relative to their stats. The field was added in M5 specifically so recruitment cost scales with roster depth. | **Open — M7 Wave 1.** |
| D57 | **Input rebinding is silently dead.** `SettingsMenu.gd:104` and `:118` resolve the rebinding target with `get_tree().root.get_node_or_null("InputManager")` — i.e. as an autoload. `InputManager` is **not** an autoload; it is a scene-local node at `World/Systems/InputManager`. Both lookups always return null, both are null-guarded, so pressing a key in the rebind flow swallows the input (`set_input_as_handled()`), clears `_awaiting_rebind`, and re-renders the *old* binding — no error, no crash, no rebinding. **M6 Requirement 9.2 / Task 27 does not work.** Same class as D15: a feature checkpoint-verified in isolation but dead in the real tree. | **Open — M7 Wave 1.** Fix by group lookup or by promoting `InputManager` to an autoload. |
| D58 | **Cold start is unplayable by construction.** `ResourceManager` starts the player on **200 gold**; `IslandMenu`'s colonize button costs **1000**; and `EmpireManager.home_island_id` is only ever assigned by `Island.gd:124` on a successful capture. A new player therefore owns no island, has no production, and must grind 800 gold from combat loot alone before the game's central verb (building) becomes available. | **Open — M7.** Resolution in `docs/13_CAMPAIGN_LEVELS_1-5.md` §3: a new game starts with Port Royal owned and set as home; the 1000-gold colonise cost applies to additional islands only. |
| D59 | **Map ring ordering is inverted.** In `scenes/world/World.tscn`, tier-2 `skull_cove` sits **54 u** from the home island while tier-1 `tortuga` sits **94 u**, so the first thing a new player sails toward is the tier-2 pirate stronghold. Distance stops signalling danger, which is the map's primary spatial read. | **Fixed 2026-08-14** — see the map-layout entry below. |
