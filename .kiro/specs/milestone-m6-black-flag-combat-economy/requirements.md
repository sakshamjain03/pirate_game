# Requirements Document

## Introduction

Milestone M6 — Black Flag Combat & Island Economy is the first milestone aimed squarely at
**retention** rather than at feature coverage. M1–M5 built a world that works; M6 makes that
world worth returning to.

The reference hierarchy for this milestone, in priority order:

1. **Assassin's Creed IV: Black Flag** (primary) — naval combat feel and island economy.
   Broadsides that must be *aimed* and *timed*, not just triggered; ships that show damage;
   boarding as the climax of a fight rather than an instant kill; a fleet you invest in.
2. **Pirates of the Caribbean** (flavour) — naming, crew personality, legendary ships, the
   tone of an event log.
3. **Clash of Clans** (progression) — building levels, upgrade costs that gate on a currency
   you must go and *earn*, storage caps that push you back out to sea, a home island that
   visibly grows.

The design intent is a **circular economy**: sail → fight → loot → upgrade island → island
funds a better ship → better ship reaches harder waters → larger loot. Today that circle is
broken in two specific places, both confirmed by direct code inspection on 2026-08-09:

1. **Combat has no depth.** `ShipCombat.fire_broadside()` spawns identical cannonballs from
   every marker on a side with a single cooldown. There is no ammunition type, no aiming, no
   damage model beyond one `current_health` float, no boarding, no crew, and no reason to
   prefer one engagement over another. `EnemyAI` has five states but every enemy fights
   identically regardless of ship class or faction.
2. **The economy does not compound.** `BuildingData.next_upgrade` exists and `IslandMenu`
   already renders an Upgrade button — but **not one of the ten `resources/buildings/*.tres`
   files sets `next_upgrade`**, so the button never appears and `Island.upgrade_structure()`
   is unreachable dead code. Every building is level 1 forever. Production is a flat integer
   per tick with no scaling, so a player who has played for an hour earns exactly what a
   player who has played for a minute earns.

Scope note: per the user's direction, **this milestone builds the first 5 progression levels
only**. Building upgrade chains stop at level 5, island tiers stop at 5, and the ship ladder is
tuned so tier 5 is a satisfying mid-game plateau rather than an endgame.

This milestone assumes M1–M5 are complete. The M2 gaps re-confirmed during the 2026-08-09
audit (docking camera transitions, input rebinding UI) are folded into this milestone as
Requirement 9, because both are player-facing polish that affects the same retention goal.

---

## Glossary

- **Broadside** — a volley from every cannon on one side of the hull.
- **Chain shot** — ammunition that damages sails/speed rather than hull.
- **Grape shot** — ammunition that damages crew rather than hull.
- **Round shot** — standard hull-damage ammunition.
- **Boarding** — the melee resolution that triggers when an enemy hull drops below a
  threshold and the player closes to contact range.
- **Crew** — a per-ship population that gates boarding strength and repair rate.
- **Building level** — an integer 1–5; each level raises production and raises the next
  upgrade's cost.
- **Island tier** — an integer 1–5 derived from the levels of the buildings on it; gates
  which buildings may be constructed at all.
- **Circular economy** — the loop in which combat rewards fund island upgrades, and island
  upgrades fund combat capability.

---

## Requirements

### Requirement 1 — Ammunition types

**User Story:** As a player, I want to choose what I load into my cannons, so that combat is a
tactical decision rather than a single repeated button press.

#### Acceptance Criteria

1. WHEN the player fires a broadside THEN the system SHALL use the currently selected
   ammunition type.
2. The system SHALL support exactly three ammunition types: `ROUND` (hull damage),
   `CHAIN` (speed/sail damage), and `GRAPE` (crew damage).
3. WHEN `CHAIN` shot hits a ship THEN the system SHALL reduce that ship's effective top speed
   by a configured percentage for a configured duration, and SHALL NOT reduce hull health by
   the full round-shot amount.
4. WHEN `GRAPE` shot hits a ship THEN the system SHALL reduce that ship's crew count and SHALL
   NOT reduce hull health by the full round-shot amount.
5. Ammunition damage values, speed penalties, and durations SHALL be authored in a `Resource`
   file, not hardcoded in any script.
6. WHEN the player switches ammunition type THEN the HUD SHALL reflect the change within one
   frame.
7. The system SHALL NOT require ammunition to be purchased or depleted in this milestone
   (unlimited ammo of every type) — resource pressure comes from the economy, not from ammo.

### Requirement 2 — Directional damage and a real damage model

**User Story:** As a player, I want where I hit an enemy to matter, so that positioning is
rewarded.

#### Acceptance Criteria

1. The system SHALL track damage against a ship in at least three separate pools: `hull`,
   `sails`, and `crew`.
2. WHEN a ship's `hull` reaches zero THEN the ship SHALL be destroyed.
3. WHEN a ship's `sails` are damaged THEN its effective top speed SHALL be reduced
   proportionally, down to a configured floor above zero.
4. WHEN a ship's `crew` reaches zero THEN the ship SHALL become unable to fire.
5. WHEN a cannonball strikes a ship from behind (within a configured stern arc) THEN the
   system SHALL apply a configured critical damage multiplier.
6. The system SHALL emit a signal on every damage event carrying the pool affected and the
   amount, so UI and audio can react without polling.
7. Existing saves SHALL load without error after this change (missing pools default to full).

### Requirement 3 — Boarding

**User Story:** As a player, I want to board a crippled enemy rather than only sinking it, so
that I have a reason to fight carefully and a larger reward when I do.

#### Acceptance Criteria

1. WHEN an enemy ship's hull drops below a configured threshold AND the player ship is within
   a configured boarding range THEN the system SHALL offer a boarding prompt.
2. WHEN the player accepts a boarding prompt THEN the system SHALL resolve the boarding as a
   deterministic comparison of the two ships' crew counts modified by captain traits.
3. WHEN a boarding succeeds THEN the player SHALL receive a configured loot multiplier over
   sinking the same ship, and SHALL lose a portion of crew.
4. WHEN a boarding fails THEN the player SHALL lose a larger portion of crew and the enemy
   SHALL remain alive.
5. Boarding thresholds, ranges, multipliers, and crew losses SHALL be authored in a `Resource`
   file.
6. The system SHALL NOT require a minigame or new input scheme — boarding resolves through
   the existing UI layer.

### Requirement 4 — Crew as a resource

**User Story:** As a player, I want a crew that I must maintain, so that repeated fighting has
a cost I feel.

#### Acceptance Criteria

1. Every ship SHALL have a `crew` count with a maximum derived from its `ShipStats`.
2. WHEN the player docks at a friendly island with a Tavern THEN the player SHALL be able to
   recruit crew in exchange for gold and/or rum.
3. WHEN crew is below a configured fraction of maximum THEN the player ship's fire rate SHALL
   be reduced proportionally.
4. Crew SHALL persist across save/load via the existing `get_save_data()`/`load_save_data()`
   convention.

### Requirement 5 — Building levels 1–5

**User Story:** As a player, I want to upgrade my buildings repeatedly, so that my island
visibly improves as I invest in it.

#### Acceptance Criteria

1. Every production building SHALL have a five-level upgrade chain authored as five linked
   `BuildingData` resources with `next_upgrade` correctly set on levels 1–4.
2. WHEN a building is upgraded THEN its production per tick SHALL increase according to an
   authored curve, and its next upgrade cost SHALL increase according to an authored curve.
3. The level-5 building SHALL have `next_upgrade` unset, and the UI SHALL render it as
   maxed rather than showing a dead Upgrade button.
4. `BuildingData` SHALL expose a `level: int` field so UI and save data can reason about
   progression without string-parsing `building_id`.
5. WHEN a building is upgraded THEN its visual model SHALL change or scale to reflect the new
   level.
6. Building levels SHALL persist across save/load.
7. The existing `Island.upgrade_structure()` code path SHALL be used — this requirement SHALL
   NOT introduce a second parallel upgrade system (`AGENTS.md`: never duplicate systems).

### Requirement 6 — Island tiers and gated construction

**User Story:** As a player, I want my island to have an overall level that unlocks new
options, so that progression has visible milestones rather than only incremental numbers.

#### Acceptance Criteria

1. Each island SHALL derive an integer tier 1–5 from the levels of its constructed buildings.
2. WHEN an island's tier increases THEN the system SHALL emit a signal and the HUD SHALL
   announce it.
3. Buildings SHALL declare a `required_island_tier`, and the build UI SHALL disable (with a
   reason shown) any building whose requirement is unmet.
4. Island tier SHALL persist across save/load.

### Requirement 7 — Compounding production and storage pressure

**User Story:** As a player, I want my income to grow as I invest, and I want a reason to come
back and spend it, so that the loop keeps pulling me forward.

#### Acceptance Criteria

1. Production per economy tick SHALL scale with building level.
2. Storage caps SHALL scale with Warehouse level, replacing the current flat `+500/+200/+100/+50`
   per-warehouse constant in `ResourceManager.recalculate_storage_capacity()`.
3. WHEN a resource is at its storage cap THEN the HUD SHALL indicate it, so the player
   understands that further production is being wasted.
4. Upgrade costs SHALL be tuned so that reaching building level 5 requires resources that
   cannot be obtained from production alone within a reasonable session — combat loot SHALL be
   a necessary input. This is the mechanism that closes the circular economy.
5. The system SHALL NOT introduce timed build queues or real-time waits in this milestone.

### Requirement 8 — Combat rewards that feed the economy

**User Story:** As a player, I want fighting to pay for my empire, so that the two halves of
the game reinforce each other.

#### Acceptance Criteria

1. WHEN an enemy ship is destroyed or boarded THEN the loot granted SHALL scale with that
   ship's class.
2. Boarding SHALL yield strictly more than sinking, per Requirement 3.3.
3. Loot tables SHALL remain authored in the existing `LootTableData` resources.
4. WHEN the player's notoriety rises THEN encountered enemy ship classes SHALL trend larger,
   so that higher risk carries higher reward.

### Requirement 9 — Deferred M2 polish

**User Story:** As a player, I want the camera to behave when I dock and I want to rebind my
controls, so that the game feels finished.

#### Acceptance Criteria

1. WHEN the player docks THEN the camera SHALL transition smoothly to a docked framing, and
   SHALL restore the sailing framing on undock. (Closes M2 Task 5.3.)
2. The settings UI SHALL allow rebinding the core gameplay actions and SHALL persist bindings
   through `SettingsManager`. (Closes M2 Task 6.3.)
3. Rebinding SHALL reject a binding that would leave an essential action unbound.

---

## Non-Goals

Explicitly **out of scope** for M6, to keep the milestone shippable:

- Progression beyond level 5 of anything.
- Ammunition scarcity/purchasing.
- Fleet-vs-fleet tactical battles (player commands one ship in combat).
- Multiplayer, guilds, PvP (permanently out of scope per `AGENTS.md`).
- Timed build queues / energy timers.
- A boarding minigame.
