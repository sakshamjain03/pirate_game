@tool
class_name HeatTierData extends Resource

## Purpose: one band of the player's "wanted level" (M25). Heat is a lens over
## `EmpireManager.notoriety` — a set of authored behaviours per band — NOT a
## second stat. Nothing should ever write a `heat` variable.
## Responsibilities: pure data. `HeatConfigData` holds the catalog,
## `EmpireManager` resolves the current tier, `EnemySpawner` and `EnemyAI` read
## it. Nothing here runs on its own.
##
## Adding a seventh tier must require zero script changes — author one more
## `.tres`, append it to the catalog, done.

@export var tier: int = 0
## Shown in the HUD ("Unknown", "Wanted", "Nemesis"...). Player-facing, so it is
## the thing that has to read as a wanted level without a number.
@export var display_name: String = ""
## Inclusive lower bound on `EmpireManager.notoriety`. The catalog resolves a
## notoriety value to the highest tier whose threshold it meets.
@export var min_notoriety: float = 0.0

@export_group("Ambient danger")
## Replaces EnemySpawner's previously hardcoded `max_enemies = 5`.
@export_range(0, 16) var max_ambient_enemies: int = 3
@export_range(5.0, 300.0) var spawn_interval_seconds: float = 30.0
## Multiplies spawned hull stats. Composes with EnemySpawner's existing
## region-tier/notoriety multiplier rather than replacing it.
@export_range(0.5, 5.0) var enemy_strength_multiplier: float = 1.0

@export_group("Aggression")
## THE GTA line. When false, an ambient enemy patrols and ignores the player
## until that specific ship is provoked (shot, rammed, boarded) or its faction
## is already hostile. A new player cannot be farmed before learning to steer.
@export var engages_unprovoked: bool = true

@export_group("Squads")
## M30 1.7 — the squads an ambient encounter that opts in
## (`EncounterData.use_heat_squad`) draws from at this tier. Higher tiers author
## bigger, nastier mixes; `test_m30_squads` pins that the average never drops.
@export var squad_pool: Array[SquadData] = []

@export_group("Cooling off")
## Free decay, applied after EmpireManager's grace window and doubled while the
## player is docked at an owned island. Free decay must always be able to reach
## tier 0 unaided — the paid clear is a shortcut, never the only way down
## (docs/00_VISION.md §19.2: a timer must also be shortenable by playing).
@export_range(0.0, 60.0) var decay_per_minute: float = 2.0
## Eights to drop from this tier to the one below. One tier per purchase, so
## clearing from Nemesis is a repeated deliberate choice rather than a single
## button that erases every consequence. 0 = cannot be bought down.
@export_range(0, 500) var clear_cost_eights: int = 0
