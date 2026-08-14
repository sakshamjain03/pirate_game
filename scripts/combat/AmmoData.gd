@tool
class_name AmmoData extends Resource

@export var ammo_id: String = "round"
@export var display_name: String = "Round Shot"

@export_group("Damage")
@export var hull_damage_mult: float = 1.0
@export var sail_damage_mult: float = 0.0
@export var crew_damage_mult: float = 0.0

@export_group("Effects")
@export var speed_penalty: float = 0.0        # fraction of top speed removed
@export var speed_penalty_duration: float = 0.0

@export_group("Ballistics")
@export var speed_mult: float = 1.0           # multiplies ShipStats.cannon_speed
@export var spread_degrees: float = 0.0       # grape spreads, round does not
@export var projectiles_per_cannon: int = 1   # grape fires a cluster
