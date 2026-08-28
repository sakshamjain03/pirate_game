# Design Document — M10 The Legible World

## Sequencing

Per `docs/15_MASTER_PLAN.md` §4's critical path, Ocean LOD (Requirement 1) gates the Expanded map
(Requirement 2) — do it first, verify it holds at the *current* Compact scale, then move
coordinates. Requirements 3/4 (map UI, discovery) depend on Requirement 2's real `world_position`/
`region_id` fields existing on `IslandData`. Requirements 5–9 (weather/enemy types, damage visuals,
new islands, building art, save version) are independent of the LOD/map work and of each other —
implement in any order, or in parallel if multiple tracks are available, same as M8/M10's
historical disjoint-system parallelism note.

---

## Requirement 1 — Ocean LOD

`WaveGenerator` (CPU, feeds `BuoyancySimulator`) and `water.gdshader` (GPU) currently share one
`OceanSettings.tres` and compute the full wave field everywhere uniformly (per D11's finding in
`docs/05_CURRENT_SYSTEM.md` — they already agree with each other, the gap is *scale*, not sync).

**Rendering side (the actual LOD):** reduce the water mesh's subdivision density with distance from
camera — Godot doesn't have a built-in ocean LOD primitive, so this is either (a) a
multi-ring mesh (concentric annuli of decreasing vertex density around the camera, re-centered each
frame or each N frames) or (b) a single mesh with distance-based tessellation done in the vertex
shader if the target Godot/hardware supports it cheaply. Given this project's low-poly art
direction already tolerates visible faceting (`docs/03_ART_DIRECTION.md`), a ring-based mesh swap
is the lower-risk choice — it's a content/mesh-generation change, not a shader-capability gamble.

**Physics side (must NOT regress):** `BuoyancySimulator`'s CPU wave sampling (`WaveGenerator`'s
Gerstner function evaluated at each ship's float points) must keep evaluating the *full-resolution*
analytic wave function regardless of render LOD — LOD only reduces vertex density of what's drawn,
never the underlying wave math ships float on. This is naturally satisfied if `WaveGenerator`'s CPU
sampling path stays untouched and only the GPU mesh/shader gains distance-based density reduction —
confirm this with the existing buoyancy property tests before considering Requirement 1 done.

**Closing the test:** `test_property_21_lod_distance_transitions` presumably already encodes the
expected behavior (distance bands, transition smoothness) — read it first; it may already specify
the exact API this task needs to implement against, rather than requiring new test design.

---

## Requirement 2 — Expanded map layout

Straightforward data change once `IslandData.world_position`/`region_id` exist (new fields, per
Requirement 2 AC3) — six coordinate updates per `docs/11_WORLD_MAP.md` §4b, applied to both the
`IslandData` resources and `World.tscn`'s node transforms (today the two may only agree by
convention; use this migration to make `IslandData.world_position` authoritative and have
`World.tscn`'s node transform *read from* it at scene setup, closing the "layout only lives in the
scene file" gap `docs/14_SYSTEM_INVENTORY.md` flags, rather than maintaining both by hand going
forward).

`EnemySpawner`'s hardcoded ±100 fallback box: find the literal, replace with an `@export var
spawn_bounds_half_extent: float = 100.0` (or similar), then set it to the Expanded-appropriate value
in `World.tscn`'s `EnemySpawner` node instance, not in the script default — per `AGENTS.md`'s data-
over-code balance rule.

---

## Requirement 3 — World map UI

New `scenes/ui/WorldMapScreen.tscn` + `WorldMapScreen.gd`, following the established UI pattern:
`PirateThemeBuilder.build()` applied in `_ready()`, opened via a `WorldHUD`-owned button built the
same dynamic-positioning way `_create_captains_log_button()` already works (reuse that function's
pattern, don't invent a second one). Content: three concentric ring `Control`s (or a simple 2D
`Node2D`/`Control`-drawn representation using `_draw()`) scaled to each region's radius band from
`docs/11_WORLD_MAP.md` §4b, with island markers placed proportionally from each `IslandData.
world_position`. Player position/heading: a small marker driven by the same ship-position data
`WorldHUD`'s compass (`CompassPanel`/`CompassNeedle`) already reads — reuse that data source rather
than re-deriving heading independently.

Active-chapter objectives: rather than duplicating `CaptainsLog`'s objective list inside the map
screen, the simplest reuse is a "View Log" button on the map screen that opens `CaptainsLog`
(already exists, already themed, already wired to `CampaignManager`) — satisfies Requirement 3 AC4
without building a second objectives UI.

---

## Requirement 4 — Discovery / fog of war

Extend the existing on-dock write path (`CampaignManager._on_player_docked()`, M7) with a second,
continuous check: a `WorldManager` (or `Island.gd`-owned) proximity check against each
undiscovered island's `world_position`, using a `discovery_radius` similar in spirit to
`DockingSystem`'s existing dock-range check — reuse that check's pattern (likely an `Area3D` or
distance comparison already present for docking) rather than a new spatial-query mechanism.
`island_discovered` signal (new, or reuse `CampaignManager`'s existing dispatch-by-signal
convention) feeds both the map screen (Requirement 3) and `CampaignManager`'s `DISCOVER_ISLAND`
objective condition (already defined in the `Condition` enum per the M7 section of
`docs/05_CURRENT_SYSTEMS.md`, currently dispatched by nothing — this closes that gap).

---

## Requirement 5 — Per-region weather and enemy types

**Weather:** `EnvironmentController` already drives time-of-day sky/fog/lighting from
`EnvironmentSettings.tres` (per D35's fix). Add a per-region weather modifier — simplest approach:
`RegionData` (already exists, already has `resources/world/regions/*.tres`) gains weather-relevant
fields (e.g. `fog_density_multiplier`, `wave_intensity_multiplier`) that `EnvironmentController`
reads when the player's current region changes, rather than inventing a parallel weather-region
concept — `RegionData` is already the region-scoped data owner (`EmpireManager` already loads and
tracks it).

**`EventData`:** new `scripts/world/EventData.gd` resource (`event_id`, `display_text`,
`weight`, `min_region_tier`, whatever `EventManager`'s current hardcoded event list already
varies by) — author one `.tres` per existing hardcoded event, then `EventManager` loads/rolls from
`resources/world/events/*.tres` the same `DirAccess`-scan-and-roll pattern `EmpireManager`/
`CampaignManager` already use for regions/chapters (reuse, don't reinvent).

**Enemy types by region:** `EnemySpawner` already has `compute_spawn_multiplier(region_tier)`
(stat-only). Add a per-region roster: either a `RegionData.enemy_pool: Array[PackedScene]`/
`Array[String]` field the spawner selects from instead of always spawning the same base enemy
scene, or an `AIProfileData`-keyed pool per region tier — follow whichever of `RegionData` or
`AIProfileData` already owns "what varies per region/tier" most naturally; `RegionData` is the
more direct fit since region is already the axis this varies on.

---

## Requirement 6 — Ship damage visuals follow-up

`ShipVisuals` already listens to `ShipDamage.pool_changed` for the M8 damaged/critical
smoke-and-scorch states (`hull_damaged_threshold`, `hull_critical_threshold`). Add one more
threshold band below `hull_critical_threshold` (e.g. `hull_sinking_threshold`) with its own visual
treatment (heavier smoke, listing/tilt via a small visual-only rotation offset — not touching
`BuoyancySimulator`'s actual physics) — same signal, same pattern, one more tier. Cache clean-state
values the same way the M8 work already established (per-surface albedo cached once at `_ready()`
so repeated damage/repair cycles blend from the true original).

---

## Requirement 7 — 2–4 new islands

Pure content — author new `IslandData` `.tres` files following the exact schema the existing 6
already use (`docs/11_WORLD_MAP.md`'s per-island dossier format: name, type, region, a rumor/flavor
hook). Place them using Requirement 2's Expanded coordinate space, filling out each region's ring
band rather than clustering. No new script/system needed — `Island.gd` already handles arbitrary
island instances generically.

---

## Requirement 8 — Building-model art sourcing

This is a research task before it's an integration task. The exact same source that closed D40
(the ship-model texture gap) — Kenney's asset packs, several of which are building/structure-themed
("Mini Kits", "Nature Kit," "Space Kit," "Medieval," "Castle" — survey what's available and whether
scale/faction fits a pirate-empire building's silhouette) — should be checked first. If the project
already has any Kenney packs vendored beyond what's currently used (check `assets/models/` for
unused packs, similar to how D40 found the fleet's existing untapped models), that's the fastest
path. If integrating, follow the existing `BuildingData.model_path` mechanism exactly — no schema
change needed, since `docs/10_ASSET_REQUESTS.md`'s M6 delivery plan already specified this
integration point; it was simply never fed real assets.

---

## Requirement 9 — Minimal save-schema version stamp

```gdscript
# SaveManager.gd
const SAVE_SCHEMA_VERSION := 1

func save_game() -> void:
    var save_dict := { "save_schema_version": SAVE_SCHEMA_VERSION, "economy": {}, ... }
    ...

func load_game() -> void:
    var version : int = data.get("save_schema_version", 0)
    # No migration logic yet — M12 scope. Just read and (optionally) log if version is unexpected.
    ...
```

Deliberately inert beyond the field itself — this is insurance for M12, not a migration system.

---

## Verification

Standard command:
```
<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
Baseline entering this milestone: whatever M9's checkpoint closes at (324+ tests, all passing
except none — M9 is expected to close the D32/D36 regressions without changing the LOD test's
status, since that failure is unrelated to M9's scope).

Requirement 1 (Ocean LOD) is expected to close `test_property_21_lod_distance_transitions` — the
new baseline after this milestone should show 0 known failures for the first time in the project's
history. If that's not true at checkpoint time, treat it as a blocking finding, not a footnote.

Per this project's now-twice-demonstrated lesson (`docs/09_VISUAL_BUG_TRACKER.md`'s "Wrong turns"
§7): a passing GUT suite is necessary but not sufficient for the map/discovery/weather work in this
milestone, all of which is fundamentally visual/experiential. A fresh headful `CaptureHarness` run
(or equivalent manual verification) reviewed by a human is required at this milestone's checkpoint,
same discipline `.kiro/specs/milestone-m9-presentation-pass/` established.
