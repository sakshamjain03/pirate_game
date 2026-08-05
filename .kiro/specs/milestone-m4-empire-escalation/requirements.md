# Requirements Document

## Introduction

Milestone M4 — Empire Escalation adds the mechanic that was missing from every prior document:
**your empire draws the attention of larger powers as it grows, and those powers raid you back.**
This is the single biggest gap between the current build (a working sail/build/fight sandbox with
no sense of mounting danger) and the "pirate Clash-of-Clans / Age-of-Empires" fantasy described in
the product direction.

This milestone does **not** introduce multiplayer, real-time PvP, or discrete mission maps — per
the confirmed product direction: all opposing "empires" and rival pirates are AI factions in a
single continuous open world, and regions unlock progressively rather than existing as separate
levels.

This milestone assumes milestone-m3-stabilization is complete — in particular, the colonize/
capture flow (D2) must already work, since Empire Escalation is built directly on top of
`Island.capture_island()` and `FactionManager`.

MVP scope for this milestone is **3 regions**, not 5 (matching `agents.md`'s existing "MVP
Philosophy: Three Regions" line). A 4th and 5th region are pure data-addition follow-up work
once this milestone's systems exist (see §Out of Scope).

---

## Glossary

- **Empire faction**: A `FactionData` instance flagged `is_empire = true` — a large colonial
  power (Royal Navy / "Britain", a new Spanish Empire faction) as opposed to a smaller faction
  (Pirate Clans, Merchant Guild) that does not escalate.
- **Notoriety**: A single float value (0+, unbounded upward, no explicit cap) tracked globally by
  `EmpireManager`, representing how much attention the player's empire has drawn. Increases when
  the player destroys empire-faction ships, colonizes/captures islands, or completes raids.
  Decreases slowly over real time when the player takes no aggressive action (see Requirement 3).
- **Region**: A named grouping of existing islands (`RegionData` resource), each associated with
  one dominant empire faction and a threat tier (1, 2, or 3 for this milestone).
- **Region activation**: The state transition of a region from "dormant" (its ENEMY-type islands
  have no defenders, cannot be colonized, and do not raid the player) to "active" (full gameplay:
  defenders spawn, colonization is possible, the region's empire can raid the player), triggered
  by the player's Notoriety crossing that region's activation threshold.
- **Home Island**: The first island the player colonizes. The target of Empire raids.
- **Raid**: A simulated attack on the player's Home Island by an active region's empire faction,
  resolved deterministically (not as a real-time battle the player fights) by comparing a
  defense score against an attack score, producing a `RaidReport`.
- **RaidReport**: A data structure describing the outcome of a resolved raid (resources stolen,
  buildings damaged, whether the raid was repelled), shown to the player via a new UI screen.
- **Defense score**: A number computed from the Home Island's built defensive buildings
  (Fortress, Watchtower tiers) and any ships explicitly assigned to "Defend Home" duty via
  `FleetManager`.
- **Attack score**: A number computed from the raiding empire's current threat tier and the
  player's current Notoriety.

---

## Requirements

### Requirement 1: Empire faction data

**User Story:** As a player, I want to face escalating colonial powers (not just generic
"enemy ships"), so that growing my empire feels like it's provoking someone specific and real.

#### Acceptance Criteria

1. THE `FactionData` resource schema SHALL gain a new `is_empire: bool` field, defaulting to
   `false`, additive to the existing schema (no existing field removed or renamed).
2. THE existing `RoyalNavy` faction (representing Britain) SHALL have `is_empire = true`.
3. A new faction resource `resources/factions/SpanishEmpire.tres` SHALL exist with
   `is_empire = true`, a distinct `id`/`name`/sail+hull colors from all existing factions.
4. THE `PirateClans`, `MerchantGuild`, and `GhostFaction` factions SHALL retain
   `is_empire = false`.
5. THE `PlayerFaction` (from milestone-m3-stabilization) SHALL have `is_empire = false`.

---

### Requirement 2: Region data and mapping

**User Story:** As a player, I want the ocean to feel like it's organized into progressively
more dangerous territories, so that my sense of growth is tied to place, not just numbers.

#### Acceptance Criteria

1. A new `RegionData` Resource class SHALL exist (`scripts/world/RegionData.gd`) with fields:
   `id: String`, `display_name: String`, `tier: int` (1–3 for this milestone), `dominant_faction:
   String` (a faction id), `activation_notoriety_threshold: float`, `island_ids: Array[String]`.
2. Exactly 3 `RegionData` instances SHALL exist, mapping the 6 existing populated `IslandData`
   instances as follows (or an equivalent grouping preserving increasing danger order):
   - Region 1 "Beginner Waters" — tier 1, dominant_faction = PirateClans or MerchantGuild,
     `activation_notoriety_threshold = 0` (always active from game start) — islands: PortRoyal, Tortuga
   - Region 2 "Contested Waters" — tier 2, dominant_faction = RoyalNavy — islands: SkullCove, FrozenIsland
   - Region 3 "Imperial Waters" — tier 3, dominant_faction = SpanishEmpire — islands: VolcanoIsland, plus one newly-authored ENEMY island owned by SpanishEmpire
3. EVERY existing `IslandData` instance SHALL be assigned to exactly one region (no island
   belongs to zero or multiple regions).
4. THE `activation_notoriety_threshold` for Region 2 and Region 3 SHALL be nonzero and
   increasing (Region 3's threshold > Region 2's threshold), so regions activate in order.

---

### Requirement 3: Notoriety tracking

**User Story:** As a player, I want my aggressive/expansionist actions to visibly build toward
something, so that I understand why the world is getting more dangerous around me.

#### Acceptance Criteria

1. A new autoload `EmpireManager` (`scripts/managers/EmpireManager.gd`) SHALL track a single
   float `notoriety`, starting at `0.0`.
2. WHEN the player destroys a ship belonging to an `is_empire = true` faction, THE
   `EmpireManager` SHALL increase `notoriety` by a configurable amount (suggested default: 5.0
   per empire ship destroyed, 1.0 per non-empire enemy ship destroyed).
3. WHEN the player successfully colonizes or captures an island (via `Island.capture_island()`),
   THE `EmpireManager` SHALL increase `notoriety` by a configurable amount (suggested default:
   15.0 per island).
4. WHILE more than a configurable idle duration has passed since the last notoriety-increasing
   action (suggested default: 10 real-time minutes), THE `EmpireManager` SHALL decrease
   `notoriety` at a slow configurable rate, clamped to a minimum of `0.0`.
5. THE `EmpireManager` SHALL emit `notoriety_changed(new_value: float)` whenever `notoriety`
   changes.
6. THE `notoriety` value SHALL persist through `SaveManager` (save/load round-trip preserves the
   exact value, subject to float tolerance).

---

### Requirement 4: Region activation

**User Story:** As a player, I want previously-dormant, more dangerous territories to "come
alive" as I grow, so that the world visibly escalates in response to my actions rather than being
uniformly difficult from the start.

#### Acceptance Criteria

1. WHEN `EmpireManager.notoriety` crosses a region's `activation_notoriety_threshold` (from
   below to at-or-above), THE `EmpireManager` SHALL mark that region active and emit
   `region_activated(region_id: String)` exactly once for that region.
2. WHILE a region is dormant (not yet active), THE ENEMY-type islands within it SHALL NOT spawn
   defenders and SHALL NOT be colonizable (the "Colonize"/capture-on-defeat flow SHALL be
   disabled for islands in a dormant region, with a UI message indicating the region is not yet
   contested).
3. WHEN a region becomes active, THE ENEMY-type islands within it SHALL begin spawning defenders
   according to their existing `Island.gd` logic, and SHALL become colonizable/capturable as
   normal.
4. THE `activation_notoriety_threshold` check SHALL be re-evaluated whenever `notoriety` changes
   (subscribe to `notoriety_changed`), not only at game load.
5. Region 1 SHALL be active from game start (`activation_notoriety_threshold = 0`).
6. THE active/dormant state of each region SHALL persist through `SaveManager`.

---

### Requirement 5: Escalating raid fleet strength

**User Story:** As a player, I want enemy ships to actually get tougher as I gain notoriety and
move into higher-tier regions, so that growth feels like it comes with real risk.

#### Acceptance Criteria

1. THE `EnemySpawner.gd` (or a new helper it calls) SHALL expose a function that, given a region's
   `tier` and the current global `notoriety`, returns a scaling multiplier applied to spawned
   enemy ship stats (health/damage) and/or a higher-tier `ShipStats` resource selection for that
   spawn.
2. WHEN an empire faction (`is_empire = true`) ship is spawned in a tier-2 or tier-3 region, ITS
   effective stats SHALL be measurably higher (at minimum +25% health and damage at tier 2,
   +60% at tier 3, relative to the base `EnemyShipStats.tres` values) than the same faction's
   ship spawned in a tier-1 region.
3. THE scaling function SHALL be pure/deterministic for a given (tier, notoriety) input pair —
   calling it twice with the same inputs SHALL return the same multiplier, so it is testable
   without relying on random state.
4. THIS requirement SHALL NOT change ambient (non-empire) pirate/merchant spawn strength — only
   `is_empire = true` faction spawns scale with tier/notoriety.

---

### Requirement 6: Home Island raid simulation

**User Story:** As a player, I want my colony to be at risk even when I'm not actively defending
it, so that building defenses and choosing where to leave my fleet actually matters — the core
"you can be raided" promise of the pitch.

#### Acceptance Criteria

1. THE player's first successfully colonized island SHALL be recorded by `EmpireManager` as the
   `home_island_id`.
2. THE `EmpireManager` SHALL compute a **defense score** for the Home Island from: the tier of
   its built Fortress (if any) and Watchtower (if any) buildings, plus a bonus for any ship
   explicitly flagged "Defend Home" via `FleetManager`. Ships actively piloted by the player or
   on an active Fleet mission SHALL NOT count toward defense score.
2. THE `EmpireManager` SHALL compute an **attack score** for a potential raid from: the
   dominant empire faction of the highest-tier *active* region, that region's tier, and the
   current `notoriety` value.
3. ON a periodic check (suggested default: every 15 real-time minutes while the game is running,
   AND once on game load if that much real time has elapsed since the last check, using
   timestamps persisted via `SaveManager`), IF at least one region is active with
   `dominant_faction.is_empire == true`, THEN THE `EmpireManager` SHALL roll a raid attempt with
   a probability that increases with `notoriety` (suggested: probability = clamp(notoriety /
   200.0, 0.05, 0.6)).
4. WHEN a raid attempt occurs, THE `EmpireManager` SHALL compare defense score to attack score
   and produce a `RaidReport` (Dictionary or lightweight Resource) containing: whether the raid
   was repelled (defense ≥ attack), gold/resources stolen if not repelled (a percentage of
   current stored resources, capped at a reasonable maximum e.g. 25%), and which empire faction
   conducted the raid.
5. IF the raid is not repelled, THEN THE `EmpireManager` SHALL deduct the stolen resources via
   `ResourceManager` and SHALL NOT destroy or downgrade built buildings in this milestone
   (building damage is out of scope — theft only, to keep the first slice simple).
6. THE most recent unshown `RaidReport` SHALL persist through `SaveManager` if the game closes
   before the player has seen it.

---

### Requirement 7: Raid report UI

**User Story:** As a player, I want to be told clearly what happened while I was away, so that a
raid feels like a meaningful event rather than resources silently vanishing.

#### Acceptance Criteria

1. A new scene `scenes/ui/RaidReportScreen.tscn` + `scripts/ui/RaidReportScreen.gd` SHALL exist,
   following the same `CanvasLayer → Control (FULL_RECT)` structure as `DeathScreen`.
2. WHEN the World scene loads and an unshown `RaidReport` exists, THE `RaidReportScreen` SHALL be
   shown automatically, displaying: which faction raided, whether it was repelled, and (if not
   repelled) how many of each resource were stolen.
3. THE `RaidReportScreen` SHALL have a single dismiss button that closes the screen and marks the
   report as shown (cleared from persisted state).
4. THE `RaidReportScreen` SHALL NOT block indefinitely — if dismissed, gameplay resumes normally.

---

### Requirement 8: Notoriety visibility in HUD

**User Story:** As a player, I want to see my current notoriety and know how close I am to the
next region activating, so that escalation feels like a legible system, not an invisible dice
roll.

#### Acceptance Criteria

1. THE `WorldHUD` SHALL display the current `notoriety` value.
2. WHEN a dormant region exists, THE `WorldHUD` (or a dedicated small panel) SHALL display the
   notoriety threshold remaining until the next region activates.
3. WHEN a region activates, THE `WorldHUD` SHALL show a one-time, dismissable notification naming
   the region and its dominant empire.

---

## Out of Scope

- Regions 4 and 5 (Frozen Sea / Volcanic Sea / Royal Navy Waters / Ancient Ocean from the PRD's
  aspirational list) — pure data-addition follow-up once this milestone's `RegionData`/
  `EmpireManager` systems exist and are proven with 3 regions.
- Building damage/destruction from raids (theft only in this milestone).
- Real-time player-fought defense battles (raids are simulated/resolved, not fought live) — a
  live "defend your island" battle mode is a candidate for a later milestone, not this one.
- Diplomacy UI, alliance/peace mechanics with empire factions.
- Any physical map-locking/fog-of-war for dormant regions — dormant regions remain sailable and
  visible, only their gameplay hooks (defenders, colonization, raiding) are inactive. Do not
  build a barrier or loading-gate system.
- Independent Cities / Ancient Order factions from the PRD.
- Rebalancing existing non-empire faction difficulty.
