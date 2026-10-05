class_name PowderKeg extends RigidBody3D

## Purpose: droppable powder keg that detonates with area damage — M30 W1 task 1.10.
## Kegs float in water, have a visible fuse, and detonate on contact or proximity.
##
## Lifecycle:
## - Player drops a keg (consumes stock)
## - Keg floats for `fuse_burn_time` seconds
## - Keg detonates: applies AreaDamage in a radius, then frees itself
## - Stock is refilled when docking at a friendly island

signal detonated()

@export var config: KegConfigData = preload("res://resources/combat/KegConfig.tres")
@export var fuse_burn_time: float = 3.0  # placeholder: tune in M31
@export var buoyancy_force: float = 9.81  # match water's gravity

var _time_since_drop: float = 0.0
var _has_detonated: bool = false
var _spawner: Node = null  # Reference to EnemySpawner for target_hulls


func _ready() -> void:
	add_to_group("powder_kegs")
	gravity_scale = 0.0  # Handled by buoyancy


func _process(delta: float) -> void:
	if _has_detonated:
		return

	_time_since_drop += delta

	# Buoyancy: keep the keg at surface level
	if global_position.y < 0.0:
		global_position.y = 0.0
		linear_velocity.y = clampf(linear_velocity.y, -1.0, 0.0)

	# Check for detonation
	if _time_since_drop >= fuse_burn_time:
		_detonate()


func _detonate() -> void:
	if _has_detonated:
		return

	_has_detonated = true
	detonated.emit()

	# Apply area damage
	if config:
		# Gather all enemy hulls in the scene
		var target_hulls: Array[Node3D] = []
		for hull in get_tree().get_nodes_in_group("enemy_ship"):
			target_hulls.append(hull)

		AreaDamage.apply_damage(
			global_position,
			config.detonation_radius,
			config.detonation_damage,
			target_hulls
		)

	# Free the keg
	queue_free()


func set_spawner(spawner: Node) -> void:
	"""Optional: set the enemy spawner for contact detection."""
	_spawner = spawner
