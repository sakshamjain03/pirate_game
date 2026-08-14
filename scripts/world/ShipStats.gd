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
## Range is 0..30 rather than 0..20 because the authored ships form a deliberate
## ladder scaling with hull size (Dinghy 8 -> Galleon 20 -> ManOWar 25), and
## ManOWar's 25 sat outside the old range. Out-of-range values still load at
## runtime, so this was never silently dropped — but the inspector clamped it,
## so editing ManOWar in the editor would have quietly snapped it to 20.
@export_range(0.0, 30.0) var stability_torque_multiplier: float = 10.0
@export_range(0.0, 10.0) var linear_damp: float = 0.5
@export_range(0.0, 10.0) var angular_damp: float = 2.0

@export_group("Visual")
@export var model_path: String = "res://assets/models/ships/player_ship.glb"
## Empty means "keep the model's own colormap colors". The previous default
## pointed at a ShipMaterial.tres that does not exist in the project, so any
## ShipStats that didn't override it made KenneyMaterialApplier fail to load a
## base material and silently skip the toon/outline pass entirely.
@export var material_path: String = ""

@export_group("Combat")
@export_range(1.0, 1000.0) var max_health: float = 100.0
@export_range(1.0, 1000.0) var max_sails: float = 100.0
@export_range(1.0, 200.0) var max_crew: float = 20.0
@export_range(1.0, 5.0) var stern_crit_multiplier: float = 1.5
@export_range(0.0, 180.0) var stern_arc_degrees: float = 60.0
@export_range(0.0, 1.0) var min_speed_fraction: float = 0.35
@export_range(0.0, 1.0) var optimal_crew_fraction: float = 0.5
@export_range(1.0, 100.0) var cannon_damage: float = 15.0
@export_range(0.1, 10.0) var fire_rate: float = 2.0
@export_range(10.0, 1000.0) var cannon_range: float = 200.0
@export_range(10.0, 200.0) var cannon_speed: float = 100.0
