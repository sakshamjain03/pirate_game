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
4. **The world is bounded, generously.** Originally "expands outward forever" — amended once the
   game shipped with unlimited sailable space, which read as a bug rather than a feature. The
   world is now a square, ±1400 u from the origin (`WorldBoundsData.tres`,
   `ShipController._clamp_to_world_bounds()`), sized with headroom past Ghost Reaches' 1150 u
   ring (the outermost currently authored content). New regions still don't require moving any
   existing coordinate; growing past this bound in some future milestone means revisiting this
   one number.
5. **Readable from the compass alone, and now anchored to real Golden Age of Piracy geography**
   since the named islands are real places. Beginner Waters (Port Royal, Tortuga) sits at the
   English/buccaneer home waters (Jamaica–Hispaniola corridor); Contested Waters (Skull Cove,
   Frostbite Reef) clusters **north**, echoing the real Bahamas as the era's biggest lawless
   pirate haven; Imperial Waters (Mount Brimstone, Cartagena Outpost) clusters **south/south-east**,
   the real Spanish Main. Mental map: *the pirates are close in, the lawless north is where the
   Navy hunts, Spain is south.*

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

> **M10 update: Expanded (§4b) is now the live layout** — Ocean LOD landed (§7), gating condition
> met. §3 above still documents the pre-Compact history (the M-1/M-2 defects that motivated this
> section) and §4a's Compact numbers as the intermediate step that shipped in M7; neither is the
> current in-game state any more. The six original islands' `world_position` values are §4b's
> numbers below; three new islands from M10 Requirement 7 are in §6.

Two options, both shipped in sequence rather than picking one. **Compact adopted M7, Expanded
adopted M10 once ocean LOD existed.**

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

> **Former blocker, resolved M10:** `test_property_21_lod_distance_transitions` was the project's
> single known failing test precisely because `OceanController` had **no LOD system** — a 1350 u
> ocean span with a uniform wave mesh is a mobile framerate problem. M10 closed it with a two-ring
> `PlaneMesh` LOD (`OceanController.get_lod_level()`); see `docs/05_CURRENT_SYSTEMS.md`'s M10
> section for the implementation.

## 4c. Realistic-geography bearings (current)

The 5 islands the campaign builds around (Chapters 1, 2, 4, 5) were repositioned to real Golden
Age of Piracy bearings, keeping each inside its already-live Expanded ring band (§4b) — only the
compass direction changed, not the distance-equals-danger pacing:

| Island | Region | Coordinates (x, z) | Distance | Bearing | Real-world echo |
|---|---|---|---|---|---|
| Port Royal | Beginner | (0, 0) | — | home | Jamaica |
| Tortuga | Beginner | (170, −140) | 220 u | ENE | Real Tortuga sits NE of Jamaica |
| Skull Cove | Contested | (60, −430) | 434 u | N | The Bahamas — the era's biggest pirate haven |
| Frostbite Reef | Contested | (280, −340) | 440 u | NE | Groups with Skull Cove as the lawless north |
| Mount Brimstone | Imperial | (480, 380) | 612 u | SE | Real volcanic islands (Lesser Antilles) sit SE |
| Cartagena Outpost | Imperial | (120, 630) | 641 u | S | Real Cartagena is due south of Jamaica |

`pelican_cay`, `blackwater_shoal`, `isla_del_rey`, `widows_reach`, `fogbound_cay` keep their
pre-existing coordinates for now — a natural follow-up once these 5 are done.

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
- **Islands:** Port Royal (home, buildable), Tortuga (friendly, Guild trade + Tavern), Pelican
  Cay (neutral, resource island — M10).
- **Purpose:** teach the loop. Never punish.

## Region 2 — Contested Waters (tier 2, threshold 60)

- **Dominant faction:** Royal Navy. **Bearing:** north (the Bahamas-like lawless channel).
- **Weather:** choppier seas, occasional squall (visual only at first).
- **Enemies:** Schooners, Brigantines, Corvettes. `StandardEnemy` profile. Navy patrols travel
  in pairs. Spawn multiplier 1.3+ for `is_empire` factions.
- **Islands:** Skull Cove (enemy, Pirate Clan seat — Chapter 2 target), Frostbite Reef (enemy,
  Navy anchorage — Chapter 4 boss arena), Blackwater Shoal (enemy, Navy waystation — M10).
- **Purpose:** the first real fights and the first raids on home.

## Region 3 — Imperial Waters (tier 3, threshold 150)

- **Dominant faction:** Spanish Empire. **Bearing:** south and south-east (the Spanish Main).
- **Weather:** heavy seas; Mount Brimstone carries ash haze, Cartagena is fog-prone.
- **Enemies:** Frigates and Galleons, `AggressiveGalleon` profile. Spawn multiplier 1.6+.
- **Islands:** Mount Brimstone (enemy, volcanic — iron/sulphur), Cartagena Outpost (capital,
  the Chapter 5 prize), Isla del Rey (enemy, Spanish garrison — M10).
- **Purpose:** the mid-game plateau. Level-5 buildings and the largest hulls live here.

## Region 4 — The Ancient Ocean (tier 4, threshold 300) — built M14

- **Dominant faction:** Pirate Clans (reused rather than inventing a new faction — Solomon Vane,
  whose lost ship this region's story is about, was a legendary pirate captain). **Bearing:** due
  west, past Cartagena.
- **Enemies:** Galleons and Men O'War (`AncientOcean.tres`'s `enemy_ship_pool`) — the highest-tier
  existing hulls, no new ship stats needed for ambient combat here.
- **Islands:** Widow's Reach (`widows_reach`, LEGENDARY — the first-ever use of that `IslandType`
  value; a discovery/wreck site, not a garrison, so it carries no `owner_faction`).
- **Purpose:** Chapter 6 (The Wandering Widow) — Higgins' forty-year secret and Vane's chart, both
  paid off here.

## Region 5 — The Ghost Reaches (tier 5, threshold 500) — built M14

- **Dominant faction:** The Ghost Fleet (`ghost_fleet`, already existed as a rumour-only faction
  pre-M14). **Bearing:** due north, past Frostbite.
- **Enemies:** Ghost Raiders/Ghost Marauders (`GhostReaches.tres`'s `enemy_ship_pool`, class 3/4,
  reusing the existing `ship-ghost.glb` model) for ordinary ambient combat, plus a dedicated
  region-gated boss, "The Wandering Widow" (`ghost_fleet_flagship`) — the Ghost Fleet's first real,
  regular, everyday mechanical presence rather than the pre-existing rare global ambient event
  (`GhostShipBoss`), which still exists unchanged alongside it.
- **Islands:** Fogbound Cay (`fogbound_cay`, ENEMY, owned by the Ghost Fleet).
- **Purpose:** the tone rule's Chapters 1–5 boundary ("the supernatural is rumoured, never
  confirmed") is deliberately left behind here — real ships, real crew, real combat, real
  boarding/looting — while the *supernatural explanation* stays unconfirmed on purpose (M14
  design.md's explicit resolution, not a default). No chapter is gated on this region; it's pure
  world-expansion content, same as the original three regions.

---

# 6. Island dossiers

Each island answers: what it *gives*, what it *costs*, and what story it carries.

### Port Royal — `port_royal` · Beginner · **HOME (once claimed)**
Drowned in the quake, half of it still underwater. Pirate-friendly and undefended, but **not
owned at game start** — the player claims it via the ordinary Colonize flow (Chapter 1's new
opening objective), at a story-cheap cost (`colonize_cost_gold = 100`) nobody else wanted to
charge for a ruin.
- **Gives:** every build slot the player owns, once claimed; the only island with the full
  building set.
- **Costs:** nothing to hold — but once home, it is the *only* raid target
  (`EmpireManager._resolve_raid()`).
- **Story:** Chapter 1 in its entirety. The harbour board with the empire's name on it.
- **Type:** `NEUTRAL` until claimed, then `FRIENDLY` — the same generic `capture_island()` path
  every other island uses (no more special-cased `CAPITAL` seeding).
- **Visual:** `DROWNED_RUIN` terrain theme — a bleached, waterlogged tint distinct from a stock
  tropical island.

### Tortuga — `tortuga` · Beginner · Friendly
The pirate port that *didn't* sink, and is quietly smug about it.
- **Gives:** Merchant Guild trade at better rates; the Tavern where the first hires happen;
  rumours (chapter hints).
- **Costs:** robbing Guild convoys tanks reputation here and shuts the tap off.
- **Story:** Higgins' contacts; Factor Hale's office; where the player hears about Morrow.

### Pelican Cay — `pelican_cay` · Beginner · Neutral
A low sandbar thick with pelican rookeries; fishermen from Tortuga work it.
- **Gives:** a second Beginner-ring resource stop, keeping Region 1 worth exploring beyond
  the two original islands rather than a two-stop errand.
- **Costs:** nothing — neutral, no faction claims it.
- **Story:** no chapter hook yet; a quiet island for the early game's economy variety.

### Skull Cove — `skull_cove` · Contested · Enemy
A drowned volcanic caldera with one entrance. Morrow's seat.
- **Gives:** on capture — the best *rum* production in the game, and the Pirate Clans stop
  raiding.
- **Costs:** capture tanks Pirate Clan reputation permanently; they spawn hostile after.
- **Story:** the whole of Chapter 2. Target of the first island capture the player *chooses*.
- **Visual:** `CALDERA` terrain theme — a dark basalt tint, distinct from Mount Brimstone's
  scorched-ash `VOLCANIC` theme despite both being volcanic in lore.

### Frostbite Reef — `frozen_island` · Contested · Enemy
Not truly frozen — a cold-current reef with wrecks locked in rime. Navy deep anchorage.
- **Gives:** on capture — iron, and the Navy loses its forward base (raid frequency drops).
- **Costs:** the hardest fight before Imperial Waters; the boss arena.
- **Story:** Chapter 4. HMS *Intransigent* is berthed here.

### Blackwater Shoal — `blackwater_shoal` · Contested · Enemy
A Navy resupply waystation on a reef too shallow for their larger hulls.
- **Gives:** on capture — thins the Navy's Contested-ring presence, a third target alongside
  Skull Cove and Frostbite Reef.
- **Costs:** a Royal Navy hold; capture affects Navy reputation like the region's other targets.
- **Story:** no chapter hook yet — a region-filling target, not a story beat.

### Mount Brimstone — `volcano_island` · Imperial · Enemy
Active volcano; Spain mines sulphur and iron with convict labour.
- **Gives:** the game's only high-tier iron; unlocks the best cannon tech line.
- **Costs:** Spanish Empire reputation floor; ash haze reduces visibility in combat.
- **Story:** Chapter 5's first objective — cut the fleet's supply before you rob it.

### Isla del Rey — `isla_del_rey` · Imperial · Enemy
A walled Spanish garrison island guarding the approach to Cartagena.
- **Gives:** on capture — a third Imperial-ring target alongside Mount Brimstone and
  Cartagena Outpost, giving the region's deepest ring more to explore before the finale.
- **Costs:** a Spanish Empire hold; capture affects Spanish reputation like the region's
  other targets.
- **Story:** no chapter hook yet — a region-filling target, not a story beat.

### Cartagena Outpost — `cartagena_outpost` · Imperial · **Capital**
The fortified staging port for the treasure fleet crossing.
- **Gives:** on capture — the largest single loot payout in the game and a second buildable
  island (the first non-home island the player can develop).
- **Costs:** the hardest content in v1.
- **Story:** Chapter 5 finale; Cárdenas; the unmapped chart.
- **Visual:** `FORTIFIED` terrain theme — a grey stone/arid tint matching its colonial garrison
  lore.

### Widow's Reach — `widows_reach` · Ancient Ocean · **Legendary** (M14)
The wreck site of the *Wandering Widow*, Solomon Vane's ship, lost forty years before the
campaign begins. The first island in the game to use `IslandType.LEGENDARY`.
- **Gives:** no production, no capture — a discovery/story site, not a garrison. Carries no
  `owner_faction`.
- **Costs:** nothing to visit; the danger on the way there is the region's ambient Pirate Clan
  presence, not the island itself.
- **Story:** Chapter 6 (The Wandering Widow) in its entirety — Higgins' forty-year secret (he was
  the Widow's cabin boy) and the payoff of Vane's chart from Chapter 5's closing beat.

### Fogbound Cay — `fogbound_cay` · Ghost Reaches · Enemy (M14)
A reef permanently wrapped in fog, held by the Ghost Fleet.
- **Gives:** on capture — the deepest-water resource yield in the game (not yet a chapter
  objective; a region-filling target, same category Blackwater Shoal/Isla del Rey were before
  M14 gave one of them a chapter hook).
- **Costs:** the hardest ambient combat in the game — Ghost Raiders/Marauders, plus a dedicated
  boss ("The Wandering Widow," `ghost_fleet_flagship`) once the region is active.
- **Story:** no chapter hook — the Ghost Fleet's tone-rule boundary (rumour → real mechanical
  presence) is the point of this region, not a story beat tied to a specific chapter.

---

# 7. What the map needs that does not exist yet

| Need | Why | Status |
|---|---|---|
| `IslandData` carries no coordinates | Layout lives only in `World.tscn`; nothing can reason about distance | ✅ M10 — `world_position: Vector2`, and `Island.gd::_ready()` now writes the node's `global_position` from it, making the data authoritative rather than agreeing with `World.tscn` only by convention |
| `IslandData` carries no region id | Region membership is only in `RegionData.island_ids` (one-way) | ✅ M10 — `region_id: String` |
| No discovery/fog system | `IslandData.discovered` exists and is **unused** | ✅ M10 — reveal-on-approach via `WorldManager._check_island_discovery()`, plus `discovered` is now actually persisted (it wasn't before — a real bug found and fixed during M10) |
| No world map / navigation UI | Player cannot see the map or set a heading | ✅ M10 — `WorldMapScreen.tscn` |
| No per-region weather or enemy *types* | Only stat multipliers differ; documented gap in §5 of CURRENT_SYSTEMS | ✅ M10 — `RegionData.wave_intensity_multiplier` + `enemy_ship_pool` |
| Ocean LOD | Gates the Expanded layout | ✅ M10 — two-ring `PlaneMesh` LOD, closes the project's one previously-standing failing test |
| Second buildable island | Cartagena is designed as one; `Island.gd` supports it, no UI flow proves it | 🟡 verify in M7 |
| Deep-water / open-ocean spawn zones | Enemies spawn relative to player, not to region | ✅ resolved differently than proposed — `EnemySpawner`'s player-relative spawn box turned out to already scale correctly with map size on its own (confirmed during M10's re-verification pass); no region-tied spawn zones were needed |

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
