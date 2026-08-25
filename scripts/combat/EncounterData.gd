@tool
class_name EncounterData extends Resource

## Purpose: one authored naval encounter — composition, objective, rewards, pacing.
## Responsibilities: pure data. `EncounterManager` interprets it; nothing here runs.
##
## This is the content framework of `docs/navalCombat.md` §15 (encounter types) and
## the thing that gives §11's temporary upgrades a "current battle" to belong to.
## Adding a new kind of fight must never need a script change — author a `.tres`.

enum Kind {
	ENCOUNTER,  ## small hostile group, the baseline fight
	CONVOY,     ## merchant fleet to break
	AMBUSH,     ## spawns around the player rather than ahead of them
	ELITE,      ## harder composition, better loot
	BOSS,       ## unique hull with its own stats
	DEFENSE,    ## protect a friendly hull or island
}

enum Objective {
	DESTROY_ALL,     ## sink every ship in the composition
	DESTROY_COUNT,   ## sink `objective_count` of them
	SURVIVE_TIME,    ## stay alive for `time_limit` seconds
	PROTECT_TARGET,  ## the escorted hull must survive
}

@export var encounter_id: String = "open_water_skirmish"
@export var display_name: String = "Enemy Sail Sighted"
@export_multiline var announce_text: String = "Enemy sail sighted off the bow!"

@export_group("Type")
@export var kind: Kind = Kind.ENCOUNTER
@export var objective: Objective = Objective.DESTROY_ALL
## Only read for DESTROY_COUNT.
@export_range(1, 20) var objective_count: int = 1
## Seconds. The pacing target for a normal fight is 2–5 min, elite 5–8, boss 5–12
## (`docs/navalCombat.md` §13). 0 means no limit.
@export_range(0.0, 900.0) var time_limit: float = 0.0

@export_group("Composition")
@export var enemy_scene: PackedScene
@export_range(1, 12) var enemy_count: int = 2
## Multiplies the composition's health and damage. Stacks on top of
## `EnemySpawner.compute_spawn_multiplier()`'s region/notoriety scaling, and is
## applied to a *duplicated* ShipStats — never to the shared resource.
@export_range(0.1, 10.0) var strength_multiplier: float = 1.0
@export_range(10.0, 400.0) var spawn_distance_min: float = 55.0
@export_range(10.0, 400.0) var spawn_distance_max: float = 90.0

@export_group("Escort")
## Only used when `objective == PROTECT_TARGET` — DEFENSE's "protect a friendly
## hull" (see `Kind.DEFENSE` above). Spawned at the encounter centre with its
## AI and auto-fire disabled: it is a target, not a combatant. The encounter
## ends in defeat if it is destroyed before the composition is cleared.
@export var escort_scene: PackedScene

@export_group("Allies")
## AI-controlled support ships that actually fight alongside the player
## (`docs/navalCombat.md` §15) — unlike the escort above, these keep their
## `EnemyAI` and auto-fire, and losing one is not a fail condition; they're
## tactical aid for this fight, not an objective.
@export var ally_scene: PackedScene
@export_range(0, 4) var ally_count: int = 0
## Optional override for the ally's AI personality/role (`AIProfileData.Role`,
## Slice 6). Empty keeps whatever profile `ally_scene` already authors.
@export var ally_profile: AIProfileData

@export_group("Rewards")
@export var loot_table: LootTableData
## Granted once on victory, on top of the per-kill drops that already exist.
@export_range(0, 5000) var bonus_gold: int = 0
@export_range(0, 1000) var captain_xp: int = 50
@export_range(0.0, 100.0) var notoriety_reward: float = 5.0

@export_group("Pacing")
## How many temporary upgrade choices this battle offers (`docs/navalCombat.md`
## §12: 2–4 for a normal encounter, more for a boss).
@export_range(0, 8) var upgrade_offers: int = 2
## Seconds between offers. §12 targets ~30–60 s, deliberately not a fast timer.
@export_range(5.0, 180.0) var upgrade_interval: float = 40.0

@export_group("Disengage")
## Sailing this far from the encounter centre for `disengage_grace` seconds ends
## the fight as an escape — §16's "target escaped" outcome. No rewards, no
## penalty; the player simply chose not to commit.
@export_range(50.0, 600.0) var disengage_distance: float = 220.0
@export_range(1.0, 60.0) var disengage_grace: float = 6.0


func get_kind_name() -> String:
	return Kind.keys()[kind].capitalize()
