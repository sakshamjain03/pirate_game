class_name MaelstromBandData extends Resource

## Purpose: one escalation band of a Maelstrom run (M26).
## Responsibilities: pure data. From `start_seconds` until the next band starts,
##   MaelstromRun hands these values to EnemySpawner.spawn_profile_override.

## Seconds survived at which this band takes over.
@export var start_seconds: float = 0.0
@export var max_enemies: int = 3
@export var spawn_interval: float = 6.0
## Multiplies a spawned hull's max_health and cannon_damage on a duplicated
## ShipStats — never the shared resource.
@export var strength_multiplier: float = 1.0
## Empty = the spawner's own enemy_scene.
@export var ship_pool: Array[PackedScene] = []
## Optional. Spawned once, when the run enters this band.
@export var boss_scene: PackedScene
