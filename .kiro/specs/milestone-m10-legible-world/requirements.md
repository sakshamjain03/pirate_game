# Requirements Document

## Introduction

Milestone M10 (originally scoped as "M9 — The Legible World" in `docs/15_MASTER_PLAN.md` before
the 2026-08-26 presentation audit inserted a new M9 ahead of it) makes the world worth exploring —
today the Compact map is crossable in roughly 25 seconds at cruise speed, `IslandData.discovered`
is never actually written, and the game's one permanently-failing test
(`test_property_21_lod_distance_transitions`) blocks the larger Expanded map from ever shipping.
`docs/00_VISION.md`'s "Explore" pillar (hidden islands, discovery, mysteries) and
`docs/06_NARRATIVE_AND_WORLD.md`'s Chapter 5 closing hook (an unmapped chart pointing at Region 4)
both depend on a world that's actually big enough and legible enough to make "what's past the fog"
a real question. This milestone also picks up two items surfaced by the presentation audit that
don't fit anywhere else: sourcing real building-progression art (currently 0 of 54 models,
`docs/10_ASSET_REQUESTS.md`) and a minimal save-schema version stamp ahead of M12's full
versioning/backup pass.

Full context: `docs/15_MASTER_PLAN.md`'s M10 entry and §8, `docs/14_SYSTEM_INVENTORY.md` §2/§3,
`docs/11_WORLD_MAP.md` (Compact/Expanded layouts, per-region specs).

---

## Requirements

### Requirement 1 — Ocean LOD

**User Story:** As a player on a mid-range Android device, I want the ocean to render at a stable
frame rate regardless of how large the world is, so exploring a bigger map doesn't tank
performance.

#### Acceptance Criteria

1. `OceanController`/`WaveGenerator` SHALL implement a level-of-detail scheme that reduces wave
   mesh density/update frequency with distance from the camera, closing
   `test_property_21_lod_distance_transitions` (the project's one standing, previously-accepted
   test failure).
2. The LOD transition SHALL NOT be visually abrupt at typical sailing speed — verified by a
   headful `CaptureHarness`-style capture crossing an LOD boundary, reviewed by a human per this
   project's established presentation-audit discipline (see `.kiro/specs/milestone-m9-presentation-pass/`).
3. Buoyancy (`BuoyancySimulator`'s CPU wave sampling) SHALL remain correct at any distance from the
   camera — LOD SHALL only affect rendering, not the physics wave field ships float on.
4. This SHALL be the first task in this milestone — it gates Requirement 2 (the Expanded map is
   not viable without it, per `docs/15_MASTER_PLAN.md` §4's critical path).

### Requirement 2 — Expanded map layout

**User Story:** As a player, I want the world to feel like a real voyage, not a pond, so sailing
between regions carries the weight the game's Black Flag inspiration is going for.

#### Acceptance Criteria

1. All six islands' `world_position` SHALL move to the Expanded coordinates in
   `docs/11_WORLD_MAP.md` §4b (all Compact coordinates × 2.5): Port Royal (0,0), Tortuga
   (-175, 137.5), Skull Cove (100, -375), Frostbite Reef (375, 150), Mount Brimstone (-450, -375),
   Cartagena Outpost (-500, 400).
2. The player spawn point and the three authored ambient-enemy spawn regions SHALL move with their
   respective islands, preserving each region's relative danger/distance relationship.
3. `IslandData` SHALL gain `world_position: Vector2`/`Vector3` and `region_id: String` fields (
   currently absent per `docs/14_SYSTEM_INVENTORY.md` §4), authored per island, replacing any
   position data that currently lives only in `World.tscn` scene transforms.
4. `EnemySpawner`'s hardcoded ±100 fallback spawn box SHALL become an `@export`ed value scaled to
   the new map size, per `AGENTS.md`'s "no hardcoded balance."
5. A deepest one-way voyage (e.g. Port Royal to Cartagena Outpost) SHALL take approximately 55
   seconds at cruise speed (12 u/s), per `docs/11_WORLD_MAP.md` §4b's Expanded-layout target.
6. The Compact-layout ring-ordering correctness (tier-1 islands closer than tier-2, tier-2 closer
   than tier-3 — the fix that closed D59) SHALL be preserved in the Expanded coordinates.

### Requirement 3 — World map UI

**User Story:** As a player, I want to open a map and see where I am, what I've found, and where I
haven't been, so exploration has a legible payoff.

#### Acceptance Criteria

1. A new UI screen SHALL show all three regions as concentric rings (or an equivalent legible
   spatial representation) around Port Royal, matching `docs/11_WORLD_MAP.md`'s stated geography
   model.
2. Discovered islands SHALL render with their name/type visible; undiscovered islands SHALL render
   either hidden or as an unrevealed "?" marker, consistent with Requirement 4's discovery system.
3. The player's current position and heading SHALL be shown on the map.
4. The active chapter's objectives (already tracked by `CampaignManager`/`CaptainsLog`) SHALL be
   visible from the map view, or the map SHALL be reachable from the same HUD area as
   `CaptainsLog` without leaving the informational context of "what should I be doing."
5. The map SHALL be reachable via a HUD button consistent with `CaptainsLog`'s existing
   dynamically-positioned button pattern (`WorldHUD._create_captains_log_button()`), not a new ad
   hoc UI convention.

### Requirement 4 — Discovery / fog of war

**User Story:** As a player, I want islands to reveal themselves as I approach, so the ocean holds
real mystery instead of the whole map being known from the start.

#### Acceptance Criteria

1. `IslandData.discovered` SHALL flip to `true` the first time the player comes within a
   configurable reveal radius of that island (building on the existing on-dock write path from M7,
   extending it to reveal-on-approach rather than reveal-only-on-dock).
2. An island's marker SHALL not appear on the Requirement 3 map (or SHALL appear only as an
   unrevealed marker) until `discovered` is `true`.
3. Discovery state SHALL persist through `SaveManager` (extending the existing
   `IslandData`/`Island` save round-trip, not a new persistence path).
4. Chapter objectives using the `DISCOVER_ISLAND` condition (already defined in
   `ObjectiveData.Condition` per `docs/05_CURRENT_SYSTEMS.md`'s M7 section, listed as a gap in
   `docs/13_CAMPAIGN_LEVELS_1-5.md` §8) SHALL now be dispatchable from this real discovery signal.

### Requirement 5 — Per-region weather and enemy types

**User Story:** As a player, I want Contested Waters and Imperial Waters to feel meaningfully
different to sail through, not just harder versions of Beginner Waters.

#### Acceptance Criteria

1. `EnvironmentController` SHALL support per-region weather variation (at minimum: the "choppy
   seas / occasional squall" for Contested Waters and "heavy seas" for Imperial Waters already
   described in `docs/11_WORLD_MAP.md`'s per-region specs), beyond today's time-of-day-only
   variation.
2. A new `EventData` resource (per `docs/14_SYSTEM_INVENTORY.md`'s identified gap — `EventManager`
   currently hardcodes its events) SHALL let world events be authored as data, not GDScript
   literals.
3. Enemy *type* composition (not just the existing stat multiplier) SHALL differ by region — e.g.
   Beginner Waters' Sloops/Dinghies vs. Imperial Waters' Frigates/Galleons, per
   `docs/11_WORLD_MAP.md`'s per-region enemy rosters — closing the gap `EnemySpawner`'s own TODO
   already flags.

### Requirement 6 — Ship damage visuals follow-up

**User Story:** As a player, I want a badly-damaged ship to visibly look like it's about to sink,
completing the "hull shows what it survived" beat M8 started.

#### Acceptance Criteria

1. `ShipVisuals` SHALL gain a distinct visual state for hull-critical (near-destruction) beyond the
   existing `hull_damaged_threshold` smoke/scorch-tint states from M8 — per `docs/navalCombat.md`
   §7's one remaining open item.
2. This SHALL reuse `ShipDamage.pool_changed`, the same signal M8's existing damage-visual states
   already listen to — no new signal or polling.

### Requirement 7 — 2–4 new islands

**User Story:** As a player, I want each region to hold more than two islands, so exploring within
a region (not just between regions) has payoff.

#### Acceptance Criteria

1. 2–4 new `IslandData` resources SHALL be authored across the existing three regions (not a new
   region), each with a real `world_position`/`region_id` per Requirement 2, an `IslandType`, and
   at minimum a rumor/flavor hook consistent with `docs/11_WORLD_MAP.md`'s per-island dossier
   format.
2. Each new island SHALL be reachable and dockable using the existing `DockingSystem` with no new
   docking mechanics.

### Requirement 8 — Building-model art sourcing

**User Story:** As a player, I want my buildings to visibly look more advanced as I upgrade them,
so investing in my port feels like it's building something, not just incrementing a number.

#### Acceptance Criteria

1. Existing stock 3D asset packs (starting with Kenney-style packs, the same source that supplied
   every ship/island model already in the project) SHALL be investigated for building/structure
   models suitable for the 10 building chains × 5 levels, before any custom art is assumed
   necessary — mirroring the D40 ship-model-remap precedent.
2. If suitable stock models are found, they SHALL be integrated via `BuildingData.model_path` (the
   same mechanism `docs/10_ASSET_REQUESTS.md`'s M6 delivery plan already specified), for as many of
   the 50 building-level combinations as the sourced pack reasonably covers — a partial
   improvement (e.g. 3 distinct stages reused across levels, per `docs/10_ASSET_REQUESTS.md`'s own
   documented fallback) is an acceptable outcome if a full 50-model set isn't found.
3. If no suitable stock assets exist, this requirement SHALL be closed by documenting that finding
   in `docs/10_ASSET_REQUESTS.md` (updating the outstanding request with what was searched and
   ruled out) rather than left silently unaddressed — this milestone SHALL NOT block on
   commissioning custom art, which is outside a coding session's reach.

### Requirement 9 — Minimal save-schema version stamp

**User Story:** As a maintainer, I want every save file to record what schema version wrote it, so
M12's full versioning/backup/migration work has something to build on instead of starting from
zero after two more milestones of persisted-state growth.

#### Acceptance Criteria

1. `SaveManager.save_game()` SHALL write a `save_schema_version: int` field at the top level of
   the save data.
2. `SaveManager.load_game()` SHALL read this field (defaulting to `0`/unversioned for any
   pre-existing save file lacking it) but SHALL NOT yet implement any migration logic — that's
   explicitly M12 scope (see Non-Goals).
3. This SHALL NOT change any other save/load behavior — purely additive.

### Requirement 10 — Documentation

**User Story:** As a maintainer, I want this milestone's systems and any defects found while
building them recorded the same way every prior milestone's work has been.

#### Acceptance Criteria

1. `docs/05_CURRENT_SYSTEMS.md` SHALL gain an "M10 — The Legible World" section describing what
   shipped, following the established format of prior milestone sections.
2. `docs/14_SYSTEM_INVENTORY.md` SHALL have the Ocean LOD, world map UI, discovery/fog,
   per-region weather/enemy-type, and building-model-art rows updated from ❌/🟡 to ✅ (or 🟡 with
   an honest note, if Requirement 8's stock-asset search comes up short).
3. `docs/15_MASTER_PLAN.md`'s M10 exit-criteria results SHALL be filled in.

---

## Non-Goals

- Full save schema migration/versioning logic, backup files, or corruption recovery — Requirement
  9 only adds the version *field*; the migration path is explicitly M12 scope
  (`docs/15_MASTER_PLAN.md`'s M12 entry).
- Custom-commissioned building art — Requirement 8 is scoped to sourcing existing stock assets and
  honestly documenting the outcome either way, not art production.
- A fourth or fifth region (Ancient Ocean, Ghost Reaches) — both remain id-reserved for M14, per
  `docs/11_WORLD_MAP.md` §5 and `docs/15_MASTER_PLAN.md`'s M14 entry.
- Wind as a mechanic, cannonball arcing, or any other M11 (Depth) scope.
- Real portrait art — M11 scope; this milestone doesn't touch character presentation.
- Mobile device performance profiling on real hardware — Requirement 1's "mid-range Android
  device" framing is the target this milestone's LOD work is *for*, but actual on-device testing
  remains M13 scope (no device profiling has ever been run on this project, per
  `docs/14_SYSTEM_INVENTORY.md` §5).
