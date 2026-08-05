class_name BuoyancySimulator extends Node

## Purpose: Simulates buoyancy forces on the parent RigidBody3D ship.
## Responsibilities: Applies per-point buoyancy forces, drag, and stability torque.
## Dependencies: ShipStats, WaveGenerator, parent RigidBody3D

@export var ship_stats: ShipStats
@export var wave_generator: WaveGenerator
@export var float_points: Array[Node3D]

var body: RigidBody3D
var default_gravity: float = 9.8

## Depth (in meters) a float point needs to submerge before it produces a
## full point-share of upward force. Keeps the equilibrium waterline close
## to the hull's actual draft instead of requiring the whole point to sink
## a full meter+ before buoyancy can counteract gravity.
const SUBMERGE_DEPTH: float = 0.4

# Optimization for mobile (M10)
var _time_since_wave_calc: float = 0.0
const WAVE_CALC_INTERVAL: float = 0.06 # approx 15Hz
var _cached_water_heights: Dictionary = {}

func _ready() -> void:
	body = get_parent() as RigidBody3D
	if not body:
		push_error("BuoyancySimulator must be a child of a RigidBody3D")
		return

	if not wave_generator:
		var wave_gens = get_tree().get_nodes_in_group("wave_generator")
		if wave_gens.size() > 0:
			wave_generator = wave_gens[0] as WaveGenerator

	if ProjectSettings.has_setting("physics/3d/default_gravity"):
		default_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

	# Auto-discover float points from sibling FloatPoints node if not manually assigned
	if float_points.is_empty():
		var fp_container = body.get_node_or_null("FloatPoints")
		if fp_container:
			for child in fp_container.get_children():
				if child is Marker3D or child is Node3D:
					float_points.append(child)

	if float_points.is_empty():
		push_warning("BuoyancySimulator: No float_points configured — buoyancy will act at body center.")

func apply_buoyancy(delta: float) -> void:
	if not body or not ship_stats:
		return

	# If no wave generator, assume flat water at y=0
	var use_wave_gen = wave_generator != null

	# Use global time to sync with shader TIME
	var global_time = Time.get_ticks_msec() / 1000.0

	var effective_points: Array = float_points
	# Fallback: use body origin as single float point
	if effective_points.is_empty():
		_apply_buoyancy_at_pos(body.global_position, global_time, 1, use_wave_gen)
	else:
		_time_since_wave_calc += delta
		var update_waves = false
		if _time_since_wave_calc >= WAVE_CALC_INTERVAL:
			update_waves = true
			_time_since_wave_calc = 0.0
			
		for i in range(effective_points.size()):
			var point = effective_points[i]
			if point:
				var w_height = 0.0
				if use_wave_gen:
					if update_waves or not _cached_water_heights.has(i):
						w_height = wave_generator.get_water_height_at(point.global_position, global_time)
						_cached_water_heights[i] = w_height
					else:
						w_height = _cached_water_heights[i]
				_apply_buoyancy_at_pos_with_height(point.global_position, w_height, effective_points.size())

	# Apply overall stability torque to keep ship upright
	var right = body.global_transform.basis.x
	var forward = -body.global_transform.basis.z

	var target_up = Vector3.UP
	var pitch_correction = target_up.dot(forward)
	var roll_correction = target_up.dot(right)

	var stability_torque = (right * pitch_correction - forward * roll_correction) \
		* ship_stats.stability * body.mass * ship_stats.stability_torque_multiplier
	body.apply_torque(stability_torque)

func _apply_buoyancy_at_pos(global_pos: Vector3, time: float, num_points: int, use_wave_gen: bool) -> void:
	var water_height: float = 0.0
	if use_wave_gen:
		water_height = wave_generator.get_water_height_at(global_pos, time)
	_apply_buoyancy_at_pos_with_height(global_pos, water_height, num_points)

func _apply_buoyancy_at_pos_with_height(global_pos: Vector3, water_height: float, num_points: int) -> void:
	var depth = water_height - global_pos.y
	if depth > 0:
		var force_per_point = (body.mass * default_gravity) / float(num_points)
		var buoyancy_force = (depth / SUBMERGE_DEPTH) * ship_stats.buoyancy * force_per_point
		var force = Vector3.UP * buoyancy_force
		var offset = global_pos - body.global_position
		body.apply_force(force, offset)

		# Water drag
		var point_vel = body.linear_velocity + body.angular_velocity.cross(offset)
		var drag_force = -point_vel * depth * ship_stats.water_drag_multiplier
		body.apply_force(drag_force, offset)
