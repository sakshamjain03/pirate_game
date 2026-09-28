# Requirements Document

## Introduction

The game has one way to play: the campaign. There is nothing to pick up for ten minutes, no mode
that is purely about combat, and no reason to come back once a chapter is done. **The Maelstrom**
is an endless, Vampire-Survivors-style survival mode: one ship, open water inside a storm wall,
enemies that never stop and keep getting stronger, and pickups floating in the ocean from every
kill — plunder that levels the run up, repair kits, and short-lived power-ups. Each level-up offers
three temporary upgrades. The run ends when the ship sinks; how long it lasted is the score.

It is **isolated from the campaign by construction**. A run never changes gold, wood, iron, rum,
notoriety, heat, fleet, captains, chapter progress or the campaign save. The single deliberate
link is the one `AGENTS.md` already allows: a run may grant a capped amount of Pieces of Eight
("Eights are only granted by purchase, chapters, achievements, sieges and Maelstrom runs").

**Already met, no work needed** — this mode is mostly assembly of parts that exist:
- `BattleUpgradeData` + 6 authored upgrades (`resources/combat/upgrades/`) — "Vampire-Survivors-
  style build choices, active for the current encounter only" per its own header.
- `CombatModifiers` — per-ship stacked temporary multipliers, `apply_upgrade()`, `can_apply()`,
  `add_timed_effect(effects, duration)`, `repair_pool()`, `reset()`; never mutates `ShipStats`.
- `UpgradeChoiceScreen` — pauses the tree, shows cards, and binds to *any* node exposing
  `upgrade_offer_requested(choices, offer_index, total_offers)` and `apply_upgrade_choice()`.
- `EnemySpawner` — safe-distance spawning, population cap, interval, strength multiplier via a
  duplicated `ShipStats`, with exported fallbacks when no heat tier is available.
- `LootDrop` — floating, bobbing pickup with proximity collect and a `collected(loot_data)` signal.
- `SaveManager` autosave already runs only when `current_scene.name == "World"`.

## Glossary

- **Run** — one Maelstrom session, from entering the scene to the ship sinking or the player
  quitting. All run state lives on one scene-local node and is discarded when the scene frees.
- **Band** — one authored `MaelstromBandData` entry: from `start_seconds`, the enemy cap, spawn
  interval, strength multiplier and ship pool in force.
- **Plunder** — run XP. Dropped by kills, collected by sailing over it, spent automatically on
  level-ups. Not gold; never touches `ResourceManager`.
- **Level-up** — reaching the next plunder threshold; opens one upgrade offer of three choices.
- **Pickup** — a `LootDrop` in the Maelstrom carrying one `kind`: `plunder`, `repair`, `powerup`,
  or `keg`.
- **Game mode** — `SceneManager.game_mode`, `CAMPAIGN` or `MAELSTROM`. The one switch every
  campaign side-effect checks.

## Requirements

### Requirement 1: Entering and leaving the mode

**User Story:** As a player, I want to start an endless battle from the main menu at any time, so
that I can play a quick session without touching my campaign.

#### Acceptance Criteria

1. The main menu SHALL show a "The Maelstrom" button, available from a fresh install with no save.
2. WHEN pressed, THE game SHALL set `SceneManager.game_mode = MAELSTROM` and change to
   `res://scenes/modes/Maelstrom.tscn`.
3. THE run's player ship SHALL use the player's active hull (`FleetManager.get_active_ship()`)
   read-only, falling back to the starter sloop when there is none.
4. WHEN the run ends or the player quits, THE game SHALL return to the main menu and set
   `game_mode = CAMPAIGN` before any other scene loads.

### Requirement 2: Campaign isolation

**User Story:** As a player, I want a Maelstrom run to leave my campaign exactly as it was, so
that the mode is safe to play at any point.

#### Acceptance Criteria

1. WHILE `game_mode == MAELSTROM`, a kill SHALL NOT change `EmpireManager.notoriety`.
2. WHILE `game_mode == MAELSTROM`, a pickup SHALL NOT call `ResourceManager.add_resource()` for
   any campaign resource.
3. THE Maelstrom scene SHALL NOT contain a `Systems/EnemySpawner` or `Systems/EncounterManager`
   path, so `CampaignManager` and `SeasonalEventManager` never connect to its kills.
4. THE Maelstrom scene root SHALL NOT be named `World`, so `SaveManager` never autosaves during a
   run.
5. A test SHALL snapshot every manager's `get_save_data()` before a scripted run (kills, pickups,
   level-ups, death) and assert every snapshot is identical afterwards, except the `maelstrom`
   section and the Eights grant.

### Requirement 3: Escalation

**User Story:** As a player, I want the pressure to climb the longer I survive, so that every
run ends in a real fight.

#### Acceptance Criteria

1. Enemy cap, spawn interval, strength multiplier and ship pool SHALL come from an authored
   `MaelstromCurveData` (`resources/balance/MaelstromCurve.tres`) of time-ordered bands. No
   escalation value SHALL be hardcoded in a script.
2. `EnemySpawner` SHALL accept a spawn-profile override that, when set, replaces the heat-tier
   lookup for cap, interval and strength. With no override its behaviour SHALL be unchanged.
3. Enemy ships SHALL engage the player unprovoked for the whole run.
4. A band MAY author a boss spawn at its start; the boss SHALL be one existing boss scene.
5. Strength scaling SHALL duplicate `ShipStats`, never mutate the shared resource.

### Requirement 4: Pickups from the ocean

**User Story:** As a player, I want kills to scatter things I sail over, so that moving through
the fight is as important as shooting.

#### Acceptance Criteria

1. Every Maelstrom kill SHALL drop one or more pickups rolled from an authored drop table.
2. `plunder` SHALL add run XP only. `repair` SHALL call `CombatModifiers.repair_pool()`.
   `powerup` SHALL call `CombatModifiers.add_timed_effect()` with an authored effect and
   duration. `keg` SHALL deal authored area damage to enemies around the pickup.
3. Pickups SHALL despawn after their authored lifetime.
4. A pickup magnet radius SHALL exist as a modifier an upgrade can raise.

### Requirement 5: Level-ups

**User Story:** As a player, I want to choose an upgrade each time I level up, so that each run
becomes a different build.

#### Acceptance Criteria

1. Plunder thresholds per level SHALL be authored in `MaelstromCurveData`.
2. On reaching a threshold THE run SHALL emit `upgrade_offer_requested` with three weighted
   choices that `CombatModifiers.can_apply()` accepts, and `UpgradeChoiceScreen` SHALL show them
   with the tree paused.
3. THE upgrade pool SHALL contain at least 18 `BattleUpgradeData` resources (6 existing + at
   least 12 new).
4. Multiple level-ups gained at once SHALL queue, one offer at a time.

### Requirement 6: Run end, score and reward

**User Story:** As a player, I want a result screen and a reason to try again, so that a lost run
still feels like progress.

#### Acceptance Criteria

1. WHEN the player ship dies, THE run SHALL stop spawning and show a results panel: time survived,
   kills, level reached, best time, Eights earned, with Retry and Main Menu.
2. Eights SHALL be granted from an authored milestone table (survived-seconds → Eights), summed,
   and capped by an authored per-run maximum.
3. THE Eights grant SHALL be the only campaign-visible effect of a run.
4. Best time, best level and total runs SHALL persist in a `maelstrom` save section via
   `get_save_data()`/`load_save_data()`. THE section SHALL be omitted entirely when no run has
   ever finished.

## Out of Scope

- **Meta-progression** (permanent unlocks bought between runs). Eights are the only carry-over;
  a meta tree is a separate balance problem.
- **Leaderboards / online scores.** The game has no multiplayer and `AGENTS.md` forbids adding it.
- **New enemy art or hulls.** Bands draw from the existing enemy and boss scenes.
- **Maelstrom-specific islands or map.** Open water inside a storm wall only.
- **Rewarded ad for a revive.** Belongs with M33's ad work, if at all.
- **Chapter lesson for the mode.** M28 authors a pointer lesson; this milestone only builds the mode.
