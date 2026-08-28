# 14_SYSTEM_INVENTORY.md

> Version: 1.0
> Status: Living Document — complete component and process inventory
> Owner: Project Lead
>
> **What this document is for.** `docs/05_CURRENT_SYSTEMS.md` describes what is implemented and
> what is broken. This document is the *complete map of everything a game of this type needs* —
> logical, physical, presentational, data, platform, and process — with each item marked as
> present, partial, or missing, and assigned an owning milestone. It is the checklist that stops
> the project discovering a whole missing subsystem in month nine.
>
> Legend: ✅ built and working · 🟡 partial or unverified · ❌ not built · 🚫 deliberately out of
> scope for v1

---

# 0. Architecture snapshot (verified 2026-08-25, M7 campaign spine)

**Autoloads** (`project.godot` `[autoload]`, in load order) — 13 registered:

```
SaveManager, SceneManager, SettingsManager, InputManager, AudioManager, ResourceManager,
FleetManager, TechManager, EventManager, FactionManager, EmpireManager, CampaignManager,
TutorialManager
```

`GameManager` is **gone** — only an orphaned `scripts/managers/GameManager.gd.uid` remains.
`InputManager` (D57) and `CampaignManager` (M7) were newly promoted to/created as autoloads this
pass; both were previously scene-local or nonexistent.

**Scene-local systems** (children of `World/Systems` in `scenes/world/World.tscn`) — these are
*not* autoloads, which matters for anything outside the World scene trying to reach them:

```
WorldManager, DockingSystem, EnemySpawner, EncounterManager, BoardingSystem
```

`WorldEventManager` was **deleted in M8** — `EncounterManager` absorbed its boss timer.
`InputManager` moved out of this list into the autoload list above (D57, M7).

**Test baseline (measured 2026-08-26 after the M7.5 checkpoint correction, Godot 4.7.1):** **324
tests, 323 passing, 1 failing** — `test_property_21_lod_distance_transitions`, the known LOD gap,
unchanged since M6. **324/323 is the number to regress against.** (History: 103 → 118/117 (stale
count fixed) → 214/213 (M8 Phase 1) → 249/248 (M8 Phase 2) → 320/319 (M7 campaign spine + M1/M2
tail) → 323/322 (M7.5 — D64/D65, self-reported, did not reproduce) → 324/323 (M7.5 checkpoint
correction — D66/D67).)

---

# 1. Logical systems — the rules of the game

| System | Owner | Status | Notes |
|---|---|---|---|
| Resource economy (gold/wood/iron/rum/research) | `ResourceManager` | ✅ | 10 s global tick, per-resource caps, `can_afford`/`spend_resource` |
| Storage caps scaling with Warehouse level | `ResourceManager.recalculate_storage_capacity()` | ✅ | M6; D50 fixed the dropped `research` cap |
| Building production per tick | `Island._on_economy_tick()` | ✅ | scales with `BuildingData.level` |
| Building construction + 5-level upgrades | `Island.build_structure()` / `upgrade_structure()` | ✅ | 10 chains × 5 levels authored |
| Island tier derivation (1–5) | `Island.get_island_tier()` | ✅ | floor(avg building level), gated on `min_buildings_for_tier` |
| Construction gating by island tier | `BuildingData.required_island_tier` + `IslandMenu` | ✅ | M6 |
| Free building placement | — | 🚫 | fixed `Marker3D` slots by design |
| Timed build queues / energy | — | 🚫 | `AGENTS.md`: no artificial waiting |
| Fleet roster + active ship/captain | `FleetManager` | ✅ | D18 fixed the captain-index desync |
| Background trade/patrol missions | `FleetManager` | ✅ | tick gold + reputation on a timer |
| Captain XP / levelling | `CaptainData.add_xp()` | ✅ | computed modifiers from base + level |
| Captain stat differentiation | `resources/captains/*.tres` | 🟡 | **D55**: `base_boarding_modifier` unauthored on all 20 |
| Crew as a resource | `ShipDamage.crew` + Tavern recruit | ✅ | M6 |
| Tech tree / research | `TechManager` | 🟡 | works, but only **2** techs authored |
| Faction reputation (−100..100) | `FactionManager` | ✅ | 6 factions authored |
| Hostility + hunter dispatch | `FactionManager` | ✅ | the raid-mechanic extension point |
| Notoriety | `EmpireManager` | ✅ | +1/+5 per kill, +15 per capture, decays after 10 min idle |
| Region activation by notoriety | `EmpireManager` + `RegionData` | ✅ | 3 regions, thresholds 0/60/150 |
| Difficulty scaling by region + notoriety | `EnemySpawner.compute_spawn_multiplier()` | ✅ | `is_empire` factions only |
| Home-island raids | `EmpireManager._resolve_raid()` | ✅ | 15 min roll, defence vs attack score |
| Loot tables + class/notoriety scaling | `LootTableData`, `ShipController`, `BoardingSystem` | ✅ | M6 Task 22 |
| Island colonise / capture | `Island.capture_island()` | ✅ | **D58 fixed M7**: `World._seed_port_royal_as_home()` grants Port Royal on a genuinely new game, so the first colonise is no longer unreachable |
| Random world events | `EventManager` + `EventData` | 🟡 | **M10:** the 3 event types are now authored as `EventData` `.tres` resources (weight, `min_region_tier`), loaded via the same `DirAccess`-scan pattern `EmpireManager` uses, and picked by weighted-random roll gated on the player's current region tier — text itself is still generic, not chapter-aware |
| Boss encounters | `EncounterManager` + dedicated boss scenes | 🟡 | **M7:** two dedicated bosses (HMS Intransigent, Cárdenas' escort) with their own `ShipStats`/`EncounterData`, matched by `ship_id` on `DEFEAT_BOSS`. Not in `World.tscn`'s ambient pool — no in-world trigger exists yet, reachable only via a manual `EncounterManager.start_encounter()` call |
| Save / load | `SaveManager` | ✅ | `get_save_data()`/`load_save_data()` convention |
| Offline catch-up (capped 4 h) | `SaveManager` | ✅ | M5; deliberately does not re-emit the tick signal |
| Tutorial / onboarding | `TutorialManager` | ✅ | **M7:** reduced to a thin wrapper — UI-unlock/replay logic only; the 8 hardcoded steps are gone, replaced by `CampaignManager` |
| **Campaign / chapter director** | `CampaignManager` | ✅ **M7** | 5 authored chapters, gated by region activation / prior-chapter completion, cascading catch-up |
| **Objective tracking + progress** | `CampaignManager` | ✅ **M7** | 15-condition `ObjectiveData.Condition` enum, dispatched off real gameplay signals |
| **Island discovery / fog of war** | `CampaignManager._on_island_discovered()`, `WorldManager._check_island_discovery()` | ✅ **M10** | **M7:** on-dock write path. **M10:** extended to reveal-on-approach — `WorldManager` checks player distance to every undiscovered island each frame (configurable `discovery_radius`) and emits the previously-dead `island_discovered` signal, now connected to `CampaignManager`; `WorldMapScreen` (below) renders only discovered islands. `discovered` is now actually persisted through `SaveManager` — it never was before M10, silently resetting to false on every load |
| Diplomacy (treaties, tribute) | — | ❌ M11 | PRD §16 |
| Trade routes as placeable objects | — | ❌ M11 | today: abstract missions only |
| Multiplayer / PvP / guilds | — | 🚫 | permanently out for v1 |

---

# 2. Physical systems — simulation and space

| System | Owner | Status | Notes |
|---|---|---|---|
| Wave field (GPU) | `water.gdshader` | ✅ | |
| Wave field (CPU, for buoyancy) | `WaveGenerator` | ✅ | shares one `OceanSettings.tres` with the shader (D11) |
| Buoyancy + float points | `BuoyancySimulator` | ✅ | 4 float points per hull |
| Self-righting / stability torque | `BuoyancySimulator` | ✅ | D33: four stacked causes fixed; `1-cos(tilt)` backstop past 60° |
| Ballasted centre of mass | ship `.tscn` files | ✅ | D33 — explicit on all three ship scenes |
| Roll/pitch angular damping | `BuoyancySimulator` | ✅ | D34 — applied on roll/pitch only, never yaw |
| Yaw servo steering | `ShipMovement` | ✅ | D33: servos the yaw component only |
| Ship acceleration/drag/drift | `ShipMovement` + `ShipStats` | ✅ | |
| Sail damage → speed | `ShipDamage.get_speed_multiplier()` | ✅ | M6, floored at `min_speed_fraction` |
| Wind as a mechanic | — | ❌ M11 | Black Flag's sail-trim layer; not simulated; excluded from v1 combat per `docs/navalCombat.md` §3 |
| Weather (storms, squalls, visibility) | `EnvironmentController` | 🟡 | time-of-day + fog. **M10:** per-region wave-intensity variation added — `RegionData.wave_intensity_multiplier` (Beginner 1.0 / Contested 1.3 / Imperial 1.6) scales `OceanSettings.wave_height`/`wave_speed` when the player's nearest-island region changes; `fog_density_multiplier` is authored but not yet wired to a shader parameter (no density param exists on the current fog model — see `water.gdshader`). Still no storms |
| Projectile flight | `Cannonball` (`RigidBody3D`) | 🟡 | straight-line; **no arcing** — a documented gap |
| Damage pools (hull/sails/crew) | `ShipDamage` | ✅ | M6; **M8 added the write path** (`repair`/`restore_all`) — D60, it was entirely dead |
| Directional / stern-arc crits | `ShipDamage.apply_hit()` | ✅ | M6 |
| Ammunition types (round/chain/grape) | `AmmoData` + 3 `.tres` | ✅ | M6 |
| Boarding resolution | `BoardingSystem` | ✅ | D49 fixed the double-boarding exploit |
| Auto-fire on arc alignment + broadside indicator | `FiringSolver` + `ShipCombat` | ✅ | **M8.** Arc geometry lives once in `FiringSolver`, shared by the player and `EnemyAI`; `arc_lock_changed` drives the `WorldHUD` indicator. Manual `fire_port`/`fire_starboard` retained as a deprecated escape hatch |
| Player-timed full broadside (special) | `ShipCombat.fire_special_broadside()` | ✅ | **M8.** Both sides at once, damage premium, own cooldown, bypasses the per-side reload |
| Bow / stern / special weapon *slots* | `FiringSolver` (`SIDE_BOW`/`SIDE_STERN`) + `ShipStats` | ✅ | **M8 Phase 2.** Narrow, longer-range chaser cone gated on `has_bow_chaser`/`has_stern_chaser`; authored on Frigate/Galleon/Man O'War |
| Captain active abilities (in-battle) | `CaptainAbility` + `CaptainAbilityData` | ✅ | **M8.** 20 authored, one per captain, keyed to their six-word read in `docs/12_CHARACTER_BIBLE.md` §4. Follows the captain, not the ship |
| Temporary in-battle upgrade offers | `EncounterManager` + `BattleUpgradeData` + `UpgradeChoiceScreen` | ✅ | **M8.** 10 authored; cadence per `EncounterData`; applied via `CombatModifiers` and cleared on `encounter_ended` |
| Runtime combat modifier layer | `CombatModifiers` | ✅ | **M8.** Battle-long + timed layers; never mutates a shared `ShipStats` |
| Bounded encounter lifecycle (start/objective/end/rewards) | `EncounterManager` | ✅ | **M8.** Absorbed and deleted `WorldEventManager` |
| Ship modules + a ship Level distinct from captain Level | `OwnedShipData` + `ShipModuleData` | ✅ | **M8 Phase 2.** `FleetManager.owned_ships` wraps each hull's shared `ShipStats` template with per-instance level (max 5) + up to 5 modules (one per slot); `get_effective_stats()` applies both to a duplicate, never the template. 10 modules authored |
| AI-controlled support ships fighting in real-time | `EncounterData.ally_scene` + `EnemyAI` | ✅ | **M8 Phase 2.** Allies join a `friendly_ship` group (not `player_ship` — see D-note below) and keep their `EnemyAI`/auto-fire; `EnemyAI._find_player()` resolves to the nearest hostile `enemy_ship` hull for a friendly-grouped AI instead of the human player |
| Hull-facing armour variance | — | ❌ M11 | only the stern arc differentiates today |
| Collision layer registry | scene files | ✅ | **1** = ships, **2** = enemy ships, **5** = terrain (islands = 17), camera arm masks 16 (D31) |
| Docking + alignment | `DockingSystem` | ✅ | D19 clamped the slerp weight |
| Camera rig + spring arm | `CameraRig` | ✅ | D31 stopped it burying inside the hull; ORBIT/LOOK still deferred stubs |
| Enemy obstacle avoidance | `EnemyAI._get_avoidance_turn()` | ✅ | D39 — three-feeler whisker probe on terrain layer only |
| Enemy AI state machine | `EnemyAI` | ✅ | 5 states + `AIProfileData` (6 profiles) |
| Enemy role differentiation (Raider/Artillery/Tank/Support/Boss) | `AIProfileData.role` | ✅ | **M8 Phase 2.** A content tag, not a second numeric system — a role is authored aggression/distance/flee values, not a code-side multiplier. `SUPPORT` is the one role with its own behavior: repairs a wounded ally instead of attacking |
| Multi-ship fleet coordination in combat | — | 🚫 v1 | player commands one ship |
| Per-region enemy *type* composition | `EnemySpawner` + `RegionData.enemy_ship_pool` | ✅ **M10** | previously only a stat multiplier varied by region (`compute_spawn_multiplier`); now `EnemySpawner` picks a random `ShipStats` from the current region's pool (Beginner: Sloop/Dinghy, Contested: Schooner/Brigantine/Corvette, Imperial: Frigate/Galleon) before applying that same multiplier on top |
| Ocean LOD | `OceanController` (`get_lod_level()`) | ✅ **M10** | closed the project's one standing failing test. Two concentric `PlaneMesh` rings (near: 300×300 @ 60×60 subdiv, far: 1200×1200 @ 40×40 subdiv) sharing one `ShaderMaterial`, both re-centered under the camera each frame same as the old single mesh — cuts rendered vertex count from ~14.6k to ~5.4k. `WaveGenerator`'s CPU sampling (buoyancy) is untouched, LOD is render-only |
| Spatial partitioning / culling for a large map | — | ❌ M11+ | Ocean LOD (above) covers the ocean mesh specifically; general scene culling for islands/enemies at Expanded scale is not yet needed (still cheap at ~9 islands) but likely wanted eventually |

---

# 3. Presentation — what the player sees and hears

| System | Owner | Status | Notes |
|---|---|---|---|
| Toon shading with cel bands | `toon.gdshader` | ✅ | D26/D27/D28/D48 all fixed here |
| Per-model material application | `KenneyMaterialApplier` | ✅ | D23 tinting opt-in; D24 theme override forced |
| Terrain themes (tropical/volcanic/frozen) | `Island._apply_terrain_theme()` | ✅ | D24 |
| Sky / time of day / fog | `EnvironmentController` + `EnvironmentSettings.tres` | ✅ | D35: `EnvironmentSettings` is the single source of truth |
| Water surface + shoreline | `water.gdshader` | ✅ | D25 fixed the ocean being hidden by oversized beaches |
| Wake / spray VFX | `WakeParticles.tscn` | 🟡 | wake only; no impact spray, no muzzle smoke |
| Damage state on hulls | `ShipVisuals` | ✅ | **M8 Phase 2.** Below `hull_damaged_threshold` a smoke `GPUParticles3D` fades in; below `hull_critical_threshold` the toon-shader albedo blends toward a scorch tint, reverting exactly on repair |
| Building visual level-up | `Island._spawn_building_visual()`, `BuildingData.model_path` | 🟡 **M10** | all 50 of 50 building-level combinations now have a real vendored Kenney model (`assets/models/`) assigned via `model_path` — 45 were already assigned from an earlier undocumented pass, M10 found and assigned the remaining 5 (`Farm_L1-5`, actually the Rum Distillery chain → `crate-bottles.glb`). Still one shared model per whole chain, not 5 visually distinct per-level models — `Island.gd`'s scale-up-by-1.2× remains the only per-level visual differentiator. See `docs/10_ASSET_REQUESTS.md`'s M10 update |
| Captain/cast portraits | — | ❌ **M11** | 0 of 27 delivered (20 captains + 7 named cast); confirmed in actual play — Higgins' dialogue portrait renders as a generic fallback icon, not a stylised placeholder |
| Floating damage numbers | `FloatingDamage.tscn` | ✅ | |
| Enemy health bars | `EnemyHealthBar.tscn` | ✅ | |
| HUD (resources, notoriety, announcements) | `WorldHUD` | ✅ | **M9.** D36 re-fixed for real (container-layout, not a hardcoded offset — see §7.7); `announce_event()` now a themed, framed panel (D68); tutorial dialogue dims the combat HUD and gates ambient encounters (D69) |
| Mobile touch controls | `MobileControls.tscn` | 🟡 | exists; never verified on a device |
| Audio buses + SFX | `AudioManager` + `default_bus_layout.tres` | 🟡 | manager works; **no authored SFX set** |
| Music / shanties | — | ❌ M11 | `AGENTS.md`: "no silent interactions" is not yet met |
| Screen inventory | `scenes/ui/` | ✅ | Boot, MainMenu, Settings, Pause, Credits, Death, WorldHUD, IslandMenu, RaidReport, TutorialDialogue. **M9:** every screen now applies `PirateThemeBuilder` (Settings/Credits were the last two, D70); MainMenu has a real title/subtitle/button typographic hierarchy (D71); IslandMenu's main panel is responsive, not a fixed 600×400px box (D72) |
| **Captain's Log / objective panel** | `CaptainsLog.tscn` | ✅ **M7** | completed chapters + active chapter's objectives with live progress, optional objectives in a distinct section |
| **World map / navigation UI** | `WorldMapScreen.tscn`/`.gd` | ✅ **M10** | concentric region rings (radius from `RegionData.display_ring_radius`), discovered-island markers from `IslandData.world_position` (undiscovered islands omitted entirely — true fog of war, not a "?" placeholder), player position/heading marker reusing the same ship transform `WorldHUD`'s compass reads, "View Log" button opening the existing `CaptainsLog`. Opened via a `WorldHUD` HUD button built with the same dynamic-positioning pattern as `_create_captains_log_button()` |
| Codex / lore browser | `CodexScreen.tscn`/`.gd` | ✅ **M12** | completed chapters, encountered captains, and their factions, reusing `CampaignManager`/`FleetManager`/`CaptainData` gating wholesale — no new tracking mechanism |
| Localisation-ready strings | `translations/en.csv`, `[internationalization]` in `project.godot` | ✅ **M12** | UI-chrome strings in MainMenu/WorldHUD/IslandMenu/SettingsMenu/CaptainsLog/CodexScreen wrapped in `tr()`; `.tres` content-data strings (building/tech/captain names) explicitly out of scope, left for a future milestone |

---

# 4. Data layer — schemas and authored content

| `Resource` schema | Script | Authored count | Status |
|---|---|---|---|
| `ShipStats` | `scripts/world/ShipStats.gd` | 8 ships + 2 enemy | ✅ **D53/D54 closed M8 Phase 2**: `cost_gold/wood/iron/rum`, `ship_id`, `display_name`, `ship_class` all authored; bow/stern chaser fields authored on 3 hulls |
| `BuildingData` | `scripts/world/BuildingData.gd` | 10 chains × 5 = 50 | ✅ |
| `CaptainData` | `scripts/world/CaptainData.gd` | 20 | ✅ **D55/D56 both closed** (`base_boarding_modifier`, `active_ability`, `hire_cost_gold` authored on all 20); **M7**: identity fields (`home_island_id`, `allegiance_faction_id`, `unlock_chapter_id`, `portrait_path`) added and authored on all 20 per `docs/12_CHARACTER_BIBLE.md` §4 |
| `OwnedShipData` | `scripts/managers/OwnedShipData.gd` | — (per-instance) | ✅ **M8 Phase 2** — wraps a `ShipStats` template with level + installed modules |
| `ShipModuleData` | `scripts/world/ShipModuleData.gd` | 10 | ✅ **M8 Phase 2** — 2 per slot (Hull/Cannon/Sail/Utility/Special) |
| `FactionData` | `scripts/world/FactionData.gd` | 6 | ✅ |
| `IslandData` | `scripts/world/IslandData.gd` | 6 | 🟡 no `world_position`, no `region_id`; **M7**: `discovered` now written on dock via `CampaignManager._on_player_docked()` |
| `RegionData` | `scripts/world/RegionData.gd` | 3 | ✅ |
| `TechData` | `scripts/world/TechData.gd` | **2** | 🟡 thin — a tech *tree* needs ~15 |
| `LootTableData` | `scripts/combat/LootTableData.gd` | 3 | ✅ |
| `AmmoData` | `scripts/combat/AmmoData.gd` | 3 | ✅ |
| `AIProfileData` | `scripts/combat/AIProfileData.gd` | 6 | ✅ M8 Phase 2 — `role` tag covers Raider/Artillery/Tank/Support/Boss |
| `BoardingData` | `scripts/combat/BoardingData.gd` | 1 | ✅ |
| `OceanSettings` / `CameraSettings` / `EnvironmentSettings` | `scripts/world/` | 1 each | ✅ |
| **`ChapterData`** | `scripts/world/ChapterData.gd` | 5 | ✅ **M7** |
| **`ObjectiveData`** | `scripts/world/ObjectiveData.gd` | ~40 across the 5 chapters | ✅ **M7** — 15-value `Condition` enum |
| **`DialogueBeatData`** | `scripts/world/DialogueBeatData.gd` | ~15 across the 5 chapters | ✅ **M7** |
| **`EncounterData`** | `scripts/combat/EncounterData.gd` | 6 | ✅ M8 — Encounter/Convoy/Ambush/Elite/Boss/Defense (Defense added M8 Phase 2 with a real `PROTECT_TARGET` escort + optional fighting allies) |
| **`BattleUpgradeData`** | `scripts/combat/BattleUpgradeData.gd` | 10 | ✅ M8 |
| **`CaptainAbilityData`** | `scripts/combat/CaptainAbilityData.gd` | 20 | ✅ M8 — one per captain |
| `EventData` (world events as data) | — | 0 | ❌ M10 — `EventManager` hardcodes its events |
| `EnemyData` / spawn tables per region | — | 0 | ❌ M10 — only stat multipliers differ per region |

## Content volume targets for v1

| Content | Now | v1 target | Gap |
|---|---|---|---|
| Regions | 3 | 3 | — |
| Islands | 9 (M10 added 3) | 8–10 | — |
| Buildings (types × levels) | 10 × 5 | 10 × 5 | — |
| Ships | 8 | 8 | — |
| Captains | 20 | 20 | — |
| Techs | **13** (M11: 2→13) | 12–15 | — |
| Chapters | 5 | 5 | — |
| Bosses | **5** (M11: 3→5 — The Iron Vulture, Fortune's Toll added) | 3–5 | — |
| World events | **9** (M11: 3→9; 11 total `EventData` files including the 2 boss ambient events) | 8–10 | — |
| SFX cues | **25** (M11: 0→25, plus 2 music tracks) | 25–30 | — |
| Portraits | **20 of 27** (M11: 20 captains, flat-color icon-bust substitute; 7 named cast still use M9's monogram fallback) | 27 + fallback | +7 (non-blocking, intentional fallback) |

**M11 note:** the "Now" values above were stale going into M11 (this table hadn't been refreshed
since before M7/M10 landed — Chapters showed 0 despite M7 shipping all 5, Islands showed 6 despite
M10 adding 3 more). Refreshed in full during M11's documentation pass, not just the M11-owned rows,
since a content-volume table that's wrong on unrelated rows isn't trustworthy on the rows it does
own either.

**This table is v1's target only** (through M13's Android launch) — deliberately unchanged by
M14's scope. M14 (Live Operations, post-v1) targets Chapters 5→10, Regions 3→5, plus one new
content type v1 never had: seasonal repeatable events (Spring Crossing, 1 authored) and a
"What's New" patch-notes panel — tracked in `.kiro/specs/milestone-m14-live-operations/`, not
folded into this v1 table.

## Naming conventions (enforced)

`PascalCase` classes · `snake_case` vars/functions/signals · `UPPER_CASE` constants ·
building levels `<Name>_L<N>.tres` (resolved by convention in `Island.restore_buildings()`) ·
ids are `snake_case` and must match across `.tres` files and any doc that references them.

---

# 5. Meta / platform

| System | Status | Notes |
|---|---|---|
| Input actions + gamepad | ✅ | 13 actions (M8 added `special_broadside`, `captain_ability`), joypad events added in D10 |
| Input rebinding | 🟡 | **D57 — silently dead.** `SettingsMenu` looks up `InputManager` as an autoload; it is a scene-local node |
| Settings persistence | ✅ | `SettingsManager`; D41 made `InputMap` rewriting opt-in |
| Save file | ✅ | `user://` JSON; pure data, never nodes |
| Save backup / corruption recovery | ✅ **M12** | rotating `save_data.json.bak` written before every overwrite; `load_game()` falls back to it on primary-file failure before giving up |
| Save schema versioning | ✅ **M12** | `SaveManager._migrate()`, one `match` arm per transition on top of M10's `save_schema_version` stamp; `0→1` (island-array → discovery record) is the first real transition |
| Cloud saves | 🟡 M15 | **Code landed 2026-08-29 (`SaveManager` sync/conflict resolution, uncommitted-WIP-turned-commit `be46960`) but M15 has not yet written its own `docs/05_CURRENT_SYSTEMS.md` section — this row is stale relative to the actual codebase until that pass happens.** Supabase-backed, opt-in only |
| Account sign-in (email/password + Google) | 🟡 M15 | **Email/password landed 2026-08-29** (`AuthManager.gd`, `SettingsMenu` Account tab) — Google Sign-In not yet built. Same doc-lag caveat as the row above; optional/opt-in, never required to play |
| Password reset | ✅ M15 | `AuthManager.request_password_reset()` landed 2026-08-29; same doc-lag caveat |
| Account deletion | ✅ M15 | `AuthManager.delete_account()` + a Supabase Edge Function (`supabase/functions/delete-account/`) landed 2026-08-29; in-app path exists, web-accessible path is M13's privacy-policy contact email (below). Same doc-lag caveat |
| Privacy policy / Play Console Data Safety | 🟡 M13 | Page published to the `gh-pages` branch (content sourced from M15's real Requirement 9.2 enumeration, since M15 had already landed by the time this was written) — **GitHub Pages itself is not yet enabled in repo Settings, and the Play Console Data Safety form has not been filled out** (no Play Console access in this environment). See `docs/05_CURRENT_SYSTEMS.md`'s M13 section |
| Remote config / feature flags | ❌ M15 | flat public key/value table, no per-user targeting; consumed by M14's seasonal-event scheduling and content kill-switch, always with a safe local fallback |
| Analytics / telemetry | ✅ **M12** | `AnalyticsManager` — local JSON-lines funnel log (`user://telemetry/`), no Firebase/backend configured yet; the documented fallback, not a stopgap |
| Crash reporting | ✅ **M12** | `CrashReporter` — local, opt-in-disclosed report bundle; no configured support endpoint to send it to yet |
| Localisation | ✅ **M12** | see "Localisation-ready strings" above |
| Push notifications (offline-completion events) | 🟡 **M12** | `LocalNotificationManager` implemented and tested (no-op-safe adapter, lazy permission request, no forced re-prompt); re-scoped to raid-resolution only after verifying buildings/missions have no real completion timer to schedule against; **no Android plugin bundled and no device verification done** |
| Android export + signing | 🟡 M13 | SDK/JDK/templates/keystores all installed and configured 2026-08-29; **a successful export has not been produced** — blocked on a well-investigated, likely engine-side bug in this Godot build. See `docs/05_CURRENT_SYSTEMS.md`'s M13 section and `docs/RELEASE_CHECKLIST.md` step 4 |
| Touch/mobile performance profiling | ❌ M13 | never run on a device — blocked on the export issue above (no installable build exists yet) |
| Store assets (icon, screenshots, listing) | 🟡 M13 | listing copy written (`docs/STORE_LISTING.md`); icon is a placeholder and screenshots aren't captured, both deprioritized behind the export blocker |
| Monetisation hooks | 🚫 v1 | `AGENTS.md`: no microtransactions in v1 |

---

# 6. Process — how the work gets made

| Process | Status | Where it lives |
|---|---|---|
| Milestone specs (requirements/design/tasks) | ✅ | `.kiro/specs/milestone-mN-*/` — M1–M7 complete (M8 combat rework also complete, tracked outside the M1-M7 spec set); M7.5 stabilization pass complete (D64/D65). M9 (Presentation Pass) and M10 (Legible World) fully scaffolded 2026-08-26; M11–M13 scaffolded at requirements/design level; M14 (Live Operations) and M15 (Backend & Cloud Services) both fully scaffolded 2026-08-27 — M14 was outline-only until this pass brought it to full depth including its previously-missing `tasks.md`, and gained a soft dependency on M15's new Remote Config requirement; M13 gained a new privacy-policy/data-compliance requirement sourced from M15's data-collection enumeration |
| Single-agent workflow (Claude plans, implements, and verifies) | ✅ | `docs/07_AI_AGENT_WORKFLOW.md` — rewritten 2026-08-26; the prior two-agent (Claude/Gemini) split is retired, `docs/08_PROMPT_LIBRARY.md` and the `gemini-prompt` skill deleted, their reusable content folded into `docs/07` |
| Blocking checkpoint review | 🟡 | **the process exists and was skipped**: M6 Task 29 was ticked with *"Skipped local execution of GUT since binary is unavailable"* |
| Automated test suite | ✅ | GUT, 46 scripts, **324 tests** — `godot-verify` skill |
| Test-count regression guard | ✅ | baseline is **324 / 323** after the M7.5 checkpoint correction (was 323/322 self-reported, did not reproduce; 320/319 after M7 + M1/M2 tail) |
| Visual verification | ✅ | `scenes/debug/CaptureHarness.tscn` renders the real viewport at ~0/1/3/7/12 s — this is what actually caught D64/D65 (§7.5); a passing GUT suite alone had not |
| Manual/feel verification | 🟡 | requires a human; repeatedly and correctly flagged as un-automatable |
| Ground-truth doc upkeep | ✅ | `docs/05_CURRENT_SYSTEMS.md` + `sync-systems-doc` skill |
| Visual bug ledger | ✅ | `docs/09_VISUAL_BUG_TRACKER.md` |
| Asset request pipeline | ✅ | `docs/10_ASSET_REQUESTS.md` |
| Balance tuning pass | ✅ **M11/M12** | `docs/BALANCE_MODEL.md` — started M11 (ship ladder, techs, bosses, events), extended M12 (buildings, modules, captains, raid theft fraction, loot tables). Every resource/encounter category with a cost or reward field now traces to it — the artefact D53 was missing |
| Content authoring guide (for a non-coder) | ❌ M10 | needed before chapters/techs scale |
| Release checklist | ✅ M13 | `docs/RELEASE_CHECKLIST.md` — executed against this milestone's own release as its first real use; found real gaps (export blocker, deferred icon/screenshots) rather than passing cleanly |
| Playtest protocol | 🟡 **M12** | `docs/PLAYTEST_PROTOCOL.md` written; **no real round has been run yet** — nobody outside the project has played it. Requires a human to actually execute; not something an AI session can do alone |

## Two process failures worth naming

1. **A checkpoint was accepted on a self-report.** M6's final checkpoint was ticked without the
   test suite ever running. The suite runs fine — the binary is at
   `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.7.1-stable_win64.exe`,
   exactly where `Play Pirate Empire.cmd` says it is. `docs/07_AI_AGENT_WORKFLOW.md` Rules 4/7/8
   exist precisely to prevent this, and the ledger in CURRENT_SYSTEMS records two prior instances
   of tasks marked `[x]` with zero file changes.
2. **No balance model exists.** D53 (a Man O'War costing 300 gold) is not a coding mistake — it
   is what happens when prices are derived in a UI file instead of authored in data with a
   spreadsheet behind them. Every economy number in the game is currently unmodelled.

---

# 7. The 2026-08-14 pre-M7 audit — new defects

Found by direct code and resource inspection while writing docs 06 and 11–15. All are logged into
`docs/05_CURRENT_SYSTEMS.md` as **D53–D59**. None were known before this pass.

| ID | Severity | Defect | Fix milestone |
|---|---|---|---|
| D53 | 🔴 **critical** | Ship prices computed from physics `mass` in `IslandMenu.gd:357` — Man O'War costs **300 gold** vs a level-5 Farm at 1350. Breaks M6 Req 8's circular economy entirely, and couples balance to buoyancy tuning | **Fixed M8 Phase 2** |
| D54 | 🟡 | `ShipStats` has no `ship_id`, `display_name`, or `ship_class`. Shipyard names come from filenames; nothing can rank hulls, so M6 Req 8.4 approximates class via `max_crew` | **Fixed M8 Phase 2** |
| D55 | 🟡 | `base_boarding_modifier` set on **0 of 20** captains, so `BoardingSystem.gd:80` always reads 1.0 and captain choice cannot affect boarding — M6 Req 3.2 half-dead. D14 class | Fixed M8 Phase 1 |
| D56 | 🔵 | `hire_cost_gold` unset on 5 of 20 captains; they silently default to 500 | **Fixed M8 Phase 2** |
| D57 | 🟡 | `SettingsMenu.gd:104,118` resolve `InputManager` via `get_tree().root.get_node_or_null()` — i.e. as an autoload — but it is scene-local under `World/Systems`. Both return null and are null-guarded, so rebinding **silently does nothing**. M6 Req 9.2 is dead. D15 class | **Fixed M7** — `InputManager` promoted to an autoload |
| D58 | 🟡 | Cold start is unplayable-by-design: 200 starting gold vs a 1000-gold colonise cost, and `home_island_id` is only set on capture — so a new player owns no island and has no production | **Fixed M7** — `World._seed_port_royal_as_home()` on a genuinely new game |
| D59 | 🔵 | Map ring ordering inverted: tier-2 Skull Cove at 54 u from home, tier-1 Tortuga at 94 u | Fixed 2026-08-14 (map-layout pass, predates M7) |

Plus one documentation correction, not a defect: the GUT baseline is **118 tests / 117 passing**,
not the 103 recorded in the M6 spec and CURRENT_SYSTEMS §2.

---

# 7.5. The 2026-08-25 post-M7 stabilization pass — new defects

Found by actually running the game (`scenes/debug/CaptureHarness.tscn`, headful) and looking at
the rendered output, not by reading code or trusting a passing test suite — the GUT suite was
green the entire time both of these were live. Full detail and resolution in
`docs/05_CURRENT_SYSTEMS.md`'s "M7.5 Stabilization Pass" section.

| ID | Severity | Defect | Fix milestone |
|---|---|---|---|
| D64 | 🔴 **critical** | `SaveManager` couldn't distinguish "no player position was ever saved" from "saved, and it's empty" — a save written with no `player_ship` in the tree defaulted the ship to `Vector3(0,1,0)` on load, which is Port Royal's own island origin now that M7 made it the home island. Loading such a save embeds the ship in the island's collision and collapses the camera's spring arm into the terrain — the 3D viewport renders solid black while the HUD keeps working, with no error anywhere | **Fixed M7.5** |
| D65 | 🟡 | Chapters 4/5's dedicated bosses (HMS Intransigent, Cárdenas' flagship) had real `DEFEAT_BOSS` objectives but no in-world trigger — reachable only via a manual `EncounterManager.start_encounter()` call, so neither chapter was completable by a real player | **Fixed M7.5** — chapter-gated ambient pool entry via `EncounterData.required_chapter_id` |

## 7.6. The 2026-08-26 M7.5 checkpoint correction — new defects

Found by re-verifying the M7.5 checkpoint above against actual code and a real GUT run instead of
its recorded self-report. Full detail and resolution in `docs/05_CURRENT_SYSTEMS.md`'s "Checkpoint
correction" addendum.

| ID | Severity | Defect | Fix milestone |
|---|---|---|---|
| D66 | 🔴 **critical** | `CampaignManager._catch_up()` could advance past an in-progress, incomplete chapter whenever a later chapter's own gate (region-only, e.g. ch3/ch5) happened to already be satisfied — silently orphaning that chapter's objectives, reward, and (via D65's own gate) its ambient-pool boss | **Fixed M7.5 correction** |
| D67 | 🟡 | The M7.5 checkpoint's recorded "323/322" GUT result did not reproduce (actual: 323/321) — root cause was `ResourceManager.current_resources` leaking across test files, the same class as two prior `SaveManager`/`EmpireManager` test-isolation bugs from the M7 pass | **Fixed M7.5 correction** |

---

# 7.7. The 2026-08-26 presentation audit — D32/D36 reopened, all resolved in M9

Found by actually running the game (`scenes/debug/CaptureHarness.tscn`, headful, zero input) and
reading the rendered screenshots directly — the first time this project's verification crossed
from "an automated capture exists" to "a human looked at it." Full technical detail, including
D32's real traced root cause and D36's second (Log-button) overlap caught only by a fresh capture
after the first fix: `docs/05_CURRENT_SYSTEMS.md`'s "Presentation audit (2026-08-26)" section and
`docs/15_MASTER_PLAN.md` §8.

| ID | Severity | Defect | Fix milestone |
|---|---|---|---|
| D32 | 🟡 reopened | Previously "Resolved" (0 errors claimed); a fresh run reproduced all 4 `Parameter "material" is null` startup errors | **M9 — resolved, root cause traced** (a save-triggered `ShipVisuals._rebuild_model()` re-run racing the renderer's first-frame sync; confirmed harmless, documented rather than restructured) |
| D36 | 🔴 reopened | Previously "Resolved"; the notoriety/next-escalation label still visibly overlaps the resource bar on a fresh run | **M9 — resolved** (container-layout fix; a second overlap against the Log button, introduced by the first fix attempt, was caught by a follow-up capture and closed too) |
| D68 | 🟡 | `announce_event()` banner renders as unframed raw red text over the 3D world | **M9 — resolved** (themed, framed panel; red reserved for genuine warnings) |
| D69 | 🟡 | Tutorial dialogue, combat HUD, and ambient encounters render stacked with no arbitration | **M9 — resolved** (combat HUD dims while dialogue is open; ambient encounters gated) |
| D70 | 🟡 | `SettingsMenu`/`CreditsScreen` never apply `PirateThemeBuilder` — the only two unthemed screens | **M9 — resolved** |
| D71 | 🔵 | `MainMenu`'s own title has no font-size hierarchy; 2 of 5 buttons inconsistently styled; dead `VignetteOverlay` | **M9 — resolved** |
| D72 | 🔵 | `IslandMenu`'s main panel is a hardcoded 600×400 px size, not responsive, in a mobile-first project | **M9 — resolved** |

This pass also caused the roadmap insertion of **M9 — Presentation Pass** ahead of the
previously-planned M9 (now M10), and the renumbering of every milestone after it through M14 —
reflected throughout this document and `docs/15_MASTER_PLAN.md`. M9 also found and fixed a
pre-existing, unrelated GUT-suite crash (D73, a fourth instance of the D67 test-isolation defect
class) while establishing its own checkpoint baseline — see `docs/05_CURRENT_SYSTEMS.md`.

---

# 7.8. The 2026-08-27 monetization and coverage audit — nineteen unowned gaps

This document's own §8 says "when planning a milestone, take the ❌ rows for that milestone as the
candidate scope." That only works if the ❌ rows are complete. An audit on 2026-08-27 found they
were not: nineteen items had **no owning milestone at all**, several of them whole subsystems.
This section adds them, so the inventory stops reading as complete when it is not.

The audit was triggered by a product decision — the game is intended to be freemium — which
collided with `AGENTS.md`'s then-absolute "Never introduce paid features" and "Never introduce new
currencies". Those rules have since been scoped (see `docs/15_MASTER_PLAN.md` §3's post-v1
preamble and `docs/00_VISION.md` §19.1). The monetization gaps below could not previously be
listed here, because listing them would have described a constitutional violation.

## Monetization and commerce — none of this existed in any form

| System | Status | Owner |
|---|---|---|
| Cosmetic items (hull skins, sails, flags, figureheads, decorations) | ❌ | M16 |
| `CosmeticData` resource schema and catalogue | ❌ | M16 |
| Entitlement model — account-scoped, one-time, non-consumable ownership | ❌ | M16 |
| `EntitlementManager` autoload | ❌ | M16 |
| Wardrobe / equip / preview surface | ❌ | M16 |
| Cosmetic art pipeline (`docs/10_ASSET_REQUESTS.md` had no cosmetic category) | ❌ | M16 |
| Platform-agnostic billing interface (`IStoreBackend`) | ❌ | M17 |
| Google Play Billing integration | ❌ | M17 |
| Store surface with real fetched prices | ❌ | M17 |
| Restore purchases | ❌ | M17 |
| Refund detection and entitlement revocation | ❌ | M17 |
| Purchase-support / order-id surface | ❌ | M17 |
| Rewarded advertisement SDK and the three permitted surfaces | ❌ | M17 |
| Ad frequency caps ledger | ❌ | M17 |
| Age gate (COPPA / Play Families) | ❌ | M17 |
| UMP / GDPR advertising consent flow | ❌ | M17 |
| Apple ATT prompt | ❌ | M20 |
| Terms/Privacy revision for ads and purchase data (M15's predate both) | ❌ | M17 |
| Play Data Safety re-declaration | ❌ | M17 |
| Store price tiers per market | ❌ | M17 |
| Premium currency / wallet / spendable balance | 🚫 | **never** — `AGENTS.md`, `docs/17_MONETIZATION.md` §3 |
| Loot boxes, gacha, randomized paid rewards | 🚫 | **never** |
| Interstitial or forced advertising | 🚫 | **never** — `docs/00_VISION.md` §19 |
| Server-authoritative entitlement validation | 🚫 | deliberate — `docs/17_MONETIZATION.md` §4.4 |
| Anti-cheat | 🚫 | deliberate — same |

## Retention and re-engagement — the layer that makes freemium earn

| System | Status | Owner |
|---|---|---|
| Login streak / Captain's Log | ❌ | M18 |
| Weekly goals (authored as Resources) | ❌ | M18 |
| Comeback bonus for 7+ day absence | ❌ | M18 |
| Offline-return panel upgrade (also closes **V13**) | 🟡 | M18 |
| Notification scheduler with quiet hours and a one-per-day budget | ❌ | M18 |
| In-game feedback / bug-report channel | ❌ | M18 |
| FTUE funnel *response* (M12 collects the data; nothing acted on it) | ❌ | M18 |
| Decay / energy / punishment-on-absence mechanics | 🚫 | **never** — `docs/19_RETENTION_AND_LIVEOPS.md` |

## Accessibility — this had zero coverage anywhere in M9 through M15

The single largest omission the audit found. Not one accessibility item appeared in this document
or in any milestone spec. It excludes players, and it is a Google Play quality-listing factor.

| System | Status | Owner |
|---|---|---|
| Colourblind palettes (Deuteranopia / Protanopia / Tritanopia) | ❌ | M19 |
| Non-colour redundancy for every colour-coded state | ❌ | M19 |
| Contrast conformance (4.5:1 / 3:1) across themes and palettes | ❌ | M19 |
| Text scaling to 200% with real reflow | ❌ | M19 |
| Dyslexia-friendly font option | ❌ | M19 |
| Dialogue captions | ❌ | M19 |
| Captions for meaningful non-speech audio | ❌ | M19 |
| Reduced-motion mode (camera only — never the simulation) | ❌ | M19 |
| One-handed layout | ❌ | M19 |
| 48dp minimum touch targets | ❌ | M19 |
| Hold-versus-tap options | ❌ | M19 |
| Accessibility settings section | ❌ | M19 |
| Automated accessibility regression tests | ❌ | M19 |
| Screen-reader narration of the 3D world | 🚫 | `docs/18_ACCESSIBILITY.md` §1 |

## Platform — M13 is Android-only

| System | Status | Owner |
|---|---|---|
| iOS export pipeline | ❌ | M20 |
| StoreKit (as an implementation of M17's seam, never a second storefront) | ❌ | M20 |
| App Store listing and App Review compliance | ❌ | M20 |
| App Privacy nutrition labels | ❌ | M20 |
| Cross-platform entitlement honouring (needs M15) | ❌ | M20 |
| Repeatable screenshot pipeline (drive the existing `ScreenshotHarness`) | ❌ | M20 |
| Trailer | ❌ | M20 |
| Press kit | ❌ | M20 |
| Localized *listing* copy (distinct from M12's in-game strings) | ❌ | M20 |
| Engine-version decision (`docs/20_PLATFORM_MATRIX.md` §2 defers it to pre-M20) | 🟡 | M20 |
| macOS / tvOS / Steam / console | 🚫 | `docs/20_PLATFORM_MATRIX.md` §1 |

## Performance, integrity, and standing debt

| System | Status | Owner |
|---|---|---|
| Spatial partitioning and frustum/distance culling — **previously marked "M11+", which is not an owner** | ❌ | M21 |
| Save tamper *detection* (explicitly not anti-cheat) | ❌ | M21 |
| Entitlement-data integrity | ❌ | M21 |
| **V5** — material-null errors at startup, closed once and reopened 2026-08-26 | ❌ | M21 |
| **V8** — AI ships beach on islands, only partially addressed by D39 | 🟡 | M21 |
| `CurrentHealth`-on-upgrade rescale — an undecided design question, not a bug | ❌ | M21 |
| Region mixed-role enemy compositions beyond `EliteHunters` | 🟡 | M21 |

## Still unowned after this audit

| System | Status | Owner |
|---|---|---|
| **Multi-slot saves** — `SaveManager` writes one hardcoded `user://save_data.json` (`scripts/managers/SaveManager.gd:25`) with no slot concept anywhere | ❌ | **none** |

Found while auditing the Supporter Pack, an early draft of which promised "extra save slots". The
promise was removed rather than left unbuildable (`docs/17_MONETIZATION.md` §2.2). It is recorded
here and as gap #19 in `docs/15_MASTER_PLAN.md` §3.1 so that it stays visible rather than becoming
a surprise the next time someone assumes slots exist.

---

# 8. How to use this document

- **Before proposing a new system**, find it here. If it is ✅ or 🟡, extend it — `AGENTS.md`:
  *never duplicate systems*.
- **When a system changes**, update its row *and* its entry in `docs/05_CURRENT_SYSTEMS.md` in the
  same change.
- **When planning a milestone**, take the ❌ rows for that milestone as the candidate scope.
- **A 🚫 row is a decision, not a gap.** Reopening one requires amending `AGENTS.md`.
