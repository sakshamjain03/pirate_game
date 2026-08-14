# 11_WORLD_MAP.md

> Version: 1.0
> Status: Living Document — geography spec
> Owner: Project Lead
>
> Ground truth for what exists today: `docs/05_CURRENT_SYSTEMS.md` §3.
> Story context: `docs/06_NARRATIVE_AND_WORLD.md`. Chapters: `docs/13_CAMPAIGN_LEVELS_1-5.md`.

---

# 1. Design principles for the map

1. **The map is a set of rings, not a grid.** The home port is the origin. Distance from home
   *is* difficulty, danger, and reward. A player can always tell how deep they are by how far
   the harbour is behind them.
2. **Every island is a destination with a reason.** No decorative islands. Each one either
   produces something, threatens something, or hides something.
3. **Regions are rings, and they unlock by notoriety, not by sailing.** This already works —
   `EmpireManager` activates a region when `notoriety` crosses the region's threshold, and
   `Island._should_be_active()` gates defenders and capture on it. A player *can* sail into a
   dormant region early; it will simply be empty and uncapturable. That is a feature: the fog
   is lifted by fame, not by travel time.
4. **The world expands outward forever.** New regions are new rings. No existing coordinate
   ever has to move to add content.
5. **Readable from the compass alone.** Each region owns a rough bearing so players build a
   mental map: *Navy is north-east, Spain is south-west, the pirates are close in.*

---

# 2. Coordinate system

Godot world space, Y-up. The ocean plane is XZ.

- **+X = East**, **−X = West**
- **+Z = South**, **−Z = North**
- Y is reserved for wave height / terrain. Islands sit at `y = 0` with terrain raised to
  `y ≈ 0.9` (see `docs/05_CURRENT_SYSTEMS.md` D25).
- Home origin for all "distance from home" figures below is **Port Royal**.

**Physical constants that constrain layout** (measured, not assumed):

| Constant | Value | Source |
|---|---|---|
| Island collision cylinder radius | 11 u | `Island.tscn` |
| Island beach/terrain union radius | ≈ 13.7 u | D25 fix |
| Island dock marker | x = 16 u | `Island.tscn` |
| Minimum safe island-to-island spacing | **40 u** | 13.7 × 2 + navigation clearance |
| Player cruise speed (Sloop) | 15 u/s max, ≈ 11–12 u/s realistic | `resources/ships/Sloop.tres` |
| Islands collision layer | 17 (layer 1 + layer 5 = terrain) | D31 |
| Camera spring-arm mask | 16 (terrain only) | D31 |

---

# 3. Current layout (as authored in `scenes/world/World.tscn`)

| Island | id | Coordinates (x, z) | Distance from home | Region (from `.tres`) | Region tier |
|---|---|---|---|---|---|
| Port Royal | `port_royal` | (30, −30) | 0 (home) | Beginner Waters | 1 |
| Tortuga | `tortuga` | (−50, 20) | **94 u** | Beginner Waters | 1 |
| Skull Cove | `skull_cove` | (10, −80) | **54 u** | Contested Waters | 2 |
| Frostbite Reef | `frozen_island` | (80, 60) | **104 u** | Contested Waters | 2 |
| Mount Brimstone | `volcano_island` | (−80, −70) | **118 u** | Imperial Waters | 3 |
| Cartagena Outpost | `cartagena_outpost` | (−120, 100) | **197 u** | Imperial Waters | 3 |

## Two defects in the current layout

**M-1 — the rings are out of order.** Skull Cove is a *tier-2* island but sits **54 u** from
home, closer than tier-1 Tortuga at **94 u**. The first thing a new player sails toward is the
tier-2 pirate stronghold. Distance stops communicating danger, which breaks principle 1 and
undercuts Chapter 2's staging.

**M-2 — the world is too small for its own travel times.** At ≈ 12 u/s, the *entire* map is
crossed in about 25 seconds and the deepest island is ~16 s away. There is no voyage, no
commitment, no "we are a long way from home" — which is the single most important feeling AC
IV: Black Flag delivers and the one this map cannot currently produce.

Both are fixed in §4. Neither is urgent enough to block M6.

---

# 4. Target layout

Two options. **Recommendation: adopt Compact now (M7), Expanded when ocean LOD exists.**

## 4a. Compact (recommended for the next milestone)

Minimal change — fixes ring ordering only, keeps the world small enough for the current ocean
mesh. No new islands.

| Island | Region | New (x, z) | Distance | Bearing | Change |
|---|---|---|---|---|---|
| Port Royal | Beginner | (0, 0) | — | home | moved to true origin |
| Tortuga | Beginner | (−70, 55) | 89 | SW | ~unchanged |
| Skull Cove | Contested | (40, −150) | 155 | N | **moved out 101 u** |
| Frostbite Reef | Contested | (150, 60) | 162 | E | moved out 58 u |
| Mount Brimstone | Imperial | (−180, −150) | 234 | NW | moved out 116 u |
| Cartagena Outpost | Imperial | (−200, 160) | 256 | SW | moved out 59 u |

Ring bands: **Beginner 60–110 u · Contested 140–180 u · Imperial 220–270 u.**
Deepest one-way voyage ≈ 21 s. Region-to-region crossing ≈ 8–10 s.

## 4b. Expanded (target once ocean LOD lands)

All Compact coordinates × **2.5**. Ring bands become **150–275 / 350–450 / 550–675 u**;
deepest one-way voyage ≈ 55 s, which is the AC-IV-like commitment we actually want.

> **Blocker, and it is a real one:** `test_property_21_lod_distance_transitions` is the
> project's single known failing test precisely because `OceanController` has **no LOD
> system**. A 1350 u ocean span with a uniform wave mesh is a mobile framerate problem. The
> long-standing "accepted failure" is therefore not cosmetic — it is the gate on the world
> being the size the design wants. See `docs/15_MASTER_PLAN.md`, M8.

## Sail-time budget (design target, ≈ 12 u/s cruise)

| Trip | Compact | Expanded | Feel we want |
|---|---|---|---|
| Home → nearest island | 7 s | 19 s | errand |
| Home → own region edge | 9 s | 23 s | patrol |
| Home → next region | 13 s | 33 s | expedition |
| Home → deepest island | 21 s | 55 s | voyage |

---

# 5. Regions

## Region 1 — Beginner Waters (tier 1, threshold 0, always active)

- **Dominant faction:** Pirate Clans. **Bearing:** the centre; home.
- **Weather:** calm, clear, low waves. No storms.
- **Enemies:** Sloops and Dinghies only, `HarassingSloop` AI profile, spawn multiplier 1.0.
- **Islands:** Port Royal (home, buildable), Tortuga (friendly, Guild trade + Tavern).
- **Purpose:** teach the loop. Never punish.

## Region 2 — Contested Waters (tier 2, threshold 60)

- **Dominant faction:** Royal Navy. **Bearing:** north and east.
- **Weather:** choppier seas, occasional squall (visual only at first).
- **Enemies:** Schooners, Brigantines, Corvettes. `StandardEnemy` profile. Navy patrols travel
  in pairs. Spawn multiplier 1.3+ for `is_empire` factions.
- **Islands:** Skull Cove (enemy, Pirate Clan seat — Chapter 2 target), Frostbite Reef (enemy,
  Navy anchorage — Chapter 4 boss arena).
- **Purpose:** the first real fights and the first raids on home.

## Region 3 — Imperial Waters (tier 3, threshold 150)

- **Dominant faction:** Spanish Empire. **Bearing:** west and south-west.
- **Weather:** heavy seas; Mount Brimstone carries ash haze, Cartagena is fog-prone.
- **Enemies:** Frigates and Galleons, `AggressiveGalleon` profile. Spawn multiplier 1.6+.
- **Islands:** Mount Brimstone (enemy, volcanic — iron/sulphur), Cartagena Outpost (capital,
  the Chapter 5 prize).
- **Purpose:** the mid-game plateau. Level-5 buildings and the largest hulls live here.

## Reserved regions (do not build; keep the ids free)

| id | Name | Tier | Threshold | Bearing | Seeded by |
|---|---|---|---|---|---|
| `ancient_ocean` | The Ancient Ocean | 4 | 300 | due W, past Cartagena | Ch5 closing beat |
| `ghost_reaches` | The Ghost Reaches | 5 | 500 | due N, past Frostbite | Ghost Fleet flavour |

---

# 6. Island dossiers

Each island answers: what it *gives*, what it *costs*, and what story it carries.

### Port Royal — `port_royal` · Beginner · **HOME**
Drowned in the quake, half of it still underwater. The player's capital.
- **Gives:** every build slot the player owns; the only island with the full building set.
- **Costs:** nothing to hold — but it is the *only* raid target (`EmpireManager._resolve_raid()`).
- **Story:** Chapter 1 in its entirety. The harbour board with the empire's name on it.
- **Type:** should be `CAPITAL` once owned (currently `NEUTRAL`).

### Tortuga — `tortuga` · Beginner · Friendly
The pirate port that *didn't* sink, and is quietly smug about it.
- **Gives:** Merchant Guild trade at better rates; the Tavern where the first hires happen;
  rumours (chapter hints).
- **Costs:** robbing Guild convoys tanks reputation here and shuts the tap off.
- **Story:** Higgins' contacts; Factor Hale's office; where the player hears about Morrow.

### Skull Cove — `skull_cove` · Contested · Enemy
A drowned volcanic caldera with one entrance. Morrow's seat.
- **Gives:** on capture — the best *rum* production in the game, and the Pirate Clans stop
  raiding.
- **Costs:** capture tanks Pirate Clan reputation permanently; they spawn hostile after.
- **Story:** the whole of Chapter 2. Target of the first island capture the player *chooses*.

### Frostbite Reef — `frozen_island` · Contested · Enemy
Not truly frozen — a cold-current reef with wrecks locked in rime. Navy deep anchorage.
- **Gives:** on capture — iron, and the Navy loses its forward base (raid frequency drops).
- **Costs:** the hardest fight before Imperial Waters; the boss arena.
- **Story:** Chapter 4. HMS *Intransigent* is berthed here.

### Mount Brimstone — `volcano_island` · Imperial · Enemy
Active volcano; Spain mines sulphur and iron with convict labour.
- **Gives:** the game's only high-tier iron; unlocks the best cannon tech line.
- **Costs:** Spanish Empire reputation floor; ash haze reduces visibility in combat.
- **Story:** Chapter 5's first objective — cut the fleet's supply before you rob it.

### Cartagena Outpost — `cartagena_outpost` · Imperial · **Capital**
The fortified staging port for the treasure fleet crossing.
- **Gives:** on capture — the largest single loot payout in the game and a second buildable
  island (the first non-home island the player can develop).
- **Costs:** the hardest content in v1.
- **Story:** Chapter 5 finale; Cárdenas; the unmapped chart.

---

# 7. What the map needs that does not exist yet

| Need | Why | Status |
|---|---|---|
| `IslandData` carries no coordinates | Layout lives only in `World.tscn`; nothing can reason about distance | ❌ add `world_position: Vector2` |
| `IslandData` carries no region id | Region membership is only in `RegionData.island_ids` (one-way) | ❌ add `region_id: String` |
| No discovery/fog system | `IslandData.discovered` exists and is **unused** | ❌ M8 |
| No world map / navigation UI | Player cannot see the map or set a heading | ❌ M8 |
| No per-region weather or enemy *types* | Only stat multipliers differ; documented gap in §5 of CURRENT_SYSTEMS | ❌ M7 |
| Ocean LOD | Gates the Expanded layout | ❌ M8 (known failing test) |
| Second buildable island | Cartagena is designed as one; `Island.gd` supports it, no UI flow proves it | 🟡 verify in M7 |
| Deep-water / open-ocean spawn zones | Enemies spawn relative to player, not to region | 🟡 `EnemySpawner` |

---

# 8. Adding a new island (checklist)

1. Author `resources/world/<Name>.tres` (`IslandData`) — id must be unique snake_case.
2. Add the id to exactly one `resources/world/regions/*.tres` `island_ids` array.
3. Instance `Island.tscn` in `scenes/world/World.tscn`; set `island_data`; place it at
   ≥ 40 u from every neighbour and inside its region's ring band.
4. Set `terrain_theme` (TROPICAL/VOLCANIC/FROZEN) — this re-tints the shared terrain
   (`KenneyMaterialApplier.override_material_path()`, fixed in D24).
5. If it is capturable, confirm `owner_faction` points at a real `FactionData`.
6. Add a dossier entry to §6 of this document.
7. Run the GUT suite. A new island must not change the test count.
