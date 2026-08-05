class_name ShipMovement extends Node

@export var ship_stats: ShipStats
var body: RigidBody3D

func _ready() -> void:
	body = get_parent() as RigidBody3D
	if not body:
		push_error("ShipMovement must be a child of a RigidBody3D")

func apply_movement(forward_input: float, turn_input: float, delta: float) -> void:
	if not body or not ship_stats:
		return
		
	var speed_mod = 1.0
	var turn_mod = 1.0
	if body and "active_captain" in body and body.active_captain:
		speed_mod = body.active_captain.speed_modifier
		turn_mod = body.active_captain.turn_rate_modifier
		
	# Forward/Backward movement (Propulsion)
	var forward_dir = -body.global_transform.basis.z.normalized()
	
	if forward_input != 0:
		var target_speed = ship_stats.max_speed * speed_mod * forward_input
		var current_speed = body.linear_velocity.dot(forward_dir)
		var speed_diff = target_speed - current_speed
		
		# Use acceleration for speeding up, deceleration for slowing down/reversing
		var accel = ship_stats.acceleration if (forward_input * current_speed > 0 and abs(current_speed) < abs(target_speed)) else ship_stats.deceleration
		
		# Calculate force to reach target speed, capped by max acceleration
		var max_velocity_change = accel * delta
		var actual_velocity_change = sign(speed_diff) * min(abs(speed_diff), max_velocity_change)
		var force = forward_dir * (actual_velocity_change / delta * body.mass)
		
		body.apply_central_force(force)
	else:
		# Water resistance
		var current_speed = body.linear_velocity.dot(forward_dir)
		var drag = -forward_dir * (current_speed * ship_stats.deceleration * body.mass)
		body.apply_central_force(drag)

	# Turning (Steering)
	if turn_input != 0:
		# Reduce turn rate if moving backwards (Property 9)
		var current_speed = body.linear_velocity.dot(forward_dir)
		var actual_turn_rate = ship_stats.turn_rate * turn_mod
		if current_speed < -0.1:
			actual_turn_rate *= ship_stats.reverse_turn_modifier
			
		var torque = Vector3.UP * (-turn_input * actual_turn_rate * body.mass)
		body.apply_torque(torque)
		
	# Drift compensation
	var right_dir = body.global_transform.basis.x.normalized()
	var drift_velocity = body.linear_velocity.dot(right_dir)
	var anti_drift_force = -right_dir * (drift_velocity * (1.0 - ship_stats.drift_factor) * body.mass * ship_stats.drift_compensation_multiplier)
	body.apply_central_force(anti_drift_force)
