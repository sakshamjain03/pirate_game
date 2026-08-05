@tool
class_name ShipStats extends Resource

@export_group("Movement")
@export_range(0.0, 100.0) var max_speed: float = 30.0
@export_range(0.0, 10.0) var acceleration: float = 2.0
@export_range(0.0, 10.0) var deceleration: float = 1.5
@export_range(0.0, 10.0) var turn_rate: float = 1.5
@export_range(0.0, 1.0) var drift_factor: float = 0.3

@export_group("Physics")
@export_range(0.0, 10000.0) var mass: float = 5000.0
@export_range(0.0, 1.0) var buoyancy: float = 0.8
@export_range(0.0, 1.0) var stability: float = 0.7
@export_range(0.0, 1.0) var reverse_turn_modifier: float = 0.5
@export_range(0.0, 20.0) var drift_compensation_multiplier: float = 5.0
@export_range(0.0, 10.0) var water_drag_multiplier: float = 2.0
@export_range(0.0, 20.0) var stability_torque_multiplier: float = 10.0
@export_range(0.0, 10.0) var linear_damp: float = 0.5
@export_range(0.0, 10.0) var angular_damp: float = 2.0

@export_group("Visual")
@export var model_path: String = "res://assets/models/ships/player_ship.glb"
@export var material_path: String = "res://resources/materials/ShipMaterial.tres"

@export_group("Combat")
@export_range(1.0, 1000.0) var max_health: float = 100.0
@export_range(1.0, 100.0) var cannon_damage: float = 15.0
@export_range(0.1, 10.0) var fire_rate: float = 2.0
@export_range(10.0, 1000.0) var cannon_range: float = 200.0
@export_range(10.0, 200.0) var cannon_speed: float = 100.0
