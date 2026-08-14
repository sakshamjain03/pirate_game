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

# 0. Architecture snapshot (verified 2026-08-14)

**Autoloads** (`project.godot` `[autoload]`, in load order) — 11 registered, and not the same set
`docs/05_CURRENT_SYSTEMS.md` §4 used to name (that list was stale; it has now been corrected):

```
SaveManager, SceneManager, SettingsManager, AudioManager, ResourceManager,
FleetManager, TechManager, EventManager, FactionManager, EmpireManager, TutorialManager
```

`GameManager` is **gone** — only an orphaned `scripts/managers/GameManager.gd.uid` remains, while
§4 of CURRENT_SYSTEMS still lists it and omits `TutorialManager`.

**Scene-local systems** (children of `World/Systems` in `scenes/world/World.tscn`) — these are
*not* autoloads, which matters for anything outside the World scene trying to reach them:

```
WorldManager, InputManager, DockingSystem, EnemySpawner, WorldEventManager, BoardingSystem
```

**Test baseline (measured 2026-08-14, Godot 4.7.1):** **118 tests, 117 passing, 1 failing** —
`test_property_21_lod_distance_transitions`, the known LOD gap. The `103` baseline quoted
throughout the M6 spec and CURRENT_SYSTEMS is stale by 15 tests (Wave 3's three files were never
counted). **118/117 is the number to regress against.**

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
| Island colonise / capture | `Island.capture_island()` | 🟡 | works; **D58** makes the *first* one unreachable |
| Random world events | `EventManager` | 🟡 | 3 event types; text is generic, not chapter-aware |
| Boss encounters | `WorldEventManager` + `BossShip.tscn` | 🟡 | one ghost-ship boss; no boss id on the death signal |
| Save / load | `SaveManager` | ✅ | `get_save_data()`/`load_save_data()` convention |
| Offline catch-up (capped 4 h) | `SaveManager` | ✅ | M5; deliberately does not re-emit the tick signal |
| Tutorial / onboarding | `TutorialManager` | 🟡 | works, but 8 steps are **hardcoded** in the script |
| **Campaign / chapter director** | — | ❌ **M7** | `CampaignManager` + `ChapterData`/`ObjectiveData` |
| **Objective tracking + progress** | — | ❌ **M7** | |
| **Island discovery / fog of war** | — | ❌ **M9** | `IslandData.discovered` authored, **never written** |
| Diplomacy (treaties, tribute) | — | ❌ M10 | PRD §16 |
| Trade routes as placeable objects | — | ❌ M10 | today: abstract missions only |
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
| Wind as a mechanic | — | ❌ M10 | Black Flag's sail-trim layer; not simulated; excluded from v1 combat per `docs/navalCombat.md` §3 |
| Weather (storms, squalls, visibility) | `EnvironmentController` | 🟡 | time-of-day + fog only; no storms, no per-region weather |
| Projectile flight | `Cannonball` (`RigidBody3D`) | 🟡 | straight-line; **no arcing** — a documented gap |
| Damage pools (hull/sails/crew) | `ShipDamage` | ✅ | M6 |
| Directional / stern-arc crits | `ShipDamage.apply_hit()` | ✅ | M6 |
| Ammunition types (round/chain/grape) | `AmmoData` + 3 `.tres` | ✅ | M6 |
| Boarding resolution | `BoardingSystem` | ✅ | D49 fixed the double-boarding exploit |
| Auto-fire on arc alignment + broadside indicator | — | ❌ **M8** | firing is currently manual-only (`fire_port`/`fire_starboard` key press → `ShipCombat.fire_broadside()`), with no arc check; `docs/navalCombat.md` §4 locks the target design |
| Bow / stern / special weapon slots | — | ❌ M8 | only port/starboard broadside markers exist today |
| Captain active abilities (in-battle) | — | ❌ M8 | `CaptainData` has passives only; `docs/navalCombat.md` §10 |
| Temporary in-battle upgrade offers | — | ❌ M8 | net-new roguelite layer; `docs/navalCombat.md` §11 |
| Ship modules + a ship Level distinct from captain Level | — | ❌ M8 | ships are fixed once bought today; `docs/navalCombat.md` §13 |
| AI-controlled support ships fighting in real-time | — | ❌ M8 | `FleetManager` support ships only run background trade/patrol missions |
| Hull-facing armour variance | — | ❌ M10 | only the stern arc differentiates today |
| Collision layer registry | scene files | ✅ | **1** = ships, **2** = enemy ships, **5** = terrain (islands = 17), camera arm masks 16 (D31) |
| Docking + alignment | `DockingSystem` | ✅ | D19 clamped the slerp weight |
| Camera rig + spring arm | `CameraRig` | ✅ | D31 stopped it burying inside the hull; ORBIT/LOOK still deferred stubs |
| Enemy obstacle avoidance | `EnemyAI._get_avoidance_turn()` | ✅ | D39 — three-feeler whisker probe on terrain layer only |
| Enemy AI state machine | `EnemyAI` | ✅ | 5 states + `AIProfileData` (3 profiles) |
| Multi-ship fleet coordination in combat | — | 🚫 v1 | player commands one ship |
| Ocean LOD | — | ❌ **M9** | the project's one known failing test; **gates map scale** |
| Spatial partitioning / culling for a large map | — | ❌ M9 | needed with LOD |

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
| Damage state on hulls | — | ❌ M9 | Black Flag's "ship shows what it survived"; pools exist, visuals don't |
| Building visual level-up | `Island._spawn_building_visual()` | 🟡 | **scale** only, not distinct models per level |
| Floating damage numbers | `FloatingDamage.tscn` | ✅ | |
| Enemy health bars | `EnemyHealthBar.tscn` | ✅ | |
| HUD (resources, notoriety, announcements) | `WorldHUD` | ✅ | D36 fixed both layout defects |
| Mobile touch controls | `MobileControls.tscn` | 🟡 | exists; never verified on a device |
| Audio buses + SFX | `AudioManager` + `default_bus_layout.tres` | 🟡 | manager works; **no authored SFX set** |
| Music / shanties | — | ❌ M10 | `AGENTS.md`: "no silent interactions" is not yet met |
| Screen inventory | `scenes/ui/` | ✅ | Boot, MainMenu, Settings, Pause, Credits, Death, WorldHUD, IslandMenu, RaidReport, TutorialDialogue |
| **Captain's Log / objective panel** | — | ❌ **M7** | |
| **World map / navigation UI** | — | ❌ **M9** | player cannot see the map |
| Codex / lore browser | — | ❌ M11 | |
| Localisation-ready strings | — | ❌ M11 | all strings are inline literals today |

---

# 4. Data layer — schemas and authored content

| `Resource` schema | Script | Authored count | Status |
|---|---|---|---|
| `ShipStats` | `scripts/world/ShipStats.gd` | 8 ships + 2 enemy | 🟡 **D53/D54**: no cost, no `ship_id`, no `display_name`, no `ship_class` |
| `BuildingData` | `scripts/world/BuildingData.gd` | 10 chains × 5 = 50 | ✅ |
| `CaptainData` | `scripts/world/CaptainData.gd` | 20 | 🟡 **D55/D56**; no identity fields (home port, allegiance, unlock chapter, portrait) |
| `FactionData` | `scripts/world/FactionData.gd` | 6 | ✅ |
| `IslandData` | `scripts/world/IslandData.gd` | 6 | 🟡 no `world_position`, no `region_id`; `discovered` never written |
| `RegionData` | `scripts/world/RegionData.gd` | 3 | ✅ |
| `TechData` | `scripts/world/TechData.gd` | **2** | 🟡 thin — a tech *tree* needs ~15 |
| `LootTableData` | `scripts/combat/LootTableData.gd` | 3 | ✅ |
| `AmmoData` | `scripts/combat/AmmoData.gd` | 3 | ✅ |
| `AIProfileData` | `scripts/combat/AIProfileData.gd` | 3 | ✅ |
| `BoardingData` | `scripts/combat/BoardingData.gd` | 1 | ✅ |
| `OceanSettings` / `CameraSettings` / `EnvironmentSettings` | `scripts/world/` | 1 each | ✅ |
| **`ChapterData`** | — | 0 | ❌ **M7** |
| **`ObjectiveData`** | — | 0 | ❌ **M7** |
| **`DialogueBeatData`** | — | 0 | ❌ **M7** |
| `EventData` (world events as data) | — | 0 | ❌ M9 — `EventManager` hardcodes its events |
| `EnemyData` / spawn tables per region | — | 0 | ❌ M9 — only stat multipliers differ per region |

## Content volume targets for v1

| Content | Now | v1 target | Gap |
|---|---|---|---|
| Regions | 3 | 3 | — |
| Islands | 6 | 8–10 | +2–4 |
| Buildings (types × levels) | 10 × 5 | 10 × 5 | — |
| Ships | 8 | 8 | — |
| Captains | 20 | 20 | — |
| Techs | **2** | 12–15 | **+10–13** |
| Chapters | 0 | 5 | **+5** |
| Bosses | 1 | 3 | +2 |
| World events | 3 | 8–10 | +5–7 |
| SFX cues | ~0 | 25–30 | **all** |
| Portraits | 0 | 27 + fallback | all (non-blocking) |

## Naming conventions (enforced)

`PascalCase` classes · `snake_case` vars/functions/signals · `UPPER_CASE` constants ·
building levels `<Name>_L<N>.tres` (resolved by convention in `Island.restore_buildings()`) ·
ids are `snake_case` and must match across `.tres` files and any doc that references them.

---

# 5. Meta / platform

| System | Status | Notes |
|---|---|---|
| Input actions + gamepad | ✅ | 11 actions, joypad events added in D10 |
| Input rebinding | 🟡 | **D57 — silently dead.** `SettingsMenu` looks up `InputManager` as an autoload; it is a scene-local node |
| Settings persistence | ✅ | `SettingsManager`; D41 made `InputMap` rewriting opt-in |
| Save file | ✅ | `user://` JSON; pure data, never nodes |
| Save backup / corruption recovery | ❌ M11 | one file, no backup, no schema version |
| Save schema versioning | ❌ M11 | a migration path will be needed before launch |
| Cloud saves | 🚫 v1 | |
| Analytics / telemetry | ❌ M11 | no funnel data ⇒ no way to tune retention |
| Crash reporting | ❌ M11 | |
| Localisation | ❌ M11 | |
| Android export + signing | ❌ M12 | **export templates are not installed on the dev machine** |
| Touch/mobile performance profiling | ❌ M12 | never run on a device |
| Store assets (icon, screenshots, listing) | 🟡 | project icon exists (D38); nothing else |
| Monetisation hooks | 🚫 v1 | `AGENTS.md`: no microtransactions in v1 |

---

# 6. Process — how the work gets made

| Process | Status | Where it lives |
|---|---|---|
| Milestone specs (requirements/design/tasks) | ✅ | `.kiro/specs/milestone-mN-*/` — M1–M6 complete |
| Two-agent workflow (Claude plans, Gemini implements) | ✅ | `docs/07_AI_AGENT_WORKFLOW.md` |
| Gemini prompt template | ✅ | `docs/08_PROMPT_LIBRARY.md` + `gemini-prompt` skill |
| Blocking checkpoint review | 🟡 | **the process exists and was skipped**: M6 Task 29 was ticked with *"Skipped local execution of GUT since binary is unavailable"* |
| Automated test suite | ✅ | GUT, 25 scripts, 118 tests — `godot-verify` skill |
| Test-count regression guard | ✅ | baseline must be corrected 103 → **118** |
| Visual verification | ✅ | `scenes/debug/CaptureHarness.tscn` renders the real viewport at ~0/1/3/7/12 s |
| Manual/feel verification | 🟡 | requires a human; repeatedly and correctly flagged as un-automatable |
| Ground-truth doc upkeep | ✅ | `docs/05_CURRENT_SYSTEMS.md` + `sync-systems-doc` skill |
| Visual bug ledger | ✅ | `docs/09_VISUAL_BUG_TRACKER.md` |
| Asset request pipeline | ✅ | `docs/10_ASSET_REQUESTS.md` |
| Balance tuning pass | ❌ | **no spreadsheet, no model.** D53 is the direct consequence |
| Content authoring guide (for a non-coder) | ❌ M9 | needed before chapters/techs scale |
| Release checklist | ❌ M12 | |
| Playtest protocol | ❌ M11 | nobody outside the project has played it |

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
| D53 | 🔴 **critical** | Ship prices computed from physics `mass` in `IslandMenu.gd:357` — Man O'War costs **300 gold** vs a level-5 Farm at 1350. Breaks M6 Req 8's circular economy entirely, and couples balance to buoyancy tuning | M7 |
| D54 | 🟡 | `ShipStats` has no `ship_id`, `display_name`, or `ship_class`. Shipyard names come from filenames; nothing can rank hulls, so M6 Req 8.4 approximates class via `max_crew` | M7 |
| D55 | 🟡 | `base_boarding_modifier` set on **0 of 20** captains, so `BoardingSystem.gd:80` always reads 1.0 and captain choice cannot affect boarding — M6 Req 3.2 half-dead. D14 class | M7 |
| D56 | 🔵 | `hire_cost_gold` unset on 5 of 20 captains; they silently default to 500 | M7 |
| D57 | 🟡 | `SettingsMenu.gd:104,118` resolve `InputManager` via `get_tree().root.get_node_or_null()` — i.e. as an autoload — but it is scene-local under `World/Systems`. Both return null and are null-guarded, so rebinding **silently does nothing**. M6 Req 9.2 is dead. D15 class | M7 |
| D58 | 🟡 | Cold start is unplayable-by-design: 200 starting gold vs a 1000-gold colonise cost, and `home_island_id` is only set on capture — so a new player owns no island and has no production | M7 |
| D59 | 🔵 | Map ring ordering inverted: tier-2 Skull Cove at 54 u from home, tier-1 Tortuga at 94 u | M7 |

Plus one documentation correction, not a defect: the GUT baseline is **118 tests / 117 passing**,
not the 103 recorded in the M6 spec and CURRENT_SYSTEMS §2.

---

# 8. How to use this document

- **Before proposing a new system**, find it here. If it is ✅ or 🟡, extend it — `AGENTS.md`:
  *never duplicate systems*.
- **When a system changes**, update its row *and* its entry in `docs/05_CURRENT_SYSTEMS.md` in the
  same change.
- **When planning a milestone**, take the ❌ rows for that milestone as the candidate scope.
- **A 🚫 row is a decision, not a gap.** Reopening one requires amending `AGENTS.md`.
