@tool
class_name SquadSlotData extends Resource

## Purpose: one slot of an authored squad (M30 1.7) — which hull, flown how, how many.
## Responsibilities: pure data. `EncounterManager._spawn_composition()` expands it,
##   setting `EnemyAI.ai_profile` on each hull BEFORE `add_child`, because
##   `EnemyAI` applies its profile in `_ready()`.

## The hull to spawn. Null falls back to `EncounterData.enemy_scene`, then the
## spawner's default enemy scene.
@export var hull_scene: PackedScene
## The personality this hull flies with. Null keeps whatever the scene authors.
@export var ai_profile: AIProfileData
@export_range(1, 4) var count: int = 1  # placeholder: tune in M31
## The hull class (stats + model) this slot sails, so a squad mixes sloops with
## frigates rather than only AI personalities. Duplicated per hull and assigned
## before add_child, exactly as EnemySpawner does with `enemy_ship_pool`. Null
## keeps the scene's own stats.
@export var ship_stats: ShipStats
